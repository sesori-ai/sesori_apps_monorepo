# Output Image Support: Tracker

## Current State

- **Plan slug:** `output-image-support`
- **Implementation base:** `origin/main` at
  `9d2c1e9e79ab80fa8824b9d803a74798eb71140d`
- **Series state:** Step 6/13 ready for PR
- **Current step:** Step 6/13 — surface live Codex images
- **Plan PR:** [#638](https://github.com/sesori-ai/sesori_apps_monorepo/pull/638)
- **Next action:** open and monitor the Step 6/13 PR

## Plan Review

- **Verdict:** earlier drafts rejected with actionable findings; all findings
  applied directly; corrected plan not re-reviewed merely for approval
- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-07-31
- **Reviewed scope:** in-chat Codex/ACP architecture and multi-PR delivery drafts
- **Applied corrections:** sealed rollout state, typed app-server boundary,
  API/repository/tracker separation, explicit composition, one ACP tool-content
  policy, immediate production consumers, and symmetric live/replay tracker
  adoption

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [x] | 1/13 | `investigate-opencode-image-support` | `[output-image-support] docs: plan output image support [step 1/13]` | 450-700 | [PR #638](https://github.com/sesori-ai/sesori_apps_monorepo/pull/638) merged as `bfadd097` |
| [x] | 2/13 | `output-image-support-codex-rollout-content` | `[output-image-support] refactor(codex): seal rollout content [step 2/13]` | 1,200-1,500 | [PR #639](https://github.com/sesori-ai/sesori_apps_monorepo/pull/639) merged as `17e0ecf1`; 680 changed lines |
| [x] | 3/13 | `output-image-support-codex-rollout-envelopes` | `[output-image-support] refactor(codex): seal rollout envelopes [step 3/13]` | 900-1,350 | [PR #644](https://github.com/sesori-ai/sesori_apps_monorepo/pull/644) merged as `f78e1f69`; 1,075 changed lines |
| [x] | 4/13 | `output-image-support-codex-response-items` | `[output-image-support] refactor(codex): seal response items [step 4/13]` | 1,100-1,500 | [PR #646](https://github.com/sesori-ai/sesori_apps_monorepo/pull/646) merged as `4be1e7bb`; 1,416 changed lines |
| [x] | 5/13 | `output-image-support-codex-image-events` | `[output-image-support] refactor(codex): type image-bearing events [step 5/13]` | 1,200-1,500 | [PR #648](https://github.com/sesori-ai/sesori_apps_monorepo/pull/648) merged as `e9a03363`; 1,472 changed lines |
| [ ] | 6/13 | `output-image-support-codex-live-images` | `[output-image-support] feat(codex): surface live output images [step 6/13]` | 900-1,400 | Ready for PR; 830 changed lines |
| [ ] | 7/13 | `output-image-support-codex-image-history` | `[output-image-support] feat(codex): restore output image history [step 7/13]` | 1,100-1,500 | Blocked on Step 6 merge |
| [ ] | 8/13 | `output-image-support-acp-content-blocks` | `[output-image-support] refactor(acp): type content blocks [step 8/13]` | 1,300-1,500 | Blocked on Step 7 merge |
| [ ] | 9/13 | `output-image-support-acp-content-mapping` | `[output-image-support] refactor(acp): centralize tool content mapping [step 9/13]` | 1,100-1,500 | Blocked on Step 8 merge |
| [ ] | 10/13 | `output-image-support-acp-message-images` | `[output-image-support] feat(acp): surface live message images [step 10/13]` | 1,100-1,500 | Blocked on Step 9 merge |
| [ ] | 11/13 | `output-image-support-acp-tool-images` | `[output-image-support] feat(acp): surface live tool images [step 11/13]` | 1,200-1,500 | Blocked on Step 10 merge |
| [ ] | 12/13 | `output-image-support-acp-image-replay` | `[output-image-support] feat(acp): restore output image replay [step 12/13]` | 900-1,400 | Blocked on Step 11 merge |
| [ ] | 13/13 | `output-image-support-retire-plan` | `[output-image-support] docs: retire output image support plan [step 13/13]` | 50-200 | Blocked on Step 12 merge |

## Exact PR Titles

1. `[output-image-support] docs: plan output image support [step 1/13]`
2. `[output-image-support] refactor(codex): seal rollout content [step 2/13]`
3. `[output-image-support] refactor(codex): seal rollout envelopes [step 3/13]`
4. `[output-image-support] refactor(codex): seal response items [step 4/13]`
5. `[output-image-support] refactor(codex): type image-bearing events [step 5/13]`
6. `[output-image-support] feat(codex): surface live output images [step 6/13]`
7. `[output-image-support] feat(codex): restore output image history [step 7/13]`
8. `[output-image-support] refactor(acp): type content blocks [step 8/13]`
9. `[output-image-support] refactor(acp): centralize tool content mapping [step 9/13]`
10. `[output-image-support] feat(acp): surface live message images [step 10/13]`
11. `[output-image-support] feat(acp): surface live tool images [step 11/13]`
12. `[output-image-support] feat(acp): restore output image replay [step 12/13]`
13. `[output-image-support] docs: retire output image support plan [step 13/13]`

## Execution Rules

- Merge in numeric order. A successor may target its immediate predecessor while
  both are open, but each step must remain independently buildable and valid.
- After a PR merges, continue automatically with the next numbered step without
  waiting for another user prompt. Stop only for a material decision or blocker.
- Count additions plus deletions, including generated files and tests, against
  each PR base. Target no more than 1,500 changed lines per PR as a soft cap;
  split coherently first or record why an expected overage is unavoidable.
- Do not merge adjacent steps merely because one is small.
- Stop and update this plan before opening a PR that cannot fit its budget
  without separating required generated output, constructor callers, production
  behavior, or meaningful tests.
- Every production parser, mapper, and tracker must have a production consumer
  when introduced.
- Live and replay adopt shared ACP policy/state in the same PR even when replay
  image rendering is materialized only in Step 12.
- Generated files are regenerated, never hand-edited.
- Run focused tests, owning-package full tests, `dart analyze --fatal-infos`,
  `git diff --check`, and architecture implementation review as declared in
  `PLAN.md` for each implementation step.

## Verification Log

- Step 1/13 (2026-07-31): plan and tracker authored; fixed slug, thirteen titles,
  lifecycle boundaries, delivery order, and changed-line estimates
  cross-checked. The original staged diff was 581 changed lines and
  `git diff --cached --check` passed. Committed as
  `3cc4881e`, pushed, and opened as
  [PR #638](https://github.com/sesori-ai/sesori_apps_monorepo/pull/638). The PR
  now also codifies the requested Plan Maker lifecycle and 1,500-line soft-cap
  rules; its current diff is 617 changed lines and `git diff --check` passes. No
  Dart or Flutter suites were run for this documentation-only step. PR #638
  merged as `bfadd097` on 2026-07-31.
- Step 2/13 (2026-07-31): sealed rollout content into required text, image, and
  unknown variants; moved the rollout tool mapper into the repository mapping
  layer; and wired one instance from the production composition root into live
  and history consumers. Codex codegen, focused tests, all 210 package tests,
  `dart pub get`, `dart analyze --fatal-infos`, and `git diff --cached --check`
  pass. `aristotle-impl-review` approved the staged architecture with no
  findings. Commit `3b18da2d` was opened as [PR #639](https://github.com/sesori-ai/sesori_apps_monorepo/pull/639).
  The 680-line diff is below the 1,500-line soft cap; no neighboring scope was combined. PR #639
  merged as `17e0ecf1` on 2026-07-31.
- Step 3/13 (2026-07-31): sealed the outer rollout envelope into session
  metadata, turn context, response item, compacted, and unknown variants;
  retained the existing response-item payload representation for Step 4; and
  migrated catalog, tailer, live-event, and history consumers atomically. Codex
  codegen, focused structural/catalog/tailer/mapper/repository tests, all 211
  package tests, `dart pub get`, `dart analyze --fatal-infos`, and
  `git diff --cached --check` pass. `aristotle-impl-review` approved the staged
  architecture with no findings. The 1,075-line diff is within the 900-1,350
  target and below the 1,500-line soft cap; no neighboring scope was combined.
  PR #644 merged as `f78e1f69` on 2026-07-31.
- Step 4/13 (2026-07-31): sealed response items into message, reasoning,
  function/custom call and output, web-search, and unknown variants; migrated
  tool and history consumers to exhaustive patterns; and kept image generation
  unknown until Step 7. Codex codegen, focused DTO/mapper/history/tailer tests,
  all 213 package tests, `dart pub get`, `dart analyze --fatal-infos`, and
  `git diff --cached --check` pass. `aristotle-impl-review` approved the staged
  architecture with no findings. The 1,416-line diff is within the 1,100-1,500
  target and below the 1,500-line soft cap; no neighboring scope was combined.
  PR #646 merged as `4be1e7bb` on 2026-07-31.
- Step 5/13 (2026-07-31): added generated app-server variants and a
  zero-collaborator parser for image generation plus MCP/dynamic text, image,
  and audio content; migrated existing MCP/dynamic text/status/error mapping;
  and kept all image behavior unrendered for Step 6. Codex codegen, focused
  parser/event tests, all 218 package tests, `dart pub get`,
  `dart analyze --fatal-infos`, and `git diff --cached --check` pass. The first
  architecture review moved output projection back to the event mapper; the
  second `aristotle-impl-review` pass approved with no findings. The 1,472-line
  diff is below the 1,500-line soft cap; no neighboring scope was combined. PR
  #648 merged as `e9a03363` on 2026-07-31.
- Step 6/13 (2026-07-31): added the bounded Codex image attachment mapper and
  surfaced stable first-class generation, MCP, and dynamic live image tool
  attachments while preserving text, errors, statuses, and rollout enrichment.
  Count, decoded-byte, MIME, base64, metadata fallback, basename, privacy-log,
  remote/local, audio, and `imageView` policies have focused coverage. All 229
  package tests, `dart pub get`, `dart analyze --fatal-infos`, and
  `git diff --cached --check` pass. `aristotle-impl-review` approved the staged
  architecture and security boundaries with no findings. The 830-line diff is
  below the 1,500-line soft cap. Analytics remain excluded because this is
  passive rendering without an authoritative action.

## Findings And Plan Deltas

- **2026-07-31 — Automatic continuation:** After each merged PR, proceed with
  the next numbered step without waiting for another explicit user request.
- **2026-07-31 — Lifecycle and line budget:** Set a 1,500 changed-line soft cap,
  retained plan delivery as Step 1/13, kept the eleven implementation boundaries
  as Steps 2/13 through 12/13, and added plan retirement as Step 13/13.
- **2026-07-31 — PR-size split:** Split the high-churn Codex rollout refactor
  into content, outer-envelope, and inner-response-item steps. Kept ACP DTO,
  message-state, tool-state, and replay materialization boundaries separate.
- **2026-07-31 — Split review corrections:** Ensured the Codex app-server parser
  and ACP mapper are production-consumed when introduced; made replay adopt the
  assistant tracker in the live-message step and the tool tracker in the
  live-tool step, leaving only replay materialization for the final
  implementation PR.
