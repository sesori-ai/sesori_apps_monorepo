# Quota auto continuation tracker

Plan: [PLAN.md](PLAN.md). Series slug: `quota-auto-continuation`. Total: **6 PRs**.

| Step | State | PR / evidence |
|---|---|---|
| 1 — Plan and support audit | PR open | [#1601][plan-pr]; audit and reviewed plan. |
| 2 — Quota normalization | Not started | Verify payloads across registered harnesses. |
| 3 — Bridge state and scheduler | Not started | Includes typed route, persistence and normal prompt dispatch. |
| 4 — Shared chat controls | Not started | Inline hint, indicator and three-dot toggle on phone and desktop. |
| 5 — Regression reconciliation | Not started | Complete affected feature docs and capability matrix. |
| 6 — L4 verification and retirement | Not started | All recorded boundary/platform/provider coverage must pass. |

[plan-pr]: https://github.com/sesori-ai/sesori_apps_monorepo/pull/1601

## Confirmed user decisions

- Auto continuation remains enabled for subsequent quota interruptions in the
  same session, until disabled.
- The chat session's top-right three-dot menu must expose enable/disable.
- Start with per-session opt-in; global configuration is outside this version.

## Proposed implementation defaults

- Two-minute buffer after the reported reset; ordinary prompt text `Continue.`.
- Paused sessions recheck after five minutes, checking readiness before history.
- Durable bridge-owned preference and pending observation; no client timer.
- One attempt per observed reset, with an explicitly accepted possible missed
  attempt if the bridge crashes between consumption and backend acceptance.
- No guessed reset for an unrecognized error/provider or imported old history.

## Validation record

- Read-only local session evidence: complete, scope and limits in EVIDENCE.md.
- Architecture plan review: specificity rejection clarified; second pass
  produced concrete findings, applied directly. Corrected version not re-reviewed.
- PR feedback: clarified reset-based due selection, persisted pause recheck delay,
  readiness-before-history, and wrapped the long documentation tables.
- Follow-up feedback: explicit per-plugin ownership, repository-owned selection,
  service-owned scheduled transitions, and durable cancellation before Stop/archive.
- Plan links / diff checks: passed on the final documentation revision.
- Product tests / live scheduled continuation: not run; no implementation exists.
- Final L4 matrix: not run. Do not retire this plan on the plan PR's checks.
