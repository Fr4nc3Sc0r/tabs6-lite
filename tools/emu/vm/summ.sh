#!/bin/bash
# summ.sh <console log>: condensed view of a virtual boot
L="$1"
echo "== last line: $(tail -n 1 "$L" | cut -c1-110)"
echo "== milestones"
for k in "init second stage started" "ueventd started" "apexd-bootstrap: .*[Aa]ctivat\|Bootstrap apexes are ready\|apexd.status" "starting service 'servicemanager'" "starting service 'hwservicemanager'" "starting service 'zygote'" "starting service 'surfaceflinger'" "starting service 'netbpfload'\|starting service 'bpfloader'" "sys.boot_completed\|Boot is completed\|bootanim.exit" "post-fs-data" "processing action (late-init)" "zygote-start" "system_server"; do
    grep -m1 -n "$k" "$L" | sed -E 's/^([0-9]+):\[ *([0-9.]+)\][^]]*\] /  \2s /' | cut -c1-170
done
echo "== services that exited (count, last status)"
grep -o "Service '[^']*' (pid [0-9]*) \(exited with status [0-9]*\|received signal [0-9]*\)" "$L" | sed -E 's/ \(pid [0-9]*\)//' | sort | uniq -c | sort -rn | head -40
echo "== critical / reboot / panic"
grep -n -i "critical process\|rebooting\|reboot,\|Kernel panic\|Unable to handle kernel\|kernel BUG\|init: Reboot\|shutdown" "$L" | cut -c1-200 | head -12
echo "== could not start"
grep -o "init: .*\(Could not start\|cannot execute\|No such file\|failed to exec\|File .* does not exist\)[^$]*" "$L" | grep -v "Unable to read config\|Cannot expand" | cut -c1-200 | sort | uniq -c | sort -rn | head -20
echo "== avc denials by scontext/tclass (enforcing)"
grep -o "avc:  denied  {[^}]*} .*" "$L" | sed -E 's/.*denied  (\{[^}]*\}).*scontext=u:r:([^:]*):.*tcontext=u:(object_r|r):([^:]*):.*tclass=([a-z_0-9]*).*/\2 -> \4 \5 \1/' | sort | uniq -c | sort -rn | head -40
