# Codex Plugin Stability Feedback: Tracker

## Current State

- **Plan slug:** `codex-plugin-stability-feedback`
- **Implementation base:** `origin/main` at
  `5a67ee65e63a8594049fd27028700aa5c184b6c8`
- **Stack root:** `2408b574`
- **Series state:** Steps 1 through 9 merged; Step 10 is verified and ready
  for review
- **Current step:** Step 10/11
- **Current branch:** `codex-plugin-stability-feedback-f12-generated-repository-instructions`
- **Plan PR:** [#724](https://github.com/sesori-ai/sesori_apps_monorepo/pull/724),
  merged as `149e7914` with the Step 1 production fix
- **Next action:** Open the Step 10 PR

## Plan Review

- **Reviewer:** `aristotle-plan-review`
- **Verdict:** Approved with no findings
- **Date:** 2026-08-04
- **Reviewed scope:** `.plan/active/codex-plugin-stability-feedback/`
- **Findings and corrections:** None. The reviewed plan passed the pre-review
  gate and the bridge, shared, and client architecture checks.

## Finding Ledger

| Done | Finding | State | Existing fix branch / PR / commit | Current delivery acceptance |
|---|---|---|---|---|
| [x] | F-01 generated context | Fixed on `main` | `codex-stability-2-user-context`; [#710](https://github.com/sesori-ai/sesori_apps_monorepo/pull/710); `0dc0c6ec` | Preserve complete-envelope omission and authored-text regressions |
| [x] | F-02 shell identity | Fixed on `main` | `codex-stability-3-tool-identity`; [#712](https://github.com/sesori-ai/sesori_apps_monorepo/pull/712); `e5cb9d86`; [#731](https://github.com/sesori-ai/sesori_apps_monorepo/pull/731); `7b2fa65a` | Direct and code-mode commands retain one canonical ID |
| [x] | F-03 interrupted history | Fixed on `main` | `codex-stability-4-tool-lifecycle`; [#713](https://github.com/sesori-ai/sesori_apps_monorepo/pull/713); `f70bdbcb` | Preserve terminal replay regressions |
| [x] | F-04 prompt image history | Fixed on `main` | `codex-stability-5-prompt-images`; [#715](https://github.com/sesori-ai/sesori_apps_monorepo/pull/715); `6930b3a9` | Preserve stable text/file replay regressions |
| [x] | F-05 debug SSE UTF-8 | Fixed on `main` | `codex-stability-1-debug-sse`; [#709](https://github.com/sesori-ai/sesori_apps_monorepo/pull/709); `025ba43b` | Preserve same-connection UTF-8 regression |
| [x] | F-06 failed tool replay | Fixed on `main` | `codex-stability-6-failed-tool-status`; [#717](https://github.com/sesori-ai/sesori_apps_monorepo/pull/717); `20521cc2` | Preserve error/output/exit-code replay |
| [x] | F-07 generated image convergence | Fixed on `main` | `codex-stability-7-image-generation-history`; [#718](https://github.com/sesori-ai/sesori_apps_monorepo/pull/718); `2408b574`; [#724](https://github.com/sesori-ai/sesori_apps_monorepo/pull/724); [#732](https://github.com/sesori-ai/sesori_apps_monorepo/pull/732) | Durable images and exact generated wrappers converge live and cold |
| [x] | F-08 late abort identity | Fixed on `main` | D4; `a32b6c29`; [#733](https://github.com/sesori-ai/sesori_apps_monorepo/pull/733); `c6c73650` | Late completion updates and retires only its failed canonical card |
| [x] | F-09 file identity | Fixed on `main` | D5 `9da8f2e1`; [#740](https://github.com/sesori-ai/sesori_apps_monorepo/pull/740); `b4455593`; D8 `d4e30b87`; [#749](https://github.com/sesori-ai/sesori_apps_monorepo/pull/749); `22f65807` | Typed boundary merged |
| [x] | F-10 restart terminalization | Fixed on `main` | D6 `8f0f4ece`; [#743](https://github.com/sesori-ai/sesori_apps_monorepo/pull/743); `4b779cc2`; D8 `d4e30b87`; [#749](https://github.com/sesori-ai/sesori_apps_monorepo/pull/749); `22f65807` | Typed boundary merged |
| [x] | F-11 archive history | Fixed on `main` | D7; `cdd3a305`; [#746](https://github.com/sesori-ai/sesori_apps_monorepo/pull/746); `4785f4c7` | Archive/unarchive remains readable and delete remains destructive |
| [x] | F-12 generated repository instructions | Fixed on Step 10 branch | Documented on D9 `ef2356c4`; fixed by `2e534673` | Complete generated AGENTS envelopes are hidden without hiding authored text |

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [x] | 1/11 | `codex-stability-deep-test-1-image-wrapper-directive` | `🌿 [codex-plugin-stability-feedback] fix(codex): recognize directed image wrappers [step 1/11]` | 1,100 actual | [PR #724](https://github.com/sesori-ai/sesori_apps_monorepo/pull/724) merged as `149e7914` |
| [x] | 2/11 | `codex-stability-deep-test-2-code-mode-tool-identity` | `⚙️ [codex-plugin-stability-feedback] fix(codex): unify code-mode command identity [step 2/11]` | 299 actual | [PR #731](https://github.com/sesori-ai/sesori_apps_monorepo/pull/731) merged as `7b2fa65a` |
| [x] | 3/11 | `codex-stability-deep-test-3-image-wrapper-projection` | `⚙️ [codex-plugin-stability-feedback] fix(codex): hide generated image wrappers [step 3/11]` | 159 actual | [PR #732](https://github.com/sesori-ai/sesori_apps_monorepo/pull/732) merged as `5aaf979d` |
| [x] | 4/11 | `codex-stability-deep-test-4-late-abort-tool-identity` | `⚙️ [codex-plugin-stability-feedback] fix(codex): retain late command identity after abort [step 4/11]` | 643 actual | [PR #733](https://github.com/sesori-ai/sesori_apps_monorepo/pull/733) merged as `c6c73650` |
| [x] | 5/11 | `codex-stability-deep-test-5-file-tool-identity` | `⚙️ [codex-plugin-stability-feedback] fix(codex): unify file change identity [step 5/11]` | 342 actual | [PR #740](https://github.com/sesori-ai/sesori_apps_monorepo/pull/740) merged as `b4455593` |
| [x] | 6/11 | `codex-stability-deep-test-6-restart-tool-terminalization` | `⚙️ [codex-plugin-stability-feedback] fix(codex): settle interrupted tools after restart [step 6/11]` | 380 actual | [PR #743](https://github.com/sesori-ai/sesori_apps_monorepo/pull/743) merged as `4b779cc2` |
| [x] | 7/11 | `codex-stability-deep-test-7-local-archive-history` | `🌿 [codex-plugin-stability-feedback] fix(codex): preserve locally archived history [step 7/11]` | 384 actual | [PR #746](https://github.com/sesori-ai/sesori_apps_monorepo/pull/746) merged as `4785f4c7` |
| [x] | 8/11 | `codex-stability-deep-test-8-typed-boundaries` | `🚧 [codex-plugin-stability-feedback] refactor(codex): type replay and item boundaries [step 8/11]` | 1,174 actual | [PR #749](https://github.com/sesori-ai/sesori_apps_monorepo/pull/749) merged as `22f65807` |
| [x] | 9/11 | `codex-stability-deep-test-9-mobile-images` | `🚧 [codex-plugin-stability-feedback] feat(codex): support mobile image prompts [step 9/11]` | 1,325 actual | [PR #751](https://github.com/sesori-ai/sesori_apps_monorepo/pull/751) merged as `5a67ee65` |
| [ ] | 10/11 | `codex-plugin-stability-feedback-f12-generated-repository-instructions` | `🌿 [codex-plugin-stability-feedback] fix(codex): hide generated repository instructions [step 10/11]` | 157 actual | `2e534673`; merged forward from `5a67ee65`; verified and ready to open |
| [ ] | 11/11 | `codex-plugin-stability-feedback-retire-plan` | `🌱 [codex-plugin-stability-feedback] docs: retire Codex stability feedback plan [step 11/11]` | 40–100 | Blocked on Step 10 merge |

## Exact PR Titles

1. `🌿 [codex-plugin-stability-feedback] fix(codex): recognize directed image wrappers [step 1/11]`
2. `⚙️ [codex-plugin-stability-feedback] fix(codex): unify code-mode command identity [step 2/11]`
3. `⚙️ [codex-plugin-stability-feedback] fix(codex): hide generated image wrappers [step 3/11]`
4. `⚙️ [codex-plugin-stability-feedback] fix(codex): retain late command identity after abort [step 4/11]`
5. `⚙️ [codex-plugin-stability-feedback] fix(codex): unify file change identity [step 5/11]`
6. `⚙️ [codex-plugin-stability-feedback] fix(codex): settle interrupted tools after restart [step 6/11]`
7. `🌿 [codex-plugin-stability-feedback] fix(codex): preserve locally archived history [step 7/11]`
8. `🚧 [codex-plugin-stability-feedback] refactor(codex): type replay and item boundaries [step 8/11]`
9. `🚧 [codex-plugin-stability-feedback] feat(codex): support mobile image prompts [step 9/11]`
10. `🌿 [codex-plugin-stability-feedback] fix(codex): hide generated repository instructions [step 10/11]`
11. `🌱 [codex-plugin-stability-feedback] docs: retire Codex stability feedback plan [step 11/11]`

## Branch Ancestry

```text
origin/main
  -> D1 + PLAN.md + TRACKER.md
  -> D2
  -> D3
  -> D4
  -> D5
  -> D6
  -> D7
  -> D8
  -> D9
  -> F-12 fix
  -> plan retirement
```

- Preserve existing production commit order:
  `c3ab5fcb` -> `58585e1f` -> `36ee48e9` -> `a32b6c29` ->
  `9da8f2e1` -> `8f0f4ece` -> `cdd3a305` -> `d4e30b87` ->
  `ef2356c4`.
- Documentation commits `c4767b04` and `e86bb66f` remain on D7 and D8.
- Merge forward only. Never rebase, reset, reorder, or cherry-pick the stack.
- Before opening Step N, merge the updated Step N-1 branch into it and resolve
  only evidenced conflicts.

## Locked Decisions

- Backend-specific wrapper, identity, replay, and generated-context behavior
  stays in `sesori_plugin_codex`.
- Shared/mobile code consumes only declared backend-neutral capabilities.
- Missing or unresolved attachment support is false; disconnect clears prior
  bridge capability provenance.
- No database migration, new persisted field, generic correlation registry,
  broad parser framework, global lock, or cross-plugin lifecycle owner.
- Complete generated content may be hidden only at an owning projection boundary
  with authored-content evidence and focused false-positive tests.
- The relay-version `123` defect is explicitly outside this plan.
- The transient self-healing initial-history observation is accepted unless new
  ordinary-flow evidence demonstrates meaningful persistent impact.
- Existing product analytics remain unchanged; no content/provider/image data is
  reported.

## Cleanup Outcomes Planned

- Step 4 narrows alias retention and retires aliases at item completion.
- Step 7 removes destructive backend archive notification.
- Step 8 removes raw map/status interpretation after typed owners replace it.
- Step 9 deletes the hardcoded composer attachment-support helper.
- Step 10 reuses the existing generated-context boundary without new machinery.
- Step 11 moves the active plan tree to completed and later permits obsolete
  branch/worktree cleanup once no stacked PR depends on those refs.
- The stability report remains as test evidence; plan/tracker own delivery state.

## Execution Rules

- Merge PRs in numeric order. A successor may target its immediate predecessor
  while open, but every step must be independently valid at its base.
- After each merge notification, continue automatically with the next numbered
  step. Stop only for a material decision or blocker.
- Update this tracker in every step with actual base SHA, changed-line count,
  tests, analysis, review, PR URL, merge SHA, and finding-state changes.
- Target at most 1,500 changed lines per PR, counting generated code and tests.
- Run code generation instead of hand-editing generated files.
- Run focused tests, owning-package full tests, fatal analysis, and
  `git diff --check` for production steps. Run architecture implementation
  review only for Steps 6, 8, and 9 unless scope materially changes.
- Step 10 captures a sanitized structural fixture first and broadens beyond cold
  history only if ordinary-flow evidence requires it.
- Step 11 runs documentation validation only and leaves no active plan copy.

## Verification Log

- **Historical baseline:** PRs #709, #710, #712, #713, #715, #717, and #718
  merged to `main`; their exact finding mapping appears above.
- **Existing deep-test verification:** the stability report records focused and
  full Codex tests, fatal analysis, simulator evidence, navigation/reconnect/
  restart checks, and privacy-safe cleanup through D8.
- **Step 1 base update:** merged `origin/main` at `009bb44a` forward into D1 as
  merge commit `636546f6`; no rebase or history rewrite.
- **Step 1 plan authoring:** `PLAN.md` and `TRACKER.md` added with fixed slug,
  eleven titles, D1-D9 ancestry, F-12 follow-up, retirement lifecycle, and
  individual F-01 through F-12 acceptance entries.
- **Step 1 plan review:** `aristotle-plan-review` approved the complete plan and
  tracker with no findings on 2026-08-04.
- **Step 1 production verification:** All 29 focused lifecycle-tracker tests and
  all 297 Codex package tests pass. `dart analyze --fatal-infos` reports no
  issues. Both branch and staged `git diff --check` pass.
- **Step 1 PR review:** Ten bot threads produced six valid correction groups.
  Step 9 now explicitly requires its dated transport-compatibility cleanup
  comment; malformed `@exec` JSON remains visible; a local balanced scanner
  requires the exact direct/forwarded wrapper remainder while ignoring call-like
  prompt text; directive marker spacing is horizontal-only; and forwarded
  capture handling is null-safe. Nested executable tool calls also fail visible
  without treating call-like prompt text as code. All seven code regressions
  failed before the mapper hardening. All 29 focused tests, fatal analysis, and
  `git diff --check` pass afterward.
- **Step 1 accepted review risk:** Four subsequent bot threads requested broader
  JavaScript regex/template/delimiter parsing for unobserved generated wrappers.
  The owner accepted the bounded risk on 2026-08-04 rather than growing this
  localized classifier into a partial JavaScript tokenizer. Every thread
  received a rationale reply and was closed before merge.
- **Step 1 change size:** 1,100 lines against the PR merge base: 842 plan/tracker
  additions plus 250 production/test additions and 8 deletions. This is below the
  1,500-line soft cap.
- **Step 1 delivery:** Plan/tracker committed as `d3ec1923`; PR
  [#724](https://github.com/sesori-ai/sesori_apps_monorepo/pull/724) merged as
  `149e7914` on 2026-08-04 with zero unresolved threads.
- **Step 2 base update:** Merged the complete local D1 branch forward as
  `8ee54e0b`, then merged `origin/main` at `4f890087` as `24e07907`. Existing
  production commit `58585e1f` remains in its original stack position; no
  rebase, reset, reorder, or cherry-pick occurred.
- **Step 2 production verification:** All 33 focused lifecycle-tracker tests and
  all 301 Codex package tests pass. `dart analyze --fatal-infos` reports no
  issues. Both the branch comparison and current working-tree `git diff --check`
  pass.
- **Step 2 PR review:** Six bot threads produced one valid correction group.
  The code-mode classifier now finds exactly one balanced command invocation
  outside strings and comments while accepting invocation whitespace; three
  regressions failed before the correction. The separate direct and code-mode
  queues remain intentional because a direct rollout `exec_command` record is
  authoritative and the custom code-mode call is only its fallback.
- **Step 2 change size:** 299 lines against the PR merge base,
  including production code, tests, and plan/tracker updates. This is below the
  1,500-line soft cap.
- **Step 2 delivery:** Pushed and opened as
  [PR #731](https://github.com/sesori-ai/sesori_apps_monorepo/pull/731), which
  passed all 11 checks and merged as `7b2fa65a` on 2026-08-04 with zero
  unresolved threads.
- **Step 3 base update:** Merged the complete local D2 branch forward as
  `3c7a9556`, then merged `origin/main` at `7b2fa65a` as `2a806710`. Existing
  production commit `36ee48e9` remains in its original stack position; no
  rebase, reset, reorder, or cherry-pick occurred.
- **Step 3 merge resolution:** Re-expressed the content-forwarding wrapper as an
  exact post-invocation remainder on the Step 1 balanced scanner. This preserves
  the D3 behavior while retaining malformed, mixed-purpose, nested-tool, and
  call-like prompt visibility regressions added during Step 1 review.
- **Step 3 production verification:** All 33 focused lifecycle-tracker tests and
  all 301 Codex package tests pass. `dart analyze --fatal-infos` reports no
  issues. Both branch and working-tree `git diff --check` pass.
- **Step 3 change size:** 159 lines against the PR merge base,
  including production code, tests, and plan/tracker updates. This is below the
  1,500-line soft cap.
- **Step 3 delivery:** Pushed and opened as
  [PR #732](https://github.com/sesori-ai/sesori_apps_monorepo/pull/732), which
  merged as `5aaf979d` on 2026-08-04.
- **Step 3 late review:** One bot thread arrived as PR #732 merged. It correctly
  identified that a content loop shadowing the image-result variable is invalid
  JavaScript and must remain visible. Step 4 carries correction `443b4433` and a
  regression that failed before the fix; the merged-PR thread received a reply
  and was resolved.
- **Step 4 base update:** Merged the complete local D3 branch forward as
  `e1f2cc78`, then merged `origin/main` at `5aaf979d` as `9cf73e30`. Existing
  production commit `a32b6c29` remains in its original stack position; no
  rebase, reset, reorder, or cherry-pick occurred.
- **Step 4 production verification:** All 38 focused lifecycle-tracker tests and
  all 306 Codex package tests pass. `dart analyze --fatal-infos` reports no
  issues. Both branch and working-tree `git diff --check` pass.
- **Step 4 PR review:** Repeated bot-review rounds exposed two valid lifecycle
  seams but also made the thread-wide cleanup approach increasingly coupled.
  The owner approved replacing its retention marker and active-work predicate
  with an isolated per-item retained-command map. Terminal evidence moves only
  outstanding aliased commands into that map and clears ordinary thread state;
  each late completion updates and retires only its own canonical command, so a
  newer turn remains independent. Late output still merges exactly once, and
  terminal app-server evidence settles commands when rollout terminal evidence
  is unavailable. Current Codex `turn/completed` evidence maps nested `failed`
  and `interrupted` statuses to errors rather than assuming method-level success.
  The architecture review kept terminal evidence interpretation in the tracker;
  the plugin only drains, forwards evidence, and emits returned projections.
  Regressions cover omitted turn IDs, external/newer turns, pending completed
  candidates, stale late rollout output, repeated literal `Output:` text, and
  executor-envelope overlap. Turn-scoped terminal evidence now leaves a newer
  rollout turn untouched. Late app-server `aggregatedOutput` replaces the
  provisional rollout envelope as the authoritative process output, removing
  the custom overlap parser and handling repeated polling envelopes directly.
- **Step 4 change size:** 643 lines against the PR merge base,
  including the inherited Step 3 correction, production code, tests, and
  plan/tracker updates. This is below the 1,500-line soft cap.
- **Step 4 delivery:** Pushed and opened as
  [PR #733](https://github.com/sesori-ai/sesori_apps_monorepo/pull/733), which
  passed all 12 checks and merged as `c6c73650` on 2026-08-04 with zero
  unresolved threads.
- **Step 5 base update:** Merged the complete local D4 branch forward as
  `39d7dac7`, then merged `origin/main` at `c6c73650` as `d3425e53`. Existing
  production commit `9da8f2e1` remains in its original stack position; no
  rebase, reset, reorder, or cherry-pick occurred. Conflicts preserved D4's
  per-item late-command lifecycle while extending the same tracker-owned
  correlation boundary to D5 file changes.
- **Step 5 production verification:** All 39 focused lifecycle-tracker tests and
  all 307 Codex package tests pass. `dart analyze --fatal-infos` reports no
  issues. Both branch and working-tree `git diff --check` pass.
- **Step 5 behavior:** Exact generated code-mode `tools.apply_patch` wrappers
  project as canonical edit tools, retain their patch/path presentation, and
  correlate same-turn app-server `fileChange` start/completion events onto that
  identity. Ordinary command ordering remains unchanged.
- **Step 5 PR review:** Three Qodo bot threads produced one correctness fix and
  two convention fixes. Redirected wait results now check the selected canonical
  identity before suppressing executor output; its regression failed before the
  change. New mapper/test helpers now use required named parameters throughout.
  A subsequent Cubic finding correctly required decoded wrappers to contain a
  complete patch envelope and file header before entering the FIFO; the malformed
  predecessor regression failed before validation. Cubic's request to remove the
  `fileChange` start pre-drain was declined: that drain is the ordinary-flow seam
  that discovers the rollout ID before native stable-item mapping, and no image
  ordering regression was demonstrated.
- **Step 5 cleanup:** The duplicate native `exec-*` file-change presentation is
  no longer emitted for correlated patches. No additional obsolete persisted,
  transport, cache, flag, listener, or compatibility state was found.
- **Step 5 change size:** 342 lines against the PR merge base, including
  production code, focused tests, and tracker updates. This is below the
  1,500-line soft cap.
- **Step 5 delivery:** Pushed and opened as
  [PR #740](https://github.com/sesori-ai/sesori_apps_monorepo/pull/740), which
  passed all 11 checks and merged as `b4455593` on 2026-08-04 with zero
  unresolved threads.
- **Step 6 base update:** Merged the complete local D5 branch forward as
  `f06aa211`, then merged `origin/main` at `b4455593` as `0232ffc2`. Existing
  production commit `8f0f4ece` remains in its original stack position; no
  rebase, reset, reorder, or cherry-pick occurred.
- **Step 6 production verification:** The 136 focused rollout, session-service,
  lifecycle-tracker, and write-path tests pass, as do all 310 Codex package
  tests. `dart analyze --fatal-infos` reports no issues. Both branch and
  working-tree `git diff --check` pass.
- **Step 6 architecture review:** `aristotle-impl-review` approved the branch
  against `origin/main` with no findings. It confirmed the plugin, service,
  repository, and tracker ownership flow remains cohesive and proportional. A
  follow-up review rejected an initial callback-based activity recheck because
  it reversed the plugin-to-service dependency; the correction instead splits
  durable history preparation from synchronous projection so the plugin reads
  its own activity only after the service await, without a lower-layer callback.
- **Step 6 behavior:** Replay snapshots the rollout and persisted outcomes,
  yields queued app-server activity, then resolves current plugin activity
  before projection. Confirmed-idle history terminalizes unresolved rollout
  tools and image generations from every chronology segment as errors, while
  active, provisional, retry-backed, or activity-unknown sessions preserve
  running state. The prepared service context is opaque and immutable to its
  plugin caller.
- **Step 6 cleanup:** No persistence, transport, cache, or lifecycle artifact
  becomes obsolete in this step. The temporary `PluginSessionStatus` replay
  boundary is intentionally replaced by Step 8's sealed replay disposition.
- **Step 6 change size:** 380 lines against the PR merge base, including
  production code, tests, and tracker updates. This is below the 1,500-line
  soft cap.
- **Step 6 delivery:** PR
  [#743](https://github.com/sesori-ai/sesori_apps_monorepo/pull/743)
  merged as `4b779cc2` on 2026-08-04 with all checks passing and zero
  unresolved threads.
- **Step 7 base update:** Merged the complete local D6 branch forward as
  `663aed74`, then merged `origin/main` at `0c950221` as `d070b16b`. Existing
  production commit `cdd3a305` remains in its original stack position; no
  rebase, reset, reorder, or cherry-pick occurred.
- **Step 7 production verification:** The focused archive write-path regression
  and all 311 Codex package tests pass. `dart analyze --fatal-infos` reports no
  issues. The stability report is consistent with the merged PR series, and
  `git diff --check` passes.
- **Step 7 behavior:** Codex archive is intentionally bridge-local and does not
  send `thread/archive`, so archived sessions retain readable rollout history
  and can be unarchived without a missing backend callback. Delete remains the
  explicit destructive operation.
- **Step 7 cleanup:** The obsolete Codex backend archive request is removed. No
  persistence, transport, schema, cache, or client artifact becomes obsolete.
- **Step 7 review feedback:** At explicit owner request, the disabled backend
  archive request remains as commented reference code. The evidence report now
  scopes its completion claim to the original matrix and keeps F-12 visibly open.
- **Step 7 change size:** 384 lines against the PR merge base, including the
  production fix, focused test, completed evidence report, and tracker updates.
  This is below the 1,500-line soft cap.
- **Step 7 delivery:** PR
  [#746](https://github.com/sesori-ai/sesori_apps_monorepo/pull/746)
  merged as `4785f4c7` on 2026-08-04 with all checks passing. Its remaining
  unresolved thread is the human-owned archive-code retention request that was
  implemented and replied to before merge.
- **Step 8 successor update:** Merged the complete local Step 7 branch forward
  as `524d2902`, merged its review follow-up as `8a5f3506`, then merged
  `origin/main` at `4785f4c7` as `61511618`. Existing production commit
  `d4e30b87` remains in its original stack position; no rebase, reset, reorder,
  or cherry-pick occurred.
- **Step 8 verification:** Typed command/file parser, mapper, repository,
  service, tracker, outcome, rollout, and write-path coverage passes, as do all
  315 Codex package tests. `dart analyze --fatal-infos` and `git diff --check`
  pass. Code generation completed with zero changed outputs.
- **Step 8 architecture review:** `aristotle-impl-review` approved the merged
  Step 8 scope with no findings. It confirmed typed parser ownership,
  service-owned replay policy, dependency direction, and cohesion.
- **Step 8 merge correction:** Typed late-completion handling now checks the
  retained canonical-tool store before active thread state and preserves late
  aggregated output. Existing late-abort regressions caught and verify this
  correction.
- **Step 8 cleanup:** Raw command/file item interpretation is removed from the
  lifecycle tracker. No wire, database, cache, or client artifact is obsolete.
- **Step 8 change size:** 1,174 lines against the PR merge base, including
  generated typed models, production code, tests, report, and tracker updates.
  This is below the 1,500-line soft cap.
- **Step 8 delivery:** Pushed and opened as
  [PR #749](https://github.com/sesori-ai/sesori_apps_monorepo/pull/749).
- **Step 8 merge:** PR
  [#749](https://github.com/sesori-ai/sesori_apps_monorepo/pull/749)
  merged as `22f65807` on 2026-08-04 with all checks passing and no unresolved
  threads.
- **Step 9 successor update:** Merged the complete local Step 8 branch forward
  as `3096c2db`, then merged `origin/main` at `22f65807` as `078a3dc1`.
  Existing production commit `ef2356c4` remains in its original stack position;
  no rebase, reset, reorder, or cherry-pick occurred.
- **Step 9 verification:** Shared and client code generation completed with zero
  changed outputs. Fatal analysis passes in shared, plugin interface, OpenCode,
  Codex, bridge foundation, bridge app, client core, and mobile. Full-suite runs
  passed all 360 shared, 149 plugin-interface, 409 OpenCode, 316 Codex, 66
  bridge-foundation, 2,429 bridge-app, and 1,008 client-core tests. After the
  final reconnect fence, 33 focused client-core and 43 mobile cubit tests pass.
  The report also retains the completed real-iOS image-selection and submission
  evidence.
- **Step 9 architecture review:** The first review found that a pre-disconnect
  silent refresh could restore old attachment capability after reconnect; the
  second found the equivalent full-load/recovery path. Both paths now fence
  capability-bearing snapshots by connection generation and require a fresh
  current-connection load before queued images drain. Focused regressions cover
  both races. After the second rejection, the owner selected fix-and-verify
  without a prohibited third review.
- **Step 9 analytics:** The accepted session-message outcome remains the
  authoritative existing event. No image-, provider-, or plugin-specific event
  or parameter was added.
- **Step 9 cleanup:** The hardcoded composer attachment-support helper is
  removed. No database or cache artifact is obsolete.
- **Step 9 change size:** 965 lines against the PR merge base, including the
  compatible wire model, bridge/plugin/client flow, tests, report, and tracker.
  This is below the 1,500-line soft cap.
- **Step 9 delivery:** Pushed and opened as
  [PR #751](https://github.com/sesori-ai/sesori_apps_monorepo/pull/751), which
  passed 15/15 checks and merged as `5a67ee65` on 2026-08-04. Review follow-ups
  preserved legacy OpenCode compatibility, retained staged images while
  capability is unresolved, fenced stale load failures, validated Codex inline
  image payloads, and kept the declined capability-cache thread open with its
  rationale.
- **Step 10 successor update:** Branched directly from the pushed Step 9 head,
  then merged `origin/main` at `5a67ee65` forward as `038d2271`. Merge
  conflicts retained the newer Step 9 review fixes while preserving the Step 10
  projection change; no rebase, reset, reorder, or cherry-pick occurred.
- **Step 10 sanitized shape:** Confirmed the privacy-safe runtime structure as
  an exact `# AGENTS.md instructions` header with an optional `for <directory>`
  suffix, one blank line, and a complete `<INSTRUCTIONS>` envelope.
- **Step 10 verification:** The regression failed before `2e534673`, then passed.
  After the Step 9 merge, all 318 Codex tests, `dart analyze --fatal-infos`,
  and `git diff --check` pass.
  Tests preserve submitted exact envelopes, casing near matches, incomplete
  markers, mixed authored text, path/no-path forms, and outer whitespace.
- **Step 10 scope:** Classification stays inside `CodexMessageRepository` at the
  existing cold-history projection boundary. No live/cold coordination,
  architecture change, wire change, database change, or analytics change was
  required, so no implementation architecture review applies.
- **Step 10 cleanup:** Stored Codex rollouts remain untouched; only generated history projection changes. No artifact is obsolete.
- **Step 10 change size:** 157 lines against merged `main`, including production
  code, regression coverage, report, and tracker updates. This modestly exceeds
  the planned 70-140 line estimate and remains far below the 1,500-line cap.

## Findings And Plan Deltas

- **2026-08-04 — First PR scope:** User selected the first unmerged deep-test
  fix rather than rebuilding already-merged F-01 history. Step 1 combines the
  plan/tracker with D1 `c3ab5fcb`.
- **2026-08-04 — Stack order:** User required plan delivery steps to match the
  existing stacked branches exactly. D1 through D9 remain Steps 1 through 9.
- **2026-08-04 — Remaining findings:** Confirmed F-12 is added after D9 and must
  be fixed inside this plan. The separately owned relay-version defect is not
  duplicated here.
- **2026-08-04 — Finding traceability:** Because historical findings do not map
  one-to-one to the remaining branches, the plan keeps an independent F-01
  through F-12 acceptance ledger alongside the PR delivery sequence.
- **2026-08-04 — Wrapper parser boundary:** The owner accepted bounded behavior
  for unobserved regex-literal, template-interpolation, and malformed-delimiter
  wrapper shapes; no broader JavaScript tokenizer is planned without new runtime
  evidence.
- **2026-08-04 — Automatic continuation:** After every merge notification,
  proceed immediately with the next numbered step without another user prompt;
  stop only for a material decision or blocker.
- **2026-08-04 — Code-mode fallback ordering:** Preserve direct rollout command
  correlation ahead of the custom code-mode fallback. A shared FIFO would let
  an outer custom wrapper claim the app-server item before its authoritative
  direct rollout call; no ordinary-flow evidence justifies that regression to
  protect a theoretical mixed-form ordering case.
- **2026-08-04 — Step 4 lifecycle simplification:** After review patches began
  coupling retained aliases to thread-wide active/pending state, the owner chose
  a per-item retained-command lifecycle. No retention boolean, activity scan,
  lock, timeout, or cross-layer registry remains.
