# Step 4 — Native macOS Packaging and Notarization

Status: **in progress — native signed packages verified; installed GUI checks remain**.
PR ordinal **5/13**.
Branch: `desktop-distribution-macos-packaging`, in the existing `tan-antelope`
worktree. Predecessor [3.b](step-03b.md) merged as
`e853838ac29b5d829f13622702c5d47a74eaa829`.

## Authentication decision

The user selected existing GitHub Apple ID/app-specific-password/team credentials
for trusted CI notarization on 2026-09-15. No secret values are inspected or printed;
no product publication or new infrastructure is authorized by this choice.

The current CLI workflow names `Developer ID Application: DigitalBlock Labs LTD`
with the configured `APPLE_TEAM_ID`. Local metadata shows one matching valid
identity, but this is not signed-desktop or notarization evidence. A manual-only
mode of the existing qualification workflow will verify certificate import, a
hardened/timestamped native probe signature, and `notarytool history` authentication
on both qualified native macOS runners. Default PR/six-target qualification stays
credential-free. The probe, decoded certificate, temporary keychain and history
response are job-private and removed; only operation results enter CI logs.

## Credential preflight evidence

Manual [run 34997710034](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/34997710034)
used workflow revision `896378178722b766d74e0167b82e37cd69909d26` (not a PR merge
checkout). Both native runners imported the configured secret material but failed
at `codesign`: the expected Developer ID Application identity was not found.
Notarization authentication had not run. The normal tooling/native qualification
jobs were skipped, as required by this opt-in mode.

The same exact public publisher identity is valid in the local keychain; no local
key was exported or used. A bounded diagnostic follow-up lists imported public
identity names/validity and checks notarization authentication before attempting
the unchanged publisher-specific signature. No alternative publisher or weakened
signature gate is accepted. Logs remain under ignored
`build/desktop-macos-packaging-evidence/`. Initial and diagnostic workflow actionlint
checks passed; actual signed-desktop behavior is still unverified.

Diagnostic [run 34998095733](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/34998095733)
at `93fac44` found the exact expected valid Developer ID identity on both runners,
and both authenticated successfully to notarization. The signature lookup still
failed with the isolated keychain, despite `codesign --keychain`. The next attempt
registers that temporary keychain in the user search list, matching the existing
CLI signing workflow; no certificate/publisher replacement was attempted.

[Run 34998357930](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/34998357930)
at workflow revision `d76fcef410055d38f0b24e4e5405d4d7195824a9` passed on both native
Mac runners after that search-list registration. Jobs `104480252199` (x64) and
`104480252317` (arm64) authenticated to notarization, signed a native probe with
Developer ID/timestamp/hardened runtime, verified it and executed it. This proves
credential/tool access, not application notarization, entitlements or GUI behavior.
No product was submitted or published. Captured metadata/logs are under
`build/desktop-macos-packaging-evidence/`; they were fetched from repository root
using `gh api --allow-escape-sequences repos/sesori-ai/sesori_apps_monorepo/actions/jobs/<job-id>/logs`.

## Implementation outline

1. Pass the explicit trusted-CI credential preflight before packaging work relies
   on those credentials. Use the existing `MACOS_CERT_*`, Apple credentials and
   team configuration, not a new signing account or exported local key.
2. Reuse the committed-source identity-bound staging producer and qualified
   macOS 26/Xcode 26.6 x64/arm64 runners. Use Apple `codesign`, `ditto`, `hdiutil`
   and `notarytool`; do not introduce a custom updater or release backend.
3. Sign nested native code/frameworks inside-out, then the app, with hardened
   runtime. Keep App Sandbox disabled. Audit and retain only demonstrated release
   entitlements; no speculative JIT/library-validation exceptions or provisioning-
   only Keychain groups. Desktop DI retains `FlutterSecureStorage` with
   `MacOsOptions(accountName: "com.sesori.desktop", usesDataProtectionKeychain: false)`.
   The resolved Darwin plugin is 0.4.2, which supports this classic mode.
