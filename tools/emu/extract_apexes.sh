#!/bin/bash
# extract_apexes.sh <work_dir> <out_dir> <tools_bin>: unpack every APEX payload to <out_dir>/<apex name>
W="$1"; OUT="$2"; T="$3"
for a in "$W"/system/system/apex/* "$W"/system/system/system_ext/apex/* "$W"/product/apex/* "$W"/vendor/apex/*; do
    [ -f "$a" ] || continue
    tmp="$(mktemp -d)"
    unzip -q -o "$a" -d "$tmp" 2>/dev/null
    if [ -f "$tmp/original_apex" ]; then mkdir "$tmp/o"; unzip -q -o "$tmp/original_apex" -d "$tmp/o"; src="$tmp/o"; else src="$tmp"; fi
    [ -f "$src/apex_payload.img" ] || { echo "no payload: $(basename "$a")"; rm -rf "$tmp"; continue; }
    name="$(strings -a "$src/apex_manifest.pb" | head -n 1)"
    d="$OUT/$name"; rm -rf "$d"; mkdir -p "$d"
    if [[ "$(xxd -p -s 1024 -l 4 "$src/apex_payload.img")" == "e2e1f5e0" ]]; then
        "$T/fsck.erofs" --extract="$d" --overwrite "$src/apex_payload.img" > /dev/null 2>&1 && fs=erofs || fs="erofs FAILED"
    else
        debugfs -R "rdump / $d" "$src/apex_payload.img" > /dev/null 2>&1 && fs=ext4 || fs="ext4 FAILED"
    fi
    echo "$name [$fs] $(basename "$a")"
    rm -rf "$tmp"
done
