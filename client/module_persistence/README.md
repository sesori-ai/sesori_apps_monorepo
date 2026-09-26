# Shared client persistence

Pure-Dart infrastructure below client auth/core, shared by mobile and desktop.
No dependency on Flutter or product/domain packages.

- Distinct `StringPersistenceKey`, `BoolPersistenceKey` and `SecretStorageKey`
  contracts prevent secrets from entering plaintext APIs. Domain packages own
  explicit key spellings, scoped identities and typed serialization.
- `PersisterRepository` maps typed string/bool keys through `PersisterApi`
  directly into Drift. Defaults apply only to absence; failures propagate.
- `SecureStorageRepository` owns per-row AES-256-GCM and one cached master-key
  initialization future. Failed initialization stays failed for normal operations.
  Explicit startup-only `reset()` independently attempts ciphertext clearing and
  native-key replacement, retaining both errors. The cached future is replaced
  immediately and publishes its new key only after both operations succeed.
  Failed reset stays cached; successful key replacement also invalidates old
  ciphertext if deletion failed. Missing-row reads/deletes need no native key.
  `blockAccess(error:, stackTrace:)` synchronously replaces the cached future with
  an observed failure, without I/O, so an incomplete startup operation cannot
  admit new secret writes. Missing rows still return null; existing reads fail.
- `PersisterRepository.clearAndWriteBool` atomically replaces primitive tables
  with one typed bool. Its API owns the transaction; callers never supply SQL or
  transaction callbacks. A failed replacement rolls back both deletions.
- A missing master key is created only for a store without encrypted rows, and
  saved natively before ciphertext. Normal reads/writes never clear or re-key
  existing rows after key loss/corruption. Destructive reset is an explicit
  startup recovery operation, not an automatic repository fallback. `StorageCipher` authenticates scope/key identity with fresh
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

Both product shells use this implementation. Production mobile awaits the
isolated deprecated importer in core before consumers; development and desktop
never resolve it. There is no per-value runtime backend, alias or fallback.
Native migration, authorization and backup/restore qualification remain tracked
in the active `desktop-master-key-storage` plan.

## Verification

Run `dart test` and `dart analyze --fatal-infos` here. Fixtures use real temporary
SQLite files/in-memory databases but fake native keys, never personal credentials.
Generate Drift and DI with `dart run build_runner build`; never edit generated
output by hand. See [the regression contract](../../docs/regression/client-persistence.md).
