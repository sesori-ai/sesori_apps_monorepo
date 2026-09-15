# Desktop Distribution — Signed Native Installers And Updates

## Status and goal

- **Slug:** `desktop-distribution`
- **Date:** 2026-09-15
- **Status:** Planning; implementation and publication have not started.
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Delivery:** 12 planned PRs; exact titles below. Keep one current series total.
- **Architecture review:** reviewed 2026-09-15; ownership/DI/identity findings applied
  directly. The corrected revision was not re-reviewed; see `TRACKER.md`.

Deliver the existing supervisor + cockpit as signed, installable, updateable desktop
software on macOS, Windows, and Linux, each natively on x64 and arm64. Release macOS
first, then Windows, then Linux; both architectures must pass before their platform
ships. A working CLI target or an emulated run does not prove native desktop support.

This succeeds [desktop-app](../desktop-app/PLAN.md), whose step 22 explicitly named
this work. The user requested distribution planning before that plan's retirement.
Its tracker still lists MT Gate C, regression reconciliation, and retirement as
pending. Do not mark them passed, retire the parent, or claim inherited evidence
that has not been recorded. Planning and non-public packaging can proceed; the first
public desktop gate requires the parent closeout or an explicit user-accepted change
to that prerequisite. The parent keeps its own step numbering and ownership.

## Decisions aligned with the user

| ID | Decision |
|---|---|
| D1 | macOS first, followed by Windows and Linux; independent platform ship gates. |
| D2 | All six native targets: macOS, Windows, Linux × x64, arm64. No silent reduction. |
| D3 | macOS: direct Developer ID distribution, hardened runtime, notarization, stapled DMGs, Sparkle updates. App Store sandboxing does not fit the current host-tool model. |
| D4 | Windows: direct download first, signed per-user EXE installer, app-managed updates, and winget discovery. Store/MSIX is not a launch requirement; full-trust MSIX is a legitimate later alternative, not inherently incompatible with subprocesses. |
| D5 | Linux: DEB and RPM packages with signed APT/RPM repositories. No AppImage, Flatpak, Snap, or custom Linux self-updater in this plan. |
| D6 | App-managed updates prepare in the background and install on normal application quit. Closing to tray is not quit. Explicit Install and restart remains available; ordinary Quit must not reopen the app. Linux updates remain package-manager-owned. |
| D7 | GitHub Releases hosts downloadable installers; static GCS hosts updater feeds and signed Linux repositories. No new backend release service. Linux repositories also host their package payloads, rather than relying on cross-origin package-manager redirects. |

### Proposed implementation defaults

These are design choices in this plan, not claims that the user separately selected
each detail. Change them if the qualification evidence requires it; ask before
changing user intent, adding material infrastructure, or reducing the matrix.

- Bundle the same-commit, matching-architecture bridge and all native assets with
  the GUI. Use separate architecture artifacts rather than inventing universal
  Dart/native-asset bundles. Harness runtimes remain installed on demand through
  existing plugin management; PATH-installed harnesses retain precedence.
- Keep shared product semantic versioning, adding desktop to `tool/sync_versions.dart`.
  Desktop release attempts have their own build number, tags, feeds, and publication
  gate; they never query TestFlight/Play to obtain a desktop build number.
- Start with explicit internal and stable desktop release dispatches. No new hourly
  scheduler, release database, rollout service, or automatic stable promotion.
- Stable is the installed default. Internal testing is an explicit separate feed/
  repository selection; do not build an in-app channel-switching feature now.
- Use a maintained updater, not a new archive downloader/swap/rollback engine.
  Sparkle is the macOS choice. WinSparkle is the Windows candidate, subject to the
  install-on-quit qualification below; do not adopt two Windows engines or silently
  replace this policy with prompt-and-immediate-install.
- Use GCS's standard HTTPS object endpoint initially. A branded HTTPS hostname
  needs an existing front door or separately approved TLS/load-balancer/CDN setup;
  a bucket CNAME alone does not provide custom-domain HTTPS.
- Retain local diagnostics. No remote crash reporting, new desktop analytics SDK,
  unattended data upload, or new product-event taxonomy as part of distribution.

## Current behavior and code anchors

