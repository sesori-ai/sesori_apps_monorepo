---
name: update-dependencies
description: Weekly dependency update workflow for Sesori Apps Monorepo. Updates every pubspec.yaml across the bridge and mobile workspaces plus standalone packages, regenerates all lockfiles, re-resolves iOS/macOS SwiftPM native dependencies (Package.resolved), updates Fastlane/Gemfile versions, handles conflicts, and verifies via analyze/test/codegen.
---

<objective>
Systematically update all project dependencies across both Dart workspaces and standalone packages while maintaining stability, tracking conflicts, and ensuring proper commit hygiene.
</objective>

<project_structure>
<workspaces>
The repo has two Dart workspaces and two standalone packages. Workspace members share a single resolution; standalone packages resolve independently.

**Mobile workspace** (`mobile/pubspec.yaml` is the workspace root, has `flutter` env constraint):

- `mobile/pubspec.yaml` — workspace root, env only
- `mobile/module_auth/pubspec.yaml`
- `mobile/module_core/pubspec.yaml`
- `mobile/module_prego/pubspec.yaml` (Flutter package — theme/assets)
- `mobile/app/pubspec.yaml` (Flutter app — Firebase, flutter_bloc, etc.)

**Bridge workspace** (`bridge/pubspec.yaml` is the workspace root, pure Dart):

- `bridge/pubspec.yaml` — workspace root, env only
- `bridge/sesori_plugin_interface/pubspec.yaml`
- `bridge/sesori_bridge_foundation/pubspec.yaml` (depends on `sesori_plugin_interface`; bridge-wide shared primitives)
- `bridge/sesori_plugin_runtime/pubspec.yaml` (depends on `sesori_plugin_interface`)
- `bridge/sesori_plugin_opencode/pubspec.yaml`
- `bridge/app/pubspec.yaml` (CLI relay server)

**Standalone packages** (NOT in any workspace — resolve independently with their own lockfile):

- `shared/sesori_shared/pubspec.yaml` — pure Dart; consumed by both workspaces via `path:` dep
- `shared/no_slop_linter/pubspec.yaml` — pure Dart analyzer plugin; consumed by `module_prego` via `path:` dev_dep

**IMPORTANT**: Update `shared/sesori_shared` FIRST because both workspaces depend on it.

**DO NOT update `shared/no_slop_linter`** as part of this workflow. Its analyzer/`_fe_analyzer_shared` constraints span multiple majors intentionally and break easily — bumps are done manually, less often, by a human. Skip its pubspec edits in Phase 3, but still run `make analyze`/`make test` against it via the shared `Makefile` for verification.
</workspaces>

<ios_files>
Sesori iOS is **Swift Package Manager only** — there is no Podfile, and CocoaPods is not part of the iOS dependency graph. Do not run `pod install` or attempt to add Podfile handling here.

- `mobile/app/ios/Gemfile` (fastlane gem only)
- `mobile/app/ios/Gemfile.lock`
</ios_files>

<android_files>

- `mobile/app/android/Gemfile` (fastlane gem)
- `mobile/app/android/Gemfile.lock`
</android_files>

<swiftpm_files>
iOS and macOS pull native dependencies (Firebase, Google SDKs, leveldb, gRPC, etc.) via Swift Package Manager. The resolved native versions are pinned in `Package.resolved` lockfiles. The **build-authoritative** copies — the ones `flutter build` actually uses — are:

- `mobile/app/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `mobile/app/macos/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`

There are also secondary `Runner.xcodeproj/project.xcworkspace/.../Package.resolved` copies that Xcode maintains only when the bare project is opened. They are not build-critical and are not reliably kept in sync (iOS already differs from its workspace copy) — do not hand-edit or force them.

These lockfiles change on most weekly runs because native SDK patch releases land continuously, **independent of pubspec.yaml**. They MUST be re-resolved every run (Phase 5). Skipping this is a silent, recurring miss — e.g. one past run bumped firebase-ios-sdk but left GoogleUtilities/nanopb/promises stale.
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
sed -n '/^workspace:/,$p' mobile/pubspec.yaml
```
</step>

<step name="0.3">List the iOS/macOS SwiftPM lockfiles that Phase 5 will refresh (expect exactly two — these are native deps and are in scope):

