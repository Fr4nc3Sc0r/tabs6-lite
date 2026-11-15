#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Compares target/gta4xlwifi/config.sh and platform/exynos9611/config.sh with
# what the extracted stock firmware of the tablet actually says, and prints a
# Markdown report (also saved as out/verify_target-report.md by build.sh).
#
#   FAIL  the build would produce a ROM for the wrong hardware: exit status 1
#   WARN  a [VERIFY] value in config.sh differs from stock: fix config.sh
#   INFO  facts worth knowing when debugging
#
# Must run after the stock firmware has been extracted (run_cmd extract_fw).

set -o pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

FAILS=0
WARNS=0

row() { printf '| %s | %s | `%s` | `%s` |\n' "$1" "$2" "${3:-<unset>}" "${4:-<absent>}"; }

# check <FAIL|WARN> <description> <configured> <stock>
check()
{
    local LEVEL="$1" DESC="$2" CONF="$3" STOCK="$4"
    if [[ "$CONF" == "$STOCK" ]]; then
        row "ok" "$DESC" "$CONF" "$STOCK"
    else
        row "**$LEVEL**" "$DESC" "$CONF" "$STOCK"
        if [[ "$LEVEL" == "FAIL" ]]; then FAILS=$((FAILS + 1)); else WARNS=$((WARNS + 1)); fi
    fi
}

info() { row "info" "$1" "-" "$2"; }

# bool_sff <feature>: "true" when the stock floating feature is TRUE, else "false"
bool_sff() { [[ "$(stock_sff "$1")" == "TRUE" ]] && echo "true" || echo "false"; }

meta() { [ -f "$STOCK_DIR/$1" ] && grep -m 1 "^$2=" "$STOCK_DIR/$1" | cut -d "=" -f 2-; }

GROUP_SIZE_VAR="TARGET_$(tr "[:lower:]" "[:upper:]" <<< "$TARGET_SUPER_GROUP_NAME")_SIZE"

echo "# Verifica configurazione gta4xlwifi contro il firmware stock"
echo
echo "Firmware stock: \`$(cat "$STOCK_DIR/.extracted")\`"
echo
echo "| Esito | Controllo | config.sh | Firmware stock |"
echo "|---|---|---|---|"

# --- Identity: a mismatch here means the wrong firmware or the wrong target ---
check FAIL "Codename (ro.product.vendor.device)" "$TARGET_CODENAME" "$(stock_prop vendor/build.prop ro.product.vendor.device)"
check FAIL "SDK del vendor (ro.vendor.build.version.sdk)" "$TARGET_PLATFORM_SDK_VERSION" "$(stock_prop vendor/build.prop ro.vendor.build.version.sdk)"
check FAIL "Versione VNDK (ro.vndk.version)" "$TARGET_BOARD_API_LEVEL" "$(stock_prop vendor/build.prop ro.vndk.version)"
check WARN "API di lancio (ro.product.first_api_level)" "$TARGET_PRODUCT_SHIPPING_API_LEVEL" "$(stock_prop vendor/build.prop ro.product.first_api_level)"
info "Modello (ro.product.vendor.model)" "$(stock_prop vendor/build.prop ro.product.vendor.model)"
info "Patch di sicurezza vendor" "$(stock_prop vendor/build.prop ro.vendor.build.security_patch)"
info "ro.build.characteristics (system)" "$(stock_prop system/system/build.prop ro.build.characteristics)"
info "ro.sf.lcd_density (vendor)" "$(stock_prop vendor/build.prop ro.sf.lcd_density)"
info "ro.hardware.egl (vendor)" "$(stock_prop vendor/build.prop ro.hardware.egl)"

