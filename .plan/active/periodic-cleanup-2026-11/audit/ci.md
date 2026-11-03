# CI and tooling cleanup audit

## Summary
CI and tooling are in good shape. Every `.github/scripts/*` file has an invoker, every `test_*.py` runs in some workflow, every composite action and reusable workflow has a caller, the Makefile MODULES lists match the package directories, and no workflow still references a deleted package. The debt is small, scattered leftovers from three migrations: `build-<N>` tags to `v*-internal.<N>`, `mobile/` to `client/`, and the retired macOS signing bootstrap.
Top 3:
1. XC-CI-1: edits to `submit-release.yml` and the Firebase cutoff files trigger the full Mobile CI (analyze plus 7 Flutter test shards) only so one Python test can run. Moving that test to Release Workflow CI ends this.
2. XC-CI-2: the legacy `build-<N>` tag and `mobile/app` pubspec fallbacks in two release workflows can no longer be reached.
3. XC-CI-3: `shared/sesori_shared/Makefile` is broken because it reads a `.tool-versions` file that has never existed, and its `make publish` target is still documented.
Estimated removable: about 150-200 lines of YAML, Make and test code, plus about 76 lines if the path lists are deduplicated (XC-CI-9). Three decisions could remove up to about 1,000 more lines (`tool/mcp-contracts`, `.github/release.yml`, `deploy-android-internal.yml`).

## Findings

### XC-CI-1 Firebase cutoff test runs full Mobile CI for release-workflow edits
- Category: simplification
- Evidence: `.github/workflows/mobile-ci.yml:20-23,40-43` add `publish_firebase_analytics_release_cutoff.py`, its test, `publish-firebase-analytics-release-cutoff.yml` and `submit-release.yml` to the Mobile CI path filters. The only consumer is the `toolchain` job step at `mobile-ci.yml:61-62` (`python3 .github/scripts/test_publish_firebase_analytics_release_cutoff.py`). Every Flutter job (`analyze`, 7 `test` shards) `needs: toolchain`, so a one-line `submit-release.yml` edit pays for the whole Flutter matrix. `release-workflow-ci.yml` already triggers on `submit-release.yml` (lines 23, 66) and already runs the other release Python tests (lines 105-125). `docs/regression/analytics.md:167-170` names the test file but not the workflow, so no doc change is needed.
- Proposal: Move the step to `release-workflow-ci.yml` next to `test_check_internal_release.py`. Add the cutoff script, its test and the cutoff workflow to that workflow's two path lists. Remove the 4 path entries (x2) and the step from `mobile-ci.yml`.
- Size: about 11 lines removed from mobile-ci, about 7 added to release-workflow-ci; 2 files.
- Risk: low. CI-only. The test's coverage stays the same, and Mobile CI stops running for non-mobile edits.
- Confidence: verified
- Decision needed: none

### XC-CI-2 Remove unreachable `build-<N>` and `mobile/app` fallbacks in release workflows
- Category: leftover
- Evidence: `submit-release.yml:16`, `:49` (dispatch input description "or build-<N> tag"), `:110`, `:117-121` (`refs/tags/build-${N}` fallback), `:129-136` (`git show "${SHA}:mobile/app/pubspec.yaml"` fallback), `:730` (comment). `publish-firebase-analytics-release-cutoff.yml:43-49` (`legacy_tag="build-${BUILD_NUMBER}"`, added a0568e2d6a on 2026-08-28). The last `build-N` tag is `build-52` (2026-06-10). The `mobile/` to `client/` rename landed in f52be45c13 on 2026-06-25. TestFlight builds expire after 90 days, and Play requires increasing version codes, so a `build-N` from June can no longer be submitted. No test or doc asserts these fallbacks (rg over `.github/scripts`, `docs`).
- Proposal: Remove the legacy tag branch, the `mobile/app` fallback and the related comments and error-text fragments. Shorten the `:730` comment, because the reason (resolved commits predating the notes script) no longer holds once only `v*-internal` tags resolve.
- Size: about 15 lines removed or changed; 2 files.
- Risk: low. It only affects promoting a build older than 2026-06-10, which the stores no longer accept.
- Confidence: verified
- Decision needed: none

