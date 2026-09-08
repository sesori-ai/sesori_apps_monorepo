# Harness-unavailable chats tracker

Authority: [PLAN.md](PLAN.md). Six sequential PRs; implementation has not started.

| Step | Complexity | Deliverable | Status |
|---|---|---|---|
| 1/6 | 🌱 | Plan unavailable chat recovery | Plan ready for PR; review findings addressed |
| 2/6 | ⚙️ | Identify pre-dispatch harness refusals | Not started |
| 3/6 | ⚙️ | Gate chat actions and retain unsent input | Not started |
| 4/6 | ⚙️ | Explain unavailable chats on both surfaces | Not started |
| 5/6 | 🌿 | Document unavailable chat guarantees | Not started |
| 6/6 | 🌿 | Verify recovery and retire plan | Not started |

Use the exact PR titles in PLAN.md. Step 6 requires the recorded targeted L4
matrix to pass and an EVIDENCE.md summary before retirement. Missing accounts,
devices or live harness coverage keeps the plan active unless the user explicitly
accepts a matrix reduction in PLAN.md.

## Decisions and evidence

- User requests planning, not implementation.
- Scope: all registered harnesses; shared mobile and desktop chat surfaces.
- Root gap confirmed in code: no harness-status gate in chat; generic send
  errors requeue; composer clears on void callback; local queue is cubit-owned.
- No live reproduction or product-code tests have been run for this plan PR.
- Initial review rejected the plan as underspecified. Clarification review
  passed its pre-review gate, then identified concrete architecture findings.
  Applied valid corrections without a third review; bounded exclusions and the
  exact review outcome are recorded in PLAN.md. No approved verdict is claimed.
- No implementation or live verification has started.
