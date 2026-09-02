#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE=src/julia.rs

usage() {
    cat <<EOF
Usage:
  $0 YYYY-MM-DD
  $0 --check
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

extract_const() {
    local name=$1
    local values
    values=$(sed -n "s/^const $name: &str = \"\(.*\)\";\$/\1/p" "$SOURCE")
    if [[ -z "$values" || $(wc -l <<<"$values") -ne 1 ]]; then
        fail "expected exactly one \`const $name\` in $SOURCE."
    fi
    printf '%s\n' "$values"
}

fetch_file() {
    local repository=$1
    local revision=$2
    local path=$3
    gh api "repos/$repository/contents/$path?ref=$revision" --jq .content |
        base64 -d
}

if [[ $# -eq 1 && ( $1 == --help || $1 == -h ) ]]; then
    usage
    exit 0
fi
if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

CHECK=false
if [[ $1 == --check ]]; then
    CHECK=true
    REVISION=$(extract_const JETLS_REVISION)
elif [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    REVISION=$1
else
    usage >&2
    exit 2
fi

REPOSITORY_URL=$(extract_const JETLS_REPOSITORY)
CURRENT_REVISION=$(extract_const JETLS_REVISION)
CURRENT_JULIA_LOWER=$(extract_const JULIA_VERSION_LOWER_BOUND)
CURRENT_JULIA_UPPER=$(extract_const JULIA_VERSION_UPPER_BOUND)
REPOSITORY=${REPOSITORY_URL#https://github.com/}

DESCRIPTOR=$(fetch_file "$REPOSITORY" "$REVISION" JETLS_VERSION)
if [[ "$DESCRIPTOR" != "$REVISION" ]]; then
    fail "JETLS_VERSION at $REVISION contains '$DESCRIPTOR'."
fi

PROJECT_TOML=$(fetch_file "$REPOSITORY" "$REVISION" Project.toml)
COMPAT=$(printf '%s\n' "$PROJECT_TOML" |
    sed -n '/^\[compat\]/,/^\[/p' | sed -n 's/^julia = "\(.*\)"$/\1/p')
if [[ -z "$COMPAT" ]]; then
    fail "could not read the julia compat entry at $REVISION."
fi
if [[ ! $COMPAT =~ ^([^[:space:]]+)[[:space:]]-[[:space:]]([^[:space:]]+)$ ]]; then
    fail "unsupported julia compat at $REVISION: '$COMPAT'."
fi
JULIA_LOWER=${BASH_REMATCH[1]}
JULIA_UPPER=${BASH_REMATCH[2]}

if [[ "$CHECK" == true ]]; then
    if [[ "$CURRENT_JULIA_LOWER - $CURRENT_JULIA_UPPER" != "$COMPAT" ]]; then
        fail "julia bounds in $SOURCE ($CURRENT_JULIA_LOWER - $CURRENT_JULIA_UPPER) do not match $REVISION ($COMPAT)."
    fi
    printf 'JETLS revision %s and julia bounds %s in %s are up to date.\n' \
        "$CURRENT_REVISION" "$COMPAT" "$SOURCE"
    exit 0
fi

TEMP=$(mktemp "${SOURCE}.XXXXXX")
trap 'rm -f "$TEMP"' EXIT
awk \
    -v revision="$REVISION" \
    -v julia_lower="$JULIA_LOWER" \
    -v julia_upper="$JULIA_UPPER" \
    '
$1 == "const" && $2 == "JETLS_REVISION:" {
    print "const JETLS_REVISION: &str = \"" revision "\";"
    next
}
$1 == "const" && $2 == "JULIA_VERSION_LOWER_BOUND:" {
    print "const JULIA_VERSION_LOWER_BOUND: &str = \"" julia_lower "\";"
    next
}
$1 == "const" && $2 == "JULIA_VERSION_UPPER_BOUND:" {
    print "const JULIA_VERSION_UPPER_BOUND: &str = \"" julia_upper "\";"
    next
}
{ print }
' "$SOURCE" >"$TEMP"

if cmp -s "$SOURCE" "$TEMP"; then
    printf '%s already pins JETLS revision %s with julia compat %s.\n' \
        "$SOURCE" "$REVISION" "$COMPAT"
else
    cat "$TEMP" >"$SOURCE"
    printf 'Updated %s to JETLS revision %s with julia compat %s.\n' \
        "$SOURCE" "$REVISION" "$COMPAT"
fi