Verified against the planning checkout, not inferred from the superseded proposal:

- `client/desktop` is the thin Flutter shell; `client/module_desktop_core` owns
  supervision and lifecycle policy. Shared cockpit logic remains in `module_app_ui`
  and `module_core`; desktop never imports bridge-workspace implementation code.
- `DesktopBridgeExecutablePathResolver` only supports development: an explicit
  `SESORI_DESKTOP_BRIDGE_PATH` or the repository's `bridge/app/build/cli/bundle/bin`
  path. Packaged startup is not implemented.
- `BridgeControlCubit.quit()` already locks controls, cancels pending restore, awaits
  `BridgeProcessService.stop()`, then disposes tray/window state and terminates.
  Failed helper stop leaves the app alive. Quit preserves last-On/Off intent.
- `IoLaunchAtLogin` records the exact executable path in a macOS LaunchAgent,
  Windows HKCU Run value, or Linux autostart desktop entry. Installed paths and
  packaged quit/update behavior therefore require real testing, not just new archives.
- No desktop updater implementation exists; `AppUpdater` references in module
  instructions describe an intended seam, not delivered code.
- Desktop pubspec is `0.1.0`; mobile and bridge are `1.8.4`. Version synchronization
  and release guards currently omit desktop.
- `desktop-ci.yml` analyzes/tests and builds on three host runners. It does not
  package, sign, publish, or prove six native desktop targets.
- `_reusable-bridge-build.yml` already builds six bridge archives and signs macOS
  executables plus bundled dylibs, including verification after extraction. It does
  not establish hardened-runtime/notarized desktop-bundle correctness. Its Linux
  ARM64 leg explicitly avoids a missing Flutter host SDK by using standalone Dart;
  that workaround cannot compile the Flutter GUI by itself.
- `release-all-platforms.yml` and `check_internal_release.sh` preserve a scheduled,
  immutable-commit, all-or-nothing mobile/CLI release with no automatic retry of an
  attempted commit. Desktop-only changes intentionally do not consume store uploads.
- The GitHub source repository is public. Existing bridge installers/updaters consume
  its releases; new desktop assets/tags must not change their release selection.

The historical `docs/desktop/phase-3-packaging.md` is recoverable before commit
`586dec5a6d`; it is research input, not authority. In particular, its Windows
"no SmartScreen warning after signing" promise is incorrect, and its updater
ownership proposal must not bypass today's process service.

## Boundaries and concrete design

### 1. Bundle identity and installed layout

The GUI and helper ship as one versioned package built from one immutable source SHA.
Keep the Dart CLI bundle's `bin/` and `lib/` relationship intact; do not move only the
executable or hand-edit native-asset metadata. Include a build-generated, typed bundle
identity manifest with semantic version, build identity, source SHA, OS, and CPU;
compile the expected identity into the GUI. The pure-Dart typed model is
`DesktopBundleIdentity` in
`client/module_desktop_core/lib/src/foundation/models/desktop_bundle_identity.dart`,
with generated JSON serialization; reuse suitable existing closed OS/CPU types.
`client/desktop/tool/stage_desktop_bundle.dart` is the build-time producer: it
serializes that model into `desktop-bundle.json` at the helper bundle root and
supplies the same identity as Flutter build defines. The existing shell
`DesktopBridgeExecutablePathResolver` reads and validates the manifest against the
GUI's compiled identity before returning a helper path to the process API. Its
existing development branch remains separately testable. Export the model from
desktop core only; neither `module_core` nor `sesori_shared` acquires this contract.
This is an immutable build artifact, not a database, client/bridge wire contract,
or mutable runtime registry.

- **macOS:** put the complete helper bundle under `Sesori.app/Contents/Helpers/bridge/`.
  Audit native asset lookup and nested signing before freezing that layout in step 2.
  Install the GUI in an Applications directory; do not run daily use from the DMG.
- **Windows:** stable per-user install root under LocalAppData, with a helper
  subdirectory preserving the CLI bundle layout. No administrator requirement for
  ordinary install/update, PATH modification, or machine-wide service.
