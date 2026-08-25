# Step 3/45 — Delete dead shared helpers, models, and rxdart

**PR:** [#1020](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1020)

## Re-verification against `main`

The kept set changed: the plan listed `partition` as possibly dead after Step 2,
but shared's own `multi_task_isolate_pool.dart` uses it and `reduceSafe`, which
the plan had not listed as kept. Both stay, with `toUnmodifiableList`. The
`.verify(`, `.seeded(`, `.not()`, `unawaited` and `asyncMap` hits are
`ChecksumValidator.verify`, `BehaviorSubject.seeded`, Drift's `Expression.not`,
`dart:async`'s `unawaited` and native `Stream.asyncMap` — not these extensions.

## Verification

Analyze clean in all 12 bridge packages and all 7 client modules. Tests: shared
359, `bridge/app` 2,693, opencode 434, `client/module_core` 1,172.

Size (informational — self-inclusive of this record, so it cannot validate its
own budget), measured with
`git diff --numstat "$(git merge-base HEAD origin/main)"...HEAD`:
`+52 / -1,553` = 1,605 changed lines, above the 1,500 soft cap. The overage is
deletion-only: 1,553 of the 1,605 lines are removals, of which 465 are generated
Freezed/JSON parts for the four dead models. Splitting would have separated a
helper's removal from the removal of its tests, so it stayed one PR.

The `bridge/app` total differs between step files because the package's own test
count changed during the series: 2,693 here, then 2,684 in Steps 5 and 7 after
Step 5 deleted the `PortRepository` and host-factory test files. Each figure is
correct for the tree it was measured on; they are not meant to be equal.

## Follow-up

Review flagged two `prefer_required_named_parameters` suppressions; the
conversion to required named parameters landed in Step 4.
