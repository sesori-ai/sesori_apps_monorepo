# Desktop master-key storage with Drift and typed keys

## Goal and user-approved direction

Eliminate desktop's per-value OS credential-store access: keep one cached master
key in the native credential backend, encrypt secret values before storing them
in Drift, and persist ordinary preferences as typed plaintext primitives.

The user reports five or more authorization dialogs on first run after install
or rebuild, including a Developer ID-signed macOS app. After Always Allow,
reopening the unchanged app does not prompt. Item names were not recorded, so
per-item authorization is consistent with the report, not an observed exact
item-to-dialog mapping. Success means one master-key item consulted once per
process when secrets are needed; it does not promise zero system dialogs.

The user explicitly approved **Drift + typed keys**, including affected shared
storage consumers. This supersedes the initial whole-map encrypted-file plan.
The read-only wallet reference demonstrated typed primitive tables, enum-keyed
`PersisterRepository` access, and encryption of sensitive values before database
insertion. Its legacy migrations, CBC fallback, password UX, and application
models are not part of Sesori's implementation.

## Current behavior and compatibility boundary

- Desktop's `DesktopSecureStorageAdapter` delegates every value to
  FlutterSecureStorage. `register_module.dart` uses the classic macOS Keychain
  service `com.sesori.desktop`; development and release currently share it.
- Auth stores access/refresh tokens, account data, and transient OAuth state.
  Core stores the relay room key and ordinary preferences through the same
  string-key `SecureStorage` interface.
- Ordinary consumers are `AppearanceStore`, `ChatInputModeStore`,
  `RegisteredBridgesStore`, `PluginPreferenceApi`,
  `NotificationPreferencesDeviceIdStorage`, and
  `ProductAnalyticsPreferenceStorage`. The last two scoped preferences use
  bridge/account identities in their key; preserve those scopes explicitly.
- Client packages currently have no Drift database or SQLite dependency.
  `module_desktop_core` owns desktop persistence/business logic and the existing
  `DesktopApplicationSupportDirectory` capability. The desktop primary-process
  gate runs before preferences/authentication are read.
- Mobile is publicly released. Its native item names, string/bool encoding,
  account/OAuth state, room key, and pending analytics preferences must remain
  readable and writable unchanged. Typed internal APIs update in lockstep; the
  mobile backend remains its current native store, without a new database or
  data migration.
- Desktop packages remain private/unpublished in the distribution documentation;
  public `v1.9.0` assets contain only bridge archives/checksums. Desktop-local
  legacy data does not create a compatibility obligation. New desktop storage
  starts empty and requires sign-in once. No old-item reads, migration, dual
  writes, or automatic Keychain cleanup will be introduced.
- Before switching a development installation, sign out in its existing build.
  That clears its old auth items using their current owner. Returning to an older
  internal build can otherwise restore that build's separate prior session;
  logging out of the new store must not be advertised as revoking other stored
  sessions. No automatic legacy authorization burst is added to this feature.
- Desktop analytics is explicitly disabled with `unsupportedPlatform` by shell
  DI. Do not introduce a desktop analytics-state migration for an activation path
  the current desktop runtime cannot execute. Preserve mobile pending-disable
  state byte-for-byte through the unchanged native backend and test that path.

## Scope

Included: macOS, Windows and Linux desktop; shared typed persistence contracts
and consumer updates; unchanged mobile storage via typed adapters; one desktop
SQLite database/master-key pair per development or production scope; secret
integrity and failure safety; package fixtures, focused tests and regression docs.

Excluded: bridge/plugin/relay/database-server changes; a Drift rollout on mobile;
new preference features; unrelated window/sidebar/file migrations; SQLCipher;
whole-database encryption; legacy desktop migration; wallet-specific code;
certificate provisioning; broader Keychain ACLs; unattended passwords; key
rotation/escrow; native password prompts replaced with custom UI; publication.

## Package and layer ownership

### Shared typed persistence module