```bash
find mobile/app -path '*Runner.xcworkspace*Package.resolved' -not -path '*/build/*' | sort
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
| `mobile/pubspec.yaml` | ✅ | ✅ | caret (`^3.12.2`) + range (`">=3.44.2 <3.45.0"`) |
| `mobile/app/pubspec.yaml` | ✅ | — | caret |
| `mobile/module_auth/pubspec.yaml` | ✅ | — | caret |
| `mobile/module_core/pubspec.yaml` | ✅ | — | caret |
| `mobile/module_prego/pubspec.yaml` | ✅ | — | caret |
| `bridge/pubspec.yaml` | ✅ | — | caret |
| `bridge/app/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_interface/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_bridge_foundation/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_runtime/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_opencode/pubspec.yaml` | ✅ | — | caret |
| `shared/sesori_shared/pubspec.yaml` | ✅ | — | caret |

Example:

```yaml
environment:
  sdk: ^DART_VERSION
  flutter: ">=FLUTTER_VERSION <NEXT_MINOR"   # mobile/pubspec.yaml only
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

**Mobile workspace** (one resolution covers all members; run `outdated` per-member to see direct deps per package — `flutter pub outdated` for Flutter packages, `dart pub outdated` for pure-Dart members):

```bash
set -e
(cd mobile && flutter pub get)
(cd mobile/module_auth && dart pub outdated)       # pure Dart
(cd mobile/module_core && dart pub outdated)       # pure Dart
(cd mobile/module_prego && flutter pub outdated)    # Flutter (flutter: sdk: flutter)
(cd mobile/app && flutter pub outdated)            # Flutter app
```

**Bridge workspace** (pure Dart):

```bash
set -e
(cd bridge && dart pub get)
(cd bridge/sesori_plugin_interface && dart pub outdated)
(cd bridge/sesori_plugin_runtime && dart pub outdated)
(cd bridge/sesori_plugin_opencode && dart pub outdated)
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
2. Bridge workspace members (dependency order): `bridge/sesori_plugin_interface`, `bridge/sesori_bridge_foundation`, `bridge/sesori_plugin_runtime`, `bridge/sesori_plugin_opencode`, `bridge/app`
3. Mobile workspace members: `mobile/module_auth`, `mobile/module_core`, `mobile/module_prego`, `mobile/app`

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

<step name="3.2">Run pub get for each resolution unit. Each top-level (`shared/`, `bridge/`, `mobile/`) has a `Makefile` with a `pub-get` target:

```bash
set -e
(cd shared && make pub-get)   # iterates sesori_shared + no_slop_linter (independent lockfiles)
(cd bridge && make pub-get)   # single workspace resolution
(cd mobile && make pub-get)   # single workspace resolution (uses dart from Flutter SDK)
```

</step>

<step name="3.3">If conflicts occur:

- Identify the conflicting dependency
- Roll back to the maximum compatible version
- Add to conflicts tracking list
- Re-run pub get
</step>

<step name="3.4">Verify that constraints were actually bumped — **per workspace, not globally**. The most common silent failure is updating one workspace (usually mobile) and skipping the others.

```bash
git diff --name-only -- '*.yaml' | sort
```

Account for EACH of the three resolution units independently:

- **shared** — `shared/sesori_shared/pubspec.yaml`
- **bridge** — `bridge/**/pubspec.yaml` (all members, including `sesori_plugin_runtime`)
- **mobile** — `mobile/**/pubspec.yaml`

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
(cd bridge && make analyze)   # sesori_plugin_interface, sesori_plugin_runtime, sesori_plugin_opencode, app
(cd mobile && make analyze)   # module_auth, module_core, module_prego, app (with --fatal-infos)
```

</step>

<step name="4.2">Run tests for every package via the Makefile targets. Each `test` target skips members without a `test/` dir and uses `flutter test` for the Flutter app:

```bash
set -e
(cd shared && make test)
(cd bridge && make test)
(cd mobile && make test)
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
(cd bridge && make codegen)   # sesori_plugin_interface, sesori_plugin_runtime, sesori_plugin_opencode, app
(cd mobile && make codegen)   # module_auth, module_core, module_prego, app
```

If a generator dependency is later added to a currently-skipped package, update `CODEGEN_MODULES` in the matching Makefile rather than re-introducing per-package commands here.
</step>
</phase>

<phase name="5. Native Dependencies (SwiftPM + Fastlane/Gemfile)">
<description>Refresh the iOS/macOS SwiftPM native dependency graph and the Ruby/Fastlane gems. Sesori iOS is SPM-only — there is no Podfile and no `cocoapods` gem step.</description>

<step name="5.1">Re-resolve SwiftPM native dependencies (`Package.resolved`) for iOS and macOS.

These lockfiles pin the native Firebase / Google / gRPC / leveldb versions pulled in transitively by the Flutter native plugins. They drift independently of pubspec.yaml (new native patch releases land continuously), so they MUST be re-resolved every run — skipping this leaves native deps stale even when Dart deps are current.

