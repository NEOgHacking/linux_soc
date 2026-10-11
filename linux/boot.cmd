# U-Boot boot script for linux_soc (F1C100s). UART console is ttyS0.
# Build boot.scr with: mkimage -C none -A arm -T script -d boot.cmd boot.scr
setenv bootargs console=ttyS0,115200 earlycon=uart,mmio32,0x01c25000 root=/dev/mmcblk0p2 rootwait rw
load mmc 0:1 0x80600000 zImage
load mmc 0:1 0x80c00000 suniv-f1c100s-linux_soc.dtb
bootz 0x80600000 - 0x80c00000
