#!/usr/bin/env bash
# Copyright (c) 2026 The ZMK Contributors
# SPDX-License-Identifier: MIT
#
# adv360-ble-test.sh [<app/tests/ble/path>]   (default: app/tests/ble/split)
# Runs app/run-ble-test.sh (BabbleSim, the real split GATT path) in the amd64 container.
# BabbleSim is built once into build/bsim-x86; the babblesim west group is enabled in a
# container-local west config so the shared volume's .west/config stays untouched.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
path=${1:-app/tests/ble/split}

# shellcheck disable=SC2016 # the script expands inside the container
ADV360_PLATFORM=linux/amd64 "$HERE/adv360-env.sh" exec bash -ec '
    cfg=/root/west-bsim.config
    if [ ! -f $cfg ]; then
        cp /workspaces/.west/config $cfg
        WEST_CONFIG_LOCAL=$cfg west config manifest.group-filter -- +babblesim
    fi
    export WEST_CONFIG_LOCAL=$cfg BSIM_OUT_PATH=/workspaces/zmk/build/bsim-x86
    export BSIM_COMPONENTS_PATH=/workspaces/tools/bsim/components
    if [ ! -x $BSIM_OUT_PATH/bin/bs_2G4_phy_v1 ]; then
        make -C /workspaces/tools/bsim everything -j"${CMAKE_BUILD_PARALLEL_LEVEL:-6}" >/dev/null
    fi
    cd app && ./run-ble-test.sh "$1"
' bash "${path#app/}"
