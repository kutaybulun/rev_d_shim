#!/bin/bash

# Check if the environment variable REV_D_SHIM_DIR is set
if [ -z "$REV_D_SHIM_DIR" ]; then
    echo "Please set the environment variable REV_D_SHIM_DIR to the path of the RevD-Shim directory."
    exit 1
fi

# Change to the RevD-Shim directory, then to the kernel_modules directory
cd "$REV_D_SHIM_DIR" || exit 1
echo "Starting from the RevD-Shim directory (\$REV_D_SHIM_DIR): $REV_D_SHIM_DIR"
cd kernel_modules || exit 1

# Check if the directory argument is provided
if [ $# -eq 0 ]; then
    echo "Please provide a directory as an argument."
    exit 1
fi

# By default, just run make with ARCH=arm and CROSS_COMPILE=arm-linux-gnueabihf-
MAKE_CMD="make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KDIR=$REV_D_SHIM_DIR/snickerdoodle_src/build/kernel"

# Optionally append the second argument to the make command
if [ $# -eq 2 ]; then
    MAKE_CMD="$MAKE_CMD $2"
fi

# Change directory to the first argument, checking if the directory exists
cd "$1" || exit 1

# Display the directory chosen
echo "Building kernel module(s) in directory: $(pwd)"

# Run the make command
$MAKE_CMD