### XC-CI-3 Broken `shared/sesori_shared/Makefile` and its stale `make publish` docs
- Category: leftover
- Evidence: `shared/sesori_shared/Makefile` (18 lines) resolves `DART_VERSION := $(shell grep '^dart' .tool-versions ...)` and `$(HOME)/.asdf/installs/dart/$(DART_VERSION)/bin/dart`. No `shared/sesori_shared/.tool-versions` has existed since the monorepo import (`git log --all -- shared/sesori_shared/.tool-versions` is empty), and the root `.tool-versions` pins only `flutter`, so every target runs a nonexistent binary. `shared/sesori_shared/AGENTS.md:71` documents `make publish # Publish to pub.dev`. pub.dev `sesori_shared` 0.3.0 was published from the old `sesori-ai/sesori_shared_dart` repository. In the monorepo the package is consumed only by path (for example `bridge/app/pubspec.yaml:19-20`), its CHANGELOG has not changed since the import, and its pubspec has no `publish_to`. `shared/Makefile` already provides `pub-get`/`codegen`/`test`/`analyze` for `sesori_shared` and `no_slop_linter`, and CI uses those (`bridge-ci.yml` reads MODULES from it).
- Proposal: Delete `shared/sesori_shared/Makefile` and the AGENTS.md `make publish` line. If the package is no longer published, add `publish_to: none` to its pubspec so an accidental `dart pub publish` cannot push monorepo internals to pub.dev.
- Size: about 20 lines removed, 1 added; 2-3 files.
- Risk: low. Nothing invokes the Makefile, and it cannot run.
- Confidence: verified
- Decision needed: should `sesori_shared` still be published to pub.dev from the monorepo? The recommendation is no, with `publish_to: none`. If yes, publishing needs a working recipe and is no longer a deletion.

### XC-CI-4 Leftovers of the retired macOS signing bootstrap and the Inno installer
- Category: leftover / test-debt
- Evidence: `release-workflow-ci.yml:25,68` list `.github/workflows/migrate-macos-signing-secrets.yml`, which was deleted in 05e019302e (2026-09-17). It is the only workflow path filter in the repository that names a missing file. `test_macos_signing_workflows.py:135-136` `test_bootstrap_is_retired` asserts that the file does not exist (a tombstone test). `test_package_desktop_windows.py:229` `assertNotIn("Inno", workflow)` guards the Inno-to-Velopack switch (da5240459f), and no other Inno reference remains in the repository.
- Proposal: Remove the 2 path entries, `test_bootstrap_is_retired`, and the `Inno` NotIn assertion.
- Size: about 6 lines removed; 3 files.
- Risk: none (CI-only).
- Confidence: verified
- Decision needed: none

### XC-CI-5 `setup-flutter` action: undeclared input and an always-default parameter
- Category: leftover / simplification
- Evidence: `_reusable-android-internal.yml:48-50` passes `with: include-submodules: 'false'`. `.github/actions/setup-flutter/action.yml` declares only `workspace`, so the input has been silently ignored since the initial import (b65aada389), and the iOS copy was already removed in 9d4ed48f88. The two callers (`_reusable-ios-testflight.yml:83`, `_reusable-android-internal.yml:48`) use the default `workspace: client`. The last caller with a different value (`workspace: bridge`) was removed in fed841c2f9 (2026-09-25), so the `inputs.workspace != 'none'` branch (`action.yml:49-52`) is unused.
- Proposal: Drop the `with:` block in the Android caller. Inline `working-directory: client` and remove the `workspace` input and its `none` condition. `test_check_internal_release.py:186` only lists the action path, so it is unaffected.
- Size: about 10 lines removed; 2 files.
- Risk: low. Exercised only by mobile release lanes, so confirm with one internal release run after merging.
- Confidence: verified
- Decision needed: none

