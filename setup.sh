#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Prepares the build tree: clones the One UI 9 UN1CA-based build system at a
# pinned commit into ./un1ca and copies this repository's overlay (platform
# exynos9611 + target gta4xlwifi) on top of it.
#
# Usage: ./setup.sh [--force]
#   --force   discard local changes in ./un1ca and re-apply the overlay
#
# Environment:
#   BASE_REPO / BASE_COMMIT   override the pinned base (see docs/02-architettura.md)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$HERE/un1ca"

# kusti420/k4_un1ca, branch "seventeen" (One UI 9 / Android 17), 2026-10-09
BASE_REPO="${BASE_REPO:-https://github.com/kusti420/k4_un1ca.git}"
BASE_COMMIT="${BASE_COMMIT:-bf0d0240887c28517e08304fcf1d2bb536014f16}"

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

log() { echo -e "\033[1;37m[setup]\033[0m $*"; }
die() { echo -e "\033[0;31m[setup] $*\033[0m" >&2; exit 1; }

for bin in git rsync; do
    command -v "$bin" > /dev/null || die "\"$bin\" is required"
done

if [ ! -d "$BASE_DIR/.git" ]; then
    log "Cloning base build system ($BASE_COMMIT)"
    mkdir -p "$BASE_DIR"
    git -C "$BASE_DIR" init -q
    git -C "$BASE_DIR" remote add origin "$BASE_REPO"
fi

CURRENT="$(git -C "$BASE_DIR" rev-parse HEAD 2> /dev/null || true)"
if [[ "$CURRENT" != "$BASE_COMMIT" ]]; then
    log "Fetching $BASE_COMMIT"
    git -C "$BASE_DIR" fetch -q --depth 1 origin "$BASE_COMMIT"
    git -C "$BASE_DIR" checkout -q -f FETCH_HEAD
elif $FORCE; then
    log "Resetting base tree (--force)"
    git -C "$BASE_DIR" reset -q --hard "$BASE_COMMIT"
    git -C "$BASE_DIR" clean -q -fd -e out
fi

log "Fetching base submodules"
git -C "$BASE_DIR" submodule update -q --init --recursive --depth 1

log "Applying overlay"
# --delete only inside the two directories this repository owns
mkdir -p "$BASE_DIR/platform/exynos9611" "$BASE_DIR/target/gta4xlwifi"
rsync -a --delete "$HERE/overlay/platform/exynos9611/" "$BASE_DIR/platform/exynos9611/"
# Files generated from the stock firmware live next to the committed ones: keep them
rsync -a "$HERE/overlay/target/gta4xlwifi/" "$BASE_DIR/target/gta4xlwifi/"

mkdir -p "$BASE_DIR/tabs6-tools"
rsync -a --delete "$HERE/tools/" "$BASE_DIR/tabs6-tools/"

log "Fixing base scripts"
# download_fw.sh keeps IMEI/SERIAL_NO from the previous firmware of the loop:
# the source phone's IMEI would be sent for the tablet too, and samloader
# prefers it over the serial (FUS then answers 408). Reset both per firmware.
DOWNLOAD_FW="$BASE_DIR/scripts/download_fw.sh"
if ! grep -q 'IMEI=""; SERIAL_NO=""; PARSE_FIRMWARE_STRING' "$DOWNLOAD_FW"; then
    sed -i 's/^    PARSE_FIRMWARE_STRING "\$i" || exit 1$/    IMEI=""; SERIAL_NO=""; PARSE_FIRMWARE_STRING "$i" || exit 1/' "$DOWNLOAD_FW"
    grep -q 'IMEI=""; SERIAL_NO=""; PARSE_FIRMWARE_STRING' "$DOWNLOAD_FW" \
        || { echo "Could not patch $DOWNLOAD_FW (base changed?)" >&2; exit 1; }
fi

