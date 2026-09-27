#!/usr/bin/env bash
# Copyright (c) 2026 The ZMK Contributors
# SPDX-License-Identifier: MIT
#
# adv360-build.sh <left|right> [--studio] [--pristine] [--cmake-only] [--config <dir> [--keymap <file>]] [-D<VAR>=<val> ...]
#   --config: ZMK_CONFIG dir relative to the worktree root (must be inside it, e.g.
#             zmk-config/, which .gitignore covers); builds into build/<side>[-studio]-config.
#   --keymap: KEYMAP_FILE relative to the worktree root. Needed when the config's keymap
#             is not named adv360pro*.keymap: otherwise the board's stock keymap is used
#             silently.
#   --cmake-only: configure only (Kconfig + devicetree) into build/<side>[-studio][-config]-kconfig.
#   -D...: extra CMake cache entries, e.g. -DCONFIG_ZMK_HID_KEYBOARD_EXTENDED_REPORT=y.
# Prints "UF2: build/<side>[-studio][-config]/zephyr/zmk.uf2" on success
# ("CONFIG: <dir>/zephyr/.config" with --cmake-only).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

side=${1:-}
case "$side" in left | right) shift ;; *) echo "usage: $0 <left|right> [--studio] [--pristine] [--cmake-only] [--config <dir> [--keymap <file>]] [-D<VAR>=<val> ...]" >&2; exit 2 ;; esac
studio='' pristine='' cmake_only='' config='' keymap='' defs=()
while [ $# -gt 0 ]; do
    case "$1" in
    --studio) studio=1 ;;
    --pristine) pristine=1 ;;
    --cmake-only) cmake_only=1 ;;
    --config) config=$2; shift ;;
    --keymap) keymap=$2; shift ;;
    -D*) defs+=("$1") ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
    shift
done

dir=build/$side${studio:+-studio}${config:+-config}${cmake_only:+-kconfig}
# Bare adv360pro_<side> resolves to a stub target and fails (R4); keep the full HWMv2 string.
args=(west build -s app -d "$dir" -b "adv360pro_${side}/nrf52840/zmk")
[ -n "$pristine" ] && args+=(-p)
[ -n "$cmake_only" ] && args+=(--cmake-only)
[ -n "$studio" ] && args+=(-S studio-rpc-usb-uart)
args+=(--)
[ -n "$studio" ] && args+=(-DCONFIG_ZMK_STUDIO=y)
[ -n "$config" ] && args+=("-DZMK_CONFIG=/workspaces/zmk/$config")
[ -n "$keymap" ] && args+=("-DKEYMAP_FILE=/workspaces/zmk/$keymap")
args+=(${defs[@]+"${defs[@]}"})

"$HERE/adv360-env.sh" exec "${args[@]}"
if [ -n "$cmake_only" ]; then echo "CONFIG: $dir/zephyr/.config"; else echo "UF2: $dir/zephyr/zmk.uf2"; fi
