# Step 17/45 - Simplify Orchestrator and plugin lifecycle initialization

## Re-verification against `main`

`OrchestratorSession` still owned three `CompositeSubscription`s that were
cancelled together, a one-element plugin-listener list, and a `PushDispatcher`
reference used only to call a no-op disposal chain. The session now owns one
composite and one listener directly. The shared HTTP transport remains owned by
the composition root, so the no-op `PushDispatcher.dispose` and
`PushNotificationClient.dispose` methods and their tests are gone.

Plugin-event generation checks now consistently use `_isCurrentSource`. The
second same-stack check was removed because no await separates it from the
outer ordered check; every fence after an await or queued boundary remains.
Sourced event paths now require their already-non-null plugin ID. Initial relay
connection failures also retain their original error type and stack instead of
being replaced by an untyped exception that mislabeled later startup failures.

`PluginLifecycleService` now receives immutable plugin metadata in its
constructor. Registration-derived fields are non-null and final, and every
production and test caller supplies plugins at construction. The repository no
longer maps `PluginRuntimeSnapshot` into a field-for-field lifecycle copy; the
service consumes the runtime snapshot directly, including the typed transition.
The duplicated stop-intent and lifecycle-state mappings and ready-ID equality
loop are consolidated.

The three bridge-ID reads around idle-timeout mutation remain deliberate: they
fence immediate dispatch, acquisition of the queued mutation turn, and the
settings callback before persistence. Removing any of them would weaken the
existing identity-revocation behavior covered by the lifecycle tests.

No wire contract, persisted data, database schema, or intended user-visible
behavior changed.

## Verification

- `dart analyze --fatal-infos` in `bridge/app`: clean.
- `dart test -j1 test/bridge/orchestrator_*_test.dart test/push
  test/services/plugin_lifecycle_service_test.dart
  test/bridge/routing/get_plugin_setup_handler_test.dart`: 231 tests passed.
- After adding constructor-time duplicate-ID coverage,
  `dart test -j1 test/services/plugin_lifecycle_service_test.dart`: 50 tests
  passed.
- `git diff --check`: clean.
- `dart format` formatted all supported touched files. The pinned formatter
  crashes while building existing enhanced enum bodies in `orchestrator.dart`,
  `bridge_runtime_runner.dart`, and `plugin_lifecycle_test_support.dart`
  (`dart_style` null-check failure); analyzer parsing is clean and their edited
  sections retain the existing formatting.

The production diff excluding this evidence file is `+184 / -284`.

## Architecture implementation review

Approved with no actionable findings.
