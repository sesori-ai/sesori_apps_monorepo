# Sesori desktop downloads

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
Windows publisher and installation instructions will accompany its qualified release.

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

Signed APT and RPM repositories are not published yet. Linux updates will be owned
by the package manager, not an app-managed updater. Quit Sesori before upgrading.
Repository keys, supported distributions, CPU-specific install commands and signature
verification instructions will appear here only after qualification and publication.
