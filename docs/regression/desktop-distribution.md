# Desktop distribution and manual updates

## Supported behavior

Desktop Settings → General includes app-update guidance, separate from bridge configuration and supervision.
Packaged macOS/Windows builds expose
**View downloads**, opening `https://sesori.com/desktop/` with the compiled build's
stable/internal channel, OS and CPU section. The page is live; this does not claim an
available update or published installer. Unshipped sections explicitly contain no public
download; they never link private CI artifacts or infer desktop assets from Latest.
The website page renders all eight channel/OS/CPU anchors and `linux-package-managers`,
so every generated fragment lands on its own section.
The repository download document is a content/anchor specification, not an alternate
user-facing destination. Source builds show development guidance; Linux shows
package-manager guidance.

Staging accepts `--channel stable|internal` (default stable) and emits
`SESORI_DESKTOP_RELEASE_CHANNEL` beside the compiled bundle identity. Channel is
build metadata, not helper identity, persisted state or a client/bridge contract.
Malformed present metadata does not select a guessed download destination.

macOS and Windows use manual signed packages. Users Quit normally before replacing
or installing, then reopen manually. Closing a tray-backed window is not Quit.
Failed helper stop retains the existing refusal to Quit. Nothing in the download
action stops a helper, installs, changes bridge intent or automatically relaunches.
Linux upgrades remain package-manager-owned. Shared CLI data is not update cleanup.

## Private Windows installer qualification

Manual `windows-packaging` qualification builds unsigned x64 and ARM64 per-user
Inno Setup packages from exact native staged bundles. Install defaults to
`%LOCALAPPDATA%\Programs\Sesori`; shortcuts launch `sesori_desktop.exe`. Setup and
uninstall refuse while `Global\com.sesori.desktop.running.<current-user-SID>` exists.
This per-user marker spans Windows sessions, stays owned by GUI process until OS
termination, and does not reject another GUI instance.
Installer never starts Sesori, enables login launch, closes/restarts processes, or
removes unrecorded files. Uninstall additionally removes only existing `Sesori`
login value; shared credentials, runtimes, databases, history and projects remain.

The Inno Setup 7.1.0 x64 acquisition installer is checksum-verified before it
installs the compiler. Compiler and installer launcher may run under Windows ARM64
emulation; GUI, helper and shipped libraries
must match target CPU. Isolated runner probes use per-user global mutex fixtures and
compare every staged relative file path and SHA-256 with the installed payload; only
Inno's generated uninstaller files are excluded from the installed extra-file set.
They do not start the product and prove silent fixture behavior only. Output remains private, unsigned CI evidence:
it does not establish publisher trust, SmartScreen reputation, interactive behavior,
account restoration, upgrades, or release readiness.

## Private Linux package qualification

Manual `linux-packaging` qualification builds unsigned DEB and RPM packages from
complete native x64 and ARM64 staged bundles. Both formats own the complete unchanged
GUI/helper payload below `/opt/sesori-desktop` plus only three system-integration files:
the `sesori-desktop` launcher, one desktop entry and the existing 512x512 application
icon. They leave the standalone `sesori-bridge` launcher untouched. Version, build,
source, OS and CPU come from the
staged identity. DEB dependencies come from `dpkg-shlibdeps`; RPM requirements come
from Fedora's native `rpmbuild` ELF scanning. Current locked Linux plugin sources are
checked for explicit dynamic loading before packaging; no guessed explicit runtime
requirement is added when those sources contain none.

Native Ubuntu 24.04 and Debian 13 containers install, same-version reinstall and
remove the DEB. Their official multi-architecture base-image indexes are pinned, as is
the Fedora 44 base that builds, installs, same-version reinstalls and removes the RPM
on matching native host CPUs. Package repositories and dependencies fetched by
`apt`/`dnf` remain rolling, so these pins do not claim bit-reproducible future runs.
Fixtures compare installed payload paths/hashes with staging,
require root ownership, reject maintainer scripts/scriptlets, and preserve realistic
configuration, credentials, database, runtime, attachment and project sentinels.
They never launch the GUI or helper. Same-version reinstall is not N→N+1 proof.
Unsigned private containers do not establish desktop-session behavior, account
restoration, Secret Service/tray behavior, signing, repository trust or publication.

## Private release preparation

The manual Desktop Release Preparation workflow consumes both native macOS package
artifacts from one successful qualification run. It checks source/version/build,
compiled channel, clean-source evidence, accepted notarization receipts, inventory
agreement and payload hashes before producing private metadata and checksums.
Preparation source and package source are recorded separately. Old producer runs
without channel evidence are rejected rather than assigned a guessed channel.

Preparation has read-only repository/Actions permissions and never signs, executes
packages, creates tags/releases, edits website links, or triggers CLI/mobile release
work. These are evidence-consistency checks, not independent signature verification
or permission to ship. Public release and full native upgrade gates remain outstanding.

## Private macOS manual-replacement qualification

