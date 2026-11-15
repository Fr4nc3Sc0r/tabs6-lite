# SPDX-License-Identifier: GPL-3.0-or-later
#
# Platform configuration file for Samsung Exynos 9611 devices (exynos9611)
#
# Sources for every value are listed in docs/01-hardware.md.
# Values tagged [VERIFY] could not be read from a stock firmware dump while
# writing this file: tools/verify_target.sh checks them against the extracted
# firmware and fails the build when they do not match.

# Stock vendor is Android 13 (VNDK 33); the device launched on Android 10.
TARGET_BOARD_API_LEVEL=33
TARGET_PRODUCT_SHIPPING_API_LEVEL=29

# Dynamic partitions (non-A/B, launched with Android 10)
TARGET_USE_DYNAMIC_PARTITIONS=true
TARGET_SUPER_GROUP_NAME="group_basic" # [VERIFY] lpdump of stock super.img

# OS
TARGET_OS_SINGLE_SYSTEM_IMAGE="essi"
TARGET_OS_BUILD_SYSTEM_EXT_PARTITION=false
# The 4.14 kernel in platform/exynos9611/patches/kernel has EROFS (with
# compression) enabled and stock fstab already lists erofs for every logical
# partition, so the default (erofs) is kept: it is what makes One UI 9 fit in
# a 6.1 GiB super partition.
TARGET_OS_FILE_SYSTEM_TYPE="erofs"

# AVB: defaults of the base are kept (images signed with the build keys, like the
# other Exynos platforms). vbmeta must be disabled once on the device, see
# docs/04-installazione.md.

# SEC Product Feature - WLAN (Wi-Fi 5 / 802.11ac 2x2 MIMO, no Wi-Fi 6) [VERIFY]
TARGET_WLAN_CONFIG_CONNECTION_PERSONALIZATION="0"
TARGET_WLAN_CONFIG_CPU_CSTATE_DISABLE_THRESHOLD="100"
TARGET_WLAN_CONFIG_DATA_ACTIVITY_AFFINITY_BOOSTER_THRESHOLD="150"
TARGET_WLAN_CONFIG_DYNAMIC_SWITCH="0"
TARGET_WLAN_CONFIG_L1SS_DISABLE_THRESHOLD="50"
TARGET_WLAN_SUPPORT_80211AX=false
TARGET_WLAN_SUPPORT_80211AX_6GHZ=false
TARGET_WLAN_SUPPORT_APE_SERVICE=false
TARGET_WLAN_SUPPORT_LOWLATENCY=true
TARGET_WLAN_SUPPORT_MBO=true
TARGET_WLAN_SUPPORT_MIMO=true
TARGET_WLAN_SUPPORT_MOBILEAP_5G_BASEDON_COUNTRY=false
TARGET_WLAN_SUPPORT_MOBILEAP_6G=false
TARGET_WLAN_SUPPORT_MOBILEAP_DUALAP=false
TARGET_WLAN_SUPPORT_MOBILEAP_OWE=false
TARGET_WLAN_SUPPORT_MOBILEAP_POWER_SAVEMODE=true
TARGET_WLAN_SUPPORT_MOBILEAP_PRIORITIZE_TRAFFIC=true
TARGET_WLAN_SUPPORT_MOBILEAP_WIFI_CONCURRENCY=true
TARGET_WLAN_SUPPORT_MOBILEAP_WIFISHARING_LITE=false
TARGET_WLAN_SUPPORT_SWITCH_FOR_INDIVIDUAL_APPS=true
TARGET_WLAN_SUPPORT_TWT_CONTROL=false
TARGET_WLAN_SUPPORT_WIFI_TO_CELLULAR=false
