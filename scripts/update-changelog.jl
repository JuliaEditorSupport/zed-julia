#!/usr/bin/env julia

# Finalizes Unreleased using the version in `extension.toml` and the JETLS
# release pinned in `src/julia.rs`.
# Usage: julia --startup-file=no scripts/update-changelog.jl

using TOML

const REPOSITORY = "JuliaEditorSupport/zed-julia"
const SERVER_REPOSITORY = "aviatesk/JETLS.jl"
const REPOSITORY_URL = "https://github.com/$REPOSITORY"
const SERVER_URL = "https://github.com/$SERVER_REPOSITORY"
const VERSION_PATTERN = r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$"
const REVISION_PATTERN = r"^20\d{2}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$"
const REVISION_CONST_PATTERN = r"^const JETLS_REVISION: &str = \"(.*)\";$"m
const PIN_PLACEHOLDER = "<!-- Set during release preparation; do not edit by hand. -->"
const SERVER_PLACEHOLDER = "<!-- Generated during release preparation; do not edit by hand. -->"
const SERVER_SECTION = "Language server"
const EXTENSION_SECTION = "Zed extension"

struct ChangelogError <: Exception
    msg::String
end

Base.showerror(io::IO, err::ChangelogError) = print(io, err.msg)

fail(msg::String) = throw(ChangelogError(msg))

function validate_version(version::String)
    occursin(VERSION_PATTERN, version) || fail("Invalid extension version: $version")
    return version
end

function validate_tag(tag::String)
    (startswith(tag, 'v') && occursin(VERSION_PATTERN, chopprefix(tag, "v"))) ||
        fail("Invalid previous release tag: $tag")
    return tag
end

function validate_revision(revision::String, description::String)
    occursin(REVISION_PATTERN, revision) || fail("Invalid $description: $revision")
    return revision
end

capture(m::RegexMatch, index::Int) = String(something(m.captures[index]))

struct Heading
    line::Int
    level::Int
    title::String
end

# Lines inside fenced code blocks and HTML comments never start a section.
function markdown_headings(lines::Vector{String})
    headings = Heading[]
    fence = ""
    in_comment = false
    for (i, line) in enumerate(lines)
        if !isempty(fence)
            m = match(r"^ {0,3}(`{3,}|~{3,})\s*$", line)
            if m !== nothing
                marker = capture(m, 1)
                if first(marker) == first(fence) && length(marker) >= length(fence)
                    fence = ""
                end
            end
        elseif in_comment
            in_comment = !occursin("-->", line)
        elseif (m = match(r"^ {0,3}(`{3,}|~{3,})", line)) !== nothing
            fence = capture(m, 1)
        elseif (m = match(r"^(#{2,6}) (.+)$", line)) !== nothing
            push!(headings, Heading(i, length(capture(m, 1)), rstrip(capture(m, 2))))
        else
            in_comment = occursin(r"<!--(?:(?!-->).)*$", line)
        end
    end
    return headings
end

function release_metadata(tag::String, previous_tag::String)
    return [
        "- Commit: [`$tag`]($REPOSITORY_URL/commit/$tag)",
        "- Diff: [`$previous_tag...$tag`]($REPOSITORY_URL/compare/$previous_tag...$tag)",
    ]
end

function server_section(
        previous_revision::String, revision::String, releases::Vector{String})
    previous_revision == revision && return String[]
    rollback = revision < previous_revision
    action = rollback ? "Rolled back" : "Updated"
    versions = sort!(unique!(filter(releases) do tag
        occursin(REVISION_PATTERN, tag) &&
            (rollback ? tag == revision : previous_revision < tag <= revision)
    end))
    revision in versions || fail("Missing published server release notes for $revision")
    # Three-dot comparisons hide removals when the target is an ancestor.
    comparison = string(previous_revision, rollback ? ".." : "...", revision)
    return [
        "### $SERVER_SECTION",
        "",
        "$action managed JETLS from `$previous_revision` to `$revision`.",
        "",
        ["- [Release notes for $tag]($SERVER_URL/releases/tag/$tag)" for tag in versions]...,
        "- [Full server diff]($SERVER_URL/compare/$comparison)",
    ]
end

isblank(line::String) = all(isspace, line)

function trim_blank_lines(lines::Vector{String})
    first_line = something(findfirst(!isblank, lines), length(lines) + 1)
    last_line = something(findlast(!isblank, lines), 0)
    return lines[first_line:last_line]
end

