# Sesori desktop downloads

Publication content specification for **https://sesori.com/desktop/**, which is live
and built from the `sesori-ai/landingpage` repository. The app opens that website, not
this repository document. The page renders every channel/OS/CPU heading anchor below
plus `linux-package-managers`, and its contract checks fail when one is renamed or
removed. Publishing a row means registering the verified public artifact in that
repository's `src/lib/desktop-downloads.ts` and updating the matching section here.

Desktop packages are undergoing private qualification. **No public desktop release
is available yet.** Private CI artifacts are not supported public downloads. This
index lists only verified public artifacts after the relevant release gate passes;
it never substitutes a mobile/CLI release or a private artifact.

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

Internal is an explicit test channel, not an automatic promotion to stable. The
sections below do not imply a release exists. Do not use GitHub's generic Latest
release to choose a desktop installer.

## Stable macOS x64

No public download is available.

## Stable macOS arm64

No public download is available.

## Internal macOS x64

No public download is available.

## Internal macOS arm64

No public download is available.

## Stable Windows x64

No public download is available.

## Stable Windows arm64

No public download is available.

## Internal Windows x64

No public download is available.

## Internal Windows arm64

No public download is available.

## Linux package managers

Signed APT and RPM repositories are not published yet. Private unsigned x64/arm64
DEB and RPM packages have passed native Ubuntu 24.04, Debian 13 and Fedora 44 package
fixtures; they are not supported downloads and same-version reinstall is not N→N+1
upgrade proof. Linux updates will be owned by the package manager, not an app-managed
updater. Quit Sesori before upgrading. Repository keys, supported distributions,
CPU-specific install commands and signature verification instructions will appear
here only after qualification and publication.
