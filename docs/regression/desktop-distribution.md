# Desktop distribution and manual updates

## Supported behavior

Desktop Settings includes update guidance. Packaged macOS/Windows builds expose
**View downloads**, opening the official repository index at the compiled build's
stable/internal channel, OS and CPU section. This does not claim an available
update or published installer. Unshipped sections explicitly contain no public
download; they never link private CI artifacts or infer desktop assets from Latest.
Source builds show development guidance; Linux shows package-manager guidance.

Staging accepts `--channel stable|internal` (default stable) and emits
`SESORI_DESKTOP_RELEASE_CHANNEL` beside the compiled bundle identity. Channel is
build metadata, not helper identity, persisted state or a client/bridge contract.
Malformed present metadata does not select a guessed download destination.

macOS and Windows use manual signed packages. Users Quit normally before replacing
or installing, then reopen manually. Closing a tray-backed window is not Quit.
Failed helper stop retains the existing refusal to Quit. Nothing in the download
action stops a helper, installs, changes bridge intent or automatically relaunches.
Linux upgrades remain package-manager-owned. Shared CLI data is not update cleanup.

## Coverage

| Level | Required evidence |
|---|---|
| L1 | Destination tests cover both channels and CPUs, Linux and source guidance; widget tests exercise external-link dispatch without claiming release availability. |
| L2 | Staging parser/default/invalid-channel and exact dotenv tests; existing Settings composition retains attention controls. Every generated fragment matches an index heading. |
| L3 | Real Settings navigation and external-browser dispatch to the correct index section on a packaged native build; unshipped entries remain explicit. No published installer is needed for this check. |
| L4 | Actual publisher verification and signed N→N+1 manual replacement with helper On/Off, failed-stop refusal, normal Quit/no relaunch, and data preservation. |
| L5 | All recorded native platform/package/host gates in the active distribution plan, downloaded artifacts, trust checks and public links. |

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