- **Linux:** package-owned `/opt/sesori-desktop/` contains the GUI bundle and helper
  subdirectory. Install a `sesori-desktop` launcher and desktop/icon entries using
  normal package paths. Never replace the standalone `sesori-bridge` launcher.

Resolve from the installed executable, never cwd or a source-tree search. Packaged
builds require the matching bundle; a missing/mismatched helper produces actionable
repair/restart guidance, never a download or fallback to an arbitrary PATH bridge.
Keep explicit development override behavior available only to development builds.

Linux package replacement while the desktop is open is a real ordinary flow: the
on-disk helper can become newer than the running GUI. Check the immutable bundle
identity at the existing helper-resolution boundary before a new spawn. A mismatch
requires desktop restart, not mixed-version supervision. No file watcher, polling
loop, or second lifecycle owner. Document quitting before package upgrades; external
package-manager replacement is not Sesori's app-managed install-on-quit mechanism.

### 2. Signing, trust, and platforms

**macOS:** reuse the configured Developer ID identity only after verifying access and
suitability. Sign nested Mach-O executables, Flutter/plugin frameworks, updater
helpers, and bridge native libraries inside-out, then the app. Enable hardened
runtime with only demonstrated entitlements; App Sandbox stays disabled. Verify
Keychain access, browser OAuth, loopback control, PATH-installed tools, managed
runtime launch, and filesystem/TCC prompts in the signed app. Do not add blanket
entitlement exceptions to hide a failing plugin. Notarize, staple, and validate the
final downloaded/extracted artifact on a clean Mac without bypassing Gatekeeper.

**Windows:** qualify native x64/arm64 Flutter, plugins, installer, and updater first.
Prefer Inno Setup for the per-user EXE if the qualified updater supports that path.
Use timestamped Authenticode signing through an approved CA-backed service or
hardware-backed certificate. Check Azure Artifact Signing eligibility/access before
assuming availability; no certificate purchase or cloud provisioning in this PR.
Verify both installer and shipped owned PE binaries; audit third-party signatures
and redistribution licenses. SmartScreen reputation is separate from a valid
publisher signature: record first-download behavior, never promise zero warnings.

**Linux:** DEB architecture names are `amd64`/`arm64`; RPM names are `x86_64`/`aarch64`.
Determine runtime dependencies from the actual bundles, including GTK, libsecret/
Secret Service, tray support and native assets. Build against the oldest nominated
supported userland, not `ubuntu-latest` by habit. Sign APT Release/InRelease metadata
and its authenticated package hashes; sign RPM packages and repository metadata,
and enable both checks in installation instructions. Pin the repository key and
publish its fingerprint through the project documentation. No `trusted=yes` or
signature-verification bypasses. GNOME without a tray host must stay reachable;
KDE/StatusNotifier and Wayland/X11 behavior receive explicit coverage.

### 3. App-managed updates and Quit

Keep ownership narrow:

- Layer 0 `AppUpdater` exposes typed native capability, progress/state, and prepared
  installation/termination handoff; native adapters live in `client/desktop`.
- Layer 1 `AppUpdateApi` wraps the adapter; Layer 2 `AppUpdateRepository` maps native
  outcomes into sealed desktop-domain states and retains useful typed causes.
- Layer 3 `DesktopUpdateService`, in
  `client/module_desktop_core/lib/src/services/desktop_update_service.dart`, owns
  update state, preparation policy, and prepared-install handoff decisions over
  `AppUpdateRepository`. Background startup, native callbacks and both terminal
  intents enter this one update pipeline. It never calls another service, stops
  the helper, writes bridge intent, or creates its own process-restore mechanism.
- The existing Layer 4 `BridgeControlCubit` remains the serialized terminal-quit
  owner. It consumes service state for presentation, sequences its existing process,
  instance, window and tray collaborators, and invokes a typed post-stop operation
  on `DesktopUpdateService` for normal Quit or Install and restart. Update policy
  stays in the service; helper-stop authority stays in `BridgeProcessService`.
  No second stop path, service-to-service dependency, or cubit dependency is added.
- Native callbacks marshal events onto the supported Flutter/native thread seam,
  through API/repository into `DesktopUpdateService`. They never independently kill
  the GUI/helper or start an installer. Unavailable Linux app-managed updating is
  a typed capability, not a fake success from a no-op updater.
