# Step 16/45 - Consolidate PluginRuntime command transitions

## Re-verification against `main`

`stop`, `prepareDisable`, and `restart` still repeated the same command guard,
ownership, completer, transition, and settlement machinery. Their private
single-caller implementations have been folded into the public methods, while
the common behavior now lives in `_stopPreconditionConflict`,
`_beginCommandTransition`, and `_settleCommandTransition`.

The separate nullable transition owner and completer are now one nullable
`_CommandTransition` record whose members are both non-null. This makes partial
command ownership state unrepresentable and lets all ownership checks compare
the record's unique owner. Prepared disables continue retaining the transition
until `commitDisable` or `rollbackDisable`; stop and restart continue settling
their transitions in `finally`; disposal continues waiting for settlement.

`use` now delegates to `useWithGeneration` and discards only the returned
generation. Rejected disable preparation now runs the synchronous guard ladder
before publishing the draining gate, so a command that never starts no longer
publishes a transient draining snapshot or invalidates an in-flight setup
inspection. There is no await in that precondition sequence, so acquisition
fencing is unchanged.

No wire contract, persisted data, database schema, or user-visible behavior
changed.

## Verification

- `dart analyze --fatal-infos` in `bridge/app`: clean.
- `dart test -j1 test/bridge/runtime/plugin_runtime_test.dart
  test/services/plugin_lifecycle_service_test.dart`: 109 tests passed.
- `test/helpers/plugin_runtime_test_support.dart` is a helper library, not a
  runnable test suite; it is compiled by the runtime tests above.
- `git diff --check`: clean.
- `dart format lib/src/runtime/plugin_runtime.dart` could not run because the
  pinned formatter crashes while building this file's existing enhanced enum
  body (`dart_style` null-check failure); analyzer parsing is clean and the
  edited sections retain the file's existing formatting.

The production diff excluding this evidence file is `+230 / -364`.

## Architecture implementation review

Approved. The reviewer confirmed the transition record makes partial ownership
impossible, the helpers remain private on the lifecycle invariant owner, force
takeover and restart failure precedence are preserved, prepared-disable and
disposal settlement remain serialized, and `useWithGeneration` preserves lease,
generation, authentication, and release behavior.
