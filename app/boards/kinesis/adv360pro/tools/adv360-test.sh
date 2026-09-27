#!/usr/bin/env bash
# Copyright (c) 2026 The ZMK Contributors
# SPDX-License-Identifier: MIT
#
# adv360-test.sh [<app/tests/path> ...]   (paths relative to the worktree root)
# Runs app/run-test.sh per path inside the container (native_sim is Linux-only).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

# ponytail: default set is the suites touching Kinesis features on main today;
# sections append their new suites here.
[ $# -gt 0 ] || set -- app/tests/backlight app/tests/toggle-layer app/tests/momentary-layer app/tests/studio app/tests/rgb-underglow

fail=0
for p in "$@"; do
    if "$HERE/adv360-env.sh" exec env ZMK_BUILD_DIR=/workspaces/zmk/build J="${ADV360_JOBS:-6}" \
        sh -c "cd app && ./run-test.sh '${p#app/}'">&2; then
        echo "PASS $p"
    else
        echo "FAIL $p"
        fail=1
    fi
done
exit $fail
