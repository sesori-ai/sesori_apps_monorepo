---
name: update-dependencies
description: Weekly dependency update workflow for Sesori Apps Monorepo. Updates every pubspec.yaml across the bridge and client workspaces plus standalone packages, regenerates all lockfiles, re-resolves iOS/macOS SwiftPM native dependencies (Package.resolved), updates Fastlane/Gemfile versions, handles conflicts, and verifies via analyze/test/codegen.
---

<objective>
Systematically update all project dependencies across both Dart workspaces and standalone packages while maintaining stability, tracking conflicts, and ensuring proper commit hygiene.
</objective>

<project_structure>
<workspaces>
The repo has two Dart workspaces and two standalone packages. Workspace members share a single resolution; standalone packages resolve independently.

**Client workspace** (`client/pubspec.yaml` is the workspace root, has `flutter` env constraint):

- `client/pubspec.yaml` — workspace root, env only
- `client/module_auth/pubspec.yaml`
- `client/module_core/pubspec.yaml`
- `client/module_prego/pubspec.yaml` (Flutter package — theme/assets)
- `client/module_desktop_core/pubspec.yaml` (pure Dart desktop business logic)
- `client/app/pubspec.yaml` (Flutter app — Firebase, flutter_bloc, etc.)
- `client/desktop/pubspec.yaml` (Flutter desktop app)

**Bridge workspace** (`bridge/pubspec.yaml` is the workspace root, pure Dart):

- `bridge/pubspec.yaml` — workspace root, env only
- `bridge/sesori_plugin_interface/pubspec.yaml`
- `bridge/sesori_bridge_foundation/pubspec.yaml` (depends on `sesori_plugin_interface`; bridge-wide shared primitives)
- `bridge/sesori_plugin_runtime/pubspec.yaml` (depends on `sesori_plugin_interface`)
- `bridge/sesori_plugin_opencode/pubspec.yaml`
- `bridge/sesori_plugin_codex/pubspec.yaml`
- `bridge/sesori_plugin_acp/pubspec.yaml`
- `bridge/sesori_plugin_cursor/pubspec.yaml`
- `bridge/app/pubspec.yaml` (CLI relay server)

**Standalone packages** (NOT in any workspace — resolve independently with their own lockfile):

- `shared/sesori_shared/pubspec.yaml` — pure Dart; consumed by both workspaces via `path:` dep
- `shared/no_slop_linter/pubspec.yaml` — pure Dart analyzer plugin; consumed by `module_prego` via `path:` dev_dep

**IMPORTANT**: Update `shared/sesori_shared` FIRST because both workspaces depend on it.

**DO NOT update `shared/no_slop_linter`** as part of this workflow. Its analyzer/`_fe_analyzer_shared` constraints span multiple majors intentionally and break easily — bumps are done manually, less often, by a human. Skip its pubspec edits in Phase 3, but still run `make analyze`/`make test` against it via the shared `Makefile` for verification.
</workspaces>

<ios_files>
Sesori iOS is **Swift Package Manager only** — there is no Podfile, and CocoaPods is not part of the iOS dependency graph. Do not run `pod install` or attempt to add Podfile handling here.

- `client/app/ios/Gemfile` (fastlane gem only)
- `client/app/ios/Gemfile.lock`
</ios_files>

<android_files>

- `client/app/android/Gemfile` (fastlane gem)
- `client/app/android/Gemfile.lock`
</android_files>

<swiftpm_files>
iOS and macOS pull native dependencies (Firebase, Google SDKs, leveldb, gRPC, etc.) via Swift Package Manager. The resolved native versions are pinned in `Package.resolved` lockfiles. With the Flutter + Xcode SPM integration, the plugin packages are registered at the **project** level, so the **build-authoritative** copies — the ones `flutter build` regenerates and the shipped build actually uses — are the project-workspace copies:

- `client/app/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `client/app/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

These are the two files Phase 5 refreshes and commits. The sibling `Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved` copies are NOT touched by `flutter build` (they sit stale/divergent from the project copies) — leave them alone; do not hand-edit or force-sync them.

