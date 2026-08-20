---
name: update-backend-runtimes
description: Update the target OpenCode, Codex, Cursor, Claude Code, Hermes Agent, Pi, and OMP CLI versions used by the Sesori bridge. Use when asked to update, bump, or refresh coding harness targets, managed runtimes, or release checksums while preserving compatibility minimums.
---

# Update Plugin Harness Targets

Update every registered bridge harness target to its latest stable release. This
includes managed-runtime pins and direct-CLI validation metadata, never an
implicit compatibility-floor increase, and is separate from the general
Dart/Flutter dependency update workflow.

## Scope

- OpenCode managed target and PATH minimum:
  `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_runtime_manifest.dart`
- OpenCode API surface metadata:
  `bridge/sesori_plugin_opencode/tool/opencode_v1_surface.json`
- OpenCode manifest tests:
  `bridge/sesori_plugin_opencode/test/runtime/open_code_runtime_manifest_test.dart`
- Codex managed target and PATH minimum:
  `bridge/sesori_plugin_codex/lib/src/runtime/codex_runtime_manifest.dart`
- Codex manifest tests:
  `bridge/sesori_plugin_codex/test/runtime/codex_runtime_manifest_test.dart`
- Claude Code direct-CLI target and minimum:
  `bridge/sesori_plugin_claude/lib/src/runtime/claude_plugin_descriptor.dart`
- Claude Code descriptor tests:
  `bridge/sesori_plugin_claude/test/runtime/claude_plugin_descriptor_test.dart`
- Cursor managed target, PATH minimum, and per-platform checksums:
  `bridge/sesori_plugin_cursor/lib/src/runtime/cursor_runtime_manifest.dart`
- Cursor manifest tests:
  `bridge/sesori_plugin_cursor/test/runtime/cursor_runtime_manifest_test.dart`
- Cursor availability tests:
  `bridge/sesori_plugin_cursor/test/cursor_plugin_descriptor_availability_test.dart`
- Hermes Agent direct-CLI target and minimum:
  `bridge/sesori_plugin_hermes/lib/src/runtime/hermes_plugin_descriptor.dart`
- Hermes Agent descriptor tests:
  `bridge/sesori_plugin_hermes/test/hermes_plugin_descriptor_test.dart`
- Pi managed target, PATH minimum, package archives, and per-platform checksums:
  `bridge/sesori_plugin_pi/lib/src/runtime/pi_runtime_manifest.dart`
- Pi runtime and lifecycle tests:
  `bridge/sesori_plugin_pi/test/pi_runtime_manifest_test.dart`
  `bridge/sesori_plugin_pi/test/pi_plugin_descriptor_test.dart`
- OMP managed target, PATH minimum, direct assets, and per-platform checksums:
  `bridge/sesori_plugin_omp/lib/src/runtime/omp_runtime_manifest.dart`
- OMP runtime and lifecycle tests:
  `bridge/sesori_plugin_omp/test/omp_runtime_manifest_test.dart`
  `bridge/sesori_plugin_omp/test/omp_plugin_descriptor_test.dart`
- Registered harness source of truth:
  `bridge/app/lib/src/bridge/runtime/plugin_registry.dart`
- Setup and lifecycle regression contract when a compatibility floor changes:
  `docs/regression/plugin-setup-and-lifecycle.md`

Read `bridge/AGENTS.md` before editing. Never hand-edit generated files.

Before release discovery, inspect `knownPlugins` in `plugin_registry.dart` and
confirm every concrete descriptor has a section in this skill. The current
closed set is OpenCode, Codex, Cursor, Claude Code, Hermes Agent, Pi, and Oh My
Pi. Shared interface, runtime, and ACP packages are not harnesses. If the
registry has gained another harness, extend this skill for it as part of the
same change instead of silently skipping it.

Every harness must expose an independent compatibility minimum and target:

| Harness | Compatibility minimum | Latest target |
| --- | --- | --- |
| OpenCode | `OpenCodeRuntimeManifest.minPathVersion` | `OpenCodeRuntimeManifest.targetVersion` |
| Codex | `CodexRuntimeManifest.minPathVersion` | `CodexRuntimeManifest.targetVersion` |
| Claude Code | `ClaudePluginDescriptor.minVersion` | `ClaudePluginDescriptor.targetVersion` |
| Cursor | `CursorRuntimeManifest.minPathVersion` | `CursorRuntimeManifest.targetVersion` |
| Hermes Agent | `HermesPluginDescriptor.minVersion` | `HermesPluginDescriptor.targetVersion` |
| Pi | `PiRuntimeManifest.minPathVersion` | `PiRuntimeManifest.targetVersion` |
| Oh My Pi | `OmpRuntimeManifest.minPathVersion` | `OmpRuntimeManifest.targetVersion` |

For managed runtimes, `bundledVersion` is the parsed exact target used for
download and installation. Direct-CLI targets record the latest release whose
surface was validated; they do not gate otherwise-compatible local installs.

## Version Policy

- A target refresh preserves every compatibility minimum byte-for-byte. Never
  derive a minimum from the latest target or raise one merely because a newer
  release exists.
- Update OpenCode's `targetVersion` to the latest stable `anomalyco/opencode` GitHub release.
- Update Codex's `targetVersion` to the latest stable `openai/codex` GitHub release.
- Update Claude Code's direct-CLI `targetVersion` to the latest stable
  `anthropics/claude-code` release after the candidate stream-json surface
  probe passes.
- Update Cursor's `targetVersion` to the current build advertised by the official installer at `https://cursor.com/install`.
- Update Hermes Agent's direct-CLI `targetVersion` to the semantic package
  version in the latest stable `NousResearch/hermes-agent` release after its
  ACP v1 probe passes. Its calendar release tag is not the CLI version.
- Update Pi's `targetVersion` to the latest stable `earendil-works/pi` GitHub release only after its JSONL RPC probe passes.
- Update OMP's `targetVersion` to the latest stable `can1357/oh-my-pi` GitHub release only after its ACP v1 probe passes.
- Change a compatibility minimum only for a separate, explicit requirement
  backed by a concrete newer capability. If OpenCode's minimum changes under
  such a requirement, keep `opencode_v1_surface.json` metadata aligned.
- Ignore prereleases. Confirm GitHub's `latest` release and the corresponding npm package version agree for OpenCode, Codex, and Claude Code when npm is available.

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

### Claude Code

```bash
gh api repos/anthropics/claude-code/releases/latest --jq '{tag: .tag_name, prerelease: .prerelease, publishedAt: .published_at}'
npm view @anthropic-ai/claude-code version
npm view @anthropic-ai/claude-agent-sdk version
```

Require the stable GitHub `vX.Y.Z` tag and `@anthropic-ai/claude-code` npm
version to agree. Confirm the current Agent SDK release associated with that CLI;
its patch currently tracks the CLI patch under the `0.3.x` line, but inspect the
published versions rather than assuming that scheme will never change.

Use the official current-host CLI package in an isolated temporary directory to
verify `claude --version`. Check `claude --help` for every public flag in
`ClaudeLaunchSpec`, and inspect the matching Agent SDK launch code for the
headless stream-json and stdio permission flags. Stop if a flag the production
launch requires disappeared or changed semantics. A version/help/source smoke
does not re-verify wire observations, so preserve historical protocol documents
and `Verified against` comments unless a live protocol trace was actually
repeated.

### Cursor

Fetch the official installer without executing it:

```bash
curl -fsSL https://cursor.com/install
```

Extract the build identifier used in both the version directory and download URL, for example `2026.07.16-899851b`. Do not install or update Cursor locally just to discover the version. If the installer does not expose one unambiguous build identifier, stop and report the blocker rather than guessing.

Cursor comparison parses only the leading `YYYY.MM.DD` calendar version. Preserve
the current `minPathVersion` unless a concrete capability requirement changes;
the bundled build remains an independent exact pin.

#### Cursor managed runtime checksums

Cursor publishes no digest manifest, so the manifest's SHA-256 values are computed by us at pin time. Download all four published packages for the build and hash them:

```bash
BUILD=2026.08.11-e8db854   # the installer's build identifier
D=$(mktemp -d)
for t in darwin/arm64 darwin/x64 linux/arm64 linux/x64; do
  name=${t//\//-}
  curl -fsSL -o "$D/$name.tar.gz" \
    "https://downloads.cursor.com/lab/$BUILD/$t/agent-cli-package.tar.gz"
done
shasum -a 256 "$D"/*.tar.gz
```

Write `targetVersion` as the exact published build string (for example `2026.08.11-e8db854`) and derive `_bundledVersion` from it. Preserve its `CalendarRuntimeVersion.raw` value in the download URL and version directory. There is no Windows package — leave `PlatformOs.windows` absent so the install capability stays off there.

Cursor ships a `dist-package/` directory whose `cursor-agent` entry binary loads sibling files, so its assets use `RuntimeAssetLayout.packageDirectory`. If a future build ships a single self-contained binary instead, switch the layout rather than flattening the tree.

Because the digests are self-computed, a silently re-published asset fails checksum verification at install time with a clear message. That is intended: re-pin rather than relaxing verification.

### Hermes Agent

```bash
gh api repos/NousResearch/hermes-agent/releases/latest --jq '{tag: .tag_name, name: .name, prerelease: .prerelease, publishedAt: .published_at}'
```

Hermes uses calendar Git tags such as `v2026.8.18` while
`hermes acp --version` reports a semantic package version such as `0.20.4`. Read the
semantic version from the release name and the tagged `pyproject.toml`, and
require them to agree. PyPI is not the release source: Hermes is distributed by
its shell installer, Docker, and Nix, and its PyPI project may lag.

Do not execute the remote installer merely to discover a version. Check out the
exact release tag in an isolated temporary directory, install the tagged source
with its `acp` extra in an isolated environment, and verify
`hermes acp --version`, ACP v1 `initialize`, advertised list/load capabilities, and
`session/list`. Use an isolated `HOME` so the probe cannot read or mutate the
user's Hermes profile. A fresh profile has no model/provider, so `session/new`
may remain setup-blocked; when a safe configured fixture is available, also
probe `session/new` and `session/load`. Stop on protocol regression.

### Pi

```bash
gh api repos/earendil-works/pi/releases/latest --jq '{tag: .tag_name, prerelease: .prerelease, assets: [.assets[] | select(.name == "pi-darwin-arm64.tar.gz" or .name == "pi-darwin-x64.tar.gz" or .name == "pi-linux-arm64.tar.gz" or .name == "pi-linux-x64.tar.gz" or .name == "pi-windows-arm64.zip" or .name == "pi-windows-x64.zip") | {name, digest}]}'
```

Require exactly six archive assets with non-null GitHub `sha256:` digests. macOS and Linux archives wrap a complete `pi/` package tree; Windows archives are flat package trees. Preserve `RuntimeArchiveLayout.packageDirectory` so the managed entry remains beside its assets, native modules, and metadata. Never flatten these archives to a lone executable or invoke Pi's installer scripts.

Before changing the pin, install one official current-host archive into an isolated temporary directory, verify `pi --version`, then launch `pi --mode rpc --no-session --approve` with `PI_SKIP_VERSION_CHECK=1` and verify a correlated `get_state` response. Preserve the user's normal Pi profile/config variables and stop if the RPC probe regresses.

### OMP

```bash
gh api repos/can1357/oh-my-pi/releases/latest --jq '{tag: .tag_name, prerelease: .prerelease, assets: [.assets[] | select(.name == "omp-darwin-arm64" or .name == "omp-darwin-x64" or .name == "omp-linux-arm64" or .name == "omp-linux-x64" or .name == "omp-linux-musl-arm64" or .name == "omp-linux-musl-x64" or .name == "omp-windows-x64.exe" or .name == "SHA256SUMS.txt") | {name, digest}]}'
```

