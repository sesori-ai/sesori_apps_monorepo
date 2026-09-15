# Step 4.a — Native macOS Packaging And Notarization

Status: **implementation ready for review; rendered startup moves to step 4.b**.
PR ordinal **5/14**. Work remains in the original `tan-antelope` worktree.

## Scope and safety

- Produce private native x64/arm64 DMGs and app ZIPs with the complete helper bundle.
  Sign native leaves/frameworks/app inside-out, harden the GUI/helper, require Apple
  notarization acceptance, staple, and verify extracted code plus Gatekeeper.
- Use only the existing Developer ID publisher, **DigitalBlock Labs LTD (AQNCF7663C)**,
  and the existing GitHub Apple credentials approved by the user on 2026-09-15.
  No local private-key export, new signing account, infrastructure or public release.
- Default/PR qualification remains credential-free. Only the explicit manual signing
  step receives secrets; its temporary Keychain/certificate/profile stay outside the
  checkout/artifacts and are removed. Python gets public identity/profile arguments,
  not passwords. `macos-gui-probe` never receives signing secrets.
- Keep the existing release entitlements and classic-Keychain configuration:
  `FlutterSecureStorage`, service `com.sesori.desktop`, data-protection Keychain off,
  Darwin plugin 0.4.2+. Do not reintroduce the retired native storage workaround or
  add speculative entitlement exceptions.
- The user explicitly requires uninterrupted unattended execution. Never stop or
  take over the running local bridge, including through the active desktop. Both Mac
  QA targets use fresh native CI. Human-dependent checks go to the final handoff;
  they do not become passes or authorize public publication.

## Implementation

`desktop-qualification.yml` offers closed manual modes: `native-builds`,
`macos-signing-preflight`, `macos-packaging`, and `macos-gui-probe`.

`.github/scripts/macos_signing_ci.sh` owns private import/profile setup and cleanup.
`.github/scripts/package_desktop_macos.py` reuses the existing native inventory,
signs inside-out without deep signing, submits app/DMG for notarization, requires
`Accepted`, staples, creates the final ZIP after app stapling, and verifies both
extracted payloads. Framework symlinks and complete helper bin/lib relationships
are preserved. It records authoritative receipts, identity, inventories and hashes.
Failed destinations are retained; retries use fresh destinations, not automatic deletion.

The macOS identity JSON is a sealed resource at
`Contents/Resources/desktop-bundle.json`, not data in the code-only Helpers subtree.
The helper stays at `Contents/Helpers/bridge/bin/bridge`; Windows/Linux placement,
compiled identity, every-spawn validation, repair guidance and debug/profile behavior
are unchanged. No model/schema/wire change, migration, generated code or legacy-path
fallback was added for an unpublished layout.

Fresh CI installs the real verified app into Applications, checks the expected
publisher and Gatekeeper, launches through LaunchServices, and captures its native
window, full desktop and process sample. A separately Developer-ID-signed release
fixture reuses the actual storage DI and login-registration adapter for synthetic
Keychain persistence/delete, registration write/read/remove and owned-file access.
It never starts account/bridge/session services, is not notarized as a product and
is never uploaded as a product. Guards refuse local execution, existing app/bridge
processes, existing installations and existing login registration.

GUI-only replay accepts a selected trusted successful packaging run, records the
sealed source identity and does not rebuild, re-sign or rerun unchanged helper/
Keychain probes. Artifact access requires repository authorization and retention.

## Qualified credentials and resolved layout failure

| Run / source | Evidence |
|---|---|
| `34997710034` / `8963781` | Both imports completed, but `codesign` could not locate the requested identity. |
| `34998095733` / `93fac44` | Exact public identity was valid and notary authentication passed; explicit `--keychain` alone still failed signing lookup. |
| `34998357930` / `d76fcef410055d38f0b24e4e5405d4d7195824a9` | Registering the temporary Keychain in the runner's user search list fixed lookup. Both CPUs signed, strictly verified and executed a timestamped/hardened native probe. Credential access only, not product proof. |
| `35002549379` / `f5348c07199f24030942036007b854f903c5f930` | Both native builds/profile authentications passed. Enclosing app signing rejected `Contents/Helpers/bridge/desktop-bundle.json`; no product was submitted. |
| `35006541037` / `b41a1f6500a200acaa2f6bdc6db090bfc359c139` | Resources relocation passed both native packaging/notary/extracted-helper legs, version 1.8.4/build 14. |
| `35014995494` / `8fb5d33e4c6ecc0161d31838f0bb0875794c85f6` | Both full packaging and signed platform fixtures passed, build 15. Captured windows were black, so no visual pass was claimed. |
| `35019031550` / tooling `055eb71e77ca716ef7c432766b135048f3b3c768` | Credential-free replay of the unchanged `8fb5d33` packages confirmed screens and Accessibility on both hosts, but still black content with no visible permission prompt. |

A local structural diagnostic used only an owned copy of the older `350cb8e` ARM64
bundle and ad-hoc signing. Moving just JSON to Resources allowed deep/strict app
verification; appending a newline then invalidated the seal. No GUI or private-key
use occurred. Script/results remain under
`build/desktop-macos-packaging-evidence/probe_manifest_layout.py` and
`build/desktop-macos-packaging-evidence/manifest layout probe/`. This was structural
proof, not current-head Developer ID or notarization evidence.

## Latest native evidence

