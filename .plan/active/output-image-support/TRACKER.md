# Output Image Support: Tracker

## Current State

- **Plan slug:** `output-image-support`
- **Implementation base:** `origin/main` at
  `e64fb4b5d6daeee55447efdf0177318daece5932`
- **Series state:** Step 10/13 merged as [PR #666](https://github.com/sesori-ai/sesori_apps_monorepo/pull/666)
- **Current step:** Step 11/13 — [PR #670](https://github.com/sesori-ai/sesori_apps_monorepo/pull/670) open; local review fixes verified
- **Plan PR:** [#638](https://github.com/sesori-ai/sesori_apps_monorepo/pull/638)
- **Next action:** review and publish the local PR feedback fixes

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
| [x] | 6/13 | `output-image-support-codex-live-images` | `[output-image-support] feat(codex): surface live output images [step 6/13]` | 900-1,400 | [PR #652](https://github.com/sesori-ai/sesori_apps_monorepo/pull/652) merged as `737226d8`; 830 changed lines |
| [x] | 7/13 | `output-image-support-codex-image-history` | `[output-image-support] feat(codex): restore output image history [step 7/13]` | 1,100-1,500 | [PR #657](https://github.com/sesori-ai/sesori_apps_monorepo/pull/657) merged as `4ca1cb90`; 589 changed lines |
| [x] | 8/13 | `output-image-support-acp-content-blocks` | `[output-image-support] refactor(acp): type content blocks [step 8/13]` | 1,300-1,500 | [PR #658](https://github.com/sesori-ai/sesori_apps_monorepo/pull/658) merged as `a973796c`; 1,119 changed lines |
| [x] | 9/13 | `output-image-support-acp-content-mapping` | `[output-image-support] refactor(acp): centralize tool content mapping [step 9/13]` | 1,100-1,500 | [PR #661](https://github.com/sesori-ai/sesori_apps_monorepo/pull/661) merged as `f5f24240`; 879 changed lines |
| [x] | 10/13 | `output-image-support-acp-message-images` | `[output-image-support] feat(acp): surface live message images [step 10/13]` | 1,100-1,500 | [PR #666](https://github.com/sesori-ai/sesori_apps_monorepo/pull/666) merged as `e64fb4b5`; 1,138 changed lines |
| [ ] | 11/13 | `output-image-support-acp-tool-images` | `⚙️ [output-image-support] feat(acp): surface live tool images [step 11/13]` | 1,200-1,500 | [PR #670](https://github.com/sesori-ai/sesori_apps_monorepo/pull/670) open; local review fixes verified |
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
11. `⚙️ [output-image-support] feat(acp): surface live tool images [step 11/13]`
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
  passive rendering without an authoritative action. PR #652 merged as
  `737226d8` on 2026-07-31.
- Step 7/13 (2026-07-31): typed persisted image-generation records and routed
  first-class plus tool-output images through the shared Codex attachment
  mapper into rollout enrichment and history. Stable identified and id-less
  fallback replay IDs, live/history attachment convergence, and preservation
  across later smaller app-server updates have focused coverage. Codex codegen,
  focused tests, all 231 package tests, `dart pub get`,
  `dart analyze --fatal-infos`, and `git diff --cached --check` pass.
  `aristotle-impl-review` approved the architecture with no findings. The 589
  changed-line diff is below the 1,500-line soft cap; no neighboring scope was
  combined. PR review follow-up named the repository's local helper parameters
  and exposed only `status`/`result` field names in schema-only malformed-image
  diagnostics; all 37 rollout tests and fatal analysis pass. Missing required
  image fields remain malformed rather than creating an invalid partial item.
  PR #657 merged as `4ca1cb90` on 2026-07-31.
- Step 8/13 (2026-07-31): generated typed ACP text, image, known-unsupported,
  and unknown content blocks; added the stateless ACP content mapper; and wired
  one explicit policy through live, plugin, replay, and Cursor composition.
  Live/replay text behavior remains unchanged while individual image MIME,
  base64, size, and basename-only URI metadata are validated without
  materializing image parts before the tracker step. ACP codegen, focused
  mapper/live/replay tests, all 165 ACP tests, all 108 Cursor tests,
  `dart pub get`, fatal analysis in both packages, and
  `git diff --cached --check` pass. `aristotle-impl-review` approved with no
  findings. The 1,119 changed-line diff is below the 1,500-line soft cap; no
  neighboring scope was combined. PR review restored the prior fail-soft text
  fallback for untyped, future, and nested-wrapper maps after known typed
  variants are considered; all 69 focused ACP tests, 7 Cursor mapper tests, and
  fatal analysis in both packages pass. A second bot review hardened filename
  derivation to supported hierarchical `file`, `http`, and `https` URIs only;
  all 7 mapper tests and fatal ACP analysis pass. PR #658 merged as `a973796c`
  on 2026-08-01.
- Step 9/13 (2026-08-01): generated typed ACP tool content, diff, terminal,
  and unknown variants; moved tool identity, status, text/raw-output clipping,
  and diff policy into `AcpContentMapper`; routed live and replay tool paths
  through the same mapped result; and deleted the superseded root
  `acp_content.dart`. Images and terminals remain unmaterialized. ACP codegen,
  all 73 focused mapper/live/replay tests, all 171 ACP tests, all 108 Cursor
  tests, `dart pub get`, fatal analysis in both packages, and
  `git diff --cached --check` pass. `aristotle-impl-review` approved with no
  findings. The 879 changed-line diff is below the 1,500-line soft cap; no
  neighboring scope was combined. PR review refreshed the tracker state and
  made output clipping Unicode-safe without changing the established diff
  timing; all 73 focused ACP tests, 7 Cursor mapper tests, and fatal analysis in
  both packages pass. PR #661 merged as `f5f24240` on 2026-08-01.
- Step 10/13 (2026-08-01): added the zero-collaborator `AcpContentTracker` and
  adopted its ordered text/image mutations in live and replay assistant message
  flows. Live standard ACP images now materialize as bounded file parts while
  replay records the same segmentation and budgets without image parts until
  Step 12. Mixed order, stable suffixes, count/aggregate limits, privacy-safe
  warning deduplication, message/turn identity, id-less tool boundaries, halt
  behavior, and Cursor standard-versus-extension behavior have focused coverage.
  Initial verification included the focused ACP suite, all 179 ACP tests, all
  109 Cursor tests, `dart pub get`, fatal analysis in both packages, and
  `git diff --cached --check` pass. `aristotle-impl-review` approved with no
  findings. Analytics remain excluded because passive image rendering has no
  authoritative user action or product-decision event. PR review added
  message-scoped malformed-warning deduplication, skips unrenderable replay
  drafts, stores payload-free replay image boundaries until Step 12, and aligned
  new helper signatures with named-parameter rules. A second architecture pass
  found replay was not sharing that mapping scope; replay now retains a pending
  tracker scope without creating a draft until renderable content arrives.
  Further review also made explicit messages close prior id-less envelopes, limited
  atomic live halt recognition to id-less backend notices that cannot receive a
  later image chunk, and tracks text-only versus mixed composition symmetrically
  for replay halt decisions. The latest review also made malformed replay
  discriminators fail-soft, keeps identified halt-like messages as assistant
  content in both live and replay, and resets unrendered id-less tracker state at
  message boundaries. All 90 focused ACP tests, 8 Cursor mapper tests, and fatal
  analysis in both packages pass. The 1,138 changed-line diff is below the
  1,500-line soft cap; no neighboring scope was combined. PR #666 merged as
  `e64fb4b5` on 2026-08-01.
- Step 11/13 (2026-08-01): added the zero-collaborator
  `AcpToolContentTracker`; changed `AcpContentMapper` to emit sealed replace,
  update-output, and unchanged mutations; and made both `_LiveTool` and
  replay `_ToolDraft` retain and apply that tracker. Live tool cards now render
  bounded standard ACP image attachments, while replay retains the same
  normalized final attachment state but deliberately renders none until Step
  12. Omission preservation, complete replacement, empty clearing, image-only
  replacement, raw-output fallback, count/aggregate limits, privacy-safe
  degradation, and one-shot diff signaling have focused coverage. All 199 ACP
  tests and all 109 Cursor tests pass; fatal analysis passes in both packages;
  `aristotle-impl-review` approved with no findings. No code generation was
  required. PR #670 review found four valid root issues across eight duplicate
  bot threads: reordered late `tool_call`s now retain newer live/replay content,
  status, and diff state while filling missing metadata; tool mapping stops
  normalizing image candidates after the four-item prefix while still scanning
  trailing text/diff entries; explicit non-terminal diff content now waits for
  completion while retaining the mutation; and unused tool snapshot counters
  were removed. The diff fix preserves PR #414's later `7b2d21dc` exception for
  explicit diff content with no known status after `952cc30f` introduced terminal
  gating. The five new regressions failed before the fixes. All 204 ACP
  tests and all 109 Cursor tests pass, fatal analysis passes in both packages,
  and `git diff --check` passes. Follow-up review centralized the shared
  four-image candidate limit; the status-less diff exception remains unchanged
  because it is established compatibility behavior for backends that provide no
  later status event. Malformed raw-output-only updates now preserve prior tool
  state while explicit empty output still clears it. The final 1,364-line PR diff
  is below the 1,500-line soft cap; no neighboring scope was combined.

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
