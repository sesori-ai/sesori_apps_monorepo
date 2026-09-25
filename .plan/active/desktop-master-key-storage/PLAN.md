# Desktop master-key storage

## Goal and observed problem

Replace desktop's per-value OS credential-store persistence with one cached
OS-protected master key and an authenticated-encrypted local key/value store.
The user reports five or more macOS authorization dialogs on the first run after
an install or rebuild, including a Developer ID-signed app. After choosing
Always Allow, reopening the unchanged app does not prompt. Item names were not
recorded: per-item authorization is consistent with the observation, not a
traced count of the exact dialogs.

Success means one desktop-owned master-key item is consulted once per process,
not a promise that macOS will never present a system authorization dialog.
Ordinary reads, preference updates, token refresh, and logout must not return to
Keychain after successful unlock. Existing login/refresh/logout ownership and
client/bridge wire contracts remain unchanged.

## Current code and release boundary

- `client/desktop/lib/core/platform/desktop_secure_storage_adapter.dart` delegates
  every `SecureStorage` read/write/delete to FlutterSecureStorage.
- `client/desktop/lib/core/di/register_module.dart` selects classic macOS Keychain
  with service `com.sesori.desktop`; debug and release use the same service.
  Windows and Linux use the same Flutter abstraction's native credential store.
- `module_auth` persists tokens, account data, and transient OAuth values;
  `module_core` also persists room keys and ordinary preferences through this seam.
- `client/module_desktop_core` owns pure-Dart desktop APIs and the existing
  `DesktopApplicationSupportDirectory` capability. Desktop claims its primary
  process before reading preferences or restoring authentication in `main.dart`.
- The installed macOS app's Developer ID signature passed deep/strict validation.
  The running local debug build was ad-hoc signed. Signing identity remains
  relevant, but signing alone does not consolidate per-item authorization.
- Desktop distribution remains private/unpublished according to
  `docs/regression/desktop-distribution.md`; the public `v1.9.0` release contains
  bridge archives, not desktop packages. Public mobile/bridge releases do not
  establish a desktop-local-storage compatibility obligation.

## Scope and decisions

### Included

- All desktop targets: macOS, Windows, Linux. No harness-specific behavior.
- One random 256-bit master key protected by the current OS credential backend.
- One encrypted local store under application support, separate development and
  packaged-release namespaces for both the master key and its ciphertext.
- Existing desktop `SecureStorage` consumers continue unchanged. Preferences
  also move into this local encrypted store, rather than remaining separate
  Keychain items. Their encryption adds no extra OS authorization.
- Pure-Dart persistence and crypto ownership below the Flutter shell, focused
  tests, production DI integration, and updated package qualification fixtures.
- Honest failure behavior and proof boundaries, plus privacy-safe fixture media
  showing the native first-run/relaunch behavior when qualification permits it.

### Deliberately excluded

- A shared/mobile preference-storage refactor or new per-key sensitivity schema.
- Mobile, headless bridge, backend-plugin, relay-protocol, or database changes.
- Legacy desktop dual reads/writes, automatic migration, or deletion of old
  Keychain entries. Existing internal installs sign in once after adopting the
  new store; old entries remain untouched and do not create migration dialogs.
- Keychain ACL broadening, unattended password entry, changing the user's login
  Keychain, Data Protection Keychain entitlements, certificate provisioning, or
  production publication. Existing release signing stays in place.
- Background key rotation, Secure Enclave, key recovery/escrow, cross-process
  credential sharing, file watchers, or new startup/lock-screen UI.

## Architecture and data flow

`module_auth/module_core consumers -> SecureStorage -> DesktopSecureStorageRepository`

`DesktopSecureStorageRepository -> DesktopSecureStorageApi -> DesktopMasterKeyStore + DesktopApplicationSupportDirectory`

