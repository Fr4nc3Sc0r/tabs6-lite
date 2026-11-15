#!/usr/bin/env python3
"""symcheck.py <rootfs> <bits: 64|32> [dir ...]
For every shared library and executable in the given dirs: every DT_NEEDED must
exist and every non-weak undefined symbol must be defined somewhere in the
transitive closure of its dependencies. Approximates what the Android linker
does with LD_BIND_NOW, also for libraries that are only dlopen()ed."""
import subprocess, sys, os, glob, functools
from concurrent.futures import ThreadPoolExecutor
R, bits = sys.argv[1], sys.argv[2]
lib = "lib64" if bits == "64" else "lib"
cls = 2 if bits == "64" else 1
search = [f"{R}/system/{lib}", f"{R}/system/system_ext/{lib}", f"{R}/product/{lib}", f"{R}/system/{lib}/bootstrap"] + sorted(glob.glob(f"{R}/apex/*/{lib}")) + sorted(glob.glob(f"{R}/apex/*/{lib}/bionic"))
vsearch = [f"{R}/vendor/{lib}", f"{R}/vendor/{lib}/hw", f"{R}/vendor/{lib}/egl", f"{R}/odm/{lib}", f"{R}/apex/com.android.vndk.v33/{lib}"] + search
def is_elf(p):
    try:
        with open(p, "rb") as f: h = f.read(5)
        return h[:4] == b"\x7fELF" and h[4] == cls
    except OSError: return False
@functools.lru_cache(None)
def info(p):
    d = subprocess.run(["readelf", "-dW", p], capture_output=True, text=True).stdout
    needed = [l.split("[")[1].split("]")[0] for l in d.splitlines() if "(NEEDED)" in l]
    s = subprocess.run(["readelf", "--dyn-syms", "-W", p], capture_output=True, text=True).stdout
    defs, undef = set(), set()
    for l in s.splitlines():
        f = l.split()
        if len(f) < 8 or not f[0].rstrip(":").isdigit(): continue
        # host readelf prints IFUNC as "<OS specific>: 10", so count from the end
        name, ndx = f[-1].split("@")[0], f[-2]
        if ndx == "UND":
            if "WEAK" not in f[3:-2] and name: undef.add(name)
        else: defs.add(name)
    return needed, defs, undef
def resolve(q, depth=0):
    # follow symlinks the way the device would: absolute targets are relative to the rootfs
    while os.path.islink(q) and depth < 10:
        t = os.readlink(q); depth += 1
        q = os.path.join(R, t.lstrip("/")) if t.startswith("/") else os.path.join(os.path.dirname(q), t)
    return q if os.path.isfile(q) else None
def find(n, paths):
    for d in paths:
        q = resolve(os.path.join(d, n))
        if q: return q
def check(p):
    paths = vsearch if "/vendor/" in p or "/odm/" in p else search
    seen, order, missing = {}, [p], []
    i = 0
    while i < len(order):
        cur = order[i]; i += 1
        for n in info(cur)[0]:
            if n in seen: continue
            q = find(n, paths)
            seen[n] = q
            if q: order.append(q)
            else: missing.append((n, os.path.basename(cur)))
    out = []
    if missing: out.append("missing libs: " + ", ".join(f"{n} (needed by {w})" for n, w in missing[:6]))
    else:
        defs = set()
        for q in order: defs |= info(q)[1]
        und = sorted(info(p)[2] - defs)
        if und: out.append(f"{len(und)} unresolved symbols: " + ", ".join(und[:4]))
    return p, out
targets = []
for d in sys.argv[3:]:
    if not os.path.isdir(os.path.join(R, d)): continue
    for f in sorted(os.listdir(os.path.join(R, d))):
        p = os.path.join(R, d, f)
        if os.path.isfile(p) and not os.path.islink(p) and is_elf(p): targets.append(p)
bad = 0
with ThreadPoolExecutor(16) as ex:
    for p, out in ex.map(check, targets):
        if out:
            bad += 1; print("FAIL", p[len(R):], "|", "; ".join(out)[:400])
print(f"checked {len(targets)} objects ({bits}-bit), failures: {bad}")
