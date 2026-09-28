#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# adv360-release-plan.sh: decide what the release workflow builds and tags.
#
# Rebases the adv360 patch stack (everything on $DEV_BRANCH past upstream) onto
# the latest ZMK release and onto upstream main, pushes each new result as
# adv360-candidate/<version>, and prints a JSON plan on stdout:
#   {"builds":[{version,ref,kind,target}], "tags":[{name,version}], "conflicts":[{version,target,files}]}
# Versions: zmk-<release>-adv360.<n> or zmk-<git describe of main>-adv360.<n>;
# <n> bumps only when the patch stack changes on the same upstream commit.
# Channel tags (never moved, one per date): adv360-{nightly,weekly,monthly,release,stable}-YYYY-MM-DD.
#
# Env: TARGET (optional upstream ref for a manual snapshot), TODAY (YYYY-MM-DD),
#      PUSH=0 for a dry run, DEV_BRANCH (default adv360-z4.1),
#      STABLE_DAYS (default 14).
set -euo pipefail

DEV_BRANCH=${DEV_BRANCH:-adv360-z4.1}
TODAY=${TODAY:-$(date -u +%F)}
PUSH=${PUSH:-1}
STABLE_DAYS=${STABLE_DAYS:-14}
UPSTREAM=https://github.com/zmkfirmware/zmk.git

log() { echo "$*" >&2; }

# --no-prune and narrow tag refspecs: a remote.origin.prune setting would otherwise
# delete the upstream v* tags, which the fork doesn't carry.
git fetch -q --no-prune "$UPSTREAM" '+refs/heads/main:refs/remotes/upstream/main' 'refs/tags/v*:refs/tags/v*'
git fetch -q --no-prune origin "+refs/heads/$DEV_BRANCH:refs/remotes/origin/$DEV_BRANCH" \
    'refs/tags/zmk-*:refs/tags/zmk-*' 'refs/tags/adv360-*:refs/tags/adv360-*'
dev=origin/$DEV_BRANCH
base=$(git merge-base "$dev" upstream/main)
stack=$(git diff "$base" "$dev" | git patch-id --stable | cut -c1-12)
log "stack $stack: $(git rev-list --count "$base..$dev") commits on $(git rev-parse --short "$base")"

out=$(mktemp -d)
start=$(git symbolic-ref -q --short HEAD || git rev-parse HEAD)
trap 'git checkout -q "$start"; rm -rf "$out"' EXIT
: >"$out/builds" && : >"$out/tags" && : >"$out/conflicts"
add() { echo "$2" >>"$out/$1"; }

# Prints the existing version already built from this stack on <prefix>, or the next free one.
version_for() {
    local prefix=$1 t n=0 max=0
    for t in $(git tag -l "$prefix-adv360.*"); do
        n=${t##*-adv360.}
        [ "$n" -gt "$max" ] && max=$n
        if git cat-file -p "$t" | grep -qx "stack: $stack"; then echo "$t existing"; return; fi
    done
    echo "$prefix-adv360.$((max + 1)) new"
}

# Rebases the stack onto <target>; records a build (or conflict) for <version>.
plan_build() {
    local kind=$1 target=$2 version=$3 cand=adv360-candidate/$3 files
    git checkout -q --detach "$dev"
    if ! GIT_COMMITTER_NAME=adv360-release GIT_COMMITTER_EMAIL=adv360-release@users.noreply.github.com \
        git rebase -q --committer-date-is-author-date --onto "$target" "$base" >/dev/null 2>&1; then
        files=$(git diff --name-only --diff-filter=U | jq -R . | jq -sc .)
        git rebase --abort
        add conflicts "$(jq -nc --arg v "$version" --arg t "$(git rev-parse "$target")" --argjson f "$files" '{version:$v,target:$t,files:$f}')"
        log "CONFLICT $version on $target: $files"
        return 1
    fi
    [ "$PUSH" = 1 ] && git push -q origin "HEAD:refs/heads/$cand"
    add builds "$(jq -nc --arg v "$version" --arg r "$cand" --arg k "$kind" --arg t "$(git rev-parse "$target")" \
        '{version:$v,ref:$r,kind:$k,target:$t}')"
    log "build $version ($kind) from $cand"
}

# release: only a ZMK release newer than our base (v0.3.0 predates Zephyr 4.1).
rel=$(gh api repos/zmkfirmware/zmk/releases/latest -q .tag_name)
if git merge-base --is-ancestor "$base" "$rel" && [ "$(git rev-parse "$base")" != "$(git rev-parse "$rel^{commit}")" ]; then
    read -r v state < <(version_for "zmk-$rel")
    if [ "$state" = new ] && plan_build release "$rel" "$v"; then
        add tags "$(jq -nc --arg n "adv360-release-$TODAY" --arg v "$v" '{name:$n,version:$v}')"
    fi
else
    log "latest ZMK release $rel predates the stack base; no release build"
fi

# snapshots of main (or a manual TARGET).
snap=${TARGET:-upstream/main}
read -r v state < <(version_for "zmk-$(git describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' "$snap")")
built=1
if [ "$state" = new ]; then plan_build snapshot "$snap" "$v" || built=0; fi
if [ "$built" = 1 ]; then
    chans=()
    [ "$state" = new ] && chans+=(nightly)
    [ "$(date -u -d "$TODAY" +%u 2>/dev/null || date -j -f %F "$TODAY" +%u)" = 1 ] && chans+=(weekly)
    [ "${TODAY:8:2}" = 01 ] && chans+=(monthly)
    [ -n "${TARGET:-}" ] && chans+=(nightly)
    for c in $(printf '%s\n' "${chans[@]}" | sort -u); do
        git rev-parse -q --verify "refs/tags/adv360-$c-$TODAY" >/dev/null ||
            add tags "$(jq -nc --arg n "adv360-$c-$TODAY" --arg v "$v" '{name:$n,version:$v}')"
    done
fi

# stable: the newest release build, once it has gone STABLE_DAYS without a newer patch rev.
latest_rel=$(git tag -l 'zmk-v*.*.*-adv360.*' --sort=-creatordate | grep -vE -- '-[0-9]+-g[0-9a-f]+-adv360' | head -1 || true)
if [ -n "$latest_rel" ]; then
    age=$(( ($(date -u +%s) - $(git for-each-ref --format='%(creatordate:unix)' "refs/tags/$latest_rel")) / 86400 ))
    pointed=$(git tag -l 'adv360-stable-*' --points-at "$latest_rel^{commit}")
    if [ "$age" -ge "$STABLE_DAYS" ] && [ -z "$pointed" ]; then
        add tags "$(jq -nc --arg n "adv360-stable-$TODAY" --arg v "$latest_rel" '{name:$n,version:$v}')"
    fi
fi

jq -nc --arg s "$stack" \
    --slurpfile b "$out/builds" --slurpfile t "$out/tags" --slurpfile c "$out/conflicts" \
    '{stack:$s,builds:$b,tags:$t,conflicts:$c}'
