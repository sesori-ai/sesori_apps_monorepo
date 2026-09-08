# Antigravity ACP Harness Tracker

## Current State

- **Plan:** `.plan/active/antigravity-harness/PLAN.md`
- **Status:** Steps 1–10.c merged; Step 10.d architecture-approved, publication prepared
- **Base:** synced with main `4fdd433392eabde75f1d800b649337206f057421` after Step 10.c merge
- **Current branch:** `antigravity-harness-step-10d-managed-install`
- **Merged PRs:** [#1285](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1285) (Step 1),
  [#1286](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1286) (Step 2),
  [#1287](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1287) (Step 3),
  [#1288](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1288) (Step 4),
  [#1291](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1291) (Step 5),
  [#1347](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1347) (Step 6.a),
  [#1348](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1348) (Step 6.b),
  [#1350](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1350) (Step 6.c),
  [#1351](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1351) (Step 6.d),
  [#1353](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1353) (Step 7.a),
  [#1354](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1354) (Step 7.b),
  [#1357](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1357) (Step 7.c),
  [#1359](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1359) (Step 8.a),
  [#1360](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1360) (Step 8.b),
  [#1367](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1367) (Step 8.c),
  [#1373](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1373) (Step 9),
  [#1376](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1376) (Step 10.a)
- **Merged PR:** [#1380](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1380) (Step 10.b). At the terminal
  report, 15/16 checks were complete with clean Cubic approval; Codex review was still running, so no 16/16 claim is made.
- **Merged PR:** [#1384](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1384) (Step 10.c); terminal report
  had 15/16 checks complete, with clean Cubic approval and no actionable Codex feedback.
- **Open PR:** Step 10.d publication prepared.
- **Next action:** publish and monitor Step 10.d; begin Step 11 guidance locally.

## Fixed PR Series

- [x] Step 1/12 — `🌱 [antigravity-harness] docs: plan Antigravity ACP support [step 1/12]`
- [x] Step 2/12 — `⚙️ [antigravity-harness] feat(antigravity): pin the official ACP runtime contract [step 2/12]`
- [x] Step 3/12 — `⚙️ [antigravity-harness] feat(antigravity): resolve local runtime pairs [step 3/12]`
- [x] Step 4/12 — `🚧 [antigravity-harness] feat(auth): accept browser authentication continuations [step 4/12]`
- [x] Step 5/12 — `🚧 [antigravity-harness] feat(client): add remote browser authentication handoff [step 5/12]`
- [x] Step 6.a/12 — `🚧 [antigravity-harness] feat(bridge): add isolated process and scoped store support [step 6.a/12]`
- [x] Step 6.b/12 — `🚧 [antigravity-harness] feat(antigravity): prepare isolated authentication profiles [step 6.b/12]`
- [x] Step 6.c/12 — `🚧 [antigravity-harness] feat(antigravity): add personal authentication boundaries and policy [step 6.c/12]`
- [x] Step 6.d/12 — `🚧 [antigravity-harness] feat(antigravity): compose personal browser authentication [step 6.d/12]`
- [x] Step 7.a/12 — `🚧 [antigravity-harness] feat(antigravity): map model catalogs and session options [step 7.a/12]`
- [x] Step 7.b/12 — `🚧 [antigravity-harness] feat(antigravity): handle questions and permission replies [step 7.b/12]`
- [x] Step 7.c/12 — `🚧 [antigravity-harness] feat(antigravity): normalize live and replay updates [step 7.c/12]`
- [x] Step 8.a/12 — `🚧 [antigravity-harness] feat(antigravity): add recovery foundations and ACP seams [step 8.a/12]`
- [x] Step 8.b/12 — `🚧 [antigravity-harness] feat(antigravity): compose persistent ACP sessions [step 8.b/12]`
- [x] Step 8.c/12 — `🚧 [antigravity-harness] feat(antigravity): compose runtime descriptor and setup [step 8.c/12]`
- [x] Step 9/12 — `⚙️ [antigravity-harness] feat(bridge): activate local Antigravity runtimes [step 9/12]`
- [x] Step 10.a/12 — `🌿 [antigravity-harness] feat(runtime): require archive command budgets [step 10.a/12]`
- [x] Step 10.b/12 — `🚧 [antigravity-harness] feat(runtime): validate isolated installation candidates [step 10.b/12]`
- [x] Step 10.c/12 — `🚧 [antigravity-harness] feat(antigravity): validate official managed candidates [step 10.c/12]`
- [ ] Step 10.d/12 — `🚧 [antigravity-harness] feat(antigravity): install the managed ACP runtime [step 10.d/12]`
- [ ] Step 11/12 — `🌱 [antigravity-harness] docs: complete guidance and regression coverage [step 11/12]`
- [ ] Step 12/12 — `🚧 [antigravity-harness] test: verify Antigravity and retire the plan [step 12/12]`

## Step 1 Checklist

- [x] Inspect shared ACP transport, plugin hooks, approval registry, session options, and replay behavior.
- [x] Inspect plugin descriptor/runtime/install patterns and app/client registration seams.
- [x] Inspect the official ACP registry manifest and Google docs.
- [x] Inspect T3 Code PR #9348 as corroborating released-agent evidence.
- [x] Record local-first then managed-install delivery order.
- [x] Record personal OAuth, remote loopback callback, isolated profile, supervised permission, and five-host decisions.
- [x] Write the implementation plan and retirement matrix.
- [x] Complete one architecture plan review and apply valid findings.
- [x] Validate plan paths, fixed titles, Markdown whitespace, and worktree diff.
- [x] Commit, push, open the Step 1 PR, and start the PR monitor.
- [x] Create the Step 2 successor branch and begin the package/runtime-contract work locally.

## Step 2 Checklist

- [x] Sync the successor branch to merged Step 1 and preserve the reviewed plan corrections.
- [x] Independently download, hash, inspect, and initialize-probe the official macOS arm64 runtime pair.
- [x] Separate shared ACP initialize-only and authenticate operations without changing combined callers.
- [x] Add the inactive package, pair/launch facts, generated initialize DTO, release facts, and Layer-1 ACP probe API.
- [x] Add the package to bridge workspace, Makefile, and CI discovery inventories without app registration.
- [x] Cover official target/launch facts, generated parsing, malformed/timeout/abort/exit handling, and cleanup.
- [x] Split local pair resolution into Step 3 after the combined diff measured above the 1,500-line cap.
- [x] Complete architecture implementation review and apply the generated-DTO boundary finding.
- [x] Run final focused analysis/tests and Git/Markdown validation.
- [x] Commit, push, open the Step 2 PR, and start the PR monitor.

## Step 3 Checklist

- [x] Sync the successor branch to merged Step 2 and restore the retained local-pair WIP.
- [x] Add typed pair-read and runtime-resolution outcomes at their first storage/repository consumers.
- [x] Add exact filesystem/PATH pair inspection without creating files or processes.
- [x] Map storage and generated initialize DTO outcomes through `AntigravityRuntimeRepository`.
- [x] Implement service-owned explicit -> PATH -> managed precedence and exact contract validation.
- [x] Cover pair integrity, precedence, generated mapping, contract failures, aborts, timeouts, and cleanup.
- [x] Complete architecture implementation review and apply valid findings.
- [x] Run final focused analysis/tests and Git/Markdown validation, including self-inclusive merge-base numstat
  reconciliation against the 1,500-line cap.
- [x] Commit, push, open the Step 3 PR, and start the PR monitor.

## Step 4 Checklist

- [x] Inspect descriptor, runtime, lifecycle, Codex authentication, scoped-store composition, and focused tests.
- [x] Replace the stream-only descriptor return with sealed device-code/browser operation variants.
- [x] Pass a required per-state-root `HostJsonStore` instance to authentication and every live plugin generation.
- [x] Add active-generation redirect routing with typed no-active, wrong-kind, and already-submitted conflicts.
- [x] Preserve Codex device-code behavior while rejecting browser redirect submission.
- [x] Finish focused same-request, challenge-order, generation, duplicate, cancel, shutdown, store, and cleanup
  coverage.
- [x] Complete architecture implementation review and apply valid findings.
- [x] Run final focused analysis/tests and Git/Markdown validation.
- [x] After Step 3 merges, sync, commit, push, open the Step 4 PR, and start its monitor.

## Step 5 Checklist

- [x] Complete the remote browser handoff, review, and verification.

## Step 6.a Checklist

- [x] Obtain approval for scoped stores, privacy prerequisites, and lettered Step 6 slices.
- [x] Review the new partition/shared architecture against the plan-review skill; no violations.
- [x] Add required environment-inheritance selection across host spawn and every ACP caller.
- [x] Add inert child JSON scopes retaining the same per-directory update-lock owner.
- [x] Add bounded raw stdout/stderr interception before decode/log with cancellation-safe buffers.
- [x] Cover inheritance, atomic child updates, path restrictions, byte preservation, privacy, and cleanup.
- [x] Run focused validation and update regression invariants without claiming active Antigravity support.
- [x] Independent architecture implementation review approved; no issues found.
- [x] Step 5 merged; sync Step 6.a with main before publication.
- Package remains unregistered; composed personal OAuth remains in Step 6.d.

## Step 6.b Checklist

- [x] Obtain approval for the backend-neutral early browser-noop CLI mode; update and review its architecture plan.
- [x] Add layered profile preparation, generated personal-auth settings, injected scoped store, and token presence only.
- [x] Verify private directory ordering/mode, environment filtering, and preparation failures.
- [x] Add selective plugin-owned OAuth stderr interception while retaining other diagnostics.
- [x] Build the actual native bridge; verify native/source helpers and pinned Python browser semantics synthetically.
- [x] Run focused tests and owning-package analyzers; update regression contracts.
- [x] Independent architecture review approved immutable Step 6.b code head `8fe1ee51be25`.
- Second/final review approved `7351ed64f1`; user authorized the later service-owned preflight-policy correction
  with focused tests and no third architecture review.
- [x] Step 6.a merged; synchronize before Step 6.b publication.
- Publication cap: `git diff --numstat 0723491330 4a8e14a1d5` totals 845 + 12 = 857 changed lines.
  The estimated range was a scoping guide, not a minimum; implementation and meaningful coverage fit below it.
- Validation: 45 Antigravity tests and 15 focused app/no-op/scoped-store tests pass; final selective stderr
  refinement passes its 4 tests. Antigravity, foundation, and app analyzers pass with fatal infos. Native bridge
  bundle builds and the helper exits 0 with no output; extracted pinned Python confirms no browser fallback.
  See `docs/regression/antigravity-isolated-profiles.md` for reproducible evidence and platform limits.
- No OAuth execution, token-content access, registration, managed activation, or authentication boundary work in 6.b.

## Step 6.c Checklist

- [x] Approve 6.c boundaries/policy and 6.d composition split after full-slice estimate exceeded the line cap.
- [x] Reuse existing scratch ACP ownership for personal authentication with cleanup and sanitized interception.
- [x] Add Layer-2 authorization mapping, dedicated no-proxy/no-redirect loopback transport, repository normalization,
  and service-owned exact Google/callback/state/code policy.
- [x] Thread one monotonic budget/abort signal through profile layers, preserving executor timeouts and waiting for
  non-cancellable filesystem/store work before rejecting late success. Browser preflight retains its five-second cap.
- [x] Initial checkpoint: 60 Antigravity tests (45 inherited, 15 added) and owning-package analysis passed.
- [x] Independent architecture review approved all 19 files at immutable checkpoint `afda6be61c48`.
- [x] Step 6.b merged; synchronize before Step 6.c publication.
- Publication cap: `git diff --numstat ce423c8ea7 2055e399c8` totals 1,106 + 41 = 1,147 changed lines.
- Post-sync validation: all 63 Antigravity tests and owning-package analysis pass.
- No composed operation, one-shot operation coordination, terminal reinspection, registration, real OAuth, or credential
  access in the 6.c slice; composition belongs to Step 6.d.


## Step 6.d Checklist

- [x] Compose isolated profile preparation, runtime selection/exact probing, and personal authentication through
  existing services with one environment and monotonic budget. Keep provider URL policy inside the service.
- [x] Add per-attempt single challenge/one-shot continuation, same-host completion, and awaited cancellation/cleanup.
- [x] Add the unregistered composer with shared root scopes, isolated host commands/ACP and dedicated HTTP client.
- [x] Preserve the existing bridge lifecycle service as terminal setup-reinspection owner; test closure ordering.
- [x] Approved narrow boundary fixes await pending probe/auth spawn reaping and callback transport settlement after
  forced closure, preserving the controlling failure. No new shared transport machinery or descriptor registration.
- [x] Initial checkpoint: 77 Antigravity tests, 8 relevant bridge lifecycle tests, owning Antigravity analysis and
  changed bridge-test analysis passed. Canonical-path fixture correction was verified before the complete run.
- [x] Independent architecture review approved all 14 files at immutable checkpoint `5f33ba6390`.
- [x] Step 6.c merged; synchronize before Step 6.d publication.
- Post-sync verification: 78 Antigravity tests, 8 focused lifecycle tests, and both relevant analyses pass.
- Post-sync code-head cap: `git diff --numstat f1403fbb35 d5812b3550` totals 997 + 35 = 1,032 changed lines.
- No real OAuth, ambient credential/token access, database/history changes, Step 7 work, or active harness registration.

## Step 7.a Checklist

- [x] Obtain explicit user approval for 7.a/7.b/7.c partition, retaining twelve top-level steps and per-PR line caps.
- [x] Map grouped model config through generated DTOs to immutable catalog values; validate before tracker mutation.
- [x] Expose honest partial/no-model options before a real session catalog; never create scratch persistent sessions.
- [x] Add standard typed ACP set_mode through API/repository; select exact validated model then default mode.
- [x] Focused validation: 10 catalog/options tests and 11 ACP config/API tests pass; both owning analyses are clean.
- [x] Independent architecture review approved all 19 files at immutable checkpoint `0e002cdebe`.
- [x] Step 6.d merged; synchronize before Step 7.a publication.
- Post-sync validation: 10 options tests and 11 ACP tests pass; both owning-package analyses remain clean.
- Post-sync code-head cap: `git diff --numstat 2f2f376836 778535c8f4` totals 848 + 19 = 867 changed lines.
- Final predecessor fix `54f0dbf51d` received independent architecture approval. Its pinned cap against `2f2f376836`
  is 1,008 additions + 21 deletions = 1,029 lines, including corrected catalog capture/reset and selection verification.
- Permissions/questions and update normalization remain 7.b/7.c; no descriptor, registration or capability claim.

## Step 7.b Checklist

- [x] Normalize permission requests/options with generated DTOs before service policy; serialize typed wire outcomes.
- [x] Keep all resolution dispatch in a connection-scoped interaction repository, reached only through its service.
- [x] Classify single-choice interaction requests, preserve advertised labels/IDs, and reject duplicates without repair.
- [x] Filter always/unknown/warning-bearing choices; never invent an absent choice or silently grant approval.
- [x] Reuse neutral pending lifecycle for one-shot replies, wrong-kind handling, session cancellation and disposal.
- [x] Initial code checkpoint `ef2c890284`: all 10 interaction tests and owning-package analysis passed.
- [x] Merge the reviewed predecessor fixes; update regression documentation/index and the explicit Step 8 registry seam.
- Final owning-package analysis is clean. Interaction production logic/tests are unchanged from their passing checkpoint;
  only the mapper definition comment changed. The unchanged 10-test command was not redundantly rerun.
- [x] First actual independent implementation review approved all 17 changed files at `97eda29b57`, with no findings.
- Reviewed immutable scope: `54f0dbf51d` → `97eda29b57`; 1,146 additions + 9 deletions = 1,155 changed lines.
- Publication checkpoint: `git diff --numstat daa782057c 164a7112ab` totals 1,154 + 12 = 1,166 lines, including
  the tracker's own diff. The +11 net scope difference is tracker synchronization/review-status documentation;
  `git diff 97eda29b57 164a7112ab -- bridge/sesori_plugin_antigravity` is empty.
- Later CI fix `cbc72324a7` fences late callback connection completion after an early timer; all four loopback tests
  and owning analysis pass. Review fixes add useful decoder evidence and honest permission tool-kind display.
- Final review checkpoint `80b7402f64`: all 12 interaction tests and owning analysis pass; second/final independent
  architecture review approved. Net diff against `daa782057c` is 1,340 lines. Step 7.c retains these reviewed fixes.
- [x] PR #1354 merged with 16/16 CI checks passing. Step 7.c stays on its assigned reviewed-fix base until the parent
  synchronizes after sole-writer completion; no concurrent branch switch or merge is performed by the worker.
- [x] Predecessor #1353 merged; synchronized with main `daa782057c`. Conflict resolution retained the reviewed 7.b
  additions. Antigravity/ACP/interface production and tests plus the lockfile are unchanged from the reviewed inputs;
  no unchanged passing suite was rerun. Parent owns publication.
- The neutral registry is intentionally not yet wired into `AcpPlugin`; Step 8 replaces its hard-coded stock registry
  return-type seam without dummy responders or inherited raw permission policy. No 7.c, registration, database,
  credential/OAuth/history access or active capability claim is included here.

## Step 7.c Checklist

- [x] Shared live/replay session-update hook defaults to identity; all collector consumers updated explicitly.
- [x] Generated DTOs normalize pinned native aliases, canonical command/output fields and typed text content.
- [x] Preserve ACP status independently from process exit; reserve an explicit exit note inside the shared display cap.
- [x] Bound raw JSON and remove redundant image bytes without damaging supported standard image content/metadata.
- [x] All 21 Antigravity normalization tests, 54 ACP replay/tool/history tests and 13 DeepSeek history/time tests pass.
- [x] Owning Antigravity/ACP and changed DeepSeek analyses are clean with fatal infos; DTO generation and formatting run.
- [x] Add indexed live/replay regression document; no credential, database, history mutation or active capability claim.
- [x] First actual independent review approved all 16 changed files at `19e24a4e36` against `80b7402f64`: 1,156
  additions + 12 deletions = 1,168 lines, including generated/tests/docs. Earlier incomplete checkpoints were uncounted.
- [x] Synced with main `b43758e1b3`, preserving the reviewed inputs and removing a duplicate method introduced by
  automatic merge. At publication, relevant package source/tests and lockfile matched the reviewed checkpoint exactly.
- Publication cap `b43758e1b3` → `586e787da6` is 1,158 + 12 = 1,170 lines. The +2 versus the earlier review scope
  is tracker status/synchronization documentation only; the removed duplicate method was a merge artifact, not a
  deletion from the reviewed implementation.
- Localized PR review fixes preserve formatted-only output, differing text, direct images and malformed-entry
  degradation. All 21 normalization tests and owning analysis pass; shared ownership/contracts are unchanged.
- Exact review base is `80b7402f6443b810b49b429410667138cd099b09`, not either pre-fix predecessor head. The plugin
  remains unregistered; Step 8 composes the provider normalizer override. No registry/residency/metadata seam lands here.

## Step 8.a Checklist

- [x] Partition reviewed Step 8 into recovery/seams (900–1,350) then composition (950–1,350), full estimate 1,850–2,700.
- All further necessary PR splits are pre-approved; never ask again. Keep twelve top-level steps, the full 1,500-line
  per-PR cap and one-open/immediate-successor-local sequencing.
- [x] Metadata Storage → Repository → Service, bounded read-only decoding and typed registration batch.
- [x] Neutral ACP registry, bulk-directory, residency preference and live/replay output-policy seams.
- [x] Focused validation: 20 Antigravity, 69 ACP, 13 Cursor and 11 DeepSeek tests pass (113 total); all four owning
  package analyzers are clean with fatal infos. New tests cover metadata and non-stock registry/residency/output seams.
- [x] Indexed regression documentation; source DTO generated normally without manual generated edits.
- [x] First independent architecture review approved all 30 files at `c39ce10bd3` against `635ec52ee1`: 886 additions
  + 47 deletions = 933 lines, including generated/tests/docs. No findings.
- [x] Integrated predecessor output fixes through `2b6342653e`; owning Antigravity analysis remains clean.
- [x] PR #1357 merged with 16/16 CI. Synced with main `dfe7913e67`; only documentation conflicted and relevant
  package source/tests plus lockfile remain unchanged by this synchronization. No unchanged passing suites rerun.
- [x] Parent published Step 8.a as PR #1359 and started its monitor.
- [x] Review fixes: keep recovered fallbacks below DB/live attribution in either arrival order and forget them on
  deletion; decline ambiguous Antigravity permissions with cancelled outcomes; retain safe generated-cast diagnostics.
  All 32 ACP recovery/project and 20 Antigravity metadata/interaction tests pass; both owning analyzers are clean.
- [x] Second/final architecture review approved: reviewer `8baf4e17`, all 29 files, no findings;
  `dfe7913e672a27de2c4ec39ed897b0df7272a895` → `14169bd6e3ed9307d9e49e2c04a4ff3f1ece427e`, 988 lines.
- [x] PR #1359 merged with 16/16 CI. Plugin composition is 8.b; descriptor/setup is 8.c; activation is Step 9.

## Step 8.b Checklist

- [x] Approved 8.b/8.c partition recorded; no descriptor/setup, registry/CLI activation or managed install here.
- [x] Required plugin/interaction/output composition over prepared inputs; per-call configuration repository,
  metadata fallback below DB/live bindings, resume-first residency and load-only replay.
- [x] Prefix-gated output (56 bytes before ordinary NDJSON passthrough), bounded private lines, immutable byte
  views, typed initialization mapping, original reset/error source stacks, and no new cleanup owner.
- [x] Fake composed lifecycle, long history/two sessions, active cancel/delete/questions, crash/reset/reconnect,
  interruption, late spawn, privacy and image-bearing JSON evidence; indexed regression documentation.
- [x] Fresh JSON-reporter evidence: 11 `antigravity_plugin` + 13 `antigravity_session_options_service` +
  2 `antigravity_output_composer` = 26 Antigravity tests. The plugin's nine declarations instantiate eleven tests
  through two two-value parameterizations. The prior output-composer count of ten was incorrect; combined coverage
  with the previously passing 35 ACP + 14 transport cases is 75, not 83.
  Reproduce with `dart test --reporter=json` on those three `test/*_test.dart` files in the Antigravity package.
  All 26 pass, including explicit-model recovery after reset; owning analysis is clean.
- Full local net cap against `14169bd6e3`: 1,284 additions + 81 deletions = 1,365 lines across 23 files,
  including tests/docs/planning at that initial immutable checkpoint.
- [x] First actual architecture review approved all 23 files at `4394b735a6` against `14169bd6e3` (1,365 lines),
  reviewer `b65aeff7`, no findings. Earlier incomplete-input reviews are not counted.
- [x] Synced with main `6959375add`; only documentation conflicted. Source/tests are unchanged from the reviewed
  checkpoint, so unchanged passing suites were not rerun.
- [x] Parent published Step 8.b as PR #1360 and started its monitor; only Step 8.c may proceed locally.
- Review fixes validate model IDs before admission when a catalog is known; after reset, residency restores the
  catalog before strict dispatch validation. Metadata recovery runs once per cold live connection, not enumeration.
  Message model/provider stamping remains required in 8.c before activation, preserving the full 1,500-line cap.
- Corrected immutable measurement: base `6959375addc700c00b0206204bbfc00ea6b3ca88` → head
  `ad011a4f2d05c82162b328c1c45fd82e5f6582d3`: 1,350 additions + 92 deletions = 1,442 lines across 23 files.
  This includes the tracker and every file as of that head. The 77-line increase over 1,365 is three publication-doc
  lines plus 74 review-fix lines; main synchronization itself changed no count. `66d8186601` adds two approval lines
  (1,444 total). Later changes have separately measured PR-body totals; these immutable measurements are not rewritten.
- [x] Second/final architecture review approved all 23 files at `ad011a4f2d` against `6959375add` (1,442 lines),
  reviewer `58f4d8a5`, no findings. All seven delivered GitHub threads have prefixed disposition replies.
- Descriptor exit supervision, inert setup/profile inspection and complete host/auth composition are 8.c.
  Real OAuth, native/cross-target operation, bridge import/tombstone end-to-end and L5 Full remain later gates.
  No Google history mutation, ambient credentials or active harness inventory were introduced.

## Step 8.c Checklist

- [x] Added the unregistered descriptor and complete host/runtime/auth roots over the existing composers and lifecycle.
- [x] Setup inspection is static and unversioned: exact explicit/PATH/future-managed sibling presence plus isolated token
  presence only, without writes, token reads, browser preparation, process spawning, probing or authentication.
- [x] Preparation, exact probe and live startup share the sanitized isolated environment, disable parent inheritance,
  reuse the plugin-root `HostJsonStore`, permit personal OAuth only and invoke the backend-neutral browser no-op.
- [x] Shared ACP configuration state stamps Antigravity model/provider metadata in live and replay messages. New sessions
  establish defaults; load/resume do not. Reset clears catalog/configuration together before real residency restores it.
- [x] Known-catalog pre-queue validation and strict post-residency dispatch validation preserve the Step 8.b cold-reset
  correction; successful acknowledged selections update only the named session.
- [x] Existing lifecycle exit supervision resets/reconnects and re-arms without another manager; abort and shutdown await
  cleanup. Install, bridge registry/CLI activation and real OAuth remain later gates.
- [x] Fresh JSON-reporter evidence: 7 descriptor + 14 options + 11 composed plugin = 32 primary Step 8.c tests; the
  separately included profile suite has 17 tests, for 49 non-loading tests total. All pass on integrated inputs.
  Counts use suite/test IDs and successful `testDone` entries with source lines, not compact reporter filenames.
- [x] Owning Antigravity analysis and the complete package test command pass. Test totals are not inferred from compact
  reporter filenames. Indexed regression documentation records behavior, failure signals and remaining L5 gates.
- Pre-review cap against exact base `c13843000d1532debef0efca5192aaf50fc761c3`: 1,039 additions + 38 deletions =
  1,077 changed lines across 22 files.
- [x] First actual architecture review approved all 22 files at `53296324b2954c706d95ab2d492cd5518ab08a1a`
  against `c13843000d1532debef0efca5192aaf50fc761c3`: 1,039 additions + 38 deletions = 1,077 lines.
  Reviewer `293fcc78`, no findings. Prior incomplete-input blocks `de058330` and `1c53fd03` are not attempts.
- [x] Synced with main `b13d197d517`; merge resolutions retain the reviewed Antigravity/shared owning source/tests
  unchanged. Unrelated upstream DeepSeek updates remain outside this PR's diff. No unchanged passing suites rerun.
- [x] Per user request, capability matrix documents login initiation versus local setup for every registered harness,
  plus Antigravity's explicitly unregistered browser-return implementation; detection/install are not login. The
  contract reference uses the exact `InteractivePluginAuthenticationDescriptor.authenticate` symbol.
- [x] PR feedback corrections preserve exact opaque model IDs through the shared tracker and composed live/replay
  attribution, while blank values remain absent. Provisioning timeouts now log their original timeout/stack and settle
  as non-fatal `ProvisionFailed`; explicit aborts still propagate. Callback HTTP construction is required and production
  deliberately passes `HttpClient.new`, so tests cannot fall through to a real loopback client.
- [x] Static inspection logs recovered PATH storage causes/stacks before inert managed fallback. Ordinary PATH absence
  and pair rejection remain normal candidate resolution, matching `resolve()` rather than manufacturing failures.
- Correction verification: 46 Antigravity tests across descriptor, runtime, options and composed plugin suites plus 3
  focused ACP tracker/mapper tests pass. Counts use JSON suite/test IDs and non-hidden successful `testDone` records;
  both owning package analyzers pass with fatal infos. Final cap/review head is recorded in the immutable review scope.
- [x] Second/final actual architecture review approved `b13d197d517` → `cd16aa3a96`: all 26 files, 1,339 additions +
  57 deletions = 1,396 changed lines. Reviewer `2bb17500`, no findings. The worker's post-commit provider disconnection
  lost only result delivery; preserved verification/artifacts were used without rerunning unchanged passing commands.
  First approval at `53296324b2` remains recorded; incomplete-input blocks and the never-launched reviewer are not attempts.

## Step 9 Checklist

- [x] Register `AntigravityPluginDescriptor.production()` through the existing app composition root and add the app
  package dependency; production explicitly injects `HttpClient.new` and no test/consumer can fall through to a real
  callback client.
- [x] Keep the plugin-owned opaque `antigravity` ID, generic client presentation, bridge-derived projects, OpenCode
  preferred default and existing lifecycle owner; add no shared `Harness` case or managed install capability.
- [x] Expose the descriptor's bare `bin` option as `--antigravity-bin` and retain authoritative explicit/PATH local-pair
  behavior, isolated auth/live profile, false parent-environment inheritance and exact runtime probing from Step 8.c.
- [x] Update setup/operator guidance before login is reachable: proprietary official pair, Google terms, current-client
  personal OAuth, no local fallback, isolated credentials and retained Google history after local deletion.
- [x] Update capability and affected regression contracts for fresh-process model discovery, exact opaque selection,
  default mode, safe once-kind interactions, bounded live/replay mapping, recovery, images and local tombstone behavior.
  Persistent choices are excluded categorically; warning-bearing choices are independently excluded without claiming
  an unverified upstream limitation.
- [x] Preserve every other harness login row and leave authentication methods beyond personal OAuth as honest Sesori
  implementation gaps. Native OAuth, supported-target runtime execution and the final L5 matrix remain pending gates.
- [x] Focused verification passes on pinned Dart 3.13.2: 4 registry + 3 CLI inventory tests in the app and 8 descriptor
  + 1 authentication-composer tests in Antigravity, for 16 executed tests across four suites. Both owning analyzers are
  clean with fatal infos. Counts use JSON suite/test IDs and non-hidden successful `testDone` records, never compact
  reporter filenames.
- [x] First complete architecture review approved `7befa7059a431e9dfbf0d32142d2dfd9202aa3af` →
  `0cc657c1612f233320ce8d687d672739f5077e0a`: all 30 files, 313 additions + 103 deletions = 416 changed lines.
  Reviewer `d4fee422`, no findings. Reviewer `4e5105a2` blocked before assessment on the incomplete WIP checkpoint
  and does not count as an attempt. Keep this reviewed checkpoint distinct from later publication measurements.
- [x] Synced with main `20a1580688` after Step 8.c merge. All bridge source/test/dependency inputs are unchanged from
  the reviewed checkpoint; merge resolutions preserve activation and all predecessor fixes. Unchanged passing commands
  were not rerun. Publication size is measured separately including this tracker reconciliation.
- [x] Activation review correction: unsupported targets have no managed-path candidate, allowing the existing setup
  service to report unavailable without a filename exception. Nine descriptor tests pass, including inert macOS x64
  inspection with/without an explicit path; owning analysis is clean. Index ordering, source indentation, plan status
  and platform guidance are corrected. This is a localized logic/docs fix, not an architectural expansion.

## Step 10.a Checklist

- [x] Split Step 10 under standing approval: archive budgets, isolated candidate validation, then official managed pair
  integration. Only 10.a is being implemented; later slices retain every original requirement and the 1,500-line cap.
- [x] Add required `ArchiveRuntimeAsset.archiveCommandTimeout` and extractor input, applying it to archive listing and
  extraction. Update all 34 current platform assets, fixture assets, extractor doubles and the self-update caller.
- [x] Existing archives/self-update explicitly keep a two-minute per-command budget. Listing no longer has a separate
  fixed 30-second bound. No Antigravity managed asset or installation action is introduced.
- [x] Add deterministic simulated slow-command/timeout-cleanup coverage and selected-asset forwarding assertions;
  preserve real tar/zip/symlink tests and update both relevant regression documents.
- [x] Focused JSON-counted tests pass: foundation archive 8; runtime install 12 + managed install 14 + provision 10;
  app updater 6 + registry 4 = 54 executed tests across six suites. Foundation/runtime/app analyzers and all six changed
  manifest-file analyzers pass with fatal infos; formatting and whitespace checks pass. No dependencies were installed.
- [x] First foreground architecture review approved `635df576103511dffb18a41624d2599ff5d7e7b9` →
  `3f4f00d81335e5b34042e5d1b1a923189960f2a6`: all 18 files, 222 additions + 26 deletions = 248 changed lines.
  Reviewer run `caa5bebe`, no findings. User explicitly approved foreground execution after background bootstrap failed;
  no earlier Step 10 review launched. Keep the immutable reviewed count distinct from publication metadata.
- [x] Integrated Step 9's unsupported-target/docs correction at `5c68c5b3a0`; archive-budget production/tests remain
  unchanged from their approved checkpoint. The corrected predecessor has its own passing descriptor evidence.
- [x] Step 11 explicitly names root `README.md` and `bridge/README.md`, per user request.
- [x] Step 9 merged with 16/16 checks; synchronized main `28998e2f73`. All reviewed bridge files remain byte-identical.
  Main also changed app/plugin stop contracts, so reran the 10 app updater/registry tests and app analysis: all pass.
  This overlaps the initial 54-test scope; unchanged archive tests were not rerun. Publication counts include metadata.

## Step 10.b Checklist

- [x] Add one required backend-neutral candidate-validation seam and adapt all seven managed-runtime installers
  explicitly through their existing exact bundled-version validators.
- [x] Validate downloaded candidates after checksum, archive hardening and executable chmod but before package placement
  or sentinel creation; remove the duplicate destructive post-placement probe.
- [x] Own disposable validation cwd/state below private managed staging, keep extraction in a child directory, and await
  validation plus context cleanup for downloads and cached candidates.
- [x] Pass `StartAbortSignal` through the seam while retaining honest bounded-command behavior for current validators.
- [x] Cover validation ordering/containment/private-mode commands, cache validation, exact-version behavior, and
  rejection/abort rollback preserving the prior package and sentinel.
- [x] Pinned Dart 3.13.2 verification: all 195 non-hidden tests across the runtime package's 19 suites pass; runtime,
  OpenCode, Codex, Cursor, DeepSeek, Copilot, OMP and Pi analyzers are clean with fatal infos. Counts use successful
  JSON `testDone` records keyed by suite/test IDs; logs are retained under `/tmp/antigravity-step10b-*`.
- [x] First foreground architecture review `d9e0453b` approved complete `57e9ecf33e` → `1cc96e98ff`: all 21 files,
  581 additions + 111 deletions = 692 lines, no findings. Keep this immutable review distinct from publication metadata.
- [x] Final localized diagnostics retain candidate launch errors/stacks and actual/expected version mismatches before
  returning a rejected candidate. Sixteen overlapping validator tests pass and owning analysis is clean; these are
  not additional unique cases on top of the initial 195. No architecture boundary changed in this follow-up.
- [x] Step 10.b merged in PR #1380. Its terminal report had 15/16 completed checks, clean Cubic approval, and Codex
  review still running; do not restate that as 16/16.

## Step 10.c Checklist

- [x] Split the complete Step 10.c implementation under standing approval: release facts and candidate validation
  first, followed by manifest and descriptor installation integration.
- [x] Independently downloaded all five archives from the exact official registry URLs at commit
  `536e378b70a7a6d5f078a9160180e3569a23253c`; recomputed every SHA-256 and archive byte count, and listed both member
  names/sizes. All facts match `pingdotgg/t3code@fff33f9e851912363c5b1f3ac65598be35eb5f0d`.
- [x] Pin all five verified archive facts in `AntigravityRelease`, retaining the independently hashed macOS member
  digests and the unsupported macOS x64 result.
- [x] Add `AntigravityRuntimeVersionValidator(required runtimeService)`. It uses the installer-owned state as
  `GEMINI_HOME`, shares the profile's ambient-credential stripping policy, forces file storage, uses the supplied staged
  cwd and abort signal, and awaits the existing initialize-only ACP process lifecycle under a 90-second bound.
- [x] Native macOS arm64 correctness evidence: the packaged extractor and production validator accepted the official
  artifact and exact initialize contract, created no auth/session request, and left no files in disposable validation
  cwd/state. This does not establish native correctness on other platforms.
- [x] Keep Install unavailable: no manifest, descriptor install capability, installer composition or managed-download
  disclosure is added in this slice.
- [x] Worker `9d318de2` reached its 30-minute timeout after committing `68fd08a88e`, with a clean tree. Recovered only
  missing artifacts through foreground run `6d34e6d3`; no tests/downloads were repeated for that recovery.
- [x] First architecture review `10b3a055` approved complete `8184d028f3` → `68fd08a88e`: all 15 files,
  532 additions + 55 deletions = 587 lines, no findings. Artifact SHA-256 is recorded in the recovered scope file.
- [x] Initial focused tests: profile 17 + release 3 + runtime service 13 + validator 4 = 37; owning analyzer clean.
  After main's ACP/NDJSON lifecycle changes, reran the 17 runtime-service/validator cases and owning analysis: passed.
  This overlaps the initial 37, not 54 unique cases. Reviewed production files remain unchanged after synchronization.
- [x] Add the manifest, descriptor integration/disclosure, conservative command budgets and focused install-failure
  tests, retain shared rollback coverage, then update the managed-runtime capability rows. Unexecuted native correctness
  coverage remains explicit.

## Step 10.d Checklist

- [x] Added `AntigravityRuntimeManifest` from the already pinned five official release artifacts. Every asset is a ZIP
  package directory with a conservative two-minute per listing/extraction command budget.
  Managed directories use registry package version `1.0.0`, while candidate validation
  separately requires runtime identity `agy_acp_server_20260818_01_RC01`.
- [x] Composed the shared managed installer/cleaner with the existing initialize-only
  `AntigravityRuntimeVersionValidator`. The descriptor keeps explicit -> valid PATH -> installed managed precedence,
  advertises Install only on Google's five targets without `--antigravity-bin`, and closes its required download client.
- [x] Added pre-action proprietary Google download disclosure with terms/documentation links. Updated the capability,
  runtime-installation, setup/lifecycle and Antigravity descriptor regression contracts without advancing the Step 11
  root/bridge README reconciliation.
- [x] Focused pinned-Dart verification passes: 34 non-hidden Antigravity tests across five suites and 4 app registry
  tests, counted from successful JSON `testDone` records with suite/test IDs. Antigravity and app analyzers are clean
  with fatal infos. One initial app registry run failed because its fixture omitted the now-read `bin` option; the
  fixture was corrected and its four tests plus app analysis pass.
- [x] Foreground native macOS arm64 managed-pipeline smoke reused the independently rehashed cached official archive in
  disposable state. It downloaded through the descriptor, verified/extracted the package, preserved the server/harness
  siblings, ran exactly one false-inheritance initialize-only validation, removed validation cwd/state and staging,
  and returned the `1.0.0` managed server. No OAuth, authentication, session or real user profile was used.
- [x] Native Linux x64/arm64 and Windows x64/arm64 correctness remains unexecuted and is not claimed. Shared automated
  tests continue to own integrity, traversal/symlink, candidate-before-placement, abort, cleanup and prior-runtime
  retention coverage. Same-pinned-directory placement itself is not claimed to roll back after rename.
- Pre-review cap against `4fdd433392eabde75f1d800b649337206f057421`: 483 additions + 97 deletions = 580
  changed lines across 14 files, including the committed user plan correction.
- [x] First foreground architecture review `5d75ef9a` approved complete `4fdd433392` → `4ecc6b141f`: all 14 files,
  483 additions + 97 deletions = 580 lines, no findings. Publication metadata is counted separately.

## Architecture Reviews

- **Step 6.b plan review (2026-09-05): APPROVED.** Applied `.agents/skills/architecture-plan-review/SKILL.md`
  to the profile layers and approved native browser-noop addendum before implementation. Bridge-only dependency
  direction, neutral entrypoint contract, injected invocation ownership, class cohesion, and bounded state passed.

- **Plan review:** completed 2026-09-03. The reviewer rejected the first draft with six concrete findings across
  separation of concerns, composition, suffix naming, bridge layers, client DTO mapping, and presentation ownership.
  All valid findings were applied directly; repository policy does not call for re-reviewing those fixes.
- **PR review:** first wave of eight findings applied on 2026-09-03: explicit environment inheritance, service-owned
  auth/options workflows, generic artwork, pre-activation disclosure, extraction budgets, L5 Full scope, and shutdown
  install-abort semantics. The second wave adds service-owned runtime policy, plugin-owned identity, coherent Step 6/7
  composition, and host-backed profile chmod. The third wave extends per-asset archive budgets through traversal
  preflight and documents fresh-process first-session default-model behavior. The fourth wave adds metadata/setup
  service ownership, Layer-2 protocol mapping, per-feature regression updates, and current-client-only new auth. The
  fifth wave adds typed catalog/interaction mapping and policy ownership, staging-contained managed validation, and a
  backend-neutral residency-preference hook. A follow-up aligned the authentication-operation dependency list. Four
  post-merge findings add layered interaction replies, Layer-2 auth-line mapping, useful local model diagnostics, and
  atomic host-store injection for profile settings; these corrections travel with Step 2.
- **Step 2 implementation review:** first pass rejected handwritten parsing of newly exposed ACP initialize fields. The
  shared parser additions were reverted, and Layer 1 now maps into generated Antigravity Freezed/JSON DTOs before the
  repository. The second and final pass approved the corrected architecture with no remaining violations.
- **Series implementation review:** required in Step 12 over the Step 2-10 production range; maximum two passes

## Locked Decisions

- Official Google `antigravity-acp` registry pair only; no `agy` wrapper or community adapter.
- Plugin ID/name: `antigravity` / `Antigravity`, owned by `sesori_plugin_antigravity`; no shared `Harness` case.
- Exact initial pin: registry `1.0.0`, agent `agy_acp_server_20260818_01_RC01`.
- Personal OAuth only in initial support; other advertised auth methods remain documented gaps.
- Private profile under plugin state; no default-profile credential copy. Settings use the same plugin-scoped atomic
  host store across authentication and live hosting, and POSIX setup applies owner-only mode before launch.
- Remote auth uses pure-Dart generic loopback-input validation, then independent exact plugin validation before relay.
- New browser authentication requires a current mobile/desktop client; older clients retain already-authenticated use
  and receive an update-client hint, with no claimed CLI/bridge-host login.
- Agent mode is always `default`; `allow_always`, `auto_edit`, `yolo`, and dangerous skip are unavailable.
- Before a process observes a model catalog from new/load/resume, options are partial and the first session uses the
  account default; no persistent scratch Google session is created for discovery. Raw catalogs and permissions cross
  a Layer-2 mapper before policy, and outbound interaction replies cross a connection-scoped repository/service path.
  Bounded model IDs remain in local failure diagnostics only; analytics carry none.
- Shared ACP retains load-first residency by default; Antigravity selects resume-first through a backend-neutral hook.
- Managed exact probing uses an owner-only disposable home inside staging before atomic placement; it cannot touch the
  persistent profile, authenticate, or create a session.
- Local pair support lands before managed install.
- Managed targets: macOS arm64, Linux x64/arm64, Windows x64/arm64; macOS x64 unsupported.
- No database migration and no Antigravity-specific analytics.

## Retirement Coverage

Highest required level: **L5 Full**, including the complete applicable documented L1-L5 catalog.

Required target rows:

| Target | Local pair | Managed install | ACP identity | Process smoke | Status |
| --- | --- | --- | --- | --- | --- |
| macOS arm64 | Required | Required | Required | Required | Not run |
| Linux x64 | Required | Required | Required | Required | Not run |
| Linux arm64 | Required | Required | Required | Required | Not run |
| Windows x64 | Required | Required | Required | Required | Not run |
| Windows arm64 | Required | Required | Required | Required | Not run |
| macOS x64 | Unsupported guidance | Must be absent | N/A | N/A | Not run |

Required representative end-to-end rows:

| Flow | Boundary | Status |
| --- | --- | --- |
| Same-host personal OAuth | Google -> bridge host -> official agent -> desktop | Not run |
| Remote personal OAuth | Google -> client -> pasted redirect -> bridge loopback -> agent | Not run |
| Model/session create and turn | client -> relay -> bridge -> official agent -> Google | Not run |
| Permission and interaction question | official agent -> bridge -> client -> exact response | Not run |
| History, cold resume, bridge restart | isolated profile -> ACP load/resume -> client | Not run |
| Managed install rollback/shutdown abort | Google archive -> shared installer -> validated active pair | Not run |
| Unknown/older-client fallback | shared wire/plugin identity -> client presentation | Not run |

Antigravity-affected regression documents are listed in Step 11 of `PLAN.md`. Step 12 additionally collects every
applicable catalog entry from L1 through L5 across its required plugin/platform boundaries.

## Evidence Log

- 2026-09-04 — Step 6.a architecture plan review approved the user-authorized shared prerequisite slice;
  provider-specific profile, browser suppression, stderr matching, and authentication remain in 6.b/c.
- 2026-09-04 — Step 6.a focused validation: 106 distinct tests pass (ACP interception/factories 10,
  ACP stdio/agent API 22, host stores/processes 29, Antigravity 30, host command executor 1, interface lifecycle 14).
  App, ACP, interface, foundation, and Antigravity packages analyze cleanly; 38 mechanically updated consumer files
  also analyze cleanly. A parallel analyzer-plugin snapshot race was retried serially successfully.
- 2026-09-04 — An initial interception test caught idle-stream teardown hanging in an async generator. The final
  subscription-owned EventSink transformer forwards cancellation immediately, including an unfinished partial line.
  No OAuth, credentials, token reads, or official runtime downloads/execution occurred; process tests used only
  synthetic Dart output and the existing local stdio fixture.

- 2026-09-03 — Official registry manifest pinned at
  `agentclientprotocol/registry@536e378b70a7a6d5f078a9160180e3569a23253c`.
- 2026-09-03 — T3 Code PR #9348 / commit `fff33f9e851912363c5b1f3ac65598be35eb5f0d` reviewed for
  released-agent auth, pair, protocol, model, interaction, and tool behavior.
- 2026-09-03 — No repository production files changed before Step 1 planning.
- 2026-09-03 — Architecture plan review rejected the first draft with six concrete A3/A7/A8, B-Bridge, B-Client,
  and naming findings. The revised plan moves validation out of UI, maps wire DTOs in `PluginRepository`, adds explicit
  Layer-1/repository boundaries, fixes the launch-spec Builder suffix, and records constructor/composition ownership.
- 2026-09-03 — The official macOS arm64 archive matched 314,500,221 bytes and SHA-256
  `f122ca7e7030a27f9649da4cf1a7d80e12c48c5f6118ff35affc34d56cbf83dd`; its only members match the expected pair.
  Isolated initialize confirmed ACP v1, exact identity/version, load/list/resume/logout, absent close, and four
  authentication IDs.
- 2026-09-03 — PR #1285 first review produced eight actionable plan findings. All were applied without expanding into
  a user-facing install-cancel flow: shutdown/interruption recovery is the supported install-abort boundary.
- 2026-09-03 — PR #1285 second review produced four actionable findings. Runtime decisions now belong to
  `AntigravityRuntimeService`; the ID remains plugin-owned; plugin/descriptor creation is coherent in Step 7; and
  profile chmod uses an injected host-backed lower boundary.
- 2026-09-03 — PR #1285 third review produced two actionable findings. Each archive's required command budget now
  covers traversal preflight and extraction, and model discovery honestly reports partial/default-only state until a
  real new/load/resume response provides the catalog.
- 2026-09-04 — PR #1285 fourth review produced five actionable findings. Metadata recovery and combined setup now have
  explicit service owners; protocol normalization is Layer 2; behavior-changing PRs update regression contracts when
  they land; and new authentication requires a current client with an explicit update hint.
- 2026-09-04 — PR #1285 fifth review produced four actionable findings. The protocol mapper now normalizes
  catalogs and permission requests for owning services. Managed exact validation uses a disposable staging home before
  placement, and a backend-neutral ACP hook preserves load-first behavior while Antigravity selects resume-first.
- 2026-09-04 — PR #1285 merged as `3d65382e8c`; a final post-merge review found four valid plan gaps. Step 2 carries
  layered reply dispatch, Layer-2 auth parsing, bounded local model-ID diagnostics, and atomic profile settings.
- 2026-09-04 — Step 2 architecture review rejected handwritten additions to the shared ACP initialize parser. The
  correction keeps legacy parsing unchanged, maps raw initialize data to generated typed DTOs inside Layer 1, and
  exposes only typed values to Layer 2. The second review approved the corrected architecture.
- 2026-09-04 — The combined runtime-contract WIP measured 2,209 changed lines, so local pair resolution moved to
  Step 3 and the final guidance/regression steps were combined to retain twelve PRs. No behavior or retirement
  coverage was dropped.
- 2026-09-04 — Split Step 2 verification passed: generated output is fresh, Antigravity analysis and 11 tests pass,
  shared ACP analysis and 305 tests pass, and Git/Markdown validation reports no source-width or whitespace failures.
- 2026-09-04 — PR #1286 merged as `4c587bcefe` after 16/16 CI checks, resolved review feedback, and Cubic approval.
- 2026-09-04 — Step 3 architecture implementation review approved the local Storage -> Repository -> Service flow with
  no violations. Antigravity analysis passes, all 30 tests pass, and Git/line-width validation is clean.
- 2026-09-04 — Step 3's self-inclusive cap check used
  `git diff --numstat 4c587bcefed5 1c7f3d955ac1` with an additions/deletions sum: 1246 + 7 = 1253
  changed lines, leaving 247 lines below the 1,500-line cap.
- 2026-09-04 — PR #1287 merged as `d85d9fcb1d`; Step 4 was synced to that merge before publication.
- 2026-09-04 — Step 4 architecture implementation review approved the backend-neutral operation, generation fencing,
  scoped-store composition, and Codex lockstep update with no violations. Interface (161), Codex (415), and focused app
  authentication/runtime tests (129) pass; all three packages analyze cleanly.
- 2026-09-04 — Step 4's self-inclusive cap check used
  `git diff --numstat d85d9fcb1d36 6da24f133c` with an additions/deletions sum: 838 + 158 = 996 changed lines,
  leaving 504 lines below the 1,500-line cap.
- 2026-09-04 — Step 5 final code cap: `git diff --numstat 93c8982601eb 1b2283a4903b` totals
  1155 + 334 = 1489; this tracker-only reconciliation leaves the published PR at 1489 changed lines.

- 2026-09-04 — Step 6.a architecture review approved the full tracked/untracked diff against `6d8e062ef7`.
  Reviewed implementation: 722 additions + 65 deletions = 787 changed lines; review-status bookkeeping adds one line.
- 2026-09-05 — Step 5 merged as `0e8f9e6fb9`; Step 6.a synced to main `c8150a8025c2`.
  Post-sync validation: ACP 65, host stores/processes 29, Antigravity 30, foundation 1, interface 15 tests pass.
  All five owning packages analyze cleanly. One newly merged ACP launch fixture received the required flag.
  Initial publication cap: `git diff --numstat c8150a8025c2 4d8e7f8025` totals 733 + 69 = 802.
  This net diff includes tracker changes: removing six conflict-marker lines and adding five evidence lines
  reduced the earlier code-head diff of 803 by one. Commit churn is not added to base-to-head measurements.
