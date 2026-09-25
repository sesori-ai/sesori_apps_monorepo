# Desktop Sign-In Rebuild — Tracker

This tracker holds decisions, guardrails and the fixed PR titles only. It
does not mirror PR state: live status is GitHub
(`gh pr list --state all --search "[desktop-sign-in]"`, plus visual-hierarchy
step 38 for the plan PR). Evidence for a finished step lives in
`steps/step-NN.md`, written only by that step's own PR.

## Decisions In Force

- D1 Direction A and D2 the responsive rule are the user's decisions of
  2026-09-25.
- D3–D12 are the review page's recommended defaults, adopted without
  individual answers; the user may override any of them.
- D13 (no held success card) and D14 (a failed launch keeps waiting) are
  planning decisions; see [PLAN](PLAN.md#decisions).

## Guardrails

- The Apple button ships only after the live Apple check in step 4 passes.
- No server change, loopback server, deep link or native Apple path.
- Startup restore never brings the window forward; only signed-out →
  signed-in does.
- "Last used" stores a provider key only.
- Layouts stay per shell; `LoginCubit` stays the one owner of login logic.

## Steps

| Step | Branch | Title | Target (changed lines) | Needs |
|---|---|---|---|---|
| 1 | `desktop-sign-in/plan` | [1](#fixed-pr-titles) | ≤ 600 | — |
| 2 | `desktop-sign-in/handoff-state` | [2](#fixed-pr-titles) | ≤ 900 | 1 |
| 3 | `desktop-sign-in/email-form` | [3](#fixed-pr-titles) | ≤ 600 | 2 |
| 4 | `desktop-sign-in/layout` | [4](#fixed-pr-titles) | ≤ 1,000 | 2, 3 |
| 5 | `desktop-sign-in/handoff-card` | [5](#fixed-pr-titles) | ≤ 800 | 4 |
| 6 | `desktop-sign-in/last-used` | [6](#fixed-pr-titles) | ≤ 500 | 4 |
| 7 | `desktop-sign-in/regression-docs` | [7](#fixed-pr-titles) | ≤ 300 | 5, 6 |
| 8 | `desktop-sign-in/retire` | [8](#fixed-pr-titles) | ≤ 300 | 7 |

## Fixed PR Titles

1. `🌿 [visual-hierarchy] Plan the desktop sign-in rebuild [step 38/50]`
2. `🚧 [desktop-sign-in] Let a browser sign-in be cancelled and reopened [step 2/8]`
3. `🌿 [desktop-sign-in] Share the email sign-in form with the desktop [step 3/8]`
4. `⚙️ [desktop-sign-in] Rebuild the desktop sign-in layout with Apple and email [step 4/8]`
5. `⚙️ [desktop-sign-in] Show the browser handoff card and inline errors on desktop [step 5/8]`
6. `🌿 [desktop-sign-in] Mark the last used sign-in method and bring the window forward [step 6/8]`
7. `🌱 [desktop-sign-in] Reconcile the sign-in regression docs [step 7/8]`
8. `🌱 [desktop-sign-in] Record the sign-in matrix and retire the plan [step 8/8]`
