#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <json-file> <json-schema>"
    exit 1
fi

json_file="$1"
json_schema="$2"

# Validate JSON against the JSON Schema
pajv -d "$json_file" -s "$json_schema" || {
    echo "Validation failed: JSON file does not conform to the schema."
    exit 1
}