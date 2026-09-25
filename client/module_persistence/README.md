# Shared client persistence

Pure-Dart infrastructure below client auth/core, shared by mobile and desktop.
No dependency on Flutter or product/domain packages.

- Distinct `StringPersistenceKey`, `BoolPersistenceKey` and `SecretStorageKey`
  contracts prevent secrets from entering plaintext APIs.
- Domain packages own their enums, scoped identities and typed serialization.
  Spellings are explicit, not enum ordinals or `.name`.
- `StorageCipher` supplies per-row AES-256-GCM, authenticated scope/key identity,
  fresh nonces and privacy-safe failures retaining their original causes.
- `PersistenceScope` owns stable client database/master-item names. Its new
  native master namespace is separate from legacy per-value storage.
- Shells provide `MasterKeyStore` and `PersistenceDirectory`: native I/O and a
  ready persistent directory with appropriate backup policy, not encryption,
  caching or database lifetime. Native errors must not reset stored values.
- `PersisterRepository` maps typed keys through `PersisterApi`; defaults apply
  only to absence and failures propagate. It owns no value cache.

## Composition and cutover

Register lazy platform bindings and scope, then call
`configurePersistenceDependencies(getIt: getIt)` before auth/core registration.
Cipher and primitive registrations are lazy and perform no storage I/O.

The active `desktop-master-key-storage` plan moves the Drift backend and cached
secure repository into this package next, replacing the current raw
`PrimitiveStorage` delegation. Both apps then switch together; there will be no
mobile-native runtime alternative. The public-mobile import stays in a clearly
deprecated core module, never inside normal persistence APIs/repositories.

The foundation is still unwired in product shells: no new database or master
item is opened by this slice. Existing auth's per-value interface stays live
until the lockstep consumer cutover, not as an alias to new shared code.

## Verification

Run `dart test` and `dart analyze --fatal-infos` here. Generate DI with
`dart run build_runner build`; never edit generated output by hand.
