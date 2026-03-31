---
name: update-dependencies
description: Weekly dependency update workflow for Sesori Apps Monorepo. Updates all pubspec.yaml files across bridge and mobile workspaces, handles conflicts, manages iOS/Android native dependencies, and updates Fastlane/Gemfile versions.
---

<objective>
Systematically update all project dependencies across both workspaces (bridge and mobile) while maintaining stability, tracking conflicts, and ensuring proper commit hygiene.
</objective>

<project_structure>
<workspaces>
Two independent Dart workspaces plus a shared package:

**Shared** (consumed by both workspaces via path dependency):
- `shared/sesori_shared/pubspec.yaml`

**Mobile workspace** (dependency order):
- `mobile/module_auth/pubspec.yaml`
- `mobile/module_core/pubspec.yaml`
- `mobile/app/pubspec.yaml` (Flutter app — includes Firebase, flutter_bloc, etc.)

**Bridge workspace** (dependency order):
- `bridge/sesori_plugin_interface/pubspec.yaml`
- `bridge/sesori_plugin_opencode/pubspec.yaml`
- `bridge/app/pubspec.yaml` (CLI relay server)
</workspaces>

<ios_files>
- `mobile/app/ios/Podfile`
- `mobile/app/ios/Podfile.lock`
- `mobile/app/ios/Gemfile` (fastlane + cocoapods gems)
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

Read the `environment` section in each pubspec.yaml. If the `sdk` or `flutter` minimum version is behind the current installed version, update it:

```yaml
environment:
  sdk: ">=DART_VERSION"
  flutter: ">=FLUTTER_VERSION"
```

Update ALL pubspec.yaml files listed in `<workspaces>` above. Some files (pure Dart packages like `sesori_shared`, `module_auth`, `module_core`, bridge packages) may only have `sdk` without `flutter` — only update what's present.
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
<description>Check for available updates across all modules</description>

<step name="2.1">Run outdated check for each module. The two workspaces resolve independently:

**Shared:**
```bash
cd shared/sesori_shared && dart pub outdated && cd ../..
```

**Mobile workspace:**
```bash
cd mobile/module_auth && dart pub outdated && cd ../..
cd mobile/module_core && dart pub outdated && cd ../..
cd mobile/app && flutter pub outdated && cd ../..
```

**Bridge workspace:**
```bash
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

<step name="3.1">For each pubspec.yaml (in dependency order within each workspace):

**a) Bump version constraints for direct dependencies** that have newer versions available.

For each direct dependency listed in the `pub outdated` output from Phase 2:
- If the "Latest" column shows a newer version than the current constraint's minimum AND it is resolvable:
  - Update the constraint in pubspec.yaml to use the latest resolvable version as the minimum
  - Example: `drift: ^2.30.1` → `drift: ^2.31.0`
- Skip dependencies that are blocked or would require breaking changes
- Skip dependencies using `any`, `path:`, or `git:` references

**b) Apply the same for dev_dependencies** in each file.

**IMPORTANT**: Update `shared/sesori_shared` first since both workspaces depend on it. If shared changes, both workspaces need re-resolution.
</step>

<step name="3.2">Run pub get for each workspace:

**Shared:**
```bash
cd shared/sesori_shared && dart pub get && cd ../..
```

**Mobile workspace (workspace resolution):**
```bash
cd mobile && dart pub get && cd ..
```

**Bridge workspace (workspace resolution):**
```bash
cd bridge && dart pub get && cd ..
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
<description>Ensure both workspaces build and pass analysis with updated dependencies</description>

<step name="4.1">Run analysis on all modules:

**Bridge workspace:**
```bash
cd bridge && dart pub get && cd ..
cd bridge/sesori_plugin_interface && dart analyze && cd ../..
cd bridge/sesori_plugin_opencode && dart analyze && cd ../..
cd bridge/app && dart analyze && cd ../..
```