# The "target has no secure element" branch of the eSE patches only accepts an
# NXP JCOP source, but the S26 Exynos source is GEMALTO: without this the build
# falls into the branch that ports the eSE stack and aborts. The branch itself
# only uses the SOURCE_* variables, so accept any source vendor/COS.
ESE_PATCH="$BASE_DIR/unica/patches/ese/customize.sh"
ESE_OLD='if [[ "$SOURCE_SECURITY_CONFIG_ESE_CHIP_VENDOR" == "NXP" ]] && [[ "$SOURCE_SECURITY_CONFIG_ESE_COS_NAME" =~ ^JCOP(6\.2|7\.2)U$ ]] && \'
ESE_NEW='if [[ "$SOURCE_SECURITY_CONFIG_ESE_CHIP_VENDOR" != "none" ]] && [[ "$SOURCE_SECURITY_CONFIG_ESE_COS_NAME" != "none" ]] && \'
if ! grep -qxF "$ESE_NEW" "$ESE_PATCH"; then
    grep -qxF "$ESE_OLD" "$ESE_PATCH" \
        || { echo "Could not patch $ESE_PATCH (base changed?)" >&2; exit 1; }
    ESE_OLD="$ESE_OLD" ESE_NEW="$ESE_NEW" perl -0pi -e 's/\Q$ENV{ESE_OLD}\E/$ENV{ESE_NEW}/' "$ESE_PATCH"
fi

# The legacy patches fall back to the Face HIDL 2.0 HAL whenever the vendor has
# no face@3.0 HIDL service. The tablet's vendor has the AIDL face HAL instead
# (vendor.samsung.hardware.biometrics.face-service, IFace v2), which One UI 9
# talks to natively: the fallback is not needed and its patch does not apply.
LEGACY_PATCH="$BASE_DIR/unica/patches/legacy/customize.sh"
FACE_OLD='    if [ ! -f "$WORK_DIR/vendor/bin/hw/vendor.samsung.hardware.biometrics.face@3.0-service" ]; then'
FACE_NEW='    if [ ! -f "$WORK_DIR/vendor/bin/hw/vendor.samsung.hardware.biometrics.face@3.0-service" ] && [ ! -f "$WORK_DIR/vendor/bin/hw/vendor.samsung.hardware.biometrics.face-service" ]; then'
if ! grep -qF 'biometrics.face-service" ]; then' "$LEGACY_PATCH"; then
    grep -qxF "$FACE_OLD" "$LEGACY_PATCH" \
        || { echo "Could not patch $LEGACY_PATCH (base changed?)" >&2; exit 1; }
    FACE_OLD="$FACE_OLD" FACE_NEW="$FACE_NEW" perl -0pi -e 's/\Q$ENV{FACE_OLD}\E/$ENV{FACE_NEW}/' "$LEGACY_PATCH"
fi

# netd, Smart Hotspot on a 4.14 kernel: the base removes the "ro.kernel.version
# == 4.14" check of MobileBBController::hotspotOn by nop-ing a "b.eq". In the
# S26 netd the compiler turned that branch into two "csel ..., ne" after
# "cmp w8, w10" (w10 = "4.14"), so the base's pattern is not there. Replace the
# compare with "cmp w10, #0", which is never equal: same effect, the non-4.14
# paths are always selected. The second check (isMBBPathsPresent) is unchanged.
NETD_OLD='        HEX_PATCH "$WORK_DIR/system/system/bin/netd" "1f01096be0010054" "1f01096b1f2003d5"'
NETD_NEW='        if xxd -p -c 0 "$WORK_DIR/system/system/bin/netd" | grep -q "1f01096be0010054"; then HEX_PATCH "$WORK_DIR/system/system/bin/netd" "1f01096be0010054" "1f01096b1f2003d5"; else HEX_PATCH "$WORK_DIR/system/system/bin/netd" "1f010a6bc8fcff90" "5f010071c8fcff90"; fi'
if ! grep -qF '"5f010071c8fcff90"' "$LEGACY_PATCH"; then
    grep -qxF "$NETD_OLD" "$LEGACY_PATCH" \
        || { echo "Could not patch $LEGACY_PATCH (base changed?)" >&2; exit 1; }
    NETD_OLD="$NETD_OLD" NETD_NEW="$NETD_NEW" perl -0pi -e 's/\Q$ENV{NETD_OLD}\E/$ENV{NETD_NEW}/' "$LEGACY_PATCH"
fi

# patch_base <file> <old line> <new line>: replace an exact line of a base script
# (every occurrence of it)
patch_base()
{
    grep -qxF -- "$3" "$1" && return 0
    grep -qxF -- "$2" "$1" || { echo "Could not patch $1 (base changed?)" >&2; exit 1; }
    OLD="$2" NEW="$3" perl -0pi -e 's/^\Q$ENV{OLD}\E$/$ENV{NEW}/mg' "$1"
}

