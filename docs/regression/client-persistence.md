# Client Persistence

## Capability

Shared pure-Dart typed preferences and individually encrypted secrets backed by
Drift. The backend is currently available to composition/fixtures; product
shells still use their existing native-per-value storage until migration and
cutover land. No coding plugin participates.

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

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Typed primitive/secret roundtrips, absence/defaults, false/empty values and key-local updates/deletes through the shared repositories. Automated with real SQLite and fake native storage; no plugin. |
| L2 Routine | Concurrent initialization, cached failure, pending/denied unlock without blocking preferences, key-save-before-ciphertext ordering, corruption and rollback. Automated; no plugin. |
| L3 Release | Production lazy file-open path, WAL inspection for fixture plaintext/master absence, cold reopen, scope separation and DI disposal. Automated using isolated temporary files; no plugin. |
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
- Eager filesystem I/O during composition or a database usable after disposal.

## Known Limitations

- No product-client cutover or released-mobile migration is implemented yet.
  This contract does not establish native authorization, backup/restore or
  packaged-client behavior. Those required gates remain in the active plan.
- Shared implementation is not shared files or cross-device synchronization.
  Plaintext preferences and row IDs are inspectable, as is unlocked process
  memory. One native item does not guarantee zero OS authorization prompts.

## Sources

- `client/module_persistence/` and its cipher, repository, database and DI tests.
- Active `.plan/active/desktop-master-key-storage/` for remaining cutover and
  native qualification scope; expand this contract alongside that implementation.
