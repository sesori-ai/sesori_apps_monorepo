# Desktop Distribution — Signed Native Installers And Updates

## Status and goal

- **Slug:** `desktop-distribution`
- **Date:** 2026-09-15
- **Status:** Active — steps 1–5 and the private portions of steps 6, 7 and 9
  merged. The macOS signing-secret migration is complete. Main-only run
  `35411687826` accepted private signed helper-Off `1.8.4+24 → 1.9.0+62`
  replacement on native x64 and arm64, including exact pre-Quit helper absence.
  A credential-scoped successor is implementing authenticated helper-On/Keychain
  replacement qualification; no authenticated result is accepted yet. Failed-stop,
  interactive user-account/TCC, minimum-OS and public gates remain open. Public
  macOS/Windows/Linux publication and step-8 winget assets remain gated. Step 10 onboarding waits for genuine shipped
  releases. The independently executable private portion of step 11 is in progress;
  its public-release reconciliation and final plan retirement remain blocked. Shipping
  order remains macOS, Windows, Linux. No blocked publication step is claimed completed.
- **Continuation (user-approved 2026-09-15):** start step 2 automatically after the
  plan PR merges, using `sesori-plan-worker`; thereafter keep one series PR open
  and at most one successor step local. Preserve explicit decision and release gates.
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Delivery:** 14 planned PRs; original steps 3 and 4 are split into 3.a/3.b and 4.a/4.b. Exact titles below.
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

[Desktop UX](../../completed/desktop-ux/PLAN.md) is a parallel workstream, merged into `main`
during this plan's review. It owns cockpit/navigation, autostart defaults, permission
UX and app logging; distribution owns signing/Keychain identity, packaging and
updates. Keep those responsibilities separate and integrate against its current
startup/control surfaces before steps 3–5, rather than restoring superseded UI or
first-run behavior. Follow the parent's updated Gate C routing: shell/navigation
C2/C5 move to the UX step-12 checklist; the other parent sections remain applicable
on a build after UX step 7. A merged UX plan is not passing coverage evidence.
Its 2026-09-19 retirement accepts remaining QA gaps; it does not qualify these distribution gates.

### Unattended execution direction — 2026-09-15

The user directed completing the implementation series without further questions:
never stop the running bridge (including indirectly through the local desktop),
run every safe autonomous check, and collect checks needing user help for the
final handoff. Fresh native CI is approved for both Mac QA targets. Do not wait
for human QA, unavailable signing/hosting access or interactive permission decisions
before continuing independent approved implementation. Record those limits rather
than inventing credentials, provisioning infrastructure or claiming unexecuted tests
passed. Platform ship gates continue to constrain public distribution, not progress
through the remaining implementation PRs. Public release and plan retirement still
require the recorded final matrix or an explicit end-of-plan acceptance of its limits.

## Decisions aligned with the user

| ID | Decision |
|---|---|
| D1 | macOS first, followed by Windows and Linux; independent platform ship gates. |
| D2 | All six native application targets: macOS, Windows, Linux × x64, arm64. User-approved exception (2026-09-15): the Windows ARM64 installer launcher may use emulation; installed GUI/helper/native libraries remain ARM64. No other silent reduction. |
| D3 | macOS: direct Developer ID distribution, hardened runtime, notarization, stapled DMGs, manual signed-package updates (D6 fallback). App Store sandboxing does not fit the current host-tool model. |
| D4 | Windows: direct download first, signed per-user Inno Setup EXE, manual Download update button, and winget discovery. No embedded Windows updater or automatic updates. Store/MSIX is not a launch requirement. |
| D5 | Linux: DEB and RPM packages with signed APT/RPM repositories. No AppImage, Flatpak, Snap, or custom Linux self-updater in this plan. |
| D6 | Trust, maturity, broad adoption, and simple integration outrank automation (user clarification 2026-09-15). The explicitly approved manual fallback is selected for macOS in step 5; Sparkle background preparation/install-on-quit is not part of the implementation. No custom updater, security layer, or shutdown machinery just to preserve automation. Windows uses manual signed-installer updates; Linux remains package-manager-owned. Ordinary Quit never unexpectedly reopens the app. |
| D7 | GitHub Releases hosts downloadable installers; static GCS hosts signed Linux repositories. No new backend release service. Linux repositories also host their package payloads, rather than relying on cross-origin package-manager redirects. |

### Proposed implementation defaults

