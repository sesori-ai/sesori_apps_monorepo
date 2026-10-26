# Sesori desktop downloads

Publication content specification for **https://sesori.com/desktop/**, which is live
and built from the `sesori-ai/landingpage` repository. The app opens that website, not
this repository document. The page renders every channel/OS/CPU heading anchor below
plus `linux-package-managers`, and its contract checks fail when one is renamed or
removed. Its `src/lib/desktop-downloads.ts` resolves completed public shared releases;
individual preview builds do not need a source edit or website redeployment.

**Stable/internal macOS installers and native Linux DEB/RPM previews are public for both CPUs.**
Both platforms' website downloads are live, independently selected by completion marker.
Stable macOS `v1.9.1` ships build `1017` from source
`8bfeda9416c96ea5de70ffc701a36b738f24eff7`, packaging run `38537594836`.
Both stable DMG links appeared on the live website and returned HTTP 200 on 2026-10-14;
this is publication evidence, not new native/account upgrade qualification.
Windows and stable Linux are not published yet. Linux internal build `1.9.1+1013`
passed independent anonymous package/signature verification on 2026-10-13.
The website selects each platform's newest completed preview rather than pinning
its first publication.
Private CI artifacts are not public links. This index never substitutes a mobile/CLI
release or private evidence for a desktop installer.

Release discovery is anonymous and cached for five minutes, including logged failed
lookups. All release pages share one five-second timeout on the fixed repository
endpoint. A completed macOS entry requires the desktop manifest/checksum assets and
both native DMGs with valid index sizes/SHA-256 digests. The publisher uploads the
manifest last; the website does not rehash packages or parse that manifest on each
lookup. Displayed checksums and manifest links support independent verification.
Linux internal completion independently requires its `desktop-linux-release.json`, all
four version/build-matched DEB/RPM names, both checksum/signature pairs and desktop
public key, each with valid index sizes/hashes. Discovery does not verify OpenPGP itself.
Preview availability never creates stable controls, version metadata or offers.

The website's base branch deploys automatically after push/merge, normally within
1–3 minutes. A source merge alone is not live-page verification; allow the existing
deployment to finish instead of creating a redundant deploy commit.

## Updates

Sesori Desktop updates itself, together with the bridge it bundles. A new version
downloads in the background and installs when you **Quit** or choose
**Restart to update** in Settings or the tray menu. Each install follows only its own
channel and CPU:

- **macOS (DMG or ZIP):** Sparkle, from the EdDSA-signed appcast.
- **Linux AppImage:** Velopack, which replaces the image in place, so launch at login
  keeps working. The app verifies the feed's Ed25519 signature before Velopack reads it.
