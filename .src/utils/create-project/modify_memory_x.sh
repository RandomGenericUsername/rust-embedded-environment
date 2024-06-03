#!/bin/bash

function add_memory_sections() {
    local memory_x_path="$1"
    shift
    local memory_sections=("$@")

    # Backup the original file before modification
    cp "$memory_x_path" "${memory_x_path}.bak"

    # Build the string of new lines to be inserted
    local insert_command=""
    
    # Ensure the first line and subsequent lines have consistent indentation
    for section in "${memory_sections[@]}"; do
        local memory_type=$(echo "$section" | jq -r '.memory_type' | tr '[:lower:]' '[:upper:]')
        local origin=$(echo "$section" | jq -r '.origin')
        local length=$(echo "$section" | jq -r '.length')

        # Adding indentation before each memory section
        insert_command+="\t${memory_type}\t\t\t: ORIGIN = ${origin}, \tLENGTH = ${length}\n"
    done

    # Use printf to handle the newlines correctly when passing to awk
    printf -v insert_command "%b" "$insert_command"

    # Use awk to insert the new sections before the last '}' character in the MEMORY block
    awk -v insert="$insert_command" '
    /^MEMORY/ { in_memory_block = 1 }
    in_memory_block && /^}/ { print insert; in_memory_block = 0 }
    { print }
    ' "$memory_x_path" > "$memory_x_path.tmp"

    # Replace the original file with the modified content
    mv "$memory_x_path.tmp" "$memory_x_path"
}

# Only run if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: ${0} <path_to_memory_x> <memory_section_1> ... <memory_section_N>"
        exit 1
    fi

    memory_x_path=$1
    shift
    memory_sections=("$@")
    add_memory_sections "$memory_x_path" "${memory_sections[@]}"
    rm -f "${memory_x_path}.bak"
fi
