-include shim_hw_manager_test_setup.txt
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES += $(PWD)/../shim_hw_manager.v

# Default values for shim_hw_manager parameters
SHUTDOWN_FORCE_DELAY ?= 25000000
SHUTDOWN_RESET_PULSE  ?= 25000
SHUTDOWN_RESET_DELAY  ?= 25000000
SPI_INIT_WAIT         ?= 25000000
SPI_START_WAIT        ?= 250000000 

# Enable waveform dumping for Verilator, ignore warnings and set parameters for DUT, read from shim_hw_manager_test_setup.txt
# If the file does not exist, use default values
EXTRA_ARGS += --trace --trace-structs -Wno-fatal --timing \
	-pvalue+SHUTDOWN_FORCE_DELAY=$(SHUTDOWN_FORCE_DELAY) \
	-pvalue+SHUTDOWN_RESET_PULSE=$(SHUTDOWN_RESET_PULSE) \
	-pvalue+SHUTDOWN_RESET_DELAY=$(SHUTDOWN_RESET_DELAY) \
	-pvalue+SPI_INIT_WAIT=$(SPI_INIT_WAIT) \
	-pvalue+SPI_START_WAIT=$(SPI_START_WAIT)

shim_hw_manager_test:
	$(MAKE) sim MODULE=shim_hw_manager_test TOPLEVEL=shim_hw_manager

clean_test:
	rm -rf __pycache__ results.xml sim_build dump.vcd shim_hw_manager_coverage.xml shim_hw_manager_coverage.yaml

include $(shell cocotb-config --makefiles)/Makefile.sim