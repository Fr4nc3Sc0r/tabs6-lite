# SPDX-License-Identifier: GPL-3.0-or-later
# Shared helpers for the tabs6-lite tools. Sourced, not executed.

if [ ! "${SRC_DIR:-}" ] || [ ! "${FW_DIR:-}" ] || [ ! "${TARGET_FIRMWARE:-}" ]; then
    echo "Run this from the base build environment (source buildenv.sh gta4xlwifi)," >&2
    echo "or simply use ./build.sh from the repository root." >&2
    exit 1
fi

STOCK_DIR="$FW_DIR/$(cut -d "/" -f 1 <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 <<< "$TARGET_FIRMWARE")"
TARGET_DIR="$SRC_DIR/target/$TARGET_CODENAME"

if [ ! -f "$STOCK_DIR/.extracted" ]; then
    echo "Stock firmware not extracted in $STOCK_DIR (run_cmd download_fw && run_cmd extract_fw)" >&2
    exit 1
fi

# stock_prop <file relative to the stock dir> <prop>
stock_prop()
{
    [ -f "$STOCK_DIR/$1" ] || return 0
    grep -m 1 "^$2=" "$STOCK_DIR/$1" | cut -d "=" -f 2-
}

# stock_sff <feature>: value in the stock floating_feature.xml
stock_sff()
{
    [ -f "$STOCK_DIR/system/system/etc/floating_feature.xml" ] || return 0
    grep -o -P "(?<=<$1>)[^<]+" "$STOCK_DIR/system/system/etc/floating_feature.xml" 2> /dev/null || true
}