- DI: register the shell `AppUpdater` adapter in desktop phase 1, then `AppUpdateApi`,
  `AppUpdateRepository`, and `DesktopUpdateService` in
  `configureDesktopCoreDependencies` (phase 4). Keep the current four-phase order;
  the shell's `BlocProvider` constructs the cubit, which is never DI-registered.

The normal path is:

1. After local startup, `DesktopUpdateService` starts the native updater's own
   background check/preparation and consumes its typed outcomes; no splash network
   wait or duplicate Dart polling timer. The cubit projects prepared/failed service
   state without recreating policy or exposing raw errors to remote telemetry.
2. Close-to-tray leaves the application and helper running. A prepared update must
   not turn close-to-tray, logout, Bridge Off, or a helper crash into installation.
   On a host without a tray, close already means safe application Quit and qualifies.
3. On explicit normal Quit, use the existing cubit command lock, cancel pending
   restore, and await the existing expected-stop process service. If helper stop
   fails, refuse quit and installation while leaving controls recoverable.
4. Only after helper teardown succeeds does the cubit invoke the update service's
   post-stop terminal operation. The service determines whether a fully verified
   prepared update can receive native install-on-exit handoff and returns a typed
   outcome. The cubit finishes bounds/native-surface teardown and termination via
   the same terminal flow. Normal Quit does not relaunch; Install and restart does.
   Relaunch uses ordinary startup/last-On restoration, not a new restart journal.
5. If no update is prepared, the service returns the normal-exit outcome; do not wait
   for a network download on quit. A failed update handoff remains observable and
   must not brick the current install or make quitting depend on successful update
   work. Native updater recovery owns interrupted replacement and retains a runnable
   install; no duplicate Dart rollback mechanism is added.

Sparkle's ordinary background configuration may attempt installation without an
explicit quit on some paths; intercept its supported delegate/lifecycle seam so the
chosen policy is enforced. Do not assume `SUAutomaticallyUpdate` alone proves it.

WinSparkle's documented shutdown-request callback occurs **after launching the
installer** and can run off the main thread. Merely binding that callback to
`quit()` violates the required ordering. Step 2 must prove authenticated background
preparation, retained installer lifetime, and host-controlled delayed installation
through supported APIs. If unavailable, stop and propose one maintained replacement
with its signing model and approximate integration cost; do not construct a custom
updater or weaken D6 to make WinSparkle fit.

Update archives require updater-native signature verification in addition to HTTPS
and OS code signing. Checksums downloaded from the same mutable feed are not an
independent trust anchor. Keep signing keys out of public storage; refuse altered
payloads and unauthenticated redirects/downgrades. Retain existing wire compatibility
for public phone/bridge peers; do not invent compatibility shims for unpublished
internal desktop builds or migrate their disposable GUI preferences.

### 4. Publication and release isolation

Add a desktop-owned `desktop-release.yml` with explicit immutable ref, channel, and
platform inputs and reusable platform build legs. It must not depend on mobile
store jobs, move `internal-release-attempt`, or change the existing mobile/CLI
finalizer's success conditions. PR packaging CI has no signing/publication secrets;
manual trusted release jobs use protected environments and least-privilege OIDC
where supported. Preserve source revision versus workflow revision deliberately
when reusing actions for older refs.

- Artifact identity includes semantic version, build number, source SHA, platform,
  architecture, digest, and signing evidence. Both architectures in a platform leg
  use the same identity. Extend desktop version/bundle checks without making a
  desktop signing outage block mobile/CLI release.
- Use separate `desktop-vX.Y.Z-internal.N` / `desktop-vX.Y.Z` tags and explicit desktop
  asset names. Set GitHub releases `--latest=false`; do not move a published tag or
  overwrite a published stable artifact. Verify legacy bridge selectors ignore the
  new tags, including generic GitHub latest-release behavior.
- Internal feeds reference only internal desktop builds; stable feeds reference only
  approved stable artifacts. A stable build uses the tested source SHA and clean
  version, following the existing bridge production rebuild precedent; an internal
  binary with a prerelease version is not silently relabeled as stable. Reverify the
  actual stable signed package before publication. Do not claim byte-for-byte
  promotion when version baking/signing rebuilds the artifact.