These are design choices in this plan, not claims that the user separately selected
each detail. Change them if the qualification evidence requires it; ask before
changing user intent, adding material infrastructure, or reducing the matrix.

- Bundle the same-commit, matching-architecture bridge and all native assets with
  the GUI. Use separate architecture artifacts rather than inventing universal
  Dart/native-asset bundles. Harness runtimes remain installed on demand through
  existing plugin management; PATH-installed harnesses retain precedence.
- Keep shared product semantic versioning, adding desktop to `tool/sync_versions.dart`.
  Desktop release attempts have their own build number, tags, download indexes, and publication
  gate; they never query TestFlight/Play to obtain a desktop build number.
- Start with explicit internal and stable desktop release dispatches. No new hourly
  scheduler, release database, rollout service, or automatic stable promotion.
- Stable is the installed default. Internal testing is an explicit separate download/
  repository selection; do not build an in-app channel-switching feature now.
- Use mature distribution tooling, not a new archive downloader/swap/rollback engine.
  macOS and Windows use explicit download links and normal Quit before installing;
  Windows uses Inno Setup. No Sparkle, WinSparkle or Velopack is embedded.
  Manual updates are an approved simplification, not a missing automatic capability.
  Verify authenticity and safe replacement regardless of who initiates the update.
- Use GCS's standard HTTPS object endpoint initially. A branded HTTPS hostname
  needs an existing front door or separately approved TLS/load-balancer/CDN setup;
  a bucket CNAME alone does not provide custom-domain HTTPS.
- Retain local diagnostics. No remote crash reporting, new desktop analytics SDK,
  unattended data upload, or new product-event taxonomy as part of distribution.

## Current behavior and code anchors

Verified against the implementation checkout, not inferred from the superseded proposal:

- `client/desktop` is the thin Flutter shell; `client/module_desktop_core` owns
  supervision and lifecycle policy. Shared cockpit logic remains in `module_app_ui`
  and `module_core`; desktop never imports bridge-workspace implementation code.
- `DesktopBridgeExecutablePathResolver` binds release helpers to the GUI's compiled
  `DesktopBundleIdentity`, resolving only from the installed executable. Debug/profile
  retains `SESORI_DESKTOP_BRIDGE_PATH` and the repository helper path.
- `BridgeControlCubit.quit()` already locks controls, cancels pending restore, awaits
  `BridgeProcessService.stop()`, then disposes tray/window state and terminates.
  Failed helper stop leaves the app alive. Quit preserves last-On/Off intent.
- `IoLaunchAtLogin` records the exact executable path in a macOS LaunchAgent,
  Windows HKCU Run value, or Linux autostart desktop entry. Installed paths and
  packaged quit/update behavior therefore require real testing, not just new archives.
- No desktop updater implementation exists; `AppUpdater` references in module
  instructions describe an intended seam, not delivered code.
- Desktop, mobile and bridge product semver is `1.8.4`. `tool/sync_versions.dart`
  includes desktop while preserving its own build suffix; no desktop publication
  workflow exists yet.
