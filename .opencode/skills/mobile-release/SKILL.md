---
name: mobile-release
description: Automates the Sesori mobile app release workflow — bumps version and build number based on release type, generates changelog from git history, and creates a PR
compatibility: opencode
metadata:
  audience: maintainers
  workflow: github
---

# Mobile Release Skill

This skill automates the Sesori mobile app release process. When invoked, it asks the user what type of release this is (patch, minor, or major), then automatically computes the next version.

## Workflow

### Step 1: Determine Release Type

Ask the user:

> What type of release is this? Options:
> 1. **patch** (e.g., 1.0.5 → 1.0.6) — bug fixes, small improvements
> 2. **minor** (e.g., 1.0.5 → 1.1.0) — new features, backwards compatible
> 3. **major** (e.g., 1.0.5 → 2.0.0) — breaking changes

If the user does not specify a release type, ask before proceeding.

### Step 2: Find the Latest Release Tag

Run the following to find the most recent mobile release tag:

```bash
git tag -l "app-v*" --sort=-v:refname | head -n 1
```

### Step 3: Read Current Version

Read `mobile/app/pubspec.yaml` and extract the current version line:

```yaml
version: 1.0.5+7
```

The format is `version: <semver>+<build_number>`. Extract both the current semver and build number.

### Step 4: Compute New Version

Based on the release type, increment the appropriate semver component:

| Release Type | Rule | Example (from 1.0.5) |
|---|---|---|
| **patch** | Increment patch | `1.0.6` |
| **minor** | Increment minor, reset patch to 0 | `1.1.0` |
| **major** | Increment major, reset minor and patch to 0 | `2.0.0` |

Always increment the build number by 1 (e.g., `7` → `8`).

Show the computed version to the user and ask for confirmation before proceeding.

### Step 5: Bump Version and Build Number

Update the version line in `mobile/app/pubspec.yaml`:

```yaml
version: 1.0.6+8
```

Stage the modified file:

```bash
git add mobile/app/pubspec.yaml
```

### Step 6: Analyze Changes Since Last Release

Find commits since the last release tag:

```bash
git log app-v<previous>..HEAD --oneline
```

To get the diff for mobile-specific changes:

```bash
git diff app-v<previous>..HEAD -- mobile/
git show --oneline --name-only app-v<previous>..HEAD
```

Categorize commits based on their prefixes:
- `feat:` or `feat(` → Added
- `fix:` or `fix(` → Fixed
- `chore:` → Changed (or skip unless significant)
- `docs:` → Changed
- `refactor:` → Changed

### Step 7: Update CHANGELOG.md

Read the existing `mobile/app/CHANGELOG.md` (create it if it does not exist) and add a new section at the top:

```markdown
## [v<version>] - <YYYY-MM-DD>

### Added
- <list of added features>

### Fixed
- <list of bug fixes>

### Changed
- <list of changes>
```

Use the actual categorized commits. Be specific about what each commit does, not just the commit message subject.

### Step 8: Stage CHANGELOG.md

```bash
git add mobile/app/CHANGELOG.md
```

### Step 9: Create Release Branch and Commit

```bash
git checkout -b release/app-v<version>
git commit -m "chore(release): app v<version>"
```

### Step 10: Create GitHub Pull Request

Use `gh` to create the PR:

```bash
gh pr create \
  --title "chore(release): app v<version>" \
  --body "$(cat <<'EOF'
## Summary
- Bump mobile app version to v<version>
- Bump build number to <new_build_number>
- Update CHANGELOG.md with changes since v<previous>

## Changes
<list the key changes>
EOF
)" \
  --base main
```

## Important Notes

- Always ask for the release type (patch/minor/major) before proceeding
- Always confirm the computed version with the user before making changes
- If there are no mobile-specific changes (the diff is empty), inform the user and ask if they still want to proceed
- The user must be authenticated with `gh` CLI (`gh auth status`)
- The PR is created against `main` branch
- Build number is always incremented by 1, regardless of version bump size
