# Shared client persistence with Drift and typed keys

## Goal and user-approved direction

Use **one persistence implementation on mobile and desktop**: typed plaintext
preferences in Drift, individually encrypted secret rows, and one OS-protected
master key cached by the shared secret repository. Platform differences stop at
native key access, the persistent directory and its backup policy.

The original symptom is five or more macOS authorization dialogs on first run
after install/rebuild; unchanged relaunches do not prompt after Always Allow.
One native master item reduces per-value authorization fan-out. It does not
promise zero system dialogs or equate one plugin call with one OS dialog.

The user approved Drift + typed keys, then explicitly expanded the rollout to
both clients rather than retaining mobile's native-per-value backend. Parallel
persistence behavior is rejected as lasting technical debt and a source of
platform-only defects. Released mobile data must migrate in this work.

The user additionally requires migration code to be **clearly isolated and
explicitly deprecated from its first commit**, with a concrete deletion path.
It is temporary upgrade compatibility, never a second runtime persistence path.
The read-only wallet reference informed selective encryption/typed primitives;
its password UX, CBC fallback and unrelated application models are not adopted.

## Current behavior and compatibility boundary

- Both apps currently use per-value `FlutterSecureStorage` through auth's
  string-key `SecureStorage`. Desktop uses classic Keychain service
  `com.sesori.desktop`; mobile preserves its existing plugin options/keyspace.
- Auth owns token/user/OAuth serialization and mutation/logout fencing. Core owns
  relay keys, theme/input preferences, bridge/plugin preferences, device identity
  and account-scoped analytics preferences.
- Shared contracts/cipher/SQL/secrets merged in #1708/#1715/#1726/#1729/#1734
  and live in `module_persistence`, still unwired in apps. The old desktop
  checkpoint `4a27888` remains in closed/superseded #1717. The shared backend
  passes 46 tests; the isolated deprecated importer now passes 11 recovery tests.
  No app database/native credential cutover has occurred.
- Public mobile production releases create a real migration obligation: preserve
  credentials, room keys, preferences and pending analytics opt-out, not merely
  enough data to present a logged-in screen. Do not clear/re-key failed data.
- Desktop remains unpublished. Existing internal data does not create a migration
  obligation: sign out in the old desktop build before cutover, then sign in once.
  No desktop legacy reads, dual writes or automatic old-Keychain cleanup are added.
  Local logout in the new store does not revoke an old build's separate session.
- Mobile currently initializes analytics inside `configureDependencies`, after
  core registration. The migration gate must run before that initialization and
  before deep links, auth restoration or other persistence consumers resolve.
- Android's debug/profile applications have separate IDs. iOS debug/profile and
  release currently share `com.sesori.app`; development must not consume/delete
  the production legacy namespace. The deprecated mobile import is admitted for
  the production scope only. Debug/profile use fresh development databases.
- Android's manifest now excludes only the unused new database directory, not
  still-active credential preferences. Pinned `flutter_secure_storage` 11.2.0
  warns that restoring its preferences without Keystore keys can fail. #1726
  disabled destructive reset on the active adapter; new master/source adapters
  retain it. Native credential exclusions still wait for import/cutover.
- Desktop analytics remains disabled by `unsupportedPlatform`. This work does
  not activate it or add telemetry to migration.

## Scope

Included: iOS/Android mobile and macOS/Windows/Linux desktop; one shared Drift,
crypto and repository implementation; typed consumers; isolated deprecated
mobile import; native directory/key capabilities and mobile backup boundaries;
fixture qualification, failure presentation and affected regression documents.

Excluded: bridge/plugin/relay/server database changes; web storage; new user
preferences; unrelated caches/files/window state; SQLCipher; whole-database
ciphertext; private desktop migration; broader Keychain ACLs; unattended
passwords; key rotation/escrow; public distribution or touching real user state.

## Package and layer ownership

### Shared `client/module_persistence`

This pure-Dart package becomes the sole owner of the common implementation. It
must not depend on Flutter, auth, core or desktop-core. Move/rename the unwired
Desktop-prefixed components; do not retain aliases for unpublished code.

