#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Fills target/gta4xlwifi (in the base tree) with the device files the base
# build system requires and that are plain copies of files in the stock
# firmware of the tablet. Nothing here is hand written or guessed:
#
#   vintf/compatibility_matrix.device.xml   <- /system/etc/vintf/
#   camera/camera-feature.xml               <- /system/cameradata/
#   camera/singletake/, camera/aremoji-...   <- /system/cameradata/ (empty if absent)
#   overlay/                                <- res/ of the stock framework-res product RRO
#   dvfs/<dvfs policy>.xml                  <- res/raw/ of the stock SDHMS app
#
# Must run after the stock firmware has been extracted (run_cmd extract_fw).

set -eo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

GEN_TMP="$OUT_DIR/tabs6-gen-tmp"
rm -rf "$GEN_TMP"; mkdir -p "$GEN_TMP"
trap 'rm -rf "$GEN_TMP"' EXIT

ok()   { echo -e "  \033[0;32m+\033[0m $*"; }
warn() { echo -e "  \033[0;33m!\033[0m $*"; }

echo "Generating device files from $(cat "$STOCK_DIR/.extracted")"

# --- VINTF device compatibility matrix -------------------------------------
SRC="$STOCK_DIR/system/system/etc/vintf/compatibility_matrix.device.xml"
if [ -f "$SRC" ]; then
    mkdir -p "$TARGET_DIR/vintf"
    cp -f "$SRC" "$TARGET_DIR/vintf/compatibility_matrix.device.xml"
    ok "vintf/compatibility_matrix.device.xml"
else
    warn "stock compatibility_matrix.device.xml not found (build will need --debug)"
fi

# --- Camera feature list -----------------------------------------------------
SRC="$STOCK_DIR/system/system/cameradata/camera-feature.xml"
if [ -f "$SRC" ]; then
    mkdir -p "$TARGET_DIR/camera"
    cp -f "$SRC" "$TARGET_DIR/camera/camera-feature.xml"
    ok "camera/camera-feature.xml"
else
    warn "stock camera-feature.xml not found (build will need --debug)"
fi

# --- Single Take / AR Emoji feature lists ---------------------------------------
# The base copies these two from the stock firmware and aborts if they are not
# there. The tablet ships neither feature: use the stock file when it exists,
# otherwise an empty list (every option at its default, nothing enabled).
for REL in "singletake/service-feature.xml" "aremoji-feature.xml"; do
    SRC="$STOCK_DIR/system/system/cameradata/$REL"
    mkdir -p "$(dirname "$TARGET_DIR/camera/$REL")"
    if [ -f "$SRC" ]; then
        cp -f "$SRC" "$TARGET_DIR/camera/$REL"
        ok "camera/$REL"
    else
        printf '<?xml version="1.0" encoding="UTF-8"?>\n<resources>\n</resources>\n' > "$TARGET_DIR/camera/$REL"
        ok "camera/$REL (not in stock firmware: empty list)"
    fi
done

# --- framework-res product overlay (display, power profile, brightness...) ---
APK="$(find "$STOCK_DIR/product/overlay" -maxdepth 1 -type f -name "framework-res__*auto_generated_rro_product.apk" 2> /dev/null | head -n 1)"
if [ "$APK" ]; then
    if apktool d -f -s -o "$GEN_TMP/rro" "$APK" > "$GEN_TMP/rro.log" 2>&1 && [ -d "$GEN_TMP/rro/res" ]; then
        rm -rf "$TARGET_DIR/overlay"
        cp -a "$GEN_TMP/rro/res" "$TARGET_DIR/overlay"
        ok "overlay/ ($(find "$TARGET_DIR/overlay" -type f | wc -l) files from $(basename "$APK"))"
    else
        warn "could not decode $(basename "$APK"):"
        sed "s/^/      /" "$GEN_TMP/rro.log" | tail -n 5
    fi
else
    warn "stock framework-res product overlay not found (build will need --debug)"
fi

# --- DVFS policy ---------------------------------------------------------------
APK="$(find "$STOCK_DIR/system/system/priv-app/SamsungDeviceHealthManagerService" -maxdepth 1 -type f -name "*.apk" 2> /dev/null | head -n 1)"
if [ "$APK" ]; then
    if apktool d -f -s -o "$GEN_TMP/sdhms" "$APK" > "$GEN_TMP/sdhms.log" 2>&1; then
        echo "  stock SDHMS policies: $(find "$GEN_TMP/sdhms/res/raw" "$GEN_TMP/sdhms/assets" -maxdepth 1 -type f \( -name "dvfs_policy*" -o -name "siop*" -o -name "ssrm*" \) -printf "%f " 2> /dev/null)"
        SRC="$GEN_TMP/sdhms/res/raw/$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME.xml"
        if [ -f "$SRC" ]; then
            mkdir -p "$TARGET_DIR/dvfs"
            cp -f "$SRC" "$TARGET_DIR/dvfs/$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME.xml"
            ok "dvfs/$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME.xml"
        else
            warn "\"$TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME\" is not a DVFS policy of the stock SDHMS app:"
            warn "set TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME to one of the dvfs_policy* names listed above"
        fi
    else
        warn "could not decode the stock SDHMS app"
    fi
else
    warn "stock SDHMS app not found"
fi

echo "Done: $TARGET_DIR"