- **Foundation:** define the narrow native `DesktopMasterKeyStore` capability in
  `client/module_desktop_core/lib/src/foundation/platform/desktop_master_key_store.dart`,
  with named `read` and `write` operations for the one master key, not arbitrary
  per-value access. Define `DesktopStorageScope` in
  `lib/src/foundation/desktop_storage_scope.dart` as a closed development/production
  enum, and `DesktopStorageCipher` in `lib/src/foundation/desktop_storage_cipher.dart`
  as the versioned authenticated-encryption primitive. Foundation error types
  retain original causes but present no plaintext.
- **API:** `lib/src/api/desktop_secure_storage_api.dart` owns only raw native-key
  and ciphertext-file I/O. Its injected collaborators are the native key
  capability and existing application-support resolver. Ciphertext operations
  take the required scope explicitly and derive the corresponding file path.
  Atomic ciphertext replacement and temporary-file cleanup are I/O operations
  here; the API has no key-creation policy, value cache, or ordering state.
- **Repository:** `lib/src/repositories/desktop_secure_storage_repository.dart`
  implements `SecureStorage`. It receives the API, cipher primitive, and shared
  scope, owns key initialization/presence policy, strict map encoding/decoding,
  failure retention, and the one operation tail. It passes its scope to every
  ciphertext API call; it never independently derives scope from build mode.
- **Shell:** replace the pass-through desktop adapter with a dumb
  `FlutterDesktopMasterKeyStore` adapter. It performs only native key
  reads/writes through FlutterSecureStorage. A single typed `DesktopStorageScope`
  provider in `client/desktop/lib/core/di/register_module.dart` selects development
  for debug/profile and production for packaged release. Inject that same value
  into both the native adapter and repository so key/file namespaces agree.
- **DI and exports:** phase 1 retains exactly one lazy `SecureStorage` interface
  binding in shell composition, resolving `DesktopSecureStorageRepository` only
  after all four configuration phases finish. Desktop-core phase 4 registers
  the concrete repository, API, and cipher. Export the key capability, scope,
  and repository binding seam through `lib/sesori_desktop_core.dart`; shell
  code never imports desktop-core `src` paths. Regenerate DI from source.
- **Cryptography:** use the existing `cryptography` package, declared directly in
  desktop core, with AES-256-GCM, a fresh random 96-bit nonce on every write,
  and a 128-bit authentication tag. Use an explicit format-version byte and a
  fixed Sesori desktop-storage domain string as authenticated associated data.
  The binary envelope contains version, nonce, ciphertext, and tag. Do not reuse
  relay session keys, relay encryption framing, or raw DH output.
- **Payload:** a JSON `Map<String, String>` representing the genuinely open-ended
  existing key/value contract. No hard-coded token/preference fields and no
  raw maps for known domain DTOs. Strictly validate decoded key/value types and
  wrap parser failures without exposing plaintext in exception presentation.
- **Disk:** a scoped directory beneath application support contains only the
  encrypted store and its same-directory temporary replacement. Write and flush
  ciphertext, then atomically rename over the previous file. POSIX directory
  and file permissions are owner-only; Windows inherits the user's app-data
  directory ACL. Never write a plaintext temporary file or master key to disk.

## Initialization, ordering, and failure contract

1. Resolve the scope's directory and read the native master-key item once via a
   shared initialization future. Concurrent callers share that attempt.
2. If the key is absent and no ciphertext exists, generate and persist one key
   before admitting any ciphertext write. If ciphertext exists without its key,
   fail; do not create a replacement key or clear the store.
3. Validate stored key encoding/length. Cache the usable key for this process.
   A failed initialization remains a failure for that instance; relaunch retries
   authorization. It must not fan out into repeated automatic unlock dialogs.
4. Serialize read/write/delete operations through one tail future. Each operation
   reads and decrypts the current small store; there is no additional mutable
   in-memory value cache. This preserves ordinary concurrent preference writes,
   auth refresh persistence, and parallel logout deletes without lost updates.
5. Missing ciphertext with an established key means an empty store. Missing
   values return null. Authentication failures, malformed payloads, unknown
   versions, key failures, and I/O failures remain explicit errors; they never
   become an empty store inside the persistence owner.