- **Foundation:** `PersistenceDatabase` and the three Drift tables;
  `PersistenceScope` (development/production); `StorageCipher`; typed
  `StorageException`/missing-key failure; `MasterKeyStore` and
  `PersistenceDirectory` platform capabilities; distinct string/bool/secret key
  contracts. `PersistenceDirectory.resolve()` returns a ready, non-purgeable
  directory with the platform's backup policy already applied.
- **API:** `PersisterApi` performs typed Drift primitive queries/upserts/deletes
  directly. Fold in the proposed `DesktopPrimitiveStorageApi` and delete the
  obsolete `PrimitiveStorage` delegation interface. `SecureStorageApi` owns raw
  ciphertext/native-master I/O and the encrypted-row presence query, not policy.
- **Repository:** `PersisterRepository` provides typed primitive operations and
  absence-only defaults. `SecureStorageRepository` owns encrypt/decrypt and one
  shared key initialization future. Replace the unused shared `SecureStorage`
  interface with this concrete repository; it has one production implementation.
- **DI:** `configurePersistenceDependencies({required GetIt getIt})` registers
  the database, APIs, cipher and repositories lazily, with database disposal.
  Scope, directory and native master-key access are shell-provided capabilities.
  Registration itself performs no I/O. Generate all Drift/Injectable output.
- Runtime dependencies include `cryptography`, matching `drift`/`drift_dev`
  versions and `sqlite3`; the builder disables unused Drift managers. Remove
  those dependencies from desktop-core when no live desktop owner needs them.

No whole-store map cache, custom file protocol, operation-tail queue, runtime
backend selector, mobile-native fallback, or migration dependency belongs in
normal persistence repositories/APIs.

### Auth/core ownership and public exports

Domain keys and value serialization remain with auth/core, not generic storage.
Both packages directly depend on `sesori_persistence` and consume its public
repositories. Their existing preference/service ownership and auth fencing stay
intact; no unrelated repository/service refactor is included.

`sesori_persistence.dart` is the defining public barrel for key contracts,
`PersisterRepository`, `SecureStorageRepository` and composition types. At the
consumer cutover, delete auth's old `src/platform/secure_storage.dart` and both
per-value native adapters. Auth/core directly re-export canonical shared types
where consumers need them; no duplicate interface, alias or legacy shim remains.
Core still re-exports auth functionality for shells. Shells import auth only for
its DI call, as required by `client/AGENTS.md`.

`module_core` owns the deprecated cross-domain importer because it already
consumes auth and knows the affected core key definitions. The persistence
module must not depend on that importer or know account/preference semantics.
Keep native legacy access and importer DI separate from permanent master-key
and database composition.

### Typed persisted-key inventory

- **A:** `module_auth/lib/src/models/auth_secret_key.dart` (auth's existing
  Layer-0 models directory) defines `AuthSecretKey implements SecretStorageKey`.
  Export that single enum from `sesori_auth.dart`; core migration imports the
  public barrel, never auth `src/` or a duplicate enum.
- **C:** `module_core/lib/src/foundation/persistence/persistence_keys.dart`
  defines `CoreSecretKey`, `StringPreferenceKey`, `BoolPreferenceKey`,
  `PluginPreferenceKey` and `ProductAnalyticsPreferenceKey`.

| Declaration / entry | Exact stable key | Value preserved during import | Shared table |
|---|---|---|---|
| A `accessToken` | `access_token` | Opaque token string | EncryptedValues |
| A `refreshToken` | `refresh_token` | Opaque token string | EncryptedValues |
| A `authUser` | `auth_user` | Existing `AuthUser` JSON | EncryptedValues |
| A `pkceVerifier` | `pkce_verifier` | Existing PKCE string | EncryptedValues |
| A `oauthProvider` | `oauth_provider` | Existing `AuthProvider.key` | EncryptedValues |
| A `oauthSessionToken` | `oauth_session_token` | Existing session token | EncryptedValues |
| A `oauthSessionExpiry` | `oauth_session_expiry` | Existing ISO-8601 string | EncryptedValues |
| C `relayRoomKey` | `relay_room_key` | Existing base64url key | EncryptedValues |
| C `appearanceMode` | `appearance_mode` | Existing enum storage value | StringValues |
| C `chatInputMode` | `chat_input_mode` | Existing enum storage value | StringValues |
| C `notificationDeviceId` | `notification_preferences_device_id_v1` | Existing UUID | StringValues |
| C `hasRegisteredBridges` | `has_registered_bridges` | Native `true`/`false` to bool; absent stays absent | BoolValues |
| C `PluginPreferenceKey(bridgeId: ...)` | `new_session_plugin_${Uri.encodeComponent(bridgeId)}` | Existing plugin ID | StringValues |
| C `ProductAnalyticsPreferenceKey(userId: ...)` | `product_analytics_preference_v1:$userId` | Version-1 JSON, including pending disable | StringValues |

