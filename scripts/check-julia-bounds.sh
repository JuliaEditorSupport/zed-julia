#!/usr/bin/env bash
# Checks that the Julia version bounds pinned in src/julia.rs mirror the
# pinned JETLS release's `julia` compat entry, which is required to stay
# in the `<lower> - <upper>` hyphen-range form this comparison assumes;
# drift in either direction fails the check.
#
# The pinned release's Project.toml is read through the GitHub contents
# API via `gh api`.
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE=src/julia.rs

extract_const() {
    local name=$1
    local values
    values=$(sed -n "s/^const $name: &str = \"\(.*\)\";\$/\1/p" "$SOURCE")
    if [[ -z "$values" || $(wc -l <<<"$values") -ne 1 ]]; then
        echo "Error: expected exactly one \`const $name\` in $SOURCE." >&2
        exit 1
    fi
    printf '%s\n' "$values"
}

REPOSITORY_URL=$(extract_const JETLS_REPOSITORY)
REVISION=$(extract_const JETLS_REVISION)
JULIA_LOWER=$(extract_const JULIA_VERSION_LOWER_BOUND)
JULIA_UPPER=$(extract_const JULIA_VERSION_UPPER_BOUND)

REPOSITORY=${REPOSITORY_URL#https://github.com/}
PROJECT_TOML=$(gh api "repos/$REPOSITORY/contents/Project.toml?ref=$REVISION" \
    --jq .content | base64 -d)

COMPAT=$(printf '%s\n' "$PROJECT_TOML" |
    sed -n '/^\[compat\]/,/^\[/p' | sed -n 's/^julia = "\(.*\)"$/\1/p')
if [[ -z "$COMPAT" ]]; then
    echo "Error: could not read the julia compat entry of the pinned release $REVISION."
    exit 1
fi
if [[ "$COMPAT" != "$JULIA_LOWER - $JULIA_UPPER" ]]; then
    echo "Error: julia bounds in $SOURCE ($JULIA_LOWER - $JULIA_UPPER)" \
        "do not match the pinned release's julia compat ($COMPAT)."
    exit 1
fi
echo "julia bounds in $SOURCE match the pinned release $REVISION ($COMPAT)."
