# Define the default ports for the Zynq 7010 board
# TCL script for Vivado to create ports for default XDC file

create_bd_port -dir IO -from 3 -to 0 sw
create_bd_port -dir IO -from 3 -to 0 btn
create_bd_port -dir IO -from 3 -to 0 led