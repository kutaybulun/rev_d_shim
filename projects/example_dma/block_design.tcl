############# General setup #############

## Instantiate the processing system

# Create the PS (processing_system7)
# Enable S_AXI_ACP port
# Tie AxUSER pins to 1 for ACP port (to enable coherency)
# Connections:
# - GP AXI 0 (Master) clock is connected to the processing system's first clock, FCLK_CLK0
# - ACP AXI (Slave) clock is connected to the processing system's first clock, FCLK_CLK0
init_ps ps {
  PCW_USE_S_AXI_ACP 1
  USE_DEFAULT_ACP_USER_VAL 1
} {
  M_AXI_GP0_ACLK ps/FCLK_CLK0
  S_AXI_ACP_ACLK ps/FCLK_CLK0
}

## PS reset core
# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 ps_rst {} {
  ext_reset_in ps/FCLK_RESET0_N
  slowest_sync_clk ps/FCLK_CLK0
}

### AXI Smart Connects
# PS to cfg/sts registers
cell xilinx.com:ip:smartconnect:1.0 ps_axi_smc {
  NUM_SI 1
  NUM_MI 2
} {
  aclk ps/FCLK_CLK0
  S00_AXI /ps/M_AXI_GP0
  aresetn ps_rst/peripheral_aresetn
}
# To ACP
cell xilinx.com:ip:smartconnect:1.0 dma_axi_smc {
  NUM_SI 1
  NUM_MI 1
} {
  aclk ps/FCLK_CLK0
  M00_AXI ps/S_AXI_ACP
  aresetn ps_rst/peripheral_aresetn
}


## Add an AXI CFG and STS register
cell pavel-demin:user:axi_cfg_register:1.0 cfg_0 {
  CFG_DATA_WIDTH 160
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} {
  aclk ps/FCLK_CLK0
  aresetn ps_rst/peripheral_aresetn
  S_AXI ps_axi_smc/M00_AXI
}
cell pavel-demin:user:axi_sts_register:1.0 sts_0 {
  STS_DATA_WIDTH 64
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} {
  aclk ps/FCLK_CLK0
  aresetn ps_rst/peripheral_aresetn
  S_AXI ps_axi_smc/M01_AXI
}
addr 0x40000000 128 cfg_0/S_AXI
addr 0x40100000 128 sts_0/S_AXI


# Slice off individual register signals
cell pavel-demin:user:port_slicer min_addr_writer {
  DIN_WIDTH 160 DIN_FROM 31 DIN_TO 0
} {
  din cfg_0/cfg_data
}
cell pavel-demin:user:port_slicer min_addr_reader {
  DIN_WIDTH 160 DIN_FROM 63 DIN_TO 32
} {
  din cfg_0/cfg_data
}
cell pavel-demin:user:port_slicer sample_count_writer {
  DIN_WIDTH 160 DIN_FROM 79 DIN_TO 64
} {
  din cfg_0/cfg_data
}
cell pavel-demin:user:port_slicer sample_count_reader {
  DIN_WIDTH 160 DIN_FROM 95 DIN_TO 80
} {
  din cfg_0/cfg_data
}
cell pavel-demin:user:port_slicer writer_start_ptr {
  DIN_WIDTH 160 DIN_FROM 111 DIN_TO 96
} {
  din cfg_0/cfg_data
}
cell pavel-demin:user:port_slicer reader_end_ptr {
  DIN_WIDTH 160 DIN_FROM 127 DIN_TO 112
} {
  din cfg_0/cfg_data
}
cell pavel-demin:user:port_slicer dma_enable {
  DIN_WIDTH 160 DIN_FROM 128 DIN_TO 128
} {
  din cfg_0/cfg_data
}

## Instantiate the DMA connection
cell lcb:user:axi_ram_flow_control:1.0 axi_ram_flow_control {
  AXIS_TDATA_WIDTH 128
  FIFO_WRITE_DEPTH 256
} {
  aclk ps/FCLK_CLK0
  aresetn ps_rst/peripheral_aresetn
  M_AXI dma_axi_smc/S00_AXI
  dma_enable dma_enable/dout
  min_addr_writer min_addr_writer/dout
  min_addr_reader min_addr_reader/dout
  sample_count_writer sample_count_writer/dout
  sample_count_reader sample_count_reader/dout
  writer_start_ptr writer_start_ptr/dout
  reader_end_ptr reader_end_ptr/dout
  S_AXIS axi_ram_flow_control/M_AXIS
}
# These are the default addresses provided by the automation, leaving them as-is
# ACP_IOP         0xE000_0000 4M  0xE03F_FFFF
# ACP_M_AXI_GPO   0x4000_0000 1G  0x7FFF_FFFF
# ACP_QSPI_LINEAR 0xFC00_0000 16M 0xFCFF_FFFF
# ACP_DDR_LOWOCM  0x0         1G  0x3FFF_FFFF
addr_segment 0xE0000000 4M  ps/S_AXI_ACP/ACP_IOP
addr_segment 0x40000000 1G  ps/S_AXI_ACP/ACP_M_AXI_GP0
addr_segment 0xFC000000 16M ps/S_AXI_ACP/ACP_QSPI_LINEAR
addr_segment 0x00000000 1G  ps/S_AXI_ACP/ACP_DDR_LOWOCM 
