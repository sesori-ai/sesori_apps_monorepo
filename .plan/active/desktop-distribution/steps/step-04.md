# Step 4 — Native macOS Packaging and Notarization

Status: **in progress — credential access qualification**. PR ordinal **5/13**.
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
   only Keychain groups. The current classic-Keychain adapter remains the owner.
4. Produce notarized/stapled DMGs and app ZIPs for each native architecture,
   preserving framework symlinks and the complete helper bin/lib layout. Verify
   extracted payloads and collect final identities/digests after signing/stapling.
   Outputs remain private CI artifacts; publication belongs to step 6.
5. Prove signatures/notarization, relocated-helper behavior, and the actual signed
   GUI's Keychain/auth/control/runtime/filesystem behavior. Do not launch over an
   existing desktop/bridge or access real account state without the required QA
   approval. CI build/probe success is not interactive or minimum-OS execution.

The exact packaging implementation and entitlement/probe decisions will be pinned
after access qualification and code inspection, before architecture-bearing changes.
Estimated budget: under 1,000 authored changed lines; zero new application mutable
fields, subscriptions, timers, lifecycle owners, persistence or transport contracts.
Credential cleanup is scoped to this job's own secret files; failed unsigned build
outputs remain diagnosable. No unrelated CLI/mobile release changes are intended.

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
