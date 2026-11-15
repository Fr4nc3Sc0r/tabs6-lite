#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Lists what takes space in the work dir, to decide what to add to
# target/gta4xlwifi/debloat.sh when the ROM does not fit in the 6.13 GiB super
# partition. Sizes are uncompressed: EROFS (lz4hc) typically stores app and
# library data in 55-65% of that.

set -eo pipefail

if [ ! "${WORK_DIR:-}" ] || [ ! -d "$WORK_DIR" ]; then
    echo "Work dir not found: build the ROM first (./build.sh)" >&2
    exit 1
fi

echo "Super partition: $TARGET_SUPER_PARTITION_SIZE bytes ($((TARGET_SUPER_PARTITION_SIZE / 1048576)) MiB)"
echo
echo "== Partitions (uncompressed) =="
for p in system product vendor odm system_ext; do
    [ -d "$WORK_DIR/$p" ] && du -sm "$WORK_DIR/$p" | awk -v p="$p" '{printf "%6d MiB  %s\n", $1, p}'
done
echo
echo "== Built images =="
find "$WORK_DIR" "$OUT_DIR/target/$TARGET_CODENAME" -maxdepth 2 -name "*.img" -printf "%s %p\n" 2> /dev/null | \
    awk '{printf "%6d MiB  %s\n", $1 / 1048576, $2}' | sort -rn
echo
echo "== 60 biggest app/lib directories =="
{
    find "$WORK_DIR/system/system/app" "$WORK_DIR/system/system/priv-app" "$WORK_DIR/product/app" \
        "$WORK_DIR/product/priv-app" -mindepth 1 -maxdepth 1 -type d 2> /dev/null
    find "$WORK_DIR/system/system" -mindepth 1 -maxdepth 1 -type d 2> /dev/null
} | xargs -r du -sm 2> /dev/null | sort -rn | head -n 60 | sed "s|$WORK_DIR/||" | awk '{printf "%6d MiB  %s\n", $1, $2}'