These lockfiles change on most weekly runs because native SDK patch releases land continuously, **independent of pubspec.yaml**. They MUST be re-resolved every run (Phase 5) via `flutter build --config-only` — NOT `xcodebuild -resolvePackageDependencies`, which honors the existing pins and silently no-ops, leaving native deps stale. Skipping (or using the wrong resolve command) is a silent, recurring miss — e.g. one past run bumped firebase-ios-sdk but left GoogleUtilities/nanopb/promises stale; another run's bare `xcodebuild` resolve reported "no changes" while a `flutter build --config-only` picked up GTMSessionFetcher 4.5.0→5.3.0, GoogleUtilities 8.1.0→8.1.1, nanopb, and Promises.
</swiftpm_files>
</project_structure>

<process>
<phase name="0. Preflight Discovery">
<description>Enumerate the ACTUAL dependency surface and reconcile it against the documented lists in `<project_structure>`. The hardcoded lists below WILL go stale as packages are added — a package missing from the tables is the single most common failure of this workflow (e.g. `bridge/sesori_plugin_runtime` was missed for weeks). Treat what you discover here as authoritative; the tables are only the expected reference.</description>

<step name="0.1">List every source pubspec (excludes build artifacts, codegen output, and worktrees):

```bash
find . -name pubspec.yaml -not -path '*/build/*' -not -path '*/.dart_tool/*' -not -path './.worktrees/*' | sort
```

Cross-check the output against the package inventory in `<project_structure>`. If a pubspec appears that is NOT listed there (a newly added workspace member), treat it as in-scope for THIS run — add it to every per-file step below (env constraints in 1.2, outdated check in 2.1, constraint bumps in 3.1) — AND update the inventory + env table in this skill so future runs inherit it. The ONLY pubspec excluded from edits is `shared/no_slop_linter/pubspec.yaml`.
</step>

<step name="0.2">List the authoritative workspace members straight from the workspace roots — every member here MUST be processed in Phases 1–3:

```bash
sed -n '/^workspace:/,$p' bridge/pubspec.yaml
sed -n '/^workspace:/,$p' client/pubspec.yaml
```
</step>

<step name="0.3">List the iOS/macOS SwiftPM lockfiles that Phase 5 will refresh (expect exactly two — the project-workspace copies that `flutter build` maintains; these are native deps and are in scope):

```bash
find client/app -path '*Runner.xcodeproj/project.xcworkspace*Package.resolved' -not -path '*/build/*' | sort
```
</step>
</phase>

<phase name="1. Environment Setup">
<description>Ensure Flutter/Dart is at latest stable version, align environment constraints, and clean lock files</description>

<step name="1.1">Check current Flutter version and update if needed:

```bash
flutter --version
asdf install flutter latest
asdf set flutter latest   # asdf 0.16+ canonical form; equivalent to `asdf local` on older versions
flutter --version
```

If `flutter --version` still reports the old version after `asdf set`, run `asdf reshim flutter` (or open a new shell) and re-run `flutter --version`.
</step>

<step name="1.2">Check and update environment constraints in all pubspec.yaml files **except `shared/no_slop_linter/pubspec.yaml`** (manually managed).

Get the current Dart SDK version bundled with Flutter:

```bash
flutter --version
```

Note the Dart version (e.g., "Dart 3.11.0") and Flutter version (e.g., "Flutter 3.41.0").

For each pubspec.yaml below, read its `environment` section and update only the keys present. **Preserve the existing constraint syntax per file** — do not normalize between caret and range forms.

**SKIP `shared/no_slop_linter/pubspec.yaml` entirely** — its env constraint (and all other deps) are managed manually by a human.