6. A failed operation reports to its caller while leaving the operation queue
   usable. Preserve existing ciphertext on an unsuccessful replacement. Log any
   recovered temporary-file cleanup failure with its local operation context.
7. Logout removes the requested values, not the master key or unrelated device
   preferences. Do not change the auth module's single writer or logout fencing.

### Complexity budget and safeguards

New durable state: one master-key item and one encrypted file per scope; a
short-lived encrypted replacement file while committing a write.

New long-lived mutable state in the store: one initialization future and one
operation-tail future. The initialized value holds the immutable paths and key.
No mutable value map survives an operation. The cipher and platform adapter
carry only immutable configuration.

- **Observed failure:** multiple first-run protected-item authorizations.
  Consolidation and one cached initialization directly address it.
- **Ordinary reachable flow:** independent startup/preferences/auth operations
  overlap. One small serialized storage boundary prevents lost writes/deletes.
- **Ordinary reachable flow:** OS access is denied or a key is absent after a
  restore/manual deletion. Fail closed instead of destroying ciphertext.
- **Ordinary reachable flow:** interruption/disk error during a token write.
  Flush-and-replace preserves the previously committed file.
- **Ordinary reachable flow:** malformed/tampered ciphertext or payload must not
  be treated as a valid empty account store. Authenticate and parse strictly.
- **Accepted limits:** no defense against a fully compromised running user/app;
  an unlocked key remains in process memory until exit. No cross-process locks:
  the existing primary-desktop process gate owns admission. No guarantee against
  every hardware/power-loss durability failure beyond flush plus atomic replace.
  System authorization can still occur for the single item. Repeated ad-hoc
  rebuilds are not promised a stable trusted identity.

## Cleanup and existing qualification consumers

Remove the desktop arbitrary-key native adapter and its generated registration
when the new implementation is wired. Remove stale claims that each desktop
auth value lives directly in Keychain. Keep mobile's adapter unchanged.

`client/desktop/test/native/packaged_platform_probe.dart` and
`.github/scripts/write_desktop_macos_keychain.swift` /
`.github/scripts/qualify_desktop_macos_authenticated_upgrade.py` currently read or
seed per-token native items. Update them to exercise the actual new store and
one same-team native master-key item; remove obsolete per-token seeding paths,
not dual-format support. Keep all credential transfer private/stdin-only and
bounded. AES-GCM permits a native CryptoKit fixture to validate the same envelope
without introducing another crypto dependency into Python qualification.

Old private packages are not upgrade compatibility baselines. New-to-new signed
qualification must use two packages implementing the new storage contract; old
per-token fixture success is not evidence for this change. Reconcile the active
desktop-distribution plan's affected evidence references without claiming a new
public release or erasing historical results.

## PR series and estimates

All work stays in the user-provided worktree. Keep one PR open and at most one
local successor branch. No additional worktrees. Estimates include tests, docs,
and generated output; reassess before every push against the 1,500-line soft cap.

| Step | Exact PR title | Scope and expected result | Estimate |
|---|---|---|---|
| 1 | 🌿 [desktop-master-key-storage] Plan desktop master-key persistence [step 1/5] | Commit this reviewed plan and tracker. No user-visible or database change. | 220–320 authored lines |
| 2 | 🚧 [desktop-master-key-storage] Add encrypted desktop storage boundary [step 2/5] | Foundation capability/scope/cipher, raw API and state-owning repository, public exports, focused persistence/security tests. Do not bind it in production DI yet; existing desktop behavior stays unchanged. No database change. | 850–1,300 authored lines |
| 3 | 🚧 [desktop-master-key-storage] Route desktop credentials through one master key [step 3/5] | Native adapter, lazy DI/scope wiring, native/qualification fixture replacement and integration tests. Desktop values move to encrypted local storage and first internal adoption requires login. No database/wire change. | 850–1,400 authored plus small generated DI churn |
| 4 | 🌿 [desktop-master-key-storage] Document desktop credential storage behavior [step 4/5] | Reconcile regression/package/support docs and affected active distribution evidence. No additional runtime or database change. | 100–250 authored lines |
| 5 | ⚙️ [desktop-master-key-storage] Qualify and retire desktop storage plan [step 5/5] | Run the recorded matrix, record privacy-safe evidence and limitations, and retire only on pass. No extra runtime or database change. | 100–250 authored lines |

