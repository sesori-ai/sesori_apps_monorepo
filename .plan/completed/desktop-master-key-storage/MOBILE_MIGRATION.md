# Native mobile migration qualification

The original simulator/emulator observations were recorded 2026-09-26 at product
source `ac488d0` (production files unchanged from `d550856`). That source applies
only to the historical simulator/emulator sections below, not the physical run.
Fixture: `client/app/integration_test/native_persistence_migration_test.dart`.
Flutter 3.47.5 / Dart 3.13.4; debug fixture with explicit **production persistence
scope**. These are not store-distributed upgrade builds.

## Physical-device follow-up after recovery fence

Physical-run production source: `d054d533e5f916783bd46199446a1d45f6cea870`,
whose merge parent checkpoint `0950ab7f24f31cd63f2884f30e9e72a6a918475a`
includes #1808. No production files changed during these runs. Internal debug
build: `1.9.1+1`, normal development signing, iPhoneOS 27.0 SDK (SDK version,
not a claim about device OS). The restored normal app's Info.plist confirms
that build/version; no separate per-phase binary hashes were recorded.

The first three phases used that source plus the explicit physical-device opt-in
fixture edit. The last two used the subsequently extended `recover` and
`recoveredReopen` fixture, saved exactly in
`11d56970db17fbe5932d8a879a082b4cc9fb6578`. Both fixture edits were uncommitted
when executed; that commit records them afterward and changes no production code.

User authorized Sesori-only changes on a connected physical iPhone 15, explicitly
excluding whole-device erase/restore and other apps. Five independent signed
Flutter integration invocations passed after merging #1808: `seed`, `migrate`,
`reopen`, `recover`, and `recoveredReopen`. Each used `--no-uninstall` and the
explicit `SESORI_NATIVE_PERSISTENCE_ALLOW_PHYSICAL=true` opt-in. No uninstall was
needed; no whole-device operation, backup restore, or broad Keychain change ran.
No bridge or account login was needed: all fixture HTTP remained fenced.

- Initial migration preserved native-format fixture values, empty/scoped values,
  pending opt-out and unknown native entries. Separate-process reopen passed.
- Recovery injected the persisted false completion marker plus a synthetic stale
  legacy token. Real production startup cleared the scoped destination/source,
  replaced the native master, committed completion and remained logged out.
- A newly written fixture secret survived another separate-process reopen;
  completed recovery did not rotate its master again or reimport stale auth.
- This is real native execution with synthetic data and an injected pending
  state, not a store-distributed upgrade, OS-denial test, or a real fresh login.
- After testing, a normal debug app was built, installed and launched without
  uninstalling. Fixture production-scope data remains; debug uses development.

Local logs: `.dart_tool/desktop-master-key-storage/physical-ios-*.log`.
The fixture's analyzer passed. No private device identifier is published here.

The user separately confirmed a physical Android running latest main preserved
its long-standing login through the cutover, with no reinstall, data clearing or
manual re-login. Record this as user-reported real upgrade/login continuity,
not instrumented proof of every stored field or backup/restore behavior.

Physical iOS backup restore is **not authorized**: only Sesori app/data changes
are allowed. Restore, OS-denied native access and distributed iOS upgrade remain
unverified. Do not erase the device to close these gates.

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
and target its exact device. A physical device instead requires explicit user
authorization limited to Sesori; add
`--dart-define=SESORI_NATIVE_PERSISTENCE_ALLOW_PHYSICAL=true` to **each** invocation.
This opt-in does not authorize whole-device operations. From `client/app`, run
each phase in a separate invocation; **do not omit `--no-uninstall`**:

```sh
flutter test integration_test/native_persistence_migration_test.dart \
  -d <owned-device-id> --no-pub --no-uninstall \
  --dart-define=SESORI_NATIVE_PERSISTENCE_PHASE=seed --reporter=expanded
# Repeat the command with SESORI_NATIVE_PERSISTENCE_PHASE=migrate,
# then reopen, then recover, then recoveredReopen (in that order).
# On an explicitly authorized physical device, include this in all five commands:
# --dart-define=SESORI_NATIVE_PERSISTENCE_ALLOW_PHYSICAL=true
```

Seed refuses an existing production database/master. Do not erase an existing
slot to rerun it. Reopen can inspect its retained migrated fixture. The final two
phases are intentionally destructive to that fixture's production scope: recover
injects pending reset and a stale native token, checks cleanup/master rotation,
and saves a fresh secret; recoveredReopen checks completion and its retention.
Run them only when discarding that fixture state is authorized. Restore a normal
build in place before releasing the slot; never uninstall or clear it merely to
make a failing test pass.
Private evidence is under ignored `.dart_tool/desktop-master-key-storage/` as
`native-migration-*`; source/witness payloads must not be published.

Reset-on-migration-failure is implemented by #1779/#1808 and partially qualified
by the physical pending-reset and recovered-reopen observations above. The older
simulator/emulator happy-path observations alone do not cover it. Actual native
error/denial, interrupted copy/cleanup/marker paths, distributed upgrade and
hardware restore remain distinct, unvalidated coverage. The user's explicit
acceptance of all remaining gaps is recorded in [QUALIFICATION.md](QUALIFICATION.md);
plan closure does not represent those gates as passing.
