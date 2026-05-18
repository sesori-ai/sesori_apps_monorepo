---
name: release
description: Automates the synchronized Sesori App + Bridge release workflow — bumps versions together, generates changelog entries, and creates a PR
compatibility: opencode
metadata:
  audience: maintainers
  workflow: github
---

# Release Skill

This skill automates the synchronized Sesori release process for both App and Bridge. When invoked with a release type (`patch`, `minor`, or `major`), it computes the next shared semantic version and bumps both app and bridge together.

## Workflow

### Step 1: Determine Release Type

Ask the user:

> What type of release is this? Options:
> 1. **patch** (e.g., 1.0.6 → 1.0.7) — bug fixes, small improvements
> 2. **minor** (e.g., 1.0.6 → 1.1.0) — new features, backwards compatible
> 3. **major** (e.g., 1.0.6 → 2.0.0) — breaking changes

If the user does not specify a release type, ask before proceeding.

Alternatively, the user may provide an explicit version: `make bump-version VERSION=<version>`.

### Step 2: Find the Latest Release Tag

Run the following to find the most recent shared release tag:

```bash
git tag -l "v*" --sort=-v:refname | head -n 1
```

### Step 3: Bump Versions

Run the root version bump command:

```bash
make bump-version TYPE=<type>
```

Or for an explicit version:

```bash
make bump-version VERSION=<version>
```

This updates both bridge and mobile semantic versions while preserving the mobile build number.

Stage the version-bumped files.

### Step 4: Analyze Changes Since Last Release

Find commits since the last release tag:

```bash
git log v<previous>..HEAD --oneline
```

To get diffs for each side:

```bash
git diff v<previous>..HEAD -- bridge/
git diff v<previous>..HEAD -- mobile/
git log --oneline --name-only v<previous>..HEAD
```

Categorize commits based on their prefixes:
- `feat:` or `feat(` → Added
- `fix:` or `fix(` → Fixed
- `chore:` → Changed (or skip unless significant)
- `docs:` → Changed
- `refactor:` → Changed

### Step 5: Update Root CHANGELOG.md

Read the existing `CHANGELOG.md` and add a new section below `## [Unreleased]`:

```markdown
## [<version>] - <YYYY-MM-DD>

### App
- <list of app changes, or "No changes">

### Bridge
- <list of bridge changes, or "No changes">
```

Use the actual categorized commits. Be specific about what each commit does, not just the commit message subject. When one side has no changes for this release, write exactly `- No changes`.

### Step 6: Stage CHANGELOG.md

```bash
git add CHANGELOG.md
```

### Step 7: Create Release Branch and Commit

```bash
git checkout -b release/v<version>
git commit -m "chore(release): v<version>"
```

### Step 8: Create GitHub Pull Request

Use `gh` to create the PR:

```bash
gh pr create \
  --title "chore(release): v<version>" \
  --body "$(cat <<'EOF'
## Summary
- Bump shared version to v<version>
- Update CHANGELOG.md with App and Bridge changes since v<previous>

## Changes
<list the key changes>
EOF
)" \
  --base main
```

## Important Notes

- Always confirm the release type or explicit version with the user before proceeding
- The root `make bump-version` command updates both bridge and mobile versions together
- The mobile build number is preserved during version bumps; do not increment it here
- If there are no changes on one side, use `- No changes` in that section of the changelog
- The user must be authenticated with `gh` CLI (`gh auth status`)
- The PR is created against `main` branch
- GitHub Actions workflows are not edited by this skill
