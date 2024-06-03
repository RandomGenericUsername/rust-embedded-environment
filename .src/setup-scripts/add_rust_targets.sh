#!/bin/bash

# Loop over each architecture target and add it using rustup
for target in $@; do
    echo "Adding target: $target"
    rustup target add $target
done