# --- Partition layout --------------------------------------------------------
check FAIL "Dimensione super" "$TARGET_SUPER_PARTITION_SIZE" "$(meta os_partitions_metadata.txt super_partition_size)"
check FAIL "Gruppo super" "$TARGET_SUPER_GROUP_NAME" "$(meta os_partitions_metadata.txt super_partition_group)"
check FAIL "Dimensione gruppo super" "${!GROUP_SIZE_VAR}" "$(meta os_partitions_metadata.txt "super_${TARGET_SUPER_GROUP_NAME}_group_size")"
info "Partizioni logiche stock" "$(meta os_partitions_metadata.txt "super_${TARGET_SUPER_GROUP_NAME}_partition_list")"
info "boot.img: header version" "$(meta boot.img_metadata.txt header_version)"
info "boot.img: cmdline" "$(meta boot.img_metadata.txt cmdline)"
info "boot.img: os patch level" "$(meta boot.img_metadata.txt os_patch_level)"
if [ -f "$STOCK_DIR/kernel/boot.img" ]; then
    BOOT_SIZE="$(stat -c %s "$STOCK_DIR/kernel/boot.img")"
    if [ "$BOOT_SIZE" -gt "$TARGET_BOOT_PARTITION_SIZE" ]; then
        check FAIL "boot.img stock entra nella partizione boot" "<= $TARGET_BOOT_PARTITION_SIZE" "$BOOT_SIZE"
    else
        info "boot.img stock (byte)" "$BOOT_SIZE"
    fi
fi
info "Immagini kernel nel firmware" "$(ls "$STOCK_DIR/kernel" 2> /dev/null | tr "\n" " ")"

# --- SEC product features ([VERIFY] values of config.sh) -------------------------
check WARN "Nome commerciale (SETTINGS_CONFIG_BRAND_NAME)" "$TARGET_NAME" "$(stock_sff SEC_FLOATING_FEATURE_SETTINGS_CONFIG_BRAND_NAME)"
check WARN "mDNIe mode (COMMON_CONFIG_MDNIE_MODE)" "$TARGET_COMMON_CONFIG_MDNIE_MODE" "$(stock_sff SEC_FLOATING_FEATURE_COMMON_CONFIG_MDNIE_MODE)"
check WARN "mDNIe hardware (LCD_SUPPORT_MDNIE_HW)" "$TARGET_LCD_SUPPORT_MDNIE_HW" "$(bool_sff SEC_FLOATING_FEATURE_LCD_SUPPORT_MDNIE_HW)"
check WARN "Luminosita automatica (LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS)" "$TARGET_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS" "$(stock_sff SEC_FLOATING_FEATURE_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS)"
STOCK_HFR="$(stock_sff SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_MODE)"
check WARN "Refresh rate variabile (LCD_CONFIG_HFR_MODE)" "$TARGET_LCD_CONFIG_HFR_MODE" "${STOCK_HFR:-0}"
# Older firmware has AUDIO_SUPPORT_DUAL_SPEAKER, newer ones only the speaker count
STOCK_DUAL_SPK="$(bool_sff SEC_FLOATING_FEATURE_AUDIO_SUPPORT_DUAL_SPEAKER)"
STOCK_SPK_COUNT="$(stock_sff SEC_FLOATING_FEATURE_AUDIO_NUMBER_OF_SPEAKER)"
[[ "$STOCK_SPK_COUNT" =~ ^[0-9]+$ ]] && [ "$STOCK_SPK_COUNT" -ge 2 ] && STOCK_DUAL_SPK=true
check WARN "Doppio altoparlante (AUDIO_SUPPORT_DUAL_SPEAKER / NUMBER_OF_SPEAKER)" "$TARGET_AUDIO_SUPPORT_DUAL_SPEAKER" "$STOCK_DUAL_SPK"
STOCK_CAMERAX="$(stock_prop system/system/build.prop ro.camerax.extensions.enabled)"
check WARN "CameraX extensions" "$TARGET_CAMERA_SUPPORT_CAMERAX_EXTENSION" "${STOCK_CAMERAX:-false}"
STOCK_REC="$(find "$STOCK_DIR/vendor/lib" "$STOCK_DIR/vendor/lib64" -maxdepth 1 -name "lib_SamsungRec_*.so" -printf "%f\n" 2> /dev/null | sed -E "s/lib_SamsungRec_(.*)\.so/\1/" | sort -u | tr "\n" " " | sed "s/ $//")"
check WARN "RecordAlive lib version" "$TARGET_AUDIO_CONFIG_RECORDALIVE_LIB_VERSION" "${STOCK_REC:-none}"
info "SIOP policy stock (non usata: vedi docs/07)" "$(stock_sff SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME)"
info "eSIM (EMBEDDED_SIM_SLOTSWITCH)" "$(stock_sff SEC_FLOATING_FEATURE_COMMON_CONFIG_EMBEDDED_SIM_SLOTSWITCH)"
info "S Pen (floating feature)" "$(grep -o -P "(?<=<)SEC_FLOATING_FEATURE_[A-Z_]*SPEN[A-Z_]*(?=>)" "$STOCK_DIR/system/system/etc/floating_feature.xml" 2> /dev/null | sort -u | wc -l) voci"
info "Wi-Fi (floating feature WLAN/WIFI)" "$(grep -o -P "(?<=<)SEC_FLOATING_FEATURE_(WLAN|WIFI)_[A-Z0-9_]*>[^<]*" "$STOCK_DIR/system/system/etc/floating_feature.xml" 2> /dev/null | sed "s/SEC_FLOATING_FEATURE_//; s/>/=/" | tr "\n" " ")"

