---
name: update-backend-runtimes
description: Update the targeted OpenCode, Codex, and Cursor CLI runtime versions used by the Sesori bridge. Use when asked to update, bump, or refresh the coding backend runtimes, their minimum versions, or their release checksums.
---

# Update Backend Runtimes

Update the bridge's OpenCode, Codex, and Cursor CLI targets to the latest stable releases. This is separate from the general Dart/Flutter dependency update workflow.

## Scope

- OpenCode managed runtime and PATH minimum:
  `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_runtime_manifest.dart`
- OpenCode API surface metadata:
  `bridge/sesori_plugin_opencode/tool/opencode_v1_surface.json`
- OpenCode manifest tests:
  `bridge/sesori_plugin_opencode/test/runtime/open_code_runtime_manifest_test.dart`
- Codex managed runtime and PATH minimum:
  `bridge/sesori_plugin_codex/lib/src/runtime/codex_runtime_manifest.dart`
- Codex manifest tests:
  `bridge/sesori_plugin_codex/test/runtime/codex_runtime_manifest_test.dart`
- Cursor CLI minimum build:
  `bridge/sesori_plugin_cursor/lib/src/runtime/cursor_runtime_manifest.dart`
- Cursor managed runtime (pinned build + per-platform checksums):
  `bridge/sesori_plugin_cursor/lib/src/runtime/cursor_runtime_manifest.dart`
- Cursor manifest tests:
  `bridge/sesori_plugin_cursor/test/runtime/cursor_runtime_manifest_test.dart`
- Cursor availability tests:
  `bridge/sesori_plugin_cursor/test/cursor_plugin_descriptor_availability_test.dart`

Read `bridge/AGENTS.md` before editing. Never hand-edit generated files.

## Version Policy

- Update OpenCode's `bundledVersion` to the latest stable `anomalyco/opencode` GitHub release.
- Update Codex's `bundledVersion` to the latest stable `openai/codex` GitHub release.
- Update Cursor's `minVersion` to the calendar date of the current build advertised by the official installer at `https://cursor.com/install`.
- Do not raise OpenCode's `minPathVersion` unless the user gives a specific minimum or bridge code requires a newer API. If it changes, keep `opencode_v1_surface.json` metadata aligned.
- Do not raise Codex's `minPathVersion` unless bridge code requires a newer app-server capability or the user explicitly requests it.
- Ignore prereleases. Confirm GitHub's `latest` release and the corresponding npm package version agree for OpenCode and Codex when npm is available.

## Discover Releases

Fetch concise release data instead of printing complete release payloads.

### OpenCode

```bash
gh api repos/anomalyco/opencode/releases/latest --jq '{tag: .tag_name, prerelease: .prerelease, assets: [.assets[] | select(.name == "opencode-darwin-arm64.zip" or .name == "opencode-darwin-x64.zip" or .name == "opencode-linux-arm64.tar.gz" or .name == "opencode-linux-x64.tar.gz" or .name == "opencode-windows-arm64.zip" or .name == "opencode-windows-x64.zip") | {name, digest}]}'
npm view opencode-ai version
```

Require exactly these six assets and a non-null `sha256:` digest for each:

- `opencode-darwin-arm64.zip`
- `opencode-darwin-x64.zip`
- `opencode-linux-arm64.tar.gz`
- `opencode-linux-x64.tar.gz`
- `opencode-windows-arm64.zip`
- `opencode-windows-x64.zip`

Strip the `sha256:` prefix when writing each digest into the manifest.

### Codex

```bash
gh api repos/openai/codex/releases/latest --jq '{tag: .tag_name, prerelease: .prerelease, assets: [.assets[] | select(.name == "codex-aarch64-apple-darwin.tar.gz" or .name == "codex-x86_64-apple-darwin.tar.gz" or .name == "codex-aarch64-unknown-linux-musl.tar.gz" or .name == "codex-x86_64-unknown-linux-musl.tar.gz" or .name == "codex-aarch64-pc-windows-msvc.exe.zip" or .name == "codex-x86_64-pc-windows-msvc.exe.zip") | {name, digest}]}'
npm view @openai/codex version
```

Codex release tags use `rust-vX.Y.Z`; store only `X.Y.Z` in the manifest. Require exactly these six assets and strip the `sha256:` prefix from their digests:

- `codex-aarch64-apple-darwin.tar.gz`
- `codex-x86_64-apple-darwin.tar.gz`
- `codex-aarch64-unknown-linux-musl.tar.gz`
- `codex-x86_64-unknown-linux-musl.tar.gz`
- `codex-aarch64-pc-windows-msvc.exe.zip`
- `codex-x86_64-pc-windows-msvc.exe.zip`

Confirm asset filenames have not changed before editing. Do not guess mappings for renamed or missing assets.

### Cursor

Fetch the official installer without executing it:

```bash
curl -fsSL https://cursor.com/install
```

Extract the build identifier used in both the version directory and download URL, for example `2026.07.16-899851b`. Do not install or update Cursor locally just to discover the version. If the installer does not expose one unambiguous build identifier, stop and report the blocker rather than guessing.

Cursor comparison parses only the leading `YYYY.MM.DD` calendar version. Store that date in `minVersion` so the displayed requirement exactly matches enforcement.

#### Cursor managed runtime checksums

Cursor publishes no digest manifest, so the manifest's SHA-256 values are computed by us at pin time. Download all four published packages for the build and hash them:

```bash
BUILD=2026.08.04-aaa8809   # the installer's build identifier
D=$(mktemp -d)
for t in darwin/arm64 darwin/x64 linux/arm64 linux/x64; do
  curl -fsSL -o "$D/$(echo $t | tr / -).tar.gz" \
    "https://downloads.cursor.com/lab/$BUILD/$t/agent-cli-package.tar.gz"
done
shasum -a 256 "$D"/*.tar.gz
```

Write `_bundledVersion` as the exact published build string (`2026.08.04-aaa8809`). Preserve its `CalendarRuntimeVersion.raw` value in the download URL and version directory. There is no Windows package — leave `PlatformOs.windows` absent so the install capability stays off there.

Cursor ships a `dist-package/` directory whose `cursor-agent` entry binary loads sibling files, so its assets use `RuntimeAssetLayout.packageDirectory`. If a future build ships a single self-contained binary instead, switch the layout rather than flattening the tree.

Because the digests are self-computed, a silently re-published asset fails checksum verification at install time with a clear message. That is intended: re-pin rather than relaxing verification.

## Edit

1. Update OpenCode's bundled version and all six matching SHA-256 values.
2. Apply an explicitly requested OpenCode minimum and synchronize the API surface metadata comment; otherwise preserve the existing minimum.
3. Update Codex's bundled version, release-version documentation, and all six matching SHA-256 values.
4. Preserve the Codex minimum unless a concrete requirement says otherwise.
5. Update Cursor's minimum to the official current build's calendar date, and update `CursorRuntimeManifest`'s `_bundledVersion` plus all four computed SHA-256 values.
6. Update hard-coded version URLs, version assertions, and recent-version fixtures in the three manifest/availability tests.
7. Search the affected plugin packages for the replaced target versions. Update only references that describe the current pin; preserve historical comments and protocol-shape observations tied to older versions.
8. Run `dart format` on changed Dart files.

Use `apply_patch` for manual edits.

## Verify

Run the plugin suites independently; they may run in parallel:

```bash
(cd bridge/sesori_plugin_opencode && dart test && dart analyze --fatal-infos)
(cd bridge/sesori_plugin_codex && dart test && dart analyze --fatal-infos)
(cd bridge/sesori_plugin_cursor && dart test && dart analyze --fatal-infos)
(cd bridge/sesori_plugin_runtime && dart test && dart analyze --fatal-infos)
git diff --check
```

For Cursor, also confirm the pinned download URL resolves before committing (a
wrong build string 404s only at install time on a user's machine):

```bash
curl -fsSI "https://downloads.cursor.com/lab/$BUILD/darwin/arm64/agent-cli-package.tar.gz" | head -1
```

If tests fail only because old versions are hard-coded in manifest assertions or availability fixtures, update those assertions to the new targets and rerun. Investigate all other failures normally.

Before finishing, report:

- old and new bundled/minimum versions for each backend
- whether OpenCode or Codex compatibility floors changed and why
- whether all twelve GitHub asset digests were refreshed
- Cursor's installer-advertised build, and whether its four managed-runtime digests were recomputed
- test and analyzer results

Do not commit, push, or create a PR unless the user asks.