| File | Has `sdk` | Has `flutter` | Constraint style |
|------|-----------|---------------|------------------|
| `client/pubspec.yaml` | ✅ | ✅ | caret (`^3.12.2`) + range (`">=3.44.2 <3.45.0"`) |
| `client/app/pubspec.yaml` | ✅ | — | caret |
| `client/module_auth/pubspec.yaml` | ✅ | — | caret |
| `client/module_core/pubspec.yaml` | ✅ | — | caret |
| `client/module_prego/pubspec.yaml` | ✅ | — | caret |
| `client/module_desktop_core/pubspec.yaml` | ✅ | — | caret |
| `client/desktop/pubspec.yaml` | ✅ | — | caret |
| `bridge/pubspec.yaml` | ✅ | — | caret |
| `bridge/app/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_interface/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_bridge_foundation/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_runtime/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_opencode/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_codex/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_acp/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_cursor/pubspec.yaml` | ✅ | — | caret |
| `shared/sesori_shared/pubspec.yaml` | ✅ | — | caret |

Example:

```yaml
environment:
  sdk: ^DART_VERSION
  flutter: ">=FLUTTER_VERSION <NEXT_MINOR"   # client/pubspec.yaml only
```

</step>

<step name="1.3">Commit if environment constraints changed:

```bash
git diff .tool-versions
git diff --name-only -- '*.yaml'
git add .tool-versions $(git diff --name-only -- '*.yaml')
git commit -m "chore: update Flutter/Dart environment constraints

- Update environment constraints in all pubspec.yaml files
- Update Flutter SDK version in .tool-versions (if changed)"
```

Skip this commit if no environment changes were needed.
</step>

<step name="1.4">Delete all pubspec.lock files except `shared/no_slop_linter/pubspec.lock` (the linter is excluded from this workflow — its lock must remain untouched so transitive resolution doesn't shift):

```bash
find . -name "pubspec.lock" \
  -not -path "./.worktrees/*" \
  -not -path "./shared/no_slop_linter/*" \
  -delete
```

</step>
</phase>

<phase name="2. Dependency Analysis">
<description>Check for available updates across all packages</description>

<step name="2.1">Run outdated check for each package. Workspaces resolve as a unit (run from workspace root); standalone packages resolve individually.

**Standalone (`shared/sesori_shared` only — `no_slop_linter` is excluded):**

```bash
(cd shared/sesori_shared && dart pub outdated)
```

**Client workspace** (one resolution covers all members; run `outdated` per-member to see direct deps per package — `flutter pub outdated` for Flutter packages, `dart pub outdated` for pure-Dart members):

```bash
set -e
(cd client && flutter pub get)
(cd client/module_auth && dart pub outdated)       # pure Dart
(cd client/module_core && dart pub outdated)       # pure Dart
(cd client/module_prego && flutter pub outdated)   # Flutter (flutter: sdk: flutter)
(cd client/module_desktop_core && dart pub outdated) # pure Dart
(cd client/app && flutter pub outdated)            # Flutter app
(cd client/desktop && flutter pub outdated)        # Flutter desktop app
```

**Bridge workspace** (pure Dart):

```bash
set -e
(cd bridge && dart pub get)
(cd bridge/sesori_plugin_interface && dart pub outdated)
(cd bridge/sesori_bridge_foundation && dart pub outdated)
(cd bridge/sesori_plugin_runtime && dart pub outdated)
(cd bridge/sesori_plugin_opencode && dart pub outdated)
(cd bridge/sesori_plugin_codex && dart pub outdated)
(cd bridge/sesori_plugin_acp && dart pub outdated)
(cd bridge/sesori_plugin_cursor && dart pub outdated)
(cd bridge/app && dart pub outdated)
```

</step>

<step name="2.2">Identify updates and categorize:

- **Direct updates**: Can update version constraint in pubspec.yaml immediately
- **Breaking changes**: Major version bumps that need code changes (separate tickets)
- **Blocked updates**: Waiting on transitive dependencies
</step>

<step name="2.3">For each dependency with a major version update, check release notes:

- Visit pub.dev/packages/{package}/changelog
- Identify breaking changes or migration requirements
- Note any that require code changes for later
</step>

</phase>

<phase name="3. Update Dependencies">
<description>Edit pubspec.yaml files to bump version constraints, then resolve</description>

<step name="3.1">For each pubspec.yaml, in this order:

1. `shared/sesori_shared/pubspec.yaml` (consumed by both workspaces)
2. Bridge workspace members (dependency order): `bridge/sesori_plugin_interface`, `bridge/sesori_bridge_foundation`, `bridge/sesori_plugin_runtime`, `bridge/sesori_plugin_opencode`, `bridge/sesori_plugin_codex`, `bridge/sesori_plugin_acp`, `bridge/sesori_plugin_cursor`, `bridge/app`
3. Client workspace members (dependency order): `client/module_auth`, `client/module_core`, `client/module_prego`, `client/module_desktop_core`, `client/app`, `client/desktop`

**SKIP** `shared/no_slop_linter/pubspec.yaml` — analyzer-plugin constraints are bumped manually (see the project structure note). Do not edit it here even if `pub outdated` reports newer versions.

**a) Bump version constraints for direct dependencies** that have newer versions available.

