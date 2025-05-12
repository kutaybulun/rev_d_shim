#!/bin/bash
# Check the PetaLinux offline path environment variables for a project, board, and version
# Arguments: <board_name> <board_version> <project_name> [--full]
# Full check: PetaLinux project and prerequisites
# Minimum check: None

# Parse arguments
if [ $# -lt 3 ] || [ $# -gt 4 ] || ( [ $# -eq 4 ] && [ "$4" != "--full" ] ); then
  echo "[CHECK PTLNX OFFLINE] ERROR:"
  echo "Usage: $0 <board_name> <board_version> <project_name> [--full]"
  exit 1
fi
FULL_CHECK=false
if [[ "$4" == "--full" ]]; then
  FULL_CHECK=true
fi

# Store the positional parameters in named variables and clear them
BRD=${1}
VER=${2}
PRJ=${3}
PBV="project \"${PRJ}\" and board \"${BRD}\" v${VER}"
set --

# If any subsequent command fails, exit immediately
set -e

# Check prerequisites. If full, check all prerequisites. Otherwise, just the immediate necessary ones.
if $FULL_CHECK; then
  # Full check: XSA file and prerequisites
  ./scripts/check/petalinux_project.sh ${BRD} ${VER} ${PRJ} --full
fi # Minimum check: None

# Check the PetaLinux offline "downloads" path
if [ -z "$PETALINUX_DOWNLOADS_PATH" ]; then
  echo "[CHECK PTLNX OFFLINE] ERROR: PETALINUX_PATH environment variable is not set."
  exit 1
fi
if [ ! -d "${PETALINUX_DOWNLOADS_PATH}" ]; then
  echo "[CHECK PTLNX OFFLINE] ERROR: PetaLinux offline downloads directory not found at ${PETALINUX_DOWNLOADS_PATH}"
  exit 1
fi

# Check the PetaLinux offline "sstate" path
if [ -z "$PETALINUX_SSTATE_PATH" ]; then
  echo "[CHECK PTLNX OFFLINE] ERROR: PETALINUX_PATH environment variable is not set."
  exit 1
fi
if [ ! -d "${PETALINUX_SSTATE_PATH}" ]; then
  echo "[CHECK PTLNX OFFLINE] ERROR: PetaLinux offline sstate directory not found at ${PETALINUX_SSTATE_PATH}"
  exit 1
fi
