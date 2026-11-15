"""ctxcheck.py <rootfs> [vendor policy version]
Every type used in the *_contexts files of system, system_ext, product, vendor
and odm must be a type (or type alias) defined in the policy sources."""
import re, sys, os, glob
R=sys.argv[1]
VERS=sys.argv[2] if len(sys.argv)>2 else "33.0"
cils=[f"{R}/system/etc/selinux/plat_sepolicy.cil",f"{R}/system/etc/selinux/mapping/{VERS}.cil",f"{R}/system/etc/selinux/mapping/{VERS}.compat.cil",
      f"{R}/system/system_ext/etc/selinux/system_ext_sepolicy.cil",f"{R}/system/system_ext/etc/selinux/mapping/{VERS}.cil",f"{R}/system/system_ext/etc/selinux/mapping/{VERS}.compat.cil",
      f"{R}/product/etc/selinux/product_sepolicy.cil",f"{R}/product/etc/selinux/mapping/{VERS}.cil",
      f"{R}/vendor/etc/selinux/plat_pub_versioned.cil",f"{R}/vendor/etc/selinux/vendor_sepolicy.cil",f"{R}/odm/etc/selinux/odm_sepolicy.cil"]
types=set()
for c in cils:
    if os.path.isfile(c):
        t=open(c,errors="replace").read()
        types |= set(re.findall(r"\(type (\S+)\)", t)) | set(re.findall(r"\(typealias (\S+)\)", t))
print("types defined:",len(types))
files=[]
for d in ("system/etc/selinux","system/system_ext/etc/selinux","product/etc/selinux","vendor/etc/selinux","odm/etc/selinux"):
    files += [f for f in glob.glob(f"{R}/{d}/*_contexts") if os.path.isfile(f)]
bad={}
for f in files:
    for n,l in enumerate(open(f,errors="replace"),1):
        l=l.split("#")[0]
        for m in re.finditer(r"u:(?:object_r|r):([A-Za-z0-9_]+):s0", l):
            if m.group(1) not in types: bad.setdefault((os.path.relpath(f,R),m.group(1)),[]).append(n)
print("context files:",len(files),"unknown type references:",len(bad))
for (f,t),ns in sorted(bad.items()): print("  ",f,t,"lines",ns[:4],"x%d"%len(ns))