[Run 35019880379](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35019880379)
measured exactly **`d5a03026dbfe7a95af0a262225c9f3ff640c74d1`**, version **1.8.4/build 17**.
It includes incoming main `b69a485` through normal merge
`6a68876722b9c2d15a924091d853144be6ee19fa` and fixed-text startup breadcrumbs.
The recorded build patches are empty. Default six-target qualification was skipped
in this manual mode; this is not a new six-platform run.

| Target | Native job | Private packages artifact | Evidence artifact |
|---|---|---|---|
| macOS x64 | `104552686343` | `10417789644` | `10418442456` |
| macOS arm64 | `104552686228` | `10417512610` | `10417348198` |

Both native rows passed app/DMG notarization acceptance, stapling/signature checks,
Gatekeeper assessment, seven-binary inventories matching across ZIP and DMG, helper
version execution and isolated supervised E2E. Both signed fixtures passed Keychain
write/read/update, persistence across two processes, delete, login registration and
owned-file access. All four downloaded payload hashes match `packaging.json`:

| Payload | SHA256 |
|---|---|
| `Sesori-macos-x64.zip` | `782685e02d111d708474f4d23cca50b81230ee72e73d966b0309289297ac0414` |
| `Sesori-macos-x64.dmg` | `d07e1a28513f449d384a1bbbb0154f6b72bc8c4b670203464a3e0e9978b260ba` |
| `Sesori-macos-arm64.zip` | `e922f53fb7f862407e57f4cdcd00338c6a029f3f8938122c72502b084bfe04d5` |
| `Sesori-macos-arm64.dmg` | `4317f7792a18b2d92c28a7981c736a5faeaad11ca1f500b296e109e1c133b019` |

**Rendered startup is not passing.** Both native captures still show black app
content. Breadcrumbs reach `Desktop startup: starting desktop attention` but not
analytics or rendering. Native notification initialization can outlive startup;
[step 4.b](step-04b.md) addresses that separately rather than widening this packaging
PR. No specific notification-daemon or permission-dialog cause is claimed yet.
No real account login/restoration, representative harness, interactive TCC, OS-login
autostart, minimum-OS, updater or public-release gate is implied by these probes.

Evidence lives under `build/desktop-macos-packaging-evidence/native-d5a0302/`.
Artifacts expire after **14 days**. From repository root, with GitHub access and a
fresh destination:

```bash
gh run download 35019880379 --repo sesori-ai/sesori_apps_monorepo \
  --pattern 'desktop-macos-*' --dir build/desktop-macos-packaging-evidence/retrieved-d5a0302
```

Compare inner ZIP/DMG hashes against `packaging.json`, require both notary statuses
to be `Accepted`, compare manifest/packager source to the full SHA above, confirm
empty source patches and `All tests passed!` in E2E logs. Read fixture logs and
images separately; a native window assertion does not prove rendered content.
Local downloads were not installed, mounted or launched. The existing local desktop
and bridge remain untouched.

## Focused verification and review

- Manifest correction: **24** Flutter resolver/staging cases and desktop analyzer
  passed before commit `b41a1f6`; the final analyzer/test logs are
  `layout-flutter-tests-final.log` and `layout-desktop-analyze-final.log`.
- **8** Python packaging tests passed on the same correction inputs
  (`layout-python-tests.log`). The first implementation also passed its own eight
  tests before `f5348c0`; these are separate evidence checkpoints, not extra cases.
- CI-only fixture: **3** Python safety tests, desktop analyzer, native Swift
  typecheck, actionlint and ShellCheck passed (`probe-*.log`). The initial analyzer
  found import/enum style infos; the final command passed after their correction.
- GUI replay: safety tests, Swift typecheck, actionlint and publisher-requirement
  syntax/verification against a downloaded signed DMG passed (`gui-replay-*.log`).
- Merged source plus startup breadcrumbs: **one** cold-start widget smoke case and
  desktop analyzer passed (`startup-app-smoke.log`, `startup-analyze.log`). These
  mocks do not exercise the native initialization wait.
- Commands run from `client/desktop` unless Python/tooling requires repository root:

```bash
flutter test test/core/platform/desktop_packaged_bridge_path_test.dart test/tool/stage_desktop_bundle_test.dart --reporter expanded
flutter test test/app_smoke_test.dart --reporter expanded
flutter analyze --no-pub --fatal-infos
python3 -m unittest discover -s .github/scripts -p test_package_desktop_macos.py -v
python3 -m unittest discover -s .github/scripts -p test_probe_desktop_macos.py -v
xcrun swiftc -typecheck .github/scripts/inspect_desktop_macos_window.swift
actionlint .github/workflows/desktop-qualification.yml
shellcheck .github/scripts/macos_signing_ci.sh
```

Scoped architecture plan review **approved/no findings**, run
`1d781b5d-4861-4487-9094-1a00731db885`. Scoped implementation review
**approved/no findings**, run `798cfb06-1fb5-42d4-ae69-0ed731e246c9`, covering
`b41a1f6` versus `f5348c0` (all 11 changed files, B-Client only). Review artifacts:
`reviews/desktop-distribution-step-04-manifest-{plan,implementation}.md` in the
respective session outputs. They approve the manifest producer/consumer boundary,
not unrelated tooling or unexecuted QA. Later additions are tests/tooling and
fixed-text logs, not new architectural ownership.

Size checkpoints are fixed revisions: `b41a1f6` vs `e853838` was **905** authored
changed lines; `d5a0302` vs merged main `b69a485` was **1,421**, zero generated.
The evidence narrative is consolidated before opening the PR; those historical
counts are not claims about the final documentation diff. Step 4.b keeps the newly
exposed startup behavior/focused regressions out of the package-signing review.
