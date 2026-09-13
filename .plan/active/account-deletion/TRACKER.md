# Account Deletion Tracker

## Decisions

- [x] 24-hour cancellable grace period.
- [x] Exact authenticated confirmation plus one UUID operation ID per user action.
- [x] Scheduling revokes sessions/bridges immediately; bridge-local glossary follows existing revocation cleanup.
- [x] Access-token issuing version fences delayed pre-cancellation schedule calls without adding global token lookups.
- [x] A committed schedule remains successful when immediate cleanup needs server-owned retry.
- [x] Successful credential sign-in before the deadline cancels deletion.
- [x] Refresh or failed sign-in never cancels deletion.
- [x] Existing access tokens may expire naturally within 15 minutes.
- [x] Deletion begins after the deadline; external/provider completion is not promised at the exact deadline.
- [x] Preserve the minimal permanent analytics source-suppression tombstone.
- [x] Reuse the reviewed analytics deletion, aggregate rebuild, and delayed-upload sweep boundaries.
- [x] Delete every account-owned glossary scope during finalization.
- [x] Cookie Statement needs no glossary/account-deletion change unless implementation adds tracking technology.

## PR Series

- [ ] **1/9** `🌿 [account-deletion] Approve cancellable deletion plan [step 1/9]` — monorepo plan.
- [ ] **2/9** `🚧 [account-deletion] Schedule deletion and cancel on sign-in [step 2/9]` — auth API/state.
- [ ] **3/9** `🚨 [account-deletion] Finalize due account data [step 3/9]` — auth finalizer/cleanup.
- [ ] **4/9** `🚨 [account-deletion] Automate privacy target processing [step 4/9]` — analytics processor.
- [ ] **5/9** `⚙️ [account-deletion] Add client account deletion domain [step 5/9]` — client API/repository/service.
- [ ] **6/9** `🚧 [account-deletion] Add account deletion recovery UX [step 6/9]` — mobile presentation.
- [ ] **7/9** `🌿 [account-deletion] Publish deletion and glossary disclosures [step 7/9]` — legal documents.
- [ ] **8/9** `🌿 [account-deletion] Reconcile account deletion regression coverage [step 8/9]` — regression docs.
- [ ] **9/9** `⚙️ [account-deletion] Verify rollout and retire plan [step 9/9]` — destructive matrix/retirement.

## Architecture Review

- [x] First review rejected at the pre-review gate because implementation ownership and atomic contracts were too vague.
- [x] Required file/class/layer mappings, database-time transitions, tombstone shape, target processor, and client flow added.
- [x] Second review passed the pre-review gate and found one A9 ownership violation: ordinary and deletion-triggered local logout used different owners.
- [x] Valid finding applied directly without a third review: shared `AccountLogoutService` now owns both pipelines, with closed reason-specific recovery behavior.

## PR Feedback

- [x] Rotate persistent auth finalization failures with bounded lanes and indexed retry eligibility.
- [x] Preserve server scheduling success separately from client local-logout cleanup and provide local-only retry.
- [x] Fence stale access-token schedule calls after successful sign-in cancellation.
- [x] Keep committed scheduling successful when bridge/device cleanup needs worker retry.
- [x] Preserve the durable-plan rule: behavior contracts are reconciled in penultimate Step 8, not duplicated in Step 6.
- [x] Make sustainable analytics quota/cadence a Step 4 and rollout blocker; current 2 GiB cannot run the observed rebuild.

## Rollout Gates

- [ ] Auth scheduling is deployed before client exposure.
- [ ] Due-account finalizer runs under the approved privacy identity.
- [ ] Analytics pending-target processor runs under the approved analytics privacy identity.
- [ ] Production dry-run byte ceilings and the dedicated quota/cadence formula prove sustainable deletion capacity.
- [ ] Non-production end-to-end destructive drill passes.
- [ ] Privacy Policy and Terms are published.
- [ ] Client action remains hidden until both scheduled jobs are operational.

## Final Verification

- [ ] Auth tests and analysis pass.
- [ ] Analytics privacy tests, analysis, render-only validation, and deletion fixtures pass.
- [ ] Client package analysis and focused tests pass.
- [ ] iOS and Android production-shaped scheduling/logout flow passes.
- [ ] Every configured successful sign-in path cancels before deadline.
- [ ] Due account cannot cancel and all account-owned Mongo records, including glossary scopes, are removed.
- [ ] Analytics permanent exclusion, keyed deletion, fixed aggregate rebuild, delayed-upload sweep, and non-repopulation pass.
- [ ] Older public bridge revocation compatibility passes.
- [ ] Plan moved to `.plan/completed/account-deletion/` only after all required evidence is recorded.
