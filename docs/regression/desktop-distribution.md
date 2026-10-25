# Desktop distribution and manual updates

## Supported behavior

Desktop Settings → General includes app-update guidance, separate from bridge configuration and supervision.
Packaged macOS/Windows builds expose
**View downloads**, opening `https://sesori.com/desktop/` with the compiled build's
stable/internal channel, OS and CPU section. The page is live; this does not claim an
available update or published installer. Unshipped sections explicitly contain no public
download; they never link private CI artifacts or infer desktop assets from Latest.
The website preserves all eight macOS/Windows channel/CPU anchors and `linux-package-managers`,
plus four `internal-linux-<x64|arm64>-<deb|rpm>` preview anchors; the website step adds the
`<channel>-linux-<x64|arm64>-appimage` anchors. Every generated app fragment
lands on its own section; Linux preview navigation opens its channel and platform.
The repository download document is a content/anchor specification, not an alternate
user-facing destination. Source builds show development guidance; Linux packages show
package-manager guidance. A Linux AppImage (the runtime sets `APPIMAGE`) instead links its
`<channel>-linux-<x64|arm64>-appimage` manual-download section; website anchors for it land
with the website step.

The deployed website resolves completed public macOS stable/internal and Linux internal
releases independently. It follows all release pages on the fixed GitHub repository
endpoint under one five-second timeout. A five-minute cache coalesces lookups and logged
failures; no credentials, background polling or persistent release pointer is used.
macOS completion requires its manifest/checksums and both native DMGs. Linux completion
requires its own marker, all four version/build-matched DEB/RPM files, both signed checksum
pairs and desktop public key. All need positive sizes and valid SHA-256 index digests.
Publishers upload each marker last; runtime discovery does not parse it, rehash installers
or verify OpenPGP. URLs use validated tags and expected filenames. A newer core-only or
other-platform release cannot replace the last completed preview for this platform.
Preview navigation stays visible beside stable downloads. Linux-only availability cannot
claim macOS notarization; preview metadata never creates stable schema/offer availability.
The preview group leaves 32px before the selector and wraps without mobile overflow.
Linux rows link the experimental limitations note below the sticky header. They describe
manual packages, not repository updates or qualified upgrades. Actual-widget demo imagery
discloses native-control differences, not native account QA.

Staging accepts `--channel stable|internal` (default stable) and emits
`SESORI_DESKTOP_RELEASE_CHANNEL` beside the compiled bundle identity. Channel is
build metadata, not helper identity, persisted state or a client/bridge contract.
Malformed present metadata does not select a guessed download destination.

macOS and Windows use manual signed packages. Users Quit normally before replacing
or installing, then reopen manually. Closing a tray-backed window is not Quit.
Failed helper stop retains the existing refusal to Quit. Nothing in the download
action stops a helper, installs, changes bridge intent or automatically relaunches.
Linux DEB/RPM upgrades remain package-manager-owned; AppImages are replaced manually like
macOS and Windows packages. Shared CLI data is not update cleanup.

## Client storage boundary

Desktop uses the shared SQLite preferences/encrypted-value store and one native
master item. Replacement must preserve both; file sentinels alone do not prove
that secrets decrypt or local auth restores. Plaintext preference operations must
not acquire native authorization. See [client persistence](client-persistence.md).

No production desktop release exists yet. Published internal build 987 predates this
cutover. An old per-value-native build requires explicit sign-out before replacement
and one new sign-in, not a migration/compatibility promise for internal previews.
New-format N→N+1 preservation needs two shared-store builds.

## Private Windows installer qualification

Manual `windows-packaging` qualification builds unsigned x64 and ARM64 per-user
installers from exact native staged bundles with Velopack's `vpk pack` (`--packId sesori-desktop`,
the compiled channel, pack version `<version>` for stable and `<version>-internal.<build>` for
internal). The `vpk` 1.2.161 tool package is pinned by SHA-256 and installed only from that
verified file. vpk's `sesori-desktop-<channel>-Setup.exe` is renamed to
`Sesori-windows-<arch>-<version>.exe`. Its full `.nupkg` and `releases.<channel>.json` are kept
as the unpublished `desktop-velopack-windows-<arch>` artifact. The package must contain the exact
staged bundle plus Velopack's updater, launcher stub and `sq.version`, every binary native to the
target CPU (the Setup and updater included), and the Setup must embed that package.

