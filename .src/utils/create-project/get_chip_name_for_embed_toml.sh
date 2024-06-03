#!/bin/bash

# Function to print the usage of the script
print_usage() {
    echo "Usage: $0 -m <MCU name> -s <separator characters> -n <number of matches> -e <matching element>"
    echo
    echo "This script takes the name of a microcontroller (MCU) and tries to find a matching chip"
    echo "using the 'probe-rs chip list' command. The MCU name can have different formats and"
    echo "separator characters (e.g., '-', '_', '.', ' ')."
    echo
    echo "Options:"
    echo "  -m, --mcu                Name of the microcontroller"
    echo "  -s, --separator          Separator characters"
    echo "  -n, --number-of-matches  Minimum number of characters to match"
    echo "  -e, --matching-element   Element index to use for matching"
    echo
    echo "Example:"
    echo "  $0 -m Nucleo-F411 -s : . _ - -n 5 -e 2"
}

# Function to split the MCU name by a given separator
split_mcu_name() {
    local mcu_name=$1
    local separator=$2
    IFS=$separator read -ra parts <<< "$mcu_name"
    echo "${parts[@]}"
}

# Function to get the probe-rs chip list
get_probe_rs_chip_list() {
    probe-rs chip list 
}

# Function to match MCU elements with probe-rs chip list
match_mcu_with_chip_list() {
    local mcu_parts=("$@")
    local chip_list=$(get_probe_rs_chip_list)
    for ((i=${#mcu_parts[@]}-1; i>=0; i--)); do
        local part=${mcu_parts[i],,} # Convert to lowercase for comparison
        local match=$(echo "$chip_list" | grep -i "$part")
        if [ -n "$match" ]; then
            echo "$match" | sed 's/^[ \t]*//'
            return 0
        fi
    done
    echo ""
    return 1
}

# Function to perform fallback matching using the number of matches criterion
fallback_match_mcu_with_chip_list() {
    local element=$1
    local number_of_matches=$2
    shift 2
    local mcu_parts=("$@")
    local chip_list=$(get_probe_rs_chip_list)
    
    # Determine the element to use based on the provided index
    if (( element >= ${#mcu_parts[@]} )); then
        element=${#mcu_parts[@]}-1
    fi
    local match_part=${mcu_parts[element],,} # Convert to lowercase for comparison

    # Perform the matching based on the number of characters
    for chip in $chip_list; do
        if [[ "${chip,,}" == *"${match_part:0:$number_of_matches}"* ]]; then
            echo "$chip" | sed 's/^[ \t]*//'
            return 0
        fi
    done
    echo ""
    return 1
}

# Function to process the input MCU name
process_mcu_name() {
    local mcu_name=$1
    local number_of_matches=$2
    local matching_element=$3
    shift 3
    local separators=("$@") # Array of separators
    for separator in "${separators[@]}"; do
        local mcu_parts=($(split_mcu_name "$mcu_name" "$separator"))
        local match=$(match_mcu_with_chip_list "${mcu_parts[@]}")
        if [ -n "$match" ]; then
            echo "$match"
            return 0
        fi
    done

    # If initial matching fails, perform the fallback matching
    for separator in "${separators[@]}"; do
        local mcu_parts=($(split_mcu_name "$mcu_name" "$separator"))
        local fallback_match=$(fallback_match_mcu_with_chip_list "$matching_element" "$number_of_matches" "${mcu_parts[@]}")
        if [ -n "$fallback_match" ]; then
            echo "Fallback match found: $fallback_match"
            return 0
        fi
    done

    echo "No match found"
    return 1
}

# Function to parse the arguments
parse_arguments() {
    local mcu_name=""
    local separators=()
    local number_of_matches=0
    local matching_element=0
    local in_separators=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -m|--mcu)
                mcu_name="$2"
                shift 2
                ;;
            -s|--separator)
                in_separators=true
                shift
                ;;
            -n|--number-of-matches)
                number_of_matches="$2"
                shift 2
                ;;
            -e|--matching-element)
                matching_element="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                if [[ "$in_separators" == true && "$1" =~ ^-[a-zA-Z] ]]; then
                    in_separators=false
                fi
                ;;
        esac
        
        if [[ "$in_separators" == true ]]; then
            separators+=("$1")
            shift
        fi
    done

    if [[ -z "$mcu_name" ]]; then
        echo "Error: MCU name is required."
        print_usage
        exit 1
    fi

    if [[ ${#separators[@]} -eq 0 ]]; then
        echo "Error: At least one separator is required."
        print_usage
        exit 1
    fi

    if [[ $number_of_matches -le 0 ]]; then
        echo "Error: Number of matches must be greater than zero."
        print_usage
        exit 1
    fi

    process_mcu_name "$mcu_name" "$number_of_matches" "$matching_element" "${separators[@]}"
}

# Check if the user provided the necessary arguments
if [[ $# -eq 0 ]]; then
    print_usage
    exit 1
fi

# Parse the arguments and run the main function
parse_arguments "$@"