Use explicit enum spellings, never `.name` or ordinals. Scoped keys require their
identity: preserve URI escaping for bridge IDs and unescaped analytics user IDs.
Secret keys cannot be passed to plaintext APIs; no caller-controlled encryption
boolean. Domain JSON remains byte-for-byte string content at import and is
parsed by its existing typed owner, not by migration. Do not infer missing
values from empty strings or add implicit defaults for present malformed data.

### Database and cryptography

Tables remain `StringValues(key, value)`, `BoolValues(key, value)` and
`EncryptedValues(key, ciphertext)`, with primary-key upserts/deletes and generated
row/companion types. No unused integer/double/JSON tables or account scope column.
Drift owns the background connection, WAL/transaction locking and disposal.

One typed scope provider feeds the database filename, native master-item name
and cipher associated data. The master item uses a new native namespace separate
from legacy per-value storage, so the temporary reader/cleanup never accesses it. Debug/profile use development; releases production.
Use generic client names, not Desktop names, for the newly unwired namespaces.
Each installed client has its own local database/key: shared implementation does
not imply cross-device file sharing or synchronization.

1. Normal primitive operations use only SQLite, even while a secret unlock is
   pending/denied. The one-time legacy import is an explicit startup exception
   because its source is native storage; it is not hidden in primitive reads.
2. Existing-secret reads and writes share one cached initialization future.
   Missing-row reads and deletes do not load the native master key.
3. Validate native base64 and 32-byte length. Generate a missing key only when no
   encrypted rows exist. Persist it before any ciphertext write. Denied/invalid
   initialization stays failed for that repository instance; relaunch retries.
4. AES-256-GCM uses a fresh 96-bit nonce, 128-bit tag and versioned envelope.
   Associated data authenticates a fixed Sesori client domain, version, scope
   and stable row key. No relay key/framing reuse or legacy cipher fallback.
5. Secret/master plaintext never enters SQL, WAL/journal files, logs or error
   presentation. Typed original causes/stacks remain available for diagnosis.
   Failed encryption/SQL writes preserve previously committed rows.
6. Missing values are null; wrong keys, malformed envelopes and I/O failures are
   errors, not empty values. Do not replace keys or clear ciphertext to recover.
7. Existing auth mutation/logout fencing owns late writes. Deletes target only
   the requested row. No additional app-wide lock, and no native authorization
   inside a database transaction.

## Deprecated mobile migration — isolated and removable

Put the entire cross-domain importer under
`module_core/lib/src/migrations/deprecated_native_storage_v1/`, mirroring layers:
`foundation/models/`, `foundation/keys/`, `foundation/platform/`, `api/`,
`repositories/`, `services/`, and a top-level README. The mobile raw legacy
adapter lives under `app/lib/core/platform/deprecated_native_storage_v1/`.
Matching tests use an explicitly deprecated migration directory. Its concrete
owners are `LegacyNativeStorage` (raw shell capability),
`LegacyNativeStorageMigrationApi`, `LegacyNativeStorageMigrationRepository`,
`LegacyNativeStorageMigrationService`, and typed sealed `LegacyPersistenceValue`
variants carrying their required key/value. A private `LegacyMigrationKey`
implements the bool-key contract for completion. Permanent repositories,
platform master-key adapters and database code do not import these types.