Add a small pure-Dart `client/module_persistence` package below `module_auth` and
`module_core`. It is shared infrastructure, not a new feature/service owner.
This avoids placing generic persistence in auth or making core depend on desktop.

- `foundation/keys/`: distinct `StringPersistenceKey`, `BoolPersistenceKey`, and
  `SecretStorageKey` contracts. Each exposes a stable storage spelling. Secret
  keys are not subtypes of plaintext keys: ordinary write APIs cannot accept
  them, and callers never pass an `encrypted: true/false` flag.
- Closed key sets are enums in the owning auth/core package with explicit stable
  spellings, not implicit enum ordinals or rename-sensitive generated strings.
  Dynamic account/bridge keys use small immutable keyed values with their
  required identity fields; no nullable coordination fields or empty scope
  sentinels. They preserve existing mobile prefix/escaping rules.
- `foundation/platform/primitive_storage.dart`: raw string/bool read, write and
  delete operations. `foundation/platform/secure_storage.dart`: the existing
  secure-storage role, now accepting `SecretStorageKey` instead of raw strings.
- `api/persister_api.dart`: immutable raw primitive-storage delegation boundary.
- `repositories/persister_repository.dart`: typed primitive read/write/delete
  entry point over that API, including explicit defaults where a caller needs
  them. Do not turn null/malformed data into an empty-string sentinel.
- Public barrel and generated DI export/register the shared collaborators.
  The module owns no Flutter imports, native database, master key, domain
  settings state, or duplicate preference cache.

Existing auth/core storage classes retain their domain serialization and state
semantics and consume this lower-level library's public contracts. Do not create
same-package chains of feature repositories or move unrelated UI/state owners.

### Workspace graph and sole public owners

- Add `module_persistence` to `client/pubspec.yaml` and create
  `client/module_persistence/pubspec.yaml` with name `sesori_persistence`,
  `publish_to: none`, `resolution: workspace`, and the pinned Dart SDK constraint.
  Runtime dependencies are only the required Dart DI/metadata libraries; tests
  and generators are development dependencies. No Flutter, auth, core,
  desktop-core, Drift, or reverse product dependency belongs in this module.
- Add direct `../module_persistence` path dependencies in
  `client/module_auth/pubspec.yaml`, `client/module_core/pubspec.yaml`,
  `client/module_desktop_core/pubspec.yaml`, `client/app/pubspec.yaml`, and
  `client/desktop/pubspec.yaml`. Both shells directly import its DI entrypoint.
  Desktop core alone gains direct Drift/SQLite/cryptography dependencies.
- `client/module_persistence/lib/sesori_persistence.dart` is the sole defining
  public barrel for `PrimitiveStorage`, `SecureStorage`, `StringPersistenceKey`,
  `BoolPersistenceKey`, `SecretStorageKey`, and `PersisterRepository`.
- Delete `client/module_auth/lib/src/platform/secure_storage.dart` at cutover.
  Update all imports of that declaration. In `client/module_auth/lib/sesori_auth.dart`,
  replace its local export with a direct re-export of the exact
  `sesori_persistence` `SecureStorage` and `SecretStorageKey` declarations.
- In `client/module_core/lib/sesori_dart_core.dart`, remove `SecureStorage` from
  the auth `show` list and directly re-export the canonical persistence types and
  repository from `sesori_persistence`. These exports denote identical types;
  no second interface, typedef alias, delegating shim, or legacy source file remains.
  Auth/core implementation files import the lower package rather than reaching
  across its `src` boundary. Core also exports its own public preference/key types.
- Export desktop database/API/repository, scope, cipher and native-key capability
  from `client/module_desktop_core/lib/sesori_desktop_core.dart` wherever shell
  composition needs them. Register the new package in existing package discovery,
  CI and code-generation configuration wherever those lists are explicit.

### Typed persisted-key inventory

Declarations:

- **A:** `client/module_auth/lib/src/storage/auth_secret_key.dart` defines
  `AuthSecretKey implements SecretStorageKey`.