- `desktop-ci.yml` remains source CI. The separate targeted/manual qualification
  workflow passed all six native rows in step 2 and now exercises the unsigned
  identity-bound staging producer. Neither workflow signs or publishes products.
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
builds both components from one committed checkout, serializes that model into
`desktop-bundle.json` in macOS `Contents/Resources` (the signed app's data location),
or at the Windows/Linux helper bundle root, and supplies the same identity through
an explicit Flutter dotenv build-define file. Keep JSON out of macOS's code-only
Helpers subtree; native signing qualification established this placement. It enforces dependency locks, preserves
native assets/symlinks and records host-generated Git changes. No suitable existing
client OS/CPU set covers these targets; the closed desktop-only enums stay beside
the model. The existing shell
`DesktopBridgeExecutablePathResolver` reads and validates the manifest against the
GUI's compiled identity before returning a helper path to the process API. Its
existing development branch remains separately testable. Export the model from
desktop core only; neither `module_core` nor `sesori_shared` acquires this contract.
This is an immutable build artifact, not a database, client/bridge wire contract,
or mutable runtime registry.

Step 3.a supplies the typed refusal and local diagnostics. Immediate successor 3.b
(~250–400 authored lines) makes the refusal actionable before any installer work:
- Add a `BridgeExecutableResolutionException` interface with safe `userMessage` in
  the existing foundation resolver file; the shell's `DesktopBridgeBundleException`
  implements it while retaining its diagnostic `innerError`.
- Add immutable `BridgeProcessStartFailed(message)` in the existing process-state
  file. After existing startup cleanup, the process service publishes it only for
  this typed refusal when no helper remains; retain original rethrow/exit ownership.
  The existing automatic-start observer logs this refusal without replacing its
  repair state with crash backoff (observed on the helper's exit-86 restart path).
- Existing cubit/tray and cockpit notice derive repair guidance from that state.
  Update exhaustive consumers and explicit retry behavior. Hidden startup remains
  non-modal; no forced window. Do not offer child logs for an unspawned helper in
  the refusal notice. Other startup failures keep their existing behavior.
- Test no spawn, cleanup, retained guidance, subsequent valid start, and shared
  tray/window rendering. No new mutable field, tracker, subscription, timer,
  persistence, lifecycle owner, wire contract, or analytics event.

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
package-manager replacement is not an app-managed install-on-quit mechanism.
Installers own complete/authentic packages; sidecar comparison is not a filesystem
transaction or tamper detector. Do not add per-spawn digests for partial file writes
or fractional-number guards for manually edited manifests: the producer emits ints,
and these cases do not justify new machinery under the approved simplicity policy.

### 2. Signing, trust, and platforms

**macOS:** reuse the configured Developer ID identity only after verifying access and
suitability. Sign nested Mach-O executables, Flutter/plugin frameworks, updater
helpers, and bridge native libraries inside-out, then the app. Enable hardened
runtime with only demonstrated entitlements; App Sandbox stays disabled. Verify
Keychain access, browser OAuth, loopback control, PATH-installed tools, managed
runtime launch, and filesystem/TCC prompts in the signed app. Do not add blanket
entitlement exceptions to hide a failing plugin. Notarize, staple, and validate the
final downloaded/extracted artifact on a clean Mac without bypassing Gatekeeper.

**Windows:** qualify native x64/arm64 Flutter, plugins and helper first. Use the
stable Inno Setup release for the per-user EXE; its launcher may run via emulation
on ARM64 with the user's explicit approval. Test that installer on a native ARM64
host, but never call the launcher an ARM64 executable. The user has no Windows ARM
QA device; native CI builds do not substitute for interactive release QA.
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

### 3. Platform update paths and Quit

**Windows manual path:** Settings exposes **Download update**, opening the official
Windows download page for the installed channel/architecture through the existing
URL-launching abstraction. No startup checks, Dart/native update cache, comparison
service, installer subprocess, update keys or post-stop handoff exists on Windows.
The page tells users to Quit normally (not close to tray), then run the signed
installer. Inno Setup refuses install/uninstall while the GUI is running using its
supported `AppMutex` seam; disable forced close and automatic restart. The mutex
exists only for the GUI process lifetime and is not a second supervisor or restore
journal. Safe normal Quit remains the existing helper-stop path. Repeat installation
updates the same desktop-owned files; shared CLI state survives. OS signature trust
and the documented publisher must be verified; do not call a web link an in-app
signature-verifying updater. winget remains a separate package-manager update path.

**macOS manual path (D6 fallback selected in step 5):** Settings opens the official
channel/CPU download page at `https://sesori.com/desktop/` through the existing
external-link seam. The page is live with every row an unshipped placeholder;
publication availability remains a release gate. The user Quits
normally, verifies the signed/notarized published package, replaces the complete
app and reopens it manually. Close-to-tray is not Quit; failed helper stop refuses
Quit and users must not replace the running installation. No automatic checks,
prepared-update state, native installer handoff or relaunch is introduced.

The shell resolves compiled bundle identity and a separate stable/internal channel
into an immutable `DesktopUpdateDestination` value from desktop core. Shell composition
owns build decoding and package/link selection, then passes the result to
`DesktopUpdateSection`; its action only opens the website. Linux presents
package-manager guidance and source builds present development guidance. Unshipped index entries contain no artifact links. The
concrete files/data flow and approved review are in [step 5](steps/step-05.md).

The Sparkle 2.10.0 probe remains historical API qualification, not an embedded
updater. Its integration would require native termination and restart coordination
beyond the existing `dart:io.exit` seam. The user explicitly accepts manual updates
instead. Remove unused proposed updater layers rather than implement dummy APIs,
services, subscriptions or terminal-action variants. OS package trust and publisher
verification remain mandatory; the download link does not verify an installer.
Native signed N→N+1 manual replacement and preservation are still release gates.

### 4. Publication and release isolation

Step 6 first delivers private read-only preparation as described in
[step-06](steps/step-06.md). Public publication remains blocked on the prerequisites
below; merging preparation does not clear the macOS ship gate.

Add a desktop-owned `desktop-release.yml` with explicit immutable ref, channel, and
platform inputs and reusable platform build legs. It must not depend on mobile
store jobs, move `internal-release-attempt`, or change the existing mobile/CLI
finalizer's success conditions. PR packaging CI has no signing/publication secrets;
manual trusted release jobs use protected environments and least-privilege OIDC
where supported. Private qualification now uses the owner-approved `macos-signing`
environment, which admits `main` with no reviewer or wait gate so routine CLI signing
remains automatic.
All five repository-level copies are removed after post-deletion native proof; shared
reusable callers use reviewed inheritance while TestFlight/Android credentials remain
separate. Desktop publication still requires a different human-approved environment.
Preserve source revision versus workflow revision when reusing actions for older refs.

- Artifact identity includes semantic version, build number, source SHA, platform,
  architecture, digest, and signing evidence. Both architectures in a platform leg
  share only the release version/build number/source SHA; each artifact has its own
  complete identity, architecture, digest and signing evidence. Feeds select and
  verify that specific artifact. Extend desktop version/bundle checks without making
  a desktop signing outage block mobile/CLI release.
- Use separate `desktop-vX.Y.Z-internal.N` / `desktop-vX.Y.Z` tags and explicit desktop
  asset names. Set GitHub releases `--latest=false`; do not move a published tag or
  overwrite a published stable artifact. Verify legacy bridge selectors ignore the
  new tags, including generic GitHub latest-release behavior.
- Internal download entries reference only internal desktop builds; stable entries reference only
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
  that platform's previous download index/repository usable and blocks its promotion, not another product.
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
No generated-churn exception is assumed in advance. Step 3.a is independently
buildable/verified; 3.b supplies user-facing repair state before installers. Stable
step IDs are 1, 2, 3.a, 3.b, 4.a, 4.b, 5…12; PR ordinals are respectively 1…14.
Step 4.a delivers verified private packaging; 4.b fixes the independently exposed
native-attention startup wait before updater work. That split preserves published
history and keeps lifecycle changes out of the package-signing review.

| Step | Exact PR title | Dependency / scope, risk and expected result |
|---|---|---|
| 1 | 🌿 [desktop-distribution] Align platform distribution and update plan [step 1/14] | This plan, tracker, parent handoff, roadmap/vision links. Low risk; docs/link consistency only. No user-visible or database change. |
| 2 | ⚙️ [desktop-distribution] Qualify six-target packaging prerequisites [step 2/14] | After 1. Bounded native build/plugin/updater probes and repeatable package qualification tooling; freeze bundle layout, updater APIs and concrete adapter/DI/dependency graph, OS minimums, runner sources and signer prerequisites. Qualify mature manual Windows installer replacement; retain macOS automation only if the supported integration stays small. Medium risk; no publication or database change. Block affected platform on a failed capability, not the whole research effort. |
| 3.a | ⚙️ [desktop-distribution] Bind desktop builds to bundled bridge identity [step 3/14] | After 2's bundle qualification. Packaged resolver, complete helper/native assets, immutable typed build identity, version sync and focused tests. Medium risk at startup/version boundaries. Installed/dev behavior separates cleanly; no database migration or download fallback. |
| 3.b | ⚙️ [desktop-distribution] Surface packaged helper repair guidance [step 4/14] | After 3.a. Existing service/state/cubit/window flow retains typed startup refusal without a new lifecycle owner. Medium startup/presentation risk; no PID fabrication, forced hidden-startup modal, database or wire change. |
| 4.a | 🚧 [desktop-distribution] Package and notarize native macOS builds [step 5/14] | After 3.b plus signer access. Private DMGs/ZIPs, nested hardened signing, notarization/stapling and native platform probes. High supply-chain/platform risk. Both Macs verify/install without Gatekeeper bypass; rendered startup is tracked in 4.b, not claimed passing. No database change. |
| 4.b | ⚙️ [desktop-distribution] Keep desktop startup independent of native notifications [step 6/14] | After 4.a. Existing attention owner installs listeners before returning, without holding rendering behind native readiness; retain initial-open/account/disposal handling. Medium/high startup risk. Red/green service tests and both signed GUI targets; no new state owner, persistence, wire or database change. |
| 5 | ⚙️ [desktop-distribution] Offer manual macOS updates through official downloads [step 7/14] | After 4.b. D6 manual fallback: immutable channel/CPU destination, honest download index, Settings guidance and staging channel metadata. Medium presentation/build risk; unchanged safe Quit, no automatic updater or database change. Native manual replacement remains a release gate. |
| 6 | ⚙️ [desktop-distribution] Prepare isolated desktop release channels [step 8/14] | Private preparation. |
| 7 | 🚧 [desktop-distribution] Qualify private per-user Windows installers [step 9/14] | After 3.b and Windows qualification. Independent private unsigned x64/arm64 installers, complete helper bundle, shortcuts, mutex refusal and isolated install/uninstall fixtures. Signing, timestamp/publisher verification and public delivery remain gated, including the prior macOS ship gate. High installer risk; no shared CLI data deletion or database change. |
| 8 | ⚙️ [desktop-distribution] Deliver manual Windows updates and winget discovery [step 10/14] | After 6 and 7. Settings download action, signed N→N+1 manual replacement, channel-specific downloads, winget manifests and Windows ship gate. Medium integration risk; no embedded updater, forced helper shutdown or automatic restart. No database change. |
| 9 | ⚙️ [desktop-distribution] Qualify private native DEB and RPM packages [step 11/14] | Independent private preparation after native bundle qualification. Four unsigned native packages, generated dependency manifests, desktop integration and isolated package-manager fixtures. Signing, public APT/RPM repositories and shipping remain blocked behind prior platform gates. No updater, home cleanup or database change. |
| 10 | 🌿 [desktop-distribution] Offer shipped desktop downloads during onboarding [step 12/14] | After all platform gates. Shared mobile installation guidance and published links, preserve CLI alternative and truthful platform/CPU choices. Low/medium onboarding regression risk; focused UI/link tests and existing analytics assessment. New installation choice, no database change. |
| 11 | 🌿 Private regression reconciliation (13/14) | Scope and exact PR title below. |
| 12 | ⚙️ Release verification and retirement (14/14) | Scope and exact PR title below. |

Step 6 delivered read-only private metadata/checksums in PR #1511 without publication.
Credential migration is complete, but parent and native/public ship gates still apply.

**Step 6 continuation PR:**
`🚧 [desktop-distribution] Qualify signed macOS manual replacement [step 8/14]`.
This credential-free continuation adds the private native replacement probe. It closes
only after reviewed tooling passes from `main`; no tag, release, website write or
database change is included.

**Step 6 tray-evidence correction PR:**
`⚙️ [desktop-distribution] Bind macOS upgrade Quit to tray popup [step 8/14]`.
The first main-only run showed that AppKit does not expose the transient tray menu as a
status-item child. The correction admits only a new process-owned AXMenu whose frame is
anchored to the pressed status item, then searches for Quit only inside that menu.

**Step 6 hit-tested-menu correction PR:**
`⚙️ [desktop-distribution] Bind macOS Quit to hit-tested tray menu [step 8/14]`.
The second main-only run found 16 pre-existing arm64 menu elements without a new
accepted popup, while broad traversal invalidated an x64 status-item reference. This
correction requires AXPress first, hit-tests beside the recorded status-item frame,
accepts only an anchored process-owned menu and searches for Quit only inside it.

**Step 6 status-bar hit-test correction PR:**
`⚙️ [desktop-distribution] Include status-bar menu in macOS hit test [step 8/14]`.
The third main-only run showed that application-scoped AX hit testing does not surface
the transient status-bar menu. The correction uses system-wide z-order hit testing but
still accepts only the exact PID's AXMenu anchored to the clicked status-item frame,
searching for Quit only inside that menu.

**Step 6 real-click correction PR:**
`⚙️ [desktop-distribution] Click real macOS tray target [step 8/14]`.
The fourth main-only run showed system-wide hit tests still saw only groups/windows,
confirming AXPress did not expose the custom-view popup. The correction sends one mouse
click to the verified process-owned 4–100 × 4–64 point frame within the top 80 points,
then retains the exact PID/AXMenu/frame/bounded-Quit admission checks. It merged as
`75a3e8c49be647ff663ea05207ed1badaa14db28`.

**Step 6 visible-window wait correction PR:**
`🌿 [desktop-distribution] Wait for macOS replacement window [step 8/14]`.
Two post-merge runs passed arm64 completely and reached current-package startup on x64,
but each x64 job failed at its only visible-window sample 15 seconds after launch. The
correction retries that read-only inspector for 45 additional bounded seconds, records
every attempt, and still refuses an exited process, inactive screen or final absence.
It merged as `305998d689d13051ac0fb58f9d970dfffe319bf0`.

**Step 6 accepted private helper-Off evidence:**
Main-only run `35405646668` accepted package trust, visible startup, actual tray Quit,
no post-Quit relaunch/orphan, persisted Bridge Off intent and bounded state
preservation, but did not inspect a live helper. The correction
`🌿 [desktop-distribution] Observe helper-Off during macOS replacement [step 8/14]`
merged in PR #1546 as source `8d99cd2925c9866dc121323ed348b0d130bc6aca`, tree
`777f3a353ff04eaeab29f6a6ff3f81e514b04cf1`. Main-only run `35411687826` passed
tooling job `105812432480`, x64 job `105812464127` and arm64 job `105812464132`.
Evidence artifacts `10574093842` (x64, digest
`sha256:a2016249efcc4aa3edda7d6a5e0097a1e5904c15cd78975bb8437fb7e055a6a2`) and
`10574368671` (arm64, digest
`sha256:ff848668381813e9318d97a572eb3520f4c6267b0bb39d8abb668f486d2a207e`) expire
2026-10-03. Both prior/current `*-helper-off.log` files on both CPUs record
`NO_INSTALLED_HELPER`, and every implemented `upgrade.json` check is true, including
`helperAbsentBeforeQuit`. Private helper-Off replacement is accepted on both CPUs.
PR #1547 recorded that accepted boundary and merged as
`1ff3780b0b9244f5dada842c9e7735a28712fb2d`.

**Step 6 authenticated helper-On qualification PR:**
`🚧 [desktop-distribution] Qualify authenticated macOS replacement [step 8/14]`.
Add a separate `macos-authenticated-upgrade-probe` dispatch mode backed by the
`macos-authenticated-upgrade` job rather than widening the credential-free accepted
probe. It is main-only, reads the dedicated `qa@sesori.com` account from repository
Actions secrets only in the exercise step, consumes/removes them before child processes,
and serializes native x64/arm64 so one relay bridge slot is never shared. The probe requests phase-fresh
sessions in memory and writes only the three established classic-Keychain values through
stdin with the installed signed app trusted, persists
Bridge On, and performs prior/current real tray Quit. It requires the exact packaged
helper, authenticated profile lookup, relay-serving readiness, Keychain preservation,
On intent, bounded state and no relaunch/orphan. Raw auth responses, token values,
bridge/app output and authenticated screenshots never enter artifacts; only bounded
boolean/coordinate evidence does. PR #1548 merged as
`cb23a7fc5d1f5b4fcedd1de2d591f88fd4074d43`; the dedicated production QA account now
exists and its email/password are repository Actions secrets with no environment approval
gate. Workflow review plus the runtime `refs/heads/main` guard remains the access boundary.
Accept nothing until both CPUs pass from merged `main`.
Failed-stop, interactive browser/TCC, minimum-OS and public gates remain separate.

**Step 6 repository-secret follow-up PR:**
`🌿 [desktop-distribution] Use repository secrets for macOS QA [step 8.b/14]`.
Apply the owner's post-merge credential policy: remove the unused environment binding,
read the provisioned account from repository Actions secrets, and keep the existing
main-only runtime guard, step-only exposure and serialized native matrix.

**Step 6 Keychain-bound follow-up PR:**
`⚙️ [desktop-distribution] Bound macOS QA Keychain setup [step 8.c/14]`.
Merged-main run `35443816334` reached the credential exercise on both CPUs but each
consumed the job's full 35-minute timeout immediately after prior-app installation. The
native writer's create-then-change-ACL sequence was the only unbounded operation at that
boundary. Create each classic item with its trusted ACL atomically, retain that ACL while
refreshing values, add privacy-safe deadlines to every native Keychain command, and retry
from merged `main`; the cancelled run is not qualification evidence. This follow-up
merged as `55547f26c8a9f59747987f1b7a65fc473e76e9c2`.

**Step 6 Keychain-envelope follow-up PR:**
`⚙️ [desktop-distribution] Match macOS QA Keychain query [step 8.d/14]`.
Merged-main run `35454870471` proved the atomic writer no longer hangs, but both CPUs
reached the bounded prior-app helper deadline with zero installed-helper processes. The
writer's classic-Keychain insert omitted the explicit non-synchronizable
(`kSecAttrSynchronizable: false`) and when-unlocked attributes that the pinned
FlutterSecureStorage includes in its fixed read query, so a broad `security` lookup
was not sufficient proof that the app could match the item. Create the item with that
exact query envelope and immediately self-verify it through `SecItemCopyMatching` without
printing its value. Retry both CPUs from merged `main`; the failed run is not
qualification evidence. This follow-up merged as
`bf14d7c0f32def581febd1531214bbdd2be9fd74`.

**Step 6 bounded startup-diagnostic follow-up PR:**
`🌿 [desktop-distribution] Classify macOS authenticated startup [step 8.e/14]`.
Merged-main run `35460239311` passed the exact Keychain self-check on both CPUs but again
reached the prior-app helper deadline with zero final helper processes. Preserve the
privacy boundary while distinguishing local-session/restore failures, desired-state or
bridge-start failures, and transient helper/log activity: scan at most 1 MiB of
phase-scoped private app output for a closed marker set, emit auth-gate outcomes through
the captured production log sink rather than `dart:developer`, and retain whether any
exact helper generation or fresh bridge-log bytes appeared. Raw authenticated logs remain
outside artifacts and are removed during cleanup. Retry both CPUs from merged `main`;
the failed run is not qualification evidence. This follow-up merged as
`db9b0cd8bdf0e4b220d3f0fa069ec831e35f2a89`.

**Step 6 persisted-log and timeout-evidence follow-up PR:**
`🌿 [desktop-distribution] Preserve macOS startup evidence [step 8.f/14]`.
Merged-main run `35465783382`, source
`db9b0cd8bdf0e4b220d3f0fa069ec831e35f2a89`, tree
`20a3a04d3a3b5399f880cb46f79eb222e6e24f4f`, was dispatched from:

```text
/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/tan-antelope
```

```bash
gh workflow run desktop-qualification.yml \
  --repo sesori-ai/sesori_apps_monorepo --ref main \
  -f mode=macos-authenticated-upgrade-probe \
  -f previous_packaging_run=35042335424 -f packaging_run=35206885114 \
  -f channel=stable
```

It exposed two concrete evidence gaps. X64 job `105957752803` remained in the exercise
step until the job timeout and therefore never reached its always-upload step. Arm64 job
`105957752806` reached the prior-app helper deadline; bounded artifact `10591911157`
(`sha256:e4ee1899b990a5699e4127c86b83f9434a3e39ed90a808d3b6e308f734f03666`)
contains no classified marker even though the production log sink's authoritative file
is `logs/app.log`. Scan at most 1 MiB from both private sources, upload only booleans, write
an atomically replaced closed phase record before each potentially blocking boundary,
and bound the exercise step below the job deadline so the always-upload step retains the
latest phase after a step timeout. Raw app/bridge output remains private and cleanup still
removes it. Retry both CPUs from merged `main`; the cancelled run is not qualification
evidence.

**Step 11 PR:**
`🌿 [desktop-distribution] Reconcile private distribution regression coverage [step 13/14]`.
Private-package reconciliation can proceed after step 9 while step 10 is blocked.
Carry the remaining public-link/onboarding and release-runbook documentation in
step 10's existing ordinal 12/14 PR, alongside the genuine shipped-download changes.
That PR also closes the deferred portion of step 11; no second ordinal 13 PR is planned.
Keep this step in progress until both portions are complete. Low risk;
no runtime or database change.

**Step 12 PR:**
`⚙️ [desktop-distribution] Verify six-target releases and retire distribution plan [step 14/14]`.
After completed steps 10 and 11, run/assemble the complete recorded release matrix
through packaged/external boundaries, record exact artifacts and evidence, resolve
failures, then move this directory to `.plan/completed/desktop-distribution/` and
repoint live links. No runtime/database change except independently reviewed required
fixes. Never retire partial/blocked coverage.

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
| Windows | x64, arm64 | Windows 11 native hosts; native GUI/plugins/helper, standard user account, clean download reputation observation, paths with spaces/non-ASCII. Installer-only emulation is approved on ARM64. User has no ARM64 QA device; interactive proof remains blocked until a host is available. Windows 10 is not implicitly claimed. |
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
4. macOS: authentic signed N→N+1 manual upgrade with helper On and Off; prove
   normal Quit stops the helper without reopening, failed stop refuses Quit,
   publisher/Gatekeeper verification and complete-app replacement preserve state.
   Manual update is selected under D6; no automatic-install behavior is claimed.
   Windows: open the channel/CPU-correct download page, observe installer refusal
   while the GUI is running, safely Quit, then apply the signed N→N+1 EXE as a standard
   user. Test refused helper stop, publisher verification, shared-data retention and
   interrupted installer recovery. Normal Quit must not reopen the application.
5. Linux: trusted APT/DNF install and N→N+1 update, metadata/key/payload tampering
   refusal, open-app package replacement requiring restart before mismatched helper
   spawn, and native remove/reinstall. Package scripts never launch the GUI as root.
6. Shared CLI data, projects and session history survive uninstall/reinstall. Desktop
   login entries/shortcuts obey the documented per-platform ownership limitations.
7. Forced failed desktop leg/signature/feed publication leaves the previous channel
   valid and does not trigger or block mobile/CLI jobs. Stable never selects an
   internal desktop build; existing bridge installers still select bridge releases.
8. Public GitHub downloads, signed Linux repositories work
   without authentication. winget discovery is verified through its actual external
   manifest/install path; record an unapproved manifest as blocked, not passing.

Use current native N and N+1 test builds before the first public desktop release;
there is no obligation to migrate unpublished desktop builds. Once a public version
ships, include it as the upgrade baseline. Same-version metadata corruption does not
justify silently replacing immutable public artifacts.

Per-platform ship gates can release ready platforms while later ones remain blocked.
Private qualification now covers signed/notarized macOS packages and unsigned Windows
and Linux packages on both native CPUs; exact run/source/artifact evidence stays in
[steps 4.a](steps/step-04.md), [4.b](steps/step-04b.md),
[7](steps/step-07.md), and [9](steps/step-09.md). This does not close any public ship
gate. Final retirement requires all recorded targets and package variants. Missing
Windows/Linux hosts, credentials, store/package approvals, or toolchains are
**Blocked**, not an accepted reduction. Any reduction requires explicit user
acceptance in this file.
Record privacy-safe artifact IDs/digests, build SHA, actual OS/CPU, package/updater
versions, outcomes, and cleanup; keep raw account/project/log content out of Git.

## Complexity budget, safeguards, and accepted limits

Manual macOS/Windows updating adds zero mutable update state. The immutable channel
and bundle target select a static download-index section. No updater framework,
service subscription, download cache, timer, terminal action, restart journal or
rollback engine is added. Existing safe Quit remains the one helper-stop authority.
Windows adds only the planned installer-visible process-lifetime mutex for Inno's
running-app refusal. Linux package managers own their normal state and replacement.

Release state is bounded to immutable artifacts/tags, signed channel/repository
entry points, and existing CI concurrency plus object-generation preconditions.
Each channel pointer exists to publish an authoritative release, not to reconstruct
user intent. No release backend or general-purpose deployment framework.

| Safeguard | Evidence and consequence if omitted |
|---|---|
| Complete helper bundle and identity check | Observed dev-only path and native CLI assets; ordinary packaged launch or package upgrade otherwise fails or starts a mismatched helper. |
| Expected-stop before replacement | Ordinary update with bridge On; macOS replacement follows explicit Quit, and the Windows installer refuses a running GUI so users take that same safe Quit path. |
| Cryptographic release/update verification | Ordinary remote software delivery crosses an executable-code trust boundary; unauthenticated substitution compromises developer machines. |
| Immutable payloads and metadata-last publication | Ordinary partial upload/failing architecture; otherwise clients can discover incomplete or inconsistent releases. |
| Clean native host and signed-artifact testing | Existing evidence is dev-built/three-runner CI; native plugins, permissions and package dependencies are platform-specific. |
| Shared-state-preserving uninstall | Standalone CLI and desktop use shared bridge state; broad deletion loses user sessions/credentials. |

Accept: users choose when to download and install updates; no forced security-update
restart policy is invented. OS logout/reboot/crash never initiates a Sesori update. Native package managers can replace files outside Sesori's control;
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
(particularly Linux ARM64), exact OS minimums/VM ownership, Windows manual installer
and signer, macOS notarization access, GCS bucket/publication
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
