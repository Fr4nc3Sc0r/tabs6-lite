#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Builds only the kernel Image, outside of the ROM build system. Uses exactly
# the same source commit, patches and config fragment as the ROM build
# (overlay/platform/exynos9611/patches/kernel/customize.sh is the single source
# of truth for KERNEL_REPO and KERNEL_COMMIT).
#
# Usage: tools/build_kernel.sh <output dir> [codename]
#   The Image can then be used in a ROM build with KERNEL_PREBUILT_IMAGE=<path>.

set -euo pipefail

OUT="${1:?Usage: build_kernel.sh <output dir> [codename]}"
CODENAME="${2:-gta4xlwifi}"
MOD="$(cd "$(dirname "${BASH_SOURCE[0]}")/../overlay/platform/exynos9611/patches/kernel" && pwd)"

REPO="${KERNEL_REPO:-$(grep -m 1 '^KERNEL_REPO=' "$MOD/customize.sh" | sed -E 's/.*:-([^}]*)\}.*/\1/')}"
COMMIT="${KERNEL_COMMIT:-$(grep -m 1 '^KERNEL_COMMIT=' "$MOD/customize.sh" | sed -E 's/.*:-([^}]*)\}.*/\1/')}"
DEFCONFIG="exynos9611-${CODENAME}_defconfig"

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
SRC="$OUT/src"
BUILD="$OUT/build"

if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$SRC"
    git -C "$SRC" init -q
    git -C "$SRC" remote add origin "$REPO"
fi
git -C "$SRC" fetch -q --depth 1 origin "$COMMIT"
git -C "$SRC" checkout -q -f FETCH_HEAD
git -C "$SRC" reset -q --hard "$COMMIT"
git -C "$SRC" clean -q -fd

for p in "$MOD"/kernel-patches/*.patch; do
    [ -f "$p" ] || continue
    echo "- Applying $(basename "$p")"
    git -C "$SRC" apply --check "$p"
    git -C "$SRC" apply "$p"
done

MAKE=(make -C "$SRC" O="$BUILD" ARCH=arm64 LLVM=1 LLVM_IAS=1
      CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-)

"${MAKE[@]}" "$DEFCONFIG"
if [ -f "$MOD/config.fragment" ]; then
    "$SRC/scripts/kconfig/merge_config.sh" -m -O "$BUILD" "$BUILD/.config" "$MOD/config.fragment"
    "${MAKE[@]}" olddefconfig
fi
"${MAKE[@]}" -j"$(nproc)" Image

cp -f "$BUILD/arch/arm64/boot/Image" "$OUT/Image"
cp -f "$BUILD/.config" "$OUT/config"
# awk reads the whole stream: "grep -m 1" would close the pipe early and, with
# pipefail, turn a successful build into exit status 141 (SIGPIPE)
strings -n 20 "$OUT/Image" | awk '/^Linux version / && !seen { print; seen = 1 }' | tee "$OUT/version.txt"
echo "Image: $OUT/Image ($(stat -c %s "$OUT/Image") bytes)"
