# Native macOS Packaging

## Capability

Private Developer ID signed/notarized macOS x64 and arm64 desktop packages,
containing the identity-bound GUI and its complete native bridge helper. This
packaging capability does not imply public downloads or an updater have shipped.

## Required Behavior

- Build from committed source with the pinned native SDK. Reject a nonempty
  build-recorded source patch before supplying signing credentials. Preserve framework
  symlinks, native CPU support and the complete `Contents/Helpers/bridge/bin`–`lib`
  relationship. The packaged identity continues to control helper admission from
  `Contents/Resources/desktop-bundle.json`; keep JSON out of the code-only Helpers
  subtree. Changing that resource after signing must invalidate the app's seal.
- Sign nested native code/frameworks inside-out, including every helper dylib;
  enable hardened runtime for the GUI/helper without adding speculative security
  exceptions. Keep the established non-sandboxed classic-Keychain configuration.
- Notarize/staple the app before creating the final ZIP. Sign/notarize/staple the
  DMG too. Both extracted payloads must retain valid signatures and tickets, pass
  Gatekeeper assessment and execute the native helper. Their extracted native
  inventories and helper versions must match before reporting verified packages.
  Offer Applications as the installation destination, not a mounted-DMG launch.
- Use signing credentials only in explicitly selected trusted manual CI, never PR
  qualification. Keep private material out of command reporting/artifacts; clean
  only job-owned credential files. Failed output remains available for diagnosis,
  but incomplete packages are not uploaded as successful package artifacts.
- Missing native screens must fail the platform-probe step with explicit blocked
  evidence, not silently skip qualification and continue verified-package upload.
- Private upgrade qualification must consume two retained successful native packaging
  runs and require a strictly increasing sealed semantic-version/build identity. Run
  from `main`; accept package sources only from `origin/main` or an exact pinned
  retained baseline. Verify clean producers, notarization receipts, exact DMG digests,
  Developer ID identity, tickets and Gatekeeper before
  installation. The universal GUI must include the selected CPU while the bundled
  helper must be exactly package-native. On a fresh host, install from the prior DMG,
  allow a bounded visible-window readiness interval while the process remains alive,
  require AXPress capability, validate and click the small process-owned menu-bar frame,
  then use system-wide z-order hit testing beside it. Require exact PID ownership and frame anchoring, then
  invoke Quit only inside that menu. Reject relaunch/orphans,
  replace the complete app from the newer DMG, and preserve bounded desktop, shared
  CLI-data, attachment and valid login-registration sentinels. Existing app, bridge,
  registration or relevant state root causes refusal; the probe owns only its installed
  copy and exact fresh-host state paths.
- Signing, native-header inventory and fake-service helper E2E cannot stand in for
  installed GUI, account, Keychain, filesystem/TCC, autostart, minimum-OS or update
  evidence. Public-release prerequisites stay independent.

## Coverage

These are required checks, not a record that every level has passed.

| Level | Boundary / scope | Added checks |
|---|---|---|
| L1 | Automated; no plugin | Signing order, publisher/runtime/entitlement arguments, architecture and ZIP/DMG divergence refusal, every helper library's signature, isolated local/active-process/registration guards and blocked-screen failure. |
| L2 | Packaged/external; macOS x64 + arm64; faithful bridge fakes | Trusted CI signs/notarizes both formats; verify extracted headers, signatures, staples, Gatekeeper and helper E2E. Fresh native hosts exercise a separately signed release fixture's synthetic Keychain persistence/delete, login-registration write/read/remove and owned file access; install the real signed app, observe its window and attempt a screenshot. Retain source/run evidence and explicit blocked outcomes. Default PR runs cannot receive signing credentials. |
| L3 | Client end to end; installed macOS x64 + arm64; representative production plugin | Download and install the signed app into Applications without a security bypass. Verify actual GUI startup, browser login/return, token write/read/relaunch restoration, helper control, runtime launch and user-approved filesystem/TCC behavior. |
| L4 | Packaged/client end to end; both Mac CPUs | Private helper-Off replacement plus the full coverage below. |
| L5 | Packaged/client end to end; both Mac CPUs | Include the declared minimum OS and clean-host cases. Combine with the distribution plan's full platform/public ship gate; missing hosts or credentials remain Blocked, not Pass. |

At L4, install strictly increasing signed DMGs, exercise real tray Quit, reject
relaunch/orphans and preserve bounded desktop/shared-state and login-registration
sentinels. Main-only run `35405646668` passed signed replacement and persisted Bridge
Off intent but did not inspect live helper absence. After the correction merged,
main-only run `35411687826` passed the exact pre-Quit installed-helper check on native
x64 and arm64; both prior/current logs on both CPUs record `NO_INSTALLED_HELPER`, and
all implemented report checks are true. Private helper-Off is accepted on both CPUs.
Full coverage also exercises paths with spaces, authenticated helper On, failed-stop,
login/autostart and close-to-tray versus Quit with real shared CLI credentials,
runtimes, history and projects.

## Failure Signals And Exploration

Look for unsigned nested dylibs, lost framework links, wrong-CPU helpers, signature
failure after extraction, rejected/pending notarization treated as success,
Gatekeeper bypass instructions, library-validation/entitlement crashes, token
restoration changes, or packaged helper lookup falling back to PATH. Vary the
artifact format and native CPU, and preserve useful paths/errors in local evidence.
Login must render even while native notification readiness/authorization is pending;
notification listeners must already be installed. A live native window with
black/unrendered content is not a visual pass: inspect screenshots and the fixed-text
desktop startup stages to identify the stalled await.
Use credential-free GUI replay against an available trusted package run rather than
rebuilding unchanged packages for capture-only diagnostics.
Never launch QA over another running desktop or change real account state without
following the macOS QA process.

## Maintenance Sources

- `.github/workflows/desktop-qualification.yml`
- `.github/scripts/macos_signing_ci.sh`
- `.github/scripts/package_desktop_macos.py`
- `.github/scripts/test_package_desktop_macos.py`
- `.github/scripts/qualify_desktop_macos_upgrade.py`
- `.github/scripts/test_qualify_desktop_macos_upgrade.py`
- `.github/scripts/quit_desktop_macos.swift`
- `.github/scripts/inspect_desktop_macos_window.swift`
- `client/desktop/tool/stage_desktop_bundle.dart`
- `client/desktop/lib/core/di/register_module.dart`
- `client/desktop/macos/Runner/Release.entitlements`
- `.agents/skills/macos-desktop-qa/SKILL.md`
- `.plan/active/desktop-distribution/PLAN.md`
