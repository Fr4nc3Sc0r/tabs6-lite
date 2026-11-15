#!/bin/bash
# linktest.sh <rootfs> <dir inside rootfs>...: start every ELF executable with LD_BIND_NOW=1 and report link failures
R="$1"; shift
for d in "$@"; do
  for f in "$R$d"/*; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    [[ "$(head -c 4 "$f" | xxd -p)" == "7f454c46" ]] || continue
    p="${f#"$R"}"
    out="$(sudo timeout -s KILL 6 chroot "$R" /system/bin/env LD_BIND_NOW=1 "$p" < /dev/null 2>&1 | head -c 3000)"
    if grep -q "CANNOT LINK\|cannot locate symbol\|not found: needed by\|is not accessible for the namespace" <<< "$out"; then
        echo "FAIL $p"; grep -m 3 "CANNOT LINK\|cannot locate\|not found\|not accessible" <<< "$out" | cut -c1-300 | sed 's/^/     /'
    else
        echo "ok   $p"
    fi
  done
done
