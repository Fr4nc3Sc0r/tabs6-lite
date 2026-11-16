#!/bin/bash
# dexverify.sh <rootfs> <work dir for logs> <list of extra apks, paths inside the rootfs>
# Runs the ROM's own dex2oat (ART verifier) under qemu-user on the boot class
# path, on every system server jar and on the given APKs. A class that fails
# verification is rejected at run time: in framework.jar or services.jar that
# means a system_server crash at boot. The jars and APKs rebuilt by the smali
# patches are the ones at risk.
R="$1"; LOGS="$2"; shift 2
E="$(cd "$(dirname "$0")" && pwd)"
ENVV=(ANDROID_ROOT=/system ANDROID_ART_ROOT=/apex/com.android.art ANDROID_I18N_ROOT=/apex/com.android.i18n ANDROID_TZDATA_ROOT=/apex/com.android.tzdata ANDROID_DATA=/tmp)
sudo chroot "$R" /apex/com.android.sdkext/bin/derive_classpath /tmp/classpath > /dev/null 2>&1
BCP="$(sudo sed -n "s/^export BOOTCLASSPATH //p" "$R/tmp/classpath")"
SSCP="$(sudo sed -n "s/^export SYSTEMSERVERCLASSPATH //p" "$R/tmp/classpath")"
[ "$BCP" ] && [ "$SSCP" ] || { echo "**FAIL**: derive_classpath did not produce the class paths"; exit 0; }
for v in "$BCP" "$SSCP"; do for j in ${v//:/ }; do [ -f "$R$j" ] || echo "**FAIL**: class path jar missing: $j"; done; done
sudo mkdir -p "$R/tmp/b/arm64" "$R/tmp/v"
sudo python3 "$E/fakelogd.py" "$R/dev/socket/logdw" 7200 "$LOGS/dexverify.log" > /dev/null 2>&1 &
LOGPID=$!; python3 -c "import time; time.sleep(2)"
D2O=(/apex/com.android.art/bin/dex2oat64 --compiler-filter=verify --instruction-set=arm64 --instruction-set-features=default --android-root=/system --runtime-arg -Xmx1024m -j"$(nproc)")
ARGS=(); for j in ${BCP//:/ }; do ARGS+=(--dex-file="$j" --dex-location="$j"); done
sudo timeout -s KILL 3000 chroot "$R" /system/bin/env "${ENVV[@]}" BOOTCLASSPATH="$BCP" "${D2O[@]}" "${ARGS[@]}" \
    --image=/tmp/b/arm64/boot.art --oat-file=/tmp/b/arm64/boot.oat --base=0x70000000 --profile-file=/system/etc/boot-image.prof > /dev/null 2>&1
echo "- boot class path ($(tr ':' '\n' <<< "$BCP" | wc -l) jar): dex2oat rc=$?"
# qemu-user cannot fit the generated boot image plus the heap below 4 GiB: for the
# other jars point dex2oat at a boot image that does not exist, so that it loads
# the boot class path from the jars ("imageless"), which verifies the same code
CTX=""; n=0; bad=0
for j in ${SSCP//:/ }; do
    sudo timeout -s KILL 1500 chroot "$R" /system/bin/env "${ENVV[@]}" BOOTCLASSPATH="$BCP" "${D2O[@]}" --dex-file="$j" --dex-location="$j" \
        --boot-image=/tmp/noimage/boot.art --oat-file="/tmp/v/ss$n.odex" --class-loader-context="PCL[$CTX]" > /dev/null 2>&1 || { bad=$((bad + 1)); echo "  **FAIL** dex2oat on $j"; }
    CTX="${CTX:+$CTX:}$j"; n=$((n + 1))
done
echo "- system server class path ($n jar): $bad con errori di dex2oat"
n=0; bad=0
for a in "$@"; do
    h="$R$a"; [[ "$a" == /system_ext/* ]] && h="$R/system$a"
    unzip -l "$h" 2> /dev/null | grep -q "classes.dex" || continue      # resource-only APKs have no code
    sudo timeout -s KILL 1500 chroot "$R" /system/bin/env "${ENVV[@]}" BOOTCLASSPATH="$BCP" "${D2O[@]}" --dex-file="$a" --dex-location="$a" \
        --boot-image=/tmp/noimage/boot.art --oat-file="/tmp/v/apk$n.odex" --class-loader-context="PCL[]" > /dev/null 2>&1 || { bad=$((bad + 1)); echo "  **FAIL** dex2oat on $a"; }
    n=$((n + 1))
done
echo "- APK modificati dalle patch ($n): $bad con errori di dex2oat"
sudo kill "$LOGPID" 2> /dev/null; wait "$LOGPID" 2> /dev/null
HARD="$(grep -ciE "failed verification|Verification error|rejecting class|VerifyError|hard failure" "$LOGS/dexverify.log" || true)"
echo "- classi respinte dal verificatore: $HARD"
[ "$HARD" = "0" ] || grep -iE "failed verification|Verification error|rejecting class|VerifyError|hard failure" "$LOGS/dexverify.log" | cut -c1-240 | head -n 30
echo "- metodi con verifica dei lock fallita (solo più lenti): $(grep -c "failed lock verification" "$LOGS/dexverify.log" || true)"
