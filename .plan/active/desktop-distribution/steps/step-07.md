# Step 7 — Private Windows installer qualification

Ordinal 9/14. Step 6 preparation merged in #1511, but macOS/public publication
remains blocked. This step can develop unsigned private Windows installers without
shipping either platform. No Windows signing access has been established.

## Concrete implementation plan

1. `client/desktop/windows/runner/main.cpp`: before Flutter startup create the named
   mutex `Local\com.sesori.desktop.running` with `CreateMutexW(NULL, FALSE, ...)`.
   The GUI process owns the handle until process termination; do not close it when
   the window hides or the message loop ends. Windows releases it at process exit,
   including the existing Dart exit path. This follows Inno's documented AppMutex
   guidance. A failed creation reports the Windows error and refuses startup, rather
   than allowing an unprotected running GUI. Existing duplicate-instance behavior
   is unchanged: this is an existence marker, not a single-instance lock.
2. `client/desktop/tool/windows_installer.iss`: Inno Setup 7.1.0, per-user installation
   under `{localappdata}\Programs\Sesori`, application ID `com.sesori.desktop`.
   Build macros supply absolute staged bundle, output directory, version and CPU.
   Install `build/desktop-bundle/bundle` unchanged, including `sesori_desktop.exe`,
   Flutter assets/DLLs, and `bridge/bin/bridge.exe`, `bridge/lib` and
   `bridge/desktop-bundle.json`. Architecture-specific installer gates must refuse
   wrong-native-CPU payloads; compiler/launcher emulation on ARM64 is permitted.
   Use `PrivilegesRequired=lowest`, matching `AppMutex`, `CloseApplications=no`,
   `RestartApplications=no`; no `[Run]`, forced close, PATH or service changes.
   Start-menu shortcut and optional desktop shortcut target the installed GUI.
   Let Inno uninstall only its recorded files; no wildcard UninstallDelete.
3. Uninstall removes only the existing `Sesori` value under
   `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. The installer does not
   enable login launch; the existing `IoLaunchAtLogin` adapter still owns opt-in.
   No shared credentials, runtimes, databases, history or projects are removed.
4. `.github/scripts/package_desktop_windows.py`: verify staged manifest and native
   PE inventory using existing qualification helpers, invoke pinned Inno, record
   unsigned installer hashes and explicit proof limits. No signing placeholder or
   public URLs. `.github/scripts/test_package_desktop_windows.py` covers arguments,
   package identity/architecture refusal and installer directive contracts.
5. `.github/workflows/desktop-qualification.yml`: a manual private Windows mode
   stages both native x64/arm64 bundles on existing native runner labels, downloads
   the pinned official Inno compiler with verified checksum, and compiles installers.
   An isolated Windows runner probe installs/uninstalls in a temporary per-user
   path, verifies native payload inventories and untouched shared-data sentinels,
   checks mutex refusal, and uploads only private artifacts/evidence. Never run
   this against the user's live local machine. Real GUI/account/SmartScreen and
   signing are separate gates, not inferred from silent fixture execution.

## Ownership and complexity

Only architecture-bearing change: Windows runner owns one process-lifetime kernel
handle that Inno observes. No new Dart state, services, DI, queues, shutdown owner,
helper control, persistence or wire contract. Installer refuses replacement while
GUI lives so existing safe Quit remains the sole helper-stop authority. Ordinary
manual upgrade while a tray-backed GUI is running is the concrete damaging flow
(data/process disruption) this refusal prevents.

Expected 350–650 authored lines, no generated changes; reassess before push.
Keep compiler acquisition/version qualification in tooling, not app code. Inno's
pinned source license permits commercial use; the vendor encourages paid support.
No purchases, accounts, keys, new hosting or publication are authorized by this work.

## Verification and pending gates

Before implementation, scoped architecture-plan-review covers native mutex ownership
and installer observation only. After code, targeted Python tests, actionlint, native
Windows compilation and isolated installer checks on both CPUs, then architecture
implementation review. No local Flutter/bridge process may be launched or stopped.
Update `docs/regression/desktop-distribution.md` with actual supported behavior.

Signing, timestamp/publisher verification, SmartScreen observation, actual-account
restoration, interactive ARM64 QA and the prior macOS ship gate remain blocked.
Do not label private unsigned EXEs as signed installers or publish download links.

## Local implementation checkpoint

Implemented on `desktop-distribution-windows-packaging`: native process-lifetime
marker, bounded Inno script, manifest/native-inventory packager, offline tests and
manual private x64/ARM64 workflow. Inno's official `is-7_1_0` x64 asset digest is
`0362a383ed217d4c4239b5933866dd96d3eb2102737da92f80f6057a4b40df2f` and is checked
before CI executes it. Local offline desktop tooling tests and actionlint pass.
Native compiler, install/upgrade/uninstall, mutex refusal and payload checks remain
pending until the workflow is manually dispatched on isolated Windows runners.
Signing, publication and interactive product claims remain blocked.

Sources: `stage_desktop_bundle.dart` stages Windows `runner/Release` into `bundle`;
Windows CMake sets `BINARY_NAME=sesori_desktop`; `IoLaunchAtLogin` owns the `Sesori`
Run value. Inno 7.1.0 official download and source license checked; AppMutex docs
explicitly recommend retaining the handle until process termination:
https://jrsoftware.org/ishelp/topic_setup_appmutex.htm.
