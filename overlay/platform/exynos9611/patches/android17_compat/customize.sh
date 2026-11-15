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