For each direct dependency listed in the `pub outdated` output from Phase 2:

- If the "Latest" column shows a newer version than the current constraint's minimum AND it is resolvable:
  - Update the constraint in pubspec.yaml to use the latest resolvable version as the minimum
  - Example: `drift: ^2.30.1` → `drift: ^2.31.0`
- Skip dependencies that are blocked or would require breaking changes
- Skip dependencies using `any`, `path:`, or `git:` references

**b) Apply the same for dev_dependencies** in each file.
</step>

<step name="3.2">Run pub get for each resolution unit. Each top-level (`shared/`, `bridge/`, `client/`) has a `Makefile` with a `pub-get` target:

```bash
set -e
(cd shared && make pub-get)   # iterates sesori_shared + no_slop_linter (independent lockfiles)
(cd bridge && make pub-get)   # single workspace resolution
(cd client && make pub-get)   # single workspace resolution (uses dart from Flutter SDK)
```

</step>

<step name="3.3">If conflicts occur:

- Identify the conflicting dependency
- Roll back to the maximum compatible version
- Add to conflicts tracking list
- Re-run pub get
</step>

<step name="3.4">Verify that constraints were actually bumped — **per workspace, not globally**. The most common silent failure is updating one workspace (usually client) and skipping the others.

```bash
git diff --name-only -- '*.yaml' | sort
```

Account for EACH of the three resolution units independently:

- **shared** — `shared/sesori_shared/pubspec.yaml`
- **bridge** — `bridge/**/pubspec.yaml` (all members, including `sesori_bridge_foundation` and `sesori_plugin_runtime`)
- **client** — `client/**/pubspec.yaml`

For each, confirm one of two outcomes: either (a) its pubspec(s) appear in the diff because you bumped constraints, OR (b) you can point to the Phase 2 `outdated` output showing it genuinely had no upgradable direct/dev deps.

**HALT** if any workspace is neither changed nor provably already-current. A workspace that had outdated packages but shows no diff means you skipped it — revisit step 3.1 for that specific workspace. Do not continue until all three are accounted for.
</step>
</phase>

<phase name="4. Build Verification">
<description>Ensure all packages build and pass analysis with updated dependencies</description>

<step name="4.1">Run analysis on every package via the Makefile targets — do **not** call `dart analyze` / `flutter analyze` per package by hand. Each top-level Makefile iterates its members in dependency order:

```bash
set -e
(cd shared && make analyze)   # sesori_shared + no_slop_linter
(cd bridge && make analyze)   # all 8 bridge members, in workspace dependency order
(cd client && make analyze)   # all 6 client members, in workspace dependency order (with --fatal-infos)
```

</step>

<step name="4.2">Run tests for every package via the Makefile targets. Each `test` target skips members without a `test/` dir and uses `flutter test` for the Flutter app:

```bash
set -e
(cd shared && make test)
(cd bridge && make test)
(cd client && make test)
```

</step>

<step name="4.3">If build or tests fail:

- Identify the failing dependency
- Check if code changes are needed
- Either fix the issue or roll back the dependency
- Re-run until successful
</step>

<step name="4.4">Run code generation via the Makefile targets. Each Makefile only iterates members that have active generators (skipping `no_slop_linter`):

