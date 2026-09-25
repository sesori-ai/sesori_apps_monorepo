# Client Persistence

## Capability

Shared pure-Dart typed preferences and individually encrypted secrets backed by
Drift. The backend is currently available to composition/fixtures; product
shells still use their existing native-per-value storage until migration and
cutover land. An isolated, explicitly deprecated mobile importer is also available
for composition/fixtures, but neither shell invokes it yet. No coding plugin participates.

## Required Behavior

- String, bool and secret keys remain distinct. Absence is null; defaults apply
  only to absence. Empty strings and false are stored values. Upserts/deletes
  affect only the named row and never replace a whole snapshot.
- SQLite stores plaintext preferences but only authenticated ciphertext for
  secrets. Secret/master plaintext must not appear in database, WAL or journal.
- One cached master-key initialization serves concurrent secret operations.
  Missing-row reads and deletes avoid native access; plaintext operations remain
  usable while unlock is pending or denied. Failed initialization stays failed
  for that repository instance, without automatic prompt retries.
- A missing key is generated only when no encrypted rows exist, then persisted
  before ciphertext. Key loss, malformed keys, wrong keys or damaged envelopes
  fail explicitly without clearing or silently re-keying saved data.
- Ciphertext authenticates its version, scope and row identity. Each write uses
  a fresh nonce. Encryption/SQL failures preserve the last committed row.
- Native errors preserve typed diagnostic causes without rendering protected
  payloads. SQL transactions never wait for native authorization.
- Platform composition provides a ready, non-purgeable directory and scoped
  native master item. Database registration/resolution is lazy; first SQL use
  opens the connection, and graph disposal closes it. Development and production
  use separate files/items and authenticate separate cipher scopes.

## Deprecated Mobile Import (Unwired)

- Read the final completion bool before legacy native I/O. Snapshot/classify
  known auth/core keys first; leave unknown native entries untouched.
- Preserve opaque serialization, empty strings, absence, escaped bridge and
  literal user identities, including pending analytics disable JSON. Parse only
  the known bool; malformed present values fail rather than become defaults.
- Commit all typed destination writes before deleting any copied native item.
  Mark complete only after cleanup. Copy failure retains all source entries;
  interrupted cleanup/marker writes retry on relaunch by merging remaining
  source entries without erasing already committed absent-source rows.
- Failures retain cause, stack and operation with payload-free presentation.
  No dual reads/writes, per-key progress, native mirror or automatic retry.
- The removal checklist lives with the deprecated module. Retire it only when
  supported direct upgrades exclude public per-value-native mobile builds.

## Prepared Startup Recovery

The mobile bootstrap catches typed import failure around dependency setup,
awaits injected graph disposal and renders `PersistenceStartupFailureApp` before
normal consumers. Disposal failure remains observable and does not prevent
rendering. The standalone localized/themed root reads no DI or stored state and
directs OS close/reopen, without raw errors, analytics, automatic retry or
reinstall/data-clear advice. This seam is prepared; no shell invokes import yet.

## Prepared Native Capabilities (Not Yet Consumed)

- Both shells register development scope for debug/profile and production for
  release. Native ports are lazy and perform only scoped master read/write;
  the shared repository remains the sole initialization/cache owner.
- Mobile master storage uses the new Android namespace and iOS Keychain service,
  preserving standard protection and disabling Android destructive reset.
  The legacy source retains its old namespace; iOS enumeration and named
  deletion omit the accessibility query filter without changing stored ACLs.
- Desktop master storage uses classic macOS Keychain in its new service and the
  existing Windows/Linux plugin protection. No desktop legacy import is added.
- Directory adapters reuse existing app-support resolvers and create only the
  `persistence/` subtree, never a cache. Repeated resolution preserves existing
  files; lookup/creation errors propagate.
- Android full-backup/cloud/device-transfer XML excludes the complete unused
  database subtree, including sidecars. Legacy credential preferences remain
  unchanged until migration/cutover. iOS backup eligibility remains unchanged.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Typed primitive/secret roundtrips, absence/defaults, false/empty values and key-local updates/deletes through the shared repositories. Verify shell master keys/options, lazy construction, missing values/error forwarding and persistent directory resolution. Automated with real SQLite and mocked native channels; no coding plugin. |
| L2 Routine | Concurrent initialization, cached failure, pending/denied unlock without blocking preferences, key-save-before-ciphertext ordering, corruption and rollback. Import inventory/identities, unknown-item retention, completion skip, malformed bool, failed read/copy/cleanup/marker and relaunch recovery. Automated; no plugin. |
| L3 Release | Production lazy file-open path, WAL inspection for fixture plaintext/master absence, cold reopen, scope separation and DI disposal. Import through real shared SQL/crypto/DI, including partial cleanup and post-cleanup marker failure across cold reopen. Automated using isolated temporary files and fake native sources; no plugin. |
| L4 Extended | Repeat authoritative SQLite/crypto fixtures on macOS, Windows and Linux. Alternate platform failures remain blocked, not inferred from another OS. Automated; no plugin. |
| L5 Full | No additional coverage for the currently unwired backend. |

## Exploration Guidance

Vary overlapping operations on different rows, existing versus missing native
keys, reopen boundaries and native denial/save failures. Inspect only disposable
fixture files; never seed or read a personal Keychain/application directory.

## Failure Signals

- A stored false/empty value replaced by a default, another row lost on update,
  or a storage failure reported as absence.
- Plaintext secret/master bytes in SQL files, ciphertext accepted for a different
  row/scope, or a missing native key replaced while encrypted rows exist.
- Multiple native initialization attempts in one repository, ciphertext committed
  before its key, or a pending unlock blocking unrelated plaintext operations.
- Eager filesystem I/O during composition or an opened database connection
  remaining usable after graph disposal.
- Legacy cleanup before all copies commit, unknown items deleted, a completed
  import reading legacy storage, or restart erasing already committed rows.
- Pending analytics disable, scoped identity, empty value or diagnostic cause lost.
- Typed import failure reaching normal startup, rendering before disposal settles,
  disposal failure suppressing recovery, or failure copy exposing payloads.

## Known Limitations

- No product-client cutover or native released-mobile migration is active yet.
  The pure-Dart importer tests do not establish actual native enumeration/error
  behavior, production-only admission, native startup failure presentation, consent
  ordering, authorization, backup/restore or packaged-client behavior. Those
  required gates remain in the active plan. Channel tests across platform options
  on one host are not native OS coverage. Android XML validation is configuration
  evidence, not proof of actual cloud/device-transfer restore behavior.
- Shared implementation is not shared files or cross-device synchronization.
  Plaintext preferences and row IDs are inspectable, as is unlocked process
  memory. One native item does not guarantee zero OS authorization prompts.

## Sources

- `client/module_persistence/` and its cipher, repository, database and DI tests.
- Bootstrap failure tests verify disposal-before-render and no normal consumer
  callbacks. Shared recovery-widget tests cover light/dark and large text without DI.
- Mobile/desktop persistence capability tests, mobile deprecated-source tests
  and Android manifest/full-backup/data-extraction XML.
- `client/module_core/lib/src/migrations/deprecated_native_storage_v1/`, its
  matching tests, and permanent auth/core domain key definitions.
- Active `.plan/active/desktop-master-key-storage/` for remaining cutover and
  native qualification scope; expand this contract alongside that implementation.
