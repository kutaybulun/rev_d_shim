#!/bin/bash
# Create a patch file for the PetaLinux filesystem configuration
# Usage: petalinux.sh <board_name> <project_name>
if [ $# -ne 2 ]; then
    echo "Usage: $0 <board_name> <project_name>"
    exit 1
fi

# Check if terminal width is at least 80 columns
if [ $(tput cols) -lt 80 ] || [ $(tput lines) -lt 19 ]; then
    echo "Terminal must be at least 80 columns wide and 19 lines tall to use the PetaLinux configuration menu."
    exit 1
fi

# Store the positional parameters in named variables and clear them
# (Petalinux settings script requires no positional parameters)
BRD=${1}
PRJ=${2}
set --

# Check that the project exists in "projects"
if [ ! -d "projects/${PRJ}" ]; then
    echo "Project directory not found: projects/${PRJ}"
    exit 1
fi

# Check that the PetaLinux project configuration patch exists
if [ ! -f "projects/${PRJ}/petalinux_cfg/config.patch" ]; then
    echo "Missing PetaLinux project configuration patch already exists for project ${PRJ}: projects/${PRJ}/petalinux_cfg/config.patch"
    echo "First run the following command:"
    echo
    echo "  scripts/petalinux_config_project.sh ${BRD} ${PRJ}"
    echo
    exit 1
fi

# Check that the necessary XSA exists
if [ ! -f "tmp/${BRD}/${PRJ}/hw_def.xsa" ]; then
    echo "Missing generated XSA hardware definition file: tmp/${BRD}/${PRJ}/hw_def.xsa"
    echo "First run the following command:"
    echo
    echo "  make BOARD=${BRD} PROJECT=${PRJ} xsa"
    echo
    exit 1
fi

# Source the PetaLinux settings script (make sure to clear positional parameters first)
source ${PETALINUX_PATH}/settings.sh

# Create a new template project
cd tmp
if [ -d "petalinux_template" ]; then
    rm -rf petalinux_template
fi
mkdir petalinux_template
cd petalinux_template
petalinux-create -t project --template zynq --name petalinux
cd petalinux

# Patch the project configuration
echo "[MAKE SCRIPT] Initializing default project configuration"
petalinux-config --get-hw-description ../../${BRD}/${PRJ}/hw_def.xsa --silentconfig
echo "[MAKE SCRIPT] Patching and configuring project"
patch project-spec/configs/config ../../../../projects/${PRJ}/petalinux_cfg/config.patch
petalinux-config --silentconfig

# Initialize the default root filesystem configuration
echo "[MAKE SCRIPT] Initializing default root filesystem configuration"
petalinux-config -c rootfs --silentconfig

# Copy the default root filesystem configuration
echo "[MAKE SCRIPT] Saving default root filesystem configuration"
cp project-spec/configs/rootfs_config project-spec/configs/rootfs_config.default

# Manually configure the root filesystem
echo "[MAKE SCRIPT] Manually configuring root filesystem"
petalinux-config -c rootfs

# Create a patch for the root filesystem configuration
echo "[MAKE SCRIPT] Creating root filesystem configuration patch"
diff -u project-spec/configs/rootfs_config.default project-spec/configs/rootfs_config > ../../../projects/${PRJ}/petalinux_cfg/rootfs_config.patch
