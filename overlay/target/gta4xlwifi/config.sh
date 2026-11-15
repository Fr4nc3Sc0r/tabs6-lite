# SPDX-License-Identifier: GPL-3.0-or-later
#
# Device configuration file for Galaxy Tab S6 Lite Wi-Fi 2020 (gta4xlwifi, SM-P610)
#
# Where each value comes from is documented in docs/01-hardware.md.
# [VERIFY] = not read from a stock firmware dump yet. tools/verify_target.sh
# compares these against the extracted firmware and reports any mismatch.

TARGET_NAME="Galaxy Tab S6 Lite"
TARGET_CODENAME="gta4xlwifi"
TARGET_ASSERT_MODEL=("SM-P610")
TARGET_PLATFORM="exynos9611"

# Stock firmware used for vendor, kernel ramdisk, DTB and device files.
# P610XXS7FYD1 (Android 13, One UI 5.1.1, bootloader revision 7) is the last
# official build. A Wi-Fi tablet has no IMEI: Samsung's firmware server wants
# the device serial number instead (11 characters, starts with "R").
# Never commit a real serial: pass it through the TABS6_SERIAL environment
# variable (a GitHub Actions secret in CI). See docs/03-build.md.
TARGET_FIRMWARE="SM-P610/${TABS6_CSC:-ITV}/${TABS6_SERIAL:-R0000000000}"
TARGET_EXTRA_FIRMWARES=()
TARGET_PLATFORM_SDK_VERSION=33

# Partitions (bytes) - LineageOS android_device_samsung_gta4xl-common BoardConfigCommon.mk
TARGET_BOOT_PARTITION_SIZE=61865984
TARGET_DTBO_PARTITION_SIZE=8388608
TARGET_CACHE_PARTITION_SIZE=209715200

# Dynamic partitions (bytes) - same source; group size = super size - 4 MiB
TARGET_SUPER_PARTITION_SIZE=6585057280
TARGET_GROUP_BASIC_SIZE=6580862976

# SEC Product Feature
TARGET_AUDIO_CONFIG_RECORDALIVE_LIB_VERSION="07010"    # lib_SamsungRec_07010.so in stock vendor
TARGET_AUDIO_SUPPORT_ACH_RINGTONE=false
TARGET_AUDIO_SUPPORT_DUAL_SPEAKER=true                 # stock: AUDIO_NUMBER_OF_SPEAKER=2, spk_stereo
TARGET_AUDIO_SUPPORT_VIRTUAL_VIBRATION_SOUND=false     # no vibration motor
TARGET_BLUETOOTH_SUPPORT_A2DPSINK_PROFILE=false        # [VERIFY]
TARGET_BLUETOOTH_SUPPORT_A2DP_SBM=false
TARGET_BLUETOOTH_SUPPORT_HEAD_SAR_BACKOFF=false
TARGET_BLUETOOTH_SUPPORT_XLNA_CONTROL=false
TARGET_CAMERA_SUPPORT_CAMERAX_EXTENSION=false          # [VERIFY]
TARGET_CAMERA_SUPPORT_CUTOUT_PROTECTION=false          # no display cutout
TARGET_CAMERA_SUPPORT_MASS_APP_FLAVOR=true             # [VERIFY]
TARGET_CAMERA_SUPPORT_SDK_SERVICE=false                # [VERIFY]
TARGET_COMMON_CONFIG_MDNIE_MODE="0"                    # [VERIFY] TFT LCD panel
TARGET_COMMON_SUPPORT_DYN_RESOLUTION_CONTROL=false     # 2000x1200 fixed
TARGET_COMMON_SUPPORT_EMBEDDED_SIM=false               # Wi-Fi only
TARGET_COMMON_SUPPORT_HDR_EFFECT=false
TARGET_DVFSAPP_CONFIG_DVFS_POLICY_FILENAME="dvfs_policy_exynos9610_xx" # [VERIFY]
# "ssrm_default" makes the base ship its generic thermal policy instead of the
# device one, which is stored encrypted in the stock SDHMS app. See docs/07.
TARGET_DVFSAPP_CONFIG_SSRM_POLICY_FILENAME="ssrm_default"
TARGET_FINGERPRINT_CONFIG_SENSOR="none"                # no fingerprint reader
TARGET_LCD_CONFIG_COLOR_WEAKNESS_SOLUTION="0"          # [VERIFY]
TARGET_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS="2"          # stock floating_feature.xml
TARGET_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE="60"
TARGET_LCD_CONFIG_HFR_MODE="0"                         # 60 Hz only
TARGET_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE="none"
TARGET_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE_NS="none"
TARGET_LCD_CONFIG_SEAMLESS_BRT="none"
TARGET_LCD_CONFIG_SEAMLESS_LUX="none"
TARGET_LCD_SUPPORT_MDNIE_HW=false                      # [VERIFY]
TARGET_RIL_FEATURES="none"                             # Wi-Fi only
TARGET_RIL_SIM_CONFIG_MULTISIM_TRAYCOUNT="0"           # [VERIFY]
TARGET_RIL_SUPPORT_WATERPROOF_SIM_TRAY_MSG=false
TARGET_WLAN_SUPPORT_WIFI_TO_CELLULAR=false