- **C:** `client/module_core/lib/src/foundation/persistence/persistence_keys.dart`
  defines `CoreSecretKey`, `StringPreferenceKey`, `BoolPreferenceKey`, and the
  immutable `PluginPreferenceKey` / `ProductAnalyticsPreferenceKey` values.
  Enums implement the corresponding distinct key contract. Scoped values
  implement `StringPersistenceKey` and require their bridge/account identity.

| Declaration / entry | Exact stable storage key | Value retained on mobile | Desktop table |
|---|---|---|---|
| A `AuthSecretKey.accessToken` | `access_token` | Opaque token string | EncryptedValues |
| A `AuthSecretKey.refreshToken` | `refresh_token` | Opaque token string | EncryptedValues |
| A `AuthSecretKey.authUser` | `auth_user` | Existing `AuthUser` JSON | EncryptedValues |
| A `AuthSecretKey.pkceVerifier` | `pkce_verifier` | Existing PKCE string | EncryptedValues |
| A `AuthSecretKey.oauthProvider` | `oauth_provider` | Existing `AuthProvider.key` | EncryptedValues |
| A `AuthSecretKey.oauthSessionToken` | `oauth_session_token` | Existing session token string | EncryptedValues |
| A `AuthSecretKey.oauthSessionExpiry` | `oauth_session_expiry` | Existing ISO-8601 string | EncryptedValues |
| C `CoreSecretKey.relayRoomKey` | `relay_room_key` | Existing base64url key encoding | EncryptedValues |
| C `StringPreferenceKey.appearanceMode` | `appearance_mode` | Existing `AppearanceMode.storageValue` | StringValues |
| C `StringPreferenceKey.chatInputMode` | `chat_input_mode` | Existing `ChatInputMode.storageValue` | StringValues |
| C `StringPreferenceKey.notificationDeviceId` | `notification_preferences_device_id_v1` | Existing UUID string | StringValues |
| C `BoolPreferenceKey.hasRegisteredBridges` | `has_registered_bridges` | Literal `true` for the positive latch; delete on clear | BoolValues |
| C `PluginPreferenceKey(bridgeId: ...)` | `new_session_plugin_${Uri.encodeComponent(bridgeId)}` | Existing plugin ID string | StringValues |
| C `ProductAnalyticsPreferenceKey(userId: ...)` | `product_analytics_preference_v1:$userId` | Existing version-1 typed preference JSON, including pending disable | StringValues |

These spellings are explicit key-definition values, not `.name` or ordinal
serialization. Plugin IDs retain `Uri.encodeComponent` on the bridge identity;
analytics keys retain the unescaped existing user ID. The native mobile adapter
uses these exact strings and its existing FlutterSecureStorage options; it adds
no prefix or new account/service name. Its bool encoding is `true`/`false`, not
SQLite's integer representation; the current bridge-latch consumer writes only
true and deletes when clearing. Null still means absence. Scoped identities are
required constructor data, not an optional scope column or empty-string sentinel.

The only sensitivity reclassification is ordinary core preferences moving to
plaintext desktop primitive tables. All existing auth values and the relay key
remain secret-typed. Tests pin every inventory entry, both scoped-key encodings,
existing serialized values, mobile clear behavior and pending-disable restoration.

### Desktop persistence

- **Foundation:** `DesktopPersistenceDatabase` under
  `module_desktop_core/lib/src/foundation/persistence/` owns the Drift connection
  and schema. `DesktopStorageScope` is the development/production enum.
  `DesktopStorageCipher` owns AES-256-GCM envelope encoding and authenticated row
  identity. `DesktopMasterKeyStore` is the narrow OS key read/write capability.
  Privacy-safe typed errors retain original causes.
- **Tables:** `StringValues(key TEXT PRIMARY KEY, value TEXT)`,
  `BoolValues(key TEXT PRIMARY KEY, value BOOLEAN)`, and
  `EncryptedValues(key TEXT PRIMARY KEY, ciphertext BLOB)`. Use generated Drift
  row/companion types and `WITHOUT ROWID` where supported. Only primitives with
  current consumers are included; no unused int/double/JSON tables. Existing
  typed JSON models serialize into string values at their domain owner.
