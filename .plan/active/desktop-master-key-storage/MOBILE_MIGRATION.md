# Native mobile migration qualification

Recorded 2026-09-26. Product source: `ac488d0` (production files unchanged from
`d550856`). Fixture: `client/app/integration_test/native_persistence_migration_test.dart`.
Flutter 3.47.5 / Dart 3.13.4; internal app 1.9.1+1, debug fixture with explicit
**production persistence scope**. These are not store-distributed upgrade builds.

## Boundary and results

Used the existing global `sesori-local-testing` slot workflow: owned iPhone 17 /
iOS 26.5 simulator and Android 16 / API 36 ARM64 emulator. No personal app,
bridge/helper or login Keychain was operated on. A slot bridge held its debug
port; fixture HTTP was replaced with a throwing client, not real account calls.
All persistence ports, SQLite, native master access and production DI/import were
real. Existing slot legacy records were preserved; only missing test fields were
seeded. Synthetic defaults cannot authenticate to the server.

The seeder matches the native format/options from public-source baseline
`ffa5935`, including flutter_secure_storage 11.2.0 / Darwin 0.4.3. Android
`resetOnError` is deliberately disabled; no plugin algorithm change is involved.
The additional iOS scoped preference is written with `first_unlock`; other added
items use `unlocked`. Production enumeration and named cleanup handle both.

| Observation | iOS | Android |
|---|---|---|
| Add missing released-format entries without overwriting existing native values | Pass | Pass |
| Production DI imports auth/OAuth, room key, preferences and scoped identities | Pass, cumulative evidence below | Pass |
| Exact source-to-destination preservation, including empty strings and bool encoding | Pass | Pass |
| Fixture pending-disable JSON is readable before analytics bootstrap | Pass | Pass |
| Delete copied native items; retain unknown native item | Pass | Pass |
| Separate-process reopen, offline authenticated restoration and room-key read | Pass | Pass |
| Completion skips the import capability on reopen | Pass | Pass |
| Subsequent primitive writes use Drift, without recreating old native entries | Pass | Pass |
| Existing development database and ciphertext unchanged by fixture | Not claimed: runner uninstall incident | Pass, full pre/post digest and primitive comparison |

Final production row counts: iOS **9 strings / 2 bools / 8 encrypted values**;
Android **6 strings / 2 bools / 8 encrypted values**. Bool counts include the
completion marker. Extra strings came from pre-existing slot-scoped entries.

A SHA-256 witness of the complete native inventory is saved inside the owned
app's persistence directory, not plaintext. Verification recombines destination
values with retained unknown source entries and compares the digest. This proves
preservation of the independently added fixture entries and observed existing
inventory, not completeness for every historical native envelope or error path.
The pending-disable fixture is separate from any pre-existing slot account's
preference; this does not prove an actual server opt-out synchronization.

## Harness failures and recovery

- Initial seed refused existing legacy data before writing. The fixture was
  corrected to preserve it and add only absent entries; it never overwrites a
  source value.
- **Flutter integration tests uninstall by default.** The first iOS invocations
  erased the owned app sandbox, including its development DB and digest witness.
  Native Keychain entries survived. Migration then correctly stopped because its
  witness file was absent. All later runs used `--no-uninstall`.
- The retained iOS migration invocation passed full data/cleanup/pending-disable
  verification, then failed an incorrect fixture assertion that AuthSession was
  still unconstructed inside the analytics callback. Production resolves
  AnalyticsCrawlGateService and its AuthSession dependency **after migration but
  before that callback**. Removed this assertion; subsequent separate-process
  reopen passed all data/auth/write/skip checks. Do not report the initial
  migration invocation as a completely green test.
- Android seed, migration and reopen all passed independently with the corrected
  fixture and `--no-uninstall` from the outset.
- Restored the normal builds on both owned devices. Restored iOS development login
  through real email UI, then restored original plaintext preference rows from
  the private pre-test snapshot while the app was stopped. Four encrypted auth/
  relay rows, original preferences and authenticated Projects UI survived a cold
  launch. This was **test-slot repair**, not migration evidence or byte-identical
  preservation of the lost ciphertext. The notification prompt was denied during
  this repair; prior OS permission state was not established.
- Initial slot-bridge launch inherited an expired sandbox TMPDIR and clang failed
  to create temporary files. Retry with a persistent test-owned TMPDIR passed all
  required slot identity/listener/relay/waiting markers. Not a product failure.

Both normal client builds are retained, stopped; owned simulator/emulator and
bridge are stopped, slot data remains. Production fixture records remain for
later reopen/adverse-state work. No real credentials, account details, raw logs,
databases or comparison digests are committed.

## Reproduction

Claim a slot with the global skill, verify ownership, use normal native signing,
and target its exact device. From `client/app`, run each phase in a separate
invocation; **do not omit `--no-uninstall`**:

```sh
flutter test integration_test/native_persistence_migration_test.dart \
  -d <owned-device-id> --no-pub --no-uninstall \
  --dart-define=SESORI_NATIVE_PERSISTENCE_PHASE=seed --reporter=expanded
# Repeat with phase=migrate, then phase=reopen.
```

Seed refuses an existing production database/master. Do not erase an existing
slot to rerun it. Reopen can inspect its retained migrated fixture. Restore a
normal build in place before releasing the slot; never uninstall or clear it.
Private evidence is under ignored `.dart_tool/desktop-master-key-storage/` as
`native-migration-*`; source/witness payloads must not be published.

This narrows the remaining [qualification matrix](QUALIFICATION.md), not the
required L4 gates. Native error/denial, interrupted copy/cleanup/marker paths,
actual distributed upgrade and hardware restore remain distinct. The subsequent
user-requested reset-on-migration-failure policy is not implemented or qualified
by these happy-path observations.
