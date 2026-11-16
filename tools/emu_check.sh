#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Checks a built ROM on the PC, without the tablet. There is no emulator of the
# Exynos 9611 board, so the kernel and the hardware cannot be tried; what can be
# tried is the userspace, by running the ARM programs of the ROM under
# qemu-user in a chroot assembled from the work dir:
#
#   1. the ROM's own linkerconfig generates the linker configuration
#   2. the ROM's own secilc compiles system + vendor SELinux policy, as init
#      does at boot (the precompiled policy never matches on a port)
#   3. every label used in the *_contexts files must exist in the policy;
#      every HAL of the vendor manifest must still have a client in the system
#   4. every executable of system and vendor is started with LD_BIND_NOW=1:
#      a missing library or symbol shows up as "CANNOT LINK EXECUTABLE"
#   5. every library (also the dlopen()ed ones) must find its dependencies
#      and symbols; for the vendor the result is compared with the same check
#      on the stock firmware, to list only what the port broke
#   6. the ROM's own dex2oat verifies the bytecode of the boot class path, of
#      the system server jars and of the APKs rebuilt by the patches
#
# Usage: tools/emu_check.sh            (after ./build.sh, needs sudo)
# Needs: qemu-user-static (with binfmt), python3, binutils, e2fsprogs.
# Report: un1ca/out/emu_check-report.md
set -eo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(cd "$HERE/.." && pwd)/un1ca"
[ -d "$BASE/out" ] || BASE="$(cd "$HERE/.." && pwd)"            # when run from un1ca/tabs6-tools
OUT="$BASE/out"
W="$OUT/target/gta4xlwifi/work_dir"
STOCK="$(find "$OUT/fw" -maxdepth 1 -type d -name "SM-P610_*" | head -n 1)"
TOOLS="$OUT/tools/bin"
EMU="$OUT/emu"; R="$EMU/rootfs"; E="$HERE/emu"
REPORT="$OUT/emu_check-report.md"
[ -d "$W/system/system" ] || { echo "Work dir not found: build the ROM first" >&2; exit 1; }
for b in qemu-aarch64-static qemu-arm-static python3 readelf debugfs; do
    type "$b" > /dev/null 2>&1 || { echo "Missing host tool: $b" >&2; exit 1; }
done

teardown() {
    mount | awk -v r="$R" '$3 ~ "^"r {print $3}' | sort -r | while read -r m; do sudo umount "$m" || true; done
}
# EMU_KEEP=1 leaves the chroot mounted at the end (un1ca/out/emu/rootfs), for manual experiments
[ "${EMU_KEEP:-}" ] || trap teardown EXIT
teardown
mkdir -p "$R" "$EMU/apexes" "$EMU/stock/apex"

echo "- Unpacking APEX modules"
rm -rf "$EMU/apexes"; mkdir -p "$EMU/apexes"
"$E/extract_apexes.sh" "$W" "$EMU/apexes" "$TOOLS" > "$EMU/apexes.log"
(cd "$EMU/apexes" && for d in *; do n="$(sed -E 's/^[^a-z]+//' <<< "$d")"; [ "$n" = "$d" ] || mv "$d" "$n"; done)
! grep -q "FAILED\|no payload" "$EMU/apexes.log" || { echo "Some APEX could not be unpacked, see $EMU/apexes.log" >&2; exit 1; }

