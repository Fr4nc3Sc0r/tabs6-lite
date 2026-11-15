# SPDX-License-Identifier: GPL-3.0-or-later
#
# Debloat list for Samsung Exynos 9611 devices (exynos9611)
# - Add entries inside the specific partition containing that file (<PARTITION>_DEBLOAT+="")
# - DO NOT add the partition name at the start of any entry
# - DO NOT add a slash at the start of any entry

# Overlays that only make sense on the source SoC's Wi-Fi chipset
SYSTEM_DEBLOAT+="
system/app/WifiRROverlayAppLls
"
PRODUCT_DEBLOAT+="
overlay/SoftapOverlayQC
"
