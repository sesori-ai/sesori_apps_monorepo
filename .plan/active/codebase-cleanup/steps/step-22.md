# Step 22/45 — Deduplicate updater/server helpers and seal platform trios

## Re-verification against `main`

The duplicate tasklist CSV parsers, filesystem classifiers and cleanup logic,
transient-network ladders, updater failure text, editor pass-through repository,
and public per-platform wake-lock/editor classes all remained. The updater's
`UpdateInstallResult` and `UpdateResolution` also still admitted coordinated or
impossible states.

Two plan assumptions were stale. Server runtime-file deletion needs surfaced
errors rather than updater-style best-effort cleanup, and the updater's EIO(5)
classification must remain updater-local rather than becoming a bridge-wide
permission rule. Both current semantics were preserved.

## Change

- Added a Layer-0 `CsvParser`, moved `FilesystemCleaner` to Layer 0, expanded
  `FilesystemPermissionValidator`, and reused them from updater/server callers.
- Centralized transient-network classification and canonical updater failure
  reasons. `UpdateResult` now represents failures only, successful downloads
  return no failure, staged installs are sealed success/failure variants, and
  the latest eligible release/version pair is one nullable record.
- Folded the one-method `DefaultEditorRepository` into
  `BridgeSettingsRepository`; settings-only compositions explicitly inject no
  editor while config editing injects the platform API.
- Collapsed wake-lock and default-editor platform trios into factory-selected
  private implementations, reused the shared process starter, and centralized
  warning logging with preserved error and stack-trace arguments.
- Removed obsolete platform files, local parser/cleanup/error helpers, and the
  superseded platform/repository tests. There is no user-visible, wire,
  persisted-data, or database behavior change.

## Verification

- `dart analyze --fatal-infos` in `bridge/app`: passed.
- Full `dart test` in `bridge/app`: 2,691 passed; 2 executable PowerShell cases
  skipped because PowerShell is unavailable locally.
- Focused updater/server suite during implementation: 160 passed.
- Focused platform/editor/sleep-prevention suite: 46 passed.
- Final process-ID/system-process suites after the parser architecture fix: 17
  passed.
- Correctness review found three integration gaps; impossible staged success,
  explicit editor availability, and wake-lock failure coverage were fixed. The
  follow-up review found no remaining issues.
- Architecture implementation review found one top-level parser-boundary issue;
  the logic now lives on the named `CsvParser` collaborator, and the second
  review approved the implementation with no remaining findings.
- `git diff --check`: passed.
- Size excluding this evidence file against `a278f0dc82`:
  **`+672 / -1064` = 1,736 changed lines**. This is 236 lines above the
  1,500-line soft cap because the coherent step replaces nine platform and
  repository files and their tests while making editor absence explicit at all
  concrete repository compositions; the production and test surface is 392
  lines smaller overall.
