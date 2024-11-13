#!/bin/bash
# Build a PetaLinux project for the given board name
# Usage: petalinux.sh <board_name> <project_name>
if [ $# -ne 2 ]; then
    echo "Usage: $0 <board_name> <project_name>"
    exit 1
fi

# Check that the necessary XSA exists
if [ ! -f "tmp/${1}/${2}/hw_def.xsa" ]; then
    echo "Missing generated XSA hardware definition file: tmp/${1}/${2}/hw_def.xsa."
    exit 1
fi

# Check that the necessary PetaLinux config files exist
if [ ! -f "projects/${2}/petalinux_cfg/config" ]; then
    echo "Missing source PetaLinux project configuration for project ${2}: projects/${2}/petalinux_cfg/config"
    exit 1
fi
if [ ! -f "projects/${2}/petalinux_cfg/config" ]; then
    echo "Missing source filesystem project configuration for project ${2}: projects/${2}/petalinux_cfg/rootfs_config"
    exit 1
fi

# Make the project
cd tmp
echo "[MAKE SCRIPT] Creating project"
petalinux-create project --template zynq --name ${1}/${2}/petalinux

# Enter the project
cd ${1}/${2}/petalinux

# Patch the project configuration
echo "[MAKE SCRIPT] Initializing default project configuration"
petalinux-config --get-hw-description ../hw_def.xsa --silentconfig
echo "[MAKE SCRIPT] Patching and configuring project"
patch project-spec/configs/config ../../../../projects/${2}/petalinux_cfg/config.patch
petalinux-config --silentconfig

# Patch the root filesystem configuration
echo "[MAKE SCRIPT] Initializing default root filesystem configuration"
petalinux-config -c rootfs --silentconfig
echo "[MAKE SCRIPT] Patching and configuring root filesystem"
patch project-spec/configs/rootfs_config ../../../../projects/${2}/petalinux_cfg/rootfs_config.patch
petalinux-config -c rootfs --silentconfig

# Build the project
echo "[MAKE SCRIPT] Building the project"
petalinux-build