Setup installs into `%LOCALAPPDATA%\sesori-desktop`: the bundle in `current\`, beside
`Update.exe`, a `Sesori.exe` launcher and `packages\`. It creates only the Start menu
`Sesori\Sesori` shortcut and a `sesori-desktop` uninstall entry with the app icon. An
interactive install starts Sesori when it finishes; a silent one does not. Setup, reinstall
and uninstall stop running Sesori processes under the install folder instead of refusing.
Velopack runs `sesori_desktop.exe --veloapp-<hook> <version>` at install, update and
uninstall; the Windows runner answers every hook before starting Flutter, and the uninstall
hook removes only the `Sesori` login value. Install never enables login launch. Uninstall
deletes the whole install folder; shared credentials, runtimes, databases, history and
projects outside it remain.

Isolated runner probes install silently into a temporary folder, reinstall the same version,
verify the `current\` inventory, and compare every staged relative file path and SHA-256
with it; only `sq.version` is allowed as an extra file. After silent uninstall no recorded
payload, uninstall entry or login value remains, and a pre-existing login value survives
install and reinstall. They do not start the product and prove silent fixture behavior only.
Output remains private, unsigned CI evidence:
it does not establish publisher trust, SmartScreen reputation, interactive behavior,
account restoration, upgrades, or release readiness.

## Linux tray reachability

On a functioning StatusNotifier host, Linux configures the native click trigger before
publishing the menu and showing the icon. The host must receive a usable menu containing
normal Show/Quit actions; an icon alone is not reachability. Manual `openContextMenu`
is unsupported by the Linux backend and cannot substitute for exporting the menu.
GNOME without a host retains its no-tray behavior. macOS/Windows keep their existing
manual click callbacks. Adapter tests cover Linux configuration order and non-Linux
isolation; real menu/normal-Quit proof still requires fresh native signed builds.

## Private Linux package qualification and signing

Manual main-only `linux-packaging` qualification first builds unsigned DEB and RPM packages from
complete native x64 and ARM64 staged bundles. Both formats own the complete unchanged
GUI/helper payload below `/opt/sesori-desktop` plus only three system-integration files:
the `sesori-desktop` launcher, one desktop entry and the existing 512x512 application
icon. They leave the standalone `sesori-bridge` launcher untouched. Version, build,
source, OS and CPU come from the
staged identity. DEB dependencies come from `dpkg-shlibdeps`; RPM requirements come
from Fedora's native `rpmbuild` ELF scanning. Current locked Linux plugin sources are
checked for explicit dynamic loading before packaging; no guessed explicit runtime
requirement is added when those sources contain none. The one known exception is the
Flutter GTK embedder itself, which dlopens EGL and GLES through libepoxy: DEBs also
depend on `libegl1, libgles2`, and RPMs require `libEGL.so.1()(64bit)` and
`libGLESv2.so.2()(64bit)`. Without them the app aborts at first frame on clean Debian 13
and Fedora 44 with `Couldn't open libEGL.so.1` / `libGLESv2.so.2`.

The same job also builds a portable `Sesori-linux-<arch>-<version>-<build>.AppImage` from the
unchanged bundle: an AppDir whose `AppRun` symlinks the GUI binary, plus a desktop entry and
icon, packed as a root-owned zstd squashfs behind the static AppImage type2 runtime `20251108`.
Each CPU's runtime is pinned by SHA-256; a mismatched download refuses. The image is read back
with `unsquashfs -offset` and must match the assembled AppDir exactly; packaging never executes
it. The AppImage is unchanged by signing and covered only by the signed checksums. It needs
host GTK 3, libsecret, EGL/GLES and glibc 2.39 or newer (the Ubuntu 24.04 build host), plus FUSE.
It installs no menu entry, and launch at login autostarts the
image file named by `APPIMAGE`, not its transient mount. Repositories serve only the DEB/RPM rows.

`linux-session` replaces the AppImage natively on Arch Linux (x64: the pinned official
image; ARM64: the Arch Linux ARM community rootfs, verified against its pinned signing key)
under a headless Plasma 6 Wayland session with the StatusNotifier host. As user `qa`
it installs the previous image at `~/Applications/Sesori.AppImage` and launches it over FUSE.
It requires a render, the mounted bundle identity and a pid-matched tray. It enables launch
at login and requires `Exec="<image>" "--hidden"`. It quits from the tray menu and requires
exit 0, unmount and no helper. It then replaces the image at the same path, relaunches
hidden, and requires `Launch at login: On` and preserved probe data. A registration naming
the transient mount fails this row.

Native Ubuntu 24.04 and Debian 13 containers install, same-version reinstall and
remove the DEB. Their official multi-architecture base-image indexes are pinned, as is
the Fedora 44 base that builds, installs, same-version reinstalls and removes the RPM
on matching native host CPUs. Package repositories and dependencies fetched by
`apt`/`dnf` remain rolling, so these pins do not claim bit-reproducible future runs.
Fixtures compare installed payload paths/hashes with staging,
require root ownership, reject maintainer scripts/scriptlets, and preserve realistic
configuration, credentials, database, runtime, attachment and project sentinels.
They never launch the GUI or helper. Same-version reinstall is not N→N+1 proof.
Container package mechanics do not establish desktop-session behavior, account
restoration, Secret Service/tray behavior, repository trust or publication.

After construction, a signing step checks the input evidence and matching identities,
adds a native RPM OpenPGP signature, and signs checksums covering the final RPM and
unchanged DEB and AppImage. The full configured primary fingerprint must match the imported key.
Only this step receives the `linux-signing` secrets. Tools install before secret
exposure; the network-disabled signing container uses a temporary private GnuPG home
and passphrase file, removes secret variables from child environments and cleans up
its agent/key material. Public-only verification must pass before fixture installation
and artifact upload. RPM fixtures enable local-package signature checking; all three
distribution fixtures verify signed checksums. Digest-only RPM verification is not
accepted as a signature. Wrong key/passphrase, changed input, altered payload and
signature failures refuse completion. No private key material enters artifacts/logs.

