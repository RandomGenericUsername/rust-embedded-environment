#!/bin/bash

# Declare associative array for command options
declare -A options=(
    [-p]="path_to_file"
    [-o]="output_file"
    [-i]="ignore_keys"
    [-f]="output_format"
)

# Variable to store the keys that will be ignored from flattening
ignore_keys=()
# Default name of the output file
output_file="flattened_output.yml"  # Default output file if not specified
intermediate_file_path="/tmp/intermediate.yaml"
output_format="yaml"  # Default format is YAML



# Help function
function show_help() {
    echo "Usage: $0 -p <path/to/yaml> -o <output/file> -i <ignore_key1 ignore_key2 ...>"
    echo "  -p, --path: Path to the YAML file (mandatory)"
    echo "  -o, --output: Output file path (default: flattened_output.yml in current directory)"
    echo "  -i, --ignore-keys: Keys to ignore in the flattening process (optional)"
    echo "  -f, --format: Output format (yaml, json, toml) (default: yaml)"
}


# Function to parse the command-line options
function parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -p|--path) path_to_file="$2"; shift 2 ;;
            -o|--output) output_file="$2"; shift 2 ;;
            -f|--format) output_format="$2"; shift 2 ;;
            -i|--ignore-keys) shift; while [[ "$#" -gt 0 && "${1:0:1}" != "-" ]]; do ignore_keys+=("$1"); shift; done ;;
            *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
        esac
    done

    if [ -z "$path_to_file" ]; then
        echo "Error: Path to YAML file is mandatory."
        show_help
        exit 1
    fi

    # Validate the output format
    if ! [[ "$output_format" =~ ^(yaml|json|toml)$ ]]; then
        echo "Error: Unsupported format '$output_format'. Supported formats are yaml, json, toml."
        exit 1
    fi
}

# Function to convert the output to the specified format
function correct_toml_format() {
    local toml_file="$1"
    sed -i 's/: /=/' $toml_file
}

# Function to convert the output to the specified format
function convert_output_format() {
    local input_file="$1"
    local output_file="$2"
    local format="$3"

    case "$format" in
        yaml)
            cp "$input_file" "$output_file"
            ;;
        json)
            yq e -o=json "$input_file" > "$output_file"
            ;;
        toml)
            remarshal -i "$input_file" -o "$output_file" -if yaml -of toml
            correct_toml_format "$output_file"
            ;;
        *)
            echo "Unsupported format '$format'. No conversion performed."
            ;;
    esac
    return 0
}

# Function to extract indices from section parts
extract_index() {
    local section="$1"
    # Use regex to extract the index within brackets if present
    [[ "$section" =~ \[([0-9]+)\] ]] && echo "${BASH_REMATCH[1]}"
}


# Function to modify the string as specified
# Function to modify the string as specified
modify_string() {
    local input_string="$1"
    local remove_sections="$2"
    local separator="$3"
    local min_sections="$4"
    
    # Split the string into an array based on '.'
    IFS='.' read -r -a sections <<< "$input_string"
    
    # Determine the total number of sections
    local total_sections="${#sections[@]}"

    # Adjust min_sections if it matches the total number of sections to total_sections - 1
    if [[ "$min_sections" -eq "$total_sections" ]]; then
        min_sections=$((total_sections - 1))
    fi

    # Determine how many sections to actually remove
    remove_sections=$((remove_sections > total_sections - min_sections ? total_sections - min_sections : remove_sections))
    
    # Collect indices and prepare final sections
    local indices=()
    local result_sections=()
    
    for (( i=0; i<total_sections; i++ )); do
        local index=$(extract_index "${sections[i]}")
        [[ -n "$index" ]] && indices+=("$index")  # Collect index if exists
        
        # Add to result if it is beyond the removed sections
        if (( i >= remove_sections )); then
            # Remove indices from section names
            local clean_section="${sections[i]%%\[*}"
            result_sections+=("$clean_section")
        fi
    done
    
    # Create the base result string by joining result_sections with separator
    local result=$(IFS="$separator"; echo "${result_sections[*]}")
    
    # Append indices to the result string
    for index in "${indices[@]}"; do
        result+="${separator}${index}"
    done
    
    echo "$result"
}


