# Claude Code Harness Plugin: Tracker

## Current State

- **Plan slug:** `claude-code-plugin`
- **Implementation base:** `origin/main` at
  `22f65807` (Step 2 rebased onto it after Step 1 merged)
- **Series state:** Step 1/17 merged; Step 2/17 open for review
- **Current step:** 2/17 — protocol ground truth and package scaffold
- **Plan PR:** [#737](https://github.com/sesori-ai/sesori_apps_monorepo/pull/737),
  merged 2026-08-04 as `6d641532`
- **Next action:** Step 3 stream-json transport

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
  the two catalogs distinct names; moved `ClaudeEventMapper` and
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
| [x] | 2/17 | `claude-code-plugin-protocol-scaffold` | `⚙️ [claude-code-plugin] feat(claude): ground protocol and scaffold package [step 2/17]` | 1,100-1,500 | [PR #752](https://github.com/sesori-ai/sesori_apps_monorepo/pull/752) open; see the verification log for the measured diff |
| [ ] | 3/17 | `claude-code-plugin-stream-client` | `⚙️ [claude-code-plugin] feat(claude): add stream-json transport [step 3/17]` | 1,200-1,500 | Not started |
| [ ] | 4/17 | `claude-code-plugin-transcript-catalog` | `⚙️ [claude-code-plugin] feat(claude): enumerate transcript sessions [step 4/17]` | 1,200-1,500 | Not started |
| [ ] | 5/17 | `claude-code-plugin-content-mapper` | `⚙️ [claude-code-plugin] feat(claude): map content blocks to parts [step 5/17]` | 1,000-1,400 | Not started |
| [ ] | 6/17 | `claude-code-plugin-history-mapper` | `⚙️ [claude-code-plugin] feat(claude): replay transcript history [step 6/17]` | 1,000-1,400 | Not started |
| [ ] | 7/17 | `claude-code-plugin-tool-tracker` | `⚙️ [claude-code-plugin] feat(claude): track tool lifecycle [step 7/17]` | 1,000-1,400 | Not started |
| [ ] | 8/17 | `claude-code-plugin-event-mapper` | `🚧 [claude-code-plugin] feat(claude): map stream events to SSE [step 8/17]` | 1,200-1,500 | Not started |
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

  DTOs were moved out of this step into the steps that consume them. Measured
  against the Codex analog, Freezed expands roughly tenfold
  (`codex_rollout_dto.dart`: 326 source lines, 3,286 generated), so the original
  bundle of stream, control, and transcript DTOs would have exceeded the cap
  several times over while having no production consumer in the same PR. Step
  estimates for 3, 4, and 5 were raised to absorb them and the step total is
  unchanged.

## Findings And Plan Deltas

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
