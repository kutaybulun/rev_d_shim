#!/bin/bash

# Check if the environment variable REV_D_SHIM_DIR is set
if [ -z "$REV_D_SHIM_DIR" ]; then
    echo "Please set the environment variable REV_D_SHIM_DIR to the path of the RevD-Shim directory."
    exit 1
fi

# Change to the RevD-Shim directory, then to the kernel_modules directory
cd "$REV_D_SHIM_DIR" || exit 1
cd kernel_modules || exit 1

# Check if the directory argument is provided
if [ $# -eq 0 ]; then
    echo "Please provide a directory as an argument."
    exit 1
fi

# Change directory to the first argument
cd "$1" || exit 1

# Run make with ARCH=arm
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-