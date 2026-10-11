#!/bin/bash
# Build mainline U-Boot + Linux for linux_soc (F1C100s) with UART0 console.
# Tested against U-Boot v2024.01+ and Linux v6.6+ (suniv support).
set -e
cd "$(dirname "$0")"

UBOOT_VER=${UBOOT_VER:-v2024.01}
LINUX_VER=${LINUX_VER:-v6.6}
JOBS=${JOBS:-$(nproc)}
CROSS=${CROSS_COMPILE:-arm-linux-gnueabi-}

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1 ($2)"; MISSING=1; }; }
echo "== checking tools =="
need "${CROSS}gcc" "sudo apt install gcc-arm-linux-gnueabi"
need dtc "sudo apt install device-tree-compiler"
need mkimage "sudo apt install u-boot-tools"
need flex "sudo apt install flex"
need bison "sudo apt install bison"
need bc "sudo apt install bc"
need openssl "sudo apt install libssl-dev"
# U-Boot v2024.01 ships a pre-generated pylibfdt wrapper that does not compile
# with SWIG >= 4.3, so the in-tree device-tree build is unusable. Instead we
# build with the system dtc plus the distro's prebuilt python module, which
# skips the in-tree pylibfdt build entirely (see the U-Boot make invocation).
if ! python3 -c "import libfdt" >/dev/null 2>&1; then
  echo "missing: python3 libfdt module (sudo apt install python3-libfdt)"
  MISSING=1
fi
DTC_VER=$(dtc -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
if [ -z "$DTC_VER" ] || [ "$(printf '%s\n%s\n' "1.4.6" "$DTC_VER" | sort -V | head -n1)" != "1.4.6" ]; then
  echo "missing: dtc >= 1.4.6 (sudo apt install device-tree-compiler)"
  MISSING=1
fi
if [ -n "$MISSING" ]; then echo "Install the above, then re-run."; exit 1; fi

if [ ! -d u-boot ]; then
  echo "== cloning U-Boot $UBOOT_VER =="
  git clone --depth 1 --branch "$UBOOT_VER" https://github.com/u-boot/u-boot.git u-boot
fi
if [ ! -d linux ]; then
  echo "== cloning Linux $LINUX_VER =="
  git clone --depth 1 --branch "$LINUX_VER" https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git linux
fi

echo "== installing board DTS =="
# Clean up artifacts from the pre-fix script revision, which targeted the
# old top-level path (Linux >= 5.19 keeps sunxi files in allwinner/).
rm -f linux/arch/arm/boot/dts/suniv-f1c100s-linux_soc.dts
if grep -q "suniv-f1c100s-linux_soc.dtb" linux/arch/arm/boot/dts/Makefile 2>/dev/null; then
  sed -i '/suniv-f1c100s-linux_soc.dtb/d' linux/arch/arm/boot/dts/Makefile
fi
cp -v suniv-f1c100s-linux_soc.dts linux/arch/arm/boot/dts/allwinner/
grep -q "suniv-f1c100s-linux_soc.dtb" linux/arch/arm/boot/dts/allwinner/Makefile \
  || echo 'dtb-$(CONFIG_MACH_SUNIV) += suniv-f1c100s-linux_soc.dtb' >> linux/arch/arm/boot/dts/allwinner/Makefile

echo "== building U-Boot (licheepi_nano_defconfig works for F1C100s UART0) =="
# NOTE: modern U-Boot assembles u-boot-sunxi-with-spl.bin via binman during a
# plain build (see u-boot/doc/board/allwinner/sunxi.rst); there is no such
# make target, so `make u-boot-sunxi-with-spl.bin` fails with "No rule".
(
  cd u-boot
  make CROSS_COMPILE="$CROSS" licheepi_nano_defconfig
  # Binman inserts u-boot's own scripts/dtc/pylibfdt ahead of dist-packages on
  # sys.path, so its stale libfdt.py would shadow the working system module
  # and pair it with a mismatched _libfdt. Hoist the directory holding the
  # tested system module ahead of it (PYTHONPATH lands before those inserts).
  LIBFDT_DIR=$(python3 -c "import libfdt, os; print(os.path.dirname(libfdt.__file__))")
  PYTHONPATH="$LIBFDT_DIR" make CROSS_COMPILE="$CROSS" DTC=dtc -j"$JOBS"
  ls -l u-boot-sunxi-with-spl.bin
)

echo "== building Linux (multi_v5_defconfig + fragment) =="
# NOTE: F1C100s is ARM926EJ-S (ARMv5). sunxi_defconfig is MULTI_V7-only and
# can never enable MACH_SUNIV, so no suniv dtb would build. multi_v5_defconfig
# is the correct mainline base for this SoC.
(
  cd linux
  make ARCH=arm CROSS_COMPILE="$CROSS" multi_v5_defconfig
  ./scripts/kconfig/merge_config.sh -m .config ../linux.config.fragment
  make ARCH=arm CROSS_COMPILE="$CROSS" olddefconfig
  make ARCH=arm CROSS_COMPILE="$CROSS" -j"$JOBS" zImage dtbs modules
  ls -l arch/arm/boot/zImage arch/arm/boot/dts/allwinner/suniv-f1c100s-linux_soc.dtb
)

echo "== building boot.scr =="
mkimage -C none -A arm -T script -d boot.cmd boot.scr
ls -l boot.scr u-boot/u-boot-sunxi-with-spl.bin linux/arch/arm/boot/zImage

cat <<MSG

Done. SD layout (example /dev/sdX, CHECK device!):
  sudo dd if=u-boot/u-boot-sunxi-with-spl.bin of=/dev/sdX bs=1024 seek=8
  # partition 1: FAT32, files: zImage, suniv-f1c100s-linux_soc.dtb, boot.scr
  # partition 2: ext4 rootfs (buildroot/debian armel)
  cp linux/arch/arm/boot/zImage /mnt/boot/
  cp linux/arch/arm/boot/dts/allwinner/suniv-f1c100s-linux_soc.dtb /mnt/boot/
  cp boot.scr /mnt/boot/

Console: UART0 PE0/PE1 -> J1 P10/P11, 115200 8N1:
  picocom -b 115200 /dev/ttyUSB0
Boot log should show U-Boot SPL -> U-Boot -> Linux with:
  [0.000000] Kernel command line: console=ttyS0,115200 ...
  ... then login on ttyS0.
MSG
