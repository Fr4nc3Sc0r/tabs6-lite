#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Boots the built ROM in a "virtual tablet": QEMU's generic arm64 machine with
# the tablet's own kernel source (same configuration plus virtio drivers) and
# the ROM's system, vendor, product and odm images. None of the tablet's
# hardware exists there, so this does NOT show whether display, Wi-Fi, audio or
# the TEE work. It does run, for real, everything that comes before them:
# first stage init, mounting the EROFS images, compiling and loading the
# SELinux policy in the 4.14 kernel, second stage init with every .rc file,
# ueventd, apexd, linkerconfig, cgroups, the BPF loaders, servicemanager and
# the start of zygote. Those are where a port to a new Android version breaks.
#
# VM-only changes (never part of the ROM), all applied to copies:
#   - kernel: one change to exynos-topology.c (below), kernel-virt.fragment and the
#     Samsung initcalls of initcall-blacklist.txt skipped (they need the SoC)
#   - fstab: virtio disks, no AVB, no dynamic partitions
#   - vendor: no wait for the TEE daemons, no Wi-Fi MAC loader
#   - system: no wait for keystore/odsign (they need the TEE-backed keymaster),
#     a service that copies logcat to the serial console
#
# Usage: tools/vm_boot.sh [seconds, default 600]      (after ./build.sh; needs sudo)
# Needs: qemu-system-arm, the kernel build dependencies, e2fsprogs.
# Output: un1ca/out/emu/vm/console.log and un1ca/out/vm_boot-report.md
set -eo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(cd "$HERE/.." && pwd)/un1ca"; [ -d "$BASE/out" ] || BASE="$(cd "$HERE/.." && pwd)"
OUT="$BASE/out"; W="$OUT/target/gta4xlwifi/work_dir"; T="$OUT/tools/bin"
KC="$OUT/kernel-cache"; KSRC="$KC/universal9611"; KOUT="$KC/universal9611-out-gta4xlwifi"
V="$OUT/emu/vm"; E="$HERE/emu/vm"; SECS="${1:-600}"
[ -d "$W/system/system" ] && [ -f "$KOUT/.config" ] || { echo "Build the ROM first (./build.sh)" >&2; exit 1; }
type qemu-system-aarch64 > /dev/null 2>&1 || { echo "Missing qemu-system-aarch64 (apt install qemu-system-arm)" >&2; exit 1; }
mkdir -p "$V"
MKFS=("$T/mkfs.erofs" -z lz4hc,9 -C 65536 -b 4096 -T 1640995200)

echo "- Kernel for the virt machine"
if [ ! -f "$KC/virt2/arch/arm64/boot/Image" ] || [ "$KOUT/.config" -nt "$KC/virt2/arch/arm64/boot/Image" ]; then
    rsync -a --delete "$KSRC/" "$KC/virt-src/"
    python3 - "$KC/virt-src/drivers/soc/samsung/exynos-topology.c" << 'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = '\t\tpr_err("CPU topology isn\'t composed properly\\n");\n\t\tBUG_ON(cpuid_topo->cluster_id);\n'
new = '\t\t/* virt machine: no Exynos cpu-map, one flat cluster */\n\t\tcpuid_topo->cluster_id = 0;\n\t\tcpuid_topo->coregroup_id = 0;\n\t\tcpuid_topo->core_id = cpuid;\n'
assert old in s, "exynos-topology.c changed: update the replacement in tools/vm_boot.sh"
open(p, "w").write(s.replace(old, new))
PY
    mkdir -p "$KC/virt2"; cp "$KOUT/.config" "$KC/virt2/.config"
    MA=(O="$KC/virt2" ARCH=arm64 LLVM=1 LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-)
    (cd "$KC/virt-src" && scripts/kconfig/merge_config.sh -m -O "$KC/virt2" "$KC/virt2/.config" "$E/kernel-virt.fragment" > "$V/kernel-config.log" 2>&1 \
        && make "${MA[@]}" olddefconfig >> "$V/kernel-config.log" 2>&1 && make "${MA[@]}" -j"$(nproc)" Image > "$V/kernel-build.log" 2>&1) \
        || { echo "Kernel build failed, see $V/kernel-build.log" >&2; exit 1; }
fi

echo "- Images"
for p in product odm; do
    "${MKFS[@]}" --mount-point "$p" --fs-config-file "$W/configs/fs_config-$p" --file-contexts "$W/configs/file_context-$p" "$V/$p.img" "$W/$p" > "$V/mkfs_$p.log" 2>&1
done
mkdir -p "$V/vendor_tree"; rsync -a --delete "$W/vendor/" "$V/vendor_tree/"
cp "$E/fstab.vm" "$V/vendor_tree/etc/fstab.exynos9611"
python3 - "$V/vendor_tree/etc/init" << 'PY'
import sys, os
d = sys.argv[1]
p = os.path.join(d, "teegris.rc"); s = open(p).read()
s = s.replace("    start tz_service\n    wait_for_prop vendor.tzdaemon Ready\n", "    # VM: no TEE\n")
s = s.replace("    start tzts_service\n    wait_for_prop vendor.tzts_daemon Ready\n", "")
open(p, "w").write(s)
p = os.path.join(d, "init.exynos9611.rc"); s = open(p).read()
open(p, "w").write(s.replace("    wait /dev/block/platform/13520000.ufs/by-name/sec_efs\n", ""))
# macloader reads the MAC address from the Wi-Fi chip through sysfs: without the
# chip the Samsung driver oopses and takes the rest of the boot with it
p = os.path.join(d, "wifi.rc"); s = open(p).read()
open(p, "w").write(s.replace("    start macloader\n", "    # VM: no Wi-Fi chip\n"))
PY
"${MKFS[@]}" --mount-point vendor --fs-config-file "$W/configs/fs_config-vendor" --file-contexts "$W/configs/file_context-vendor" "$V/vendor.img" "$V/vendor_tree" > "$V/mkfs_vendor.log" 2>&1
mkdir -p "$V/sys_upper/system/etc/init/hw" "$V/sys_work" "$V/sys_merged"
python3 - "$W/system/system/etc/init/hw/init.rc" "$V/sys_upper/system/etc/init/hw/init.rc" << 'PY'
import sys
s = open(sys.argv[1]).read()
for a, b in (("    exec - system system -- /system/bin/vdc keymaster earlyBootEnded\n", "    # VM: no keymaster HAL without the TEE\n"),
             ("    wait_for_prop keystore.module_hash.sent true\n", "    # VM: no keystore\n"),
             ("    start odsign\n", "    # VM: odsign needs keystore\n    setprop odsign.key.done 1\n    setprop odsign.verification.done 1\n    setprop odsign.verification.success 0\n")):
    assert s.count(a) == 1, "init.rc changed: " + a.strip()
    s = s.replace(a, b)
