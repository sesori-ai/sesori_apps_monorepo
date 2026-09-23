# Quota auto continuation tracker

Plan: [PLAN.md](PLAN.md). Series slug: `quota-auto-continuation`. Total: **6 PRs**.

| Step | State | PR / evidence |
|---|---|---|
| 1 — Plan and support audit | Ready to publish | Local evidence and architecture corrections complete. |
| 2 — Quota normalization | Not started | All registered harnesses considered; support conditional on verified payloads. |
| 3 — Bridge state and scheduler | Not started | Includes typed route, persistence and normal prompt dispatch. |
| 4 — Shared chat controls | Not started | Inline hint, indicator and three-dot toggle on phone and desktop. |
| 5 — Regression reconciliation | Not started | Complete affected feature docs and capability matrix. |
| 6 — L4 verification and retirement | Not started | All recorded boundary/platform/provider coverage must pass. |

## Confirmed user decisions

- Auto continuation remains enabled for subsequent quota interruptions in the
  same session, until disabled.
- The chat session's top-right three-dot menu must expose enable/disable.
- Start with per-session opt-in; global configuration is outside this version.

## Proposed implementation defaults

- Two-minute buffer after the reported reset; ordinary prompt text `Continue.`.
- Durable bridge-owned preference and pending observation; no client timer.
- One attempt per observed reset, with an explicitly accepted possible missed
  attempt if the bridge crashes between consumption and backend acceptance.
- No guessed reset for an unrecognized error/provider or imported old history.

## Validation record

- Read-only local session evidence: complete, scope and limits in EVIDENCE.md.
- Architecture plan review: specificity rejection clarified; second pass
  produced concrete findings, applied directly. Corrected version not re-reviewed.
- Plan links / diff checks: passed on the final documentation revision.
- Product tests / live scheduled continuation: not run; no implementation exists.
- Final L4 matrix: not run. Do not retire this plan on the plan PR's checks.
