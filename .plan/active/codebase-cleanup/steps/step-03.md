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
359, `bridge/app` 2,693, opencode 434, `client/module_core` 1,172. Size
`+52 / -1,553`.

## Follow-up

Review flagged two `prefer_required_named_parameters` suppressions; the
conversion to required named parameters landed in Step 4.