**Mobile workspace:**
```bash
cd mobile && dart pub get && cd ..
cd mobile/module_auth && dart analyze && cd ../..
cd mobile/module_core && dart analyze && cd ../..
cd mobile/app && dart analyze && cd ../..
```
</step>

<step name="4.2">Run tests:

**Bridge:**
```bash
cd bridge/app && dart test && cd ../..
```

**Mobile:**
```bash
cd mobile/module_auth && dart test && cd ../..
cd mobile/module_core && dart test && cd ../..
cd mobile/app && flutter test && cd ../..
```
</step>

<step name="4.3">If build or tests fail:
- Identify the failing dependency
- Check if code changes are needed
- Either fix the issue or roll back the dependency
- Re-run until successful
</step>

<step name="4.4">Run code generation if any annotated classes changed:
```bash
cd mobile/app && dart run build_runner build --delete-conflicting-outputs && cd ../..
cd mobile/module_core && dart run build_runner build --delete-conflicting-outputs && cd ../..
cd mobile/module_auth && dart run build_runner build --delete-conflicting-outputs && cd ../..
```
</step>
</phase>

<phase name="5. iOS Dependencies">
<description>Update iOS CocoaPods dependencies</description>

<step name="5.1">Clean and update Podfile.lock:
```bash
rm -f mobile/app/ios/Podfile.lock
cd mobile/app/ios && pod install --repo-update && cd ../../..
```
</step>

<step name="5.2">Check for iOS changes:
```bash
git status mobile/app/ios/
```
</step>
</phase>

<phase name="6. Fastlane and Gemfile Dependencies">
<description>Update Fastlane and Ruby gem dependencies for iOS and Android</description>

<step name="6.1">Check the latest fastlane version:
```bash
gem search fastlane --remote --versions | head -3
```

Update the `fastlane` gem constraint in both Gemfiles if a newer minor version is available:
- `mobile/app/ios/Gemfile`
- `mobile/app/android/Gemfile`

For the iOS Gemfile, also check for `cocoapods` gem updates:
```bash
gem search cocoapods --remote --exact --versions | head -3
```
</step>

<step name="6.2">Update Gemfile.lock for iOS:
```bash
cd mobile/app/ios && bundle update && cd ../../..
```
</step>

<step name="6.3">Update Gemfile.lock for Android:
```bash
cd mobile/app/android && bundle update && cd ../../..
```
</step>

<step name="6.4">Verify fastlane still works:
```bash
cd mobile/app/ios && bundle exec fastlane --version && cd ../../..
cd mobile/app/android && bundle exec fastlane --version && cd ../../..
```
</step>
</phase>

<phase name="7. Final Commits">
<description>Commit all remaining changes with proper categorization</description>

<step name="7.1">Commit dependency updates (pubspec.yaml changes, lock files, generated code):
```bash
git add -A
git commit -m "chore: update project dependencies

- Update {list key dependencies bumped}
- Regenerate lock files and generated code

Conflicts/Deferred:
- {dependency}: blocked by {reason}"
```
</step>

<step name="7.2">If iOS had changes, commit separately:
```bash
git add mobile/app/ios/
git commit -m "chore: update iOS CocoaPods dependencies

- Update iOS dependencies via pod install"
```
</step>

<step name="7.3">If Fastlane/Gemfile had changes, commit separately:
```bash
git add mobile/app/ios/Gemfile mobile/app/ios/Gemfile.lock mobile/app/android/Gemfile mobile/app/android/Gemfile.lock
git commit -m "chore: update Fastlane and Ruby gem dependencies

- Update fastlane to X.Y.Z
- Update cocoapods gem to X.Y.Z (iOS only, if changed)
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
- Environment constraints (sdk, flutter) in ALL pubspec.yaml files match the currently installed Flutter/Dart versions
- Version constraints in pubspec.yaml files bumped to match latest resolvable versions
- All pubspec.lock files regenerated
- `dart analyze` passes for all modules
- All tests pass (`dart test` for pure Dart, `flutter test` for app)
- iOS Podfile.lock updated
- Fastlane and Gemfile.lock updated for both iOS and Android
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
