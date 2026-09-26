# Shared client persistence qualification

Status: **Partial — plan stays active.** Recorded 2026-09-26. No coverage waiver
or importer-retirement decision has been given.

## Authorization and isolation

The user approved test-only use of existing Apple signing/notarization and
approved QA-account secrets in isolated GitHub Actions, without store publication
or changes to personal local applications. They then explicitly requested the
global `sesori-local-testing` skill. Its slot-owned development accounts and
simulator/emulator workflow was used for the mobile checks below.

No dedicated physical test devices are available. Device-dependent restore gates
remain **Blocked**, not passed or inapplicable. Local native tests do not authorize
access to personal credentials, the login Keychain, or the running desktop/helper.

## Live mobile checks

Source: `d5508561b09915c214d1b7abd7bf1b6ac50186e0`; app `1.9.1+1`, debug /
development persistence scope; Flutter `3.47.5`, Dart `3.13.4`.

- iPhone 17 simulator, iOS 26.5, slot-owned device selected by exact UDID because
  two stopped simulators shared the slot name.
- Android 16 / API 36, ARM64 emulator owned by the same slot. The existing debug
  app was updated in place; its previous displayed version was 1.9.0. This is
  **not** a released-production migration test.
- One source-run bridge used the skill's isolated slot data directory and debug
  port. Startup verified the expected development account, listener, relay URL
  and waiting state. No coding-session prompt or destructive account action ran.

| Scenario | iOS | Android | Observed boundary |
|---|---|---|---|
| Sign in through the actual mobile UI | Pass | Pass | Real email auth and native storage; no fake storage ports. |
| Persist tokens, user and relay key | Pass | Pass | `access_token`, `refresh_token`, `auth_user`, `relay_room_key` are four ciphertext BLOB rows in the shared database. |
| Change ordinary preferences | Pass | Pass | UI selected dark/text-first on iOS and light/text-first on Android; read-only SQL confirmed the persisted spellings. |
| Terminate and cold-launch | Pass | Pass | Authenticated settings restored without credential entry; preferences, registered-bridge bool and all four ciphertext rows remained unchanged. iOS rendered the restored dark/text selection. |
| Log out | Pass | Pass | Confirmed logout removed all four secret rows while retaining appearance/input preferences. |
| Sign in again | Pass | Pass | Four encrypted secret rows were recreated; iOS preference values were also rechecked. |
| Development scope separation | Pass, bounded | Pass, bounded | No production database or migration-completion row was created. This does not independently prove native source enumeration was never called. |

The iOS database and WAL were also checked for the known test-account email;
neither contained it. This bounded check does not claim an exhaustive plaintext
or master-key scan. Native master-item counts and authorization prompt counts
were not independently measured.

### Initial iOS signing failure

The first simulator build used `--no-codesign`. Email sign-in failed with
`Client storage failed during readMasterKey`, before any secret row was written.
Rebuilding the unchanged source with normal simulator signing, reinstalling only
on the owned simulator, and relaunching resolved the failure. All subsequent
native flows passed. The underlying native error code was not captured; do not
invent one or classify this as a released-product defect.

The final build commands were:

```sh
# From client/app; target only the skill-owned devices.
flutter build ios --simulator --debug --no-pub
flutter build apk --debug --no-pub --target-platform android-arm64
```

### Cleanup and private evidence

Both slot-owned clients were stopped, the iOS simulator was shut down by UDID,
the Android emulator was stopped, and the owned bridge exited. The slot debug
port was verified free. Existing personal desktop and bridge processes remained
running. Device/data directories and their final development login state were
retained as the global skill requires.

Build logs, ciphertext comparison digests and the inspected preference image are
under ignored `.dart_tool/desktop-master-key-storage/local-slot-1-*`. No tokens,
passwords, account details, raw app logs or native databases are published here.
No production source was changed to obtain this evidence.

## Existing signed macOS native evidence

An already completed shared release was inspected read-only; no release or
signing workflow was dispatched for these observations:

- [Run 36221737896](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/36221737896).
- Product/packager source: `e510d118bcc1d6f7ffc125fa431c34f2b75ebf7e`.
- Accompanying product: internal `1.9.1+988`; Flutter `3.47.5`, Dart `3.13.4`.
- Native hosts: macOS 27.0 (26A428), arm64; macOS 26.6.1 (25G76), x64.
- Both jobs passed their separately signed platform fixture's shared
  SQLite/Keychain write/read/update and second-process relaunch/delete checks.
  The driver verifies the fixture signature and approved Team ID before running.
- Both product app/DMG notarizations were accepted; both source-change patches
  were empty. Storage assertions ran in the separate fixture, not the shipped
  product. Its independently compiled bundle version was not verified as 988.

Downloaded evidence archives match GitHub's artifact digests:

| CPU | Artifact | Archive SHA-256 |
|---|---|---|
| arm64 | `10899616043` | `f15d11dfda263d13785c849c8be5d9f68421765fd9ff903fa9441fa8579116ec` |
| x64 | `10899498480` | `d9249f154785376a71f47cc4af8093d5cf28767bd88b0ecfe853dc5bcd5179ba` |

Allowlisted phase reports are `platform-probe/platform-write.log` and
`platform-probe/platform-read.log` in each archive. Source/build identity comes
from the bundle/packaging reports; OS versions come from job metadata. Archives
and a bounded summary are retained privately under ignored
`.dart_tool/desktop-master-key-storage/native-evidence/36221737896/`.

This proves real native shared-store roundtrip and cold reopen on those hosts,
not replacement, authorization denial, observed prompt counts or full L3/L4.
The accompanying shared-format packages are a possible future replacement
baseline, not replacement evidence themselves.

## Remaining required coverage

- **Not run:** iOS/Android production-scope released-format import, complete native
  inventory/error behavior, interruption/copy/cleanup/marker recovery, pending
  opt-out admission, and native migration-failure presentation.
- **Not run:** native Windows/Linux master-store roundtrip/cold reopen and
  new-format replacement on all three desktop platforms. Existing six-platform
  native build passes are not native storage execution.
- **Not run:** macOS denied access, same-identity replacement and actual prompt
  observations; required cross-platform extended adverse-state coverage.
- **Blocked:** device-dependent paired iOS encrypted-backup restore. Android
  cloud/device-transfer behavior is also unverified; static XML validation is
  not native restore proof.
- The authenticated macOS replacement fixture still needs production-Dart
  shared-store seeding and a shared-format baseline before reuse. Its old
  per-value seeder must not be used against the cutover.

Retain the existing automated evidence on unchanged inputs. Complete the missing
[plan matrix](PLAN.md#verification-and-retirement) before retirement, or record a
separate explicit user acceptance of the named missing coverage. The deprecated
mobile importer has its own public-upgrade retirement condition and remains.
