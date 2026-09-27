#!/usr/bin/env bash
# Copyright (c) 2026 The ZMK Contributors
# SPDX-License-Identifier: MIT
#
# adv360-env.sh up|exec <cmd...>|down|name
# One long-lived container per worktree; west workspace (zephyr + modules) in a
# shared named volume mounted at /workspaces, worktree bind-mounted over
# /workspaces/zmk so `west init -l zmk/app` resolves the same for every worktree.
set -euo pipefail

IMAGE=${ADV360_IMAGE:-docker.io/zmkfirmware/zmk-build-arm:4.1}
VOLUME=${ADV360_VOLUME:-zmk-adv360-west}
JOBS=${ADV360_JOBS:-6}
WT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
NAME=zmk-adv360-$(basename "$WT")
# A worktree's .git file points at the main repo's absolute gitdir; mount it at
# the same path so git (and Zephyr's version stamp) works inside the container.
GITDIR=$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir)

running() { [ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" = true ]; }

up() {
    if ! running; then
        docker rm -f "$NAME" >/dev/null 2>&1 || true
        docker run -d --name "$NAME" \
            -v "$VOLUME":/workspaces \
            -v "$WT":/workspaces/zmk \
            -v "$GITDIR":"$GITDIR":ro \
            -e CMAKE_BUILD_PARALLEL_LEVEL="$JOBS" \
            -w /workspaces/zmk "$IMAGE" sleep infinity >/dev/null
    fi
    # Workspace init/update is shared by every container: serialize it, and only
    # re-run `west update` when app/west.yml changes.
    docker exec -w /workspaces "$NAME" bash -ec '
        git config --global --add safe.directory "*"
        exec 9>/workspaces/.adv360.lock; flock 9
        # `west init -l zmk/app` would make zmk/ the topdir (inside the bind
        # mount); pin the topdir to the volume instead.
        [ -f .west/config ] || { mkdir -p .west; printf "[manifest]\npath = zmk/app\nfile = west.yml\n\n[zephyr]\nbase = zephyr\n" >.west/config; }
        want=$(sha256sum zmk/app/west.yml | cut -d" " -f1)
        if [ "$(cat .adv360-west.sha 2>/dev/null)" != "$want" ]; then
            west update --fetch-opt=--filter=tree:0 && echo "$want" >.adv360-west.sha
        fi
        west zephyr-export >/dev/null'
    echo "$NAME"
}

case "${1:-}" in
up) up ;;
exec) shift; running || up >/dev/null; docker exec -w /workspaces/zmk "$NAME" "$@" ;;
down) docker rm -f "$NAME" >/dev/null ;;
name) echo "$NAME" ;;
*) echo "usage: $0 up|exec <cmd...>|down|name" >&2; exit 2 ;;
esac
