# Step 12/45 — Consolidate module_core test helpers

## Re-verification against `main`

The duplication is real but smaller than the plan's audit estimated, and the
counts differ because the audit counted usages while these are declarations:

| Mock | Files declaring it (plan estimate) | Actual |
|---|---|---|
| `MockPermissionRepository` | 6 | 6 |
| `MockNotificationCanceller` | 6 | 6 |
| `MockRelayHttpApiClient` | 6 | 5 |
| `MockAuthSession` | 15 | 4 |
| `MockSessionDetailLoadService` | 4 | 4 |
| `MockFailureReporter` | 5 | 3 |
| `MockRoomKeyStorage` | 6 | 2 |
| `MockProductAnalyticsService` | 5 | 0 (already consolidated) |

Every `Mock*` duplicate was a byte-identical one-liner, and both `FakeAuthSession`
copies hashed identically, so all consolidate without behaviour change.

One genuine divergence: `session_viewing_service_test.dart` declared its own
`FakeLifecycleSource` whose emit method was named `emit` rather than the
helper's `emitState`. Same behaviour, different name — the seven call sites now
use the helper's API.

The plan's `buildSessionDetailCubit` harness and the connection-service support
file are **not** in this step: the 28 long-hand cubit constructions differ in
more than defaults, and folding them needs the fakes to settle first. They move
to a follow-up so this step stays a pure de-duplication.

## Verification

`client/module_core`: `dart analyze --fatal-infos` clean, `dart test` 1,172
passed. 34 duplicate declarations removed across 13 files; `dart fix` cleared
the 19 imports they had required.

Architecture implementation review not run — test-only change, no production
code touched.
