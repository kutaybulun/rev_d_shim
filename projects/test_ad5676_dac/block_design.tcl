###############################################################################
#
#   Single-ended ports
#
###############################################################################


#------------------------------------------------------------
# Inputs
#------------------------------------------------------------

# (Shutdown_Sense)
create_bd_port -dir I -type data Shutdown_Sense
# (Trigger_In)
create_bd_port -dir I Trigger_In


#------------------------------------------------------------
# Outputs
#------------------------------------------------------------

# (Shutdown_Sense_Sel0-2)
create_bd_port -dir O -from 2 -to 0 -type data Shutdown_Sense_Sel
# (~Shutdown_Force)
create_bd_port -dir O n_Shutdown_Force
# (~Shutdown_Reset)
create_bd_port -dir O n_Shutdown_Reset



###############################################################################
#
#   Differential ports
#
###############################################################################


#------------------------------------------------------------
# DAC
#------------------------------------------------------------

# (LDAC+)
create_bd_port -dir O -from 0 -to 0 -type data LDAC_p
# (LDAC-)
create_bd_port -dir O -from 0 -to 0 -type data LDAC_n
# (~DAC_CS+)
create_bd_port -dir O -from 7 -to 0 -type data n_DAC_CS_p
# (~DAC_CS-)
create_bd_port -dir O -from 7 -to 0 -type data n_DAC_CS_n
# (DAC_MOSI+)
create_bd_port -dir O -from 7 -to 0 -type data DAC_MOSI_p
# (DAC_MOSI-)
create_bd_port -dir O -from 7 -to 0 -type data DAC_MOSI_n
# (DAC_MISO+)
create_bd_port -dir I -from 7 -to 0 -type data DAC_MISO_p
# (DAC_MISO-)
create_bd_port -dir I -from 7 -to 0 -type data DAC_MISO_n


#------------------------------------------------------------
# ADC
#------------------------------------------------------------

# (~ADC_CS+)
create_bd_port -dir O -from 7 -to 0 -type data n_ADC_CS_p
# (~ADC_CS-)
create_bd_port -dir O -from 7 -to 0 -type data n_ADC_CS_n
# (ADC_MOSI+)
create_bd_port -dir O -from 7 -to 0 -type data ADC_MOSI_p
# (ADC_MOSI-)
create_bd_port -dir O -from 7 -to 0 -type data ADC_MOSI_n
# (ADC_MISO+)
create_bd_port -dir I -from 7 -to 0 -type data ADC_MISO_p
# (ADC_MISO-)
create_bd_port -dir I -from 7 -to 0 -type data ADC_MISO_n


#------------------------------------------------------------
# Clocks
#------------------------------------------------------------

# (SCKO+)
create_bd_port -dir I -from 7 -to 0 MISO_SCK_p
# (SCKO-)
create_bd_port -dir I -from 7 -to 0 MISO_SCK_n
# (~SCKI+)
create_bd_port -dir O -from 0 -to 0 n_MOSI_SCK_p
# (~SCKI-)
create_bd_port -dir O -from 0 -to 0 n_MOSI_SCK_n


###############################################################################

### 0 and 1 constants to fill bits for unused boards
cell xilinx.com:ip:xlconstant:1.1 const_0 {
  CONST_VAL 0
} {}
cell xilinx.com:ip:xlconstant:1.1 const_1 {
  CONST_VAL 1
} {}

###############################################################################

### Create processing system
# Enable M_AXI_GP0 and M_AXI_GP1
# Enable UART1 on the correct MIO pins
# UART1 baud rate 921600
# Pullup for UART1 RX
# Set FCLK0 to 150 MHz
# Turn off FCLK1-3 and reset1-3
init_ps ps {
  PCW_USE_M_AXI_GP0 1
  PCW_USE_M_AXI_GP1 1
  PCW_USE_S_AXI_ACP 0
  PCW_UART1_PERIPHERAL_ENABLE 1
  PCW_UART1_UART1_IO {MIO 36 .. 37}
  PCW_UART1_BAUD_RATE 921600
  PCW_MIO_37_PULLUP enabled
  PCW_FPGA0_PERIPHERAL_FREQMHZ 100
  PCW_EN_CLK1_PORT 0
  PCW_EN_CLK2_PORT 0
  PCW_EN_CLK3_PORT 0
  PCW_EN_RST1_PORT 0
  PCW_EN_RST2_PORT 0
  PCW_EN_RST3_PORT 0
} {
  M_AXI_GP0_ACLK ps/FCLK_CLK0
  M_AXI_GP1_ACLK ps/FCLK_CLK0
}

## PS clock reset core
# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 ps_rst {} {
  ext_reset_in ps/FCLK_RESET0_N
  slowest_sync_clk ps/FCLK_CLK0
}

# ### AXI Smart Connects
# # System config and control interconnect
# cell xilinx.com:ip:smartconnect:1.0 sys_cfg_axi_intercon {
#   NUM_SI 1
#   NUM_MI 2
# } {
#   aclk ps/FCLK_CLK0
#   S00_AXI ps/M_AXI_GP0
#   aresetn ps_rst/peripheral_aresetn
# }
# # DAC SPI interconnect
# cell xilinx.com:ip:smartconnect:1.0 dac_spi_intercon {
#   NUM_SI 1
#   NUM_MI 8
# } {
#   aclk ps/FCLK_CLK0
#   S00_AXI ps/M_AXI_GP1
#   aresetn ps_rst/peripheral_aresetn
# }

###############################################################################

## Fixed 50 MHz SPI clock
cell xilinx.com:ip:clk_wiz:6.0 spi_clk {
  PRIMITIVE MMCM
  PRIM_SOURCE Single_ended_clock_capable_pin
  PRIM_IN_FREQ.VALUE_SRC USER
  PRIM_IN_FREQ 99.999893
  MMCM_REF_JITTER1 0.0005
  CLKOUT1_USED true
  CLKOUT1_REQUESTED_OUT_FREQ 50.0
  CLKOUT2_USED false
  USE_PHASE_ALIGNMENT true
  JITTER_SEL Min_O_Jitter
  JITTER_OPTIONS PS
  USE_DYN_RECONFIG false
} {
  clk_in1 ps/FCLK_CLK0
}


###############################################################################

### Create I/O buffers for differential signals
module io_buffers io_buffers {
  n_mosi_sck spi_clk/clk_out1
  ldac_p LDAC_p
  ldac_n LDAC_n
  n_dac_cs_p n_DAC_CS_p
  n_dac_cs_n n_DAC_CS_n
  dac_mosi_p DAC_MOSI_p
  dac_mosi_n DAC_MOSI_n
  dac_miso_p DAC_MISO_p
  dac_miso_n DAC_MISO_n
  n_adc_cs_p n_ADC_CS_p
  n_adc_cs_n n_ADC_CS_n
  adc_mosi_p ADC_MOSI_p
  adc_mosi_n ADC_MOSI_n
  adc_miso_p ADC_MISO_p
  adc_miso_n ADC_MISO_n
  miso_sck_p MISO_SCK_p
  miso_sck_n MISO_SCK_n
  n_mosi_sck_p n_MOSI_SCK_p
  n_mosi_sck_n n_MOSI_SCK_n
}

###############################################################################
