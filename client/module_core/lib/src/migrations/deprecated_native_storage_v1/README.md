# DEPRECATED / TEMPORARY — native-storage v1 import

This isolated importer exists only to preserve direct upgrades from publicly
released mobile builds that stored each value in `flutter_secure_storage`.
`LegacyNativeStorageMigrationService.migrate()` is deprecated from its first
commit; it is not a second storage backend or a supported normal-runtime API.
The declaration narrowly acknowledges `remove_deprecations_in_breaking_versions`:
this internal module's 0.x version does not retire public mobile upgrade support.
Same-package deprecation diagnostics are already disabled by workspace policy;
no new blanket suppression is added. Mobile startup narrowly acknowledges its
one deprecated call with the same dated retirement condition.

## Ownership and admission

- Foundation: raw legacy capability, sealed typed snapshot values, safe failure
  with retained cause/stack, and the internal completion key.
- API: native enumeration, named deletion and failed-import namespace clearing.
- Repository: classify known auth/core keys and scoped prefixes. Auth keys come
  from `sesori_auth`'s public `AuthSecretKey`, never a duplicate migration enum.
- Service: orchestrate the source repository and shared typed primitive/secret
  repositories. No persistent state except one final completion bool.

Production mobile resolves and awaits the service after shared/core registration
and before auth, analytics, preferences or other consumers. Bootstrap checks
`PersistenceScope.production` **before** resolving it: development must not
construct the legacy source. Desktop never invokes it. The mobile legacy adapter
remains inside its own deprecated folder; normal storage/native master adapters
never import migration types.

## Data and restart contract

1. Read completion first. Completed import performs no legacy native I/O.
2. Snapshot/classify known source entries before writing. Unknown native items
   stay untouched. Preserve opaque token/JSON/provider/date/base64 spellings,
   empty strings, absence, bridge/user identities and pending analytics opt-out.
   Only the known boolean is parsed, strictly; malformed data is not defaulted.
3. Copy through normal shared repositories, committing each write. No transaction
   spans native authorization.
4. Only after every copy succeeds, delete copied source entries individually,
   then commit completion. Successful import retains unknown entries.
5. Relaunch after interrupted cleanup/marker writes merges remaining native
   entries into committed rows. Missing source entries never delete destination
   data. No per-key progress records, fallback reads, mirrors, timers or retries.

## Failed-import recovery

The mobile shell installs its file sink before migration. Caught failures log
through `LegacyStorageMigrationException`, retaining native/SQL causes, operation
and original stacks (including both reset failures). Parser source buffers are
omitted, not their error messages/offsets. Before normal startup:

1. Independently attempt ciphertext clearing and protected-master replacement
   through `SecureStorageRepository.reset()`. Its replacement future retains both
   failures and stays cached. A saved replacement key also makes old ciphertext
   unusable on relaunch if SQL deletion failed; no new writes use it until both
   operations succeed.
2. Clear both primitive tables atomically through `PersisterRepository.clear()`.
3. If secret reset failed, stop recovery here: retain the remaining legacy source
   and leave import incomplete so a cold launch retries before trusting destination
   rows. Do not claim partial/unfenced reset was handled.
4. After successful secret reset, clear the old native namespace, including unknown
   entries. The new master uses a separate namespace. Then attempt completion even
   if preference/source cleanup failed, fencing surviving legacy auth when saved.

Each cleanup failure stays logged. Primitive clearing is attempted even when
secret reset failed; only source retirement/completion require its success.
Successful reset permits fresh login and follows normal account/server analytics
preferences; pending local-only opt-out may be lost, as explicitly accepted.
No alternate store, consent flag or blocking migration-specific UI is introduced.
Permanent native/SQL denial can still fail normal persistence operations; reset
is best effort, not a promise that unavailable storage has become writable.

## Native gates (not established by pure-Dart tests)

The mobile source adapter stays under its own deprecated folder. It
preserves the old namespace/algorithms/protection, disables Android `resetOnError`,
and uses the same iOS account/group without an accessibility filter for both
enumeration and named cleanup. Plugin-channel fixtures verify options and error
forwarding, not actual native completeness. Native/decryption failure must throw,
not look like an empty snapshot. Shell tests exercise production admission,
startup/reset ordering, pending disable and offline restoration through real
SQL/crypto with fake native sources. Actual iOS/Android released-format
enumeration, failure propagation and backup/restore still require qualification.
Android now excludes old/new credential preferences with the database subtree.

## Retirement condition

Remove only when supported direct upgrades exclude the **last publicly released
per-value-native mobile build**. The public baseline observed on 2026-09-25 is
**1.9.0 on both stores**: [Apple lookup](https://itunes.apple.com/lookup?bundleId=com.sesori.app&country=us)
reports an iOS release at `2026-09-25T02:28:01Z`;
[Google Play](https://play.google.com/store/apps/details?id=com.sesori.app&hl=en&gl=US)
reports Android 1.9.0 with public release-note commit `ffa5935`. Public listings do
not establish exact iOS build numbers or native upgrade qualification. Reconcile
any later per-value-native production release at rollout and before retirement.
Do not invent a retirement version, treat internal `1.9.1+1` as a public baseline,
or equate plan completion with permission to remove upgrade compatibility.

## Deletion checklist

- Remove the mobile startup admission/call that exists solely for this importer.
- Remove this entire deprecated directory and the mobile
  `core/platform/deprecated_native_storage_v1/` adapter directory.
- Remove migration-specific core/shell DI bindings, ignored dependency entries,
  exports, models and tests under `test/migrations/deprecated_native_storage_v1/`.
- Regenerate DI; remove obsolete regression assertions and instructions.
- Keep permanent shared storage, native master-key/directory backup policy,
  domain keys and their normal consumer tests. No runtime compatibility alias.
- An inert completion row may remain. Do not add a cleanup migration or permanent
  read path merely to delete it.
