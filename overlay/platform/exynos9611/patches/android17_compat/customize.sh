# SPDX-License-Identifier: GPL-3.0-or-later
#
# Found with static checks on the built images (docs/07, Fase B). The first
# six are solved in the base for the Galaxy A52s, which has the same kind of
# old vendor: run those implementations (each one checks by itself whether it
# applies) instead of copying them.
#
#   ueventd    the vendor ships /vendor/ueventd.rc only; Android 17 ueventd
#              imports just /vendor/etc/ueventd.rc, so device nodes would keep
#              root-only permissions and the HALs could not open them
#   ion_label  Android 17 no longer labels /dev/ion, the Exynos graphics and
#              media HALs still allocate through legacy ION
#   seccomp    the Codec2 seccomp policy only allows mremap with two flag
#              values, Android 17 bionic uses others -> SIGSYS in the codec HAL
#   cgroups    Android 17 aborts cgroup setup when a mandatory controller is
#              missing; the 4.14 kernel has cpuset cpu cpuacct blkio memory
#              freezer, the same set the A52s implementation assumes, and no
#              Samsung "sfreezer"
#   engmode, vaultkeeper
#              the S26 client libraries only talk to the AIDL versions of
#              these two Samsung security HALs; the tablet's vendor serves the
#              HIDL ones (engmode@1.0, vaultkeeper@2.0), so every call blocks
#              waiting for a service that never comes (slow boot, USB events
#              stalled, Bluetooth unable to get its storage key). Use the
#              client libraries of the stock firmware; the programs of the S26
#              system that link libvkmanager only use symbols the stock one has
A52S="$SRC_DIR/target/a52sxq/patches"
for p in ueventd ion_label seccomp cgroups engmode vaultkeeper; do
    [ -f "$A52S/$p/customize.sh" ] || ABORT "Implementation not found in the base: target/a52sxq/patches/$p"
    # shellcheck disable=SC1090
    source "$A52S/$p/customize.sh"
done
unset A52S p

# The kernel has no vsock (CONFIG_VSOCKETS is not set): traced dies at start
# with the S26 relay port.
SET_PROP "product" "traced.relay_producer_port" --delete

# The S26 KeyMint does remote key provisioning only. The tablet has Keymaster
# 4.0 with factory attestation keys and no remotely provisioned component:
# with this prop keystore2 would refuse to fall back to them.
SET_PROP "product" "remote_provisioning.tee.rkp_only" --delete

# Android 17 init refuses vendor properties whose platform label vendor_init may
# no longer set (seen in the boot log of the virtual tablet, tools/vm_boot.sh:
# "Do not have permissions to set ... in property file '/vendor/build.prop'").
# For a Wi-Fi tablet the rejected ones are harmless (mobile data, DNS and
# emergency number defaults) except the log path of the Wi-Fi/Bluetooth
# daemon: declare that one in /system, which is loaded without the check.
WLBT_LOG_PATH="$(GET_PROP "vendor" "exynos.wlbtlog.path")"
[ "$WLBT_LOG_PATH" ] && SET_PROP "system" "exynos.wlbtlog.path" "$WLBT_LOG_PATH"
unset WLBT_LOG_PATH

# Audio: the vendor manifest declares the HIDL audio and audio effect HALs at
# version 5.0, and Android 17 only has clients for 6.0, 7.x and AIDL
# (libaudiohal@5.0 is gone): audioserver finds no devices factory and dies in
# AudioFlinger::onFirstRef() at every start, which is what the virtual tablet
# showed. The vendor already ships the 6.0 implementations next to the 5.0
# ones (/vendor/lib/hw/android.hardware.audio@6.0-impl.so and the effect one);
# its service tries 6.0 first and only gave up because the manifest does not
# list it ("must be in VINTF manifest in order to register"). Declare 6.0 and
# drop the 5.0 implementations, as the base does for the Exynos 990.
for f in "lib/hw/android.hardware.audio@6.0-impl.so" "lib/hw/android.hardware.audio.effect@6.0-impl.so"; do
    [ -f "$WORK_DIR/vendor/$f" ] || ABORT "Vendor audio 6.0 implementation not found: /vendor/$f"
done
LOG "- Declaring the HIDL audio HALs at version 6.0 in /vendor/etc/vintf/manifest.xml"
python3 - "$WORK_DIR/vendor/etc/vintf/manifest.xml" << 'PYEOF' || ABORT "Failed to update the audio HAL version in the vendor manifest"
import re, sys
p = sys.argv[1]; s = open(p).read()
n = 0
def fix(m):
    global n
    b = m.group(0)
    if re.search(r"<name>android\.hardware\.audio(\.effect)?</name>", b) and "<version>5.0</version>" in b:
        n += 1
        b = b.replace("<version>5.0</version>", "<version>6.0</version>").replace("<fqname>@5.0::", "<fqname>@6.0::")
    return b
s = re.sub(r"<hal format=\"hidl\">.*?</hal>", fix, s, flags=re.S)
assert n == 2, "expected the audio and audio.effect 5.0 entries, found %d" % n
open(p, "w").write(s)
PYEOF
for f in "lib/hw/android.hardware.audio@5.0-impl.so" "lib/hw/android.hardware.audio.effect@5.0-impl.so" \
        "lib64/hw/android.hardware.audio@5.0-impl.so" "lib64/hw/android.hardware.audio.effect@5.0-impl.so"; do
    [ -f "$WORK_DIR/vendor/$f" ] && DELETE_FROM_WORK_DIR "vendor" "$f"
done
unset f

# SurfaceFlinger: the Android 17 build picks the Vulkan (SkiaVk) RenderEngine by
# default and aborts when it cannot set it up, with no fallback ("Could not
# initialize Vulkan RenderEngine!"). The Mali-G72 driver of the stock vendor is
# from Android 13, where SurfaceFlinger composed with OpenGL ES (threaded
# SkiaGL), and that is the only path this driver was shipped and validated
# with. Ask for it explicitly; the binary still contains SkiaGLRenderEngine.
SET_PROP "system" "debug.renderengine.backend" "skiaglthreaded"

# EGL: the vendor has /vendor/lib*/egl/libGLES_mali.so and sets no
# ro.hardware.egl. Up to Android 13 the EGL loader would pick any libGLES_*.so
# it found; the Android 17 one only looks for libGLES_<name>.so with <name> from
# persist.graphics.egl, ro.hardware.egl or ro.board.platform (universal9611),
# finds nothing and aborts SurfaceFlinger ("couldn't find an OpenGL ES
# implementation", seen in the virtual tablet). Name the driver.
[ -f "$WORK_DIR/vendor/lib64/egl/libGLES_mali.so" ] || ABORT "Mali GLES driver not found in /vendor/lib64/egl"
SET_PROP "vendor" "ro.hardware.egl" "mali"
