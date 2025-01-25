# Initialize the Vivado environment for the Snickerdoodle Rev D, declaring directories

# Source this from your Vivado_init.tcl. 
# Make sure to set the REV_D_DIR environment variable to the root of the this repository.
# Example (to paste into Vivado_init.tcl):
# ------------------------------------------------------------
#     # Set up Rev D configuration
#     set rev_d_dir $::env(REV_D_DIR)
#     source $rev_d_dir/scripts/vivado_repo_init.tcl
# ------------------------------------------------------------

# Vivado_init.tcl is searched for in the following directories (in order, with each overwriting the previous):
# - Install directory (`/tools/Xilinx/Vivado/<version>/Vivado_init.tcl` by default)
# - Particular Vivado version (`~/.Xilinx/Vivado/<version>/Vivado_init.tc`)
# - Overall Vivado (`~/.Xilinx/Vivado/Vivado_init.tcl`)

set rev_d_dir $::env(REV_D_DIR)
set_param board.repoPaths [glob -type d ${rev_d_dir}/boards/*/board_files/1.0/]