```bash
set -e
(cd shared && make codegen)   # sesori_shared
(cd bridge && make codegen)   # all bridge members with build_runner dependencies
(cd client && make codegen)   # all 6 client members
```

If a generator dependency is later added to a currently-skipped package, update `CODEGEN_MODULES` in the matching Makefile rather than re-introducing per-package commands here.
</step>
</phase>

<phase name="5. Native Dependencies (SwiftPM + Fastlane/Gemfile)">
<description>Refresh the iOS/macOS SwiftPM native dependency graph and the Ruby/Fastlane gems. Sesori iOS is SPM-only — there is no Podfile and no `cocoapods` gem step.</description>

<step name="5.1">Re-resolve SwiftPM native dependencies (`Package.resolved`) for iOS and macOS.

These lockfiles pin the native Firebase / Google / gRPC / leveldb versions pulled in transitively by the Flutter native plugins. They drift independently of pubspec.yaml (new native patch releases land continuously), so they MUST be re-resolved every run — skipping this leaves native deps stale even when Dart deps are current.

**Use `flutter build --config-only`, NOT `xcodebuild -resolvePackageDependencies`.** `flutter build --config-only` runs the full iOS/macOS build *configuration*: it regenerates the `FlutterGeneratedPluginSwiftPackage` from the (already-bumped, post-Phase-3) plugin versions AND re-resolves SwiftPM at the project level, writing the newest versions allowed by those constraints into the build-authoritative `Runner.xcodeproj/project.xcworkspace/.../Package.resolved`. A bare `xcodebuild -resolvePackageDependencies` honors the existing pins and silently no-ops — it will NOT pick up new native patch releases (this was a real recurring miss). `--config-only` stops after configuration (no compile); `--no-codesign` avoids signing on the iOS release config.

```bash
set -e
if command -v xcodebuild >/dev/null 2>&1; then
  (cd client/app && flutter build ios --config-only --release --no-codesign)
  (cd client/app && flutter build macos --config-only --release)
else
  echo "xcodebuild unavailable (non-macOS host) — record SwiftPM resolution as deferred in the conflict list"
fi
```

This updates the two build-authoritative `Runner.xcodeproj/project.xcworkspace/.../Package.resolved` files (see `<swiftpm_files>`). Notes:

- Run `flutter build` from `client/app`, not the `client` workspace root — `client/app` is the package that owns the `ios/`/`macos/` dirs. `flutter build` runs `flutter pub get` and regenerates the SwiftPM package itself, so there is no separate pub-get step and no stale-generated-package window to guard against.
- These commands are macOS + Xcode only, and under `set -e` they would abort the whole run on a non-macOS host; the `command -v xcodebuild` guard lets the workflow continue and record SwiftPM as deferred instead of silently skipping.
- Leave the sibling `Runner.xcworkspace/.../Package.resolved` copies alone — `flutter build` does not maintain them (see `<swiftpm_files>`).
</step>

<step name="5.2">Verify the SwiftPM lockfiles resolved (changes here are expected on most weekly runs, in the two `Runner.xcodeproj/project.xcworkspace/.../Package.resolved` files):

```bash
git diff --stat -- '*Package.resolved'
```

If there are NO changes, confirm that's genuine (the native graph really was current) and not a resolve that silently failed — re-check the `flutter build --config-only` exit codes from 5.1. A `git diff` showing nothing while a resolve "succeeded" is the classic symptom of the wrong resolve command: make sure 5.1 used `flutter build`, not `xcodebuild -resolvePackageDependencies`.
</step>

<step name="5.3">Check the latest fastlane version:

```bash
gem search fastlane --remote --versions | head -3
```

Update the `fastlane` gem constraint in both Gemfiles if a newer minor version is available:

- `client/app/ios/Gemfile`
- `client/app/android/Gemfile`

