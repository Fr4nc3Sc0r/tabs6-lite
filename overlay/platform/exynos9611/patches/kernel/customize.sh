# SPDX-License-Identifier: GPL-3.0-or-later
#
# Builds the Exynos 9611 kernel from source and swaps it into the stock boot.img.
# See docs/05-kernel.md for the reasoning behind every choice made here.
#
# Everything can be overridden from the environment:
#   KERNEL_REPO / KERNEL_COMMIT   source tree and exact commit to build
#   KERNEL_DEFCONFIG              defconfig name (default: exynos9611-<codename>_defconfig)
#   KERNEL_CMDLINE_EXTRA          text appended to the boot.img cmdline
#   KERNEL_PREBUILT_IMAGE         path to an already built Image: skips the build
#   KERNEL_JOBS                   make -j value (default: nproc)

# [
KERNEL_REPO="${KERNEL_REPO:-https://github.com/Parbindar7/android_kernel_samsung_universal9611}"
# lineage-24.0 @ 2026-11-12 "AnyKernel3: Add support for Android 17" (Linux 4.14.357)
KERNEL_COMMIT="${KERNEL_COMMIT:-c19ad6b2414e5c110d68ce9cccf1ba95776be317}"
KERNEL_DEFCONFIG="${KERNEL_DEFCONFIG:-exynos9611-${TARGET_CODENAME}_defconfig}"
KERNEL_CMDLINE_EXTRA="${KERNEL_CMDLINE_EXTRA:-}"
KERNEL_PREBUILT_IMAGE="${KERNEL_PREBUILT_IMAGE:-}"
KERNEL_JOBS="${KERNEL_JOBS:-$(nproc)}"

KERNEL_SRC_DIR="$SRC_DIR/out/kernel-cache/universal9611"
KERNEL_OUT_DIR="$SRC_DIR/out/kernel-cache/universal9611-out-$TARGET_CODENAME"
KERNEL_TMP_DIR="$TMP_DIR/exynos9611_kernel"

