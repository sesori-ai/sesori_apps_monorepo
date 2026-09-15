# Step 4 — Native macOS Packaging and Notarization

Status: **in progress — local packaging tooling checks passed; native CI next**.
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
restricted entitlement is changing; reassess architecture review only if a concrete
native failure requires production-boundary changes.
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
Actual signed-package and profile-based notarization evidence remains pending.

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