Manual `macos-upgrade-probe` qualification is credential-free and consumes two
retained successful macOS packaging runs on each package's native CPU. It runs only
from `main` and accepts a source only from `origin/main` or the exact pinned retained
1.8.4 run/source/tree. It verifies that baseline's merged-PR provenance, exact DMG
hashes, clean producers, sealed identities, accepted notarization, Developer ID
identity, tickets and Gatekeeper. The current
package must have a strictly newer semantic-version/build identity and the requested
compiled channel; an older unpublished baseline may predate channel metadata.

On a fresh Actions host with no existing app, bridge, login registration or relevant
state root, the probe copies the previous app from its real DMG into Applications,
launches with persisted Bridge Off and, after the initial startup interval, retries the
read-only visible-window inspector for up to 45 additional seconds while the process
remains alive. This is the deliberate exception to one-shot window observation because
two native x64 runs had a live owned process at that boundary: it polls only the local
inspector within the fixed deadline, never restarts the app or workflow, and leaves the
window acceptance criteria unchanged. It requires AXPress capability on its
process-owned status item,
validates its small menu-bar frame and clicks that exact
frame. It then performs a system-wide z-order hit test beside the frame and
accepts only a menu owned by the exact PID and anchored to that frame,
then invokes `Quit Sesori` only inside the
accepted menu. The probe rejects relaunch or
orphan processes, replaces the complete app from the current DMG and repeats while
preserving bounded desktop, shared CLI-data, attachment and valid login-registration
sentinels. Cleanup removes only probe-owned paths. Pre-merge run `35363132033` is not
accepted because its Quit lookup was broader. First main-only run `35367589565` failed
safely on both CPUs when status-item-only traversal could not observe AppKit's transient
menu. Second main-only run `35375073067` also failed safely: arm64 exposed 16 menus
before the press without a new accepted popup, while x64 traversal invalidated its
status-item reference. Third main-only run `35384845467` failed safely because
application-scoped hit testing did not surface the status-bar menu on either CPU.
Fourth main-only run `35391748404` also refused because AXPress left only groups/windows
at the system-wide sample points. The bounded real-click correction then merged. Runs
`35399491087` and `35399933745` passed arm64 completely. Both x64 jobs passed prior-app
Quit and current installation/launch but found no current window at the single sample
15 seconds after launch. After the bounded-wait correction, main-only run `35405646668`
passed signed replacement, persisted Bridge Off intent and post-Quit process absence,
but did not inspect a live helper. The helper-observation correction then merged.
Main-only run `35411687826` passed x64 job `105812464127` and arm64 job
`105812464132`; both prior/current helper logs on both CPUs record
`NO_INSTALLED_HELPER`, and every implemented check is true, including
`helperAbsentBeforeQuit`. Private helper-Off is accepted on both CPUs.

The separate manual `macos-authenticated-upgrade-probe` is the credential-bearing
continuation. It is restricted to `main`, serializes the CPU jobs around the dedicated
`qa@sesori.com` production account, and reads its email/password from repository Actions
secrets only in the exercise step, then consumes/removes both before any child process.
No extra QA approval environment is required; workflow review plus the runtime main guard
is the credential-access boundary. An earlier, separate `macos-signing` step signs the
QA-only Keychain helper with the existing Developer ID and removes signing material before
QA credentials enter the job. This step needs no notarization credentials or publication
permission; the helper is neither packaged with the app nor uploaded as evidence.
The helper checks valid Developer ID signatures and matching app/helper teams before any
Keychain access. The trusted-app ACL alone does not grant access across modern macOS
signing partitions. Reads and writes therefore use the same signed helper, not an unrelated
security-tool reader. Writes consume stdin; reads are privately captured and never logged.
The probe requests phase-fresh tokens in memory, creates the three established
classic-Keychain values with their exact trusted-app ACL atomically, retains that ACL
while refreshing values, and bounds every native Keychain command. The writer must also
create and self-verify each item through the pinned FlutterSecureStorage query's explicit
non-synchronizable (`kSecAttrSynchronizable: false`) and when-unlocked envelope.
On
failure, the probe may inspect at most 1 MiB from each phase-scoped redirected app output
and authoritative persisted `logs/app.log` for the closed markers
`desktopStartupRendered`, `localSessionUnavailable`, `localUserRestoreIncomplete`,
`desiredStateRestoreFailure` and `bridgeStartFailure`. It also reports the furthest closed
`startupStage`: `noMarker`, `dartMainEntered`, `processAdmissionStarted`,
`processAdmissionCompleted`, `preferences`, `nativeWindow`, `controlDispatcher`,
`relayClient`, `desktopAttention`, `analyticsPreferences` or `rendering`. The separate
`startupMarkerSupport` value is `none`, `preRender` or `preSinkAdmission`. Ordinary
packages derive it from checked-out immutable source; exact retained baseline
`35042335424` uses pinned metadata because its PR-head object need not be reachable from
merged `main`. `noMarker` means only "before the first
supported marker"; it never upgrades a legacy package to pre-sink evidence. Fixed pre-sink
markers distinguish entry into Dart main and primary-process admission for newly built
packages; later stages reuse privacy-safe production log messages. Current package run
`35501361734` (`1.9.0+122`) contains these markers. Its authenticated pairing with baseline
`35042335424` failed before replacement in run `35502787779`: both CPUs observed baseline
`desktopAttention`, no helper activity, and completed cleanup. Signing-partition local
controls establish a harness defect, not full authenticated replacement acceptance.
The auth gate emits
privacy-safe outcome markers
through the production log sink rather than relying on `dart:developer` output. The probe
uploads only closed values, an atomic closed phase/cleanup record, and whether any helper
generation or fresh bridge-log activity appeared. The exercise has a 20-minute deadline
within a 35-minute job; separate helper signing is bounded to three minutes, preserving
upload headroom. The probe
persists Bridge On and requires the exact packaged helper, an authenticated profile lookup
and relay-serving readiness before each real tray Quit. It then verifies Keychain, On
intent, bounded state and helper absence through replacement. Artifacts exclude raw auth
responses, token values, bridge/app output and authenticated screenshots. The tooling
alone is not accepted helper-On evidence; both CPUs must pass from merged `main`. Even a
pass does not prove
failed-stop refusal, interactive browser/user-account/TCC, minimum-OS support, public
retrieval or release readiness.