The startup entry point `LegacyNativeStorageMigrationService.migrate()` is
explicitly `@Deprecated`, with a dated
`COMPATIBILITY ... (v1.9.1)` marker at the retained declaration/call seam. The
README says **DEPRECATED / TEMPORARY** from the first commit. Any intentional
analyzer acknowledgement stays at the narrow startup/test usage, not a blanket
production suppression. Current product version comes from app/bridge pubspec,
not the library's version, and is refreshed if it changes before implementation.

Retirement condition: remove the importer when the supported direct-upgrade
baseline no longer includes publicly released per-value-native builds. Record
the last such production build at cutover; do not invent a future release number
or mistake internal tags for a public baseline. Finishing this plan does not by
itself make retained public upgrade compatibility safe to delete.

### Ownership and algorithm

- The temporary native-source capability enumerates/reads existing values and
  deletes named imported items in the old mobile keyspace. Disable Android
  `resetOnError`; preserve native algorithms, item names and access protection.
  For iOS enumeration, omit the accessibility query filter (`IOSOptions` with
  `accessibility: null`) while preserving the old account/group: the pinned
  Darwin plugin ignores errors in fallback queries, so filtering the primary
  query can hide legacy items. This is a non-mutating query change, not an ACL
  change. Validate real legacy-envelope reads and denial/error propagation;
  native failure must not become an empty snapshot.
- The migration API wraps that raw native capability. Its repository classifies
  the closed inventory and scoped prefixes into typed values. Unknown native
  items, including the new master item, are neither imported nor deleted.
- The migration service orchestrates that repository plus the public shared
  `PersisterRepository` and `SecureStorageRepository`. It runs once, awaited by
  bootstrap; normal repositories know nothing about legacy data.
- Read the private completion bool from Drift first. If complete, return without
  any legacy native access. A production first run without legacy values still
  marks completion. Development does not inspect the production legacy store.
- Read and classify the source before copying. Copy all present known values
  through the normal typed repositories, preserving serialized bytes and absent
  values. The secret repository persists/retains the sole master key normally.
- Each SQL write commits before proceeding. After **all copies succeed**, delete
  only the copied legacy items, then write the completion marker. This avoids
  leaving a second usable auth source after local logout, which currently does
  not revoke the remote session. Do not use `deleteAll`.
- No consumers run before completion. A copy failure leaves all native items
  intact. An interruption/cleanup failure can leave already committed SQL rows
  and only some native source items. On relaunch, merge remaining source entries
  into existing SQL rows; never clear/replace the destination snapshot or delete
  rows merely because a source item is now absent. A crash after cleanup but
  before the marker safely completes on the next run with the retained SQL data.
- This is idempotent restart recovery, not a resumable job framework: one final
  marker, no per-key progress records, native mirror, fallback reads, dual
  writes, timers or background retries. No SQL transaction spans native access.
- Failure preserves data and throws `LegacyStorageMigrationException` with its
  original cause/stack. In `app/lib/main.dart`, `bootstrapSesoriApp` catches that
  typed failure around `configureDependenciesFn`, logs it without payloads, and
  awaits an injected `disposeDependenciesFn` (production: `getIt.reset`). Log a
  cleanup failure separately without masking the migration failure or stopping
  rendering. Database disposal remains the registered shared GetIt disposer.
- The catch calls `runAppFn` with `PersistenceStartupFailureApp`, owned by
  `module_app_ui/lib/src/widgets/persistence_startup_failure_app.dart`, then
  returns before deep links/auth/analytics/theme reads. This stateless root uses
  ordinary shared localization/theme primitives, with no DI/service access.
  Copy is fixed and privacy-safe: the upgrade could not finish; close and reopen
  Sesori to retry. No raw exception text, reinstall/data-clear advice, automatic
  retry, process-termination API or in-process graph-restart controller. Closing
  via the OS and relaunching is the explicit action; migration remains pure Dart.

Deletion checklist in the migration README: remove the startup call, deprecated
folder/native source adapter, migration-specific DI/exports/models/tests and
obsolete regression statements; regenerate DI. Keep permanent directory backup
policy, key definitions, shared storage and its tests. An inert leftover marker
row does not justify a cleanup migration or permanent read path.

## Shell composition, backup and lifecycle

Both shells register native capabilities first, then configure persistence,
auth and core; desktop subsequently configures desktop-core. All module
registrations are lazy. A single scope supplies both native and database names.

