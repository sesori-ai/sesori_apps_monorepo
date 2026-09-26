# Feedback Flow Tracker

Plan: [PLAN.md](PLAN.md). This file lists the fixed series; PR state lives on
GitHub.

## Fixed PR Titles

| Step | Repository | Title |
|---|---|---|
| 1 | monorepo | `🌱 [feedback-flow] Plan the production feedback flow [step 1/9]` |
| 2 | sesori_auth_server | `⚙️ [feedback-flow] Add an authenticated feedback endpoint [step 2/9]` |
| 3.a | monorepo | `🚧 [feedback-flow] Open the rating sheet from Settings and ask for a store review [step 3.a/9]` |
| 3.b | monorepo | `🚧 [feedback-flow] Send private feedback from the rating sheet [step 3.b/9]` |
| 4 | monorepo | `⚙️ [feedback-flow] Add voice input to private feedback [step 4/9]` |
| 5 | monorepo | `⚙️ [feedback-flow] Request the OS review prompt in release builds [step 5/9]` |
| 6 | monorepo | `🚧 [feedback-flow] Show the rating sheet automatically after good sessions [step 6/9]` |
| 7 | monorepo | `🌿 [feedback-flow] Record feedback answers in product analytics [step 7/9]` |
| 8 | monorepo | `🌱 [feedback-flow] Reconcile the feedback regression document [step 8/9]` |
| 9 | monorepo | `🌱 [feedback-flow] Run release coverage and retire the plan [step 9/9]` |

## Dependencies

- Step 3 needs step 2 deployed to the dev auth server for manual checks; its
  tests use a fake API.
- Step 6 needs step 5 for the OS prompt.
- Steps 4, 5 and 7 are independent of each other after step 3.
