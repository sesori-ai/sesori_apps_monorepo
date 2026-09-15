# Native macOS Packaging

## Capability

Private Developer ID signed/notarized macOS x64 and arm64 desktop packages,
containing the identity-bound GUI and its complete native bridge helper. This
packaging capability does not imply public downloads or an updater have shipped.

## Required Behavior

- Build from committed source with the pinned native SDK. Preserve framework
  symlinks, native CPU support and the complete `Contents/Helpers/bridge/bin`–`lib`
  relationship. The packaged identity continues to control helper admission from
  `Contents/Resources/desktop-bundle.json`; keep JSON out of the code-only Helpers
  subtree. Changing that resource after signing must invalidate the app's seal.
- Sign nested native code/frameworks inside-out, including every helper dylib;
  enable hardened runtime for the GUI/helper without adding speculative security
  exceptions. Keep the established non-sandboxed classic-Keychain configuration.
- Notarize/staple the app before creating the final ZIP. Sign/notarize/staple the
  DMG too. Both extracted payloads must retain valid signatures and tickets, pass
  Gatekeeper assessment and execute the native helper. Offer Applications as the
  installation destination, not running the GUI from a mounted DMG.
- Use signing credentials only in explicitly selected trusted manual CI, never PR
  qualification. Keep private material out of command reporting/artifacts; clean
  only job-owned credential files. Failed output remains available for diagnosis,
  but incomplete packages are not uploaded as successful package artifacts.
- Signing, native-header inventory and fake-service helper E2E cannot stand in for
  installed GUI, account, Keychain, filesystem/TCC, autostart, minimum-OS or update
  evidence. Public-release prerequisites stay independent.

## Coverage

These are required checks, not a record that every level has passed.

| Level | Boundary / scope | Added checks |
|---|---|---|
| L1 | Automated; no plugin | Native signing order, correct publisher/runtime/entitlement arguments, architecture refusal, explicit verification of all helper libraries. |
| L2 | Packaged/external; macOS x64 + arm64; faithful bridge fakes | Trusted CI signs/notarizes both formats; verify extracted headers, signatures, staples, Gatekeeper and helper E2E; retain final digests/identity and attributable source/run evidence. Default PR runs cannot receive signing credentials. |
| L3 | Client end to end; installed macOS x64 + arm64; representative production plugin | Download and install the signed app into Applications without a security bypass. Verify actual GUI startup, browser login/return, token write/read/relaunch restoration, helper control, runtime launch and user-approved filesystem/TCC behavior. |
| L4 | Packaged/client end to end; both Mac CPUs | Exercise paths with spaces, login/autostart and close-to-tray versus Quit. Compare an installed N→N+1 package with stable signing identity; preserve shared CLI credentials, runtimes, history and projects. |
| L5 | Packaged/client end to end; both Mac CPUs | Include the declared minimum OS and clean-host cases. Combine with the distribution plan's full platform/public ship gate; missing hosts or credentials remain Blocked, not Pass. |

## Failure Signals And Exploration

Look for unsigned nested dylibs, lost framework links, wrong-CPU helpers, signature
failure after extraction, rejected/pending notarization treated as success,
Gatekeeper bypass instructions, library-validation/entitlement crashes, token
restoration changes, or packaged helper lookup falling back to PATH. Vary the
artifact format and native CPU, and preserve useful paths/errors in local evidence.
Never launch QA over another running desktop or change real account state without
following the macOS QA process.

## Maintenance Sources

- `.github/workflows/desktop-qualification.yml`
- `.github/scripts/macos_signing_ci.sh`
- `.github/scripts/package_desktop_macos.py`
- `.github/scripts/test_package_desktop_macos.py`
- `client/desktop/tool/stage_desktop_bundle.dart`
- `client/desktop/lib/core/di/register_module.dart`
- `client/desktop/macos/Runner/Release.entitlements`
- `.agents/skills/macos-desktop-qa/SKILL.md`
- `.plan/active/desktop-distribution/PLAN.md`