## Current evidence boundary

Private package mechanics are qualified for both native CPUs on all three desktop
platforms: signed/notarized/stapled DMGs and ZIPs containing the signed/notarized/stapled
app on macOS (the ZIP itself is not signed or stapled), unsigned per-user EXE
construction and isolated fixtures on Windows, and unsigned DEB/RPM construction plus
six native package-manager fixtures on Linux. This is repository-shipped preparation,
not public release support. Exact accepted sources, runs, hashes and proof limits stay
in the active distribution plan's [macOS](../../.plan/active/desktop-distribution/steps/step-04.md),
[Windows](../../.plan/active/desktop-distribution/steps/step-07.md), and
[Linux](../../.plan/active/desktop-distribution/steps/step-09.md) evidence.

Still unproved: public retrieval and trust, interactive user-account/browser/TCC
restoration, declared minimum OS, full GUI/keyring/tray/login behavior, authenticated
helper-On and failed-stop macOS replacement, signed Windows N→N+1 manual replacement,
and signed-repository Linux N→N+1 updates. Unrun authenticated tooling, a private
helper-Off probe, silent fixture or same-version reinstall cannot close those gates.

## Coverage

- **L1:** Destination tests cover both channels and CPUs, Linux and source guidance;
  widget tests exercise external-link dispatch without claiming release availability.
- **L2:** Offline preparation fixtures cover both CPUs, channel/source mismatches,
  altered payload/evidence, missing packages, deterministic output and no overwrite.
  Windows fixtures cover identity/CPU refusal, complete native inventory, pinned
  compiler arguments, bounded installer directives and no-overwrite diagnostics.
  Linux fixtures cover identity/CPU refusal, payload layout and symlink preservation,
  source-derived dynamic-loading audit, generated dependency invocation, bounded
  ownership and absence of package lifecycle scripts. macOS upgrade fixtures cover
  producer/run/source/channel/identity ordering, altered DMGs, dirty-source refusal,
  credential source isolation, stdin-only Keychain writes, bounded auth evidence and
  main-only environment scoping. Staging parser/default/invalid-channel and exact
  dotenv tests; Settings
  composition retains attention controls. Generated fragments match specification headings.
- **L3:** Real Settings navigation and external-browser dispatch on a packaged native
  build. Verify the browser lands on the website section matching the build's channel,
  OS and CPU. No published installer is needed to check browser dispatch.
- **L4:** Actual publisher verification and signed N→N+1 manual replacement with
  helper On/Off, failed-stop refusal, normal Quit/no relaunch, and data preservation.
- **L5:** All recorded native platform/package/host gates in the active distribution
  plan, downloaded artifacts, trust checks and public links.

L1/L2 do not establish installation, native trust, real-account restoration, minimum
OS or publication. Public downloads remain gated; a merged index is not a release.
See [packaging](desktop-macos-packaging.md), [supervision](desktop-bridge-supervision.md)
and [download instructions](../desktop/downloads.md).

## Failure signals

Wrong channel/CPU fragment, guessed architecture for source builds, private or
unshipped artifact links, a dead Linux/self-update button, raw release-version
inference, losing attention settings, startup network waits, or a download action
that stops/restarts the app or helper. Windows setup/uninstall proceeding while GUI
mutex exists, changing login intent during install, launching the app, forced close/
restart, wrong-CPU payloads, or broad uninstall cleanup are failures. Linux package ownership of
`/usr/bin/sesori-bridge`, user homes or autostart entries; guessed runtime dependencies;
non-native container execution; package scriptlets; altered staged payloads; or calling
a same-version reinstall an N→N+1 upgrade are failures. Manual replacement must never
delete shared credentials, harness runtimes, databases, history or projects.
