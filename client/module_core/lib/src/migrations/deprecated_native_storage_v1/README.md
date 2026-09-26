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
- API: native enumeration and named deletion only.
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
   spans native authorization. A copy failure leaves **all** source items intact.
4. Only after every copy succeeds, delete copied source entries individually,
   then commit completion. Never `deleteAll`.
5. Relaunch after interrupted cleanup/marker writes merges remaining native
   entries into committed rows. Missing source entries never delete destination
   data. No per-key progress records, fallback reads, mirrors, timers or retries.

A failure retains its original typed cause and stack in
`LegacyStorageMigrationException`, with payload-free presentation and the failed
operation. Bootstrap awaits disposal of its partial graph and renders the fixed
upgrade failure root instead of starting normal consumers. It logs disposal
failure separately and still renders recovery. OS close/relaunch retries;
clearing app data, replacing keys and automatic re-entry are not recovery paths.

## Native gates (not established by pure-Dart tests)

The mobile source adapter stays under its own deprecated folder. It
preserves the old namespace/algorithms/protection, disables Android `resetOnError`,
and uses the same iOS account/group without an accessibility filter for both
enumeration and named cleanup. Plugin-channel fixtures verify options and error
forwarding, not actual native completeness. Native/decryption failure must throw,
not look like an empty snapshot. Shell tests exercise production admission,
startup ordering/disposal, pending disable and offline restoration through real
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

- Remove the mobile startup admission/call and migration-failure presentation
  seam that exists solely for this importer.
- Remove this entire deprecated directory and the mobile
  `core/platform/deprecated_native_storage_v1/` adapter directory.
- Remove migration-specific core/shell DI bindings, ignored dependency entries,
  exports, models and tests under `test/migrations/deprecated_native_storage_v1/`.
- Regenerate DI; remove obsolete regression assertions and instructions.
- Keep permanent shared storage, native master-key/directory backup policy,
  domain keys and their normal consumer tests. No runtime compatibility alias.
- An inert completion row may remain. Do not add a cleanup migration or permanent
  read path merely to delete it.
