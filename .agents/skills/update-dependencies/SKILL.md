---
name: update-dependencies
description: Recurring repo maintenance run for the Sesori Apps Monorepo. Brings every dependency, toolchain, CI action and image up to date — Dart pubspecs and lockfiles, Flutter/Dart SDK, iOS/macOS SwiftPM, Fastlane/Gemfiles, the Android Gradle toolchain (AGP, Gradle wrapper, Kotlin/Google plugins, JDK), GitHub Actions and the toolchains/runners they install, Docker base images, Node packages, `.tool-versions` and pinned tool versions in scripts. Use for "maintenance", "update deps", "dependency update", "refresh toolchains/CI", "bump actions/Docker/Node" and similar requests.
---

<objective>
This is the recurring maintenance run: bring every dependency surface in the repository up to date, verify it, and publish it.

**The rule: a run updates every dependency surface in the repo.** Nothing is skipped because an earlier run or an older version of this skill didn't cover it. The only reason to defer an item is a concrete blocker (a named incompatibility, an upstream issue, a pending decision with its owner), recorded in the conflict table. "Out of scope", "not covered", "risky" and "later" are not blockers.
</objective>

<project_structure>
Dart resolution units (workspace members share one resolution; standalone packages resolve alone):

- **Client workspace**: root `client/pubspec.yaml` (has a `flutter` env constraint); members are listed under its `workspace:` key.
- **Bridge workspace**: root `bridge/pubspec.yaml` (pure Dart); members are listed under its `workspace:` key.
- **Standalone**: `shared/sesori_shared` (consumed by both workspaces via `path:`; update it FIRST) and `shared/no_slop_linter`.

**DO NOT update `shared/no_slop_linter`.** Its analyzer/`_fe_analyzer_shared` constraints span multiple majors intentionally and break easily; a human bumps them manually. Leave its pubspec and lockfile byte-for-byte unchanged, but still analyze and test it through the shared `Makefile`.

Sesori iOS is **Swift Package Manager only**: there is no Podfile, no CocoaPods and no `cocoapods` gem. Never add one.

Other surfaces and their files (Phase 0 discovers them generically, so treat this list as reference only):

| Surface | Files |
|---|---|
| Flutter/Dart SDK | `.tool-versions`, `environment:` in every in-scope pubspec |
| SwiftPM | `client/app/ios` and `client/desktop/macos`: project + workspace `Package.resolved`; direct `XCRemoteSwiftPackageReference` pins in `Runner.xcodeproj/project.pbxproj` (macOS pins Firebase and Sparkle with `exactVersion`) |
| Fastlane | `client/app/{ios,android}/Gemfile{,.lock}` |
| Android toolchain | `client/app/android/settings.gradle.kts` plugin `version` entries, `gradle/wrapper/gradle-wrapper.properties`, the `dependencies` block of `client/app/android/app/build.gradle.kts` (desugar_jdk_libs, AndroidX, Play review) |
| GitHub Actions | `.github/workflows/*.yml`, `.github/actions/*/action.yml`, `.github/actionlint.yaml` |
| Docker | `.github/scripts/Dockerfile.*`, `tool/release_scheduler/Dockerfile`, digest-pinned images in workflows |
| Node | `tool/release_scheduler/package.json` + lockfile; `bridge/app/npm/*` are publish shims whose versions the release sets |
| Pinned tools in scripts | e.g. `VPK_VERSION` in `.github/scripts/package_desktop_linux.py` |
| Desktop CMake | `client/desktop/{linux,windows}/CMakeLists.txt` (Flutter template minimums; usually nothing to change) |
</project_structure>

<process>
<phase name="0. Sweep">
<description>Discover the ACTUAL surface. Hardcoded lists go stale; a surface missing from this skill is the most common failure (a missed bridge package once sat stale for weeks, and a whole run once skipped CI, Docker, Node and Android). Whatever this sweep finds is in scope.</description>

<step name="0.1">Run the generic sweep from the repo root:

```bash
git ls-files '*pubspec.yaml' | sort
sed -n '/^workspace:/,$p' bridge/pubspec.yaml client/pubspec.yaml
git ls-files | grep -E 'Package\.resolved$|Gemfile(\.lock)?$|package(-lock)?\.json$|\.gradle(\.kts)?$|gradle-wrapper\.properties$|Dockerfile|\.tool-versions$|CMakeLists\.txt$|\.(nvmrc|node-version|ruby-version|python-version)$|dependabot|renovate'
grep -rhoE 'uses: *[^ ]+' .github | sort | uniq -c
grep -rnE '(python|ruby|node|java|dotnet|go|flutter|xcode)-version:|XCODE_VERSION|runs-on:|runner:|@sha256:|^FROM ' .github tool
grep -rnE '^[A-Z_]*VERSION[A-Z_]* *= *"' .github/scripts tool --include=*.py --include=*.sh --include=*.ts
```

