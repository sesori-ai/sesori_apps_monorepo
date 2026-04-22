---
name: bridge-release
description: Automates the Sesori bridge release workflow — bumps version, generates changelog from git history, and creates a PR
compatibility: opencode
metadata:
  audience: maintainers
  workflow: github
---

# Bridge Release Skill

This skill automates the Sesori bridge release process. When invoked with a version number (e.g., `/bridge-release 0.4.0`), it will:

1. Run `dart run tool/bump_version.dart <version>` to update all version files
2. Run `git diff bridge-v<previous>..HEAD -- bridge/` to analyze commits and code changes since the last release
3. Parse commit messages and PR numbers from the git log to categorize changes (Added, Fixed, Changed)
4. Update `CHANGELOG.md` with the new version, today's date, and categorized changes
5. Create a new branch (`release/bridge-v<version>`)
6. Commit all changes
7. Create a GitHub Pull Request

## Workflow

### Step 1: Find the Latest Release Tag

Run the following to find the most recent bridge release tag:

```bash
git tag -l "bridge-v*" --sort=-v:refname | head -n 1
```

Let the user confirm the version they want to release. The user provides the new version as `$ARGUMENTS`.

### Step 2: Bump Version

Run the version bump tool from the `bridge/app/` directory:

```bash
cd bridge/app && dart run tool/bump_version.dart <version>
```

Stage the version-bumped files.

### Step 3: Analyze Changes Since Last Release

Find commits since the last release tag:

```bash
git log bridge-v<previous>..HEAD --oneline
```

To get the diff for bridge-specific changes:

```bash
git diff bridge-v<previous>..HEAD -- bridge/
git show --oneline --name-only bridge-v<previous>..HEAD
```

Categorize commits based on their prefixes:
- `feat:` or `feat(` → Added
- `fix:` or `fix(` → Fixed
- `chore:` → Changed (or skip unless significant)
- `docs:` → Changed
- `refactor:` → Changed

### Step 4: Update CHANGELOG.md

Read the existing `bridge/app/CHANGELOG.md` and add a new section at the top:

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

### Step 5: Stage CHANGELOG.md

```bash
git add CHANGELOG.md
```

### Step 6: Create Release Branch and Commit

```bash
git checkout -b release/bridge-v<version>
git commit -m "chore(release): bridge v<version>"
```

### Step 7: Create GitHub Pull Request

Use `gh` to create the PR:

```bash
gh pr create \
  --title "chore(release): bridge v<version>" \
  --body "$(cat <<'EOF'
## Summary
- Bump bridge version to v<version>
- Update CHANGELOG.md with changes since v<previous>

## Changes
<list the key changes>
EOF
)" \
  --base main
```

## Important Notes

- Always confirm the new version with the user before proceeding
- If there are no bridge-specific changes (the diff is empty), inform the user and ask if they still want to proceed
- The `bump_version.dart` script updates: `pubspec.yaml`, `lib/src/version.dart`, and all `npm/*/package.json` files
- The user must be authenticated with `gh` CLI (`gh auth status`)
- The PR is created against `main` branch
