# Step 2 — Native Distribution Qualification

Status: **in progress**. This is evidence and qualification output, not a shipping
claim. Source checkout began at `ef6f3d6548` (plan PR #1483), 2026-09-15.
No product release, distribution signing, or cloud provisioning has been performed.
Local build-tool ad-hoc signatures are not Developer ID/notarization evidence.

## Pinned Flutter/Dart and six-target build routes

Local native host: macOS arm64. `flutter --version --machine` reports:

- Flutter `3.47.4`, stable
- Framework revision `9584c6713b324636289d067944a46fd6b49df14b`
- Engine revision `06a2e2a110089dff50fe635cffd2a61e1b24fbcd`
- Dart `3.13.3`

The official release manifests contain these exact pinned archives:

| Host SDK | Published archive | Evidence boundary |
|---|---|---|
| macOS x64 | `stable/macos/flutter_macos_3.47.4-stable.zip` | Manifest only; GUI build not run here. |
| macOS arm64 | `stable/macos/flutter_macos_arm64_3.47.4-stable.zip` | Native release build, binary inventory and relocated-helper integration passed; see evidence below. |
| Windows x64 | `stable/windows/flutter_windows_3.47.4-stable.zip` | Manifest only. |
| Linux x64 | `stable/linux/flutter_linux_3.47.4-stable.tar.xz` | Manifest only. |
| Windows arm64 | No prepacked Flutter SDK archive in the pinned Windows manifest | Pinned source bootstrap and ARM64 Dart asset available; native GUI build still required. |
| Linux arm64 | No prepacked Flutter SDK archive in the pinned Linux manifest | Pinned source bootstrap and ARM64 Dart asset available; native GUI build still required. |

All listed archives map to the same framework revision and Dart version. A missing
prepacked SDK is not proof that the target is unsupported:

- The pinned `bin/internal/update_dart_sdk.ps1` detects ARM64 and selects
  `dart-sdk-windows-arm64.zip`; its shell counterpart handles Linux ARM64.
- HEAD requests for both engine-pinned Dart bootstrap archives returned HTTP 200:
  `https://storage.googleapis.com/flutter_infra_release/flutter/<engine>/dart-sdk-<os>-arm64.zip`.
- The pinned Windows build source maps `TargetPlatform.windows_arm64` to CMake
  `ARM64`; the Linux build source contains native/cross-target ARM64 support.

Next proof: bootstrap the exact official framework revision on native ARM64 CI
hosts, build the actual GUI/native plugins and helper, and inspect resulting
architecture. Do not substitute an emulated x64 app or call these targets qualified
from manifest/source availability alone. No custom Flutter fork or toolchain upgrade
is approved or currently indicated by this evidence.

Sources:

- `https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json`
- `https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json`
- `https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json`
- Flutter source at the framework revision above:
  `bin/internal/update_dart_sdk.{sh,ps1}`,
  `packages/flutter_tools/lib/src/{windows/build_windows,linux/build_linux}.dart`

## Windows update path: manual by user-approved simplification

Audited the released **WinSparkle 0.9.4** public header, not merely current website
wording or an unreleased branch:

`https://github.com/vslavik/winsparkle/blob/v0.9.4/include/winsparkle.h`

- `win_sparkle_check_update_without_ui` explicitly says that an available update
  shows the usual update-available window and that the function is **not completely
  UI-less**. It silently checks; it does not silently prepare a download.
- `win_sparkle_check_update_with_ui_and_install` shows progress UI and immediately
  installs when an update is found. That is not the approved prepare-now/quit-later
  behavior.
- `win_sparkle_set_user_run_installer_callback` can handle an already-downloaded
  payload; it does not provide an unattended download operation. Its default
  shutdown-request callback occurs after installer launch, as previously recorded.
- The released public operation surface offers those checks and installer/shutdown
  callbacks, but no independently callable silent download/preparation operation.

WinSparkle does not satisfy the original automatic-preparation policy through its
supported public API. After this finding, the user explicitly prioritized mature,
widely used tools and low complexity over automation, accepting a dedicated update
button with no automatic updates. D6 now records that decision.

**Selected Windows path:** a Download update button opens the official channel/CPU
page; users Quit normally and run the signed per-user Inno Setup installer. No
embedded Windows updater, retained download, custom signature protocol, background
checker, or shutdown callback bridge is required. An Inno `AppMutex` check refuses
install/uninstall while the GUI remains open; disable automatic/forced application
closing and restart. Verify the running-app refusal and normal helper shutdown on
a native host before shipping. Existing URL-launching and Quit ownership remain.

### Maturity and trust evidence

- Sparkle's project history dates to 2006 and names OBS, VLC, Wireshark and other
  adopters: `https://sparkle-project.org/about/`. Retain it for macOS; do not replace
  mature native behavior with a custom updater to achieve uniformity.
- Inno Setup dates to 1997 and names VS Code and Git for Windows as users. VS Code's
  actual `build/win32/code.iss` confirms use. This establishes adoption, not that its
  extensive custom background-update scripting should be copied into Sesori.
- WinSparkle is established too: Wireshark's current developer documentation and
  update headers describe its integration; MuseScore 3's release notes document
  historical use. Its omission here is about unnecessary integration cost, not a
  claim that it is untrustworthy.
- Inno Setup latest stable audited release: `7.1.0` (`is-7_1_0`, 2026-08-12).
  `SetupArchitecture` supports x86/x64, not a native ARM64 launcher. The user
  explicitly accepts launcher-only emulation; installed GUI/helper/libraries must
  still be native. They have no Windows ARM QA device. CI build/loader evidence
  must not be presented as completed interactive install/update QA.
- Verify Inno license terms and the project's commercial license request before
  commercial packaging; no license purchase is authorized by qualification.

Sources:

- `https://jrsoftware.org/isinfo.php`
- `https://github.com/microsoft/vscode/blob/main/build/win32/code.iss`
- `https://www.wireshark.org/docs/wsdg_html_chunked/ChLibsSparkle.html`
- `https://musescore.org/en/3.0`
- `https://jrsoftware.org/ishelp/topic_setup_appmutex.htm`
- `https://jrsoftware.org/ishelp/topic_setup_closeapplications.htm`
- `https://jrsoftware.org/ishelp/topic_setup_setuparchitecture.htm`
- `https://jrsoftware.org/files/is/license.txt`

### Investigated but not adopted: Velopack 1.2.0

The released C/C++ API has the lifecycle primitives WinSparkle lacks:

- `vpkc_download_updates`: independent download/preparation with progress callbacks.
- `vpkc_wait_exit_then_apply_updates`: starts the updater, waits for the application
  to exit, and has explicit silent/restart flags. The documented wait is 60 seconds;
  Sesori must finish helper teardown before handing off, not spend this window
  waiting for backend work.
- `vpkc_app_set_auto_apply_on_startup` is exposed; startup auto-apply must be disabled
  if selecting this engine, to preserve the approved normal-Quit installation policy.
- Custom update-source callbacks and SHA256 asset metadata are exposed. Their use
  for an authenticated feed/payload trust chain still needs qualification.

Source:
`https://github.com/velopack/velopack/blob/1.2.0/src/lib-cpp/include/Velopack.h`

Velopack would also replace the installer and need native adapter, update-trust and
scheduling qualification. Authenticode signing and an unsigned feed's checksum do
not establish independent update authentication. Rather than add custom trust or
lifecycle machinery, use the approved manual Windows path. No further Velopack
integration is planned, and no claim that Velopack is generally unsafe is made.

References:

- `https://docs.velopack.io/getting-started/cpp`
- `https://docs.velopack.io/packaging/signing`
- `https://docs.velopack.io/reference/cs/Velopack/UpdateManager`

## Repeatable native qualification tooling

`.github/workflows/desktop-qualification.yml` is a read-only, unsigned PR/manual
workflow. It never starts the GUI, accesses signing credentials, publishes a product,
or changes mobile/CLI release gates. Six native runner rows are explicit:

| Target | Runner label | Build tooling / evidence |
|---|---|---|
| macOS x64 | `macos-15-intel` | Xcode 26.3 selected explicitly; Flutter + Sparkle API compile probe. |
| macOS arm64 | `macos-15` | Same Xcode pin, native arm64 host. |
| Windows x64 | `windows-2025` | Image Visual Studio/SDK recorded by Flutter doctor; this is not Windows 11 interactive QA. |
| Windows arm64 | `windows-11-arm` | Native host and Dart required; x64 fallback fails. |
| Linux x64 | `ubuntu-24.04` | Native clang/CMake/GTK, libsecret and Ayatana headers. |
| Linux arm64 | `ubuntu-24.04-arm` | Same dependencies on native ARM64, not an x64 emulator. |

Runner source: `https://docs.github.com/en/actions/reference/runners/github-hosted-runners`.
GitHub image labels are mutable; the report records `ImageOS`, `ImageVersion`, actual
OS/CPU, SDK/compiler and Flutter revisions so a run can be attributed exactly. The
runner choice itself is not passing execution evidence.

`.github/scripts/qualify_desktop.py` bootstraps official Flutter source at the
repository pin's tag and checks it against the official release-manifest revision.
It verifies native Dart headers instead of substituting a standalone SDK or accepting
a silent x64 fallback. Local inspection uses the already-installed pinned SDK;
bootstrap refuses non-CI use. This is qualification tooling, not a new runtime manager.

After normal GUI/helper builds, `inspect` inventories Mach-O/PE/ELF binaries, CPU
slices and independent SHA256 hashes. A mismatched library fails the target. It
relocates the **complete** helper bundle into the proposed layout (including a path
with spaces), runs its side-effect-free `--version`, and provides the relocated path
to the existing isolated supervised E2E fixture. That fixture exercises native SQLite,
fake auth/relay/control handshake, restart and unregister/exit without touching real
credentials, sessions, harnesses or a running user's bridge. Linux also records `ldd`
closure and fails on unresolved shared libraries. Logs/inventory and partial failures
are CI artifacts, not product downloads or committed machine/account data.

macOS GUI output is currently universal while the helper is host-native. Inventory
records both slices honestly; step 3's staging must produce architecture-specific
application payloads with matching helper identity rather than claim a universal
helper. No native-asset metadata is hand-edited.

### Local macOS arm64 evidence — 2026-09-15

Source: `ef6f3d6548` production code; only qualification tools/plans were dirty.
Host: macOS `26.6.2` (`25G83`), arm64. Xcode `26.6` (`17F113`), SDK `26.5`.

- Locked bridge/client dependency resolution: passed; no lockfile changes.
- `flutter build macos --release`: passed, `Sesori.app` about 67 MB.
- `dart build cli -o build/cli`: passed, complete native helper bundle.
- `python3 .github/scripts/qualify_desktop.py inspect --arch arm64`: passed.
  Four universal GUI Mach-O binaries (app, App/FlutterMacOS/objective_c frameworks),
  three ARM64 helper binaries (`bridge`, `libsqlite3.dylib`, `macos_power_observer.dylib`).
- Relocated `bridge --version`: `1.8.4`, from the app's proposed Helpers layout.
- Existing `supervised_e2e_test.dart` with `SESORI_DESKTOP_BRIDGE_PATH` pointing to
  that relocated helper and `SESORI_E2E_REQUIRED=1`: **1 test passed**. Uses isolated
  local fakes; not real login/relay/harness or GUI proof.
- Python header/bootstrap/diagnostic tooling tests: **8 passed**.
- GUI Mach-O load commands report macOS minimum `12.0`. This matches the Xcode
  project and Sparkle minimum; a run on macOS 12 is still needed before claiming it
  as a tested minimum.

One actionable clean-checkout failure was corrected in the tooling: `dart pub get`
followed by `flutter build --no-pub` leaves the generated SwiftPM package absent.
Allow the normal Flutter build pub phase to generate it. No source/plugin workaround
or manual edit to generated files was needed.

Private/local raw evidence lives under gitignored `build/desktop-qualification/`.
No GUI was launched, no real account was used, and no distribution signing or
notarization was attempted. The other five native GUI builds remain unverified.

### First native CI attempt

[Run 34960934498](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/34960934498)
confirmed official source bootstrap with native Dart on Windows x64 and Linux
x64/ARM64. Their first attempt then failed at client dependency resolution, before
GUI compilation: plain `dart pub get` did not populate the source SDK's `sky_engine`
cache. The workflow now uses `flutter pub get --enforce-lockfile` for the client
workspace while retaining Dart-only bridge resolution. Do not label this setup
failure an unsupported CPU target or bypass locked dependencies to fix it.

## macOS updater API and selected topology

Audited stable Sparkle **2.10.0**, released 2026-09-13. Downloaded its official
`Sparkle-2.10.0.tar.xz` and checked the release asset SHA256:
`c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c`.
The framework, Autoupdate, Updater app and both XPC services have **x64 + arm64**
slices. Framework load commands report minimum macOS `12.0`.

`.github/scripts/probe_sparkle.swift` typechecks against that release, locally passed,
and runs on both macOS CI hosts. It exercises the public
`willInstallUpdateOnQuit:immediateInstallationBlock:` delegate and standard controller
construction without starting any updater. Returning true retains native install-on-
quit handling and stalls future cycles; the stored native callback requests explicit
restart. This is an API/compiler proof, **not** a signed N→N+1 runtime proof.

Selected graph (implementation belongs to step 5): `MacOsSparkleUpdater` shell
adapter → `SparkleUpdateBridge.swift` → Sparkle 2.10.0, linked using its checksum-pinned
SwiftPM binary target. No additional third-party Flutter updater wrapper.
`DesktopUpdatePlatformModule` registers a sealed `DesktopUpdatePlatform` in phase 1:
macOS carries the required updater, Windows its manual download URI, Linux a
package-manager-owned variant. API/repository/service stay in desktop core phase 4;
`BridgeControlCubit` remains the only serialized Quit owner. Exact file paths and
startup/disposal responsibilities are in `PLAN.md`.

**Unresolved lifecycle gate:** existing `IoDesktopApplicationTerminator` uses
`dart:io.exit`, not AppKit termination. Do not assume it triggers Sparkle notification
hooks. Prove normal quit/no-relaunch and explicit restart only after helper teardown,
including a native updater-initiated termination request. `shouldPostponeRelaunch`
is not an all-exit hook. If supported integration requires substantial coordination,
use the user's accepted manual macOS path instead of inventing another shutdown owner.
This proof is required before committing to the app-managed implementation in step 5.

Sources: Sparkle tag `2.10.0`, `SPUUpdaterDelegate.h`, `SPUAutomaticUpdateDriver.m`,
`SPUInstallerDriver.m`, and `Package.swift`.

## Signing and hosting: metadata inspection only

Read GitHub secret/variable **names only**, never values. The repository exposes
existing macOS certificate/keychain secret names and Apple account/team credential
names. These are candidates for reuse, not proof of successful Developer ID signing
or notary access. No Windows signing, Sparkle update-key, or GCS publication identity
was established by this inspection. The existing Google Play credential is not a
GCS publishing credential and must not be repurposed implicitly.

Native Windows/Linux execution, final macOS entitlements, updater signature tests,
GCS permissions and clean-host package/runtime dependency qualification remain
outstanding. Ubuntu 24.04 and Debian 13 remain nominated DEB baselines; the supported
Fedora release and CPU/desktop-environment mapping remain a Linux release entry gate.
A successful build on one runner does not freeze those runtime baselines. The six
native application targets remain required, with only the approved installer-launcher
exception. Step 2 stays in progress while the native build matrix is pending.
