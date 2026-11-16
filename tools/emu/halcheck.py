#!/usr/bin/env python3
"""halcheck.py <work_dir> <unpacked apex dir>
For every HAL the vendor declares in its VINTF manifest, checks that the system
still contains a client for that interface (and, for HIDL, for that version):
its name must appear in a system binary, library or in the dex code of a
framework jar. A HAL nobody can talk to is how the 5.0 audio HAL broke
audioserver under Android 17."""
import glob, os, re, subprocess, sys, zipfile
W, APEX = sys.argv[1], sys.argv[2]
PAT = re.compile(rb"(?:android\.hardware|android\.system|android\.frameworks|vendor\.samsung|vendor\.samsung_slsi|com\.dsi)[A-Za-z0-9_.]*(?:@[0-9]+\.[0-9]+)?")
hals = set()
for f in [W + "/vendor/etc/vintf/manifest.xml"] + glob.glob(W + "/vendor/etc/vintf/manifest/*.xml"):
    s = open(f).read()
    for fmt, b in re.findall(r'<hal format="(\w+)"[^>]*>(.*?)</hal>', s, re.S):
        name = re.search(r"<name>([^<]+)</name>", b).group(1)
        if fmt == "hidl":
            for v in set(re.findall(r"<version>([^<]+)</version>", b)) | set(re.findall(r"<fqname>@([0-9.]+)::", b)):
                hals.add((fmt, name + "@" + v))
        else:
            hals.add((fmt, name))
corpus = set()
def scan(data):
    for m in PAT.findall(data): corpus.add(m.decode())
roots = [W + "/system/system/lib64", W + "/system/system/bin", W + "/system/system/system_ext/lib64", W + "/system/system/system_ext/bin",
         W + "/system/system/framework", W + "/system/system/system_ext/framework", APEX]
for r in roots:
    for d, _, fs in os.walk(r):
        for f in fs:
            p = os.path.join(d, f)
            if os.path.islink(p) or not os.path.isfile(p): continue
            try:
                if f.endswith((".jar", ".apk")):
                    with zipfile.ZipFile(p) as z:
                        for n in z.namelist():
                            if n.endswith(".dex"): scan(z.read(n))
                elif f.endswith(".so") or "/bin" in d:
                    scan(open(p, "rb").read())
            except Exception:
                pass
bad = 0
for fmt, n in sorted(hals):
    if fmt == "hidl":
        name = n.split("@")[0]
        if not any(c == n or c.startswith(n) for c in corpus):
            bad += 1
            known = sorted({c.split("@")[1] for c in corpus if c.startswith(name + "@")})
            aidl = any(c == name or c.startswith(name + ".I") for c in corpus)
            print("NO CLIENT hidl %-60s system has: %s%s" % (n, ",".join(known) or "nothing", " + AIDL client" if aidl else ""))
    elif not any(c == n or c.startswith(n + ".") for c in corpus):
        bad += 1; print("NO CLIENT aidl", n)
print("vendor HALs: %d, without a client in the system: %d" % (len(hals), bad))