- Upload immutable payloads and versioned metadata first, verify their public HTTPS
  retrieval and signatures, then publish each channel entry point last. Serialize
  publication to that platform/channel using workflow concurrency and conditional
  object writes. GCS has atomic object replacement, not an atomic multi-object
  transaction: APT by-hash/versioned indexes and immutable RPM metadata must keep
  readers valid across the switch. Retain referenced old artifacts through upgrades.
- Linux repository payloads live alongside signed repository metadata in GCS; the
  same DEB/RPM bytes can also be downloadable GitHub release assets. Do not make
  package managers depend on user-specific tokens or expiring download URLs.
- Failed signing, notarization, architecture builds, or repository publication leaves
  that platform's previous feed usable and blocks its promotion, not another product.
  Manual retries reuse completed immutable artifacts where valid; stable corrections
  require a new version instead of clobbering delivered bytes.

Document the GCS bucket/endpoint, protected environments, certificate ownership,
renewal/expiry recovery, Windows signing eligibility, and Linux/updater public keys.
These are execution prerequisites, not permission to copy private keys into Git or
provision billable resources during planning. Do not add staged rollout percentages,
a key-rotation service, or a custom release catalog API.

### 5. Installation, removal, and user-facing discovery

- Keep app/helper binaries desktop-owned. Shared `token.json`, managed harness roots,
  bridge databases/session history, provider credentials, and user projects survive
  desktop uninstall. Uninstall is not account deletion or global logout.
- Windows uninstall removes desktop binaries, shortcuts, and its login registration;
  it must not auto-kill an active supervised workload without user consent. Linux
  package removal owns system files only; it must not walk home directories or
  execute the GUI as root. Retained per-user autostart residue after Linux removal
  is an accepted low-damage limitation, with documented user-level removal.
- macOS DMG removal is not an installer uninstall hook. Document Quit, disable login
  launch, remove the app, and optional desktop-only data cleanup. Do not add a root
  uninstall daemon or reset feature solely for cosmetic preference residue.
- Publish one documented download index pointing only at platforms that passed their
  gates. Add winget manifests after the stable Windows assets exist; manifest approval
  is an external prerequisite, not proof supplied by an EXE build.
- Update phone onboarding with the desktop installation path only when its published
  link works, retaining the standalone CLI route and honest unshipped-platform copy.
  Inspect the add-analytics skill and existing onboarding events at that step; reuse
  approved authoritative instrumentation if applicable, otherwise record no new event.
  Distribution alone does not justify replacing desktop's current local-only adapters.

## Delivery steps

Every PR uses the exact title below. Estimates count authored plus generated
additions/deletions against the merge base; aim below 1,500 total and substantially
lower for update/lifecycle work. If qualification changes scope or a clean split is
needed, update this single sequence, dependencies, tracker, and total before pushing.
No generated-churn exception is assumed in advance.