| Phase | Mobile | Desktop |
|---|---|---|
| 1 | Existing `getIt.init(...)` plus lazy master-key/directory/scope and temporary legacy-source bindings | Existing platform/route/capability registration plus lazy master-key/directory/scope bindings |
| 2 | `configurePersistenceDependencies(getIt: getIt)` | Same shared entry point |
| 3 | Existing auth registration | Existing auth registration |
| 4 | Existing core registration | Existing core registration |
| 5 | Await deprecated production mobile migration, before consumer resolution | Existing desktop-core registration; retain primary-process admission before storage is opened |
| 6 | Existing analytics bootstrap/capability and thumbnail initialization, then deep links/auth/analytics/UI startup | Existing desktop startup and disabled analytics capability |

In `app/lib/core/di/injection.dart`, immediately after core registration and
before `createAnalyticsRuntimeBootstrap`, check the already registered
`getIt<PersistenceScope>() == PersistenceScope.production`. Only inside that
branch resolve `LegacyNativeStorageMigrationService` and await `migrate()`.
Development never resolves the importer/native source or calls enumeration or
cleanup. Test the guard with a legacy source that fails if even constructed.
The `bootstrapSesoriApp` typed catch/disposal/render path above owns presentation;
normal consumers never start on failure. Desktop's primary gate, helper
supervision and rendering sequence are not reordered by storage. Shell scope
values are explicitly registered before platform DI from `kReleaseMode` (release
production; debug/profile development): Injectable module providers reject enum
return types. Master/directory/source capabilities remain lazy.

With cutover PR 4.d, update the dependency diagram and phase/ownership guidance
in `client/AGENTS.md`, `desktop/AGENTS.md`, `module_auth/AGENTS.md` and
`module_core/AGENTS.md`, alongside actual exports and regenerated DI. Do not
leave the old 3/4-phase or auth-owned secure-storage descriptions in force.

Native adapters provide the protected master item and a persistent `persistence/`
subdirectory, not a cache/temp directory. Reuse desktop's existing application-
support resolver without moving unrelated desktop storage/log owners.

Backup policy follows native key portability rather than imposing one OS policy
on every client. Android excludes the complete persistence directory (including
WAL/SHM/journal) and old/new plugin credential preferences from cloud/device-
transfer backup using both supported XML formats, because Keystore keys do not
transfer with those files. Confirm exact filenames from the pinned plugin. PR
4.b may exclude only the unused new DB directory; exclusions for the still-active
old credential preferences wait for the migration/cutover in PR 4.d. Separately,
PR 3.b immediately disables `resetOnError` on the current mobile native instance,
so intermediate public builds cannot reset legacy values before import ships;
the later master-key and temporary source adapters must retain this safety.
iOS keeps its existing unlocked, non-synchronizable Keychain accessibility and
Application Support backup eligibility: qualify a paired encrypted backup/restore
of the database and master item instead of gratuitously disabling existing iOS
recovery or adding a backup-policy channel. No unrelated backup disablement.

Pinned-source inspection for cutover: `path_provider_android` 2.3.1 resolves
Application Support to Android `filesDir`. `flutter_secure_storage` 11.2.0 uses
these SharedPreferences names (on-disk `.xml` files): `FlutterSecureStorage`,
`FlutterSecureKeyStorage`, `FlutterSecureStorageConfiguration`,
`FlutterSecureStorageConfiguration:FlutterSecureStorage`,
`com.sesori.client.persistence`,
`FlutterSecureKeyStorage:com.sesori.client.persistence`, and
`FlutterSecureStorageConfiguration:com.sesori.client.persistence`. Apply those
credential/config exclusions in PR 4.d, not while old storage is active.

Ordinary updates retain data; Android new-device restore starts fresh. A copied
DB without a usable master must fail explicitly, never silently re-key. Test
these boundaries without claiming cross-device synchronization.

Register database disposal with GetIt. Drift owns the connection/isolate; no new
lifecycle controller, background flush loop or global file lock. Native fixture
seeding uses production Dart storage/schema code, not a copied Python/Swift DDL.
The existing authenticated macOS upgrade fixture seeds per-value credentials and
retains an old-format desktop baseline. Adapt both during required qualification
before using that fixture with the cutover; no desktop legacy migration is owed.

