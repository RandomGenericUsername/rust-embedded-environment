#!/bin/bash
# This script acts as an entrypoint for the container, allowing the user to run different commands based on the provided arguments.

# Function to display help text
show_help() {
    # Use basename to strip the directory path and show only the script name
    local script_name=$(basename "$0")
    echo "Available commands:"
    for cmd in "${!commands[@]}"; do
        echo "  $cmd"
    done
    echo "Usage: $script_name [command]"
}


# Get the directory of the script
SCRIPT_DIR="$(dirname "$0")"
COMPILE_PROJECT="${SCRIPT_DIR}/utils/compile-project/compile_project.sh"
CREATE_PROJECT="${SCRIPT_DIR}/utils/create-project/create_project.sh"

# Define an associative array where keys are command names and values are script paths
declare -A commands
commands=(
    [compile]=$COMPILE_PROJECT # compile a project
    [create-project]=$CREATE_PROJECT # create a new project
    [/bin/bash]="/bin/bash" # Note: This is a special case to run a shell inside the containe
)

# Check if a command is provided and is in the list of recognized commands
if [[ -z "$1" ]] || [[ -z "${commands[$1]}" ]]; then
    # If no command is provided or it's not recognized, show help
    echo "Unknown or missing command: $1"
    show_help
    exit 1
else
    # Extract the command
    command="$1"
    script_path="${commands[$command]}"
    
    # Remove the command from the arguments list
    shift
    
    # Execute the corresponding script with the remaining arguments
    exec "$script_path" "$@"
fi
