# SPDX-License-Identifier: GPL-3.0-or-later

if ${TABS6_KEEP_ENCRYPTION:-false}; then
    LOG "\033[0;33m! TABS6_KEEP_ENCRYPTION is set, leaving the stock userdata entry untouched\033[0m"
    return 0
fi

FSTAB="$WORK_DIR/vendor/etc/fstab.exynos9611"
[ -f "$FSTAB" ] || ABORT "File not found: ${FSTAB//$WORK_DIR/}"

LINE="$(grep -n -E "^[^#]\S*\s+/data\s" "$FSTAB" | cut -d ":" -f 1)"
if [ ! "$LINE" ] || [[ "$LINE" == *$'\n'* ]]; then
    ABORT "Expected exactly one /data entry in ${FSTAB//$WORK_DIR/}"
fi

LOG "- Removing FBE/metadata encryption flags from /data in ${FSTAB//$WORK_DIR/}"
sed -i -E "${LINE}s/,?(fileencryption|metadata_encryption|keydirectory)=[^,[:space:]]+//g" "$FSTAB"
# A flag list that started with one of the removed flags is left with a leading comma
sed -i -E "${LINE}s/([[:space:]]),/\1/g" "$FSTAB"

if sed -n "${LINE}p" "$FSTAB" | grep -q -E "fileencryption|metadata_encryption|keydirectory"; then
    ABORT "Failed to remove the encryption flags from ${FSTAB//$WORK_DIR/}"
fi

unset FSTAB LINE