# The product feature patches know ultrasonic, optical and side fingerprint
# readers only. The tablet has none: the sensor string is already replaced with
# "none" by the generic part, so just skip the sensor-type specific patches.
FEATURE_PATCH="$BASE_DIR/unica/patches/product_feature/customize.sh"
patch_base "$FEATURE_PATCH" \
    '    elif [[ "$1" == *"side"* ]]; then' \
    '    elif [[ "$1" == "none" ]]; then echo "none"; elif [[ "$1" == *"side"* ]]; then'
patch_base "$FEATURE_PATCH" \
    '            elif [[ "$(GET_FINGERPRINT_SENSOR_TYPE "$TARGET_FINGERPRINT_CONFIG_SENSOR")" != "ultrasonic" ]]; then' \
    '            elif [[ "$(GET_FINGERPRINT_SENSOR_TYPE "$TARGET_FINGERPRINT_CONFIG_SENSOR")" != "ultrasonic" ]] && [[ "$TARGET_FINGERPRINT_CONFIG_SENSOR" != "none" ]]; then'

# Default refresh rate (120 on the S26, 60 on the tablet): in One UI 9 the
# "HFR_DEFAULT_REFRESH_RATE: " dump string moved from dump() to
# dumpProductFeature(). The base already knows this for HFR_MODE, not here.
patch_base "$FEATURE_PATCH" \
    '        "dump(Ljava/io/PrintWriter;Ljava/lang/String;Z)V" \' \
    '        "dumpProductFeature(Ljava/io/PrintWriter;Ljava/lang/String;Z)V" \'

# Wi-Fi: the S26 has 802.11ax with 6 GHz, the tablet is 802.11ac. The base has
# no patch for "source ax + 6 GHz, target without ax" (a TODO) and aborts. On
# One UI 9 do what the base does for an ax target without 6 GHz, i.e. make the
# central isSupported6Ghz() return false; there is no compiled-in 802.11ax
# switch left in the Wi-Fi facade, that capability comes from the driver.
patch_base "$FEATURE_PATCH" \
    '            LOG_MISSING_PATCHES "SOURCE_WLAN_SUPPORT_80211AX" "TARGET_WLAN_SUPPORT_80211AX" || true' \
    '            if [ "$SOURCE_PLATFORM_SDK_VERSION" -ge "37" ]; then SMALI_PATCH "system" "system/framework/semwifi-service.jar" "smali/com/samsung/android/server/wifi/SemFrameworkFacade.smali" "return" "isSupported6Ghz()Z" "false"; else LOG_MISSING_PATCHES "SOURCE_WLAN_SUPPORT_80211AX" "TARGET_WLAN_SUPPORT_80211AX" || true; fi'
patch_base "$FEATURE_PATCH" \
    '            LOG_MISSING_PATCHES "SOURCE_WLAN_SUPPORT_80211AX_6GHZ" "TARGET_WLAN_SUPPORT_80211AX_6GHZ"' \
    '            [ "$SOURCE_PLATFORM_SDK_VERSION" -ge "37" ] || LOG_MISSING_PATCHES "SOURCE_WLAN_SUPPORT_80211AX_6GHZ" "TARGET_WLAN_SUPPORT_80211AX_6GHZ"'

# The tablet's vendor declares FCM level 4 (launched on Android 10). Android 17
# only ships framework compatibility matrices from level 7; the base restores
# levels 5 and 6 from the stock firmware, level 4 has to come back too.
patch_base "$BASE_DIR/unica/patches/vintf/customize.sh" \
    'RESTORE_TARGET_FCM "5"' \
    'RESTORE_TARGET_FCM "4"; RESTORE_TARGET_FCM "5"'

