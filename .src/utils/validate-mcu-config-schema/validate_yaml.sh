#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <yaml-file> <json-schema>"
    exit 1
fi

yaml_file="$1"
json_schema="$2"
json_temp="$(mktemp).json"  # Ensuring the temp file has a .json extension might help with editors/tools recognizing the format.

# Determine the directory where the script is located to find validate_json.sh
script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
json_validator="${script_dir}/validate_json.sh"

# Convert YAML to JSON using yq
yq eval -o=json "$yaml_file" > "$json_temp"

# Validate the converted JSON using the validate_json.sh script
"$json_validator" "$json_temp" "$json_schema"
if [ $? -ne 0 ]; then
    echo "JSON validation failed, exiting..."
    exit 1
fi
# Clean up temporary JSON file
rm "$json_temp"