_KERNEL_FETCH_SOURCE()
{
    if [ ! -d "$KERNEL_SRC_DIR/.git" ]; then
        LOG "- Fetching kernel source ($KERNEL_COMMIT)"
        EVAL "mkdir -p \"$KERNEL_SRC_DIR\"" || return 1
        EVAL "git -C \"$KERNEL_SRC_DIR\" init -q" || return 1
        EVAL "git -C \"$KERNEL_SRC_DIR\" remote add origin \"$KERNEL_REPO\"" || return 1
    fi

    if [[ "$(git -C "$KERNEL_SRC_DIR" rev-parse HEAD 2> /dev/null)" != "$KERNEL_COMMIT" ]]; then
        EVAL "git -C \"$KERNEL_SRC_DIR\" fetch -q --depth 1 origin \"$KERNEL_COMMIT\"" || return 1
        EVAL "git -C \"$KERNEL_SRC_DIR\" checkout -q -f FETCH_HEAD" || return 1
    fi

    # Always start from the pristine pinned commit so patches apply exactly once
    EVAL "git -C \"$KERNEL_SRC_DIR\" reset -q --hard \"$KERNEL_COMMIT\"" || return 1
    EVAL "git -C \"$KERNEL_SRC_DIR\" clean -q -fd" || return 1

    local PATCH
    for PATCH in "$MODPATH"/kernel-patches/*.patch; do
        [ -f "$PATCH" ] || continue
        LOG "- Applying $(basename "$PATCH")"
        EVAL "git -C \"$KERNEL_SRC_DIR\" apply --check \"$PATCH\"" || return 1
        EVAL "git -C \"$KERNEL_SRC_DIR\" apply \"$PATCH\"" || return 1
    done
}

_KERNEL_BUILD()
{
    local MAKE_ARGS="O=\"$KERNEL_OUT_DIR\" ARCH=arm64 LLVM=1 LLVM_IAS=1"
    MAKE_ARGS+=" CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-"

    if [ ! -f "$KERNEL_SRC_DIR/arch/arm64/configs/$KERNEL_DEFCONFIG" ]; then
        ABORT "Kernel defconfig not found: $KERNEL_DEFCONFIG"
        return 1
    fi

    LOG "- Configuring ($KERNEL_DEFCONFIG)"
    EVAL "make -C \"$KERNEL_SRC_DIR\" $MAKE_ARGS \"$KERNEL_DEFCONFIG\"" || return 1

    if [ -f "$MODPATH/config.fragment" ]; then
        LOG "- Merging config.fragment"
        EVAL "\"$KERNEL_SRC_DIR/scripts/kconfig/merge_config.sh\" -m -O \"$KERNEL_OUT_DIR\" \"$KERNEL_OUT_DIR/.config\" \"$MODPATH/config.fragment\"" || return 1
        EVAL "make -C \"$KERNEL_SRC_DIR\" $MAKE_ARGS olddefconfig" || return 1
    fi

    LOG "- Building Image (-j$KERNEL_JOBS), this takes a while"
    EVAL "make -C \"$KERNEL_SRC_DIR\" $MAKE_ARGS -j\"$KERNEL_JOBS\" Image" || return 1

    [ -f "$KERNEL_OUT_DIR/arch/arm64/boot/Image" ] || { ABORT "Kernel Image was not produced"; return 1; }
}

_KERNEL_REPACK_BOOT()
{
    local IMAGE="$1"
    local ARGS
    local VERSION
    local SIZE

    [[ "$(LC_ALL=C file -b "$IMAGE")" == "Linux kernel ARM64"* ]] || { ABORT "Not an ARM64 kernel Image: $IMAGE"; return 1; }
    VERSION="$(strings -n 20 "$IMAGE" | awk '/^Linux version / && !seen { print; seen = 1 }')"
    [[ "$VERSION" == "Linux version 4.14."* ]] || { ABORT "Unexpected kernel version: $VERSION"; return 1; }

    [ -f "$WORK_DIR/kernel/boot.img" ] || { ABORT "$WORK_DIR/kernel/boot.img not found"; return 1; }

    [ -d "$KERNEL_TMP_DIR" ] && rm -rf "$KERNEL_TMP_DIR"
    mkdir -p "$KERNEL_TMP_DIR"

    # Keep the stock header (v2), ramdisk (first stage init + fstab), DTB, offsets and OS patch level
    ARGS="$(unpack_bootimg --boot_img "$WORK_DIR/kernel/boot.img" --out "$KERNEL_TMP_DIR/stock" --format mkbootimg 2>&1)"
    [ -f "$KERNEL_TMP_DIR/stock/kernel" ] || { ABORT "Cannot unpack the stock boot.img\n\n$ARGS"; return 1; }

    EVAL "cp -f \"$IMAGE\" \"$KERNEL_TMP_DIR/stock/kernel\"" || return 1

    if [ "$KERNEL_CMDLINE_EXTRA" ]; then
        LOG "- Appending to the kernel cmdline: $KERNEL_CMDLINE_EXTRA"
        if [[ "$ARGS" == *"--cmdline "* ]]; then
            ARGS="$(sed -E "s|--cmdline '([^']*)'|--cmdline '\1 $KERNEL_CMDLINE_EXTRA'|; s|--cmdline \"([^\"]*)\"|--cmdline \"\1 $KERNEL_CMDLINE_EXTRA\"|" <<< "$ARGS")"
            [[ "$ARGS" == *"$KERNEL_CMDLINE_EXTRA"* ]] || { ABORT "Could not edit the boot.img cmdline, set it by hand"; return 1; }
        else
            ARGS+=" --cmdline '$KERNEL_CMDLINE_EXTRA'"
        fi
    fi

    EVAL "cd \"$KERNEL_TMP_DIR\" && mkbootimg $ARGS -o \"$KERNEL_TMP_DIR/boot.img\"" || { ABORT "mkbootimg failed"; return 1; }

    # Samsung bootloaders expect this trailer on boot/recovery images
    if ${TARGET_BOOT_SEANDROID_MAGIC:-true}; then
        echo -n "SEANDROIDENFORCE" >> "$KERNEL_TMP_DIR/boot.img"
    else
        head -c 16 /dev/zero >> "$KERNEL_TMP_DIR/boot.img"
    fi

    SIZE="$(stat -c %s "$KERNEL_TMP_DIR/boot.img")"
    if [[ "$TARGET_BOOT_PARTITION_SIZE" != "none" ]] && [ "$SIZE" -gt "$TARGET_BOOT_PARTITION_SIZE" ]; then
        ABORT "boot.img is $SIZE bytes, boot partition is $TARGET_BOOT_PARTITION_SIZE bytes"
        return 1
    fi

    EVAL "mv -f \"$KERNEL_TMP_DIR/boot.img\" \"$WORK_DIR/kernel/boot.img\"" || return 1
    rm -rf "$KERNEL_TMP_DIR"

    LOG "- Kernel: ${VERSION%% (*}"
    LOG "- boot.img: $SIZE bytes"
}
# ]

if [ "$KERNEL_PREBUILT_IMAGE" ]; then
    [ -f "$KERNEL_PREBUILT_IMAGE" ] || ABORT "KERNEL_PREBUILT_IMAGE not found: $KERNEL_PREBUILT_IMAGE"
    LOG "- Using prebuilt kernel Image: $KERNEL_PREBUILT_IMAGE"
    _KERNEL_REPACK_BOOT "$KERNEL_PREBUILT_IMAGE" || ABORT "Failed to repack boot.img"
else
    _KERNEL_FETCH_SOURCE || ABORT "Failed to prepare the kernel source"
    _KERNEL_BUILD || ABORT "Kernel build failed"
    _KERNEL_REPACK_BOOT "$KERNEL_OUT_DIR/arch/arm64/boot/Image" || ABORT "Failed to repack boot.img"
fi

unset KERNEL_REPO KERNEL_COMMIT KERNEL_DEFCONFIG KERNEL_CMDLINE_EXTRA KERNEL_PREBUILT_IMAGE KERNEL_JOBS
unset KERNEL_SRC_DIR KERNEL_OUT_DIR KERNEL_TMP_DIR
unset -f _KERNEL_FETCH_SOURCE _KERNEL_BUILD _KERNEL_REPACK_BOOT
