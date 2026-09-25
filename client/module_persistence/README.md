# Shared client persistence

Pure-Dart infrastructure below client auth/core, shared by mobile and desktop.
No dependency on Flutter or product/domain packages.

- Distinct string/bool/secret key contracts prevent secrets from entering
  plaintext APIs. Domain packages own explicit spellings and serialization.
- `PersisterRepository` maps typed primitive keys through `PersisterApi`
  directly into Drift. Defaults apply only to absence; failures propagate.
- `PersistenceDatabase` owns three tables (`StringValues`, `BoolValues`,
  `EncryptedValues`), a lazy background SQLite connection, WAL and disposal.
  SQLite owns atomicity, not a value cache or custom write queue.
- `StorageCipher` provides per-row AES-256-GCM, authenticated scope/key identity,
  fresh nonces and privacy-safe failures retaining original causes.
- Shells supply `PersistenceScope` and `PersistenceDirectory`: a ready,
  non-purgeable directory with native backup policy applied. Primitive access
  needs no `MasterKeyStore` binding or native authorization.

## Composition and cutover

Register lazy directory/scope bindings, then call
`configurePersistenceDependencies(getIt: getIt)` before auth/core registration.
Database, primitive API/repository and cipher are lazy; graph reset closes the
connection. The encrypted table is part of the shared schema, but the native-key
and secret-repository integration is the next active-plan slice.

Product shells are not switched yet. The `desktop-master-key-storage` plan adds
cached secrets, deprecated mobile import and native capabilities before coherent
consumer cutover. Existing auth's per-value interface remains live until then,
not as an alias or fallback inside this implementation.

## Verification

Run `dart test` and `dart analyze --fatal-infos` here. Fixtures use isolated
SQLite files/in-memory databases, not application directories or credentials.
Generate Drift and DI with `dart run build_runner build`; never edit generated
output by hand. See [the regression contract](../../docs/regression/client-persistence.md).
