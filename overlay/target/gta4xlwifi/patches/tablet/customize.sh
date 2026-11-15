# SPDX-License-Identifier: GPL-3.0-or-later

# Stock value on every Samsung tablet, "phone" in the S26 source firmware.
# This is the switch read by the framework (and by a long list of Samsung
# apps) to decide between the phone and the tablet behaviour.
SET_PROP "system" "ro.build.characteristics" "tablet"

# /odm comes from the source phone and describes ITS hardware (NFC, eSE, UWB,
# telephony...). None of it exists on the tablet: drop the HAL manifests and
# feature declarations it carries, exactly as the Exynos 9611 A51 port does.
DELETE_FROM_WORK_DIR "odm" "etc/vintf"
DELETE_FROM_WORK_DIR "odm" "etc/permissions"
