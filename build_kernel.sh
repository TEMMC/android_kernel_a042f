#!/bin/bash
set -e

export ARCH=arm64
export RDIR="$(cd "$(dirname "$0")" && pwd)"
export KBUILD_BUILD_USER="@ravindu644"
export KBUILD_BUILD_HOST="github-actions"

git submodule update --init --recursive

export BUILD_CROSS_COMPILE="aarch64-linux-gnu-"
export BUILD_CC="clang"

command -v "$BUILD_CC" >/dev/null 2>&1 || { echo "ERROR: clang is not installed"; exit 1; }
command -v "${BUILD_CROSS_COMPILE}gcc" >/dev/null 2>&1 || { echo "ERROR: AArch64 cross GCC is not installed"; exit 1; }

ARGS=(
    -C "$RDIR"
    -j"$(nproc)"
    ARCH=arm64
    CROSS_COMPILE="$BUILD_CROSS_COMPILE"
    CC="$BUILD_CC"
    LD=ld.lld
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    CLANG_TRIPLE=aarch64-linux-gnu-
    KCFLAGS="-w -Wno-error=int-conversion"
    CONFIG_SECTION_MISMATCH_WARN_ONLY=y
)

build_kernel() {
    # Vendor Makefiles require the kernel source tree itself to be clean.
    # Build in-tree instead of using O=out.
    make "${ARGS[@]}" clean
    make "${ARGS[@]}" mrproper
    make "${ARGS[@]}" a04e_defconfig
    "$RDIR/scripts/kconfig/merge_config.sh" -m "$RDIR/.config" "$RDIR/arch/arm64/configs/custom.config"
    make "${ARGS[@]}" olddefconfig
    make "${ARGS[@]}"
    mkdir -p "$RDIR/build"
    cp "$RDIR/arch/arm64/boot/Image.gz" "$RDIR/build/Image.gz"
}

build_boot() {
    rm -f "$RDIR/AIK-Linux/split_img/boot.img-kernel" "$RDIR/AIK-Linux/boot.img"
    cp "$RDIR/build/Image.gz" "$RDIR/AIK-Linux/split_img/boot.img-kernel"
    mkdir -p "$RDIR/AIK-Linux/ramdisk/"{debug_ramdisk,dev,metadata,mnt,proc,second_stage_resources,sys}
    cd "$RDIR/AIK-Linux"
    ./repackimg.sh --nosudo
    mv image-new.img "$RDIR/build/boot.img"
}

build_tar() {
    cd "$RDIR/build"
    tar -cvf "KernelSU-Next-SM-A042F.tar" boot.img
    rm boot.img
    echo -e "\n[i] Build Finished..!\n"
}

build_kernel
build_boot
build_tar