## Complexity, safeguards and cleanup

Persistent state: one scoped SQLite store, one OS master item, and one temporary
migration completion bool in the existing bool table. Runtime mutable state:
Drift's connection and the secret repository's single initialization future.
Migration holds a bounded transient source snapshot and executes sequentially
under the existing single startup sequence, without another coordinator.

- **Observed:** desktop authorization fan-out; replace per-value native accesses.
- **Ordinary:** overlapping auth/preferences writes; use SQL and existing auth
  ordering, not whole-map writes or another mutation lock.
- **Ordinary:** app termination, disk/native failures or device lock during an
  upgrade; preserve source/destination, retry on relaunch and gate consumers.
- **Ordinary:** Android backup restore without Keystore keys; targeted exclusions
  prevent an unusable copied database/native credential envelope.
- **Observed code boundary:** iOS build modes share a bundle ID; do not let a
  development import consume the production native namespace.
- **Accepted:** unlocked process memory and plaintext preferences/row IDs remain
  inspectable; OS signing can still require authorization; no escrow or guarantee
  against arbitrary hardware loss. New-device transfer is not a data-sync feature.

Causal cleanup belongs in the implementation: remove desktop-owned copies of the
shared backend, raw primitive delegation, the unused shared secure interface,
auth's old secure interface and both per-value runtime adapters. Keep only the
explicitly deprecated public-mobile import compatibility until its retirement
condition holds. Do not retain aliases, duplicate crypto or optional old APIs.

Update behavior-specific regression documents with each behavior-changing PR,
not only in the final documentation step. A new `client-persistence.md` owns the
shared contract; align account/onboarding, analytics, desktop packaging and
distribution documentation. No new analytics event is needed for this storage
implementation change; consent restoration must precede existing analytics.

## PR series and current delivery

Keep this worktree only, one open PR and at most one local successor. The stable
slug remains `desktop-master-key-storage`; the approved scope is now all native
clients. Current total: **12 PRs**. #1717 is closed as superseded, not merged.
Its published branch/review evidence stays intact; never force-push it to fake a
smaller history. Carry applicable feedback into shared-backend PRs 5/6.

The combined shared port measured 1,611 changed lines before final tracking.
Split at the existing ownership boundary: schema/direct primitives first,
cached secret repository second. Both compile independently without a temporary
adapter, schema, migration or app backend. SQL #1729, cached secrets #1734 and
deprecated importer #1739 and native capabilities #1744 merged.

The complete consumer cutover at `ea7550e` (base `064dcf8`) measures 1,650 lines:
1,545 authored and 105 generated. It passes 153 focused tests and five module/
shell analyses. Standalone recovery #1749 and atomic consumer cutover #1751
merged. No temporary backend or compatibility adapter bridged this split.
Regression reconciliation starts from fixed main `6056290`; required native
qualification still precedes plan retirement.