4. Produce notarized/stapled DMGs and app ZIPs for each native architecture,
   preserving framework symlinks and the complete helper bin/lib layout. Verify
   extracted payloads and collect final identities/digests after signing/stapling.
   Outputs remain private CI artifacts; publication belongs to step 6.
5. Prove signatures/notarization, relocated-helper behavior, and the actual signed
   GUI's Keychain/auth/control/runtime/filesystem behavior. Do not launch over an
   existing desktop/bridge or access real account state without the required QA
   approval. CI build/probe success is not interactive or minimum-OS execution.

Packaging tooling will stay in `.github/scripts/package_desktop_macos.py` with
focused `test_package_desktop_macos.py` fixtures, reusing `qualify_desktop.inventory`
rather than creating another native-header scanner. A CI-only shell seam will own
secret import, temporary Keychain/notary-profile setup and cleanup; the packager
receives only public identity/profile/path arguments. Apple `notarytool` profiles
keep passwords out of Python command/error reporting. The existing workflow will
use one closed dispatch-mode choice for native qualification, credential preflight
or private macOS packaging, so mutually exclusive operations cannot both be selected.
Default PR qualification remains credential-free. No application/Keychain owner or
restricted entitlement was changed by the initial tooling. The concrete native
failure below now requires a scoped producer/consumer placement change and an
architecture-plan review before touching those Dart paths.
Estimated budget: under 1,000 authored changed lines; zero new application mutable
fields, subscriptions, timers, lifecycle owners, persistence or transport contracts.
Credential cleanup is scoped to this job's own secret files; failed unsigned build
outputs remain diagnosable. No unrelated CLI/mobile release changes are intended.

The first packaging implementation signs native leaves, framework containers and
then the application, without deep signing. It verifies each native file explicitly
because the helper bin/lib directory is not a nested application bundle. After app
acceptance/stapling it produces the final ZIP, creates an Applications-link DMG,
signs/notarizes/staples the DMG and verifies both extracted payloads. Receipts,
optional detailed notary logs, final inventory/digests and the unchanged identity
manifest are retained. Only fully verified packages pass the private-upload step;
installed GUI/account/minimum-OS/publication claims are explicitly excluded.

Local checks on the uncommitted implementation based on `d76fcef410055d38f0b24e4e5405d4d7195824a9`
passed: **8 Python packaging tests**, actionlint, Bash syntax, ShellCheck and
whitespace. Later edits only wrapped long lines and added documentation. Commands,
from repository root:

```bash
python3 -m unittest discover -s .github/scripts -p test_package_desktop_macos.py -v
actionlint .github/workflows/desktop-qualification.yml
bash -n .github/scripts/macos_signing_ci.sh
shellcheck .github/scripts/macos_signing_ci.sh
git diff --check
```

No Dart/Flutter production input changed, so unchanged owning suites were not rerun.
The current secure-storage owner/options were checked in `register_module.dart`;
older advice to recreate a native Keychain workaround is not the current design.
The first native run below verified profile authentication but failed application
signing before a product could be submitted for notarization.

## Native finding and proposed manifest-placement correction

[Run 35002549379](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35002549379)
used `f5348c07199f24030942036007b854f903c5f930`. Tooling passed; both native builds
completed and both temporary notary profiles authenticated. Jobs `104494308731`
(x64) and `104494308790` (arm64) signed nested native code, then refused the enclosing
app with `code object is not signed at all`, naming
`Contents/Helpers/bridge/desktop-bundle.json` as the subcomponent. No product was
submitted/notarized or uploaded as a successful package. Local CI logs:
`build/desktop-macos-packaging-evidence/first-packaging-{x64,arm64}.log`.

