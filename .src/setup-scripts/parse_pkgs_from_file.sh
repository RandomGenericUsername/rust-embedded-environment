parsePackagesFromFile() {
    file="$1"
    packages=""

    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -n "$line" && "${line:0:1}" != "#" ]]; then
            if [[ -z "$packages" ]]; then
                packages="$line"
            else
                packages="$packages $line"
            fi
        fi
    done < "$file"

    echo "$packages"
}
