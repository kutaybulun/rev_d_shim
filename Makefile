#############################################
## Variables
#############################################

# You need to set PROJECT and BOARD to the project and board you want to build
# These can be set on the command line:
# - e.g. 'make PROJECT=example_axi_hub_regs BOARD=snickerdoodle_black'

# Default values for PROJECT and BOARD
PROJECT ?= example_axi_hub_regs
BOARD ?= snickerdoodle_black


#############################################
## Initialization
#############################################

# Run some checks and setup, but only if there are targets other than clean or cleanall
ifneq ($(),$(filter-out clean cleanall,$(MAKECMDGOALS))) # Clean check

# Check that the project and board exist, and that the necessary files are present
ifeq ($(),$(wildcard boards/$(BOARD)/board_config.json))
$(error Board "$(BOARD)" or the corresponding board configuration file "boards/$(BOARD)/board_config.json" does not exist)
endif
ifeq ($(),$(wildcard projects/$(PROJECT)))
$(error Project "$(PROJECT)" does not exist)
endif
ifeq ($(),$(wildcard projects/$(PROJECT)/block_design.tcl))
$(error Project "$(PROJECT)" does not have a block design file "projects/$(PROJECT)/block_design.tcl")
endif
ifeq ($(),$(wildcard projects/$(PROJECT)/ports.tcl))
$(error Project "$(PROJECT)" does not have a ports file "projects/$(PROJECT)/ports.tcl")
endif
ifeq ($(),$(wildcard projects/$(PROJECT)/$(BOARD)_xdc))
$(error No support for board "$(BOARD)" in project "$(PROJECT)" -- design constraints folder "projects/$(PROJECT)/$(BOARD)_xdc" does not exist)
endif

# Extract the part and processor from the board configuration file
export PART=$(shell jq -r '.part' boards/$(BOARD)/board_config.json)
export PROC=$(shell jq -r '.proc' boards/$(BOARD)/board_config.json)

# Get the list of cores from the project file
PROJECT_CORES = $(shell ./scripts/get_cores_from_tcl.sh projects/$(PROJECT)/block_design.tcl)

endif # Clean check

# Set up commands
VIVADO = vivado -nolog -nojournal -mode batch
XSCT = xsct
RM = rm -rf

# Files not to delete on half-completion (.PRECIOUS is a special target that tells make not to delete these files)
.PRECIOUS: tmp/cores/% tmp/%.xpr tmp/%.bit

# Targets that aren't real files
.PHONY: all clean cleanall bit rootfs boot cores xpr xsa

#############################################



#############################################
## Generic and clean targets
#############################################
# Default target is just the bitstream
all: bit

# Remove the intermediate and temporary files
clean:
	$(RM) .Xil
	$(RM) tmp

# Remove the output files too
cleanall: clean
	$(RM) out

#############################################


#############################################
## Output targets
#############################################

# The bitstream file
bit: tmp/$(BOARD)_$(PROJECT).bit
	mkdir -p out/$(BOARD)/$(PROJECT)
	cp tmp/$(BOARD)_$(PROJECT).bit out/$(BOARD)/$(PROJECT)/system.bit

# The compressed root filesystem
rootfs: tmp/$(BOARD)_$(PROJECT)_petalinux/images/linux/rootfs.tar.gz
	mkdir -p out/$(BOARD)/$(PROJECT)
	cp tmp/$(BOARD)_$(PROJECT)_petalinux/images/linux/rootfs.tar.gz out/$(BOARD)/$(PROJECT)/rootfs.tar.gz

# The boot binary
boot: tmp/$(BOARD)_$(PROJECT).bit tmp/$(BOARD)_$(PROJECT)_petalinux/images/linux/rootfs.tar.gz
	mkdir -p out/$(BOARD)/$(PROJECT)
	$(info --------------------------)
	$(info ---- PACKAGING BOOT.BIN)
	$(info --------------------------)
	cd tmp/$(BOARD)_$(PROJECT)_petalinux && \
	source $(PETALINUX_PATH)/settings.sh && \
	petalinux-package boot \
	--format BIN \
	--fsbl \
	--u-boot \
	--kernel \
	--boot-script \
	--dtb \
	--boot-device sd \
	--force
	cp tmp/$(BOARD)_$(PROJECT)_petalinux/images/linux/BOOT.BIN out/$(BOARD)/$(PROJECT)/BOOT.BIN

# --fpga ../$(BOARD)_$(PROJECT).bit \

#############################################


#############################################
## Intermediate targets
#############################################

# All the cores necessary for the project
cores: $(addprefix tmp/cores/, $(PROJECT_CORES))

# The Xilinx project file
xpr: tmp/$(BOARD)_$(PROJECT).xpr

# The hardware definition file
xsa: tmp/$(BOARD)_$(PROJECT).xsa

#############################################



#############################################
## Specific targets
#############################################

# Cores are built using the scripts/package_core.tcl script
tmp/cores/%: cores/%.v
	$(info --------------------------)
	$(info ---- MAKING CORE: $*)
	$(info --------------------------)
	mkdir -p $(@D)
	$(VIVADO) -source scripts/package_core.tcl -tclargs $* $(PART)

# The project file 
# Requires all the cores
# Built using the scripts/project.tcl script
tmp/$(BOARD)_$(PROJECT).xpr: projects/$(PROJECT) $(addprefix tmp/cores/, $(PROJECT_CORES))
	$(info --------------------------)
	$(info ---- MAKING PROJECT: $(BOARD)_$(PROJECT).xpr)
	$(info --------------------------)
	mkdir -p $(@D)
	$(VIVADO) -source scripts/project.tcl -tclargs $(BOARD) $(PROJECT)

# The bitstream file
# Requires the project file
# Built using the scripts/bitstream.tcl script
tmp/$(BOARD)_$(PROJECT).bit: tmp/$(BOARD)_$(PROJECT).xpr
	$(info --------------------------)
	$(info ---- MAKING BITSTREAM: $(BOARD)_$(PROJECT).bit)
	$(info --------------------------)
	$(VIVADO) -source scripts/bitstream.tcl -tclargs $(BOARD)_$(PROJECT)

# The hardware definition file
# Requires the project file
# Built using the scripts/hw_def.tcl script
tmp/$(BOARD)_$(PROJECT).xsa: tmp/$(BOARD)_$(PROJECT).xpr
	$(info --------------------------)
	$(info ---- MAKING HW DEF: $(BOARD)_$(PROJECT).xsa)
	$(info --------------------------)
	$(VIVADO) -source scripts/hw_def.tcl -tclargs $(BOARD)_$(PROJECT)

# The compressed root filesystem
# Requires the hardware definition file
# Build using the scripts/petalinux.sh file
tmp/$(BOARD)_$(PROJECT)_petalinux/images/linux/rootfs.tar.gz: tmp/$(BOARD)_$(PROJECT).xsa
	$(info --------------------------)
	$(info ---- MAKING LINUX SYSTEM: $(BOARD)_$(PROJECT)_petalinux)
	$(info --------------------------)
	source $(PETALINUX_PATH)/settings.sh && \
	scripts/petalinux.sh $(BOARD) $(PROJECT)