Every hit belongs to a phase below. If one doesn't fit any phase, handle it anyway and add it to the `<project_structure>` table so future runs inherit it.
</step>

<step name="0.2">Check ownership. Before touching a surface, check open PRs (`gh pr list --state open`) for one already changing it. Leave owned files alone and list them in the conflict table with the owning PR.
</step>
</phase>

<phase name="1. Flutter/Dart SDK and environment constraints">
<step name="1.1">Update Flutter to the latest stable and pin it in `.tool-versions`:

```bash
asdf install flutter latest && asdf set flutter latest && flutter --version
```

If `flutter --version` still shows the old version, run `asdf reshim flutter`.
</step>

<step name="1.2">In every in-scope pubspec (all except `shared/no_slop_linter`), update the `environment` keys that are present to the bundled Dart (`sdk`) and Flutter (`flutter`) versions. Preserve each file's syntax: caret (`^3.13.0`) or range (`">=3.47.0 <3.48.0"`). Only the client root and a few Flutter members carry a `flutter` key. Commit `.tool-versions` and env changes on their own.
</step>

<step name="1.3">Delete every `pubspec.lock` except the linter's:

```bash
find . -name pubspec.lock -not -path './.worktrees/*' -not -path './shared/no_slop_linter/*' -delete
```
</step>
</phase>

<phase name="2. Dart dependencies">
<step name="2.1">Check for updates. Workspaces resolve as a unit; run `outdated` per member to see each one's direct deps (`flutter pub outdated` for Flutter members, `dart pub outdated` for pure Dart):

```bash
(cd shared/sesori_shared && dart pub outdated)
(cd bridge && dart pub get) && for m in $(sed -n '/^workspace:/,$p' bridge/pubspec.yaml | sed -n 's/^ *- *//p'); do (cd bridge/$m && dart pub outdated --show-all); done
(cd client && flutter pub get) && for m in $(sed -n '/^workspace:/,$p' client/pubspec.yaml | sed -n 's/^ *- *//p'); do (cd client/$m && flutter pub outdated --show-all); done
```

Use `--show-all`: after lockfile regeneration the default output hides already-resolved latest versions even when their declared minimums can still be raised. For every major bump, read the changelog (pub.dev/packages/{pkg}/changelog) and fix breaking changes in the same run.
</step>

<step name="2.2">Bump constraints in this order: `shared/sesori_shared`, then the bridge members, then the client members (each in dependency order). Raise each direct and dev dependency's minimum to the latest resolvable version (`drift: ^2.30.1` → `^2.31.0`). Skip `any`, `path:` and `git:` references, and never edit `shared/no_slop_linter`. Recheck every `dependency_overrides` entry, especially `git:` forks: drop it once upstream ships the fix (a stale fork can sit below the version its parent package requires).
</step>

<step name="2.3">Resolve:

```bash
(cd shared && make pub-get)   # sesori_shared + no_slop_linter; confirm the linter is unchanged
(cd bridge && make pub-get)
(cd client && make pub-get)
```

`pub get` can keep older transitive pins even after constraints widen. If `outdated` still shows them, run `dart pub upgrade` (or `flutter pub upgrade`) in that resolution root only, never in `shared/no_slop_linter`. On a conflict, fall back to the highest compatible version and record the blocker.
</step>

<step name="2.4">**HALT check.** Account for shared, bridge and client separately: each one either shows pubspec changes in `git diff --name-only -- '*.yaml'` or has `outdated` output proving it had nothing to upgrade. A workspace with outdated packages and no diff was skipped. Go back and update it.
</step>

<step name="2.5">Verify with the Makefiles, never with per-package `dart analyze` by hand:

```bash
set -e
for d in shared bridge client; do (cd $d && make analyze && make test && make codegen); done
```

If a generator is added to a skipped package, update `CODEGEN_MODULES` in that Makefile.

To compare `liquid_glass_widgets` versions on screen, render under the app's own glass setup: `LiquidGlassWidgets.wrap` with the adaptive scope capped at `standard`, as in `client/app/lib/main.dart`. A bare harness without it falls back to `premium`, which the app never renders. Take settled shots with `timeDilation = 1`. Verified 2026-11-20: a corner artifact seen in 1.19.0 harness shots came from the premium path only.

