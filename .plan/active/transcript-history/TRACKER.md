# Transcript History — Tracker

This tracker holds decisions, guardrails and the fixed PR titles only. It does
not mirror PR state. Live status is on GitHub:
`gh pr list --state all --search "[transcript-history]"`. Evidence for a
finished step lives in `steps/step-NN.md`, written only by that step's own PR.

## Decisions In Force

- W1–W3 and Q1–Q6 are the user's final decisions of 2026-10-06. Do not reopen
  them.
- P1–P9 are planning decisions from code evidence. See
  [PLAN](PLAN.md#planning-decisions).
- This plan supersedes turn-navigation D30, the derived-only guardrail, and
  the Later Phases F1/F2. See
  [PLAN](PLAN.md#supersession-of-turn-navigation).
- Open: O1 (W2 on v1.8.3 and older apps). Option (a) is suggested. Step 2
  does not open until the user answers.

## Guardrails

- Compression happens inside the AEAD, and only for a request that asked. The
  outer frame and its version byte never change. Control messages and SSE
  events are never compressed.
- `sesori_shared` imports no platform library. zlib calls stay in Layer 0
  transport code: the bridge's `foundation/` codec and `RelayClient` in
  `module_core`.
- Page and route projections (W2, W3, index previews, search excerpts) live
  in `ChatHistoryRepository` or `repositories/mappers/`. Routing handlers do
  no mapping.
- A v1.9.0 peer on either side sees today's bytes and behavior: plain
  responses, full tool parts, and the loaded-only Prompts screen.
- The bridge stores no index. It derives index and search results per request
  with the same shared rule the app uses.
- Nothing the user is reading moves:
  - load-through messages are prepended off-screen;
  - the far-tap spinner appears only after about 150 ms;
  - tool rows expand through a loading body and a size animation.
- Prompt numbers come from the bridge or not at all.

## Steps

| Step | Branch | Title | Target (changed lines) | Needs |
|---|---|---|---|---|
| 1 | `transcript-history/plan` | [1](#fixed-pr-titles) | ≤ 900 | — |
| 2 | `transcript-history/shell-title` | [2](#fixed-pr-titles) | ≤ 250 | 1 |
| 3 | `transcript-history/bridge-deflate` | [3](#fixed-pr-titles) | ≤ 450 | 1 |
| 4 | `transcript-history/app-deflate` | [4](#fixed-pr-titles) | ≤ 400 | 3 |
| 5 | `transcript-history/detail-phases` | [5](#fixed-pr-titles) | ≤ 700 | 2–4 |
| 6 | `transcript-history/shared-turn-rule` | [6](#fixed-pr-titles) | ≤ 600 | 5 |
| 7 | `transcript-history/prompt-index` | [7](#fixed-pr-titles) | ≤ 900 | 6 |
| 8 | `transcript-history/load-through` | [8](#fixed-pr-titles) | ≤ 600 | 5 |
| 9 | `transcript-history/prompts-list` | [9](#fixed-pr-titles) | ≤ 1,000 | 7, 8 |
| 10 | `transcript-history/unloaded-pin` | [10](#fixed-pr-titles) | ≤ 500 | 9 |
| 11 | `transcript-history/prompt-search` | [11](#fixed-pr-titles) | ≤ 800 | 9 |
| 12 | `transcript-history/slim-tools-bridge` | [12](#fixed-pr-titles) | ≤ 700 | 5 |
| 13 | `transcript-history/slim-tools-app` | [13](#fixed-pr-titles) | ≤ 700 | 12 |
| 14 | `transcript-history/regression-docs` | [14](#fixed-pr-titles) | ≤ 300 | 2–13 |
| 15 | `transcript-history/retire` | [15](#fixed-pr-titles) | ≤ 250 | 14 |

Rows 6–13 are provisional and do not start until step 5 merges with its
architecture review. Step 5 may re-split or reorder them; it updates this
table and the titles together.

## Fixed PR Titles

1. `🌱 [transcript-history] Plan transcript wire savings and the prompt index [step 1/15]`
2. `🌿 [transcript-history] Drop the duplicated shell title from transcript pages [step 2/15]`
3. `🚧 [transcript-history] Deflate relay responses for apps that ask [step 3/15]`
4. `🚧 [transcript-history] Ask for deflated relay responses in the app [step 4/15]`
5. `🌱 [transcript-history] Detail the prompt index and slim tool phases [step 5/15]`
6. `⚙️ [transcript-history] Move the prompt-turn rule into sesori_shared [step 6/15]`
7. `🚧 [transcript-history] Serve a session prompt index from the bridge [step 7/15]`
8. `🚧 [transcript-history] Load every message down to a chosen prompt [step 8/15]`
9. `🚧 [transcript-history] List every prompt and jump to unloaded ones [step 9/15]`
10. `⚙️ [transcript-history] Pin the prompt above an unloaded range [step 10/15]`
11. `⚙️ [transcript-history] Search every prompt through the bridge [step 11/15]`
12. `🚧 [transcript-history] Serve slim tool parts and a tool detail route [step 12/15]`
13. `⚙️ [transcript-history] Fetch tool output when a row expands [step 13/15]`
14. `🌱 [transcript-history] Reconcile the regression docs [step 14/15]`
15. `🌱 [transcript-history] Run the L3 matrix and retire the plan [step 15/15]`