A bounded local structural diagnostic copied the earlier real ARM64 `350cb8e`
staged app and used **ad-hoc signing only**, without GUI execution or private-key
use. It reproduced the Helpers JSON refusal, moved only that JSON to
`Contents/Resources/desktop-bundle.json`, then signed and deep/strict verified the
app. Appending a newline to the relocated manifest made verification fail. This
proves the placement/resource-seal behavior, not Developer ID, notarization or
current-head GUI behavior. Script and retained tampered copy/results:
`build/desktop-macos-packaging-evidence/probe_manifest_layout.py` and
`build/desktop-macos-packaging-evidence/manifest layout probe/results.json`.

Scoped architecture-plan review **approved**, pre-review gate passed, run
`1d781b5d-4861-4487-9094-1a00731db885` (`medium-intelligence-fast`). Applied B-Client;
B-Bridge/B-Shared were outside the proposed change. No findings. Review output:
`reviews/desktop-distribution-step-04-manifest-plan.md` in that run's artifacts.
This approves the placement correction, not unrelated tooling or unexecuted QA.

Implemented correction after that approval:

- `client/desktop/tool/stage_desktop_bundle.dart`: `stageDesktopBundle` still copies
  the entire native helper to `Contents/Helpers/bridge`; on macOS only it writes the
  unchanged `DesktopBundleIdentity` JSON under `Contents/Resources`. Create that
  destination directory as part of staging. Windows/Linux keep helper-root JSON.
- `client/desktop/lib/core/platform/desktop_bridge_executable_path_resolver.dart`:
  `_resolvePackaged` derives macOS's manifest path from the running executable's
  `Contents/Resources` directory. Helper resolution remains
  `Contents/Helpers/bridge/bin/bridge`; Windows/Linux and debug/profile behavior
  remain unchanged. Continue every-spawn validation and typed repair/error behavior.
- Existing resolver coverage retains all six OS/CPU combinations; staging tests
  cover each OS's placement (there is no CPU-specific placement branch). They assert
  the macOS resource path and absence of JSON in the code-only Helpers subtree.
  The packager copies the evidence manifest from Resources; its native-signing-order
  fixture includes that resource and excludes it from executable signing targets.
- Update current bundle/packaging/regression guidance. Historical step-3.a artifact
  evidence remains attributed to its original layout; do not rewrite past results.
- No new production class, layout registry, mutable field, timer, DI registration,
  database, wire schema or generated code. Reuse the existing manifest filename and
  immutable model. This unpublished desktop layout needs no old-path fallback or
  migration. Estimated correction: approximately 100 authored lines in the same PR.

Local correction verification passed: **24 focused Flutter resolver/staging tests**,
**8 Python packaging tests**, and desktop analysis. The first analyzer found one
`avoid_slow_async_io` info on the new test assertion; changing it to `existsSync`
resolved it, and the final 24-test command/analyzer both passed. Python inputs were
unchanged after their passing run. These checks measured the uncommitted correction
based on `f5348c07199f24030942036007b854f903c5f930`, subsequently committed for
implementation review. Commands (Flutter commands from `client/desktop`, Python
from repository root):

```bash
flutter test test/core/platform/desktop_packaged_bridge_path_test.dart test/tool/stage_desktop_bundle_test.dart --reporter expanded
flutter analyze --no-pub --fatal-infos
python3 -m unittest discover -s .github/scripts -p test_package_desktop_macos.py -v
```

Logs: `layout-flutter-tests-final.log`, `layout-desktop-analyze-final.log` and
`layout-python-tests.log` under `build/desktop-macos-packaging-evidence/`.