CI seeds the `sqlite3` and `pdfium_dart` (pdfrx) build-hook downloads with `.github/actions/prefetch-sqlite3-native/prefetch.py`, which parses those packages' sources and pins archive hashes. `make test` doesn't run it. When either package's resolved version changes, run all four plans, and fix the script (or `PDFIUM_PINS`) in the same PR if one fails:

```bash
set -e
for wp in "bridge host" "client host" "client android" "client ios"; do set -- $wp
  GITHUB_OUTPUT=/dev/null python3 .github/actions/prefetch-sqlite3-native/prefetch.py --workspace $1 --platform $2 plan; done
```
</step>
</phase>

<phase name="3. SwiftPM (iOS + macOS)">
<description>`Package.resolved` pins Firebase/Google/gRPC/leveldb/Sparkle versions pulled in by Flutter plugins. Native patch releases land continuously, independent of pubspec.yaml, so re-resolve every run. Each native directory has two tracked copies: `Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (project) and `Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved` (workspace). The release lanes build the **workspace** (`build_app(workspace: "Runner.xcworkspace")`), so a stale workspace copy ships old native SDKs. Verified 2026-07-21: the stale workspace copy resolved AppCheck 11.3.0 / GoogleUtilities 8.1.1 while the project copy said 11.3.1 / 8.1.2.</description>

<step name="3.1">Regenerate the plugin package and the project copies with `flutter build --config-only`, **not** a bare `xcodebuild -resolvePackageDependencies`, which honors existing pins and silently no-ops. One past run's bare resolve reported "no changes" when `--config-only` found GTMSessionFetcher 4.5.0→5.3.0, GoogleUtilities, nanopb and Promises. Run it from each owning shell. Without Xcode, record SwiftPM as deferred.

```bash
(cd client/app && flutter build ios --config-only --release --no-codesign)
(cd client/desktop && flutter build macos --config-only --release)
```

Then raise the direct package references the Runner projects declare themselves (`grep -n -A5 XCRemoteSwiftPackageReference client/*/*/Runner.xcodeproj/project.pbxproj`). They use `exactVersion`, so no resolve ever moves them: edit `version =` to the latest release (`gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`), read the release notes of a major for minimum-OS and API changes, and build the shell once (`flutter build macos --debug`). Verified 2026-11-20: desktop macOS still pinned Firebase 12.19.3 while iOS resolved 13.2.0.
</step>

<step name="3.2">Re-resolve the workspace copies. Delete each lockfile first, and use a scratch clone cache, because the shared cache can hold stale tag data:

```bash
set -e
for native_dir in client/app/ios client/desktop/macos; do
  lockfile="$native_dir/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved"
  backup="$(mktemp)"; [ -f "$lockfile" ] && cp "$lockfile" "$backup"; rm -f "$lockfile"
  if (cd "$native_dir" && xcodebuild -resolvePackageDependencies -workspace Runner.xcworkspace -scheme Runner \
      -clonedSourcePackagesDirPath "$(mktemp -d)"); then rm "$backup"
  else [ -s "$backup" ] && mv "$backup" "$lockfile"; exit 1; fi
done
```
</step>

<step name="3.3">Assert that the two copies agree per directory:

```bash
for d in client/app/ios client/desktop/macos; do
  diff <(jq -S .pins "$d/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved") \
       <(jq -S .pins "$d/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved") \
    && echo "$d: identical" || echo "$d: MISMATCH"
done
```

On a mismatch, run the same delete-and-resolve as 3.2 against the **project** copy (`-project Runner.xcodeproj`), keeping the fresh workspace copy. Verified 2026-08-19 with Flutter 3.47.0: `--config-only` can leave the project copy on older valid pins. An empty diff after a "successful" resolve usually means a resolve that honored old pins, so check the exit codes.
</step>
</phase>

<phase name="4. Ruby and Fastlane">
<step name="4.1">Put a modern Ruby first on `PATH`. The lockfiles use Bundler 4, which macOS's system Ruby 2.6 can't run (`export PATH=/opt/homebrew/opt/ruby/bin:$PATH`). Raise `fastlane` in both Gemfiles to the latest (`gem search fastlane --remote`), then run `bundle update` in `client/app/ios` and `client/app/android`.
</step>

<step name="4.2">Verify under the Ruby version CI installs (the `ruby-version` in the workflows, bumped in Phase 6): `bundle exec fastlane --version` in both directories, `ruby -c` on both Fastfiles, and `ruby client/app/fastlane/test_build_changelog.rb`.
</step>
</phase>

<phase name="5. Android toolchain">
<step name="5.1">Find the latest stable versions, ignoring alpha, beta, RC, milestone, snapshot and nightly builds:

- AGP: `https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/maven-metadata.xml`
- google-services: `https://dl.google.com/dl/android/maven2/com/google/gms/google-services/maven-metadata.xml`
- Crashlytics: `https://dl.google.com/dl/android/maven2/com/google/firebase/firebase-crashlytics-gradle/maven-metadata.xml`
- Kotlin Gradle plugin: `https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-gradle-plugin/maven-metadata.xml`
- Gradle: `https://services.gradle.org/versions/all`
- App-side Gradle deps in `client/app/android/app/build.gradle.kts`: each artifact's `maven-metadata.xml` under `https://dl.google.com/dl/android/maven2/<group path>/<artifact>/` (Google Maven) or `https://repo1.maven.org/maven2/` (Maven Central). Verified 2026-11-23: constraintlayout 2.2.2 (July 2026) had been missed because earlier runs only checked the plugins.
</step>