Step 2 depends on Step 1; Step 3 on Step 2; Step 4 on Step 3; Step 5 on Step 4.
Architecture plan review runs before publishing Step 1. Architecture implementation
review covers each architecture-bearing production diff; documentation and
qualification-only follow-ups need no architecture review. Valid local findings
are applied without widening the task into unrelated refactors.

## Verification and retirement gates

Highest required level: **L4 Extended for the new desktop credential-storage
feature**, with the specifically required packaged macOS boundary below. This
does not request the entire unrelated account/provider or desktop distribution
catalog. Add a focused `docs/regression/desktop-credential-storage.md` feature
entry and align affected statements in `account-and-onboarding.md`,
`desktop-macos-packaging.md`, and `desktop-distribution.md`.

| Gate | Boundary and matrix | Required proof |
|---|---|---|
| L1 | Automated; pure Dart owning-package tests | Roundtrip, persistence across store instances, missing-value semantics, actual encrypted bytes rather than plaintext, one successful master-key read for many values. |
| L2 | Automated; desktop core and shell DI/platform tests | First key creation, no repeated native reads/writes on warm operations, correct development/release separation, token-style updates and logout-style deletes preserving preferences, production consumer binding. |
| L3 | Packaged/native fixture; Developer ID-signed macOS arm64 | Actual Flutter adapter + production store write/read/delete through classic Keychain; cold launch, unchanged relaunch, and replacement with a second valid same-identity new-format build preserve values and consult only the master item. Count adapter operations and observe native authorization; never infer dialog count from Dart mocks. Use only dummy fixture values and isolated owned state. |
| L4 | Automated on macOS, Linux, Windows; native failure fixture on macOS | Concurrent operations and initialization, corrupt/tampered/truncated/unknown envelope, malformed plaintext payload, invalid/missing/denied key, failed key creation, write/replacement failure preserving committed data, and queue continuity. Native fixture covers denied/unavailable access without replacing keys or destroying the file. |

Owning-package analysis and directly relevant tests run locally; CI owns its
normal full matrix. Add/dispatch only focused platform checks missing from CI.
No coding plugin, mobile simulator, auth-server account, or live bridge is needed
to prove this platform-storage contract: existing auth/relay business behavior is
unchanged, while credential persistence is exercised through its actual native
boundary with fixture values. Do not launch the user's app or disturb its bridge.

The packaged macOS test must reproduce modern login-style partition behavior;
a scratch Keychain in an arbitrary temporary directory is insufficient. Creation
of a disposable local Keychain or any interactive authorization needs explicit
operator permission, otherwise use the existing isolated CI signing/fixture path.
Never mutate the user's default/search-list settings or inspect real secret bytes.

Record Pass/Partial/Blocked/Fail per gate, exact commit/build/signing identity,
commands and bounded artifacts, and cleanup. Preserve the active plan if a
required OS/native boundary is blocked or unexecuted. A smaller matrix requires
explicit user acceptance recorded here before retirement. No zero-prompt,
signed-update, Windows/Linux native credential-store, or public-release claim
may be inferred from a unit-test result alone.

## Review record

- Architecture plan review: initial plan rejected with four concrete findings
  (repository ownership, phase-1 interface registration, one shared typed scope,
  and public exports). Applied those corrections above; no repeat approval is
  claimed or required. The raw API owns atomic I/O, while the repository owns
  policy and ordering. Review run: `2359dc5a-26c5-4e8a-a2d4-195b638c8e70`.
- The review completed and its full report was recovered after a workflow-only
  reporting failure on an undefined optional output field. Remaining reviews
  resume through the same subagent protocol; the completed review is not rerun.
- Implementation reviews: not started.