# --- Files the base build system reads from the stock firmware -------------------
exists() { [ -e "$STOCK_DIR/$1" ] && echo "presente" || echo "ASSENTE"; }
check FAIL "floating_feature.xml in /system/etc" "presente" "$(exists system/system/etc/floating_feature.xml)"
check FAIL "fstab del vendor" "presente" "$(exists vendor/etc/fstab.exynos9611)"
check WARN "cameradata/portrait_data (richiesta dalla base per One UI 9)" "presente" "$(exists system/system/cameradata/portrait_data)"
check WARN "compatibility_matrix.device.xml" "presente" "$(exists system/system/etc/vintf/compatibility_matrix.device.xml)"
info "Voce /data nell'fstab" "$(grep -E "^[^#]\S*\s+/data\s" "$STOCK_DIR/vendor/etc/fstab.exynos9611" 2> /dev/null | tr -s " \t" " ")"

# --- Vendor HAL inventory (what the One UI 9 framework will have to talk to) -----
if [ -d "$STOCK_DIR/vendor/bin/hw" ]; then
    HAL32=0; HAL64=0
    while IFS= read -r f; do
        case "$(head -c 5 "$f" | od -An -tx1 | tr -d " \n")" in
            7f454c4601) HAL32=$((HAL32 + 1)) ;;
            7f454c4602) HAL64=$((HAL64 + 1)) ;;
        esac
    done < <(find "$STOCK_DIR/vendor/bin/hw" -maxdepth 1 -type f)
    info "Servizi HAL in /vendor/bin/hw" "$HAL64 a 64 bit, $HAL32 a 32 bit"
    info "HAL AIDL luci" "$(exists vendor/bin/hw/vendor.samsung.hardware.light-service)"
fi
info "Moduli kernel nel vendor" "$(find "$STOCK_DIR/vendor/lib/modules" -name "*.ko" 2> /dev/null | wc -l)"

echo
echo "## Servizi HAL del vendor"
echo
echo '```'
ls -1 "$STOCK_DIR/vendor/bin/hw" 2> /dev/null
echo '```'
echo
echo "## Esito"
echo
echo "- FAIL: $FAILS"
echo "- WARN: $WARNS"
if [ "$FAILS" -gt 0 ]; then
    echo
    echo "Almeno un controllo FAIL: la build viene fermata. Vedi docs/06-troubleshooting.md."
    exit 1
fi
exit 0