<step name="5.2">Pick the newest mutually compatible set, not just the newest of each:

- AGP release notes: minimum Gradle and JDK.
- The Kotlin table at kotlinlang.org/docs/gradle-configure-project.html caps the Gradle version. It once capped Gradle at 9.7.x while 9.9.1 existed.
- The pinned Flutter's `DependencyVersionChecker.kt` / `gradle_utils.dart` minimums.
- The Gradle compatibility matrix (docs.gradle.org/current/userguide/compatibility.html): the Java version the chosen Gradle can **run** on.
</step>

<step name="5.3">Edit the plugin `version` entries in `client/app/android/settings.gradle.kts` and `distributionUrl` in `gradle/wrapper/gradle-wrapper.properties`. The repo doesn't track `gradlew` or the wrapper jar, so edit the properties file directly rather than running `./gradlew wrapper`. Verify with `flutter build apk --debug`, and read its warnings: plugins that apply KGP themselves will fail on future Flutter versions, so record any such warning.
</step>

<step name="5.4">JDK: `java-version` in `.github/workflows/_reusable-android-internal.yml` must be an LTS that the chosen Gradle runs on and AGP accepts. Never lower it. Flutter builds with Android Studio's bundled JBR, not `JAVA_HOME`, so to verify a different JDK, run `./gradlew assembleDebug` in `client/app/android` with `JAVA_HOME` set after one `flutter build apk`.
</step>
</phase>

<phase name="6. GitHub Actions, CI toolchains and runners">
<step name="6.1">Get the latest release of every action from the sweep's `uses:` list with `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`. Read the release notes of every major in between, check our inputs against them (for example `artifact-ids`, `pip-install`, `registry-url`/`NODE_AUTH_TOKEN`) and fix breaking changes.
</step>

<step name="6.2">Pinning convention:

- GitHub-owned `actions/*` use major tags (`@v7`). Exception: steps that hold secrets, such as `create-github-app-token`, are SHA-pinned.
- Every third-party action is pinned to a commit SHA with a version comment: `uses: owner/repo@<40-char sha> # vX.Y.Z`. Resolve the SHA with `gh api repos/<owner>/<repo>/commits/<tag> --jq .sha`, which dereferences annotated tags.

Edit with a tool that preserves line endings. Some workflow files are CRLF, and a naive read/write rewrites every line. Check `git diff --stat` for whole-file churn.
</step>

<step name="6.3">Toolchains the workflows install:

- Flutter comes from `.tool-versions` through `resolve-flutter-dart-version`.
- Python and Ruby: latest stable that the setup actions offer.
- Node and JDK: latest LTS.
- .NET: the newest version the pinned `vpk` tool ships for. Check the `tools/net*` folders in its nupkg; tools don't roll forward to a newer major.
- Xcode: `XCODE_VERSION` in `.github/actions/setup-xcode/action.yml`. Use the newest **release** build (not beta or RC; check xcodereleases.com) that the runner image README lists.

Verify every bump locally where possible: the `.github/scripts` unittest suite under the new Python, Fastlane under the new Ruby (Phase 4.2), and the Android build under the new JDK (Phase 5.4).
</step>

<step name="6.4">Runner images: move a pinned label to the newer image only once the runner-images README lists it without a beta or preview badge. Keep Linux **build and qualification** hosts on the release that sets the documented glibc floor (`docs/desktop/downloads.md`); moving them is a support-floor decision, not a version bump. If actionlint doesn't know a new GA label yet, add it to `self-hosted-runner.labels` in `.github/actionlint.yaml` with a comment.
</step>

