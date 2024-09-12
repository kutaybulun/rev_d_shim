[![DOI](https://zenodo.org/badge/28404370.svg)](https://zenodo.org/badge/latestdoi/28404370)

# Red Pitaya Notes

Notes on the Red Pitaya Open Source Instrument

http://pavel-demin.github.io/red-pitaya-notes/


# Rev D Shim

## Directory Structure

The modified organization of this repository is as follows:
```
rev_d_shim/
├── kernel_modules/ # Custom kernel modules
│   ├── README.md # Instructions on building kernel modules
│   ├── cma/ # CMA kernel module, useful example
├── snickerdoodle_src/ # Snickerdoodle Linux kernel source
│   ├── README.md # Instructions on building the Snickerdoodle kernel
│   ├── rev-d-shim-snickerdoodle-dts/ # Device tree source for the Rev D shim [submodule]
│   ├── rev-d-shim-snickerdoodle-linux/ # Linux kernel source with Rev D shim support [submodule]
│   ├── rev-d-shim-snickerdoodle-uboot/ # UBoot source with Rev D shim support [submodule]
├── README.md # This file
```