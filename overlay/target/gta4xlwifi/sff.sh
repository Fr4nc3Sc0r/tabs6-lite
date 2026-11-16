# SPDX-License-Identifier: GPL-3.0-or-later
#
# SEC Floating Feature overrides for Galaxy Tab S6 Lite (gta4xlwifi)
#
# The base already merges the stock floating_feature.xml of the tablet into the
# One UI 9 one (unica/patches/__floating_feature): features the tablet declares
# keep the tablet value (S Pen, tablet layout, speakers, display...), features
# only the source phone declares are dropped. Only add here what must differ
# from BOTH files. Format: SEC_FLOATING_FEATURE_NAME=value (empty = delete).

SEC_FLOATING_FEATURE_SETTINGS_CONFIG_BRAND_NAME=Galaxy Tab S6 Lite

# The base always keeps the source phone's always-on display feature list. The
# tablet has an LCD panel and no always-on display: its stock firmware does not
# declare this feature at all, so drop it (it also needs phone-only resources).
SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_AOD_ITEM=

# S Pen direct writing (write with the pen in any text field). The base treats
# this feature as deprecated and drops it, but the One UI 9 framework still
# reads it (ViewRune.SUPPORT_DIRECT_WRITING), and so do SystemUI and
# SettingsProvider. Stock value of the tablet.
SEC_FLOATING_FEATURE_SIP_SUPPORT_DIRECT_WRITING_ENABLE=TRUE