<step name="6.5">Workflow-contract tests in `.github/scripts/test_*.py` match workflow text. Keep them version-agnostic (`uses: actions/checkout@`, not `@v6`). Run them from the repo root:

```bash
PYTHONPATH=.github/scripts python3 -m unittest discover -s .github/scripts -p 'test_*.py'
actionlint   # compare against main's output; no new findings
```
</step>
</phase>

<phase name="7. Docker images">
<step name="7.1">Update each `FROM` to the latest base: latest Node LTS on the current Debian stable slim image for `tool/release_scheduler`, and the latest digest of the pinned distro release elsewhere. Keep digest pinning where it's used. Resolve digests with `docker buildx imagetools inspect <image>:<tag> --format '{{json .Manifest.Digest}}'`.
</step>

<step name="7.2">The Fedora digest in `Dockerfile.linux-signing` and the Ubuntu/Debian/Arch digests in `desktop-qualification.yml` and `desktop-linux-session.yml` are named qualification fixtures, and a test keeps the shared ones in step. Refresh their digests every run. Moving a fixture to a new distro **release** renames a documented matrix row (fixture names, evidence files, `docs/desktop/downloads.md`), so it needs a decision and a dispatch qualification run.
</step>

<step name="7.3">Build every Dockerfile locally from its own build context: `docker build -f .github/scripts/Dockerfile.linux-signing -t sesori-linux-signing .github/scripts` and the same for `Dockerfile.linux-repository`, then `docker build -f tool/release_scheduler/Dockerfile tool/release_scheduler` (its `COPY` lines expect that directory as the context). Check each Dockerfile's `COPY` paths when picking the context. `Dockerfile.linux-repository` builds `FROM sesori-linux-signing`, so build that image first.
</step>
</phase>

<phase name="8. Node">
<step name="8.1">In `tool/release_scheduler`, raise every dependency to its latest version (`npm view <pkg> dist-tags`), keep `engines.node` and `@types/node` aligned with the Node major used by the Dockerfile and the workflow `node-version`, then run `npm install`, `npm run typecheck` and `npm test`. Also run them inside the new image's Node (`docker run node:<ver> ...`) when the major changes. Leave the `bridge/app/npm/*` package versions alone; the release sets them.
</step>
</phase>

<phase name="9. Remaining pins">
<step name="9.1">Update the other hits from sweep step 0.1: version constants in scripts (move them with their checksums), `.tool-versions` entries other than Flutter, and dependabot/renovate config if any appears. CMake minimums come from Flutter's templates, so change them only when Flutter's template changes.
</step>
</phase>

<phase name="10. Publish">
<step name="10.1">Group commits by surface. Follow the PR sizing rules in `AGENTS.md`: Dart/SwiftPM/Fastlane, the Android toolchain, and CI/Docker/Node usually make separate PRs in one `[<slug>] ... [step x/y]` series. Every PR body includes the conflict table.
</step>
</phase>
</process>

<conflict_tracking>
| Item | Current | Latest | Blocker | Next step |
|---|---|---|---|---|

Rules for a deferred row:

- **Name the concrete blocker**: the incompatibility, the upstream issue link, the owning PR, or the decision needed and who makes it. Rows without one are not deferrals; do the update.
- **Check that it isn't already done** before listing it. Run `git log origin/main --oneline -i --grep=<topic>`, `gh pr list --state all --search "<topic>"` and `git grep` for the API or setting involved. A past run listed the firebase_messaging token migration as pending when #2503 had already shipped it.
- **Upstream-blocked** rows link the upstream issue and say whether a prerelease fixes it.
</conflict_tracking>

<success_criteria>
- Phase 0 ran, and every surface it found is either updated or a deferred row with a concrete blocker.
- `.tool-versions` and every in-scope pubspec env constraint are current. Every in-scope pubspec is bumped, and shared, bridge and client are each accounted for. `shared/no_slop_linter` is untouched.
- `make analyze`, `make test` and `make codegen` pass in `shared`, `bridge` and `client`.
- Both SwiftPM graphs are re-resolved, with project and workspace pins identical, or deferred because no Xcode was available.
- Fastlane is current, and both bundles run under CI's Ruby.
- AGP, Gradle, KGP, google-services and Crashlytics are current and compatible; `flutter build apk --debug` passes; the JDK is an LTS that Gradle runs on.
- Every action is on its latest release, with third-party actions SHA-pinned. Toolchains and GA runner images are current. actionlint shows no new findings, and the workflow tests pass.
- Every Dockerfile builds. Node packages are current, and the release scheduler passes its typecheck and tests.
- The PRs are open with the conflict table, and no uncommitted changes remain.
</success_criteria>