echo "- Assembling the root filesystem"
sudo mount --bind "$W/system" "$R"; sudo mount -o remount,bind,ro "$R"
for p in vendor product odm; do sudo mount --bind "$W/$p" "$R/$p"; sudo mount -o remount,bind,ro "$R/$p"; done
for t in apex linkerconfig tmp dev; do sudo mount -t tmpfs tmpfs "$R/$t"; done
sudo mount -t proc proc "$R/proc"
sudo mknod -m 666 "$R/dev/null" c 1 3; sudo mknod -m 666 "$R/dev/zero" c 1 5
sudo mknod -m 666 "$R/dev/urandom" c 1 9; sudo mknod -m 666 "$R/dev/random" c 1 8
{
    echo '<?xml version="1.0" encoding="utf-8"?>'; echo '<apex-info-list>'
    for d in "$EMU/apexes"/*; do
        n="$(basename "$d")"; sudo mkdir -p "$R/apex/$n"; sudo mount --bind -o ro "$d" "$R/apex/$n"
        f="$(grep -l -a -m1 "$n" "$W"/system/system/apex/* "$W"/system/system/system_ext/apex/* "$W"/product/apex/* "$W"/vendor/apex/* 2> /dev/null | head -n 1)"
        case "$f" in
            */system_ext/apex/*) part=SYSTEM_EXT; path="/system_ext/apex/$(basename "$f")" ;;
            */product/apex/*) part=PRODUCT; path="/product/apex/$(basename "$f")" ;;
            */vendor/apex/*) part=VENDOR; path="/vendor/apex/$(basename "$f")" ;;
            *) part=SYSTEM; path="/system/apex/$(basename "${f:-$n.apex}")" ;;
        esac
        echo "    <apex-info moduleName=\"$n\" modulePath=\"$path\" preinstalledModulePath=\"$path\" versionCode=\"1\" versionName=\"1\" isFactory=\"true\" isActive=\"true\" lastUpdateMillis=\"0\" provideSharedApexLibs=\"false\" partition=\"$part\"/>"
    done
    echo '</apex-info-list>'
} > "$EMU/apex-info-list.xml"
sudo cp "$EMU/apex-info-list.xml" "$R/apex/apex-info-list.xml"
python3 "$E/mkprops.py" "$R" "$EMU/props.bin" > /dev/null
sudo cp "$EMU/props.bin" "$R/dev/__properties__"; sudo chown 0:0 "$R/dev/__properties__"; sudo chmod 444 "$R/dev/__properties__"
[[ "$(sudo chroot "$R" /system/bin/getprop ro.build.version.release 2> /dev/null)" ]] || { echo "The ROM's getprop does not run under qemu-user" >&2; exit 1; }

if [ "${EMU_ONLY_ROOTFS:-}" ]; then sudo chroot "$R" /apex/com.android.runtime/bin/linkerconfig --target /linkerconfig > /dev/null 2>&1 || true; echo "Chroot ready: $R"; exit 0; fi
{
echo "# Verifica della ROM in emulazione (qemu-user)"
echo
echo "Generato da \`tools/emu_check.sh\` il $(date +%F). Android $(sudo chroot "$R" /system/bin/getprop ro.build.version.release 2> /dev/null), vendor VNDK $(sudo chroot "$R" /system/bin/getprop ro.vndk.version 2> /dev/null), zygote \`$(sudo chroot "$R" /system/bin/getprop ro.zygote 2> /dev/null)\`."
echo
echo "## 1. Configurazione del linker"
sudo chroot "$R" /apex/com.android.runtime/bin/linkerconfig --target /linkerconfig > "$EMU/linkerconfig.log" 2>&1 || true
if [ -s "$R/linkerconfig/ld.config.txt" ]; then echo "ok: \`ld.config.txt\` generato, $(wc -l < "$R/linkerconfig/ld.config.txt") righe"; else echo "**FAIL**: linkerconfig non ha prodotto \`ld.config.txt\`"; fi
echo
echo "## 2. Compilazione della policy SELinux"
VERS="$(head -n 1 "$R/vendor/etc/selinux/plat_sepolicy_vers.txt")"
S1=/system/etc/selinux; S2=/system/system_ext/etc/selinux; S3=/product/etc/selinux; ARGS=()
for f in "$S1/mapping/$VERS.compat.cil" "$S2/system_ext_sepolicy.cil" "$S2/mapping/$VERS.cil" "$S2/mapping/$VERS.compat.cil" "$S3/product_sepolicy.cil" "$S3/mapping/$VERS.cil" \
        /vendor/etc/selinux/plat_pub_versioned.cil /vendor/etc/selinux/vendor_sepolicy.cil /odm/etc/selinux/odm_sepolicy.cil; do
    [ -f "$R$f" ] && ARGS+=("$f")
done
sudo cp "$R/system/bin/secilc" "$R/tmp/secilc"; sudo chmod 755 "$R/tmp/secilc"
if sudo chroot "$R" /tmp/secilc "$S1/plat_sepolicy.cil" -m -M true -G -N -c 30 "$S1/mapping/$VERS.cil" -o /tmp/sepolicy -f /dev/null "${ARGS[@]}" > "$EMU/secilc.log" 2>&1 && [ -s "$R/tmp/sepolicy" ]; then
    echo "ok: policy $VERS compilata con il \`secilc\` della ROM ($(stat -c %s "$R/tmp/sepolicy") byte)"
else
    echo "**FAIL**: la policy non si compila"; echo '```'; grep -v "linker" "$EMU/secilc.log" | tail -n 15; echo '```'
fi
echo
echo "## 3. Etichette SELinux"
echo '```'; python3 "$E/ctxcheck.py" "$R" "$VERS"; echo '```'
echo
echo "## 3b. Client dei servizi hardware (HAL) del vendor"
echo '```'; python3 "$E/halcheck.py" "$W" "$EMU/apexes"; echo '```'
echo
echo "## 4. Avvio dei programmi con LD_BIND_NOW=1"
"$E/linktest.sh" "$R" /vendor/bin/hw /vendor/bin /odm/bin > "$EMU/linktest_vendor.txt" 2>&1
"$E/linktest.sh" "$R" /system/bin /system/system_ext/bin /product/bin > "$EMU/linktest_system.txt" 2>&1
for k in vendor system; do
    echo "- $k: $(grep -c '^ok' "$EMU/linktest_$k.txt") ok, $(grep -c '^FAIL' "$EMU/linktest_$k.txt") non collegabili"
done
if grep -q "^FAIL" "$EMU/linktest_vendor.txt" "$EMU/linktest_system.txt"; then echo; echo '```'; grep -h -A1 "^FAIL" "$EMU/linktest_vendor.txt" "$EMU/linktest_system.txt" | grep -v "^--" | cut -c1-260; echo '```'; fi
echo
echo "## 5. Dipendenze e simboli di tutte le librerie"
VDIRS64="vendor/lib64 vendor/lib64/hw vendor/lib64/egl vendor/lib64/soundfx vendor/lib64/mediadrm vendor/lib64/camera vendor/bin vendor/bin/hw odm/lib64"
VDIRS32="vendor/lib vendor/lib/hw vendor/lib/egl vendor/lib/soundfx vendor/lib/mediadrm vendor/lib/mediacas vendor/lib/camera vendor/lib/omx vendor/bin vendor/bin/hw"
python3 "$E/symcheck.py" "$R" 64 system/lib64 system/system_ext/lib64 product/lib64 system/bin system/system_ext/bin > "$EMU/sym_system64.txt"
python3 "$E/symcheck.py" "$R" 64 $VDIRS64 > "$EMU/sym_vendor64.txt"
python3 "$E/symcheck.py" "$R" 32 $VDIRS32 > "$EMU/sym_vendor32.txt"
echo "- sistema 64 bit: $(tail -n 1 "$EMU/sym_system64.txt")"
echo "- vendor 64 bit: $(tail -n 1 "$EMU/sym_vendor64.txt")"
echo "- vendor 32 bit: $(tail -n 1 "$EMU/sym_vendor32.txt")"
if [ "$STOCK" ]; then
    if [ ! -d "$EMU/stock/apex/com.android.runtime" ]; then
        "$E/extract_apexes.sh" "$STOCK" "$EMU/stock/apex" "$TOOLS" > "$EMU/stock_apexes.log"
        (cd "$EMU/stock/apex" && for d in *; do n="$(sed -E 's/^[^a-z]+//' <<< "$d")"; [ "$n" = "$d" ] || mv "$d" "$n"; done)
    fi
    ln -sfn "$STOCK/system/system" "$EMU/stock/system"; for p in vendor product odm; do ln -sfn "$STOCK/$p" "$EMU/stock/$p"; done
    python3 "$E/symcheck.py" "$EMU/stock" 64 $VDIRS64 > "$EMU/stock_sym_vendor64.txt"
    python3 "$E/symcheck.py" "$EMU/stock" 32 $VDIRS32 > "$EMU/stock_sym_vendor32.txt"
    echo
    echo "Oggetti del vendor che falliscono nel port ma non nel firmware stock:"
    echo '```'
    for b in 64 32; do
        comm -23 <(grep "^FAIL" "$EMU/sym_vendor$b.txt" | cut -d " " -f 2 | sort) <(grep "^FAIL" "$EMU/stock_sym_vendor$b.txt" | cut -d " " -f 2 | sort) | while read -r o; do
            grep -F "FAIL $o " "$EMU/sym_vendor$b.txt" | cut -c1-240
        done
    done
    echo '```'
fi
echo
echo "## 6. Verifica del bytecode con il dex2oat della ROM"
# the APKs and jars the patches rebuilt with apktool are listed in the apktool work dir
PATCHED=()
while IFS= read -r d; do PATCHED+=("/${d#"$OUT/target/gta4xlwifi/apktool/"}"); done < <(find "$OUT/target/gta4xlwifi/apktool" -mindepth 3 -maxdepth 4 -type d -name "*.apk" 2> /dev/null)
"$E/dexverify.sh" "$R" "$EMU" "${PATCHED[@]}"
echo
echo "Fallimenti nel sistema (64 bit):"
echo '```'; grep "^FAIL" "$EMU/sym_system64.txt" | cut -c1-240 | head -n 40; echo '```'
} > "$REPORT"
echo "Report: $REPORT"