### XC-CI-6 Fully rolled-out `DESKTOP_MACOS_PUBLICATION_ENABLED` gate
- Category: leftover (rolled-out flag)
- Evidence: Repository variable `DESKTOP_MACOS_PUBLICATION_ENABLED=true`, set 2026-09-26 (`gh variable list`). Workflow conditions: `release-all-platforms.yml:205,234`, `_reusable-desktop-publish.yml:28`, `submit-release.yml:421,442,512`. Test assertions: `test_publish_desktop_release.py:154,178`, `test_publish_desktop_linux.py:282`. Docs: `bridge/RELEASING.md:141`, `docs/regression/desktop-distribution.md:107,578`, `docs/desktop/update-signing.md:40`. Linux publication has no equivalent gate. Related stale comment: `release-all-platforms.yml:19-20` says desktop "stays in Actions artifacts until its separate platform-publication admission is enabled", but it is enabled. `.plan/active/desktop-distribution` is still open, with step 12 retirement pending.
- Proposal: Remove the variable checks, test assertions and doc mentions, then delete the repository variable. A natural home is the desktop-distribution retirement step.
- Size: about 25-35 lines across about 8 files.
- Risk: low to medium. It removes a one-click macOS publication kill switch, and the release workflows need one internal run to confirm.
- Confidence: verified
- Decision needed: keep the variable as an intentional macOS kill switch (then reword its docs as a kill switch and fix the stale comment), or remove it like any rolled-out flag. The recommendation is to remove it, since Linux ships without one.

### XC-CI-7 One owner for parsing the Flutter version from `.tool-versions`
- Category: simplification
- Evidence: The same 16-line bash block (`TOOL_SPEC=$(awk '$1 == "flutter" { print $2 }' .tool-versions)`, a `-` split into version and channel, written to `GITHUB_OUTPUT`) appears in `mobile-ci.yml:64-81`, `desktop-ci.yml:43-58` and `design-catalog-ci.yml` (around 40-55). `.github/actions/resolve-flutter-dart-version/action.yml` already parses that spec into version and channel before it resolves the Dart version, and is used by `bridge-ci.yml:38` and `_reusable-bridge-build.yml:95`.
- Proposal: Add `flutter-version` and `flutter-channel` outputs to the existing action, or extract a parse-only step. Replace the three copies with one `uses:` line each.
- Size: about 40 lines removed, about 6 added; 4 files.
- Risk: low. A wrong output fails CI loudly at the `subosito/flutter-action` step.
- Confidence: verified
- Decision needed: none

### XC-CI-8 `.github/release.yml` configures notes nobody generates, and the `ignore-for-release` label does not exist
- Category: leftover
- Evidence: `.github/release.yml` (28 lines, unchanged since the initial import) groups GitHub's auto-generated notes by the labels `feat`, `fix`, `chore`, `refactor`, `docs`, `perf`, `test`, `ci` and `build`. None of these labels exist on the repository (`gh api repos/.../labels`: bug, documentation, duplicate, enhancement, invalid, question, wontfix, ready-for-human-review, Do not merge, triage, automatically-merged, agent-ready). No workflow uses `generate_release_notes`. Releases use `tool/generate_release_notes.dart`, through `--notes-file` (`release-all-platforms.yml:351-353`) and `body_path` (`submit-release.yml:777`). That tool classifies by title prefix. Its `_ignoreLabel = 'ignore-for-release'` (`tool/generate_release_notes.dart:34,355`) and the `release.yml` exclude both name a label that does not exist and was never applied (`gh search prs --label ignore-for-release` is empty). The `release-notes` skill (`.agents/skills/release-notes/SKILL.md:74`) documents that exclusion.
- Proposal: Delete `.github/release.yml`. Either create the `ignore-for-release` label so the documented exclusion works, or drop `_ignoreLabel`, its check and the SKILL line.
- Size: about 28 lines removed, plus about 5 if the label check goes; 1-3 files.
- Risk: low. It only affects the GitHub UI "Generate release notes" button grouping, which no release flow uses.
- Confidence: verified
- Decision needed: should PR authors be able to exclude a PR from release notes by label? If yes, create the label and delete only `release.yml`. If no, delete both.