The correction is commit `b41a1f6500a200acaa2f6bdc6db090bfc359c139`, with 146 authored
changed lines across 11 paths against `f5348c0`; the whole branch diff at `b41a1f6`
against `e853838` was 905 authored changed lines across 15 paths, zero generated.
Scoped architecture implementation review **approved/no findings**, run
`798cfb06-1fb5-42d4-ae69-0ed731e246c9` (`medium-intelligence-fast`), covering all 11
changed files and applying B-Client. B-Bridge/B-Shared were outside the change.
Review output: `reviews/desktop-distribution-step-04-manifest-implementation.md`.
The review confirmed existing shell responsibilities, immutable identity and
DI/lifecycle ownership; no new classes, dependencies, registries or compatibility
paths. It does not certify unrelated tooling or unexecuted native behavior.

[Native packaging run 35006541037](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35006541037)
**passed** at that immutable correction head. Both source trees had empty recorded
build patches. Each produced desktop/helper **1.8.4, build 14**, accepted app and DMG
notarization with no reported issues, valid staples/signatures, three Gatekeeper
acceptances as Notarized Developer ID (DMG, ZIP app, mounted app), seven native
binaries with identical ZIP/DMG inventories, helper version execution and passing
isolated supervised E2E. Default six-target qualification was skipped in this manual
mode; this is not a new six-platform run.

| Target | Native job | Private packages artifact | Evidence artifact |
|---|---|---|---|
| macOS x64 | `104507677779` | `10412257146` | `10412297019` |
| macOS arm64 | `104507677778` | `10411784657` | `10411784662` |

All four downloaded final payloads matched the recorded SHA256s:

| Payload | SHA256 |
|---|---|
| `Sesori-macos-x64.zip` | `8987490f6fa9197eac707d55f3ae282b945b884d424f351afce3aa4c6b84cacf` |
| `Sesori-macos-x64.dmg` | `79ae859d6720d5bd75d4f93da9d177a9254415be76e4ffd0cf91a08937343fc7` |
| `Sesori-macos-arm64.zip` | `081031a479a2b340dc67aac80e0448b77066016cb2d0805bb23b3d2f47c20de1` |
| `Sesori-macos-arm64.dmg` | `516fd1e1041d3e1bf0849b4312c34f5a9df9e7a497a52bec10b4935d60df9032` |

Captured files are under `build/desktop-macos-packaging-evidence/native-b41a1f6/`.
To retrieve while the private Actions artifacts remain available (14-day retention),
run from repository root with GitHub access and choose a fresh destination:

```bash
gh run download 35006541037 --repo sesori-ai/sesori_apps_monorepo \
  --pattern 'desktop-macos-*' --dir build/desktop-macos-packaging-evidence/retrieved-b41a1f6
```

Compare the inner ZIP/DMG hashes to `packaging.json`, inspect `desktop-bundle.json`
for source `b41a1f6500a200acaa2f6bdc6db090bfc359c139`, check both notarization statuses
and detail reports, the empty build patch and `All tests passed!` in the E2E log.
Downloads were not locally mounted, installed or launched. The broader installed
GUI, Keychain/TCC/autostart and ship gates remain open, not replaced by these probes.
No public release, tag, feed or infrastructure was created.

Local GUI safety preflight also found an existing debug desktop from `rose-elephant`
(PID 74143) and an existing `/Applications/Sesori.app`. Neither was changed. The user
subsequently selected fresh native CI on both CPUs and directed uninterrupted,
unattended plan execution: never stop the running bridge; run safe autonomous tests
and leave human-dependent checks for the final handoff. Do not launch local QA over
that state or wait for additional user answers.

## Autonomous packaged-platform probes

Add a bounded CI-only probe after private packaging, using first-party Flutter,
Xcode, `codesign`, CoreGraphics and process tools, with no new production hook.
A separate release-mode test entrypoint reuses the actual desktop secure-storage
DI configuration and `IoLaunchAtLogin`: synthetic Keychain write/update, persistence
across two probe launches, delete, per-user login-registration write/read/remove,
and owned temporary-file access. It never initializes the bridge/session services.
Sign that fixture with the same Developer ID/hardened-runtime/entitlement policy;
do not upload it as a product. Build it separately from the staged real application.

