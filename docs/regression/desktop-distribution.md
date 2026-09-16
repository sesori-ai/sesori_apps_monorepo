# Desktop distribution and manual updates

## Supported behavior

Desktop Settings includes update guidance. Packaged macOS/Windows builds expose
**View downloads**, opening `https://sesori.com/desktop/` with the compiled build's
stable/internal channel, OS and CPU section. This does not claim an available
update or published installer. Unshipped sections explicitly contain no public
download; they never link private CI artifacts or infer desktop assets from Latest.
The website is not live yet; the user explicitly selected this destination anyway.
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
or permission to ship. Public release and native upgrade gates remain outstanding.

## Coverage

- **L1:** Destination tests cover both channels and CPUs, Linux and source guidance;
  widget tests exercise external-link dispatch without claiming release availability.
- **L2:** Offline preparation fixtures cover both CPUs, channel/source mismatches,
  altered payload/evidence, missing packages, deterministic output and no overwrite.
  Staging parser/default/invalid-channel and exact dotenv tests; Settings
  composition retains attention controls. Generated fragments match specification headings.
- **L3:** Real Settings navigation and external-browser dispatch on a packaged native
  build. Verify the correct website section once live; until then record page availability
  separately. No published installer is needed to check browser dispatch.
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
that stops/restarts the app or helper. Manual replacement must never delete shared
credentials, harness runtimes, databases, history or projects.