| Step | Exact PR title | Dependency / scope, risk and expected result |
|---|---|---|
| 1 | 🌿 [desktop-distribution] Align platform distribution and update plan [step 1/12] | This plan, tracker, parent handoff, roadmap/vision links. Low risk; docs/link consistency only. No user-visible or database change. |
| 2 | ⚙️ [desktop-distribution] Qualify six-target packaging prerequisites [step 2/12] | After 1. Bounded native build/plugin/updater probes and repeatable package qualification tooling; freeze bundle layout, updater APIs, OS minimums, runner sources and signer prerequisites. Test Windows delayed install before selecting its engine. Medium risk; no publication or database change. Block affected platform on a failed capability, not the whole research effort. |
| 3 | ⚙️ [desktop-distribution] Bind desktop builds to bundled bridge identity [step 3/12] | After 2's bundle qualification. Packaged resolver, complete helper/native assets, immutable typed build identity, version sync and focused tests. Medium risk at startup/version boundaries. Installed/dev behavior separates cleanly; no database migration or download fallback. |
| 4 | 🚧 [desktop-distribution] Package and notarize native macOS builds [step 4/12] | After 3 plus signer access. Two DMGs and update archives, nested hardened signing, notarization/stapling, packaged Keychain/TCC/autostart probes. High supply-chain/platform risk. Both Macs install and run without Gatekeeper bypass; no database change. |
| 5 | 🚧 [desktop-distribution] Apply macOS updates through safe application quit [step 5/12] | After 4. Narrow updater layers, Sparkle adapter, existing Quit owner integration, signed N→N+1 fixtures and failure tests. High lifecycle risk. Background prepare; normal Quit installs without relaunch, explicit restart restores intent. No new database or separate supervisor state machine. |
| 6 | ⚙️ [desktop-distribution] Publish isolated desktop channels and macOS downloads [step 6/12] | After 5 and parent public-release prerequisite. Trusted manual workflow, GitHub desktop tags, GCS feed staging, download index/runbook, release-isolation tests and macOS ship gate. High operational risk but bounded publication logic; no mobile store uploads or database change. macOS public only after both native gates pass. |
| 7 | 🚧 [desktop-distribution] Package signed per-user Windows installers [step 7/12] | After 3 and Windows qualification; delivered after macOS gate. Native x64/arm64 EXEs, complete helper bundle, timestamped signing, shortcuts/autostart/uninstall and clean-host tests. High installer/trust risk. No elevation for normal use, no shared CLI data deletion, no database change. |
| 8 | 🚧 [desktop-distribution] Deliver quit-installed Windows updates and winget discovery [step 8/12] | After 6 and 7. One qualified native updater, reuse shared quit policy, signature-verified N→N+1 update, channel publication, winget manifests and Windows ship gate. High lifecycle risk; no installer-before-helper-stop or surprise restart. No database change. |
| 9 | ⚙️ [desktop-distribution] Publish signed native DEB and RPM repositories [step 9/12] | After 3 and Linux qualification; delivered after Windows gate. Four native packages, dependency manifests, signed APT/RPM metadata/payload publication, desktop integration and Linux ship gate. Medium/high packaging risk; no custom updater or privileged per-user cleanup. Package-manager upgrades retain shared data; no database change. |
| 10 | 🌿 [desktop-distribution] Offer shipped desktop downloads during onboarding [step 10/12] | After all platform gates. Shared mobile installation guidance and published links, preserve CLI alternative and truthful platform/CPU choices. Low/medium onboarding regression risk; focused UI/link tests and existing analytics assessment. New installation choice, no database change. |
| 11 | 🌿 [desktop-distribution] Reconcile distribution regression coverage [step 11/12] | After 10. Complete affected feature documents and installation/release runbooks, remove superseded dev-only guidance where behavior changed. Low risk; no runtime or database change. |
| 12 | ⚙️ [desktop-distribution] Verify six-target releases and retire distribution plan [step 12/12] | After 11. Run/assemble the complete recorded release matrix through packaged/external boundaries, record exact artifacts and evidence, resolve failures, then move this directory to `.plan/completed/desktop-distribution/` and repoint live links. No runtime/database change except independently reviewed required fixes. Never retire partial/blocked coverage. |

Step 2's platform qualification results may be gathered independently; there is no
requirement to keep one expensive test machine idle until another OS finishes. PRs
remain a coherent sequential series, with one writer in the task's existing worktree.
This plan does not authorize new worktrees or parallel release publication.

## Verification and release gates

### Qualification matrix to freeze in step 2

Each row requires a native runner/host and an exact pinned image/toolchain record.
Provisional OS baselines below are planning targets, not already-supported claims;
confirm against the pinned Flutter build and bundled native dependencies before
advertising minimum versions. If a proposed baseline is unavailable, record the
blocker and ask before reducing coverage rather than substituting emulation.

| Platform | Native CPU matrix | Required host variation |
|---|---|---|
| macOS | arm64, x64 | Supported minimum OS established from Flutter/native dependencies and latest OS available for each CPU; notarized downloaded install, Keychain/TCC and login launch. |
| Windows | x64, arm64 | Windows 11 native hosts; native GUI/plugins/helper/updater, standard user account, clean download reputation observation, paths with spaces/non-ASCII. Windows 10 is not implicitly claimed. |
| Linux DEB | amd64, arm64 | Ubuntu 24.04 LTS and Debian 13 as nominated baselines, dependency resolution from clean systems, Secret Service present and unavailable behavior. |
| Linux RPM | x86_64, aarch64 | A named supported Fedora stable release pinned during qualification, clean dependency resolution. Do not claim every RPM distribution. |
| Linux desktop environment | Both CPUs represented in the Linux rows | GNOME without tray host, a functioning StatusNotifier/KDE host, Wayland and X11 where supported. Record the CPU/environment mapping explicitly before execution. |

