#!/usr/bin/env python3
"""mkprops.py <rootfs> <out file> [extra k=v ...]
Writes a legacy single-file Android property area (what bionic reads when
/dev/__properties__ is a regular file) from the build.prop files of a ROM tree,
in the order and with the precedence init uses."""
import struct, sys, os
root, out = sys.argv[1], sys.argv[2]
props, optional = {}, {}
def load(path):
    p = os.path.join(root, path)
    if not os.path.isfile(p): return
    for line in open(p, errors="replace"):
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("import ") or "=" not in line: continue
        k, v = line.split("=", 1)
        if k.endswith("?"):
            optional.setdefault(k[:-1], v); continue
        if k.startswith("ro.") and k in props: continue      # ro.* : first one wins
        props[k] = v
for f in ("system/build.prop", "system/system_ext/etc/build.prop", "vendor/default.prop", "vendor/build.prop",
          "vendor/odm/etc/build.prop", "odm/etc/build.prop", "product/etc/build.prop"):
    load(f)
for k, v in optional.items(): props.setdefault(k, v)
for kv in sys.argv[3:]:
    k, v = kv.split("=", 1); props[k] = v
# derived like init does
def first(*keys):
    for k in keys:
        if props.get(k): return props[k]
for suffix in ("", "32", "64"):
    k = "ro.product.cpu.abilist" + suffix
    if k not in props:
        vals = [props.get("ro.%s.product.cpu.abilist%s" % (p, suffix), "") for p in ("vendor", "odm")]
        vals = [v for v in vals if v] or [props.get("ro.system.product.cpu.abilist" + suffix, "")]
        props[k] = vals[0]

HDR = 128
data = bytearray()
def align(n): return (n + 3) & ~3
def new_bt(name):
    off = len(data); nb = name.encode()
    data.extend(struct.pack("<5I", len(nb), 0, 0, 0, 0) + nb + b"\0")
    data.extend(b"\0" * (align(len(data)) - len(data)))
    return off
def get(off, i): return struct.unpack_from("<I", data, off + 4 * i)[0]
def put(off, i, v): struct.pack_into("<I", data, off + 4 * i, v)
def name_of(off):
    n = get(off, 0); return bytes(data[off + 20: off + 20 + n])
def cmp(a, b): return (len(a) > len(b)) - (len(a) < len(b)) or (a > b) - (a < b)
def find_or_add(parent_field_off, parent_field_idx, name):
    cur = get(parent_field_off, parent_field_idx)
    if cur == 0:
        n = new_bt(name.decode()); put(parent_field_off, parent_field_idx, n); return n
    while True:
        c = cmp(name, name_of(cur))
        if c == 0: return cur
        idx = 2 if c < 0 else 3
        nxt = get(cur, idx)
        if nxt == 0:
            n = new_bt(name.decode()); put(cur, idx, n); return n
        cur = nxt
root_bt = new_bt("")
skipped = 0
for k in sorted(props):
    v = props[k].encode(); kb = k.encode()
    cur = root_bt
    for part in k.split("."):
        if not part: break
        cur = find_or_add(cur, 4, part.encode())
    else:
        off = len(data)
        if len(v) < 92:
            data.extend(struct.pack("<I", len(v) << 24) + v.ljust(92, b"\0") + kb + b"\0")
            data.extend(b"\0" * (align(len(data)) - len(data)))
        else:
            msg = b"Must use __system_property_read_callback() to read"
            base = align(4 + 92 + len(kb) + 1)
            blob = struct.pack("<I", (len(msg) << 24) | (1 << 16)) + msg.ljust(56, b"\0") + struct.pack("<I", base) + b"\0" * 32 + kb + b"\0"
            blob = blob.ljust(base, b"\0") + v + b"\0"
            data.extend(blob); data.extend(b"\0" * (align(len(data)) - len(data)))
        put(cur, 1, off)
        continue
    skipped += 1
size = max(HDR + len(data), 128 * 1024)
buf = struct.pack("<4I", len(data), 0, 0x504f5250, 0xfc6ed0ab) + b"\0" * (28 * 4) + bytes(data)
open(out, "wb").write(buf.ljust(size, b"\0"))
print("properties written:", len(props) - skipped, "size:", size)
