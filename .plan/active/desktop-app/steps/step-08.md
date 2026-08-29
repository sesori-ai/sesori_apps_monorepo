# Step 8 — Single instance + last-state restore

Date: 2026-08-28.

## Delivered

- Added Layer-1 `DesktopInstanceApi`: an OS-released file lock and loopback
  activation channel share one lifecycle. A second process signals the owner
  and exits; a killed owner leaves only harmless metadata and the next process
  reclaims the lock.
- Added Layer-1 `DesktopInstanceStorage` for the last desired bridge On/Off state
  under desktop-owned application support. Missing/invalid state safely means
  Off.
- Added a Layer-0 `BridgeProcessDesiredState` model so storage, repository, and
  higher layers all depend downward rather than importing a service-owned type.
- Added the Layer-2 aggregate repository and Layer-3 instance service. The
  service owns lock → activate → one recovery claim → secondary-failure policy;
  a live lock with a broken activation channel can never create a duplicate.
- Added `DesktopStartupOrchestrator`: it owns primary-claim and secondary-exit
  policy before native window setup; the narrow shell bootstrap only decides
  whether to continue building UI. The primary starts the control dispatcher,
  then last-On restoration delegates to the existing auth-gated process service.
- `BridgeControlCubit` consumes owner focus requests and persists On/Off/Quit;
  coordinated logout persists Off after successful helper stop. All persistence
  requests serialize through the singleton instance service so logout Off cannot
  be overwritten by a pending toggle On write.
- Added real subprocess tests for activation and kill recovery plus storage,
  repository, service, startup, focus, logout, and DI coverage.
- Hidden/autostart behavior remains intentionally deferred to step 9. No
  analytics event was added because instance arbitration is internal lifecycle
  behavior, not a product-adoption action.

No database or transport impact. Persisted impact is one desktop-owned scalar
file plus lock/activation metadata; standalone CLI state is untouched.

## Architecture implementation review

The first B-Client pass rejected Layer-2 launch policy and a Layer-1/2 import of
a service-owned desired-state enum. Both valid findings were fixed directly:
policy/result ownership moved to Layer 3 and the enum moved to Layer 0. The
second/final pass approved with no findings and confirmed lock/socket cohesion,
layer direction, startup composition, disposal, and Step-9 scope separation.

## Verification

- `client/module_desktop_core`: analysis clean; all 149 tests passed.
- `client/desktop`: analysis clean; all 32 tests passed.
- Focused Step-8 suite covers cross-process activation, killed-owner lock
  recovery, activation failure, persistence, layer delegation, auth-gated
  restore, focus, logout/quit Off persistence, and DI.
- Desktop-core Injectable output regenerated with the final layer ownership.
- macOS debug application build passed with the new startup composition.
- Dart LSP: 0 diagnostics across 25 affected non-generated Dart files.
- `git diff --check` — clean.
- Change size: 1,093 text changed lines, under the 1,500-line soft cap.