The final RPM digest differs from its unsigned source report; `signing.json` records
both. DEB checksums are detached artifact authentication, not an APT `InRelease`
claim. PR CI's disposable-key fixtures also check GPGV and DNF's signature-required
install/reinstall/remove flow in an isolated install root, including unsigned-RPM refusal.
Installed DEB/RPM packages register their compiled channel's signed repository
(`sesori.list` with its key, or `sesori.repo` with its key). The native fixtures
verify those files byte for byte and require that the registered key has the
fingerprints of the key that signed the package checksums (and, for RPM, the package
itself). Removal deletes the files. Failure signal: a downloaded package that never
receives updates, or a second Sesori APT source with a different `signed-by` value.
Expected, not a failure: `apt update` errors on the stable source only between the
first stable release going public and its repository publication minutes later.
Main-only native runs establish production-key access separately. These fixtures do
not run the real application. Historical unsigned package runs remain unsigned
proof; new tooling alone does not relabel them. Public repositories and
N→N+1/desktop-session checks remain separate from internal-preview publication.
See [key setup and backup guidance](../desktop/linux-signing.md).

Signed native run `38372268594` qualified x64 and arm64 at source
`de53cafb2483d76e9350a28d014b4d3906ee0fe0`, private build `1.9.1+147`, using the
configured production signing key. All six distribution fixtures passed. Independent
archive/package-file hashes, source identities, empty source patches and public-key-pinned
checksum signatures matched. This establishes real credential access and signed
package mechanics, not public repositories, GUI/account behavior or N→N+1 updates.
The manual workflow's build number is not the shared release sequence.

## Signed Linux repository preparation

`build_linux_repository.py` consumes a prepared desktop release, not unqualified build
outputs. It authenticates both signed checksum inventories against the separately
pinned primary, verifies all four package digests and DEB/RPM identity headers, and
requires native RPM signatures. Repository generation never modifies package bytes.
`apt-ftparchive` supplies both CPU indexes and `createrepo_c` supplies each RPM index;
internal/stable roots stay separate. The existing temporary signing owner creates
APT `Release.gpg`/`InRelease` and RPM `repomd.xml.asc`, verifies with public material,
and removes private state before writing the completed inventory.

APT advertises only SHA-256 by-hash indexes and a UTC `Date`/`Valid-Until` window of
30 days. A correctly signed but expired APT index is refused; regenerating metadata
from the same accepted packages restores access without disabling client expiry checks.
The repository workflow supplies protected signing and weekly metadata-only refresh
for quiet channels through the same publisher. This is not a second product release cycle and
must never rebuild apps, change release completion or dispatch stores. RPM metadata
signatures do not provide APT's expiry guarantee; its filenames contain checksums.
Publishing must retain old referenced objects and place payloads/indexes before signed
entrypoints; RPM's separate XML/signature update can safely refuse a concurrent refresh
rather than install unauthenticated data. This tooling does not publish or replace
compiled-identity/native qualification in release preparation.

Disposable-key APT/DNF fixtures exercise repository trust and inert package installation,
version upgrade and removal inside fresh roots, with unrelated state preserved.
Channel mismatch, absent CPUs, wrong signer, altered packages/checksums/signatures and
unverifiable metadata refuse completion. These fixtures do not establish native GUI,
account/keyring, tray, login-launch, real application upgrades or public HTTPS delivery.

## Hosted Linux repositories

`linux-repository.yml` follows each channel's newest completed public Linux release
(internal pre-releases; stable non-draft `v<X.Y.Z>`, promoted or not) and supports weekly
metadata-only refresh/manual repair. Every run refreshes every channel that has one in
independent matrix legs; a channel without a completed release (stable before its first
Linux release) is skipped and the run succeeds. Signing runs in the existing protected environment,
with tools installed first and no container network. A separate publisher uses GitHub
federation restricted to this repository, main and the named workflow; its service
account owns object access only on the dedicated package bucket, not project IAM,
Firebase, source storage or signing keys. Only that bucket receives the authorized
public-sharing exception tag; untagged resources retain their previous domain restriction.

Before any write, verify independent key trust, signed index/package references and
exact public inventory. Altering a producer inventory must not conceal modified package
or index bytes. Reject expired APT metadata, immutable conflicts and rollback from a
retried older run, each per channel. Retain previous content, publish dependencies first and InRelease
last; verify anonymous SHA-256 delivery and do not publish the private CI inventory.

L2 covers real signed references, ordered writes, retry/failure behavior and existing
inert client fixtures. L3 requires the merged workflow's production-key/federation run,
anonymous public files and real APT/DNF refresh against HTTPS. Bucket access alone is
not repository delivery. Neither level substitutes for native desktop/account upgrades.
See [operations](../desktop/linux-repositories.md).

### Native Linux desktop sessions