| Milestone | Exact PR title | Scope / expected result | Estimate |
|---|---|---|---|
| 1 | 🌿 [desktop-master-key-storage] Plan typed Drift desktop persistence [step 1/12] | #1698 merged; original reviewed plan. | Completed |
| 2 | ⚙️ [desktop-master-key-storage] Add typed client persistence contracts [step 2/12] | #1708 merged; unwired shared contracts. | Completed |
| 3.a | ⚙️ [desktop-master-key-storage] Add scoped desktop secret encryption [step 3/12] | #1715 merged; unwired cipher foundation. | Completed |
| 3.b | ⚙️ [desktop-master-key-storage] Share client storage foundations [step 4/12] | #1726 merged; shared cipher/capabilities and Android reset safety; no database cutover. | Completed: 1,260 lines including 13 generated |
| 3.c | ⚙️ [desktop-master-key-storage] Add shared Drift persistence [step 5/12] | #1729 merged; schema/direct primitives, lazy lifecycle and tests; no shell cutover. | Completed: 1,194 lines (517 authored, 621 generated, 56 lockfile) |
| 3.d | 🚧 [desktop-master-key-storage] Add cached shared secret storage [step 6/12] | #1734 merged; cached-key repository, encryption/recovery/concurrency tests and docs; no shell cutover. | Completed: 672 lines (655 authored, 17 generated) |
| 4.a | 🚧 [desktop-master-key-storage] Prepare deprecated mobile storage migration [step 7/12] | #1739 merged; domain keys and deprecated importer with recovery tests; not invoked yet. | Completed: 946 lines (773 authored, 173 generated) |
| 4.b | 🚧 [desktop-master-key-storage] Provide native client persistence capabilities [step 8/12] | #1744 merged; lazy master/directory/source ports and DB-only Android backup exclusion; no shell cutover. | Completed: 590 lines (565 authored, 25 generated) |
| 4.c | ⚙️ [desktop-master-key-storage] Prepare storage-upgrade recovery [step 9/12] | #1749 merged; localized recovery root and typed bootstrap catch/disposal; no storage cutover. | Completed: 280 lines (261 authored, 19 generated) |
| 4.d | 🚧 [desktop-master-key-storage] Switch both clients to shared persistence [step 10/12] | #1751 merged; coherent consumers/admission, backup rules and obsolete-adapter removal. Native qualification remains. | Completed: 1,634 lines (1,548 authored, 86 generated) |
| 5 | 🌿 [desktop-master-key-storage] Complete shared persistence regression documentation [step 11/12] | Reconcile storage, account, analytics and package contracts; distinguish automated proof from required native migration/restore/replacement evidence. No runtime/database change. | 100–250 authored |
| 6 | ⚙️ [desktop-master-key-storage] Qualify and retire shared client persistence [step 12/12] | Required full recorded matrix and bounded evidence; retire plan only on pass, not the still-required deprecated importer. | 100–250 authored |

Dependencies follow row order. Generated schema stays with source. No temporary
schemas, compatibility adapters or incomplete mobile cutover to manufacture a
split. Reassess the ~1,500 changed-line soft cap against the merge base before
each push; report authored/generated churn and explain generated-heavy overages.
Published series titles/totals are synchronized. The final
consumer switch is intentionally coherent so no released mobile data is read
from the new empty store before import is available.

## Verification and retirement

Highest required level: **L4 Extended** for shared persistence and migration,
through automated, native client and packaged boundaries. This is not the full
unrelated account/provider or plugin regression catalog.

| Gate | Required matrix | Proof |
|---|---|---|
| L1 | Shared module/core/auth focused suites | Typed keys/defaults; all 14 legacy entries and scoped keys; SQLite reopen; encrypted secret rows and no plaintext secret/master bytes in DB/WAL. |
| L2 | Both shell DI/bootstrap suites plus shared migration tests | Same repository/database implementation; no primitive unlock after migration; one cached native master load; unchanged auth fencing; pending opt-out imported before analytics/deep links/auth; no legacy calls after completion. |
| L3 mobile | Actual iOS and Android fixture builds | Native legacy-format seeding, real one-time import, restart/local auth restoration, exact preferences/opt-out, original item cleanup and new-format subsequent writes; actual SQLite/native assets. Test production scope and development isolation without using the real app/account. |
| L3 desktop | Developer ID macOS arm64 and native Windows/Linux fixtures | Packaged SQLite/native master roundtrip, reopen and new-format replacement; unchanged relaunch and same-identity macOS replacement preserve state. Observe actual authorization separately from adapter call counts. |
| L4 | Shared tests on macOS/Windows/Linux; iOS/Android adverse-state fixtures; macOS native denied-access fixture | Interrupted copy and cleanup, restart without resetting partial destination, failed final marker, key loss/denial/corruption, SQL rollback, tampered/swapped frames, failed migration blocks consumers and presents useful failure, DB disposal and plaintext independence. Verify paired iOS encrypted-backup/restore eligibility and behavior, Android cloud/device-transfer exclusions, and explicit failure for a copied DB without its master. |

Use existing-format native fixtures, not only values written by the new adapter.
Check native read completeness/error behavior on that boundary; an empty result
must not hide a failed import. Do not change plugin algorithms or broaden access
while translating data. Any required platform unavailable locally remains blocked
until isolated CI or an explicitly authorized device fixture supplies evidence.

