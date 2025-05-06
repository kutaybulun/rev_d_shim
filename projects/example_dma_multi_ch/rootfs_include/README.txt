Initialize the u-dma-buf kernel module with the following command
Creates two dma buffers of 2^20 bytes
Can create up to 8 buffers [0-7]

insmod u-dma-buf.ko udmabuf0=1048576 udmabuf1=1048576

It can be removed with the following command

rmmod u-dma-buf