Run `Desktop Native Qualification` in manual `linux-session` mode with explicit
`previous_packaging_run` and `packaging_run` inputs selecting retained signed producers.
Its reusable `desktop-linux-session.yml` uses disposable native Ubuntu 24.04 x64
GNOME/Wayland without a tray host and ARM64 KDE/X11 with StatusNotifier. Automatic
PR tooling/SDK checks do not download these finite-retention inputs.
Both use real GNOME Keyring Secret Service;
this does not claim KWallet-provider coverage. Sessions use isolated runner homes and
virtual displays, not CPU emulation. No account credentials or signing/publishing
permissions are available to this workflow.

The credential-free sequence verifies original signed producer artifacts, builds nonshipping
storage probes against each corresponding source, installs the old real package, renders
its anonymous window, performs normal close/native tray Quit, then installs and exercises
the newer package. KDE identifies the app-owned StatusNotifier title, locates its visible
Plasma icon through accessibility and right-clicks it. The visible popup must belong to
that Plasma PID and advertise the native popup window type; OCR reads its actual Quit
label and bounds before a primary pointer click. Preserve the popup image and OCR output
alongside the full-screen menu capture; do not substitute fixed row coordinates.
Plasma 5.27 forwards primary icon clicks as Activate; primary-click menu opening is not
qualified by this scenario. A captured visible menu is required, not just direct DBusMenu
event delivery. Preserve the post-click capture on lookup failure for diagnosis.
Encrypted fixture values must survive replacement; login registration
must create/read/remove correctly. Inspect the captured anonymous windows before accepting
native UI evidence. A window PID or passing mocked driver test is not a rendered-app pass.
Public internal release objects roll away; QA binds to retained successful main producer
runs instead. Expired artifacts require an explicitly selected new increasing pair, not
changed release retention, a silently substituted version or same-version fallback.
Separately compiled signed builds from the same source may verify increasing package
versions and persistence; report that source did not change and do not claim code/schema
migration coverage from that case.

Unavailable Secret Service: after the upgrade the job stops its keyring, and a user D-Bus
service override stops it from being re-activated. The probe's encrypted read must fail
typed at `readMasterKey`, and the signed app must still render and Quit normally. After the
same keyring returns, the original value must read back unchanged. Nothing may replace,
reset or delete the encrypted row or master key while the store is absent.

Debian 13 and Fedora 44 run on the same native CPU in their digest-pinned producer images.
Each installs the previous signed package, upgrades to the current one with the distro
package manager, and checks installed identity. An ordinary user then writes encrypted
probe data through real GNOME Keyring, and the job repeats the absent-store refusal and
the later read-back. The signed app must render on Xvfb against that distro's libraries
with the store both absent and present. Removal must leave no package path or process.
The kernel and display stack are the runner's, so these rows are distro-userspace
coverage, not distro-kernel or Wayland-compositor coverage.

Login autostart: the job installs the current signed package. It enables linger and a
pre-unlocked GNOME Keyring on the user bus, because autologin cannot unlock one with a
password, and writes the exact `IoLaunchAtLogin` registration. Then it starts real
GDM (GNOME/Wayland, x64) or SDDM (Plasma/X11, ARM64) autologin. The app must start as
`--hidden` from the session's own autostart (a gnome-session app scope or a
systemd-xdg-autostart unit), inside an active `user`-class logind session of the
expected type. GNOME has no tray, so the hidden launch keeps its window visible. KDE must
register the app's tray item with no window. A session-manager logout must end the app
with no remaining Sesori process. Authenticated replacement separately proves that
signed first-run defaults write exactly that registration and that it survives the
upgrade. Helper-On restoration at OS login is not separately qualified.

Real account restoration and helper On/Off behavior are separate gates. This workflow
does not publish releases.

### Authenticated Linux replacement

Manual `linux-authenticated-upgrade-probe` in `Desktop Native Qualification` owns
`desktop-linux-authenticated-upgrade.yml`. Both caller and runtime require a main-only
manual dispatch. Use explicit `previous_packaging_run` and `packaging_run` selecting
retained successful original signed internal producers; independent primary-key trust,
byte identity and strictly increasing package versions are unchanged. There is no
signing/publication role or new approval environment. Ordinary PR checks do not execute
this credential-bearing path.

The existing repository QA email/password secrets appear only in the exercise step.
Consume/remove them before starting even the session-bus daemon; pass fixture input
through stdin, never argv, child environments or files. Native x64 GNOME/Wayland and
ARM64 KDE/X11 run serially with real GNOME Keyring. The parent also queues macOS and
Linux authenticated jobs together because they share one account/relay bridge slot.
Both jobs use the same `queue: max` concurrency group with cancellation disabled;
GitHub retains up to 100 pending jobs and rejects further arrivals rather than replacing
older waiters. Authenticated outer workflows use per-run groups so their default pending
slot cannot discard those requests. Other qualification modes keep existing cancellation.
No authenticated capture, OCR, remote desktop, raw app/bridge/auth log or home upload.
The artifact allowlist contains only bounded `result.json` and `failure.json`.
Native fixture failures add a closed `probeFailureReason` check/logout-outcome code to
the failure envelope. Match the whole phase-bound receipt; malformed or unknown receipts
map to `unexpected`, never copied text. The nonshipping fixture observes the existing
bridge repository's deletion response/error without changing requests, idempotent 404
handling or production logout ownership. A retained registration reports
`bridgeDeletionPending` if the repository operation is still awaiting a result after
local logout completes; this observes an unfinished operation, not a specific timeout
or transport cause, and adds no duplicate deadline or timer. A settled deletion error
can expose a closed unauthenticated, HTTP, invalid-response, transport or
unexpected-deletion category.
HTTP rejection receipts may add `probeHttpStatus`, a whole 100–599 integer; reject
wrong phases, appended content and malformed/out-of-range statuses. Original typed
causes and stacks remain private. Distinguish missing registration, incomplete logout,
retained registration and rejected deletion without uploading account identity, URLs,
response bodies, error messages or log excerpts. None of these diagnostics accepts a
failed cleanup, and no extra deletion request is issued.