### XC-CI-9 Identical push and pull_request path lists duplicated in four workflows
- Category: simplification
- Evidence: The `push.paths` and `pull_request.paths` lists are byte-identical in `bridge-ci.yml` (7 entries), `design-catalog-ci.yml` (10), `mobile-ci.yml` (18) and `release-workflow-ci.yml` (41). Each new path must be added twice. XC-CI-4's stale entry exists twice for this reason.
- Proposal: Define each list once with a YAML anchor (`paths: &paths [...]`, then `paths: *paths`). GitHub Actions has accepted anchors since 2025.
- Size: about 76 lines removed; 4 files.
- Risk: low, provided the repository's workflow linters accept anchors.
- Confidence: needs-check. Confirm that `actionlint`, or whatever lints workflows here, and the Python source-contract tests that read workflow text (for example `test_check_internal_release.py`, `test_bridge_build_workflow.py`) accept anchored path lists.
- Decision needed: none

### XC-CI-10 Bridge CI does not trigger on `tool/sync_versions.dart`
- Category: test-debt (coverage gap)
- Evidence: `bridge/app/test/tool/sync_versions_test.dart` loads the repository-root tool (`_toolSourcePath() => p.join(_repoRoot(), 'tool', 'sync_versions.dart')`). The `bridge-ci.yml` paths are `bridge/**`, `shared/**`, `install.sh`, `install.ps1`, `.tool-versions`, its own file and `run_test_shard.sh`, without `tool/sync_versions.dart`. A PR that changes only the version-sync tool runs none of its tests.
- Proposal: Add `tool/sync_versions.dart` to both bridge-ci path lists, or once with XC-CI-9.
- Size: 2 lines added; 1 file.
- Risk: none.
- Confidence: verified
- Decision needed: none

### XC-CI-11 Stale CI and tooling comments
- Category: leftover (stale comments)
- Evidence: `release-all-platforms.yml:19-20` says desktop stays in artifacts until publication admission is enabled, but desktop is published (see XC-CI-6). `bridge-npm-publish.yml:3` says "5 platform packages", but `bridge/app/npm/` has 6 (darwin-arm64/x64, linux-arm64/x64, win32-arm64/x64). The root `Makefile` comment describes the version bump as "bridge and client (mobile) apps", but `tool/sync_versions.dart` also bumps `client/desktop`.
- Proposal: Correct the three comments. Fold them into XC-CI-6 or any adjacent PR rather than opening a standalone PR.
- Size: about 4 lines changed; 3 files.
- Risk: none.
- Confidence: verified
- Decision needed: none

### XC-CI-12 `tool/mcp-contracts` tests never run in CI
- Category: test-debt
- Evidence: `tool/mcp-contracts/` holds 915 lines (`fixture.mjs`, `probe.mjs`, `released-peer.mjs`/`.dart.in`, `terminal.py`, 4 `*.test.mjs`), added once in 2c70025d8f (2026-10-13). Its README says `node --test tool/mcp-contracts/*.test.mjs`. No workflow runs it (rg over `.github` is empty). It is the manual probe for the active `.plan/active/mcp-management` plan, now at step 36 of 37.
- Proposal: At mcp-management retirement, either add a `node --test` step to `release-workflow-ci.yml` (which already runs Node tests for `tool/release_scheduler`) with a `tool/mcp-contracts/**` path filter, or delete the directory if the probe has served its purpose.
- Size: either a 3-5 line CI addition or 915 lines removed.
- Risk: low either way. Deletion loses a manual released-peer probe.
- Confidence: verified (never run in CI). Ongoing value after the plan retires is unverified.
- Decision needed: is the MCP released-peer probe a lasting tool (run it in CI) or plan scaffolding (delete it at retirement)?