All six CPU/OS pairs receive the full packaged functional path; all four Linux
package variants additionally receive native install/update/remove tests on their
nominated distribution rows. No cross-product explosion over every harness and
every desktop environment: representative selection is justified per invariant.

### Level and authoritative boundaries

- **L5 for affected desktop distribution and supervision capabilities**, including
  cumulative applicable lower-level entries and the matrix above. Distribution is
  materially packaged/external work; L3 dev-build evidence is not a substitute.
- Preserve the parent cockpit/mobile release evidence. Run applicable L1–L3 shared
  cockpit/onboarding regressions for behavior touched here; do not rerun every
  unrelated plugin feature merely because this plan is a release workstream.
- Add `docs/regression/desktop-distribution.md` when the first distribution behavior
  lands; update `desktop-bridge-supervision.md`, `bridge-installation-and-updates.md`,
  `account-and-onboarding.md`, `plugin-runtime-installation.md`, and the index as their
  behavior changes. Reconcile all in step 11; do not describe unshipped work as live.
- Plugin scope: representative for backend-neutral supervision; one eligible plugin
  per exercised managed-install/login capability and platform. On every native target,
  prove packaged helper → real harness execution against both a PATH-installed and
  a managed runtime where supported. Enumerate every bundled native dependency and
  its platform support; record verified harness gaps in `docs/HARNESS_CAPABILITIES.md`.

### Required evidence per platform gate

1. Install from the actual downloadable signed artifact on a clean standard-user
   machine without Flutter/Dart or a Sesori source checkout. Verify GUI/helper
   identity and architecture, native assets, signature chain and platform trust.
2. Browser login → supervised helper → relay → real harness → desktop chat; verify
   existing phone coexistence and standalone CLI contention without deleting either
   installation's credentials, runtimes, or session state.
3. Login launch with last-On and last-Off, close-to-tray/no-tray behavior, single
   instance, native notifications/activation, helper restart, and normal Quit.
4. macOS/Windows: authentic signed N→N+1 upgrade with helper On and Off; background
   preparation while work is active; normal quit versus explicit restart; pending
   download, refused helper stop, altered archive, updater handoff failure, and
   interrupted native apply/recovery. Prove the actual native framework ordering,
   not only fake Dart callbacks. Normal quit must not reopen the application.
5. Linux: trusted APT/DNF install and N→N+1 update, metadata/key/payload tampering
   refusal, open-app package replacement requiring restart before mismatched helper
   spawn, and native remove/reinstall. Package scripts never launch the GUI as root.
6. Shared CLI data, projects and session history survive uninstall/reinstall. Desktop
   login entries/shortcuts obey the documented per-platform ownership limitations.
7. Forced failed desktop leg/signature/feed publication leaves the previous channel
   valid and does not trigger or block mobile/CLI jobs. Stable never selects an
   internal desktop build; existing bridge installers still select bridge releases.
8. Public GitHub downloads, GCS updater feeds and signed Linux repositories work
   without authentication. winget discovery is verified through its actual external
   manifest/install path; record an unapproved manifest as blocked, not passing.

Use current native N and N+1 test builds before the first public desktop release;
there is no obligation to migrate unpublished desktop builds. Once a public version
ships, include it as the upgrade baseline. Same-version metadata corruption does not
justify silently replacing immutable public artifacts.

Per-platform ship gates can release ready platforms while later ones remain blocked.
Final retirement requires all recorded targets and package variants. Missing Windows/
Linux hosts, credentials, store/package approvals, or toolchains are **Blocked**, not
an accepted reduction. Any reduction requires explicit user acceptance in this file.
Record privacy-safe artifact IDs/digests, build SHA, actual OS/CPU, package/updater
versions, outcomes, and cleanup; keep raw account/project/log content out of Git.

