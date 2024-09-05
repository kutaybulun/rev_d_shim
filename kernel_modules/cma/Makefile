obj-m := cma.o
KDIR := $(REV_D_SHIM_DIR)/snickerdoodle_src/build/kernel
PWD := $(shell pwd)
default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
