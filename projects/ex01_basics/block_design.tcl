## Instantiate the processing system and connect it to fixed IO and DDR

# Create the PS (processing_system7)
# Config:
# - Disable AXI ACP interface
# - Disable M_AXI_GP0 interface
# Connect the FCLK to an external port
init_ps ps {
  PCW_USE_S_AXI_ACP 0
  PCW_USE_M_AXI_GP0 0
} {
  FCLK_CLK0 fclk0
}