- **APIs:** `DesktopPrimitiveStorageApi` implements the raw primitive capability
  through typed Drift queries/upserts/deletes. `DesktopSecureStorageApi` performs
  only raw encrypted-row/native-key I/O, including an encrypted-row presence
  query; it carries no unlock policy or application state machine.
- **Repository:** `DesktopSecureStorageRepository` implements the typed
  `SecureStorage` contract. It owns one shared master-key initialization future
  and encrypt/decrypt-before/after-row-I/O policy. There is no whole-store map,
  replacement-file protocol, extra operation-tail queue, or value cache.
- **Concurrency:** SQLite owns statement/transaction atomicity and database
  locking. Separate-key mutations cannot overwrite one another's snapshots.
  Auth's existing mutation owner and logout fencing remain authoritative; do not
  invent another app-wide lock or promise atomic multi-item native-mobile writes.
  Never hold a database transaction open while awaiting OS authorization.

### Shell, DI and lifecycle

Create `client/module_persistence/lib/src/di/injection.dart` with the public
`configurePersistenceDependencies({required GetIt getIt})` entrypoint, exported
by `sesori_persistence.dart`. Its generated bindings register `PersisterApi` and
`PersisterRepository`; `PrimitiveStorage` is a shell-provided ignored external
registration, not a second implementation registered by the module.

Update the exact bootstrap call sites as follows:

| Phase | `client/app/lib/core/di/injection.dart` | `client/desktop/lib/core/di/injection.dart` |
|---|---|---|
| 1 | Existing `getIt.init(...)` environment selection plus lazy platform capability bindings | Existing `getIt.init()` plus lazy platform capability bindings and one scope provider |
| 2 | `configurePersistenceDependencies(getIt: getIt)` | `configurePersistenceDependencies(getIt: getIt)` |
| 3 | Existing `configureAuthDependencies(getIt)` | Existing `configureAuthDependencies(getIt)` |
| 4 | Existing `configureCoreDependencies(getIt)` | Existing `configureCoreDependencies(getIt)` |
| 5 | Not applicable | Existing `configureDesktopCoreDependencies(getIt)` |

Mobile's analytics crawl-gate/bootstrap/capability initialization remains after
phase 4, preserving its current ordering before consumer resolution. Desktop's
existing shell capability/route registrations retain their ordering. No domain
or persistence consumer is resolved during the preceding configuration phases.
Update phase comments and affected scoped instruction diagrams with the code.

- Mobile supplies a dumb primitive adapter over its existing
  FlutterSecureStorage instance and updates its secure adapter for typed keys.
  Preserve exact legacy native item names and true/false encoding, so released
  mobile data needs neither copying nor dual reads. This backend intentionally
  remains unchanged; desktop is the platform receiving new persistence.
- Desktop phase 1 binds raw primitive storage lazily to
  `DesktopPrimitiveStorageApi` and secure storage lazily to
  `DesktopSecureStorageRepository`; phase 5 registers those concrete core-owned
  implementations. Remove the old arbitrary-value native desktop adapter.
- Desktop's `FlutterDesktopMasterKeyStore` only reads/writes the one native key.
  One typed scope provider in desktop `register_module.dart` feeds the native
  adapter and the database/secret owner. Debug/profile use development;
  packaged releases use production. Do not derive scope independently elsewhere.
  Add `DesktopStorageScope` and `DesktopMasterKeyStore` to the ignored
  shell-provided types in `client/module_desktop_core/lib/src/di/injection.dart`;
  retain its existing ignored external types. Generate its phase-5
  database/API/cipher/repository bindings from annotated source.
- Use the existing desktop application-support resolver. Each scope gets its own
  database path and master-key namespace. Native SQLite loading/packaging is
  verified on all three desktop OSes; mobile does not acquire a SQLite runtime.
