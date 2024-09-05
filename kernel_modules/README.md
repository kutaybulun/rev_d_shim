# Kernel modules

To build custom kernel modules, you first need to build the kernel itself. Please refer to the [snickerdoodle_src README](../snickerdoodle_src/README.md) for instructions on how to build the kernel.

Once the kernel is built, you can build the kernel modules by running the following command:

```bash
./build-kernel.sh <MODULE DIRECTORY>
```

Where `<MODULE DIRECTORY>` is the directory containing the module you wish to build. This will build the module to a `.ko` file in the module directory.

To make a new module, create a new directory in the `kernel_modules` directory and add a `Makefile` to build the module. The `Makefile` for `my_module.c` should look something like this:

```make
# Makefile for the my_module kernel module
# This module is built from my_module.c
obj-m += my_module.o

# Nothing needs to be changed from here
PWD := $(shell pwd)
default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
```