write_to_yaml() {
    local key="$1"
    local value="$2"
    local output_yaml_path="$3"
    local temp_yaml="temp_value.yaml"
    # Check if the output file exists, if not, create it
    if [[ ! -f "${output_yaml_path}" ]]; then
        touch "${output_yaml_path}"
    fi
    # Check if the value is a string and needs to retain its quotes
    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
        # The value is already a quoted string
        echo "${value}" > "$temp_yaml"
    else
        # Handle non-string or needs to be converted to a properly quoted string
        echo "\"${value}\"" > "$temp_yaml"
    fi
    # Use yq to import this data directly under the specified key
    yq e -i ".${key} = load(\"${temp_yaml}\")" "$output_yaml_path"
    # Clean up the temporary file
    rm "$temp_yaml"
    return 0
}


# Function to check if a key should be ignored
function should_ignore() {
    local path="$1"
    for ignore in "${ignore_keys[@]}"; do
        if [[ "$path" == *"$ignore"* ]]; then
            return 0 # True, should ignore
        fi
    done
    return 1 # False, should not ignore
}

function access_yaml_element_str {
    local key="$1"
    local path="$2"
    local value=$(yq eval ".${key}" "$path")
    local def_key=$(modify_string ${key} "3" "_" "2")
    write_to_yaml "$def_key" "$value" "$intermediate_file_path"
    #echo "<========================================================>"
    #echo "[Key ${key} is a string => ${value}]"
    #echo "<========================================================>"
}


function access_yaml_element_list {
    local key="$1"
    local path=$2
    local data_keys_index=$(yq eval ".${key} | keys" "$path" -o json | jq -r '.[]')
    #echo "<|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|>"
    #echo "Key ${key} is a list with ${#data_keys_index} elements"
    for data_key_index in $data_keys_index; do
        explore_yaml_impl "$path" "${key}[${data_key_index}]"
    done    
    #echo "<|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|>"
}

function access_yaml_element_map {
    local key="$1"
    local path=$2
    local data_keys=$(yq eval ".${key} | keys" "$path" -o json | jq -r '.[]')
    #echo "<#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#->"
    #echo "Key ${key} is a map with ${#data_keys} elements"
    for data_key in $data_keys; do
        explore_yaml_impl "$path" "${key}.${data_key}"
    done
    #echo "<#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#->"
}

function explore_yaml_impl {

    local path=$1
    local key=$2
    local type=$(yq eval ".${key} | type" "$path")
    local value=$(yq eval ".${key}" "$path")

    # Check if the key should be ignored
    if should_ignore "$key"; then
        #echo "<I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I>"
        #echo "Ignoring key $key => $value"
        # Return 0 to indicate that the key should be ignored
        return 0
        #local def_key_ignore=$(modify_string ${key} "3" "_" "2")
        #write_to_yaml "$def_key_ignore" "$value" "$output_file"
        #echo "<I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I-I>"
    fi

    ## Check if the value is a string directly
    if [[ $type == "!!str" ]]; then
        access_yaml_element_str $key $path
        # Check if the value is a map or an array and recurse
    elif [[ $type == "!!seq" ]];then #|| [[ "$(yq eval ".${full_path} | type" "$path")" == "object" ]]; then
        access_yaml_element_list $key $path
    elif [[ $type == "!!map" ]]; then
        access_yaml_element_map $key $path
    else
        echo "[Key ${key} is not yet supported]"
        echo "Type: $type"
        echo "Value: $value"
    fi
}

# Recursive function to navigate through the YAML structure
function explore_yaml {
    #echo "Exploring YAML file at $1"
    local keys=$(yq eval "keys" "$1" -o json | jq -r '.[]')
    for key in $keys; do
        explore_yaml_impl $1 $key
    done    
}




parse_args "$@"
explore_yaml "$path_to_file"
convert_output_format $intermediate_file_path $output_file $output_format
rm $intermediate_file_path
#echo "Flattened file created at $output_file"