- Register database disposal with GetIt so reset/shutdown of the owning graph
  closes the connection. Drift owns its connection/isolate lifecycle; add no
  separate database lifecycle state machine. Export every shell-facing contract
  through public package barrels and regenerate DI/schema output from sources.

## Encryption and failure contract

1. Plain string/bool operations access only SQLite. Theme/input preference reads
   must work while Keychain access is denied or an unlock remains pending.
2. The first secret write or existing-row read shares one initialization future
   with concurrent callers. Missing-row reads return null without native access.
   Read the scope's native master item once, validate its base64 encoding
   and 32-byte length, then retain the usable key in memory for this process.
3. If no key exists, generate one only when there are **no encrypted rows**.
   A database containing only plaintext preferences is a valid fresh-secret
   store. Existing encrypted rows without a key are an explicit failure, not
   grounds to create a replacement key or clear rows.
4. Persist a newly generated key before writing ciphertext. Denied/failed/invalid
   key initialization remains failed for that instance; relaunch retries. Do not
   turn one denied unlock into an automatic prompt per caller.
5. Encrypt each secret independently with AES-256-GCM, a fresh random 96-bit
   nonce and 128-bit tag. Store a versioned binary envelope in the blob column.
   Authenticate a fixed Sesori domain, format version, storage scope and stable
   row key as associated data, so ciphertext cannot be swapped between keys.
   Never reuse relay keys/framing or add a legacy cipher fallback.
6. Only ciphertext reaches Drift for secret rows. Plaintext secrets and master
   keys must not appear in SQL parameters, logs, SQLite/WAL/journal files,
   fixtures, screenshots or exception presentations. Typed inner causes remain
   available without rendering payload-bearing parser source text.
7. Missing secret rows return null. Authentication/tag failures, unknown/truncated
   envelopes, invalid keys and I/O failures remain errors, never empty values.
   Failed encryption or SQL writes do not destroy the previously committed row.
8. Deleting a secret row needs no decryption or native key access. Logout deletes
   the requested auth values, not the master key, preferences or another account's
   scoped records. Preserve existing auth refresh and late-write fencing.

### Complexity and safeguard budget

Durable state: one scoped SQLite database (plus SQLite-owned journal/WAL files)
and one scoped OS-protected master item. In-memory mutable state beyond Drift's
connection: one initialization future in the secret repository. No map cache,
custom write queue, timers, watchers, registries, or cross-process lock.

- **Observed:** many first-run authorizations. One protected key reduces fan-out.
- **Ordinary flow:** overlapping preference/auth writes. SQL statements and
  existing domain ordering avoid whole-store lost updates.
- **Ordinary flow:** denied/unavailable key, restored database without its key,
  or invalid encrypted data. Fail without replacing keys/records.
- **Ordinary flow:** interrupted/disk-error writes. SQLite's transaction boundary
  owns durability; test rollback/failure rather than custom rename choreography.
- **Accepted:** a compromised running user/app can inspect unlocked memory;
  keys remain cached until exit; plaintext preferences and row identifiers are
  visible in the database; ad-hoc rebuilds may still need one authorization.
  The existing primary-desktop gate owns process admission. No guarantee against
  every hardware failure, and no invented recovery escrow or SQLCipher layer.

## Compatibility, cleanup and review findings

- Remove the uncommitted encrypted-file prototype, its write queue, file format
  documentation and exports. It never became a production or migration baseline.
- Remove per-value desktop native persistence and update all directly superseded
  fixtures. `packaged_platform_probe.dart` must use actual production persistence.
  The authenticated-upgrade fixture must seed the new database through production
  Dart storage/schema code and use the same-team Swift helper only for the one
  native master item. Do not duplicate Drift schema/migrations in Python/Swift.
  Credential data remains private/stdin-only; no real user state is touched.
- Old private packages are not upgrade baselines. Signed replacement qualification
  uses two new-format builds. Prior fixture results do not prove the new format.
- Update affected behavior/fixture regression statements in the implementation
  PR that switches behavior. The penultimate PR reconciles/completes the whole
  feature document and related distribution evidence, not stale interim claims.
