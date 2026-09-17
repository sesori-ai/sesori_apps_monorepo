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
- Consumer audit: source `ed09171665995b98d1e010b9b5bd340c3c50a605`, tree
  `53e40902232a807cd91f83beaec669f95c084b9f`, from cwd
  `/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/tan-antelope`.
  Reproduced with the following source-only command (no secret values retrieved):

  ```bash
  source=ed09171665995b98d1e010b9b5bd340c3c50a605
  pattern='secrets\.(MACOS_CERT_P12_BASE64|MACOS_CERT_PASSWORD|MACOS_KEYCHAIN_PASSWORD'
  pattern+='|APPLE_ID|APPLE_APP_SPECIFIC_PASSWORD)'
  git grep -n -E "$pattern" "$source" -- .github/workflows
  ```

  Result: 14 references across the four consumers/callers listed above; no iOS or
  Android credential consumer uses this allowlist. This is source evidence, separate
  from live environment API configuration. Environment configuration was checked via
  `gh api repos/sesori-ai/sesori_apps_monorepo/environments/macos-signing` and its
  `/deployment-branch-policies` endpoint.
- Bootstrap reads repository values without a destination environment binding, so
  partially populated destination secrets cannot shadow source values on retry.
  The workflow's main-ref condition remains; consumers later use the environment's
  independent main-branch deployment policy.
- Bootstrap actions are pinned to full commits; PyNaCl, cffi and pycparser binary
  wheels are version/hash-locked. A synthetic sealed-box roundtrip runs before
  credential exposure. These pins bound dependency changes, not a claim that
  hashing alone proves third-party code free of vulnerabilities.
- Bootstrap #1525 merged as `ab9d4eb245434195c6b70fdb70b285e0a7a05bd5`.
  Manual run `35139046166`, job `104938663518`, passed at that exact source;
  the synthetic sealed-box roundtrip and encryption completed without plaintext output.
- The five ciphertext values were imported via GitHub's environment-secret API only
  after checking the exact source, allowlist, destination environment, public key and
  key ID. Metadata confirms five destination names. The temporary Actions artifact
  `10464765058` and local ciphertext file were removed after successful import.
- Repository copies remain present. Step 2 binds existing consumers to the environment,
  removes their caller secret passing, and removes the temporary bootstrap workflow.
  The reusable build's full six-target matrix uses the environment (no approval delay);
  only its macOS signing steps consume credentials. Private desktop qualification uses
  the same environment. Both routes now require dispatch from main. The combined
  internal-release and submission callers also fail non-main dispatches before
  build-number/store work, preventing partial mobile uploads when signing is denied.
- `verify-macos-signing.yml` calls the actual reusable CLI build with the committed
  version and read-only repository permission. It uploads private build artifacts only;
  no TestFlight, Android, tag, release or installer publication is invoked.
- Cutover must merge before main-only native proof: dispatch `verify-macos-signing.yml`
  and `desktop-qualification.yml` with `mode=macos-signing-preflight` from main.
  Verify successful native x64/ARM64 signing and environment admission without approval.
  Repository copies must not be deleted before those checks and an active-release check.
- Live cutover verification and repository-copy removal are still pending. TestFlight
  and Android workflow files, credentials and release jobs remain unchanged.

Keep this plan active until consumer verification, removal and final metadata checks
are recorded. Existing desktop distribution release/interactive gates remain separate.
