# MCP management tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Branch/base: `sesori/mcp-approvals-issue`, `55c7d4cbba`, in the provided `copper-heron` worktree.
- Current step: 1/12, reviewed and ready for publication. Implementation has not started.
- User decisions: Claude Code and Codex first; existing servers and offered connectors only; preserve an extension path for later server creation without implementing it now.
- Plan PR: the step-1 PR containing this tracker; publication reference will be recorded at the next execution update.
- Architecture plan review: **approved** on 2026-10-13.

## Delivery

The exact titles, scope, estimates, and dependency order are in `PLAN.md`.

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/12 | Publish reviewed plan | Reviewed; publishing | Source/doc inspection; read-only CLI help/schema checks; architecture approval |
| 2/12 | Freeze priority native contracts and capability evidence | Not started | — |
| 3/12 | Claude scoped inventory and bridge contract | Not started | — |
| 4/12 | Shared phone/desktop inventory and details | Not started | — |
| 5/12 | Claude actions and native authentication | Not started | — |
| 6/12 | Shared authentication and external-action presentation | Not started | — |
| 7/12 | Claude approvals and form/URL elicitation | Not started | — |
| 8/12 | Codex inventory/actions/authentication | Not started | — |
| 9/12 | Codex forms and offered connectors | Not started | — |
| 10/12 | Secondary harness support and explicit gaps | Not started | — |
| 11/12 | Reconcile regression/capability documents | Not started | — |
| 12/12 | Execute L4 plus named external/package checks; retire | Not started | — |

## Evidence and decisions

- 2026-10-13: inspected current plugin contracts, Claude process/control ownership, Codex approvals, shared question/permission models, client browser auth ownership, bridge routing, harness capabilities, and regression proof rules.
- Verified local CLI identities: Claude Code 2.1.296 and Codex 0.162.1. Only version/help and schema generation were run; no user MCP server was queried, connected, installed, or authorized.
- Repository target/minimum versions differ from the installed CLIs. Native target/minimum captures, real OAuth, packaged clients, and end-to-end checks are **Not run** and belong to implementation/qualification.
- External documentation links and their scope are recorded in the plan. Claude terminal requirements, native elicitation frames, Codex callback completion, connector setup contracts, and old-client event handling remain explicit step-2 gates.
- Additional product analytics events are deferred; existing screen reporting applies. No server/tool/connector identities enter analytics.
- No reduction of the retirement matrix has been requested or accepted.

## Review record

- 2026-10-13: `architecture-plan-review` approved the initial design at base `55c7d4cbba`; specificity gate passed, client/bridge/shared rules applied, and no architectural findings were reported. No design changes were required.
- Review explicitly leaves native method/version support, OAuth continuation behavior, connector setup URLs, and released-client event handling to step 2. It does not establish runtime feasibility or successful authentication.

## Verification log

- Step 1: Markdown local links, 12 exact series titles, tracker order, user scope/future-creation boundaries, and staged `git diff --check` passed. The publication diff is 250 authored lines; no generated files or production files changed.
- Production tests and implementation qualification are not part of this planning-only change and remain **Not run**.
