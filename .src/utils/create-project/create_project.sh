#!/bin/bash
# Usage: create-project.sh --path /some/path --config-file /path/to/config --template-path /path/to/template --github-repo https://github.com/example

# Function to display help
show_help() {
    local script_name=$(basename "$0")
    echo "Usage: $script_name --path <path to project> [--config-file <path to config file> | --template-path <path to template> | --github-repo <repository URL>]"
    echo "Options:"
    echo "  --path: Set the path where the project should be created."
    echo "  --config-file: Specify the configuration file to be used for the project."
    echo "  --template-path: Specify the path to a project template."
    echo "  --github-repo: Specify the GitHub repository URL for the project."
}

# Capture the script directory to create paths for sourcing other scripts and files
SCRIPT_DIR="$(dirname "$0")"
PROJECT_CREATION_TEMPLATES_DIR="/opt/.project-creator-templates/"
PROJECT_CREATOR_DUAL_CORE_TEMPLATE="${PROJECT_CREATION_TEMPLATES_DIR}/dual-core/template"
PROJECT_CREATOR_SINGLE_CORE_TEMPLATE="${PROJECT_CREATION_TEMPLATES_DIR}/single-core/template"

# Source the script to create a project from a configuration file
CREATE_PROJECT_FROM_CONFIG_FILE="/commands/utils/create-project/create_project_from_config.sh"

# Define an associative array to map options to variables
declare -A options=(
    [--path]="project_path"
    [--config-file]="config_file"
    [--template-path]="template_path"
    [--github-repo]="github_repo"
)

# Initialize variables
project_path=""
config_file=""
template_path=""
github_repo=""

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        if [[ "${options[$1]}" ]]; then
            local varname=${options[$1]}
            local value="$2"
            if [[ -n $value && ! $value =~ ^-- ]]; then
                eval "$varname='$value'"
                shift 2
            else
                echo "Error: No value provided for $1"
                show_help
                exit 1
            fi
        else
            echo "Unknown option or value provided without an option: $1"
            show_help
            exit 1
        fi
    done
}

# Check that mandatory parameters are provided
function check_mandatory_params() {
    if [[ -z "$project_path" ]]; then
        echo "Error: Missing required parameters. 'path' is mandatory."
        show_help
        exit 1
    fi
}

# Check that at least one of the optional parameters is provided
function check_optional_params() {
    if [[ -z "$config_file" && -z "$template_path" && -z "$github_repo" ]]; then
        echo "Error: At least one of 'config-file', 'template-path', or 'github-repo' must be specified."
        show_help
        exit 1
    fi
}

#  Function to create project
function create_project() {
    if [[ -n "$config_file" ]]; then
        "$CREATE_PROJECT_FROM_CONFIG_FILE" --config-file "$config_file" --project-path "$project_path"
    elif [[ -n "$template_path" ]]; then
        echo "Creating project from template at $template_path"
    elif [[ -n "$github_repo" ]]; then
        echo "Creating project from GitHub repository $github_repo"
    fi
}

## Call the functions
parse_args "$@"
check_mandatory_params
check_optional_params
create_project