function finalize_changelog(changelog::String;
        version::String, revision::String, previous_tag::String,
        previous_revision::String, releases::Vector{String})
    validate_version(version)
    validate_tag(previous_tag)
    validate_revision(revision, "JETLS revision")
    validate_revision(previous_revision, "previous JETLS revision")
    tag = "v$version"

    lines = String.(split(changelog, '\n'))
    headings = markdown_headings(lines)
    sections = filter(heading -> heading.level == 2, headings)
    (!isempty(sections) && sections[1].title == "Unreleased" &&
        count(heading -> heading.title == "Unreleased", sections) == 1) ||
        fail("Expected exactly one Unreleased section before the released history")
    any(heading -> heading.title == tag, sections) &&
        fail("Release $tag already exists in the CHANGELOG")
    (length(sections) >= 2 && sections[2].title == previous_tag) ||
        fail("Latest CHANGELOG release does not match published release tag $previous_tag")

    unreleased_start, unreleased_stop = sections[1].line, sections[2].line
    unreleased = lines[unreleased_start+1:unreleased_stop-1]
    (length(unreleased) >= 5 &&
        unreleased[1:3] == ["", release_metadata("HEAD", previous_tag)...] &&
        startswith(unreleased[4], "- Pinned JETLS:") && isblank(unreleased[5])) ||
        fail("Invalid Unreleased metadata; expected $previous_tag...HEAD and a Pinned JETLS field")
    subsections = filter(headings) do heading
        heading.level == 3 && unreleased_start < heading.line < unreleased_stop
    end
    [heading.title for heading in subsections] == [SERVER_SECTION, EXTENSION_SECTION] ||
        fail("Expected '### $SERVER_SECTION' followed by '### $EXTENSION_SECTION' in Unreleased")
    server_lines = trim_blank_lines(lines[subsections[1].line+1:subsections[2].line-1])
    (isempty(server_lines) || server_lines == [SERVER_PLACEHOLDER]) ||
        fail("'### $SERVER_SECTION' is generated; move entries to '### $EXTENSION_SECTION'")
    extension_lines = trim_blank_lines(lines[subsections[2].line+1:unreleased_stop-1])

    released = [
        "## $tag",
        "",
        release_metadata(tag, previous_tag)...,
        "- Pinned JETLS: [`$revision`]($SERVER_URL/releases/tag/$revision)",
    ]
    server_lines = server_section(previous_revision, revision, releases)
    isempty(server_lines) || append!(released, ["", server_lines...])
    isempty(extension_lines) ||
        append!(released, ["", "### $EXTENSION_SECTION", "", extension_lines...])

    return join([
        lines[1:unreleased_start-1]...,
        "## Unreleased",
        "",
        release_metadata("HEAD", tag)...,
        "- Pinned JETLS: $PIN_PLACEHOLDER",
        "",
        "### $SERVER_SECTION",
        "",
        SERVER_PLACEHOLDER,
        "",
        "### $EXTENSION_SECTION",
        "",
        released...,
        "",
        lines[unreleased_stop:end]...,
    ], '\n')
end

function read_revision(source::String, description::String)
    m = @something match(REVISION_CONST_PATTERN, source) fail(
        "Could not find `const JETLS_REVISION` in $description")
    return validate_revision(capture(m, 1), "JETLS revision in $description")
end

gh(args::String...) = String(readchomp(`gh $args`))

function (@main)(args::Vector{String})
    if !isempty(args)
        println(stderr, "Usage: julia --startup-file=no scripts/update-changelog.jl")
        return 2
    end
    root = dirname(@__DIR__)
    changelog_path = joinpath(root, "CHANGELOG.md")
    try
        version = TOML.parsefile(joinpath(root, "extension.toml"))["version"]::String
        source = read(joinpath(root, "src", "julia.rs"), String)
        revision = read_revision(source, "src/julia.rs")
        previous_tag = validate_tag(
            gh("api", "repos/$REPOSITORY/releases/latest", "--jq", ".tag_name"))
        previous_source = gh("api", "-H", "Accept: application/vnd.github.raw",
            "repos/$REPOSITORY/contents/src/julia.rs?ref=$previous_tag")
        previous_revision = read_revision(previous_source, "src/julia.rs at $previous_tag")
        releases = previous_revision == revision ? String[] : String.(split(gh(
            "api", "--paginate", "repos/$SERVER_REPOSITORY/releases?per_page=100",
            "--jq", ".[] | select((.draft or .prerelease) | not) | .tag_name"), '\n'))
        changelog = finalize_changelog(read(changelog_path, String);
            version, revision, previous_tag, previous_revision, releases)
        write(changelog_path, changelog)
    catch err
        err isa Union{ChangelogError,ProcessFailedException} || rethrow()
        println(stderr, "Error: ", sprint(showerror, err))
        return 1
    end
    println("Updated CHANGELOG.md")
    return 0
end
