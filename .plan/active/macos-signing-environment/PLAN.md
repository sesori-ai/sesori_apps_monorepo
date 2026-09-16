# macOS signing environment migration

## Authorized outcome

Move the existing five macOS signing/notarization secrets from repository scope to
`macos-signing`, restricted to the `main` branch with **no required reviewers or wait
timer**. Scheduled CLI signing remains automatic. Desktop publication is separate
and must retain an approval gate; migration does not authorize publishing releases.
TestFlight, Android, App Store Connect, Match credentials and their automation remain
unchanged. No credential rotation, new identity, private-key export, local Keychain
changes, or live app/bridge interruption.

## Scope and consumers

- `_reusable-bridge-build.yml`: certificate, certificate password and temporary
  Keychain password; called by `release-all-platforms.yml` and `submit-release.yml`.
- `desktop-qualification.yml`: same three plus `APPLE_ID` and
  `APPLE_APP_SPECIFIC_PASSWORD` for private notarization.
- `APPLE_TEAM_ID` repository variable stays unchanged. The similarly named iOS
  secret and all `APP_STORE_CONNECT_API_*` / `MATCH_*` secrets are out of scope.
- Internal release finalization waits for bridge and mobile jobs. Do not introduce
  approval waits into the bridge job or delete source secrets before cutover proof.

## Execution and PR boundaries

1. `⚙️ [macos-signing-environment] Bootstrap encrypted signing-secret migration [step 1/2]`
   - Create environment with custom branch policy `main`, no reviewers/wait timer.
   - Merge a temporary manual, main-only workflow that seals the five existing values
     directly to GitHub's destination-environment public key.
   - Download only ciphertext and submit it through environment-secret API using the
     operator's existing local GitHub authorization. No admin token enters Actions;
     no credential values enter logs or local files. Verify recipient key before upload.
   - Existing consumers and repository secrets stay untouched throughout this step.
2. `⚙️ [macos-signing-environment] Cut over automatic signing and retire repository copies [step 2/2]`
   - Bind signing consumers to the main-only environment; remove caller secret passing
     and required reusable-workflow secret declarations together.
   - Add a private verification route for the reusable CLI build if necessary, with no
     mobile upload, tagging or release creation. Reuse private desktop credential checks.
   - Remove temporary migration workflow. Add focused workflow contract tests/docs.
   - After merge, prove existing environment-backed CLI signing and desktop credential
     access on both native CPUs without running TestFlight or publishing.
   - Remove only the five repository secret copies after verification. Verify environment
     names/policies and repository absence; document exact source/run evidence.

Two coherent PRs preserve the source credentials until migration and consumers are
verified. No additional product persistent state, services, timers or lifecycle owners.
The temporary encrypted artifact is retained for one day and should be removed after
successful import. No plaintext secret artifact is permitted.

## Verification and failure handling

Use actionlint, focused workflow-contract tests, and diff/link validation. CI must
exercise the actual environment-bound native signing jobs; static checks alone do not
prove access. Inspect active release jobs before final repository-secret removal.
A failed upload, signing probe or policy check leaves source repository secrets in
place; diagnose before deletion. Environment access is tied to the workflow dispatch
branch, not the checked-out release source. Existing scheduled and production dispatches
must run from main. Do not permit arbitrary branches or add approval gates to routine
CLI builds to simplify migration.

Desktop public publication remains unimplemented/gated; no release command is introduced
by this migration. The existing store-production approvals remain unchanged. A future
desktop publisher must use a separate reviewed publication job, not make automatic
signing wait for human approval.

## Current evidence

- Environment created with `main` branch policy and no reviewers/wait timer.
- Destination public key ID: `3380204578043523366` (public metadata, not a secret).
- Secret names audited across existing workflows; no values retrieved.
- No signing consumers changed and no repository secrets removed during bootstrap.
- Step 1 implementation pending review; native verification and cutover remain pending.

Keep this plan active until consumer verification, removal and final metadata checks
are recorded. Existing desktop distribution release/interactive gates remain separate.