On each fresh native runner, install the real verified app into Applications, check
Gatekeeper again, launch it as an owned CI process, inspect its native window and
attempt a screenshot. Test teardown concerns only those owned CI processes and
copies, never a local bridge or application. Missing screenshot permissions or an
unavailable GUI host are explicit blocked evidence, not a fabricated visual pass.
Provider credentials, MFA, interactive TCC decisions, real login/logout and minimum-
OS hosts are not supplied by these probes and remain in the final verification list.

Expected addition: approximately 250–350 authored test/tooling lines. No application
classes, DI ownership, lifecycle behavior, transport/storage contract or analytics
changes; architecture review is not required for this test-only extension.

Implementation is ready for native execution. Three Python safety tests pass,
along with desktop analysis, native Swift typecheck, actionlint and ShellCheck.
The first analyzer reported package-import/enum-constructor style infos; the final
analyzer passed after those fixture-only fixes. Logs are `probe-*.log` under
`build/desktop-macos-packaging-evidence/`. No local application was launched.
The fixture is Developer-ID-signed but not notarized; its native Keychain evidence
must remain separate from authentication/restoration through the actual product.

Run [35014995494](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35014995494)
at `8fb5d33e4c6ecc0161d31838f0bb0875794c85f6` passed the automated commands on both
native Macs, producing 1.8.4/build 15 with empty source patches. Notarization,
staples, seven-binary inventories, downloaded payload hashes and helper E2E still
passed. Both signed fixtures passed synthetic Keychain write/read/update, a second-
process persistence check, delete, login registration and owned-file access.
Both hosts reported one screen and a live 720×620 app window.

**Visual review did not pass:** both captured app windows contained black content.
Do not equate the successful process/window assertions with a rendered login screen.
The local-notifications dependency requests Darwin permissions by default, and the
current app awaits notification initialization before `runApp`; a pending system
prompt is one hypothesis, not yet a confirmed cause. Add full-desktop/native-stack
capture and LaunchServices launching. The `macos-gui-probe` mode reuses a selected
trusted package run without rebuilding, re-signing or rerunning unchanged helper/
Keychain checks. It checks the expected publisher and Gatekeeper before launch and
records the sealed source identity. No signing secrets are supplied to this mode.

GUI replay [35019031550](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35019031550)
used tooling `055eb71e77ca716ef7c432766b135048f3b3c768` and the unchanged signed
`8fb5d33` payloads. Both hosts had a screen and Accessibility access; LaunchServices
launching, publisher verification, window/full-desktop capture and native process
sampling passed. Both full-desktop images still showed black app content and no
visible permission prompt, so rendered startup remains unresolved. Evidence artifacts:
x64 `10416693647`, arm64 `10416369598`; local copies are under
`build/desktop-macos-packaging-evidence/gui-055eb71/`.

Added seven fixed-text startup breadcrumbs around existing awaits to locate the
stall without changing initialization order, ownership, permissions or data. A
normal merge of incoming main (`b69a485`, merge `6a68876722b9c2d15a924091d853144be6ee19fa`)
preserves the independent desktop-UX work. The cold-start widget smoke (one case)
and desktop analyzer pass on that merged tree plus the breadcrumbs. These mocks
do not replace the pending native startup diagnosis.

## Verification and boundaries

Preflight tooling: actionlint and workflow-route/credential-scope inspection; actual
manual CI on both native Mac runners. Packaging: focused command/ordering/path
fixtures, signed extracted binary inventory, helper version and isolated supervised
E2E, then the signed-app checks required by PLAN.md and the macOS QA skill.

The existing classic-Keychain implementation must not be replaced or given restricted
entitlements merely to make a probe pass. Developer ID's stable designated requirement
is the intended update identity; any required security change gets a concrete review.
Parent closeout, actual signed GUI behavior, minimum-OS execution, macOS ship coverage
and the final six-target retirement matrix remain separate unwaived gates.
