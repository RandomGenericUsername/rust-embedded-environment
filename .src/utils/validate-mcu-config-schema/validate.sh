#!/bin/bash

# Check if at least two arguments are provided (command and file paths)
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <command> <file> <schema>"
    echo "Commands:"
    echo "  json - Validate a JSON file"
    echo "  yaml - Validate a YAML file"
    exit 1
fi

# Get the command and shift the parameters so $1 starts with the first file path
command="$1"
shift

# Determine the directory where the script is located to find other scripts
script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

case "$command" in
    json)
        json_validator="${script_dir}/validate_json.sh"
        if [ ! -f "$json_validator" ]; then
            echo "JSON validation script not found."
            exit 1
        fi
        "$json_validator" "$@"
        ;;
    yaml)
        yaml_validator="${script_dir}/validate_yaml.sh"
        if [ ! -f "$yaml_validator" ]; then
            echo "YAML validation script not found."
            exit 1
        fi
        "$yaml_validator" "$@"
        ;;
    *)
        echo "Invalid command: $command"
        echo "Valid commands are 'json' or 'yaml'."
        exit 1
        ;;
esac
