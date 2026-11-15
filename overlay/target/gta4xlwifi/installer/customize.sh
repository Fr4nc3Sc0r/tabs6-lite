# SPDX-License-Identifier: GPL-3.0-or-later
#
# Runs while the flashable zip is being assembled ($TMP_DIR is the zip root).
#
# Ships the stock vbmeta.img with both "disable" flags set (byte 123 = 0x03,
# the same edit `fastboot --disable-verity --disable-verification` makes; the
# base produces it as avb/vbmeta_patched.img while extracting the firmware).
# The stock vendor fstab asks first stage init to verify system/vendor/product
# against vbmeta: with the flags set and the bootloader unlocked that check is
# skipped, which is required because the logical partitions are rebuilt.

VBMETA="$FW_DIR/$(cut -d "/" -f 1 <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 <<< "$TARGET_FIRMWARE")/avb/vbmeta_patched.img"

if [ ! -f "$VBMETA" ]; then
    LOGE "File not found: ${VBMETA//$SRC_DIR\//} (re-run extract_fw)"
    return 1
fi
if [[ "$(xxd -p -s 123 -l 1 "$VBMETA")" != "03" ]]; then
    LOGE "vbmeta_patched.img does not have verification disabled"
    return 1
fi

LOG "- Adding vbmeta.img (verification disabled)"
EVAL "cp -f \"$VBMETA\" \"$TMP_DIR/vbmeta.img\"" || return 1

unset VBMETA