### XC-CI-13 `deploy-android-internal.yml` has never run
- Category: leftover (candidate)
- Evidence: `deploy-android-internal.yml` (30 lines, manual `workflow_dispatch` wrapper around `_reusable-android-internal.yml`) has 0 runs ever (`gh run list -w deploy-android-internal.yml`). The iOS sibling `deploy-ios-testflight.yml` has run once (2026-10-29). `release-all-platforms.yml` calls the same reusable workflow hourly. `client/app/android/fastlane/Fastfile:78` refers to the wrapper in a comment.
- Proposal: Delete it and the Fastfile comment reference, or keep both platform wrappers as symmetric escape hatches.
- Size: about 31 lines removed; 2 files.
- Risk: low. It loses a one-click Android-only internal deploy, and a full `release-all-platforms` dispatch remains.
- Confidence: verified
- Decision needed: keep the manual single-platform deploy wrappers as an escape hatch, or delete the unused Android one (and the iOS one with it, for symmetry)?

## Checked and kept
- `.github/scripts/*`: every script has an invoker (workflow step, import by another script, or a documented skill/doc for manual use).
- Every `test_*.py` runs in CI, through `desktop-qualification.yml` (the `test_*desktop*.py` glob plus Docker runs), `release-workflow-ci.yml`, `mobile-ci.yml`, or the native-architecture reruns in `desktop-linux-session.yml` and `desktop-linux-authenticated-upgrade.yml`. The overlap between desktop-qualification and release-workflow-ci is intentional: different triggers, and the focused native-architecture reruns.
- `test_bridge_build_workflow.py:31-32` NotIn assertions (`setup-flutter`, `use_asdf`) sit inside a positive test that bridge builds use a bare Dart SDK. They guard a live performance invariant, so they are not tombstones.
- `.github/actions/*`: all composite actions have callers, and no declared input is unused except `setup-flutter` `workspace` (XC-CI-5).
- Reusable workflows (`_reusable-*`): all have callers. No workflow_dispatch or workflow_call inputs or secrets are declared but unread.
- Makefiles: bridge (16), client (9) and shared (2) MODULES lists match the package directories. Target paths exist and are documented in `docs/CONTRIBUTING.md`, `bridge/README.md`, `bridge/AGENTS.md`, `client/README.md` and the update-dependencies skill. Only `shared/sesori_shared/Makefile` is broken (XC-CI-3).
- `tool/sync_versions.dart`, `tool/generate_release_notes.dart` and `tool/release_scheduler/`: all paths valid, all in use (`release_scheduler` dispatches the hourly internal release and its tests run in release-workflow-ci).
- `install.sh` / `install.ps1`: live, covered by bridge-ci path filters and documented in `bridge/INSTALL.md`.
- `bridge-ci.yml`: the test, codegen-freshness and build-smoke jobs each repeat setup-dart, cache and `pub get`. A composite action would save about 15 lines but add indirection across 3 small jobs, so it is a marginal cleanup and kept.
- Low-run workflows (`sign-linux-release` 1 run, `verify-macos-signing` 6, `desktop-release` 4, `desktop-linux-release` 1, `linux-repository` 4 scheduled): all part of live, documented desktop release or recovery flows.
- No references remain to deleted `probe_sparkle.swift`, `macos-desktop-qa`, `.opencode` skills, `fetch_speech_model.sh` or Inno, apart from the XC-CI-4 test.
- `docs/cleanup-audit-2026-09-04.md` and `CONSOLIDATION.md` "Deferred findings" contain no CI or tooling items, so no earlier retention decision applies to this area.
