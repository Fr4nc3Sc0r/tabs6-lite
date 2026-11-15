# SPDX-License-Identifier: GPL-3.0-or-later
#
# Debloat list for Galaxy Tab S6 Lite (gta4xlwifi)
# - Add entries inside the specific partition containing that file (<PARTITION>_DEBLOAT+="")
# - DO NOT add the partition name at the start of any entry
# - DO NOT add a slash at the start of any entry
# - Entries that do not exist in the source firmware are silently skipped
#
# The super partition of this tablet is only 6.13 GiB (6585057280 bytes), the
# smallest of every device the base supports. If the build stops with an
# "exceeds the super/group size" error, run tools/size_report.sh to list the
# biggest directories of the work dir and add the ones you can live without
# below. Do NOT remove telephony packages (TeleService, TelephonyUI,
# SecTelephonyProvider...): the framework of a phone firmware expects them even
# on a Wi-Fi only device. See docs/06-troubleshooting.md, "La ROM non entra".

SYSTEM_DEBLOAT+="
"
PRODUCT_DEBLOAT+="
"
