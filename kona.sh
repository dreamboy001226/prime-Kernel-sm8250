#!/bin/bash

set -e

KERNEL_DIR=$(pwd)
DEVICE="$1"

# Toolchain setup
TC_DIR="$KERNEL_DIR/tc/clang-r522817"
export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
    echo "AOSP clang not found! Cloning to $TC_DIR..."
    git clone --depth=1 -b 18 https://gitlab.com/ThankYouMario/android_prebuilts_clang-standalone "$TC_DIR"
fi

OUT_DIR="$KERNEL_DIR/out"
BOOT_DIR="$OUT_DIR/arch/arm64/boot"
DTS_DIR="$BOOT_DIR/dts/vendor/qcom"

mkdir -p "$OUT_DIR"

# Build variables
BUILD_VAR="O=$OUT_DIR ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1"

# Generate temp_defconfig
cat arch/arm64/configs/vendor/kona-sec-perf_defconfig \
    arch/arm64/configs/vendor/samsung/$DEVICE.config \
    arch/arm64/configs/ksu.config > arch/arm64/configs/temp_defconfig

cat <<EOF >> arch/arm64/configs/temp_defconfig
CONFIG_THINLTO=y
# CONFIG_LTO_NONE is not set
CONFIG_LTO_CLANG=y
# CONFIG_CC_WERROR is not set

CONFIG_LOCALVERSION="-PrimeKernel"
EOF

make $BUILD_VAR temp_defconfig
make $BUILD_VAR olddefconfig
rm arch/arm64/configs/temp_defconfig

# Build kernel Image
echo "Building kernel Image..."
make -j$(nproc) $BUILD_VAR Image

# Build DTBs
echo "Building DTBs..."
make -j$(nproc) $BUILD_VAR dtbs
cat $(find "$DTS_DIR" -type f -name "*.dtb" | sort) > "$BOOT_DIR/kona.dtb"

# Build DTBO
echo "Building DTBO..."
DTBO_FILES=$(find "$BOOT_DIR/dts/samsung/$DEVICE" -name "kona-sec-$DEVICE-*.dtbo")
"$KERNEL_DIR/tools/mkdtimg" create "$OUT_DIR/dtbo.img" --page_size=4096 ${DTBO_FILES}

# Package with AnyKernel3
echo "Packaging with AnyKernel3..."
rm -rf AnyKernel3
git clone -q -b y2q https://github.com/dreamboy001226/AnyKernel3.git AnyKernel3

cp "$OUT_DIR/dtbo.img" AnyKernel3/dtbo.img
cp "$BOOT_DIR/Image" AnyKernel3/Image
cp "$BOOT_DIR/kona.dtb" AnyKernel3/kona.dtb

cd AnyKernel3
ZIPNAME="PrimeKernel-${DEVICE}-$(date '+%Y%m%d')-$(git rev-parse --short HEAD).zip"
zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
cd ..

echo "Build complete!"
echo "Output zip: $ZIPNAME"
