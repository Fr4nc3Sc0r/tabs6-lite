# SPDX-License-Identifier: GPL-3.0-or-later
#
# The stock vendor of the Exynos 9611 tablets has 32-bit HAL processes
# (android.hardware.audio.service, the Samsung camera provider, media.omx,
# Widevine, CAS) and sets ro.zygote=zygote64_32. The Galaxy S26 system has no
# 32-bit linker, no 32-bit bionic and no /system/lib: none of them could start
# and init would look for a 32-bit zygote that does not exist.
#
# The base already solves exactly this for the Galaxy A52s, with 32-bit
# prebuilts built from the AOSP release of the source system. Reuse that
# implementation as is instead of keeping a copy of it here; it only depends
# on the work dir, not on the A52s.
IMPL="$SRC_DIR/target/a52sxq/patches/__desixtification/customize.sh"
[ -f "$IMPL" ] || ABORT "32-bit compatibility implementation not found in the base: ${IMPL//$SRC_DIR\//}"

# The prebuilts must come from the same AOSP build as the source system
PREBUILT_ID="CP2A.260605.016"
SYSTEM_ID="$(GET_PROP "system" "ro.build.id")"
if [[ "$SYSTEM_ID" != "$PREBUILT_ID" ]]; then
    ABORT "32-bit prebuilts are built from $PREBUILT_ID, the source system is $SYSTEM_ID"
fi
unset PREBUILT_ID SYSTEM_ID

# shellcheck disable=SC1090
source "$IMPL"
unset IMPL
