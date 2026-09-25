#!/usr/bin/env bash

print_help() {
    cat <<'EOF'
Usage: ./scripts/prepare-release.sh [OPTIONS] VERSION

Prepare a release branch, create the release commit, and open a pull
request against main. Merging the pull request triggers the publish
workflow (.github/workflows/release.yml), which pushes the `vVERSION`
tag, creates the GitHub release, and opens a pull request that updates
the extension in zed-industries/extensions.

The release ships the JETLS release pinned on main; update the pin
beforehand with scripts/update-jetls-revision.sh.

Arguments:
  VERSION       Release version in MAJOR.MINOR.PATCH format (e.g. 0.2.1)

Options:
  -h, --help        Show this help message and exit
  --no-push         Prepare without pushing or opening a PR
  --remote REMOTE   Remote to use (default: origin)

Examples:
  ./scripts/prepare-release.sh --no-push 0.2.1
  ./scripts/prepare-release.sh 0.2.1
EOF
}

set -euo pipefail

NO_PUSH=false
REMOTE=origin
VERSION=

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_help
            exit 0
            ;;
        --no-push)
            NO_PUSH=true
            shift
            ;;
        --remote)
            if [[ $# -lt 2 ]]; then
                echo "Error: --remote requires a value"
                exit 1
            fi
            REMOTE=$2
            shift 2
            ;;
        --remote=*)
            REMOTE=${1#*=}
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: $0 [OPTIONS] VERSION"
            exit 1
            ;;
        *)
            if [[ -z "$VERSION" ]]; then
                VERSION=$1
            else
                echo "Error: Unexpected argument: $1"
                echo "Usage: $0 [OPTIONS] VERSION"
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 [OPTIONS] VERSION"
    echo "Example: $0 0.2.1"
    exit 1
fi

if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "Error: VERSION must be MAJOR.MINOR.PATCH without leading zeros (e.g. 0.2.1)"
    exit 1
fi

TAG="v$VERSION"
BRANCH="releases/v$VERSION"

echo "==> Preparing release v$VERSION"

cd "$(dirname "$0")/.."

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
    echo "Error: Git remote '$REMOTE' does not exist"
    exit 1
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: You have uncommitted changes. Please commit or stash them first."
    exit 1
fi

# Check if the release branch or tag already exists
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "Error: Branch $BRANCH already exists locally"
    exit 1
fi
if git ls-remote --exit-code --heads "$REMOTE" "$BRANCH" >/dev/null 2>&1; then
    echo "Error: Branch $BRANCH already exists on remote"
    exit 1
fi
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "Error: Tag $TAG already exists locally"
    exit 1
fi
if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/$TAG" >/dev/null 2>&1; then
    echo "Error: Tag $TAG already exists on remote"
    exit 1
fi

echo "==> Step 1: Creating release branch from $REMOTE/main"
git fetch "$REMOTE" main
git checkout -b "$BRANCH" "$REMOTE/main"

REVISION=$(sed -n 's/^const JETLS_REVISION: &str = "\(.*\)";$/\1/p' src/julia.rs)

echo "==> Step 2: Setting extension version to $VERSION"
for MANIFEST in extension.toml Cargo.toml; do
    sed -i.bak -E "s/^version = \"[^\"]*\"$/version = \"$VERSION\"/" "$MANIFEST"
    rm "$MANIFEST.bak"
    if [[ $(grep -c "^version = \"$VERSION\"$" "$MANIFEST") -ne 1 ]]; then
        echo "Error: failed to update the version in $MANIFEST."
        exit 1
    fi
done
cargo update --workspace

echo "==> Step 3: Finalizing the CHANGELOG"
CHANGELOG=CHANGELOG.md
julia --startup-file=no scripts/update-changelog.jl

echo "==> Step 4: Committing the release"
git add extension.toml Cargo.toml Cargo.lock "$CHANGELOG"
git commit -m "v$VERSION"

if [[ "$NO_PUSH" == true ]]; then
    echo ""
    echo "==> Skipping push and PR creation"
    echo ""
    echo "Release branch prepared locally: $BRANCH"
    echo "To complete the release manually:"
    echo "  1. git push -u $REMOTE $BRANCH"
    echo "  2. Create a PR from $BRANCH to main"
    exit 0
fi

git push -u "$REMOTE" "$BRANCH"

echo "==> Step 5: Creating pull request"
PR_BODY="This PR releases \`v$VERSION\`, pinning the JETLS release \`$REVISION\`.

Merging this PR pushes the \`$TAG\` tag, creates the GitHub release, and opens a pull request that updates the extension in zed-industries/extensions."

PR_URL=$(gh pr create \
    --base main \
    --head "$BRANCH" \
    --title "Release v$VERSION" \
    --body "$PR_BODY")

echo ""
echo "==> Release preparation complete!"
echo ""
echo "Pull request created: $PR_URL"
echo ""
echo "Next steps:"
echo "  1. Wait for CI to pass"
echo "  2. Review the generated CHANGELOG section"
echo "  3. Merge the PR to publish the release"
echo "  4. Review the zed-industries/extensions pull request opened by the release workflow"
