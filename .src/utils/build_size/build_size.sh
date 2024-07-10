#!/bin/bash

# Path to the binary
BINARY_PATH=$1

if [ -z "$BINARY_PATH" ]; then
  echo "Usage: $0 <binary_path>"
  exit 1
fi

# Run arm-none-eabi-size and capture the output
OUTPUT=$(arm-none-eabi-size "$BINARY_PATH")

# Parse the output
TEXT=$(echo "$OUTPUT" | awk 'NR==2 {print $1}')
DATA=$(echo "$OUTPUT" | awk 'NR==2 {print $2}')
BSS=$(echo "$OUTPUT" | awk 'NR==2 {print $3}')
DEC=$(echo "$OUTPUT" | awk 'NR==2 {print $4}')

# Convert sizes and decide the unit
convert_size() {
  local SIZE=$1
  local UNIT
  local CONVERTED_SIZE

  if (( SIZE >= 1048576 )); then
    CONVERTED_SIZE=$(echo "scale=3; $SIZE / 1048576" | bc)
    UNIT="MB"
  else
    CONVERTED_SIZE=$(echo "scale=3; $SIZE / 1024" | bc)
    UNIT="KB"
  fi

  echo "$CONVERTED_SIZE $UNIT"
}

TEXT_SIZE=$(convert_size $TEXT)
DATA_SIZE=$(convert_size $DATA)
BSS_SIZE=$(convert_size $BSS)
DEC_SIZE=$(convert_size $DEC)

# Output the formatted report
echo -e "\nBuild Size Report:"
echo -e "Executable code and read-only data:  ${TEXT_SIZE}"
echo -e "$(tput setaf 4)Initialized data:  ${DATA_SIZE}$(tput sgr0)"
echo -e "$(tput setaf 3)Uninitialized data:  ${BSS_SIZE}$(tput sgr0)"
echo -e "$(tput setaf 2)Total size:  ${DEC_SIZE}$(tput sgr0)"
