#!/bin/bash
#
# Kernel build script for GitHub Actions (Xiaomi-style uname)
#

set -e

clean=false
local=false
suonly=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--clean) clean=true; shift ;;
    -l|--local) local=true; shift ;;
    -su|--su-only) suonly=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SECONDS=0

if [ "$local" = true ]; then
  ZIPNAME="[AOSP]-Spiteful-sweet-$(date '+%Y%m%d-%H%M').zip"
else
  ZIPNAME="[AOSP]-Spiteful-sweet-$(date '+%Y%m%d').zip"
fi

# Kernel build config
export ARCH=arm64
export KBUILD_BUILD_USER="builder"
export KBUILD_BUILD_HOST="xiaomi"
export KBUILD_BUILD_VERSION="1"
export KBUILD_BUILD_TIMESTAMP="$(date +"%a %b %d %H:%M:%S CST %Y")"

echo "-perf+" > localversion

# Clone clang if not available
if [ ! -d "$PWD/clang" ]; then
  git clone https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git --depth=1 -b 15.0 clang
else
  echo "Using existing clang directory."
fi

export PATH="$PWD/clang/bin:$PATH"
export KBUILD_COMPILER_STRING="$($PWD/clang/bin/clang --version | head -n 1)"

if [ "$clean" = true ]; then
  rm -rf out
  echo "Output folder cleaned."
fi

echo -e "\n===== Starting Kernel Compilation =====\n"
make O=out ARCH=arm64 sweet_defconfig
make -j$(nproc --all) \
  O=out \
  ARCH=arm64 \
  LLVM=1 \
  LLVM_IAS=1 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
dtb="out/arch/arm64/boot/dtb.img"

if [ ! -f "$kernel" ] || [ ! -f "$dtbo" ] || [ ! -f "$dtb" ]; then
  echo "❌ Compilation failed!"
  exit 1
fi

echo -e "\nKernel compiled successfully! Zipping...\n"

# Clone AnyKernel3 if not exists
if [ -d "$AK3_DIR" ]; then
  cp -r $AK3_DIR AnyKernel3
else
  git clone https://github.com/basamaryan/AnyKernel3.git -b master AnyKernel3
fi

# Edit AnyKernel3 info
sed -i "s/kernel\.string=.*/kernel.string=Spiteful Kernel (sweet)/" AnyKernel3/anykernel.sh
sed -i "s/supported\.versions=.*/supported.versions=11-16/" AnyKernel3/anykernel.sh

# Copy kernel outputs
cp $kernel AnyKernel3/
cp $dtbo AnyKernel3/
cp $dtb AnyKernel3/

cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git README.md
cd ..

echo -e "\n✅ Build completed in $((SECONDS / 60))m $((SECONDS % 60))s"
echo "📦 Output: $ZIPNAME"
