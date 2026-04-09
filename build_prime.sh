#!/bin/bash
set -e  # abort on any error

KERNEL_DIR=$(pwd)
DEVICE="$1"

# Toolchain directory (ThankYouMario prebuilts)
TC_DIR="$KERNEL_DIR/clang-tc"
export PATH="$TC_DIR/bin:$PATH"

# Common build variables
BUILD_VAR="-j$(nproc) -C $KERNEL_DIR O=$KERNEL_DIR/out ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- LLVM=1 LLVM_IAS=1"

build_kernel() {
    echo "-----------------------------------------------"
    echo "Beginning kernel compilation for $DEVICE..."
    echo "-----------------------------------------------"

    export ARCH=arm64
    mkdir -p out

    # Merge configs
    cat arch/arm64/configs/vendor/kona-sec-perf_defconfig \
        arch/arm64/configs/vendor/samsung/$DEVICE.config \
        arch/arm64/configs/ksu.config > arch/arm64/configs/temp_defconfig

    # Append custom options
    cat >> arch/arm64/configs/temp_defconfig <<EOF
CONFIG_THINLTO=y
# CONFIG_LTO_NONE is not set
CONFIG_LTO_CLANG=y
# CONFIG_CC_WERROR is not set

CONFIG_LOCALVERSION="-PrimeKernel"
EOF

    make $BUILD_VAR temp_defconfig
    rm arch/arm64/configs/temp_defconfig
}

build_dtb() {
    echo "-----------------------------------------------"
    echo "Building dtb..."
    echo "-----------------------------------------------"
    make $BUILD_VAR
    make $BUILD_VAR dtbs

    cat out/arch/arm64/boot/dts/vendor/qcom/kona.dtb \
        out/arch/arm64/boot/dts/vendor/qcom/kona-v2.dtb \
        out/arch/arm64/boot/dts/vendor/qcom/kona-v2.1.dtb \
        > out/arch/arm64/boot/dts/dtb
}

build_dtbo() {
    echo "-----------------------------------------------"
    echo "Building dtbo.img..."
    echo "-----------------------------------------------"
    DTBO_FILES=$(find out/arch/arm64/boot/dts/samsung/$DEVICE -name "kona-sec-$DEVICE-*.dtbo")
    tools/mkdtimg create out/dtbo.img --page_size=4096 ${DTBO_FILES}
}

prepare_ak3() {
    echo "-----------------------------------------------"
    echo "Packaging with AnyKernel3..."
    echo "-----------------------------------------------"
    cd AnyKernel3/

    mv "$KERNEL_DIR/out/dtbo.img" dtbo.img
    mv "$KERNEL_DIR/out/arch/arm64/boot/Image" Image
    mv "$KERNEL_DIR/out/arch/arm64/boot/dts/dtb" dtb

    sed -i "s/^device\.name1=.*/device.name1=${DEVICE}/" anykernel.sh

    ZIP_NAME="PrimeKernel-${DEVICE}.zip"
    zip -r "../${ZIP_NAME}" *

    cd "$KERNEL_DIR"
}

build_kernel
build_dtb
build_dtbo
prepare_ak3
