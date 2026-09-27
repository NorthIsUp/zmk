#!/usr/bin/env bash
# Copyright (c) 2026 The ZMK Contributors
# SPDX-License-Identifier: MIT
#
# adv360-kconfig-check.sh: configure each case with --cmake-only and assert the
# resolved .config holds every expected line. A defconfig line Kconfig silently
# drops (unmet depends, out of range) shows up here as "missing".
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WT=$(git -C "$HERE" rev-parse --show-toplevel)

BOTH=(
    CONFIG_ZMK_RGB_UNDERGLOW_ON_START=y
    CONFIG_USB_DEVICE_VID=0x29EA
    CONFIG_USB_DEVICE_PID=0x0362
    'CONFIG_USB_DEVICE_MANUFACTURER="Kinesis Corporation"'
    CONFIG_ZMK_BLE_EXPERIMENTAL_FEATURES=y
    CONFIG_ZMK_HID_INDICATORS=y
    CONFIG_ZMK_SPLIT_PERIPHERAL_HID_INDICATORS=y
)
LEFT=(
    "${BOTH[@]}"
    CONFIG_ZMK_USB=y
    'CONFIG_BT_DIS_MANUF_NAME_STR="Kinesis Corporation"'
    '# CONFIG_BT_BAS is not set'
    '# CONFIG_ZMK_BLE_PASSKEY_ENTRY is not set'
)
RIGHT=("${BOTH[@]}")

fail=0
# check <label> <side> [-D... ...] -- <expected .config line> ...
check() {
    local label=$1 side=$2 defs=()
    shift 2
    while [ "$1" != -- ]; do defs+=("$1"); shift; done
    shift
    local log="$WT/build/kconfig-$label.log"
    mkdir -p "$WT/build"
    if ! "$HERE/adv360-build.sh" "$side" --pristine --cmake-only ${defs[@]+"${defs[@]}"} >"$log" 2>&1; then
        echo "FAIL $label (configure failed, see $log)"
        fail=1
        return
    fi
    local cfg="$WT/build/$side-kconfig/zephyr/.config" want bad=0
    if grep -q "was assigned the value" "$log"; then
        echo "FAIL $label: a Kconfig assignment was dropped (see $log)"
        bad=1
    fi
    for want in "$@"; do
        grep -qxF -- "$want" "$cfg" || { echo "FAIL $label: missing '$want'"; bad=1; }
    done
    [ $bad = 0 ] && echo "PASS $label" || fail=1
}

check left left -- "${LEFT[@]}"
check right right -- "${RIGHT[@]}"
exit $fail
