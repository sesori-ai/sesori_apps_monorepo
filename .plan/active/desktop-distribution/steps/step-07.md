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
At this local checkpoint, native execution was pending. The isolated Windows
qualification below subsequently supplied compiler/fixture evidence.
Signing, publication and interactive product claims remain blocked.

Sources: `stage_desktop_bundle.dart` stages Windows `runner/Release` into `bundle`;
Windows CMake sets `BINARY_NAME=sesori_desktop`; `IoLaunchAtLogin` owns the `Sesori`
Run value. Inno 7.1.0 official download and source license checked; AppMutex docs
explicitly recommend retaining the handle until process termination:
https://jrsoftware.org/ishelp/topic_setup_appmutex.htm.


## Parent review and focused follow-up

Architecture implementation review `8a9a17e2-b885-4100-8963-dee9738799b8` approved
`266340fab88e3a4deac890eb161e61581087275a` against `e91e1fc`, B-Client only.
The prior attempt `af5399f3-0c89-4dbf-8fb6-4c15d683b962` failed with `fetch failed`;
it produced no review decision and was retried through the same runner.

Parent correctness review changed the x64 payload gate to `x64os` (not
`x64compatible`, which permits ARM64 emulation), explicitly selected an x64 Inno
launcher, and made PowerShell fail on installed-inventory Python errors.
At exact `a5f5f46e9929ec81c1e1b777a2795e45467864a4`, tree
`aa056fbe0d422175b857733ddb5bc642060a7111`, from the repository worktree root:

- `python3 -m unittest discover -s .github/scripts -p 'test_package_desktop_windows.py'`:
  eight cases passed, exit 0 (synthetic packages and mocked compiler, not Windows execution).
- `actionlint .github/workflows/desktop-qualification.yml`: exit 0.

Logs: `build/desktop-windows-packaging-evidence/parent-tests.log` and
`parent-actionlint.log`. These local checks alone do not establish installer
compilation or Windows execution.

## Native private qualification

Run **35097548359** succeeded on exact source
`a36896d051b35786b100318c390af98442f0a19b`, tree
`c82a1f85f6c8b8594282cecfe153e4f3d5200118`, version **1.8.4/build 35**.

- ARM64 job `104799113168`: package artifact `10446962454`, evidence `10446793103`.
  Installer SHA-256: `a02169a37e5cce82dd2335ffbced0c1266fb1e7a745132b81892a6808e5c3bdc`.
- x64 job `104799113485`: package artifact `10446709408`, evidence `10447321500`.
  Installer SHA-256: `8c23a0084acb50a956cb4bb54bf691cd8dae533122d690f785d32980e8464280`.

Downloaded both package/evidence pairs with `gh run download 35097548359 --repo
sesori-ai/sesori_apps_monorepo --pattern 'desktop-windows-*' --dir
build/desktop-windows-packaging-evidence/native-a36896d`. Local SHA-256 checks match
packaging reports; installed identity and full 15-binary inventory equal the staged
report on both CPUs. Both source-change patches are empty. Both silent fixtures
report install success, same-version reinstall success, setup/uninstall mutex
refusal (exit 1), login-intent preservation, owned login-value cleanup and shared
sentinel preservation. No product GUI/helper was launched by the installer probe.

The initial private run 35092987496 stalled in compiler acquisition on both CPUs
and was cancelled. Switching Inno acquisition from Git Bash to PowerShell removed
MSYS switch rewriting as a possible cause and added a timeout/log. The successful
retry verifies the revised path; no stronger root-cause diagnosis is claimed.
An unrelated PR macOS x64 job was cancelled during staging without an available
log; a retry was requested. Current PR checks subsequently passed.

These unsigned, silent runner fixtures are **not** a signed N→N+1 upgrade, real
account/GUI lifecycle, interactive ARM64, SmartScreen or public-release proof.
GitHub artifacts require authorization and have 14-day retention. Later docs-only
commits do not change the measured native source above.

## Review follow-up qualification

Run **35101629087** passed both native rows on exact
`e9c8a1aa8ccb88c73cb7ceae0a064da91f3440d1`, tree
`c76f66d5c562e964d9707f61fe4ae2f5aab2b807`, **1.8.4/build 39**.
It additionally verifies that every staged payload file is removed by uninstall
while an unrecorded file inside the installation and the external shared sentinel
survive. The fixture explicitly limits mutex evidence to nonzero exit with the
marker held and success without it; the generic exit does not prove its diagnostic.

- ARM64 job `104812289929`; installer SHA-256
  `c705e3938aea14fee8cbd50c09ca45e249ab2e31f0f770829c077f377c956e6f`.
- x64 job `104812289889`; installer SHA-256
  `5c353ec2bdc5823804f4557f3aea3dee15b873b7ecaa174e884e37492ca40d05`.

Downloaded with the same `gh run download` command above, substituting run
`35101629087` and destination `build/desktop-windows-packaging-evidence/native-e9c8a1a`.
Both downloaded hashes match; each installed identity and 15-binary inventory equals
its staged report; both source patches are empty. Fixture assertions passed on both
CPUs. These still do not establish signed N→N+1 or interactive product behavior.

At exact `e9c8a1a`, from the repository root, the focused Python command above
passed 9 cases and actionlint passed the changed workflow (exit 0).
Logs: `build/desktop-windows-packaging-evidence/review-tests.log` and
`review-actionlint.log`. These changed-input runs cover the added file-type checks;
unchanged application tests were not rerun locally.
