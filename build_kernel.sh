#!/bin/bash
set -euo pipefail

export ARCH=arm64
export RDIR="$(pwd)"
export KBUILD_BUILD_USER="TEMMC"
export KBUILD_BUILD_HOST="github-actions"

# Use the cross compiler and LLVM packages installed by the workflow.
BUILD_CROSS_COMPILE="aarch64-linux-gnu-"
BUILD_CC="$(command -v clang)"
OUT="${RDIR}/out"
BUILD="${RDIR}/build"
AIK="${RDIR}/AIK-Linux"

command -v "${BUILD_CROSS_COMPILE}gcc" >/dev/null
command -v "${BUILD_CC}" >/dev/null
command -v ld.lld >/dev/null
test -x "$AIK/repackimg.sh"
test -f "$AIK/split_img/boot.img-dtb"
test -f "$AIK/split_img/boot.img-ramdisk.cpio.gz"

# The imported vendor tree contains Kconfig files with patch-marker '+' prefixes
# and stray quote-only lines. Clean these in the runner checkout before Kconfig.
find "$RDIR" -type f -name Kconfig \
  -not -path "$RDIR/.git/*" -print0 |
  xargs -0 -r sed -i -e 's/^+//' -e "/^'$/d"

mkdir -p "$OUT" "$BUILD"

# Use the A04e MT6765 configuration; never open interactive menuconfig in CI.
make -C "$RDIR" O="$OUT" ARCH=arm64 a04e_defconfig
if [ -f "${RDIR}/arch/arm64/configs/custom.config" ]; then
    bash "$RDIR/scripts/kconfig/merge_config.sh" -m -O "$OUT" \
      "$OUT/.config" "${RDIR}/arch/arm64/configs/custom.config"
fi

make -C "$RDIR" O="$OUT" ARCH=arm64 \
    CROSS_COMPILE="$BUILD_CROSS_COMPILE" \
    CC="$BUILD_CC" LD=ld.lld CLANG_TRIPLE=aarch64-linux-gnu- \
    KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y olddefconfig

make -C "$RDIR" O="$OUT" -j"$(nproc)" ARCH=arm64 \
    CROSS_COMPILE="$BUILD_CROSS_COMPILE" \
    CC="$BUILD_CC" LD=ld.lld CLANG_TRIPLE=aarch64-linux-gnu- \
    KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y

KERNEL_IMAGE="$OUT/arch/arm64/boot/Image.gz"
test -s "$KERNEL_IMAGE"

# AIK's extracted source boot image deliberately omits the kernel blob from Git.
# Supply the newly compiled kernel and preserve the A04e boot header, DTB and ramdisk.
cp "$KERNEL_IMAGE" "$AIK/split_img/boot.img-kernel"
(
    cd "$AIK"
    ./repackimg.sh --nosudo
    test -s image-new.img
    install -m 0644 image-new.img "$BUILD/A04e-postmarketOS-boot.img"
)

# Keep a raw boot image for direct use and a tar archive for the existing workflow.
(
    cd "$BUILD"
    tar -cf A04e-postmarketOS-boot.tar A04e-postmarketOS-boot.img
    sha256sum A04e-postmarketOS-boot.img A04e-postmarketOS-boot.tar > SHA256SUMS
)
test -s "$BUILD/A04e-postmarketOS-boot.img"
test -s "$BUILD/A04e-postmarketOS-boot.tar"
echo "Built boot image: $BUILD/A04e-postmarketOS-boot.img"
