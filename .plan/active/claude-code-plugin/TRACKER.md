# Claude Code Harness Plugin: Tracker

## Current State

- **Plan slug:** `claude-code-plugin`
- **Implementation base:** `origin/main` at
  `ca7470fd6ead8f7e1ff0d58e3591e7ce25a5314d`
- **Series state:** Step 1/17 in progress
- **Current step:** 1/17 — raise the plan
- **Plan PR:** pending
- **Next action:** open the Step 1 PR, then begin Step 2 protocol ground truth

## Plan Review

- **Verdict:** pending
- **Reviewer:** `aristotle-plan-review`
- **Date:** pending
- **Reviewed scope:** `.plan/active/claude-code-plugin/PLAN.md`
- **Applied corrections:** pending

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [x] | 1/17 | `claude-code-support` | `🌱 [claude-code-plugin] docs: plan Claude Code harness plugin [step 1/17]` | 900-1,100 | PR open |
| [ ] | 2/17 | `claude-code-plugin-protocol-scaffold` | `⚙️ [claude-code-plugin] feat(claude): ground protocol and scaffold package [step 2/17]` | 1,100-1,500 | Not started |
| [ ] | 3/17 | `claude-code-plugin-stream-client` | `⚙️ [claude-code-plugin] feat(claude): add stream-json transport [step 3/17]` | 1,000-1,400 | Not started |
| [ ] | 4/17 | `claude-code-plugin-transcript-catalog` | `⚙️ [claude-code-plugin] feat(claude): enumerate transcript sessions [step 4/17]` | 1,100-1,500 | Not started |
| [ ] | 5/17 | `claude-code-plugin-content-mapper` | `⚙️ [claude-code-plugin] feat(claude): map content blocks to parts [step 5/17]` | 900-1,300 | Not started |
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

- Merge in numeric order. A successor may target its immediate predecessor while
  both are open, but each step must remain independently buildable and valid.
- After a PR merges, continue automatically with the next numbered step without
  waiting for another user prompt. Stop only for a material decision or blocker.
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
  `.mcp.json` parses and `git diff --cached --check` passes. The staged diff is
  997 changed lines; the original 500-800 estimate was corrected to 900-1,100
  rather than published stale. No Dart or Flutter suites were run for this
  documentation-only step.

## Findings And Plan Deltas

- **2026-08-04 — Route decision:** Bespoke stream-json over stdio rather than the
  `claude-agent-acp` Node adapter. The adapter would add a Node runtime
  dependency and hide protocol surface the parity scope needs.
- **2026-08-04 — Scope decision:** Full core parity in this series — sessions,
  streaming, tools, permissions and questions, plan mode, models, interrupt,
  resume with history, slash commands, and images.
- **2026-08-04 — Effort variants deferred to evidence:** Reasoning-effort
  variants ship only if Step 2 finds first-party per-session support in the
  pinned CLI. Step 11 records the decision either way.