Require exactly seven bare executable assets plus `SHA256SUMS.txt`: macOS arm64/x64, Linux glibc arm64/x64, Linux musl arm64/x64, and Windows x64. OMP publishes no Windows arm64 executable. Confirm each executable digest against both GitHub's `sha256:` digest and `SHA256SUMS.txt`; never model these raw files as archives.

Before changing the pin, run the official candidate in an isolated temporary cwd/profile and verify `omp/<version>`, ACP v1 `initialize`, `authenticate(agent)`, `session/list`, `session/new`, `session/load`, and persisted cleanup. Point `PI_CODING_AGENT_DIR` at the temporary profile, inherit the remaining environment, and do not alter the user's normal profile or approval policy. Stop if any protocol check regresses.

## Edit

1. Update OpenCode's target version and all six matching SHA-256 values.
2. Update Codex's target version, release-version documentation, and all six matching SHA-256 values.
3. Update Claude Code's direct-CLI target and descriptor test fixtures after the candidate probe passes.
4. Update `CursorRuntimeManifest.targetVersion` to the official current build and refresh all four computed SHA-256 values.
5. Update Hermes Agent's direct-CLI target and descriptor test fixtures after the tagged-source ACP probe passes.
6. Update `PiRuntimeManifest.targetVersion` only after the isolated JSONL RPC probe passes; refresh all six SHA-256 values and preserve complete package-directory placement.
7. Update `OmpRuntimeManifest.targetVersion` only after the isolated ACP probe passes; refresh all seven SHA-256 values and preserve glibc/musl and unsupported Windows arm64 mapping.
8. Verify every minimum is unchanged from the base branch. A target-only update must not modify a minimum-version line or an outdated-version test boundary.
9. Update hard-coded version URLs, version assertions, and recent-target fixtures in all manifest/availability tests.
10. Search the affected plugin packages for the replaced target versions. Update only references that describe the current target; preserve minimum-version fixtures, historical comments, and protocol-shape observations tied to older versions.
11. Update the setup/lifecycle regression document only for a separately requested compatibility-floor change, then run `dart format` on changed Dart files.

Use `apply_patch` for manual edits.

## Verify

Run the plugin suites independently; they may run in parallel:

```bash
(cd bridge/sesori_plugin_opencode && dart test && dart analyze --fatal-infos)
(cd bridge/sesori_plugin_codex && dart test && dart analyze --fatal-infos)
(cd bridge/sesori_plugin_claude && dart test && dart analyze --fatal-infos)
(cd bridge/sesori_plugin_cursor && dart test && dart analyze --fatal-infos)
(cd bridge/sesori_plugin_hermes && dart test && dart analyze --fatal-infos)
(cd bridge/sesori_plugin_pi && dart test && dart analyze --fatal-infos)
(cd bridge/sesori_plugin_omp && dart test && dart analyze --fatal-infos)
(cd bridge/sesori_plugin_runtime && dart test && dart analyze --fatal-infos)
git diff --check
```

For Cursor, also confirm the pinned download URL resolves before committing (a
wrong build string 404s only at install time on a user's machine):

```bash
BUILD=2026.08.11-e8db854
curl -fsSI --output /dev/null "https://downloads.cursor.com/lab/$BUILD/darwin/arm64/agent-cli-package.tar.gz"
```

If tests fail only because old versions are hard-coded in manifest assertions or availability fixtures, update those assertions to the new targets and rerun. Investigate all other failures normally.

Before finishing, report:

- old and new target versions plus the unchanged minimum for every registered harness
- confirmation that no compatibility floor changed
- whether all twelve GitHub asset digests were refreshed
- Claude Code's stable GitHub/npm target, matching Agent SDK version, unchanged direct-CLI floor, and stream-json surface probe result
- Cursor's installer-advertised build, and whether its four managed-runtime digests were recomputed
- Hermes Agent's calendar release tag, semantic CLI target, unchanged direct-CLI floor, and isolated ACP probe result
- Pi's release, six verified package-archive digests, and JSONL RPC probe result
- OMP's release, seven verified bare-executable digests, and ACP probe result
- test and analyzer results

Follow the repository's normal commit, push, and PR policy.
