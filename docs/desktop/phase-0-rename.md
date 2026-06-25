# Phase 0 — Workspace Rename (`mobile/` → `client/`)

> Goal: rename the `mobile/` workspace to `client/` so it can house both the
> mobile store app and the new desktop app. Dedicated, mechanical, atomic — done
> first so it never muddies feature diffs.

**Per-PR template:** Goal · Scope · Risk (+hazards) · Review-size · Acceptance ·
DoD · Aristotle verdicts · Findings log · Plan-deltas.

---

## PR 0.1 — Rename `mobile/` → `client/` (atomic)

- **Goal:** Rename the directory `mobile/` → `client/` and the pub workspace
  `sesori_mobile_workspace` → `sesori_client_workspace`, updating every
  reference so CI, tooling, and both mobile platforms keep working.
- **Scope (files/areas):**
  - Directory move `mobile/` → `client/` (use `git mv` so renames are visible).
  - Intra-workspace `pubspec.yaml` names/paths; root pub workspace name.
  - Root `Makefile` (`cd mobile` → `cd client`).
  - **All** `.github/workflows/*` referencing `mobile/` (`mobile-ci.yml`,
    `_reusable-next-build-number.yml`, `_reusable-ios-testflight.yml`,
    `_reusable-android-internal.yml`, `submit-release.yml`,
    `release-all-platforms.yml`, `lint-suppressions.yml`).
  - `.github/actions/setup-flutter/action.yml` (`default: 'mobile'`).
  - `tool/sync_versions.dart` (path joins **and** hardcoded `'mobile'` error
    strings) and `tool/generate_release_notes.dart:364`
    (`path.startsWith('mobile/')` PR classification).
  - Fastlane references; `.gitignore` (`!mobile/pubspec.lock`).
  - `AGENTS.md` files + `README.md` references.
- **Risk:** **Med-High.** Hazards: silent breakage of release-note
  classification and version-sync error strings (don't fail loudly); CI default
  working-dir breakage; missing a reference.
- **Review-size:** **L** — large but mechanical (a move + finite string updates).
  Reviewed via a **grep-proof**, not line-by-line.
- **Acceptance:**
  - `dart pub get` (workspace), `dart analyze`, and tests pass under `client/`.
  - `flutter build` works for iOS + Android.
  - **Mobile release-pipeline dry-run succeeds** (release-safety invariant #2):
    the TestFlight/Play workflows resolve all paths under `client/`.
  - Grep gate: `rg "mobile/" ` and `rg "'mobile'"` return only intentional
    matches (none in build/CI/tooling paths).
- **DoD:** pub get / analyze / test exit 0 · codegen unaffected ·
  release-safety invariant #2 verified · `aristotle-impl-review` clear.
- **Aristotle verdicts:** plan ☐ · impl ☐.
- **Findings log:** _(fill in as the PR lands)_
- **Plan-deltas:** _(record any discovered references not listed above)_

> Must stay atomic — splitting the rename across PRs breaks `main` between them.