Do NOT touch any `cocoapods` gem entry — Sesori does not use CocoaPods. If a `cocoapods` line is still present in `client/app/ios/Gemfile`, leave it alone (it's an inert holdover); do not bump it.
</step>

<step name="5.4">Update Gemfile.lock for iOS:

```bash
cd client/app/ios && bundle update && cd ../../..
```

</step>

<step name="5.5">Update Gemfile.lock for Android:

```bash
cd client/app/android && bundle update && cd ../../..
```

</step>

<step name="5.6">Verify fastlane still works:

```bash
cd client/app/ios && bundle exec fastlane --version && cd ../../..
cd client/app/android && bundle exec fastlane --version && cd ../../..
```

</step>
</phase>

<phase name="6. Final Commits">
<description>Commit all remaining changes with proper categorization. Commit the narrowly-scoped Fastlane change FIRST, then a catch-all for everything else — a leading `git add -A` would swallow the Gemfile changes and make a separate Fastlane commit impossible.</description>

<step name="6.1">If Fastlane/Gemfile changed, commit those specific files first:

```bash
git add client/app/ios/Gemfile client/app/ios/Gemfile.lock client/app/android/Gemfile client/app/android/Gemfile.lock
git commit -m "chore: update Fastlane gem dependencies

- Update fastlane to X.Y.Z
- Regenerate Gemfile.lock for iOS and Android"
```

Skip this commit if the Gemfiles/Gemfile.lock are unchanged.
</step>

<step name="6.2">Commit everything else — pubspec.yaml bumps, regenerated `pubspec.lock` files, iOS/macOS SwiftPM `Package.resolved`, generated code, and any `.tool-versions`/env changes not already committed in Phase 1:

```bash
git add -A
git commit -m "chore: update project dependencies

- Update {list key dependencies bumped, per workspace}
- Re-resolve iOS/macOS SwiftPM native deps (Package.resolved)
- Regenerate lock files and generated code

Conflicts/Deferred:
- {dependency}: blocked by {reason}"
```

</step>
</phase>
</process>

<conflict_tracking>
Maintain a list of dependencies that could not be updated:

| Dependency | Current | Latest | Reason | Action Needed |
|------------|---------|--------|--------|---------------|
| {name} | {ver} | {ver} | {why blocked} | {next steps} |

Report this list at the end of the update process for visibility.
</conflict_tracking>

<success_criteria>

- Preflight discovery (Phase 0) ran; every discovered source pubspec and workspace member is accounted for, with none silently skipped
- Environment constraints (sdk, flutter) updated in 17 pubspec.yaml files (every pubspec EXCEPT `shared/no_slop_linter/pubspec.yaml`, which is excluded entirely — 9 bridge, 7 client, and `shared/sesori_shared`)
- Version constraints bumped to latest resolvable versions in every pubspec EXCEPT `shared/no_slop_linter/pubspec.yaml`
- All three workspaces (shared, bridge, client) are individually accounted for: each either has bumped constraints or provably had no upgradable deps (Phase 3.4)
- All in-scope pubspec.lock files regenerated (bridge workspace, client workspace, and `shared/sesori_shared` = 3 lockfiles); `shared/no_slop_linter/pubspec.lock` remains untouched
- iOS + macOS SwiftPM `Package.resolved` re-resolved via `flutter build --config-only` (the 2 authoritative `Runner.xcodeproj/project.xcworkspace` lockfiles), or recorded as deferred if no Xcode toolchain
- `(cd shared && make analyze)`, `(cd bridge && make analyze)`, `(cd client && make analyze)` all pass
- `(cd shared && make test)`, `(cd bridge && make test)`, `(cd client && make test)` all pass
- `(cd shared && make codegen)`, `(cd bridge && make codegen)`, `(cd client && make codegen)` all complete cleanly
- Fastlane and Gemfile.lock updated for both iOS and Android (no `cocoapods` bumps — SPM only)
- Conflict list documented in commit message
- No uncommitted changes remain
</success_criteria>

<rollback_strategy>
If a dependency update causes issues that cannot be quickly resolved:

1. Note the problematic version
2. Revert to the previous working version in pubspec.yaml
3. Re-run `pub get` to regenerate the lock file
4. Add to conflicts tracking list
5. Create a separate ticket if code changes are needed
6. Continue with other updates
</rollback_strategy>
