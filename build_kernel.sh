#!/bin/bash
set -euo pipefail

export ARCH=arm64
export RDIR="$(pwd)"
export KBUILD_BUILD_USER="TEMMC"
export KBUILD_BUILD_HOST="github-actions"

BUILD_CROSS_COMPILE="${RDIR}/toolchains/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"
BUILD_CC="${RDIR}/toolchains/clang-r383902/bin/clang"
OUT="${RDIR}/out"
BUILD="${RDIR}/build"
AIK="${RDIR}/AIK-Linux"

for tool in "${BUILD_CROSS_COMPILE}gcc" "$BUILD_CC"; do
    if [ ! -x "$tool" ]; then
        echo "ERROR: required compiler not found or not executable: $tool" >&2
        echo "Confirm the toolchains are present in this branch and checked out by GitHub Actions." >&2
        exit 1
    fi
done

mkdir -p "$OUT" "$BUILD"

# Use the device defconfig and optional fragment; never open interactive menuconfig in CI.
make -C "$RDIR" O="$OUT" ARCH=arm64 a04e_defconfig
if [ -f "${RDIR}/custom.config" ]; then
    bash "${RDIR}/scripts/kconfig/merge_config.sh" -m -O "$OUT" "$OUT/.config" "${RDIR}/custom.config"
fi

make -C "$RDIR" O="$OUT" ARCH=arm64 \
    CROSS_COMPILE="$BUILD_CROSS_COMPILE" \
    CC="$BUILD_CC" CLANG_TRIPLE=aarch64-linux-gnu- \
    KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y olddefconfig

make -C "$RDIR" O="$OUT" -j"$(nproc)" ARCH=arm64 \
    CROSS_COMPILE="$BUILD_CROSS_COMPILE" \
    CC="$BUILD_CC" CLANG_TRIPLE=aarch64-linux-gnu- \
    KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y

KERNEL_IMAGE="$OUT/arch/arm64/boot/Image.gz"
test -s "$KERNEL_IMAGE"
test -x "$AIK/repackimg.sh"
test -f "$AIK/split_img/boot.img-kernel"

# Repack the kernel using the existing A04e boot layout and ramdisk in AIK-Linux.
cp "$KERNEL_IMAGE" "$AIK/split_img/boot.img-kernel"
mkdir -p "$AIK/ramdisk/debug_ramdisk" "$AIK/ramdisk/dev" "$AIK/ramdisk/metadata" \
    "$AIK/ramdisk/mnt" "$AIK/ramdisk/proc" "$AIK/ramdisk/second_stage_resources" "$AIK/ramdisk/sys"
(
    cd "$AIK"
    ./repackimg.sh --nosudo
    test -s image-new.img
    mv image-new.img "$BUILD/boot.img"
)

(
    cd "$BUILD"
    tar -cf KernelSU-Next-SM-A042F.tar boot.img
)
test -s "$BUILD/KernelSU-Next-SM-A042F.tar"
echo "Build complete: $BUILD/KernelSU-Next-SM-A042F.tar"
