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

# The S26 product partition sets it again and init lets /product override
# /system ("Overriding previous property 'ro.build.characteristics':'tablet'
# with new value 'phone'" in the boot log of the virtual tablet).
SET_PROP "product" "ro.build.characteristics" "tablet"

# Samsung's init takes the product identity from the first partition of
# ro.product.property_source_order, which is /odm, and /odm is the source
# phone's: without this the tablet boots as "SM-S942B" / "m1sxxx". Use the
# identity of the stock /odm of the tablet.
STOCK_ODM_PROP="$FW_DIR/$(cut -d "/" -f 1 -s <<< "$TARGET_FIRMWARE")_$(cut -d "/" -f 2 -s <<< "$TARGET_FIRMWARE")/odm/etc/build.prop"
[ -f "$STOCK_ODM_PROP" ] || ABORT "Stock odm build.prop not found: ${STOCK_ODM_PROP//$SRC_DIR\//}"
for p in brand device manufacturer model name; do
    v="$(GET_PROP "$STOCK_ODM_PROP" "ro.product.odm.$p")"
    [ "$v" ] || ABORT "ro.product.odm.$p not found in the stock odm build.prop"
    SET_PROP "odm" "ro.product.odm.$p" "$v"
done
unset STOCK_ODM_PROP p v
