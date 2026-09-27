#!/usr/bin/env bash
# Copyright (c) 2026 The ZMK Contributors
# SPDX-License-Identifier: MIT
#
# adv360-all.sh [--pristine]: left, right, left --studio, adv360-kconfig-check.sh, then adv360-test.sh.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

summary=() fail=0
run() {
    if "$@"; then summary+=("PASS $*"); else summary+=("FAIL $*"); fail=1; fi
}
run "$HERE/adv360-build.sh" left "$@"
run "$HERE/adv360-build.sh" right "$@"
run "$HERE/adv360-build.sh" left --studio "$@"
run "$HERE/adv360-kconfig-check.sh"
run "$HERE/adv360-test.sh"
printf '== summary ==\n'
printf '%s\n' "${summary[@]}"
exit $fail