- Do not add a retirement/migration path solely for unpublished desktop auth
  items. Explicit pre-cutover sign-out instructions address old internal sessions
  without adding legacy storage access to the new app.
- Preserve mobile pending analytics opt-out values and account scopes through
  exact native key/encoding stability. Desktop capability remains disabled;
  this change must not enable analytics or add an unsupported activation path.

## PR series

Keep the supplied worktree only, one open PR and at most one local successor.
Series total is **7**. The original Step 3 is split into independently compiling
**3.a** and **3.b** after its implementation measured about 1,700 changed lines
(about 1,040 authored and 667 generated). The cipher/scope boundary is a clean
extraction: no temporary API, schema, migration or compatibility code is needed.
Completed PR links/history are retained; their GitHub titles use the current
series total. Milestone IDs below remain stable; PR ordinals are explicit in titles.
Changed-line estimates include tests/docs; report generated churn separately and
reassess before each push against the 1,500-line soft cap.

| Milestone | Exact PR title | Scope / expected result | Estimate |
|---|---|---|---|
| 1 | 🌿 [desktop-master-key-storage] Plan typed Drift desktop persistence [step 1/7] | Reviewed revised plan/tracker. No runtime, user-visible or database change. | 450–750 total changed lines against main |
| 2 | ⚙️ [desktop-master-key-storage] Add typed client persistence contracts [step 2/7] | Shared pure-Dart key contracts, primitive API/repository, focused tests and public exports. Not wired yet; existing app behavior and data unchanged. | 450–800 authored |
| 3.a | ⚙️ [desktop-master-key-storage] Add scoped desktop secret encryption [step 3/7] | Stable scope, per-row AES-GCM envelope, privacy-safe typed failures and focused cipher tests. No native item or database access yet. | 250–400 authored plus small generated DI |
| 3.b | 🚧 [desktop-master-key-storage] Add encrypted Drift desktop storage [step 4/7] | Three typed tables, raw APIs, scoped database, native-key capability and cached-key repository plus tests. Not bound in shell DI yet. | 700–850 authored plus about 650 generated |
| 4 | 🚧 [desktop-master-key-storage] Integrate typed desktop and mobile persistence [step 5/7] | Enum-keyed consumers, exact-compatible mobile adapters, desktop master-key/Drift DI, native fixtures, and changed-behavior docs. Desktop adopts SQLite; mobile physical storage stays unchanged; no server database/wire change. | 1,000–1,450 authored plus generated DI; split if a clean boundary emerges |
| 5 | 🌿 [desktop-master-key-storage] Complete persistence regression documentation [step 6/7] | Reconcile feature matrix and affected distribution/support docs/evidence. No additional runtime/database change. | 100–250 authored |
| 6 | ⚙️ [desktop-master-key-storage] Qualify and retire typed desktop persistence [step 7/7] | Run required matrix, record bounded evidence, retire only after pass. No extra runtime/database change. | 100–250 authored |

Dependencies follow row order. Step 3.b generated output stays with its schema,
with authored/generated totals explicit. Do not split tables into fake
intermediate schemas or add temporary mobile/desktop compatibility adapters only
to manufacture a PR boundary. Architecture review covers the revised plan and
architecture-bearing production diffs; documentation/tooling-only edits do not
need architecture reviewers.

## Verification and retirement

Highest level: **L4 Extended for desktop credential storage**, including the
specified native/package gates. This is not the unrelated full account/provider,
plugin or desktop-distribution catalog. Add
`docs/regression/desktop-credential-storage.md` and align account/onboarding,
macOS packaging, distribution, and affected analytics statements.

