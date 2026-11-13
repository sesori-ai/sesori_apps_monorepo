# Invocation View: Tracker

This tracker holds decisions, guardrails and the fixed PR titles. It doesn't
mirror PR state; live status is on GitHub:
`gh pr list --state all --search "[invocation-view]"`.

## Decisions In Force

- D1–D8 are the user's decisions of 2026-11-12. Do not reopen them.
- P1–P9 are planning decisions from code evidence; see
  [PLAN](PLAN.md#decisions).
- Step 4: the pinned prompt takes each opener's shape from the same
  `PromptTurnShapes` the row uses, not from `TranscriptPromptSlot`, so the
  pin and the row can't disagree. A card pin compacts to its whole header and
  two lines of arguments.

## Guardrails

- No new `MessagePart` type. `invocation` is an optional field on
  `MessageUser`.
- The app never derives a command from text. It renders the card only from
  bridge data (`invocation`, `commandSource`, the plugin capability) or from
  the source of the command the user staged.
- Bridge core stamps the field in one place, `SessionEventService` through
  `SessionRepository`. The history store keeps it.
- Backend specifics stay in plugin packages.
- Steps 2–4 don't touch files changed by #2541 or #2542, and don't touch
  `docs/HARNESS_CAPABILITIES.md` or `docs/regression/session-turns.md` while
  those PRs are open.
- The card is never a tap target. It keeps the same size in every state, and
  only the status rail under it changes.

## Fixed PR Titles

1. `🌱 [invocation-view] Raise the plan [step 1/12]`
2. `🚧 [invocation-view] Name command and skill runs on the user turn from the bridge [step 2/12]`
3. `⚙️ [invocation-view] Show command and skill runs as an event card [step 3/12]`
4. `⚙️ [invocation-view] Pin and list command and skill runs as their card [step 4/12]`
5. `⚙️ [invocation-view] Name OpenCode command and skill runs [step 5/12]`
6. `🌿 [invocation-view] Name Codex skill runs from the rollout [step 6/12]`
7. `🌿 [invocation-view] Name Pi command and skill runs [step 7/12]`
8. `🌿 [invocation-view] Name Claude Code command runs from the transcript [step 8/12]`
9. `⚙️ [invocation-view] Name ACP command runs and fold the DeepSeek/Hermes argument turn [step 9/12]`
10. to 12. Titled when each step is planned in detail. The total stays 12
   unless a step splits into substeps.