# VM only: copy the Android log to the serial console, to see zygote and system_server
s += """
service vm_logcat /system/bin/sh -c "exec /system/bin/logcat -v threadtime -b main,system,crash -f /data/local/tmp/vm_logcat.txt *:I"
    user shell
    group shell log readproc
    seclabel u:r:shell:s0
    disabled
    oneshot

on zygote-start
    start vm_logcat
"""
open(sys.argv[2], "w").write(s)
PY
umount_merged() { mountpoint -q "$V/sys_merged" && sudo umount "$V/sys_merged" || true; }
trap umount_merged EXIT
umount_merged
sudo mount -t overlay overlay -o "lowerdir=$W/system,upperdir=$V/sys_upper,workdir=$V/sys_work" "$V/sys_merged"
sudo "${MKFS[@]}" --mount-point / --fs-config-file "$W/configs/fs_config-system" --file-contexts "$W/configs/file_context-system" "$V/system.img" "$V/sys_merged" > "$V/mkfs_system.log" 2>&1
sudo chown "$(id -u):$(id -g)" "$V/system.img"; umount_merged
mkdir -p "$V/rd" "$V/boot"
"$T/unpack_bootimg" --boot_img "$W/kernel/boot.img" --out "$V/boot" > "$V/boot/info.txt"
(cd "$V/rd" && { gzip -dc ../boot/ramdisk 2> /dev/null || lz4 -dc ../boot/ramdisk; } | sudo cpio -id --quiet -u \
    && sudo cp "$E/fstab.vm" ./fstab.exynos9611 && sudo find . | sudo cpio -o -H newc --quiet | gzip -1 > ../ramdisk.vm.gz)
for i in metadata cache efs; do truncate -s 0 "$V/$i.img"; truncate -s 64M "$V/$i.img"; mkfs.ext4 -q -F "$V/$i.img"; done
truncate -s 0 "$V/userdata.img"; truncate -s 6G "$V/userdata.img"; mkfs.ext4 -q -F "$V/userdata.img"

echo "- Booting for $SECS seconds"
DRIVES=(); n=4
for d in system:on vendor:on product:on odm:on metadata:off userdata:off cache:off efs:off; do
    DRIVES+=(-drive "if=none,file=$V/${d%%:*}.img,format=raw,id=d$n,readonly=${d##*:}" -device "virtio-blk-pci,drive=d$n,addr=0x$(printf %x $n)"); n=$((n + 1))
done
timeout -s KILL "$SECS" qemu-system-aarch64 -M virt,gic-version=3 -cpu cortex-a53 -smp 4 -m 4096 \
    -kernel "$KC/virt2/arch/arm64/boot/Image" -initrd "$V/ramdisk.vm.gz" \
    -append "console=ttyAMA0 earlycon=pl011,0x9000000 panic=-1 loglevel=7 printk.devkmsg=on initcall_blacklist=$(paste -sd, "$E/initcall-blacklist.txt") loop.max_part=7 androidboot.console=ttyAMA0 androidboot.hardware=exynos9611 androidboot.serialno=VIRT00000000 androidboot.bootloader=P610VIRT androidboot.verifiedbootstate=orange androidboot.em.model=SM-P610 androidboot.sales_code=ITV" \
    "${DRIVES[@]}" -netdev user,id=n0 -device virtio-net-pci,netdev=n0 -nographic -no-reboot > "$V/console.log" 2>&1 || true
debugfs -c -R "cat /local/tmp/vm_logcat.txt" "$V/userdata.img" > "$V/logcat.txt" 2> /dev/null || true
{
    echo "# Avvio della ROM nel tablet virtuale (QEMU)"; echo
    echo "Generato da \`tools/vm_boot.sh\` il $(date +%F), $SECS secondi di esecuzione. Log completo: \`out/emu/vm/console.log\`."; echo
    echo '```'; "$E/summ.sh" "$V/console.log" | cut -c1-200; echo '```'
    echo; echo "## Log di Android (\`out/emu/vm/logcat.txt\`, $(wc -l < "$V/logcat.txt") righe)"; echo
    echo "Errori fatali e crash:"; echo '```'
    grep -E " F |FATAL EXCEPTION|AndroidRuntime|Abort message|>>> .* <<<|VerifyError|NoClassDefFoundError|UnsatisfiedLinkError|CANNOT LINK" "$V/logcat.txt" | cut -c1-220 | head -n 60 || true
    echo '```'
} > "$OUT/vm_boot-report.md"
echo "Report: $OUT/vm_boot-report.md"