The current qualification checkout's nonshipping fixture is compiled separately
against each candidate's locked product source/APIs, using its `AuthSession` and
desktop intent service. This is not a historical fixture from each producer, handwritten
token rows or a replacement GUI. A production transport fix requires a new signed current
producer that contains it; a newer qualification checkout against unchanged candidate
libraries cannot qualify that fix. Initial email login returns the stable `AuthUser.id`;
later phases compare that private id, not the opaque provider id or email. Identity
metadata stays inside the owned home and travels through stdin, never uploaded.
Login seeds only the older version and leaves bridge intent unset. The old signed GUI's
genuine first-run defaults must then admit On, serve the relay and write the exact login
registration that the credential-free login job boots. Every helper-On launch, including
the one after replacement, rechecks those registration bytes. Exercise signed
old GUI On then Off, normal close/native tray Quit and no orphan helper; install the
new package and, on the acceptance path, launch its signed GUI with preserved Off
**before** the fixture built against that candidate may write anything. Verify local account/Off preservation, set On and exercise
the new signed GUI's authenticated packaged helper/relay readiness and normal Quit.
Only the initial fixture may perform email login; preservation checks are local and
never refresh or reseed. Cleanup loads the existing registration tracker and invokes
`DesktopLogoutOrchestrator`. Successful post-helper cleanup requires the persisted,
account-matching registration before logout and its confirmed removal afterward;
a missing record is not proof that nothing needs deletion. After initial seeding,
in-process completion, errors and `SystemExit` unwind through the cleanup scope:
stop only owned GUI groups and attempt unregistration while bus/keyring/home remain.
Only successful cleanup and package removal permit success JSON. Never invalidate
all account sessions. Failed cleanup, Actions cancellation, step timeout or VM loss
can bypass or interrupt that scope and leave a QA-only bridge registration; no guaranteed teardown
is claimed. Failed disposable-VM package residue also remains bounded. Never accept
an interrupted or failed job as evidence.

GNOME closes the process-owned native window without a tray host. KDE right-clicks
the actual accessible app tray icon and requires a visible Plasma-PID-owned popup.
Read-only advertised menu metadata must end in enabled `Quit Sesori`, including the
DBusMenu protocol's `enabled=true` default when that property is omitted. Normal
End/Return keyboard navigation activates that host action. Do not capture authenticated pixels,
use copied row coordinates, inject DBusMenu events or substitute forced termination.
This is keyboard-activation evidence, not a new pointer/visual qualification claim.
Record the existing tray-disposed diagnostic as a boolean if observed; passing Quit
must not conceal it as a warning-free run.

Accept only successful post-merge native results from both CPUs. Mocked contracts,
fixture analysis or a green PR do not qualify account restoration. These virtual
Ubuntu sessions do not establish actual OS-login/autostart, unavailable Secret Service,
KWallet or other nominated distro coverage. Same-source packages establish replacement
and persistence, not code/schema migration. Those gates and stable admission stay open.
No OAuth/browser/MFA login-flow qualification is claimed.

### Private interactive Linux diagnostics

`Desktop Native Qualification` has a manual-only `linux-interactive-debug` mode for
native x64 or ARM64 KDE/X11 runners. It verifies one explicitly selected retained
signed internal producer before network admission; no rebuild, publishing, account
credentials or signing secrets are involved. This mode is not a qualification pass.

The `desktop-linux-debug` environment permits only `main` and the dedicated QA branch.
GitHub OIDC binds the repository/environment subject, workflow name and
`workflow_dispatch` claim to `tag:sesori-ci-debug`; its only configured variables are
non-secret `TAILSCALE_CLIENT_ID` and `TAILSCALE_AUDIENCE`. Tailnet policy permits admins
to reach tagged runners on SSH port 22 as `runner`, with no runner-initiated tailnet
grant. Preserve unrelated policy rules when configuring this access. No long-lived
auth key or client secret is used.

