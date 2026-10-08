# Transcript History — Tracker

This tracker holds decisions, guardrails and the fixed PR titles only. It does
not mirror PR state. Live status is on GitHub:
`gh pr list --state all --search "[transcript-history]"`. Evidence for a
finished step lives in `steps/step-NN.md`, written only by that step's own PR.

## Decisions In Force

- W1–W3 and Q1–Q6 are the user's final decisions of 2026-10-06. Do not reopen
  them.
- P1–P15 are planning decisions from code evidence. Step 5 revised P8 (the
  index refetches at every list replacement) and P9 (the load-through is its
  own route) and added P10–P15. See [PLAN](PLAN.md#planning-decisions).
- The user decided on 2026-10-07 that the prompts UI is a separate Prompts
  screen, that the bridge stamps prompt times, and that the list keeps the
  transcript's order.
- O2 and O3 answered by the user on 2026-10-07, both option A: a pin over an
  unloaded prompt shows the preview in the normal pinned bubble, and bridge
  search shows "Searching earlier prompts…" after about 150 ms, then the
  count, with Retry on failure. See [PLAN](PLAN.md#user-decisions-final).
- This plan supersedes turn-navigation D30, the derived-only guardrail, and
  the Later Phases F1/F2. See
  [PLAN](PLAN.md#supersession-of-turn-navigation).
- O1 answered by the user on 2026-10-07: accept. v1.8.3 and older apps show
  reloaded shell rows without the command label; that is cosmetic. See
  [PLAN](PLAN.md#answered-questions).
- L2 answered by the user on 2026-10-08: accept the unexecuted L3 cells and
  the recordings for steps 9, 9b, 10, 11b and 13, and retire. See
  [PLAN](PLAN.md#regression-coverage).

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
- The index, search and tool-output routes read the store or the audit file
  alone, outside the session queue, and never backfill (P10). The index and
  search handlers never answer 404, so a 404 from the index route means an
  older bridge. The app searches and far-taps only on a bridge that sent the
  index, so any search or load-through error, a 404 included, is an ordinary
  failure (search offers Retry).
- A slim tool part is its own `ToolState` variant, never nullable fields plus
  a flag. Keyless `ToolState` JSON decodes as full.
- Choosing index entries for the list, the pin and search matches is
  `module_core` business logic. `module_app_ui` only lays them out.

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
| 9 | `transcript-history/prompts-list` | [9](#fixed-pr-titles) | ≤ 1,300 | 7, 8 |
| 9b | `transcript-history/relay-decode-isolate` | [9b](#fixed-pr-titles) | ≤ 200 | 4 |
| 10 | `transcript-history/unloaded-pin` | [10](#fixed-pr-titles) | ≤ 500 | 9 |
| 11a | `transcript-history/prompt-search` | [11a](#fixed-pr-titles) | ≤ 800 for all of 11; landed at about 800 | 9 |
| 11b | `transcript-history/prompt-search-app` | [11b](#fixed-pr-titles) | split from 11; landed at about 950 | 11a |
| 12 | `transcript-history/slim-tools-bridge` | [12](#fixed-pr-titles) | ≤ 900 | 8 |
| 13 | `transcript-history/slim-tools-app` | [13](#fixed-pr-titles) | ≤ 700 | 12 |
| 14 | `transcript-history/regression-docs` | [14](#fixed-pr-titles) | ≤ 300 | 2–13 |
| 14b | `transcript-history/remove-load-through-unsupported` | [14b](#fixed-pr-titles) | ≤ 150 | 14 |
| 15 | `transcript-history/retire` | [15](#fixed-pr-titles) | ≤ 250 | 14, 14b |

Rows 6–13 are detailed in [PLAN](PLAN.md#phases-2-and-3-architecture) and
start once step 5 merges. Step 9 may split its far tap into its own PR if it
outgrows its target; that split renumbers this table and the titles together.
Step 11 split into 11a (#1900) and 11b (#1903); see `steps/step-11.md`. The
titles of 11a, 11b and 14 below are the merged ones.

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
9b. `🌿 [transcript-history] Decode large relay responses off the UI isolate [step 9b]`
10. `⚙️ [transcript-history] Pin the prompt above an unloaded range [step 10/15]`
11a. `⚙️ [transcript-history] Serve prompt search from the bridge [step 11a/15]`
11b. `⚙️ [transcript-history] Search every prompt from the Prompts screen [step 11b/15]`
12. `🚧 [transcript-history] Serve slim tool parts and a tool detail route [step 12/15]`
13. `⚙️ [transcript-history] Fetch tool output when a row expands [step 13/15]`
14. `🌱 [transcript-history] Reconcile regression docs [step 14/15]`
14b. `🌱 [transcript-history] Remove the unreachable far-tap older-bridge path [step 14b/15]`
15. `🌱 [transcript-history] Run the L3 matrix and retire the plan [step 15/15]`
