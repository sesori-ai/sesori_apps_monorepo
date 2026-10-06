# Step 15 — Number And Time Prompts From The Bridge

Branch `turn-navigation/prompt-numbers`. Architecture 12 (absolute prompt
numbers) and Architecture 16 (D38, the ACP prompt accept stamp).

## Plan Claims Checked

- The bridge's `history_messages` table is the only place that knows every
  user message of a session, loaded by the client or not, so it owns the count.
  The count uses the same `json_extract(info_json, '$.role')` the table's other
  queries already read.
- Automation is an assistant message with a non-agent sender, so a role-user
  count never numbers it. A user message the Prompts list hides still counts,
  as the builder's running count already assumed.
- Before this step only DeepSeek overrode `AcpEventMapper.localUserMessageTime`,
  with exactly the body that is now the base. Cursor, Grok and Antigravity
  subclass the mapper without overriding the hook; Copilot, Hermes and OMP use
  the base mapper. So one base change covers every ACP harness.
- `AcpSessionLoader` replays `session/load` history without the hook, so
  prompts read back from the harness stay undated. ACP carries no message time
  to replay.

## Scope Delivered

- `MessageWithPartsResponse.userMessagesBefore` (nullable, with the dated
  compatibility comment); shared DTO regenerated.
- `ChatHistoryDao.countUserMessagesBefore`, counted inside the snapshot read's
  transaction; the plain, stored-only and archived reads carry the same count
  (0 for an unlimited or empty page). The handler sends it.
- Client: `SessionDetailSnapshot.userMessagesBefore`, the older-page record's
  `userMessagesBefore`, and `SessionDetailLoaded.userMessagesBeforeOldest`,
  set by the initial load, a refresh and each older page. The Prompts screen
  numbers from it; null leaves the rows unnumbered, with no client fallback.
- `AcpEventMapper.localUserMessageTime` returns the bridge's observed instant;
  DeepSeek's duplicate override is removed.
- `HARNESS_CAPABILITIES.md` Live timers and Prompts-screen rows, and
  `transcript-turn-navigation.md` behaviour, levels, failure signals, known
  limitations and sources.

## Deviations

- No live headless-bridge run: the count and the stamp are covered by the
  DAO, repository, handler and mapper tests against real Drift and ACP fakes,
  and the numbered rows by fixture renders.
- The tracker has no status column and does not mirror PR state, so row 15 is
  unchanged.

## Evidence

Flutter 3.47.5:

- `dart analyze --fatal-infos` is clean in `bridge/app`, `sesori_plugin_acp`,
  `sesori_plugin_deepseek`, `sesori_shared`, `module_core`, `module_app_ui`,
  `client/app` and `client/desktop`.
- These tests pass:
  - `bridge/app` full suite (3078);
  - `sesori_plugin_acp` mapper, session loader and turn serialization tests;
  - `sesori_plugin_deepseek` (117) and the Antigravity, Copilot, Cursor, Grok,
    Hermes and OMP suites;
  - `sesori_shared` (428);
  - `module_core` cubits, services, API, repositories and consumers (1825);
  - `module_app_ui` session detail and session prompts (393);
  - `client/app` session detail and routing (239);
  - `client/desktop` session detail screen (13).
- Fixture renders of the Prompts screen before and after are on `pr-media`
  under `turn-navigation/prompt-numbers/`.
