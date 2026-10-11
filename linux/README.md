# Linux for linux_soc (F1C100s) — UART0 terminal

Mainline U-Boot + Linux with the console on **UART0 (ttyS0), 115200 8N1**.

- UART0: `0x01C25000`, PE0/PE1 (func 5) -> J1 P10/P11
- DRAM: 32 MB at `0x80000000`
- SD: MMC0 (`broken-cd` polling), USB: musb OTG+PHY (see `suniv-f1c100s-linux_soc.dts`)
- Kernel cmdline: `console=ttyS0,115200 earlycon=uart,mmio32,0x01c25000`

## Quick start

```bash
./build.sh
# needs: arm-linux-gnueabi-gcc, dtc >= 1.4.6, python3-libfdt, mkimage
# (u-boot-tools), flex, bison, bc, openssl
```

Then write SD (check `/dev/sdX`!):

```bash
sudo dd if=u-boot/u-boot-sunxi-with-spl.bin of=/dev/sdX bs=1024 seek=8
# p1 FAT32: zImage + suniv-f1c100s-linux_soc.dtb + boot.scr
# p2 ext4:  rootfs
```

Console:

```
picocom -b 115200 /dev/ttyUSB0
```

You should see U-Boot SPL, U-Boot, then Linux booting with `console=ttyS0`
and a login prompt on UART0.

## Files

- `suniv-f1c100s-linux_soc.dts` — board device tree (copy into kernel tree by `build.sh`)
- `linux.config.fragment` — ensures 8250_DW serial, console, MMC/USB
- `boot.cmd` — U-Boot script (`mkimage ... -d boot.cmd boot.scr`)
- `build.sh` — clones/builds U-Boot (`licheepi_nano_defconfig`) + Linux
  (`multi_v5_defconfig` + fragment) and makes `boot.scr`

## Notes

- Start from `licheepi_nano_defconfig` (U-Boot) / `multi_v5_defconfig` (kernel):
  both already know F1C100s (suniv) UART0. This board only adds its own DTS
  + cmdline. (`sunxi_defconfig` is MULTI_V7-only and cannot build suniv.)
- If your board wires an SD card-detect pin, replace `broken-cd` in the DTS
  with the real `cd-gpios` (a wrong guess can hang boot).
- For a quick userspace, use Buildroot `licheepi_nano_defconfig` or any armel
  Debian rootfs; make sure `/etc/inittab` (or systemd `serial-getty@ttyS0`)
  spawns a getty on `ttyS0`.
