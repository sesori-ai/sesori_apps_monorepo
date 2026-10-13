# MCP management tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Branch/base: `sesori/mcp-approvals-issue`, `55c7d4cbba`, in the provided `copper-heron` worktree.
- Current step: 1/12, published and addressing PR review. Implementation has not started.
- User decisions: Claude Code and Codex first; existing servers and offered connectors only; preserve an extension path
  for later server creation without implementing it now.
- Plan PR: [#1940](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1940).
- Architecture plan review: **approved** on 2026-10-13.

## Delivery

The exact titles, scope, estimates, and dependency order are in `PLAN.md`.

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/12 | Publish reviewed plan | PR review | #1940; evidence below |
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

- 2026-10-13: inspected current plugin contracts, Claude process/control ownership, Codex approvals, shared
  question/permission models, client browser auth ownership, bridge routing, harness capabilities, and regression proof
  rules.
- Verified local CLI identities: Claude Code 2.1.296 and Codex 0.162.1. Only version/help and schema generation were
  run; no user MCP server was queried, connected, installed, or authorized.
- Repository target/minimum versions differ from the installed CLIs. Native target/minimum captures, real OAuth,
  packaged clients, and end-to-end checks are **Not run** and belong to implementation/qualification.
- External documentation links and their scope are recorded in the plan. Claude terminal requirements, native
  elicitation frames, Codex callback completion, connector setup contracts, and old-client event handling remain
  explicit step-2 gates.
- Additional product analytics events are deferred; existing screen reporting applies. No server/tool/connector
  identities enter analytics.
- No reduction of the retirement matrix has been requested or accepted.

## Review record

- 2026-10-13: `architecture-plan-review` approved the initial design at base `55c7d4cbba`; specificity gate passed,
  client/bridge/shared rules applied, and no architectural findings were reported. No design changes were required.
- Review explicitly leaves native method/version support, OAuth continuation behavior, connector setup URLs, and
  released-client event handling to step 2. It does not establish runtime feasibility or successful authentication.
- Initial PR #1940 review: clarified exclusion of full authorization/elicitation URLs from diagnostics, wrapped prose,
  made the delivery overview concise while retaining exact titles and scopes below it, and recorded the measured
  publication diff. Feature scope and architectural ownership were unchanged.
- Codex follow-up review: verified the current browser service cancels its previous operation, question replies carry
  only string lists, and the question modal closes before validation. The plan now requires owner-scoped browser reuse
  with a busy result, distinct server/connector inventory variants, and typed form contracts/UI that preserve invalid
  drafts. These clarify the existing scope; arbitrary server configuration remains deferred. Step 7's estimate now
  includes the explicit shared form work.
- Architecture follow-up on 2026-10-13: **approved**, comparing the revised plan against `6fe2ad9944`. The specificity
  gate passed with no findings across client, bridge, and shared boundaries. Browser ownership, distinct catalog offers,
  and typed form layers retain one native pending owner and add no credential store or server-configuration framework.

## Verification log

- Step 1: Markdown local links, 12 exact series titles, tracker order, user scope/future-creation boundaries, and staged
  `git diff --check` passed.
- Initial publication measurement on 2026-10-13: `git diff --numstat 55c7d4cbba c56bb0c02d` reported 202 additions for
  `PLAN.md` and 48 for `TRACKER.md`: two files, 250 authored additions, zero deletions, and zero generated or production
  changes. This snapshot precedes the review formatting changes. It was below the 350–650 estimate because the initial
  prose was unwrapped and the plan used two documents without per-step files; the estimate is a sizing guide, not a
  quota.
- Production tests and implementation qualification are not part of this planning-only change and remain **Not run**.
