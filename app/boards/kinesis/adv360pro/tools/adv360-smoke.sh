#!/usr/bin/env bash
# Copyright (c) 2026 The ZMK Contributors
# SPDX-License-Identifier: MIT
#
# adv360-smoke.sh [--pristine]: build a copy of the user's config (left, left --studio,
# right) and prove the user keymap, not the board's stock one, reached the build.
#   ADV360_CONFIG_REPO: config repo checkout (default /Users/adam/src/Adv360-Pro-ZMK-v4);
#   its config/ is copied to <worktree>/zmk-config (gitignored), version.dtsi is
#   generated with its bin/get_version_local.sh, and the repo itself is never written.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WT=$(git -C "$HERE" rev-parse --show-toplevel)
REPO=${ADV360_CONFIG_REPO:-/Users/adam/src/Adv360-Pro-ZMK-v4}
[ -f "$REPO/config/adv360.keymap" ] || { echo "no config repo at $REPO" >&2; exit 2; }

rm -rf "$WT/zmk-config"
cp -R "$REPO/config" "$WT/zmk-config"
gen=$(mktemp -d)
mkdir -p "$gen/config"
(cd "$gen" && GIT_DIR="$REPO/.git" bash "$REPO/bin/get_version_local.sh" clique >/dev/null)
cp "$gen/config/version.dtsi" "$WT/zmk-config/version.dtsi"
rm -rf "$gen"

# &stp is Kinesis-only (C5); until its header lands, build the rest of the keymap.
if [ ! -f "$WT/app/include/dt-bindings/zmk/stp.h" ]; then
    echo "STUB &stp: app/include/dt-bindings/zmk/stp.h missing"
    sed -i.bak -e '/dt-bindings\/zmk\/stp.h/d' -e 's/&stp STP_BAT/\&none/g' "$WT/zmk-config/adv360.keymap"
    rm -f "$WT/zmk-config/adv360.keymap.bak"
fi

summary=() fail=0
run() { # <label> <build args...>
    local label=$1
    shift
    local dts="$WT/build/${label}-config/zephyr/zephyr.dts"
    if "$HERE/adv360-build.sh" "$@" --config zmk-config --keymap zmk-config/adv360.keymap &&
        grep -q 'macro_ver' "$dts"; then
        summary+=("PASS smoke $label")
    else
        summary+=("FAIL smoke $label")
        fail=1
    fi
}
run left left "$@"
run left-studio left --studio "$@"
run right right "$@"
printf '%s\n' "${summary[@]}"
exit $fail
