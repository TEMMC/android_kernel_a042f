#!/bin/bash
set -euo pipefail

export ARCH=arm64
export RDIR="$(pwd)"
export KBUILD_BUILD_USER="TEMMC"
export KBUILD_BUILD_HOST="github-actions"

CROSS_COMPILE="aarch64-linux-gnu-"
CC_BIN="$(command -v clang)"
LD_BIN="$(command -v ld.lld)"
OUT="${RDIR}/out"
BUILD="${RDIR}/build"
AIK="${RDIR}/AIK-Linux"

command -v "${CROSS_COMPILE}gcc" >/dev/null
test -x "${CC_BIN}"
test -x "${LD_BIN}"
test -x "$AIK/repackimg.sh"
test -f "$AIK/split_img/boot.img-dtb"
test -f "$AIK/split_img/boot.img-ramdisk.cpio.gz"

# Repair accidental patch-marker prefixes in imported vendor Kconfig files.
find "$RDIR" -type f -name Kconfig -not -path "$RDIR/.git/*" -print0 |
  xargs -0 -r sed -i -e 's/^+//' -e "/^'$/d"

mkdir -p "$OUT" "$BUILD"

# Set compiler variables even during defconfig: this kernel's Kconfig probes CC.
MAKE_ARGS=(
  -C "$RDIR" O="$OUT" ARCH=arm64
  CROSS_COMPILE="$CROSS_COMPILE"
  CC="$CC_BIN"
  LD="$LD_BIN"
  CLANG_TRIPLE=aarch64-linux-gnu-
  KCFLAGS=-w
  CONFIG_SECTION_MISMATCH_WARN_ONLY=y
)

make "${MAKE_ARGS[@]}" a04e_defconfig

if [ -f "${RDIR}/arch/arm64/configs/custom.config" ]; then
  bash "$RDIR/scripts/kconfig/merge_config.sh" -m -O "$OUT" \
    "$OUT/.config" "${RDIR}/arch/arm64/configs/custom.config"
fi

make "${MAKE_ARGS[@]}" olddefconfig

# Fail early if required native-root and dynamic-partition support did not survive Kconfig.
for required in CONFIG_BLK_DEV_INITRD=y CONFIG_DEVTMPFS=y CONFIG_DEVTMPFS_MOUNT=y CONFIG_EXT4_FS=y CONFIG_BLK_DEV_DM=y; do
  grep -qx "$required" "$OUT/.config" || {
    echo "ERROR: required kernel option missing after olddefconfig: $required" >&2
    exit 1
  }
done

make "${MAKE_ARGS[@]}" -j"$(nproc)"

KERNEL_IMAGE="$OUT/arch/arm64/boot/Image.gz"
test -s "$KERNEL_IMAGE"

# Preserve the A04e boot header, DTB, ramdisk and offsets; replace only the kernel.
cp "$KERNEL_IMAGE" "$AIK/split_img/boot.img-kernel"
(
  cd "$AIK"
  ./repackimg.sh --nosudo
  test -s image-new.img
  install -m 0644 image-new.img "$BUILD/A04e-postmarketOS-boot.img"
)

(
  cd "$BUILD"
  tar -cf A04e-postmarketOS-boot.tar A04e-postmarketOS-boot.img
  sha256sum A04e-postmarketOS-boot.img A04e-postmarketOS-boot.tar > SHA256SUMS
)
test -s "$BUILD/A04e-postmarketOS-boot.img"
test -s "$BUILD/A04e-postmarketOS-boot.tar"
echo "Built boot image: $BUILD/A04e-postmarketOS-boot.img"
