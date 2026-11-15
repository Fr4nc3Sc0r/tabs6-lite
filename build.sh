#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# One-shot build of the ROM for the Galaxy Tab S6 Lite Wi-Fi (gta4xlwifi).
#
# Usage: ./build.sh [--debug] [--probe-only]
#   --debug        base "debug" build: missing device files become warnings
#   --probe-only   stop after the firmware has been downloaded, extracted and
#                  checked against the configuration (no ROM is built)
#
# Environment:
#   TABS6_SERIAL   serial number of the tablet (required to download its firmware)
#   TABS6_CSC      CSC of the stock firmware to use (default: ITV)
#   see also overlay/platform/exynos9611/patches/kernel/customize.sh

set -eo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$HERE/un1ca"
TARGET="gta4xlwifi"

DEBUG_FLAG=""
PROBE_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --debug) DEBUG_FLAG="--debug" ;;
        --probe-only) PROBE_ONLY=true ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

if [[ ! "${TABS6_SERIAL:-}" =~ ^R[0-9A-Z]{10}$ ]]; then
    cat >&2 << MSG
TABS6_SERIAL is not set or is not a Samsung serial number (11 characters,
starting with "R"). It is printed on the back of the tablet and shown in
Settings > About tablet. Samsung's firmware server needs it to hand out the
SM-P610 firmware.

  export TABS6_SERIAL=R...........
MSG
    exit 1
fi
export TABS6_SERIAL TABS6_CSC="${TABS6_CSC:-ITV}"

# The base applies patches to its bundled tools with "git am", which needs a
# committer identity. Provide a throwaway one when the machine has none.
if ! git config user.name > /dev/null || ! git config user.email > /dev/null; then
    export GIT_AUTHOR_NAME="tabs6-lite build" GIT_AUTHOR_EMAIL="build@localhost"
    export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
fi

"$HERE/setup.sh"

cd "$BASE_DIR"
# buildenv.sh is written to be sourced from an interactive shell: do not let
# "set -e" abort on its harmless non-zero tests, check its result instead.
set +e
# shellcheck disable=SC1091
source buildenv.sh $DEBUG_FLAG "$TARGET"
BUILDENV_RC=$?
set -e
[ "$BUILDENV_RC" -eq 0 ] || { echo "buildenv.sh failed" >&2; exit 1; }

run_cmd build_dependencies
run_cmd download_fw
run_cmd extract_fw

"$BASE_DIR/tabs6-tools/gen_target_from_stock.sh"
"$BASE_DIR/tabs6-tools/verify_target.sh" | tee "$OUT_DIR/verify_target-report.md"

if $PROBE_ONLY; then
    echo "Probe finished: report in $OUT_DIR/verify_target-report.md"
    exit 0
fi

run_cmd make_rom --build-rom-zip

echo
echo "Done. Flashable zip:"
ls -1 "$OUT_DIR"/*.zip
