# Unavailable chat input-gating tracker

Authority: [PLAN.md](PLAN.md). User-approved scope: **input gating only**.
No queue recovery, submission retention, attachment storage or bridge protocol work.

| Step | Complexity | Deliverable | Status |
|---|---|---|---|
| 1/4 | 🌱 | Plan read-only unavailable chats | [PR #1366](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1366) open |
| 2/4 | ⚙️ | Gate unavailable chats on both clients | Not started |
| 3/4 | 🌿 | Reconcile chat availability regressions | Not started |
| 4/4 | 🌿 | Verify read-only chats and retire plan | Not started |

The earlier six-step proposal was replaced before implementation after the user
explicitly rejected queue-recovery scope. Use the four exact titles in PLAN.md.
Implementation requires the user's implementation request.

## Evidence and review

- Confirmed prevention gap: chat actions do not consume harness management state.
- Earlier architecture review findings relevant to the smaller scope are applied:
  sole state coordinator, metadata-first loading and shared cubit composition.
- Recovery-related PR findings are superseded by the explicit user decision;
  no approved architecture verdict is claimed for the revised plan.
- No product-code changes, live reproduction, or Dart/Flutter suites run.
- Retirement requires the recorded targeted L4 matrix, privacy-safe EVIDENCE.md
  and cleanup. Partial/Blocked/Fail keeps the plan active unless the user accepts
  a matrix reduction explicitly in PLAN.md.
