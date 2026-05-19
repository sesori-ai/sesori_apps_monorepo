---
name: update-dependencies
description: Weekly dependency update workflow for Sesori Apps Monorepo. Updates all pubspec.yaml files across bridge and mobile workspaces plus standalone packages, handles conflicts, manages iOS/Android native dependencies, and updates Fastlane/Gemfile versions.
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
- `mobile/module_zyra/pubspec.yaml` (Flutter package — theme/assets)
- `mobile/app/pubspec.yaml` (Flutter app — Firebase, flutter_bloc, etc.)

**Bridge workspace** (`bridge/pubspec.yaml` is the workspace root, pure Dart):
- `bridge/pubspec.yaml` — workspace root, env only
- `bridge/sesori_plugin_interface/pubspec.yaml`
- `bridge/sesori_plugin_opencode/pubspec.yaml`
- `bridge/app/pubspec.yaml` (CLI relay server)

**Standalone packages** (NOT in any workspace — resolve independently with their own lockfile):
- `shared/sesori_shared/pubspec.yaml` — pure Dart; consumed by both workspaces via `path:` dep
- `shared/no_slop_linter/pubspec.yaml` — pure Dart analyzer plugin; consumed by `module_zyra` via `path:` dev_dep

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
</project_structure>

<process>
<phase name="1. Environment Setup">
<description>Ensure Flutter/Dart is at latest stable version, align environment constraints, and clean lock files</description>

<step name="1.1">Check current Flutter version and update if needed:
```bash
flutter --version
asdf install flutter latest
asdf set flutter latest
flutter --version
```
</step>

<step name="1.2">Check and update environment constraints in ALL pubspec.yaml files.

Get the current Dart SDK version bundled with Flutter:
```bash
flutter --version
```
Note the Dart version (e.g., "Dart 3.11.0") and Flutter version (e.g., "Flutter 3.41.0").

For each pubspec.yaml below, read its `environment` section and update only the keys present. **Preserve the existing constraint syntax per file** — do not normalize between caret and range forms.

| File | Has `sdk` | Has `flutter` | Constraint style |
|------|-----------|---------------|------------------|
| `mobile/pubspec.yaml` | ✅ | ✅ | caret (`^3.11.5`) + range (`">=3.41.7 <3.42.0"`) |
| `mobile/app/pubspec.yaml` | ✅ | — | caret |
| `mobile/module_auth/pubspec.yaml` | ✅ | — | caret |
| `mobile/module_core/pubspec.yaml` | ✅ | — | caret |
| `mobile/module_zyra/pubspec.yaml` | ✅ | — | caret |
| `bridge/pubspec.yaml` | ✅ | — | caret |
| `bridge/app/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_interface/pubspec.yaml` | ✅ | — | caret |
| `bridge/sesori_plugin_opencode/pubspec.yaml` | ✅ | — | caret |
| `shared/sesori_shared/pubspec.yaml` | ✅ | — | caret |
| `shared/no_slop_linter/pubspec.yaml` | ✅ | — | **range with upper bound** (`">=3.11.0 <4.0.0"`) — intentional for analyzer-plugin compat across multiple analyzer majors; preserve the range form, only bump the lower bound |

