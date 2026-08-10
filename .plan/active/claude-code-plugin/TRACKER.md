# Claude Code Harness Plugin: Tracker

## Current State

- **Plan slug:** `claude-code-plugin`
- **Implementation base:** `origin/main` at
  `c169452b` (Step 8 synchronized with it after Step 7 merged)
- **Series state:** Steps 1-7/17 merged; Step 8/17 PR open
- **Current step:** 8/17 — stream event mapping
- **Plan PR:** [#737](https://github.com/sesori-ai/sesori_apps_monorepo/pull/737),
  merged 2026-08-04 as `6d641532`
- **Next action:** Start Step 9 locally while Step 8 is in review

## Plan Review

- **Verdict:** REJECTED, nine violations
- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-08-04
- **Reviewed scope:** `.plan/active/claude-code-plugin/PLAN.md`, with
  `TRACKER.md` and `PROTOCOL.md` as supporting context
- **Applied corrections:** violations 1-8 applied directly and not re-reviewed,
  per the repository plan-review process — added the Layer-2
  `ClaudeSessionProcessRepository` so no `services/` file imports `api/`; moved
  `initialize` DTO mapping into a new `ClaudeBackendCatalogRepository` and gave
  the two catalogs distinct names; moved `ClaudeEventDispatcher` and
  `ClaudeHistoryMapper` up to `lib/src/` to remove Layer-2 peer dependencies;
  gave applied model/agent/mode a single owner; declared constructor
  collaborators for every non-trivial class; declared the launch contract's files
  and put the two domain enums in `lib/src/models/` rather than `api/models/`;
  and made the approval registry's `respond` session-keyed rather than
  client-bound.
- **Declined by the user:** violation 9 — replacing the client's
  `harnessSupportsPromptAttachments` branch with a `PluginMetadata` capability
  flag. Architecturally correct, but it expands scope into shared wire types, all
  four descriptors, and client code beyond this plan's three files, and the gate
  is already dated and temporary. The user decided on 2026-08-04 to widen the
  gate as planned; that decision supersedes the review and must not be reopened
  without new evidence.
- **Note:** the reviewer confirmed the protocol-verification changes are
  architecturally sound and flagged none of them, and treated the three
  user-locked decisions as binding.

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [x] | 1/17 | `claude-code-support` | `🌱 [claude-code-plugin] docs: plan Claude Code harness plugin [step 1/17]` | 1,200-1,400 | [PR #737](https://github.com/sesori-ai/sesori_apps_monorepo/pull/737) merged; see the verification log for the measured diff |
| [x] | 2/17 | `claude-code-plugin-protocol-scaffold` | `⚙️ [claude-code-plugin] feat(claude): ground protocol and scaffold package [step 2/17]` | 1,100-1,500 | [PR #752](https://github.com/sesori-ai/sesori_apps_monorepo/pull/752) merged 2026-08-09 as `7e460bc9`; see the verification log for the measured diff |
| [x] | 3/17 | `claude-code-plugin-stream-client` | `⚙️ [claude-code-plugin] feat(claude): add stream-json transport [step 3/17]` | 1,200-1,500 (recorded overage) | [PR #792](https://github.com/sesori-ai/sesori_apps_monorepo/pull/792) merged 2026-08-09 as `9f139f8f`; see the verification log for the measured diff |
| [x] | 4/17 | `claude-code-plugin-transcript-catalog` | `⚙️ [claude-code-plugin] feat(claude): enumerate transcript sessions [step 4/17]` | 1,200-1,500 (recorded overage) | [PR #794](https://github.com/sesori-ai/sesori_apps_monorepo/pull/794) merged 2026-08-09 as `42cd0c72`; see the verification log for the measured diff |
| [x] | 5/17 | `claude-code-plugin-content-mapper` | `⚙️ [claude-code-plugin] feat(claude): map content blocks to parts [step 5/17]` | 1,000-1,400 | [PR #795](https://github.com/sesori-ai/sesori_apps_monorepo/pull/795) merged 2026-08-10 as `cfb8cc45` |
| [x] | 6/17 | `claude-code-plugin-history-mapper` | `⚙️ [claude-code-plugin] feat(claude): replay transcript history [step 6/17]` | 1,000-1,400 | [PR #799](https://github.com/sesori-ai/sesori_apps_monorepo/pull/799) merged 2026-08-10 as `d323c3c4` |
| [x] | 7/17 | `claude-code-plugin-tool-tracker` | `⚙️ [claude-code-plugin] feat(claude): track tool lifecycle [step 7/17]` | 1,000-1,400 | [PR #800](https://github.com/sesori-ai/sesori_apps_monorepo/pull/800) merged 2026-08-10 as `c169452b` |
| [ ] | 8/17 | `claude-code-plugin-event-mapper` | `🚧 [claude-code-plugin] feat(claude): map stream events to SSE [step 8/17]` | 1,200-1,500 | [PR #803](https://github.com/sesori-ai/sesori_apps_monorepo/pull/803) open against `main` |
| [ ] | 9/17 | `claude-code-plugin-approvals` | `🚧 [claude-code-plugin] feat(claude): add permission and question registry [step 9/17]` | 1,100-1,500 | Not started |
| [ ] | 10/17 | `claude-code-plugin-session-service` | `🚧 [claude-code-plugin] feat(claude): add session residency and turn queue [step 10/17]` | 1,200-1,500 | Not started |
| [ ] | 11/17 | `claude-code-plugin-catalog-service` | `⚙️ [claude-code-plugin] feat(claude): add model and agent catalog [step 11/17]` | 900-1,300 | Not started |
| [ ] | 12/17 | `claude-code-plugin-plugin-impl` | `🚧 [claude-code-plugin] feat(claude): implement the plugin API surface [step 12/17]` | 1,200-1,500 | Not started |
| [ ] | 13/17 | `claude-code-plugin-descriptor` | `⚙️ [claude-code-plugin] feat(claude): add descriptor and lifecycle [step 13/17]` | 1,100-1,500 | Not started |
| [ ] | 14/17 | `claude-code-plugin-activation` | `⚙️ [claude-code-plugin] feat(claude): register the Claude Code harness [step 14/17]` | 250-500 | Not started |
| [ ] | 15/17 | `claude-code-plugin-client-polish` | `🌿 [claude-code-plugin] feat(client): add Claude Code branding [step 15/17]` | 400-800 | Not started |
| [ ] | 16/17 | `claude-code-plugin-e2e` | `🌿 [claude-code-plugin] docs: record Claude Code live verification [step 16/17]` | 200-500 | Not started |
| [ ] | 17/17 | `claude-code-plugin-retire` | `🌱 [claude-code-plugin] docs: retire Claude Code plugin plan [step 17/17]` | 50-200 | Not started |

## Exact PR Titles

1. `🌱 [claude-code-plugin] docs: plan Claude Code harness plugin [step 1/17]`
2. `⚙️ [claude-code-plugin] feat(claude): ground protocol and scaffold package [step 2/17]`
3. `⚙️ [claude-code-plugin] feat(claude): add stream-json transport [step 3/17]`
4. `⚙️ [claude-code-plugin] feat(claude): enumerate transcript sessions [step 4/17]`
5. `⚙️ [claude-code-plugin] feat(claude): map content blocks to parts [step 5/17]`
6. `⚙️ [claude-code-plugin] feat(claude): replay transcript history [step 6/17]`
7. `⚙️ [claude-code-plugin] feat(claude): track tool lifecycle [step 7/17]`
8. `🚧 [claude-code-plugin] feat(claude): map stream events to SSE [step 8/17]`
9. `🚧 [claude-code-plugin] feat(claude): add permission and question registry [step 9/17]`
10. `🚧 [claude-code-plugin] feat(claude): add session residency and turn queue [step 10/17]`
11. `⚙️ [claude-code-plugin] feat(claude): add model and agent catalog [step 11/17]`
12. `🚧 [claude-code-plugin] feat(claude): implement the plugin API surface [step 12/17]`
13. `⚙️ [claude-code-plugin] feat(claude): add descriptor and lifecycle [step 13/17]`
14. `⚙️ [claude-code-plugin] feat(claude): register the Claude Code harness [step 14/17]`
15. `🌿 [claude-code-plugin] feat(client): add Claude Code branding [step 15/17]`
16. `🌿 [claude-code-plugin] docs: record Claude Code live verification [step 16/17]`
17. `🌱 [claude-code-plugin] docs: retire Claude Code plugin plan [step 17/17]`

## Execution Rules

- **Only one PR is open at a time.** Never stack a successor on an open
  predecessor. Build the next step locally on its own branch and open its PR only
  after the current one merges, so every PR targets `main`.
- After a PR merges, continue automatically with the next numbered step without
  waiting for another user prompt. Stop only for a material decision or blocker.
- Merge in numeric order; each step must remain independently buildable and
  valid at its own base.
- Count additions plus deletions, including generated files and tests, against
  each PR base. Target no more than 1,500 changed lines per PR as a soft cap;
  split coherently first or record why an expected overage is unavoidable.
- Do not merge adjacent steps merely because one is small.
- The app stays unaware of the plugin until Step 14, so no intermediate state
  violates the full-`BridgePluginApi` rule. Wave-1 workspace, Makefile, and CI
  plumbing still lands with the scaffold in Step 2, otherwise Steps 2–13 are
  locally unbuildable and invisible to CI.
- Generated files are regenerated, never hand-edited.
- Every production class introduced by a step has a production consumer in that
  step, or an explicitly named next-step consumer recorded in the PR body.
- Run focused tests, owning-package full tests, `dart analyze --fatal-infos`,
  `git diff --check`, and `aristotle-impl-review` for Steps 2–14. Steps 1 and
  15–17 need only their own relevant validation.
- Open every PR with `--body-file` and start monitoring with `pr-monitor:watch`.

## Verification Log

- Step 1/17 (2026-08-04): authored the plan, tracker, and protocol skeleton, and
  registered mobile-mcp in `.mcp.json` for the Step 16 simulator run. The fixed
  slug, seventeen exact titles, lifecycle boundaries, delivery order, and
  changed-line estimates were cross-checked. Referenced repository symbols were
  verified to exist before being cited: `SteadyPluginLifecycle`,
  `BridgeDerivedProjectsPluginApi`, `PersistedSessionCleanupApi`,
  `PluginSetupAuthenticationRequired`, `SemanticVersion`,
  `resolveUserHomeDirectory`, `maxToolOutputLength`,
  `maxInlineMessageAttachmentBytes`, `BufferedUntilFirstListener`,
  `PluginAuthenticationRequiredException`, `PluginStartAbortedException`,
  `HostProcessCommandExecutor`, `PluginValueOption`, and `PluginQuestionInfo`.
  `.mcp.json` parses and `git diff --cached --check` passes. No Dart or Flutter
  suites were run for this documentation-only step.

  **Changed-line measurement, corrected twice.** The figure first recorded here
  was 997, taken from `git diff --cached --numstat` against a partially staged
  tree — it undercounted. The correction to 1,784 was also wrong, measured
  against a stale local `main` that was two commits behind the remote, which
  added unrelated diff. The authoritative command is

      git diff $(git merge-base origin/main HEAD) --numstat

  which reports **1,300 changed lines** for this step including the review-fix
  commits. Both earlier numbers are superseded; the method is recorded so the
  figure can be re-derived rather than trusted.

- Step 2/17 (2026-08-04): verified the protocol against a live `claude` 2.1.221
  and `@anthropic-ai/claude-agent-sdk@0.3.221`, rewrote `PROTOCOL.md` from
  observation, created `bridge/sesori_plugin_claude` with its Wave-1 workspace,
  Makefile, and CI plumbing, and added the verified launch contract
  (`ClaudeLaunchSpec`, `ClaudePermissionMode`, `ClaudeEffortLevel`).
  `dart pub get` at `bridge/`, `dart analyze --fatal-infos`, all 12 package
  tests, and `git diff --check` pass. Measured with the authoritative command
  recorded under Step 1, `git diff $(git merge-base origin/main HEAD) --numstat`
  reports **1,078 changed lines** after the rebase onto merged `main` — just
  under the 1,100-1,500 estimate and well below the 1,500-line soft cap. An
  earlier figure of 987 was measured against the pre-merge Step 1 base and is
  superseded.

  Registered the new package in the `update-dependencies` skill's inventory:
  the workspace list, the environment-constraint table, the per-package
  `dart pub outdated` block, the bridge dependency order, and the member count
  in the analyze step. That skill's own Phase 0 warns that a package missing
  from its tables is the workflow's most common failure and names one that was
  missed for weeks, so this lands with the package rather than later. Verified
  by running the skill's Phase 0.1 discovery and reconciling: every pubspec in
  the repository is now named in the inventory.

  DTOs were moved out of this step into the steps that consume them. Measured
  against the Codex analog, Freezed expands roughly tenfold
  (`codex_rollout_dto.dart`: 326 source lines, 3,286 generated), so the original
  bundle of stream, control, and transcript DTOs would have exceeded the cap
  several times over while having no production consumer in the same PR. Step
  estimates for 3, 4, and 5 were raised to absorb them and the step total is
  unchanged.

- Step 3/17 (2026-08-04): added `ClaudeStreamMessage` with its dispatching
  parser, `ClaudeStreamClient`, the host process seam, `FakeClaudeProcess`, and
  the `claude_testing.dart` barrel. `dart analyze --fatal-infos`, all 59 package
  tests, and `git diff --check` pass. Architecture implementation review of
  `origin/main..claude-code-plugin-stream-client` returned `APPROVED` with no
  actionable findings.

  The transport was also driven against the real `claude` 2.1.221: the
  `initialize` handshake completed in ~1.1 s returning 5 models and 66 commands,
  effort levels came back as first-party per-model data, and teardown exited the
  process with 143 (SIGTERM), confirming the graceful path. That run also
  produced the `system/init` timing correction below.

  Recorded overage: **1,793 changed lines** against the 1,500 soft cap, measured
  after the rebase onto merged Step 2 with
  `git diff $(git merge-base origin/main HEAD) --numstat`. The earlier 1,767-line
  figure was measured before the final tracker handoff onto merged `main` and is
  superseded. The rationale is in `PLAN.md` under Step 3: no coherent split
  exists because the parser's only production consumer is the transport itself,
  so splitting would ship unconsumed architecture. Tests are 0.67x source,
  below the repository's 1.2-1.9x norm, so the overage is production code rather
  than test bulk.

- Step 4/17 (2026-08-04): added `ClaudeTranscriptRecord`, `ClaudeTranscriptApi`,
  `ClaudeSessionRecord`, and `ClaudeTranscriptCatalogRepository`.
  `dart analyze --fatal-infos` and all 95 package tests pass after synchronization
  with merged Step 3.

  Verified live against the developer's real `~/.claude`: **1,888 transcript
  files reduced to 180 sessions**, 143 titled, all 180 carrying a git branch,
  created time, and updated time, across 42 distinct projects; ordering
  newest-first and per-project pagination both confirmed. 37 ms to enumerate
  paths and 993 ms to scan headers inside `Isolate.run`. Synthetic fixtures
  alone would not have caught the filename finding below.

  1,620 changed lines against the Step 3 base, 120 over the 1,500 soft cap. The
  generated JSON boundary required by implementation review cannot be split from
  its only production consumer; one flat tolerant DTO keeps the overage smaller
  than a generated union over every observed record type.

- Step 5/17 (2026-08-09): added the generated tolerant
  `ClaudeContentBlockDto` union and `ClaudeContentMapper` for text, thinking,
  tool use/results, inline images, metadata degradation, unknown blocks, exact
  tool-output bounds, and aggregate attachment budgeting. Generated DTO strings
  do not expose tool or image payloads. `dart analyze --fatal-infos`, all 107
  package tests, codegen, and `git diff --check` pass. Architecture
  implementation review of the Step 5 branch against Step 4 returned
  `APPROVED` with no findings. The measured diff is 1,317 changed lines, within
  the 1,000-1,400 estimate and under the soft cap.
- Step 6/17 (2026-08-09): added generated nested transcript message DTO fields,
  repository-normalized sealed user/assistant/unreplayable record variants, an
  isolate-backed full transcript read, and top-level `ClaudeHistoryMapper`.
  Replay groups assistant records by nested Anthropic message id, preserves
  ordered user/assistant identity, timestamps, model and provider fields, folds
  persisted tool results into their originating tool part, and skips internal
  context and non-visible records. The mapper is a pure transformation over
  loaded records; missing/read failures remain thrown for Step 12 to translate
  into a cause-preserving `PluginOperationException` at the plugin API boundary,
  instead of returning an empty history. Full-tree structural surveys resolved
  the attachment and identity questions without printing paths, ids, prompts,
  transcript text, or tool payloads.

  `dart analyze --fatal-infos`, all 110 package tests, codegen, and
  `git diff --check` pass. Two architecture implementation-review passes found
  one flattened role model and one invalid assistant-id fallback; both findings
  were applied, and the second review reported no other in-scope violations.
  The measured production/test diff is 800 changed lines against Step 5, below
  the 1,000-1,400 estimate and the 1,500-line soft cap.

- Step 7/17 (2026-08-10): added collaborator-free `ClaudeToolTracker` with
  per-session and per-content-block correlation, ordered `input_json_delta`
  buffering, complete-block repair, direct `tool_result` matching, sticky
  terminal states, immutable output attachments, exact session cleanup, and
  one-shot diff decisions for Claude's four first-party edit tools. Malformed
  partial JSON remains observable without logging its source-bearing payload,
  and unmatched results do not invent orphan tool cards.

  `dart analyze --fatal-infos`, all 121 package tests, and `git diff --check`
  pass. Architecture implementation review first rejected raw edit-tool string
  decisions; the tracker now parses names into a closed tool-kind enum at its
  boundary, and the second review approved the step with no remaining findings.
  Cubic review identified that a duplicate result could replace the first
  terminal status and payload; terminal results are now sticky across duplicate
  frames, with a regression test. After synchronization with merged Step 6, the
  measured diff is 617 changed lines
  against `origin/main`, below the 1,000-1,400 estimate and the 1,500-line soft
  cap.

- Step 8/17 (2026-08-10): added top-level `ClaudeEventDispatcher` over the content
  mapper and tool tracker, plus typed stream-event, retry, assistant-error,
  result-subtype, and terminal-reason parsing at the transport boundary. Live
  events now carry schema-valid message/part/status payloads; resolved assistant
  model plus Claude/Anthropic identity; text and thinking deltas; sticky tool
  completion; one-shot diff and todo refresh signals; privacy-safe retry and
  error presentation; exact turn/session cleanup; and subagent suppression.
  A direct test proves complete live assistant/tool shapes equal Step 6 history
  replay shapes.

  Live CLI 2.1.226 probes captured both the declared budget-exhaustion result
  and the non-obvious API failure whose subtype remains `success` while
  `is_error` is true. `PROTOCOL.md` records the redacted shapes; raw backend
  error strings are retained only at the plugin transport boundary and are not
  forwarded to clients. Review renamed the stateful pipeline owner from mapper
  to dispatcher and deferred assistant envelopes until visible content exists,
  preserving live/history parity for redacted or unknown-only messages.
  `dart analyze --fatal-infos`, all 132 package tests,
  and `git diff --check` pass. Architecture implementation review approved the
  uncommitted Step 8 scope with no findings. The measured implementation/test
  diff before this documentation is 1,120 changed lines, below the 1,200-1,500
  estimate. After synchronization with merged Step 7, the final measured diff
  including plan artifacts is 1,196 changed
  lines, also below the estimate and the 1,500-line soft cap.

## Findings And Plan Deltas

- **2026-08-04 — Most of `projects/` is not sessions:** the Step 2 capture came
  from one freshly created transcript, which made the tree look uniform. In a
  real `~/.claude`, 1,695 of 1,888 files are subagent transcripts named
  `agent-<slug>-<hex>.jsonl` living in the same directories. Enumerating every
  `.jsonl` would have reported roughly ten times too many sessions with
  non-id ids. The catalog now filters on a UUID filename stem **and** on records
  not all being `isSidechain` — 5 of 120 sampled UUID-named files were entirely
  sidechain, so neither filter alone suffices. `PROTOCOL.md` section 9 is
  corrected.
- **2026-08-04 — Sixteen record types, not six:** the survey found `mode`,
  `permission-mode`, `bridge-session`, `file-history-snapshot`,
  `file-history-delta`, `pr-link`, `agent-name`, `started`, `result`, and
  `system` beyond the six recorded. This is the concrete justification for
  tolerant unknown absorption. `mode`/`permission-mode` are worth a look at Step
  11; `pr-link` carries PR metadata the session list already has a slot for, and
  is noted as a later opportunity rather than scope.
- **2026-08-04 — Enumeration must be bounded:** the surveyed tree held 1,060 MiB
  across 1,888 files (largest single transcript 17.6 MiB), so full reads are not
  viable. Everything the catalog needs is in the first ≤50 lines (title record
  median line 13), so the API reads a bounded 64-line header and takes
  `updatedAt` from file mtime.
- **2026-08-04 — Step 4 uses one generated wire DTO plus hand-written domain
  variants:** the open record-type set makes absorption the real work, and the
  four catalog-relevant types share one field set. A generated union measured at
  roughly 800 extra lines, so the generated JSON boundary is one tolerant flat
  DTO that maps into content, title, and unknown domain variants. This satisfies
  the generated parsing rule without flattening domain state or modelling all
  sixteen observed wire types independently.
- **2026-08-04 — Titles are 79% covered and stay first-party:** `ai-title` was
  present in 143 of 180 real sessions. `last-prompt.lastPrompt` would reach
  about 88% but is the user's own prompt text, so it is deliberately not used as
  a title fallback; untitled sessions map to a null title. Revisit only if this
  looks wrong in the Step 16 live run.
- **2026-08-09 — Attachment records are internal context, while user images are
  message blocks:** the full-tree shape survey found only reminder, skill, plan,
  hook, directory, and related CLI context variants under `attachment`; pasted
  images appeared under `user.message.content`. History therefore skips
  attachment records and maps image blocks through `ClaudeContentMapper`.
- **2026-08-09 — Assistant identity is nested and groups records:** one
  `message.id` grouped 1-18 assistant records and never equaled the top-level
  record UUID in the survey. History groups on nested `message.id`, never falls
  back to record UUID, and keeps an identity-less assistant record attributable
  to the catalog but unreplayable.
- **2026-08-05 — `always` must filter suggestions, not echo them (from PR #752
  review):** the plan said `always` echoes the request's own
  `permission_suggestions`, treating "what the backend suggested" as a safe
  ceiling. It is not. The SDK's `PermissionUpdate` union includes `setMode`,
  `addDirectories`, and a `destination` of `userSettings`/`projectSettings`, and
  the **only** suggestion actually observed for a file write was
  `{type: setMode, mode: acceptEdits, destination: session}`. A naive echo would
  turn one "always" tap on a single `Write` into session-wide auto-accept, or
  write a rule outliving the session. Now decided: echo session-scoped `addRules`
  only, degrade to a plain allow when nothing qualifies. Success Criterion 3 and
  `PROTOCOL.md` section 5 are rewritten; Step 9 gains a per-variant test
  requirement. Credit to cubic, which caught that the normative table contradicted
  the design note directly beneath it.
- **2026-08-05 — Launch spec matches the SDK's `=`-joined id flags:** review
  flagged `--resume`; checking `sdk.mjs` showed `--session-id` is `=`-joined too.
  Both now match, with a test that fails if either splits back into two tokens.
- **2026-08-05 — Codegen machinery removed from the scaffold:** the package
  carried `freezed`, `json_serializable`, `build_runner`, `build.yaml`, and
  `path` with nothing using them, so `make codegen` ran a generator over zero
  files. Step 4's decision to hand-write transcript envelopes as well means they
  may never be needed. Removed; they return in the step that first generates
  something, and `path` returns in Step 4 where it is actually used.

- **2026-08-04 — Multi-turn residency PROVEN:** PR review challenged the
  assumption that one process serves several turns, noting the CLI docs describe
  stream-json as producing a final result and exiting. Verified directly: two
  turns ran on one process, `poll()` confirmed it alive between them, both
  returned `result` frames, and it exited 0 only when stdin was closed. The
  architecture's residency model holds. A second `system/init` arrived with the
  second turn, independently confirming that frame is turn-triggered.
- **2026-08-04 — `--session-id` pre-binding PROVEN:** a run with a pre-generated
  UUID produced `<that uuid>.jsonl`, and every record inside reported the same
  `sessionId`. The plan still treats init's reported id as authoritative and
  cross-checks it, because the identity chain is load-bearing for enumeration,
  replay, resume, and delete.
- **2026-08-04 — Respawn-state durability is an open question:** PR review asked
  whether `--resume` restores the last-used model and whether an `always` grant
  survives a respawn. Neither is answered yet; both are now recorded in PLAN.md
  as pre-Step-10 evidence items with E2E rows 18a and 18b.
- **2026-08-04 — Prompt-attachment gate stays a client branch (user decision):**
  plan review wanted a `PluginMetadata` capability flag replacing
  `harnessSupportsPromptAttachments`. The user chose to widen the existing dated
  gate instead, keeping this series scoped. Noted for whoever does the capability
  migration later: a plain `@Default(false)` is wrong, because a new app against
  an older bridge would silently lose OpenCode attachments — the field needs to
  be nullable so absence can mean "old bridge, apply the legacy rule".
- **2026-08-04 — One PR open at a time (user decision):** successors are built
  locally and their PRs open only after the current PR merges. PR #739 (step 2)
  was closed for this reason and reopens against `main` after #737 merges; its
  branch and commits are intact.

- **2026-08-04 — Route decision:** Bespoke stream-json over stdio rather than the
  `claude-agent-acp` Node adapter. The adapter would add a Node runtime
  dependency and hide protocol surface the parity scope needs.
- **2026-08-04 — Scope decision:** Full core parity in this series — sessions,
  streaming, tools, permissions and questions, plan mode, models, interrupt,
  resume with history, slash commands, and images.
- **2026-08-04 — Effort variants deferred to evidence:** Reasoning-effort
  variants ship only if Step 2 finds first-party per-session support in the
  pinned CLI. Step 11 records the decision either way.
  **Resolved in Step 2: variants ship.** The initialize response declares
  `supportsEffort` and `supportedEffortLevels` per model, so variants are
  first-party data with no hardcoded catalog and no version gate.
- **2026-08-04 — `--permission-prompt-tool stdio` is mandatory:** Step 2 proved
  that without this flag the CLI silently auto-denies permission-gated tools —
  no control request, no error, `result.subtype: "success"`, and the refusal
  visible only in `result.permission_denials`. The flag is absent from
  `claude --help` and was found in the SDK's argv builder. It is not optional
  and Step 3 must cover it.
- **2026-08-04 — Permission/question split is first-party:** the `can_use_tool`
  request carries `requires_user_interaction`, which replaces the planned
  hardcoded `AskUserQuestion`/`ExitPlanMode` name list. Two new safety
  constraints also apply: `suppress_always_allow_rule` forbids offering
  "always", and `decision_reason` may carry ANSI escapes.
- **2026-08-04 — Agent picker drives permission modes:** the user confirmed the
  planned mapping despite Claude having a first-party `agents` concept. The
  initialize response's `agents` array is deliberately not mapped to
  `getAgents`; surfacing it is a follow-up outside this series.
- **2026-08-04 — Catalog comes from one handshake:** the `initialize` response
  returns commands, agents, models, and account together, so the catalog service
  needs no separate startup probes and `list_models` is a refresh path only.
- **2026-08-04 — Auth probe simplified:** `claude auth status --json` reports
  `loggedIn`, so the planned zero-token init-probe fallback is unnecessary. The
  same payload carries PII (email, org) that must never be logged.
- **2026-08-04 — `rename_session` exists:** the control API supports renaming, so
  Step 12's optimistic-only rename should be revisited against it.
- **2026-08-04 — `system/init` is turn-triggered, not spawn-triggered:** proved in
  Step 3 by driving the real CLI. Nothing in the connect path may depend on the
  `init` frame; the `initialize` control response is the only connect-time
  catalog. Capability detection is therefore unavailable until a turn has run,
  which is safe for `interrupt.cancel_queued` because older CLIs ignore that
  field rather than rejecting it.
