#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Prepares the build tree: clones the One UI 9 UN1CA-based build system at a
# pinned commit into ./un1ca and copies this repository's overlay (platform
# exynos9611 + target gta4xlwifi) on top of it.
#
# Usage: ./setup.sh [--force]
#   --force   discard local changes in ./un1ca and re-apply the overlay
#
# Environment:
#   BASE_REPO / BASE_COMMIT   override the pinned base (see docs/02-architettura.md)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$HERE/un1ca"

# kusti420/k4_un1ca, branch "seventeen" (One UI 9 / Android 17), 2026-10-09
BASE_REPO="${BASE_REPO:-https://github.com/kusti420/k4_un1ca.git}"
BASE_COMMIT="${BASE_COMMIT:-bf0d0240887c28517e08304fcf1d2bb536014f16}"

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

log() { echo -e "\033[1;37m[setup]\033[0m $*"; }
die() { echo -e "\033[0;31m[setup] $*\033[0m" >&2; exit 1; }

for bin in git rsync; do
    command -v "$bin" > /dev/null || die "\"$bin\" is required"
done

if [ ! -d "$BASE_DIR/.git" ]; then
    log "Cloning base build system ($BASE_COMMIT)"
    mkdir -p "$BASE_DIR"
    git -C "$BASE_DIR" init -q
    git -C "$BASE_DIR" remote add origin "$BASE_REPO"
fi

CURRENT="$(git -C "$BASE_DIR" rev-parse HEAD 2> /dev/null || true)"
if [[ "$CURRENT" != "$BASE_COMMIT" ]]; then
    log "Fetching $BASE_COMMIT"
    git -C "$BASE_DIR" fetch -q --depth 1 origin "$BASE_COMMIT"
    git -C "$BASE_DIR" checkout -q -f FETCH_HEAD
elif $FORCE; then
    log "Resetting base tree (--force)"
    git -C "$BASE_DIR" reset -q --hard "$BASE_COMMIT"
    git -C "$BASE_DIR" clean -q -fd -e out
fi

log "Fetching base submodules"
git -C "$BASE_DIR" submodule update -q --init --recursive --depth 1

log "Applying overlay"
# --delete only inside the two directories this repository owns
mkdir -p "$BASE_DIR/platform/exynos9611" "$BASE_DIR/target/gta4xlwifi"
rsync -a --delete "$HERE/overlay/platform/exynos9611/" "$BASE_DIR/platform/exynos9611/"
# Files generated from the stock firmware live next to the committed ones: keep them
rsync -a "$HERE/overlay/target/gta4xlwifi/" "$BASE_DIR/target/gta4xlwifi/"

mkdir -p "$BASE_DIR/tabs6-tools"
rsync -a --delete "$HERE/tools/" "$BASE_DIR/tabs6-tools/"

cat << MSG

Base tree ready in: $BASE_DIR

Next steps (details in docs/03-build.md):
  export TABS6_SERIAL=<serial number of YOUR tablet, e.g. R52N...>
  ./build.sh
MSG
