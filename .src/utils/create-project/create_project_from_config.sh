#!/bin/bash
# Usage: create_project_from_config_file.sh --config-file /path/to/config --project-path /path/to/project 


SCRIPT_DIR="$(pwd)"
PROJECT_CREATION_TEMPLATES_DIR="/opt/.project-creator-templates/"
PROJECT_CREATOR_DUAL_CORE_TEMPLATE="${PROJECT_CREATION_TEMPLATES_DIR}/dual-core/template"
PROJECT_CREATOR_SINGLE_CORE_TEMPLATE="${PROJECT_CREATION_TEMPLATES_DIR}/single-core/template"

CONFIG_FILE=""
PROJECT_PATH=""

DEFAULT_DEBUG_CONFIGURATION="gdb-multiarch"

# Load the flatten_yaml.sh script
FLATTEN_YAML="/commands/utils/create-project/flatten_yaml.sh"

# Temp file for the flatten configuration
FLATTENED_CONFIG_TEMP="/tmp/cargo-generate-values-template-temp.toml"

# Ignore sections in the configuration file
IGNORE_SECTIONS_CONFIG_FILE="directories extra_sections"

MODIFY_MEMORY_X="/commands/utils/create-project/modify_memory_x.sh"

VALIDATE_CONFIG_SCHEMA="/commands/utils/validate-mcu-config-schema/validate_yaml.sh"
CONFIG_SCHEMA="/opt/validation-schema/mcu_config_schema.json"
GET_CHIP_NAME_FOR_EMBED_TOML="/commands/utils/create-project/get_chip_name_for_embed_toml.sh"


# Function to check if a file exists
check_file_exists() {
    [[ -f "$1" ]]
}


function write_at_beginning_of_file() {
    local file_path="$1"
    local content="$2"
    local temp_file_path="/tmp/temp_file"
    echo $content > $temp_file_path
    echo "" >> $temp_file_path
    cat $file_path >> $temp_file_path
    mv $temp_file_path $file_path
}

function set_chip_name_in_flattened_config() {
    local flattened_config_file="$1"
    local mcu="$2"
    local chip_name=$($GET_CHIP_NAME_FOR_EMBED_TOML -m "$mcu" -s "- _" -n 4 -e 1)
    if [[ -z "$chip_name" ]]; then
        return 1
    fi  
    echo "chip_configuration = \"$chip_name\"" >> $flattened_config_file
}

is_dual_core() {
    [[ $(yq e '.config | length' "$1") -ge 2 ]]
}

flatten_config() {
    local config_file="$1"
    $FLATTEN_YAML -p "$config_file" -o "$FLATTENED_CONFIG_TEMP" -i "$IGNORE_SECTIONS_CONFIG_FILE" -f "toml" || { echo "Configuration flattening failed..."; exit 1; }
}


initialize_project() {
    local project_path="$1"
    local config_file="$2"
    local project_name=$(basename "$project_path")
    local destination_dir=$(dirname "$project_path")
    [[ "$destination_dir" == "." ]] && destination_dir="$SCRIPT_DIR"
    if is_dual_core "$config_file"; then
        local template_path="$PROJECT_CREATOR_DUAL_CORE_TEMPLATE"
    else
        local template_path="$PROJECT_CREATOR_SINGLE_CORE_TEMPLATE"
    fi

    cargo generate --destination "$destination_dir" \
                   --name "$project_name" \
                   --path "$template_path" \
                   --template-values-file "$FLATTENED_CONFIG_TEMP"
}


add_targets_and_memory_sections() {
    local config_file="$1"
    local project_path="$2"
    local configs=$(yq e '.config | keys' "$config_file" -o json | jq -r '.[]')
    
    for config in $configs; do
        local arch=$(yq e ".config[$config].architecture" "$config_file")
        rustup target add "$arch"

        local core=$(yq e ".config[$config].core" "$config_file")
        handle_memory_sections "$config_file" "$config" "$project_path" "$core"
    done
}

handle_memory_sections() {
    local config_file="$1"
    local config="$2"
    local project_path="$3"
    local core="$4"

    local extra_sections_key=".config[$config].memory.extra_sections"
    local extra_memory_sections_json=$(yq e "$extra_sections_key" "$config_file" -o json)

    if [[ "$extra_memory_sections_json" != "null" && "$extra_memory_sections_json" != "" ]]; then
        readarray -t extra_memory_sections <<< "$(echo "$extra_memory_sections_json" | jq -c '.[]')"
        local memory_x_path="${project_path}/$(is_dual_core "$config_file" && echo "${core}/")memory.x"
        $MODIFY_MEMORY_X "$memory_x_path" "${extra_memory_sections[@]}"
    fi
}


cleanup_temp_files() {
    rm -f "$FLATTENED_CONFIG_TEMP"
}

function add_debug_configuration() {
    local config_file="$1"
    local debug_configuration="$2"

    # Check if the "debug_configuration" key exists in the YAML file and if its value is not an empty string
    local key_value=$(yq eval '.debug_configuration' "$config_file")

    # If the key does not exist or its value is an empty string, add it with the value passed as the second argument
    if [[ "$key_value" == "null" || "$key_value" == "" ]]; then
        yq eval ".debug_configuration = \"$debug_configuration\"" -i "$config_file"
    fi
}

# Create a project from a configuration file
function create_project_from_config() {
    local config_file="$1"
    local project_path="$2"

    if ! check_file_exists "$config_file"; then
        echo "Error: Configuration file not found: $config_file"
        exit 1
    fi

    # validate the config file
    $VALIDATE_CONFIG_SCHEMA "$config_file" "$CONFIG_SCHEMA" || { echo "Configuration file validation failed..."; exit 1; }
    # Add debug configuration
    add_debug_configuration "$config_file" "$DEFAULT_DEBUG_CONFIGURATION"
    # flatten the config file
    flatten_config "$config_file"
    # Add "[values]" at the beginning of the file
    write_at_beginning_of_file "$FLATTENED_CONFIG_TEMP" "[values]"
    # Set the chip name according to probe-rs chip list
    set_chip_name_in_flattened_config "$FLATTENED_CONFIG_TEMP" "$(yq e '.target' "$config_file" -o json)"
    # Create the project structure using cargo generate
    initialize_project "$project_path" "$config_file"
    # Add extra memory sections if defined any in the config file
    # Add also targets for the architectures defined in the config file
    add_targets_and_memory_sections "$config_file" "$project_path"
    # Clean up the temporal files
    cleanup_temp_files
}   

# Parse arguments passed to the script
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --config-file) CONFIG_FILE="$2"; shift ;;
        --project-path) PROJECT_PATH="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not provided."
    exit 1
fi

if [[ -z "$PROJECT_PATH" ]]; then
    echo "Error: Project path not provided."
    exit 1
fi

create_project_from_config $CONFIG_FILE $PROJECT_PATH