VNC listens only on loopback and requires an SSH tunnel. Advertise readiness only
once the VNC process is alive and its loopback listener accepts connections.
The desktop has a disposable home and real GNOME Keyring, a 20-minute ready window, an explicit stop pipe and a
40-minute job ceiling. Disable Plasma's idle lock only in that disposable home before
starting the desktop; do not unlock or reconfigure the operator's workstation. Cleanup terminates owned process groups, removes the fixture
installation/home and logs the ephemeral node out. Diagnostic concurrency is separate
from packaging; it must never cancel a shared release. Reusable callers admit the
callee's OIDC scope even though the debug job is skipped; ordinary callee jobs retain
the read-only default token. Interactive screenshots, homes and session log files are
not uploaded as artifacts. CI run metadata and step logs retain the connection summary.
Operators must not log into a real account or introduce credentials; deliberately
collected evidence needs privacy review. Interactive success does not replace automated
native/account/upgrade/stable acceptance.

## Linux internal-preview publication

The shared internal cycle builds both native Linux CPUs with its source/build number
and compiled `internal` channel. The existing native workflow also accepts those same
inputs for bootstrap against an already-published shared tag; its own run number is not
an aligned release number. Retained compiled defines must match the sealed identity.
Product SDK, icon, plugin dependencies and package construction come from the selected
main-ancestor source. Signing and container qualification use the trusted workflow
checkout. Parallel Linux/macOS reusable calls have distinct concurrency groups.

The Linux publisher requires both native package sets, matching signed/unsigned
provenance, clean source and all six package fixtures. Both signer reports and checksum
signatures must match the repository's approved primary fingerprint, independently of
producer configuration or downloaded key material. Its `--channel` must equal the compiled
channel; binaries are never relabeled. Internal requires an existing public
`v<X.Y.Z>-internal.<N>` pre-release; stable requires the existing non-draft approved
`v<X.Y.Z>`, promoted or still a pre-release, exactly as macOS does. Either tag must resolve
to that exact source. Production builds stable packages from the approved source/build
before approval and attaches them only after `submit-release.yml`'s `release` job;
`bridge-only` skips Linux, and a Linux failure leaves the release, tag and macOS unchanged.
Core CLI and macOS assets remain untouched. Each public asset is anonymously hash-checked;
identical retries are allowed, conflicting bytes are never overwritten.
`desktop-linux-release.json` is uploaded last and does not depend on macOS completion.
Per-CPU `desktop-linux-<arch>-checksums.txt`/`.asc` pairs retain their original signed
bytes. `desktop-linux-public.asc` is separate from the core CLI owner's replaceable key
asset, even though both use the same signing key. Private evidence never becomes a
release asset. The publisher cannot create/promote releases, move tags or change Latest.

Native GUI/login/keyring/tray and N→N+1 upgrades were qualified on earlier signed builds,
not per release; the manifest's `proofBoundary` says so. Fixture tests alone do not
establish production-key access or public retrieval.

Public acceptance on 2026-10-13 used native producer `38438783418` for aligned
`1.9.1+1013` and publisher `38443588001`. Both compiled internal identities and all six
package fixtures passed. Independent anonymous retrieval authenticated both checksum
signatures against the separately known primary and all four package hashes. Existing
13 core/macOS asset identities, release identity/content/channel, tag and Latest were preserved; original
core/macOS checksum and manifest bytes also matched. No store dispatch or local app
installation occurred. Exact sources, trees and hashes live in the distribution plan's
[step 9](../../.plan/active/desktop-distribution/steps/step-09.md).

## Shared release cycle and private preparation

Private `macos-packaging` and `linux-packaging` accept immutable `source_sha` and `build_number`
overrides, validating main ancestry before building. This qualifies the exact selected
production source/build without enabling publication or submitting anything to stores.
The workflow's toolchain-selector action stays at its own revision; product SDK and
packaging scripts come from the selected source. Its helper checkout is excluded only
from CI's Git untracked-file check, not by weakening source cleanliness validation.

Internal macOS desktop builds participate in the existing bridge/mobile release cycle
with the same source commit and resolved build number. Desktop-only product changes
now qualify for that cycle. Native x64 and arm64 signing, notarization, extracted-helper
and GUI-fixture checks remain required. Stable submissions rebuild the selected source
with the stable channel rather than relabeling an internal binary. Beta and explicit
`bridge-only` submissions retain their scope. Scheduled run `36175398399` exercised
this internal flow end to end for `1.9.1+983`, with desktop publication skipped and
read-only shared-producer preparation accepted separately. This does not establish
stable production attachment or public desktop retrieval.

Reusable native-desktop callers
must grant `contents: read`, `actions: read` and `pull-requests: read`: GitHub validates
the nested upgrade jobs' PR-provenance permission even when those jobs are skipped.
A missing scope rejects the entire caller before its release gate can execute.

Desktop attachment follows the existing shared release finalizer; production already
passed `store-production`. Desktop failure does not change bridge/mobile success conditions.
Internal rollover retains the newest completed public prerelease independently for
macOS (`desktop-release.json`) and Linux (`desktop-linux-release.json`), alongside the
current core release. Older previews retire only after their platform has a newer completion.
A failed build or attachment on one platform preserves its last downloadable preview,
even when the other platform advances. Markers are the publishers' last-uploaded signals,
not persistent pointers or another release owner.
Stable bridge/npm cleanup skips completed desktop previews even when stable desktop
assets exist: an internal channel must not be forced onto stable. This also preserves
previews during bridge-only production or pending/failed stable desktop attachment.
`DESKTOP_MACOS_PUBLICATION_ENABLED` defaults off; the user admitted macOS on 2026-09-26
and it is now `true`. Linux internal previews were admitted on 2026-10-13. Stable Linux
publication is wired through production without a separate variable; it has no live
release yet. Windows remains unadmitted.