# The preload mod downloads the current Samsung Internet from the Galaxy Store
# and compares it with a digest fixed when the base was written, so the build
# breaks every time Samsung publishes an update. When the digest differs,
# accept the file if its signature verifies and the signer is the Samsung
# platform certificate (the one that signs SecSettings in the S26 firmware).
patch_base "$BASE_DIR/unica/mods/preload/customize.sh" \
    'if [ "$SBROWSER_ACTUAL_SHA256" != "$SBROWSER_SHA256" ]; then' \
    'if [ "$SBROWSER_ACTUAL_SHA256" != "$SBROWSER_SHA256" ] && ! { jarsigner -verify "$WORK_DIR/system/system/preload/SBrowser/SBrowser.apk" > /dev/null 2>&1 && keytool -printcert -jarfile "$WORK_DIR/system/system/preload/SBrowser/SBrowser.apk" 2> /dev/null | grep -m 1 "SHA256:" | grep -q "34:DF:0E:7A:9F:1C:F1:89:2E:45:C0:56:B4:97:3C:D8:1C:CF:14:8A:40:50:D1:1A:EA:4A:C5:A6:5F:90:0A:42"; }; then'

# UN1CA settings mod, ASKS switch: in the S26 firmware used here the body of
# refreshInstalledUnknownList_NEW() moved to refreshInstalledUnknownList_NEWInner().
# Patch whichever of the two the firmware has.
patch_base "$BASE_DIR/unica/mods/settings/customize.sh" \
    "    'refreshInstalledUnknownList_NEW()V' \\" \
    "    \"\$(grep -q 'refreshInstalledUnknownList_NEWInner()V' \"\$ASKS_SMALI\" && echo 'refreshInstalledUnknownList_NEWInner()V' || echo 'refreshInstalledUnknownList_NEW()V')\" \\"

# Single Take models: the base upgrades them in the vendor of any pre-Android 15
# target, assuming the vendor has Single Take. The tablet's vendor does not: the
# new folder would have no parent entry in fs_config and mkfs.erofs fails.
patch_base "$LEGACY_PATCH" \
    '    if [ ! -d "$WORK_DIR/vendor/etc/singletake/ClarityScorer" ]; then' \
    '    if [ -d "$WORK_DIR/vendor/etc/singletake" ] && [ ! -d "$WORK_DIR/vendor/etc/singletake/ClarityScorer" ]; then'

# EROFS images: compress in 64 KiB physical clusters instead of 4 KiB ones. On
# this ROM it makes system.img about 8% smaller (roughly 420 MiB), which is what
# lets it fit in the 6.13 GiB super partition without removing more apps. Needs
# the "big pcluster" EROFS feature, which the kernel of platform/exynos9611 has
# (EROFS_FEATURE_INCOMPAT_BIG_PCLUSTER); AOSP uses even larger clusters.
patch_base "$BASE_DIR/scripts/build_fs_image.sh" \
    '            BUILD_CMD+="-z \"lz4hc,9\" "' \
    '            BUILD_CMD+="-z \"lz4hc,9\" -C \"65536\" "'

# S Pen blobs: for an S Pen target and a source without S Pen (the S26) the base
# replaces libandroid_runtime.so with a prebuilt taken from the Galaxy S22 Ultra.
# That prebuilt is an Android 16 build: under the Android 17 system it asks for
# android.media.audio.common.types-V4-cpp.so, which does not exist (the system
# has V5), so app_process64 cannot be linked: no zygote, guaranteed bootloop
# (found by starting the binaries of the built ROM under qemu-user). Keep the
# runtime library of the source firmware; the rest of the S Pen files (apps,
# libsmpsft, pen sounds) are still added. The two lines below turn the two
# libandroid_runtime.so additions into repetitions of the libsmpsft ones.
SPEN_PATCH="$BASE_DIR/unica/patches/spen/customize.sh"
patch_base "$SPEN_PATCH" \
    '            "system" "system/lib/libandroid_runtime.so" 0 0 644 "u:object_r:system_lib_file:s0"' \
    '            "system" "system/lib/libsmpsft.smps.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0" # was libandroid_runtime.so'
patch_base "$SPEN_PATCH" \
    '            "system" "system/lib64/libandroid_runtime.so" 0 0 644 "u:object_r:system_lib_file:s0"' \
    '            "system" "system/lib64/libsmpsft.smps.samsung.so" 0 0 644 "u:object_r:system_lib_file:s0" # was libandroid_runtime.so'

cat << MSG

Base tree ready in: $BASE_DIR

Next steps (details in docs/03-build.md):
  export TABS6_SERIAL=<serial number of YOUR tablet, e.g. R52N...>
  ./build.sh
MSG
