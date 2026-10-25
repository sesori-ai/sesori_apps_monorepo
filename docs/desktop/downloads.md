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

## Updating safely

macOS and Windows use manual signed-installer updates, not automatic updates.
Download the published package for your existing channel and CPU. Select **Quit**
in Sesori and wait for it to exit before replacing or installing. Closing the
window may only hide it to the tray. If Quit reports a helper-stop failure, do not
replace the running app; resolve that failure first. Reopen Sesori manually after
installation; last-On/Off intent is preserved by ordinary startup.

On macOS, verify the publisher **DigitalBlock Labs LTD (AQNCF7663C)** and normal
Gatekeeper acceptance. Copy the complete Sesori app from the DMG into Applications;
do not replace just the helper or run daily use from the mounted DMG. Never bypass
Gatekeeper or delete Keychain items to make an update work. Shared CLI credentials,
harness runtimes, databases, session history and projects are not update cleanup.
Windows publisher and installation instructions will accompany a signed public
release. Private unsigned per-user installers have passed isolated native package
fixtures, but they are not downloads and do not establish SmartScreen, interactive
GUI/account behavior or a signed N→N+1 update.

Internal is an explicit test channel, not an automatic promotion to stable.
Internal build 987 uses the older per-value native storage format. Before replacing
that build with a shared-store preview, sign out in the old app, Quit, install the
new package, then sign in again. Internal format changes do not carry a production
migration promise; old-format replacement proof does not qualify the new format.
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

Signed APT and RPM repositories and stable Linux downloads remain unpublished.
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
RPMs have native signatures; DEBs are covered by signed checksums. Package fixtures
cover Ubuntu 24.04, Debian 13 and Fedora 44, not GUI/login/keyring/tray behavior or a
real N→N+1 upgrade. Those gaps are accepted only for internal previews.

Each Linux producer also emits a portable `Sesori-linux-<arch>-<version>-<build>.AppImage`;
the image itself is unsigned and its checksum is in the signed checksums. It needs host GTK 3,
libsecret, EGL/GLES, glibc 2.39 or newer and FUSE. Mark it executable and run it. To update,
quit Sesori and replace the image at the same path and file name, so launch at login keeps
working. Its app destination is
`<channel>-linux-<x64|arm64>-appimage`, on the website. Native qualification runs on Arch
Linux (x64) and the community Arch Linux ARM port (ARM64); it is not a universal-distro claim.

Linux preview anchors are `internal-linux-<x64|arm64>-<deb|rpm>`, in addition to the
unchanged `linux-package-managers` app destination. Each available row links the
experimental limitations note; direct links must not bypass disclosure.

DEB/RPM previews require manually downloading, verifying and installing each package;
they do not configure automatic repository updates or establish N→N+1 safety.
Replacement remains package-manager-owned, not app-managed. Quit Sesori first;
never treat shared CLI credentials, databases, runtimes or projects as update cleanup.
Repository installation commands appear only after separate repository qualification
and explicit publication approval.
