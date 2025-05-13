# Example FCLK Control Project

This project demonstrates how to control the FCLK clock on a Zynq device through software. The project includes a block design that sets up the necessary hardware components and a C code example that demonstrates how to control the FCLK clock.

## Block Design

The block design (`block_design.tcl`) is simply the initialization of the processing system with the AXI interfaces disabled and the FCLK0 clock connected to an external port.

## C Code

The C code (`fclk_control.c`) demonstrates how to control the FCLK clock through software by writing to the relevant System Level Control Register (SLCR). After mapping the correct address, an unlock code needs to be sent to enable control of the FCLK frequency dividers. The software then lets you adjust the two dividers for the FCLK frequency generation, which can be 1-63.

## PetaLinux

The default configuration is changed to make the packaged image EXT4 format to load from an SD card.

