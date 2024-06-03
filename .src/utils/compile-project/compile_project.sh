#!/bin/bash

# Function to parse command line arguments
parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --path)
                PROJECT_PATH="$2"
                shift 2
                ;;
            --arch)
                TARGET_ARCH="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --release)
                BUILD_TYPE="--release"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Check required arguments
    if [ -z "$PROJECT_PATH" ] || [ -z "$TARGET_ARCH" ] || [ -z "$OUTPUT_DIR" ]; then
        echo "Error: Missing required arguments."
        show_help
        exit 1
    fi

    # Default BUILD_TYPE to debug if not set
    BUILD_TYPE="${BUILD_TYPE:-}"
}

# Function to display help text
show_help() {
    echo "Usage: $0 --path <path-to-project> --arch <target-architecture> [--release]"
    echo ""
    echo "Options:"
    echo "  --path     Specify the path to the Rust project directory."
    echo "  --arch     Specify the target architecture for cross-compilation."
    echo " --output-dir Specify the output directory for the compiled binaries."
    echo "  --release  Compile in release mode (omit for debug mode)."
    echo "  --help     Display this help message."
}

# Main script execution starts here
parse_args "$@"

# Ensure the target architecture is added for cross-compilation
rustup target add "$TARGET_ARCH"

# Compile the project using specified directory and target
echo "Compiling the Rust project at ${PROJECT_PATH} for target ${TARGET_ARCH}..."
cargo build $BUILD_TYPE --manifest-path "${PROJECT_PATH}/Cargo.toml" --target "$TARGET_ARCH" --target-dir "${PROJECT_PATH}/$OUTPUT_DIR"

# Check the compilation status
if [ $? -eq 0 ]; then
    echo "Compilation successful. Binaries located in ${PROJECT_PATH}/output/${TARGET_ARCH}/${BUILD_TYPE:2}"
else
    echo "Compilation failed."
    exit 1
fi

# Binaries are already in the specified output directory due to --target-dir
echo "Compilation artifacts are stored in ${PROJECT_PATH}/output/${TARGET_ARCH}/${BUILD_TYPE:2}/"