Admitted macOS publication attaches four installers, `desktop-checksums.txt` and
`desktop-release.json` to existing product tags. It never creates/promotes a release,
changes Latest, or replaces bridge assets/checksums. Each asset is retrieved without
authentication and hash-verified. Retries reuse identical assets and refuse conflicting
bytes; metadata is last, and website links wait for public retrieval/trust acceptance.
Private evidence/logs/screenshots are never release assets.

The manual Desktop Release Preparation workflow consumes both native macOS package
artifacts from one successful qualification/shared release run. It checks source/version/build,
compiled channel, clean-source evidence, accepted notarization receipts, inventory
agreement and payload hashes before producing private metadata and checksums.
Preparation, producer workflow and package sources are recorded separately. A shared
finalizer can validate its own in-progress run only after the native build dependency
succeeds; another selected run must be successful. Old producer runs without channel
evidence are rejected rather than assigned a guessed channel.

Preparation has read-only repository/Actions permissions and never signs, executes
packages, creates tags/releases, edits website links, or triggers CLI/mobile release
work. These are evidence-consistency checks, not independent signature verification
or permission to ship. Publication and native/interactive acceptance require their own evidence.

## Private macOS manual-replacement qualification

Manual `macos-upgrade-probe` qualification is credential-free and consumes two
retained successful macOS qualification/shared release runs on each package's native CPU. It runs only
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
sentinels. Cleanup removes only probe-owned paths. Main-only run `36175102660`
accepted `1.8.4+24 → 1.9.1+981` on native x64 and arm64. Both prior/current helper
observations on both CPUs record `NO_INSTALLED_HELPER`; all 11 report checks are true,
including `helperAbsentBeforeQuit`. Exact artifacts, hashes and historical investigation
remain in [the step evidence](../../.plan/active/desktop-distribution/steps/step-06.md).

The recorded authenticated replacement evidence below predates the shared-store
cutover and applies only to its named sources. The current authenticated fixture
still seeds per-value Keychain entries; do not run that seed path against a
shared-store candidate or treat the old passes as shared-store qualification.
Required adaptation must seed through production Dart storage and select a
shared-format baseline, preserving the isolated credential/cleanup boundaries.
The CI-only packaged platform probe now targets shared SQLite/master roundtrips;
its source change alone does not establish a native pass.

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
signing partitions. Credential-value reads and writes therefore use the same signed helper.
Writes consume stdin; value reads are privately captured and never logged. The `security`
tool still performs metadata-only absence checks and deletion of probe-owned items; those
operations do not need to decrypt the credential.
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
packages; later stages reuse privacy-safe production log messages. A package's marker
support must not be inferred from the newer qualification tooling's source.
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
alone is not accepted helper-On evidence; both CPUs must pass from merged `main`.
Run `36174286284` accepts the same `1.8.4+24 → 1.9.1+981` pair on native x64 and arm64:
all 15 checks are true, each prior/current launch has an exact live authenticated helper
and relay readiness, and both final phase records confirm completion and cleanup.
Artifact digests and bounded records were verified, not just job conclusions. This does
not prove failed-stop refusal, interactive browser/login/TCC, minimum-OS support, arbitrary
user-history preservation, public retrieval or release readiness. Read-only preparation
`36171714173` separately regenerated stable build-981 metadata/checksums from package
run `36168531963`; it is not publication or permission to ship. Internal build 983's
shared-cycle success is separate evidence, not authenticated replacement acceptance
for that different source/channel.

## Current evidence boundary

Private package mechanics are qualified for both native CPUs on all three desktop
platforms: signed/notarized/stapled DMGs and ZIPs containing the signed/notarized/stapled
app on macOS (the ZIP itself is not signed or stapled), unsigned per-user EXE
construction and isolated fixtures on Windows, and unsigned DEB/RPM construction plus
six native package-manager fixtures on Linux. Separate signed Linux qualification and
public internal delivery are recorded above. macOS and Linux internal installers are
public; stable Linux and Windows availability are not implied.
Exact accepted sources, runs, hashes and proof limits stay
in the active distribution plan's [macOS](../../.plan/active/desktop-distribution/steps/step-06.md),
[Windows](../../.plan/active/desktop-distribution/steps/step-07.md), and
[Linux](../../.plan/active/desktop-distribution/steps/step-09.md) evidence.

On 2026-09-26 the user retired the remaining macOS/parent Gate C QA requirements with
coverage gaps accepted. Minimum-OS execution, remaining phone/live-harness scenarios
and candidate-specific manual attribution are not newly passing evidence and do not
block macOS publication. Existing shutdown tests are not native fault injection.