Run relevant owning tests/analysis locally; CI owns the normal full matrix.
No live bridge/plugin/auth-server account is needed to prove the storage boundary.
No personal Keychain changes or running-app/helper launches are authorized.
Disposable local Keychain/authorization interaction needs explicit permission;
otherwise use isolated CI and the existing signed-fixture policy, never default
Keychain/search-list changes or passwords.

Record exact commits/builds/platforms, bounded commands/artifacts, cleanup, and
observed versus inferred results. Missing native/platform/restore gates keep the
plan active. Reduce this matrix only with explicit user acceptance. A unit test
or successful build is not native authorization, migration or distribution proof.

## Review record

- Initial plan review `2359dc5a-26c5-4e8a-a2d4-195b638c8e70` supplied repository,
  API, DI, scope and export findings. Its reporter failed after completion; the
  complete report was recovered before continuing.
- Revised desktop-only plan review `52fff904-c1da-49bd-9c99-f06e30d1d21f` found
  missing package/DI/export/key-inventory details. All were applied without a
  repeat approval. The recovered full report hash was
  `7e550c2e1629b4bffbb9af8c7dca6df17c621efb713590526173f8e79d876bfc`.
- #1698's behavior-documentation and pre-cutover old-session findings were
  addressed. Its then-late review was not represented as completed evidence.
- Shared-contract implementation review `240d3ac4-7970-4398-9917-2ee9b58e2a79`
  approved `origin/main..fc8b270` without findings.
- Cipher implementation review `dd2c7b27-5c57-4ab7-b051-7b915aa39be3` approved
  `3ffe4a1..634f109` without findings; #1715 merged with passing CI.
- Superseded desktop-backend review `94992f10-0bb1-4d18-8a90-9703e659e2e5`
  approved `ee30870..bd6e7a4`, backed by 20 focused tests and clean analysis.
  #1717's current-head Codex review completed without findings. Neither review
  approves the new shared/mobile migration design or proves native qualification.
- Shared-client review `96c6ea95-da0d-475e-8729-68a8f24d74b8` passed the pre-review
  gate and identified six concrete gaps: canonical auth key layer/export, backup
  rollout/reset safety, production admission, failure rendering/disposal, nested
  deprecated layers, and cutover guidance. Applied those findings directly.
  No repeat approval is requested or claimed; the review otherwise accepted the
  shared ownership, key cache, namespace separation and migration ordering.
- Shared-foundation implementation review `4d74e149-75fb-486c-919e-e5124b39a3a8`
  approved exact range `66db48e..f38a2f7` (all 24 paths) without findings. This is
  approval of the unwired shared foundation, not the future backend or migration.
- SQL implementation review `7ee56961-ed06-48a5-aa30-2cff50d8bbd5` approved exact
  range `af23da2..2e1309b` (all 20 paths) without findings. The cached-secret
  successor, native capabilities and consumer/migration cutover were excluded.
- Cached-secret implementation review `51bf34aa-9408-4082-ae7e-7ba5a3a55c39`
  approved exact range `0818f4b..bae788a` (all 13 paths) without findings. This
  does not approve native shell adapters, migration or future app cutover.
- Deprecated-importer implementation review `d885b123-0d8a-49db-982e-be35c37e0413`
  approved exact range `f1f00ee..3b8ac72` (all 25 paths) without findings. Native
  adapters and future consumer/bootstrap cutover remain outside that approval.
- Native-capability implementation review `12180381-83ef-42c8-9963-633f1e74f283`
  approved exact range `d07c69d..b234217` (all 26 paths) without findings. Consumer
  cutover, migration invocation and actual native qualification remain separate.
- Startup-recovery implementation review `324bf4c7-5bc4-4cfe-94b1-c56e5d52401e`
  approved exact range `064dcf8..683077f` (all 12 paths) without findings. The
  preserved consumer/import-admission successor and native qualification remain
  outside this approval.
- Consumer-cutover implementation review `554a1f9d-c952-4df8-8501-eb9595df2e64`
  approved exact range `33c7815..90b20bd` (all 54 paths) without findings. This
  approves architecture, not actual native migration, backup/restore or prompt
  behavior; required qualification remains.
