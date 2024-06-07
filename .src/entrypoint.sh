#!/bin/bash
# This script acts as an entrypoint for the container, allowing the user to run different commands based on the provided arguments.

# Function to display help text
show_help() {
    # Use basename to strip the directory path and show only the script name
    local script_name=$(basename "$0")
    echo "Usage: $script_name <command> [args]"
    echo "Available commands:"
    for cmd in "${!commands[@]}"; do
        echo " · $cmd [args]"
    done
    echo "Run without any arguments to start an interactive shell or use one of the commands above."
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
)


# Check if a command is provided and if it's in the list of recognized commands
if [[ -z "$1" ]]; then
    # No command provided
    if [[ -t 0 ]]; then
        # Terminal is attached, start an interactive shell without showing help
        exec /bin/bash
    else
        # No terminal attached, show help
        show_help
        exit 1
    fi
elif [[ -n "${commands[$1]}" ]]; then
    # Extract the command
    command="$1"
    script_path="${commands[$command]}"

    # Remove the command from the arguments list
    shift

    # Execute the corresponding script with the remaining arguments
    exec "$script_path" "$@"
else
    # Command not recognized, show help
    echo "Unknown command: $1"
    show_help
    exit 1
fi