| Gate | Boundary / matrix | Required proof |
|---|---|---|
| L1 | Automated; shared persistence and desktop owning tests | Typed primitive roundtrip/default/absent semantics, enum storage spellings, secret roundtrip across repository/database reopen, per-row ciphertext and no plaintext secret bytes. |
| L2 | Automated; desktop + mobile adapter/DI and affected auth/core tests | Preference reads never unlock; one master load shared by concurrent secret callers; no repeated native calls during refresh/logout; development/release separation; mobile existing keys/encodings and pending analytics-disable state remain intact. |
| L3 | Packaged/native; Developer ID macOS arm64 plus Windows/Linux native fixture | Actual Flutter/platform composition, SQLite asset loading and persistence. macOS cold launch, unchanged relaunch and same-identity new-format replacement preserve values and consult only the master item. Observe authorization separately from adapter operation counts. Windows/Linux open/query/reopen the packaged SQLite store with a native credential roundtrip. Dummy values only. |
| L4 | Automated on macOS/Linux/Windows; macOS native denied-access fixture | Concurrent independent-key updates/deletes, SQL failure/rollback preserving rows, wrong/missing/denied keys, plaintext-only DB key creation, swapped/tampered/truncated/unknown secret envelopes, private error presentation, database disposal, and unaffected plaintext preferences while secret unlock fails/pends. |

Locally run focused owning-package tests and analysis, plus affected shared
consumer tests; CI owns the normal full matrix. Add focused missing OS-native
checks rather than duplicating unrelated CI. No backend plugin, mobile simulator,
auth-server account or live bridge is required for this persistence boundary;
mobile's unchanged physical format is proved through its adapter and real
existing-format fixtures without migrating any user account.

Native checks use isolated fixture state, never the user's running app/helper or
real credentials. Modern macOS Keychain partition behavior must be represented;
an arbitrary scratch-directory Keychain is not proof. Creating a disposable
local Keychain or interacting with authorization needs explicit permission;
otherwise use isolated CI. Never change the user's default/search-list settings.

Record exact commits/builds, platforms, bounded commands/artifacts, observed
versus inferred results, and cleanup. Keep the plan active for failed/partial/
blocked/unexecuted required gates. A reduced matrix requires explicit user
acceptance recorded here. No unit test alone establishes native dialog counts,
signed updates, OS credential behavior or public release readiness.

## Review record

- Initial file plan review `2359dc5a-26c5-4e8a-a2d4-195b638c8e70` rejected API-owned
  coordination, late interface registration, unspecified shared scope and missing
  public exports. Those findings informed this plan's repository/API/DI boundaries.
- Its workflow reporter failed on an undefined optional result field after the
  review completed. Full report was recovered; no implementation child ran.
- User then approved Drift + typed keys. This is a material architecture change;
  a revised-plan review is required, not a claimed approval of the prior plan.
- PR #1698 initial automated findings: accepted updating behavior docs at cutover;
  documented pre-cutover sign-out and the independent old-internal-session limit
  instead of adding unpublished-peer retirement code. The proposed desktop
  analytics activation is blocked by its runtime capability; the newly affected
  public-mobile path explicitly retains pending opt-out records unchanged.
- Revised-plan review `52fff904-c1da-49bd-9c99-f06e30d1d21f` rejected four missing
  details: package/dependency graph, exact DI calls, canonical contract exports,
  and the persisted-key inventory. Added all four above. This was a concrete
  review, not a failed pre-review vagueness gate; corrections are applied without
  another review and no revised approval is claimed.
- The second report's full 5,759-character tool-write content was recovered from
  its session source after a short final acknowledgement replaced the saved
  output. Recovery source/hash are retained in private local artifacts.
- Step 2 implementation review `240d3ac4-7970-4398-9917-2ee9b58e2a79` approved
  the unwired shared-persistence slice (`origin/main..fc8b270`) with no findings.
- Step 3.a implementation review `dd2c7b27-5c57-4ab7-b051-7b915aa39be3` approved
  the exact `3ffe4a1..634f109` cipher/scope slice with no findings.
- Step 3.b implementation review `94992f10-0bb1-4d18-8a90-9703e659e2e5` approved
  the exact `ee30870..bd6e7a4` backend slice with no findings. Integration review
  and packaged/native credential qualification remain future gates.
