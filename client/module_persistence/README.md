# Shared client persistence

Pure-Dart infrastructure below client auth/core, shared by mobile and desktop.
No dependency on Flutter or product/domain packages.

- Distinct `StringPersistenceKey`, `BoolPersistenceKey` and `SecretStorageKey`
  contracts prevent secrets from entering plaintext APIs. Domain packages own
  explicit key spellings, scoped identities and typed serialization.
- `PersisterRepository` maps typed string/bool keys through `PersisterApi`
  directly into Drift. Defaults apply only to absence; failures propagate.
- `SecureStorageRepository` owns per-row AES-256-GCM and one cached master-key
  initialization future. Failed initialization stays failed for that instance.
  Missing-row reads, deletes and all primitive operations require no native key.
- A missing master key is created only for a store without encrypted rows, and
  saved natively before ciphertext. Key loss/corruption never clears or re-keys
  existing rows. `StorageCipher` authenticates scope/key identity with fresh
  nonces and retains diagnostic causes behind privacy-safe error presentation.
- `PersistenceDatabase` owns three tables (`StringValues`, `BoolValues`,
  `EncryptedValues`), a lazy background SQLite connection, WAL and disposal.
  SQLite owns atomicity; there is no value cache or custom write queue. Never
  await native authorization within a database transaction.
- Shells provide `PersistenceScope`, `MasterKeyStore` and
  `PersistenceDirectory`: native I/O and a ready non-purgeable directory with
  platform backup policy applied. Normal storage contains no migration logic.

## Composition and cutover

Register lazy platform capabilities and scope, then call
`configurePersistenceDependencies(getIt: getIt)` before auth/core registration.
Database, APIs, cipher and repositories are lazy; graph reset closes the database.

Product shells are not switched yet. The active `desktop-master-key-storage`
plan adds deprecated mobile import and native capabilities before the coherent
consumer cutover. Existing auth's per-value interface remains live until then,
not as an alias or fallback inside this implementation.

## Verification

Run `dart test` and `dart analyze --fatal-infos` here. Fixtures use real temporary
SQLite files/in-memory databases but fake native keys, never personal credentials.
Generate Drift and DI with `dart run build_runner build`; never edit generated
output by hand. See [the regression contract](../../docs/regression/client-persistence.md).