**Order matters.** `flutter pub get` regenerates the `FlutterGeneratedPluginSwiftPackage` from the (already-bumped, post-Phase-3) plugin versions FIRST; the Xcode resolve then picks the newest versions allowed by those constraints. Running the resolve against a stale generated package can **downgrade** dependencies — always `flutter pub get` immediately before resolving.

```bash
set -e
(cd mobile/app && flutter pub get)   # regenerate the SwiftPM package; run in mobile/app (it owns ios/ + macos/), not the workspace root
if command -v xcodebuild >/dev/null 2>&1; then
  (cd mobile/app/ios && xcodebuild -resolvePackageDependencies -workspace Runner.xcworkspace -scheme Runner)
  (cd mobile/app/macos && xcodebuild -resolvePackageDependencies -workspace Runner.xcworkspace -scheme Runner)
else
  echo "xcodebuild unavailable (non-macOS host) — record SwiftPM resolution as deferred in the conflict list"
fi
```

This updates only the two build-authoritative `Runner.xcworkspace/.../Package.resolved` files (see `<swiftpm_files>`). Notes:

- Run `flutter pub get` from `mobile/app`, not the `mobile` workspace root — `mobile/app` is the package that owns the `ios/`/`macos/` dirs, so it is what regenerates their `FlutterGeneratedPluginSwiftPackage` (running from a pub-workspace member still resolves the whole workspace). Use `flutter pub get`, not the Makefile `dart pub get` — only the Flutter tool regenerates the SwiftPM package.
- `xcodebuild` is macOS-only, and under `set -e` a bare call would abort the whole run on a non-macOS host; the `command -v` guard lets the workflow continue and record SwiftPM as deferred instead of silently skipping.
</step>

<step name="5.2">Verify the SwiftPM lockfiles resolved (changes here are expected on most weekly runs):

```bash
git diff --stat -- '*Package.resolved'
```

If there are NO changes, confirm that's genuine (the native graph really was current) and not a resolve that silently failed — re-check the `xcodebuild` exit codes from 5.1.
</step>

<step name="5.3">Check the latest fastlane version:

```bash
gem search fastlane --remote --versions | head -3
```

Update the `fastlane` gem constraint in both Gemfiles if a newer minor version is available:

- `mobile/app/ios/Gemfile`
- `mobile/app/android/Gemfile`

Do NOT touch any `cocoapods` gem entry — Sesori does not use CocoaPods. If a `cocoapods` line is still present in `mobile/app/ios/Gemfile`, leave it alone (it's an inert holdover); do not bump it.
</step>

<step name="5.4">Update Gemfile.lock for iOS:

```bash
cd mobile/app/ios && bundle update && cd ../../..
```

</step>

<step name="5.5">Update Gemfile.lock for Android:

```bash
cd mobile/app/android && bundle update && cd ../../..
```

</step>

<step name="5.6">Verify fastlane still works:

```bash
cd mobile/app/ios && bundle exec fastlane --version && cd ../../..
cd mobile/app/android && bundle exec fastlane --version && cd ../../..
```

</step>
</phase>

<phase name="6. Final Commits">
<description>Commit all remaining changes with proper categorization. Commit the narrowly-scoped Fastlane change FIRST, then a catch-all for everything else — a leading `git add -A` would swallow the Gemfile changes and make a separate Fastlane commit impossible.</description>

<step name="6.1">If Fastlane/Gemfile changed, commit those specific files first:

```bash
git add mobile/app/ios/Gemfile mobile/app/ios/Gemfile.lock mobile/app/android/Gemfile mobile/app/android/Gemfile.lock
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
- Environment constraints (sdk, flutter) updated in 11 pubspec.yaml files (every pubspec EXCEPT `shared/no_slop_linter/pubspec.yaml`, which is excluded entirely — the count INCLUDES `bridge/sesori_plugin_runtime`)
- Version constraints bumped to latest resolvable versions in every pubspec EXCEPT `shared/no_slop_linter/pubspec.yaml`
- All three workspaces (shared, bridge, mobile) are individually accounted for: each either has bumped constraints or provably had no upgradable deps (Phase 3.4)
- All pubspec.lock files regenerated (workspace roots + 2 standalone packages = 4 lockfiles)
- iOS + macOS SwiftPM `Package.resolved` re-resolved (the 2 authoritative `Runner.xcworkspace` lockfiles), or recorded as deferred if no Xcode toolchain
- `(cd shared && make analyze)`, `(cd bridge && make analyze)`, `(cd mobile && make analyze)` all pass
- `(cd shared && make test)`, `(cd bridge && make test)`, `(cd mobile && make test)` all pass
- `(cd shared && make codegen)`, `(cd bridge && make codegen)`, `(cd mobile && make codegen)` all complete cleanly
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
