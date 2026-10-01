#!/bin/bash
export ARCH=arm64
export RDIR="$(pwd)"
export KBUILD_BUILD_USER="@ravindu644"

#init ksu next
git submodule init && git submodule update

#export toolchain paths
export BUILD_CROSS_COMPILE="${RDIR}/toolchains/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"
export BUILD_CC="${RDIR}/toolchains/clang-r383902/bin/clang"

#output dir
if [ ! -d "${RDIR}/out" ]; then
    mkdir -p "${RDIR}/out"
fi

#build dir
if [ ! -d "${RDIR}/build" ]; then
    mkdir -p "${RDIR}/build"
else
    rm -rf "${RDIR}/build" && mkdir -p "${RDIR}/build"
fi

#build options
export ARGS="
-C $(pwd) \
O=$(pwd)/out \
-j$(nproc) \
ARCH=arm64 \
CROSS_COMPILE=${BUILD_CROSS_COMPILE} \
CC=${BUILD_CC} \
CLANG_TRIPLE=aarch64-linux-gnu- \
KCFLAGS=-w \
CONFIG_SECTION_MISMATCH_WARN_ONLY=y \
"

#build kernel image
build_kernel(){
    make ${ARGS} clean && make ${ARGS} mrproper
    make ${ARGS} a04e_defconfig custom.config
    make ${ARGS} menuconfig
    make ${ARGS} || exit 1
    cp out/arch/arm64/boot/Image.gz $(pwd)/arch/arm64/boot/Image.gz
    echo "[i] Verifying required native A04e kernel options"
    grep -q "^CONFIG_ARCH_MEDIATEK=y$" out/.config
    grep -q "^CONFIG_MACH_MT6765=y$" out/.config
    grep -q "^CONFIG_MODULES=y$" out/.config
    grep -q "^CONFIG_DEVTMPFS=y$" out/.config
    grep -q "^# CONFIG_DEVTMPFS_MOUNT is not set$" out/.config
    make ${ARGS} kernelrelease > "${RDIR}/build/kernel-release.txt"
    KREL="$(cat "${RDIR}/build/kernel-release.txt")"
    rm -rf "${RDIR}/build/modules"
    mkdir -p "${RDIR}/build/modules"
    make ${ARGS} modules_install INSTALL_MOD_PATH="${RDIR}/build/modules" INSTALL_MOD_STRIP=1 DEPMOD=true
    test -d "${RDIR}/build/modules/lib/modules/${KREL}"
    find "${RDIR}/build/modules/lib/modules/${KREL}" -type f -name "*.ko" | grep -q .
}

#build boot.img
build_boot() {    
    rm -f ${RDIR}/AIK-Linux/split_img/boot.img-kernel ${RDIR}/AIK-Linux/boot.img
    cp "${RDIR}/out/arch/arm64/boot/Image.gz" ${RDIR}/AIK-Linux/split_img/boot.img-kernel
    mkdir -p ${RDIR}/AIK-Linux/ramdisk/{debug_ramdisk,dev,metadata,mnt,proc,second_stage_resources,sys}
    cd ${RDIR}/AIK-Linux && ./repackimg.sh --nosudo && mv image-new.img ${RDIR}/build/boot.img
}

#build odin flashable tar
build_tar(){
    cd ${RDIR}/build
    tar -cvf "KernelSU-Next-SM-A042F.tar" boot.img modules kernel-release.txt && rm -rf boot.img modules kernel-release.txt
    echo -e "\n[i] Build Finished..!\n" && cd ${RDIR}
}

build_kernel
build_boot
build_tar
