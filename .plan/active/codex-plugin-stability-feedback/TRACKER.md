# Codex Plugin Stability Feedback: Tracker

## Current State

- **Plan slug:** `codex-plugin-stability-feedback`
- **Implementation base:** `origin/main` at
  `009bb44a72683d0a1bc6dacd13cbc19397e92d43`
- **Stack root:** `2408b574`
- **Series state:** Historical F-01 through F-07 baseline PRs merged; remaining
  D1 through D9 branches exist and are pushed; Step 1 PR
  [#724](https://github.com/sesori-ai/sesori_apps_monorepo/pull/724) is open
- **Current step:** Step 1/11
- **Current branch:** `codex-stability-deep-test-1-image-wrapper-directive`
- **Plan PR:** [#724](https://github.com/sesori-ai/sesori_apps_monorepo/pull/724),
  combined with Step 1 production fix by user direction
- **Next action:** Monitor Step 1 CI and review; merge it before forwarding D1
  into D2

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
| [ ] | F-02 shell identity | Direct path fixed; code-mode fix stacked | `codex-stability-3-tool-identity`; [#712](https://github.com/sesori-ai/sesori_apps_monorepo/pull/712); `e5cb9d86` | Step 2 adds `58585e1f` and proves one code-mode ID |
| [x] | F-03 interrupted history | Fixed on `main` | `codex-stability-4-tool-lifecycle`; [#713](https://github.com/sesori-ai/sesori_apps_monorepo/pull/713); `f70bdbcb` | Preserve terminal replay regressions |
| [x] | F-04 prompt image history | Fixed on `main` | `codex-stability-5-prompt-images`; [#715](https://github.com/sesori-ai/sesori_apps_monorepo/pull/715); `6930b3a9` | Preserve stable text/file replay regressions |
| [x] | F-05 debug SSE UTF-8 | Fixed on `main` | `codex-stability-1-debug-sse`; [#709](https://github.com/sesori-ai/sesori_apps_monorepo/pull/709); `025ba43b` | Preserve same-connection UTF-8 regression |
| [x] | F-06 failed tool replay | Fixed on `main` | `codex-stability-6-failed-tool-status`; [#717](https://github.com/sesori-ai/sesori_apps_monorepo/pull/717); `20521cc2` | Preserve error/output/exit-code replay |
| [ ] | F-07 generated image convergence | Durable history fixed; wrappers stacked | `codex-stability-7-image-generation-history`; [#718](https://github.com/sesori-ai/sesori_apps_monorepo/pull/718); `2408b574` | Steps 1 and 3 deliver `c3ab5fcb` and `36ee48e9` |
| [ ] | F-08 late abort identity | Fixed on stack | D4; `a32b6c29` | Step 4 proves late completion updates the failed card |
| [ ] | F-09 file identity | Fixed on stack | D5 `9da8f2e1`; D8 `d4e30b87` | Steps 5 and 8 deliver behavior and typed boundary |
| [ ] | F-10 restart terminalization | Fixed on stack | D6 `8f0f4ece`; D8 `d4e30b87` | Steps 6 and 8 deliver behavior and service-owned policy |
| [ ] | F-11 archive history | Fixed on stack | D7; `cdd3a305` | Step 7 proves archive/unarchive readable and delete destructive |
| [ ] | F-12 generated repository instructions | Confirmed; not fixed | Documented on D9 `ef2356c4` | Step 10 must hide complete generated AGENTS envelopes without hiding authored text |

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [ ] | 1/11 | `codex-stability-deep-test-1-image-wrapper-directive` | `🌿 [codex-plugin-stability-feedback] fix(codex): recognize directed image wrappers [step 1/11]` | 844 actual | [PR #724](https://github.com/sesori-ai/sesori_apps_monorepo/pull/724) open; verified; D1 merged current `origin/main` forward at `636546f6` |
| [ ] | 2/11 | `codex-stability-deep-test-2-code-mode-tool-identity` | `⚙️ [codex-plugin-stability-feedback] fix(codex): unify code-mode command identity [step 2/11]` | 73 | Existing `58585e1f`; blocked on Step 1 merge-forward |
| [ ] | 3/11 | `codex-stability-deep-test-3-image-wrapper-projection` | `⚙️ [codex-plugin-stability-feedback] fix(codex): hide generated image wrappers [step 3/11]` | 118 | Existing `36ee48e9`; blocked on Step 2 |
| [ ] | 4/11 | `codex-stability-deep-test-4-late-abort-tool-identity` | `⚙️ [codex-plugin-stability-feedback] fix(codex): retain late command identity after abort [step 4/11]` | 86 | Existing `a32b6c29`; blocked on Step 3 |
| [ ] | 5/11 | `codex-stability-deep-test-5-file-tool-identity` | `⚙️ [codex-plugin-stability-feedback] fix(codex): unify file change identity [step 5/11]` | 214 | Existing `9da8f2e1`; blocked on Step 4 |
| [ ] | 6/11 | `codex-stability-deep-test-6-restart-tool-terminalization` | `⚙️ [codex-plugin-stability-feedback] fix(codex): settle interrupted tools after restart [step 6/11]` | 70 | Existing `8f0f4ece`; blocked on Step 5 |
| [ ] | 7/11 | `codex-stability-deep-test-7-local-archive-history` | `🌿 [codex-plugin-stability-feedback] fix(codex): preserve locally archived history [step 7/11]` | 308 | Existing `cdd3a305` + `c4767b04`; blocked on Step 6 |
| [ ] | 8/11 | `codex-stability-deep-test-8-typed-boundaries` | `🚧 [codex-plugin-stability-feedback] refactor(codex): type replay and item boundaries [step 8/11]` | 1,084 | Existing `d4e30b87` + `e86bb66f`; blocked on Step 7 |
| [ ] | 9/11 | `codex-stability-deep-test-9-mobile-images` | `🚧 [codex-plugin-stability-feedback] feat(codex): support mobile image prompts [step 9/11]` | 707 | Existing `ef2356c4`; blocked on Step 8 |
| [ ] | 10/11 | `codex-plugin-stability-feedback-f12-generated-repository-instructions` | `🌿 [codex-plugin-stability-feedback] fix(codex): hide generated repository instructions [step 10/11]` | 70–140 | Planned after D9; confirmed F-12 fix |
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
- **Step 1 change size:** 844 lines against `origin/main`: 815 plan/tracker
  additions plus 27 production/test additions and 2 deletions. This is below the
  1,500-line soft cap.
- **Step 1 delivery:** Plan/tracker committed as `d3ec1923`, pushed, and opened
  as [PR #724](https://github.com/sesori-ai/sesori_apps_monorepo/pull/724).

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
