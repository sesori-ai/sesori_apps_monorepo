# Step 44 — Regression Coverage Reconciliation

## Re-verified evidence

- Reconciled the Step 44 regression-document matrix against `origin/main` at
  `bafa7cd026`, including the behavior-changing steps and source moves from the
  cleanup series.
- Merge-base diff: 9 files, 61 insertions, 17 deletions.
- The plugin, client, compatibility, installer, notification, analytics, and
  design contracts still describe the merged implementation and retain their
  existing regression levels and proof boundaries.
- OMP starts `omp acp` without an approval-mode argument; the prior claim that
  it inherited the user's `tools.approvalMode` was not supported by the launch
  specification. Pi continues to launch every session mode with `--approve`.
- Step 7 flattened bridge production code out of `lib/src/bridge/`; several
  source lists still named the old layout even though their behavior contracts
  remained current.

## Change

- Corrected the OMP approval ownership statement in plugin lifecycle coverage.
- Updated bridge source references in plugin lifecycle, runtime installation,
  session creation, session turns, projects and sessions, diffs, and tool/file
  coverage to the current flattened layout.
- Added the existing popup-alert regression document to the feature index.
- Reviewed without changes: bridge connectivity, questions and permissions,
  session history and recovery, voice input, session archiving and deletion,
  account and onboarding, bridge installation and updates, notifications,
  analytics, design catalog, and popup alerts.

## Verification

- Confirmed every updated source path exists in the current tree.
- Confirmed OMP's launch arguments and Pi's `--approve` arguments directly from
  their production launch specifications.
- Searched regression documents for remaining references to the flattened
  `bridge/app/lib/src/bridge/` production layout.
- `git diff --check`: passed.
- Architecture implementation review: not run; this step changes documentation
  and plan evidence only.