Internal `1.9.1+987` installers were published from a successful shared producer. All
four payloads, desktop checksums and the last-uploaded manifest passed anonymous public
hash verification. Both CPUs' apps/DMGs passed independent Developer ID, stapled-ticket
and Gatekeeper checks without local app execution. Bridge assets and Latest stable
were unchanged. Ordinary shared run `36230719108` then completed automatic desktop
attachment for `1.9.1+991`; this was not another local bootstrap or scheduler no-op.
Website PR `sesori-ai/landingpage#111` merged and automatically deployed. Live browser
verification on 2026-09-26 selected `1.9.1+993`, exercised all nine anchors and preview
navigation, and confirmed both anonymous links/sizes and manifest/checksum agreement.
Stable schema/platform boundaries, mobile width and zero browser exceptions were checked.
Those checks do not claim new full-byte hashing, Apple trust or native execution.
Stable production attachment remains separate. Windows signed N→N+1 and Linux
signed-repository N→N+1 requirements remain open.
Shared-store native roundtrip, cold reopen, replacement and authorization remain
unproved by pre-cutover package evidence; the retired gate does not relabel that
historical evidence as shared-store qualification.

## Coverage

- **L1:** Destination tests cover both channels and CPUs, Linux and source guidance;
  widget tests exercise external-link dispatch without claiming release availability.
- **L2:** Offline preparation fixtures cover both CPUs, channel/source mismatches,
  altered payload/evidence, missing packages, deterministic output and no overwrite.
  The actual internal-rollover shell runs with a fake GitHub boundary to verify repeated
  desktop failures retain the last completed preview, newer completion retires older
  previews, pre-desktop cleanup stays intact and current-release retries remain valid.
  The npm-cleanup shell separately preserves desktop previews with or without stable
  desktop assets while still deleting same-version core-only internal releases.
  Windows fixtures cover identity/CPU refusal, complete native inventory, the pinned vpk
  install and pack arguments, exact-bundle and embedded-package refusal, the runner's
  hook handling and no-overwrite diagnostics.
  Linux publication fixtures cover compiled-channel/source/build refusal, real GPGV
  checksum verification, independent platform completion, anonymous delivery failure,
  immutable retries and separate core/macOS ownership. Package fixtures cover identity/CPU
  refusal, payload layout and symlink preservation,
  source-derived dynamic-loading audit, generated dependency invocation, bounded
  ownership and absence of package lifecycle scripts. macOS upgrade fixtures cover
  producer/run/source/channel/identity ordering, altered DMGs, dirty-source refusal,
  credential source isolation, stdin-only Keychain writes, bounded auth evidence and
  main-only environment scoping. Staging parser/default/invalid-channel and exact
  dotenv tests; Settings
  composition retains attention controls. Generated fragments match specification headings.
  Website resolver/SSR fixtures cover incomplete newer releases, page-two stable
  and older Linux discovery, independent platform completion, every missing Linux asset,
  channel isolation, malformed metadata, cache reuse/failure logging and all anchors.
  Crawler FAQ coverage prevents a correct platform summary from hiding a stale answer.
  These run in `sesori-ai/landingpage`, without live GitHub fixture dependencies.
- **L3:** Real Settings navigation and external-browser dispatch on a packaged native
  build. Verify the browser lands on the website section matching the build's channel,
  OS and CPU. No published installer is needed to check browser dispatch.
  Linux repository delivery additionally requires production-key/federated publication,
  anonymous public files and real APT/DNF refresh against HTTPS.
- **L4:** Actual publisher verification and signed N→N+1 manual replacement with
  helper On/Off, failed-stop refusal, normal Quit/no relaunch, and data preservation.
- **L5:** All recorded native platform/package/host gates in the active distribution
  plan, downloaded artifacts, trust checks and public links. The deployed website
  browser checks prove live preview selection, anchors, channel/platform presentation
  and anonymous link/metadata agreement only, not native Settings dispatch or installation.

L1/L2 do not establish installation, native trust, real-account restoration, minimum
OS or publication. Published internal macOS and Linux assets have separate recorded trust proof;
unshipped platforms/channels remain unavailable. A merged index alone is not a release.
See [packaging](desktop-macos-packaging.md), [supervision](desktop-bridge-supervision.md)
and [download instructions](../desktop/downloads.md).

## Failure signals

Wrong channel/CPU fragment, guessed architecture for source builds, private or
unshipped artifact links, permanently pinned previews, core-only releases hiding usable
desktop downloads, stable schema borrowing preview availability, a dead Linux/self-update button, raw release-version
inference, losing attention settings, startup network waits, or a download action
that stops/restarts the app or helper. On Windows, changing login intent during install,
a hook that starts the GUI, a silent install that launches the app, wrong-CPU payloads,
uninstall leaving the login value, or uninstall touching data outside the install folder
are failures. Linux package ownership of
`/usr/bin/sesori-bridge`, user homes or autostart entries; guessed runtime dependencies;
non-native container execution; package scriptlets; altered staged payloads; or calling
a same-version reinstall an N→N+1 upgrade are failures. Manual replacement must never
delete shared credentials, harness runtimes, databases, history or projects.
