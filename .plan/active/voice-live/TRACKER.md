# Live Voice — Tracker

This tracker holds decisions, guardrails and the fixed PR titles only. It does not
mirror PR state: live status is GitHub
(`gh pr list --state all --search "[voice-live]"`). Evidence for a finished step
lives in `steps/step-NN.md`, written only by that step's own PR.

## Decisions In Force

D1–D27 are the user's, from review pages `voice-live-r1` and `voice-live-r2`
(2026-10-30). D28–D33 are planning decisions. See [PLAN](PLAN.md#decisions).

## Guardrails

- No audio or transcript in logs or analytics.
- The bearer token goes only in the upgrade header.
- A failed or cut-off dictation is never sent.
- The chat and composer never relayout for live words.
- Live stays off for the first public release containing this code. The user
  decides when to turn it on.

## User Actions

- Before step 9 testing: set `voice_live_enabled` to `true` and
  `voice_live_presentation` to `focus` in Firebase Remote Config.
- Before the first public release containing this code: set `voice_live_enabled`
  to `false`. It applies at each phone's next cold launch.
- Step 12: run the real-microphone checks on an iPhone and an Android device, and the
  connect-to-`ready` measurement. The exact list is in `steps/step-07.md`, plus
  `steps/step-08.md`.

## PR Titles

| Step | Title |
| --- | --- |
| 1 | `🌱 [voice-live] Raise the live voice plan [step 1/12]` |
| 2 | `🌿 [voice-live] Mark dictated prompts for the agent [step 2/12]` |
| 3 | `⚙️ [voice-live] Send on release with a pencil target and slide-out cancel [step 3/12]` |
| 4 | `⚙️ [voice-live] Add desktop click-to-send controls [step 4/12]` |
| 5 | `🌿 [voice-live] Add the voice mode switch [step 5/12]` |
| 6 | `🚧 [voice-live] Add the realtime voice transport [step 6/12]` |
| 7 | `⚙️ [voice-live] Stream microphone audio as PCM [step 7/12]` |
| 8.i | `🚧 [voice-live] Run dictation over the live session [step 8.i/12]` |
| 8.ii | `🚧 [voice-live] Run dictation over the live session [step 8.ii/12]` |
| 9 | `🚧 [voice-live] Show live words in focus and panel [step 9/12]` |
| 10 | `⚙️ [voice-live] Glide live words to the bubble or box [step 10/12]` |
| 11 | `🌱 [voice-live] Reconcile the voice regression docs [step 11/12]` |
| 12 | `🌿 [voice-live] Run coverage and retire the plan [step 12/12]` |
