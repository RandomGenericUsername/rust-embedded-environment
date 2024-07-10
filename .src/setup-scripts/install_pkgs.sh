#!/bin/bash
source /usr/local/bin/parse_pkgs_from_file.sh
install() {
    local packagesFilePath=$1
    local packages="$(parsePackagesFromFile $packagesFilePath)"
    apt-get update && \
    apt-get install -y ${packages[@]}
    rm -rf /var/lib/apt/lists/*
}

install $@