## Complexity budget, safeguards, and accepted limits

New mutable parts are limited to one native updater instance per supported app,
one update-state subscription/projection owned by `DesktopUpdateService`, and an
explicit terminal action (normal Quit versus Install and restart) within the existing
serialized Quit owner. Cubit presentation derives from the service's state, with no
second pending-update record. Native frameworks own their download cache, scheduling,
staging, and recovery. Add
no parallel Dart cache, durable pending-update record, timer, update lock, process
registry, shutdown journal, or new database table. The immutable bundle manifest
exists to bind shipped GUI/helper identity, not to coordinate running sessions.

Release state is bounded to immutable artifacts/tags, signed channel/repository
entry points, and existing CI concurrency plus object-generation preconditions.
Each channel pointer exists to publish an authoritative release, not to reconstruct
user intent. No release backend or general-purpose deployment framework.

| Safeguard | Evidence and consequence if omitted |
|---|---|
| Complete helper bundle and identity check | Observed dev-only path and native CLI assets; ordinary packaged launch or package upgrade otherwise fails or starts a mismatched helper. |
| Expected-stop before native install handoff | Ordinary update with bridge On; Windows files can remain locked and existing supervisor can respawn into replacement. Reuse today's owner. |
| Cryptographic release/update verification | Ordinary remote software delivery crosses an executable-code trust boundary; unauthenticated substitution compromises developer machines. |
| Immutable payloads and metadata-last publication | Ordinary partial upload/failing architecture; otherwise clients can discover incomplete or inconsistent releases. |
| Clean native host and signed-artifact testing | Existing evidence is dev-built/three-runner CI; native plugins, permissions and package dependencies are platform-specific. |
| Shared-state-preserving uninstall | Standalone CLI and desktop use shared bridge state; broad deletion loses user sessions/credentials. |

Accept: updates wait indefinitely while an app stays open; no forced security-update
restart policy is invented. OS logout/reboot/crash is not guaranteed to install a
prepared update. Native package managers can replace files outside Sesori's control;
there is no custom root watchdog or multi-user shutdown protocol. Keep harmless
user-level preference/autostart residue where removing it would require broad home
scanning. No hypothetical filesystem locks or extra daemon for those cases.

## Cleanup and remaining execution decisions

- Replace the packaged branch of development-only resolver guidance while preserving
  genuine development support; remove stale superseded-plan comments in touched
  entitlements/workflows. No compatibility migration for unpublished GUI state.
- Reuse complete bridge archives/build tooling and existing supervision semantics;
  do not duplicate harness installation or the standalone self-updater in desktop.
- Remove obsolete "desktop not distributed" onboarding copy only when the target
  download exists. Keep the standalone CLI installation path and release cadence.
- No broader architecture cleanup is justified by this plan. If native integration
  would require substantial unrelated refactoring, quantify it and ask first.

Execution blockers to resolve in step 2: native six-target Flutter/plugin build route
(particularly Linux ARM64), exact OS minimums/VM ownership, Windows deferred-update
engine and signer, macOS notarization/updater signing access, GCS bucket/publication
permissions and public keys. Record chosen tool versions and identities, never
private material. The user's all-six-target decision remains binding while blocked.

## References

- [Parent implementation plan](../desktop-app/PLAN.md) and [tracker](../desktop-app/TRACKER.md)
- [Regression proof and retirement rules](../../../docs/regression/README.md)
- [Apple distribution](https://developer.apple.com/macos/distribution/)
- [Sparkle integration/signing](https://sparkle-project.org/documentation/) and
  [automatic-update customization](https://sparkle-project.org/documentation/customization/)
- [WinSparkle lifecycle callbacks](https://winsparkle.org/c-api/callbacks/)
- [Windows distribution paths](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/choose-distribution-path)
  and [SmartScreen reputation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)
- [Flutter desktop support](https://docs.flutter.dev/platform-integration/desktop)
- [Flatpak host-access constraints](https://docs.flatpak.org/en/latest/sandbox-permissions.html)
- [GCS static hosting and HTTPS constraints](https://cloud.google.com/storage/docs/hosting-static-website)