Examples by style:
```yaml
# Caret form (used in 10 of 11 files):
environment:
  sdk: ^DART_VERSION
  flutter: ">=FLUTTER_VERSION <NEXT_MINOR"   # mobile/pubspec.yaml only

# Range form (shared/no_slop_linter only — keep upper bound):
environment:
  sdk: ">=DART_VERSION <4.0.0"
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

<step name="1.4">Delete all pubspec.lock files:
```bash
find . -name "pubspec.lock" -not -path "./.worktrees/*" -delete
```
</step>
</phase>

<phase name="2. Dependency Analysis">
<description>Check for available updates across all packages</description>

<step name="2.1">Run outdated check for each package. Workspaces resolve as a unit (run from workspace root); standalone packages resolve individually.

**Standalone packages:**
```bash
cd shared/sesori_shared && dart pub outdated && cd ../..
# no_slop_linter — informational only; report findings but do NOT bump in Phase 3.
cd shared/no_slop_linter && dart pub outdated && cd ../..
```

**Mobile workspace** (one resolution covers all members, but run `outdated` per-member to see direct deps per package — use `flutter pub outdated` for Flutter packages, `dart pub outdated` for pure-Dart members):
```bash
cd mobile && flutter pub get && cd ..
cd mobile/module_auth && dart pub outdated && cd ../..       # pure Dart
cd mobile/module_core && dart pub outdated && cd ../..       # pure Dart
cd mobile/module_zyra && flutter pub outdated && cd ../..    # Flutter (flutter: sdk: flutter)
cd mobile/app && flutter pub outdated && cd ../..            # Flutter app
```

**Bridge workspace** (pure Dart):
```bash
cd bridge && dart pub get && cd ..
cd bridge/sesori_plugin_interface && dart pub outdated && cd ../..
cd bridge/sesori_plugin_opencode && dart pub outdated && cd ../..
cd bridge/app && dart pub outdated && cd ../..
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
2. Bridge workspace members: `bridge/sesori_plugin_interface`, `bridge/sesori_plugin_opencode`, `bridge/app`
3. Mobile workspace members: `mobile/module_auth`, `mobile/module_core`, `mobile/module_zyra`, `mobile/app`

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
make -C shared pub-get   # iterates sesori_shared + no_slop_linter (independent lockfiles)
make -C bridge pub-get   # single workspace resolution
make -C mobile pub-get   # single workspace resolution (uses dart from Flutter SDK)
```
</step>

<step name="3.3">If conflicts occur:
- Identify the conflicting dependency
- Roll back to the maximum compatible version
- Add to conflicts tracking list
- Re-run pub get
</step>

<step name="3.4">Verify that pubspec.yaml files were actually modified:
```bash
git diff --name-only -- '*.yaml'
```
**HALT** if no pubspec.yaml files show changes but outdated packages exist. Do not proceed without having bumped version constraints. Revisit step 3.1.
</step>
</phase>

<phase name="4. Build Verification">
<description>Ensure all packages build and pass analysis with updated dependencies</description>

<step name="4.1">Run analysis on every package via the Makefile targets — do **not** call `dart analyze` / `flutter analyze` per package by hand. Each top-level Makefile iterates its members in dependency order:

```bash
make -C shared analyze   # sesori_shared + no_slop_linter
make -C bridge analyze   # sesori_plugin_interface, sesori_plugin_opencode, app
make -C mobile analyze   # module_auth, module_core, module_zyra, app (with --fatal-infos)
```
</step>

<step name="4.2">Run tests for every package via the Makefile targets. Each `test` target skips members without a `test/` dir and uses `flutter test` for the Flutter app:

```bash
make -C shared test   # sesori_shared (no_slop_linter has tests too)
make -C bridge test
make -C mobile test
```
</step>

<step name="4.3">If build or tests fail:
- Identify the failing dependency
- Check if code changes are needed
- Either fix the issue or roll back the dependency
- Re-run until successful
</step>

<step name="4.4">Run code generation via the Makefile targets. Each Makefile only iterates members that have active generators (skipping `no_slop_linter` and `module_zyra`):

```bash
make -C shared codegen   # sesori_shared
make -C bridge codegen   # sesori_plugin_interface, sesori_plugin_opencode, app
make -C mobile codegen   # module_auth, module_core, module_zyra, app
```
If a generator dependency is later added to a currently-skipped package, update `CODEGEN_MODULES` in the matching Makefile rather than re-introducing per-package commands here.
</step>
</phase>

<phase name="5. Fastlane and Gemfile Dependencies">
<description>Update Fastlane and Ruby gem dependencies for iOS and Android. Sesori iOS is SPM-only — there is no `cocoapods` gem step.</description>

<step name="5.1">Check the latest fastlane version:
```bash
gem search fastlane --remote --versions | head -3
```

Update the `fastlane` gem constraint in both Gemfiles if a newer minor version is available:
- `mobile/app/ios/Gemfile`
- `mobile/app/android/Gemfile`

Do NOT touch any `cocoapods` gem entry — Sesori does not use CocoaPods. If a `cocoapods` line is still present in `mobile/app/ios/Gemfile`, leave it alone (it's an inert holdover); do not bump it.
</step>

<step name="5.2">Update Gemfile.lock for iOS:
```bash
cd mobile/app/ios && bundle update && cd ../../..
```
</step>

<step name="5.3">Update Gemfile.lock for Android:
```bash
cd mobile/app/android && bundle update && cd ../../..
```
</step>

<step name="5.4">Verify fastlane still works:
```bash
cd mobile/app/ios && bundle exec fastlane --version && cd ../../..
cd mobile/app/android && bundle exec fastlane --version && cd ../../..
```
</step>
</phase>

<phase name="6. Final Commits">
<description>Commit all remaining changes with proper categorization</description>

<step name="6.1">Commit dependency updates (pubspec.yaml changes, lock files, generated code):
```bash
git add -A
git commit -m "chore: update project dependencies

- Update {list key dependencies bumped}
- Regenerate lock files and generated code

Conflicts/Deferred:
- {dependency}: blocked by {reason}"
```
</step>

<step name="6.2">If Fastlane/Gemfile had changes, commit separately:
```bash
git add mobile/app/ios/Gemfile mobile/app/ios/Gemfile.lock mobile/app/android/Gemfile mobile/app/android/Gemfile.lock
git commit -m "chore: update Fastlane gem dependencies

- Update fastlane to X.Y.Z
- Regenerate Gemfile.lock for iOS and Android"
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
- Environment constraints (sdk, flutter) in ALL 11 pubspec.yaml files match the currently installed Flutter/Dart versions
- Version constraints bumped to latest resolvable versions in every pubspec EXCEPT `shared/no_slop_linter/pubspec.yaml` (manual updates only)
- All pubspec.lock files regenerated (workspace roots + 2 standalone packages = 4 lockfiles)
- `make -C shared analyze`, `make -C bridge analyze`, `make -C mobile analyze` all pass
- `make -C shared test`, `make -C bridge test`, `make -C mobile test` all pass
- `make -C shared codegen`, `make -C bridge codegen`, `make -C mobile codegen` all complete cleanly
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
