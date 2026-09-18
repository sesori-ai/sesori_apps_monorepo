# Desktop distribution and manual updates

## Supported behavior

Desktop Settings includes update guidance. Packaged macOS/Windows builds expose
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
launches a visible window with persisted Bridge Off and presses its process-owned
status item, then type-selects Quit. It accepts only a focused `Quit Sesori` menu item
owned by the exact PID whose parent menu is anchored to the recorded status-item frame.
The probe rejects relaunch or
orphan processes, replaces the complete app from the current DMG and repeats while
preserving bounded desktop, shared CLI-data, attachment and valid login-registration
sentinels. Cleanup removes only probe-owned paths. Pre-merge run `35363132033` is not
accepted because its Quit lookup was broader. First main-only run `35367589565` failed
safely on both CPUs when status-item-only traversal could not observe AppKit's transient
menu. Second main-only run `35375073067` also failed safely: arm64 exposed 16 menus
before the press without a new accepted popup, while x64 traversal invalidated its
status-item reference. The
focused-menu correction awaits a new main run. This does not prove an
authenticated helper-On or failed-stop path, real-account/Keychain/TCC behavior,
minimum-OS support, public retrieval, or release readiness.

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

Still unproved: public retrieval and trust, real-account restoration, declared minimum
OS, full interactive GUI/keyring/tray/login behavior, authenticated helper-On and
failed-stop macOS replacement, signed Windows N→N+1 manual replacement, and
signed-repository Linux N→N+1 updates. A private helper-Off probe, silent fixture or
same-version reinstall cannot close those gates.

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
  producer/run/source/channel/identity ordering, altered DMGs and dirty-source refusal.
  Staging parser/default/invalid-channel and exact dotenv tests; Settings
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