- **Windows:** Velopack, the same way, from the first public Windows release.
- **Linux DEB/RPM:** the package registers Sesori's signed repository on install
  ([package registration](linux-repositories.md#package-registration)), and the
  system's software updater installs new versions. The DEB adds the Sesori origin to
  unattended-upgrades, so where that runs (Ubuntu's default) updates install silently.
  RPM installs update silently where `dnf-automatic` is enabled. Elsewhere they arrive
  through the system's normal update prompt. Once the package is replaced, the running
  app offers **Restart to update**.

**Settings → Desktop updates → Automatic updates** is on by default. Off stops the
background checks; **Check for updates** still checks once on demand. On DEB/RPM the
toggle covers only the app's own check and prompt; silent installs follow the system
updater's configuration. Signing keys and feed locations are in
[desktop update signing](update-signing.md).

On macOS, verify the publisher **DigitalBlock Labs LTD (AQNCF7663C)** and normal
Gatekeeper acceptance. Do not run daily use from the mounted DMG. Never bypass
Gatekeeper or delete Keychain items to make an update work. Shared CLI credentials,
harness runtimes, databases, session history and projects are not update cleanup.

Windows publisher and installation instructions will accompany a signed public
release. Private unsigned per-user installers have passed isolated native package
fixtures, but they are not downloads and do not establish SmartScreen, interactive
GUI/account behavior or a signed N→N+1 update.

Internal is an explicit test channel, not an automatic promotion to stable.
The sections below do not imply every platform/channel has a release. Do not use
GitHub's generic Latest release to choose a desktop installer.

## Stable macOS x64

Available in the newest stable [shared release][shared-releases] with a desktop completion manifest:
`Sesori-macos-x64.dmg` or `Sesori-macos-x64.zip`. Verify against its
`desktop-checksums.txt` and `desktop-release.json`, not bridge `checksums.txt`.

## Stable macOS arm64

Available in the newest stable [shared release][shared-releases] with a desktop completion manifest:
`Sesori-macos-arm64.dmg` or `Sesori-macos-arm64.zip`. Verify against its
`desktop-checksums.txt` and `desktop-release.json`, not bridge `checksums.txt`.

## Internal macOS x64

Available in the newest internal [shared release][shared-releases] with a desktop completion manifest:
`Sesori-macos-x64.dmg` or `Sesori-macos-x64.zip`. Verify against its
`desktop-checksums.txt` and `desktop-release.json`, not bridge `checksums.txt`.

## Internal macOS arm64

Available in the newest internal [shared release][shared-releases] with a desktop completion manifest:
`Sesori-macos-arm64.dmg` or `Sesori-macos-arm64.zip`. Verify against its
`desktop-checksums.txt` and `desktop-release.json`, not bridge `checksums.txt`.

macOS previews advance only when `desktop-release.json` completes publication.
The shared cycle retains the newest completed internal release independently per
platform while newer core-only releases build or desktop fails. Older previews can
roll away after their platform has a newer completion. The website must select each
platform's newest completed preview, not merely the newest core release. Stable bridge/npm publication preserves
completed internal previews too; it does not replace their channel with stable.
Do not pin a permanent website link to the first internal tag or use Latest stable
as a substitute.

[shared-releases]: https://github.com/sesori-ai/sesori_apps_monorepo/releases

## Stable Windows x64

No public download is available.

## Stable Windows arm64

No public download is available.

## Internal Windows x64

No public download is available.

## Internal Windows arm64

No public download is available.

## Linux package managers

Production attaches stable Linux DEB/RPM/AppImage files to the approved `v<X.Y.Z>`
release with its own `desktop-linux-release.json` (`channel: stable`); none is published
yet. Signed [APT/RPM repositories](linux-repositories.md) host `internal` and `stable`
separately; stable appears after the first stable Linux release.
Opt-in internal DEB/RPM previews use `desktop-linux-release.json` as their independent
completion marker, with native x64/arm64 packages named
`Sesori-linux-<arch>-<version>-<build>.<deb|rpm>`. The website must not infer them from
CLI tarballs, private artifacts or macOS completion. Public native producer `38438783418`
and publisher `38443588001` established shared internal build `1.9.1+1013`, with both
signatures and all package hashes independently verified. Existing core/macOS asset identities,
release content/channel, tag and Latest remained unchanged. Website PR `sesori-ai/landingpage#112`
deployed normally. Live verification at 2026-10-13T19:20:22.227Z confirmed all four
package/verification links, 13 anchors, 32px desktop/mobile preview spacing and
unavailable stable/repository state.
[Qualification evidence](../../.plan/active/desktop-distribution/steps/step-09.md)
keeps public delivery separate from native GUI/account/upgrade proof.

Verify each CPU's `desktop-linux-<arch>-checksums.txt` and `.asc` using
`desktop-linux-public.asc` and the independently pinned primary fingerprint in
[Linux signing guidance](linux-signing.md). This is not an APT/RPM repository key setup.
RPMs have native signatures; DEBs are covered by signed checksums. Per-release package
fixtures cover Ubuntu 24.04, Debian 13 and Fedora 44. Native GUI/login/keyring/tray and
N→N+1 upgrades were qualified separately on earlier signed builds, not for every release.

Each Linux producer also emits a portable `Sesori-linux-<arch>-<version>-<build>.AppImage`;
the image itself is unsigned and its checksum is in the signed checksums. It needs host GTK 3,
libsecret, EGL/GLES, glibc 2.39 or newer and FUSE. Mark it executable and run it from a
fixed path; it [updates itself](#updates) in place there. Its app destination is
`<channel>-linux-<x64|arm64>-appimage`, on the website. Native qualification runs on Arch
Linux (x64) and the community Arch Linux ARM port (ARM64); it is not a universal-distro claim.

Linux preview anchors are `internal-linux-<x64|arm64>-<deb|rpm>`, in addition to the
unchanged `linux-package-managers` app destination. Each available row links the
experimental limitations note; direct links must not bypass disclosure.

Installing a DEB or RPM registers its channel's repository, so later versions arrive
through the system's software updater ([updates](#updates)); replacement stays
package-manager-owned, not app-managed. Never treat shared CLI credentials, databases,
runtimes or projects as update cleanup. Repository installation commands appear only after separate repository qualification
and explicit publication approval.
