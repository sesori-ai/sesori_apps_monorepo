# Typed client persistence

Pure-Dart infrastructure below the client auth/core modules.

- `StringPersistenceKey` and `BoolPersistenceKey` identify plaintext primitives.
- `SecretStorageKey` is separate and accepted only by `SecureStorage`.
- Domain packages define enum keys with explicit stable spellings, or immutable
  scoped keys with required identities. The persistence module does not know
  about accounts, bridges, preferences, auth tokens, or their serialization.
- `PersisterRepository` maps typed keys through `PersisterApi` to the
  shell-provided `PrimitiveStorage`. Defaults apply only to absent values;
  failures propagate unchanged. There is no cache or background work.
- `SecureStorage` is a separate platform capability, not an encryption flag on
  the primitive API. Its implementation owns secret persistence policy.

## Composition

Register the shell's lazy platform capabilities first, then call
`configurePersistenceDependencies(getIt: getIt)` before auth/core registration.
The generated bindings are lazy; registration performs no storage I/O. The
module does not instantiate a native backend or manage its lifetime.

This package is initially unwired. Existing mobile/desktop storage remains
unchanged until the integration step in the active desktop storage plan.

## Verification

From this directory, run `dart test` and `dart analyze --fatal-infos`. Generate
DI output with `dart run build_runner build`; never edit it by hand.
