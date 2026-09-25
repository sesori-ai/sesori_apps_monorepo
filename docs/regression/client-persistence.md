# Client Persistence

## Capability

Shared pure-Dart typed primitive persistence in Drift, plus scoped encryption
foundations. The backend is available to composition/fixtures; product shells
still use their existing native-per-value storage until migration and cutover
land. No coding plugin participates.

## Required Behavior

- String, bool and secret keys remain distinct. Primitive APIs cannot accept a
  secret key. Absence is null; defaults apply only to absence. Empty strings and
  false are data, and storage failures propagate rather than returning defaults.
- Primary-key upserts/deletes affect only the named row, not a whole snapshot.
  SQLite owns atomicity; no repository value cache hides later database values.
- Composition supplies a ready, non-purgeable directory. Registration and
  resolution perform no filesystem I/O; first SQL use opens the background
  connection with WAL, and graph disposal closes it. Primitive operations do not
  need native master-key access or a registered master-key capability.
- Development/production use separate database and master-item names. Cipher
  frames authenticate version, scope and row identity with fresh nonces; wrong
  keys, tampering and malformed encodings fail explicitly with retained causes
  and privacy-safe error presentation.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Typed keys/defaults, missing/false/empty values, primitive roundtrips and key-local updates/deletes. Automated at repository and real SQLite boundaries; no plugin. |
| L2 Routine | Failure propagation, uncached reads, scoped identities and cipher identity/authentication/corruption cases. Automated; no plugin. |
| L3 Release | Production lazy file-open path, WAL mode, cold reopen, scope separation and DI disposal. Automated using isolated temporary files; no plugin. |
| L4 Extended | Repeat authoritative SQLite/crypto fixtures on macOS, Windows and Linux. Missing platform coverage remains blocked, not inferred from another OS. Automated; no plugin. |
| L5 Full | No additional coverage for the currently unwired foundation. |

## Exploration Guidance

Vary missing/present values, updates and deletions sharing key spellings across
primitive types, reopen boundaries and scoped names. Use disposable fixture
files only, never a personal Keychain or application data directory.

## Failure Signals

- A stored false/empty value replaced by a default, another row lost on update,
  stale cached values, or a storage failure reported as absence.
- Eager filesystem I/O during composition, primitive access requiring native
  authorization, or a database usable after graph disposal.
- Ciphertext accepted under a different row/scope or protected payloads rendered
  in diagnostic exception text.

## Known Limitations

- Cached native-key/secret-repository integration, client cutover and released
  mobile migration have not landed. The encrypted table is schema preparation,
  not a currently wired native secret store. No native authorization,
  backup/restore or packaged-client qualification is established by these tests.
- Shared implementation is not shared files or cross-device synchronization.
  Plaintext preferences and row IDs are inspectable. One native master item will
  not guarantee zero OS authorization prompts.

## Sources

- `client/module_persistence/` and its cipher, primitive repository, database and
  DI tests.
- Active `.plan/active/desktop-master-key-storage/` for subsequent integration
  and required native qualification; extend this contract with implementation.
