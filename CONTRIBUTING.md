# Contributing

**Make sure to read the following documentation:**

- [Developing Extensions](https://zed.dev/docs/extensions/developing-extensions)
- [Language Extensions](https://zed.dev/docs/extensions/languages)

## Filing issues

Before reporting an issue,
check [existing issues](https://github.com/JuliaEditorSupport/zed-julia/issues?q=is%3Aissue)
(including closed issues).

The Julia Zed extension is mostly glue code that defines how Zed should use
tree-sitter and the language server protocol with Julia. Please report issues
in the appropriate issue tracker.

### tree-sitter integration

If Zed is not highlighting something properly,
check the queries defined in: [`./languages/julia/*.scm`](./languages/julia/).

If the issue does not seem to be related to the way queries are defined,
check the [tree-sitter-julia issue tracker](https://github.com/tree-sitter/tree-sitter-julia/issues).

### Language server integration

Report issues with managed installation, Julia runtime selection, Zed settings,
or other extension integration in the
[zed-julia issue tracker](https://github.com/JuliaEditorSupport/zed-julia/issues).
If the behavior also occurs when running JETLS independently of Zed, check the
[JETLS.jl issue tracker](https://github.com/aviatesk/JETLS.jl/issues).

## Updating the pinned JETLS release

Each zed-julia release pins an exact dated JETLS release tag. Update the pin
with the release date:

```sh
./scripts/update-jetls-revision.sh YYYY-MM-DD
```

The script verifies the tag's `JETLS_VERSION` descriptor, reads the `julia`
compat entry from its `Project.toml`, and updates `JETLS_REVISION`,
`JULIA_VERSION_LOWER_BOUND`, and `JULIA_VERSION_UPPER_BOUND` in
[`src/julia.rs`](./src/julia.rs). It requires the
[GitHub CLI](https://cli.github.com/) with access to the GitHub API.

Verify the current source without changing it and run the Rust tests:

```sh
./scripts/update-jetls-revision.sh --check
cargo test --locked
```

Pin updates land on `main` in their own pull requests, and users receive the new
managed JETLS version with the next zed-julia [release](#releasing). They do not
need a changelog entry: release preparation generates the `### Language server`
section from the pins of the previous and the new release, linking the release
notes of every JETLS release in between.

## Changelog

Record user-visible changes in the `Unreleased` section of
[`CHANGELOG.md`](./CHANGELOG.md), preferably in the same pull request as the
change. Write them under `### Zed extension` from an extension user's
perspective, using `#### Added`, `#### Changed`, `#### Fixed`, or similar
headings. Internal refactors, tests, documentation-only changes, and routine
dependency updates usually do not need an entry.

The pinned JETLS release and the `### Language server` section are filled in
automatically during [release preparation](#releasing); do not edit them by
hand.

## Releasing

Zed builds and distributes this extension from the commit that the
`extensions/julia` submodule of
[zed-industries/extensions](https://github.com/zed-industries/extensions)
points to. A release tags that commit here, creates a GitHub release from its
changelog section, and then opens a pull request there that updates the
submodule and the version in `extensions.toml`.

Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html). To
release the extension:

1. Prepare the release branch and pull request:

   ```sh
   ./scripts/prepare-release.sh X.Y.Z
   ```

   The script branches `releases/vX.Y.Z` off `origin/main`, sets the version in
   `extension.toml`, `Cargo.toml`, and `Cargo.lock`, renames the `Unreleased`
   section of `CHANGELOG.md` to the release version (recording the
   [pinned JETLS release](#updating-the-pinned-jetls-release), linking the
   JETLS release notes since the previous release, and re-creating the
   `Unreleased` template), creates the `vX.Y.Z` release commit, and opens a
   pull request against `main`. Use `--no-push` to prepare the branch locally
   without pushing or opening the pull request. The script requires Julia,
   Cargo, and the GitHub CLI.

2. Wait for CI to pass on the pull request and review the generated changelog
   section. The regular checks, including the pinned JETLS release check, run
   on it, and [`release.yml`](./.github/workflows/release.yml) verifies that
   the branch name matches the manifests and the changelog, that the changelog
   records the pinned JETLS release, and that the release tag does not exist
   yet.

3. Merge the pull request. The release workflow pushes the `vX.Y.Z` tag at the
   merge commit, creates the GitHub release with the changelog section as its
   notes, and opens a pull request that updates the extension in
   zed-industries/extensions. The release branch can be deleted after merging.

4. Follow up on the zed-industries/extensions pull request until it is merged.
   Never move a published tag: if the registry review requires source changes,
   merge them here, prepare a new patch release, and close the outdated
   registry pull request.

The registry update authenticates with the `COMMITTER_TOKEN` repository secret:
a classic GitHub personal access token with the `repo` and `workflow` scopes.
The pull request is opened by the token owner from their fork of
zed-industries/extensions, which is created if it does not exist yet. Updating
the fork also syncs upstream workflow files, which requires the `workflow`
scope.
