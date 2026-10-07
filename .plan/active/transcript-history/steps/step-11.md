# Step 11 — Search Every Prompt

Step 11 lands as two PRs, like step 9:

- **11a (this file's first part):** the shared helpers, the wire contract, the
  bridge route and its benchmark, plus the client's import switch to the
  moved helpers. No app behavior changes.
- **11b:** the app. `SessionRepository.searchPrompts`, `PromptSearchCubit`,
  the presentation-scope capability, both shells and the Prompts view.

The whole step would be about 1,700 changed lines, over the 800-line target
and the 1,500-line soft cap. 11a compiles and ships alone: a released app
never calls the route, and the moved helpers keep the app's loaded-range
search identical.

## 11a Scope Delivered

Branch `transcript-history/prompt-search`. `sesori_shared`, the bridge,
`module_app_ui` imports and docs. No store or database schema change.

- **Shared (`sesori_shared`):**
  - `promptSearchPattern` and `promptExcerpt` moved from
    `module_app_ui/.../session_prompts/prompt_search.dart` to
    `src/transcript/prompt_search.dart`. `promptExcerpt` now returns the wire
    `SessionPromptExcerpt`, so both sides cut alike. `promptExcerptExtent`
    stays in `prompt_spine_row.dart`.
  - Wire: `SessionPromptSearchRequest(sessionId, query)`,
    `SessionPromptSearchResponse(matches)`,
    `SessionPromptSearchMatch(messageId, excerpt)` and
    `SessionPromptExcerpt(before, match, after)`.
- **Handler:** `SearchSessionPromptsHandler` on `POST /session/prompts/search`,
  registered after `GetSessionPromptIndexHandler`. An empty session id is a
  400; it never answers 404.
- **Service:** `ChatHistoryService.searchPrompts` returns nothing for a blank
  query, otherwise reads through `_readStoredHistory` (P10): no stored
  session, the archive's audit file, or the store. Outside the session queue,
  never backfilling.
- **Repository and DAO:**
  - `ChatHistoryDao.getUserMessageRows` reads only user rows
    (`json_extract(info_json, '$.role') = 'user'`) and their parts in one
    transaction; parts are selected through a subquery, so no bound-variable
    limit applies.
  - `ChatHistoryRepository.searchPrompts` decodes parts with `_indexPart`
    (P11: no spill-file reads). `searchArchivedPrompts` filters the audit
    file's user messages in memory.
- **Mapper:** `PromptSearchMapper.matchesOf` keeps rendered user messages whose
  `promptText` holds the pattern and cuts the excerpt with the shared helper.
  No fold (P12).
- **Docs:** `docs/regression/session-history-and-recovery.md` gains the
  route's behavior, L5 coverage, failure signal and sources. The search reads
  only normalized history, so no harness gap is added to
  `docs/HARNESS_CAPABILITIES.md`.
- **Compatibility:** a released app never calls the route; a bridge without
  it answers the router's 404, which 11b maps to `Unsupported`.

## Benchmark

`dart run tool/benchmarks/prompt_search_benchmark.dart`, run from
`bridge/app/`, over step 7's synthetic session: 9,790 messages, 836 prompts,
16.7 MB of message JSON, opened through `ChatHistoryDatabase.create`.

| Query | Matches | Median | Max | First run |
|---|---|---|---|---|
| `build` (every prompt) | 836 | 17 ms | 20 ms | 31 ms |
| `no such words` | 0 | 13 ms | — | — |

Rerun after merging main and the first review wave's fixes (16.9 MB of JSON
after step 12): `build` median 16 ms, max 18 ms, first run 26 ms;
`no such words` median 12 ms. The benchmark now fails if either count is
wrong.

For comparison, the prompt index on the same session measured 134 ms
median in the same run. Reading only user rows keeps search an order of
magnitude below it, so the 250 ms debounce dominates what the user waits for.

## Evidence

- Dart 3.13.4 from Flutter 3.47.5-stable. Every check passed.
- **Measured trees:** the first benchmark and the checks below ran on the
  uncommitted tree committed as `4348f6e99c` (tree `e5bb7af3b8`); the
  evidence-only amend `2ad4317fc2` changed no code. After merging main
  (`ff9a26b09e`), the bridge routing, services, mappers and registration
  tests (1,069) and every `sesori_shared` test (461) passed. After the first
  review wave's fixes, the same bridge tests plus `test/bridge/api` (1,121),
  `dart analyze --fatal-infos` in `bridge/` and `sesori_shared`, and the
  benchmark rerun passed on the uncommitted tree pushed as the next commit.
- **In `shared/sesori_shared/`:** `dart test test/transcript/prompt_search_test.dart`
  (blank query, literal case-insensitive match, excerpt shape, emoji-safe cut,
  wire round-trip); `dart analyze --fatal-infos`.
- **In `bridge/`:** `dart analyze --fatal-infos` (includes `tool/`).
- **In `bridge/app/`:** `dart test test/bridge/routing/search_session_prompts_handler_test.dart
  test/bridge/services test/bridge/repositories/mappers
  test/bridge/orchestrator_registration_test.dart` (580 tests).
  - `chat_history_prompt_index_test.dart`: search finds a query in every
    prompt's text or attachment name and nowhere else (case-insensitive,
    assistant text excluded, blank query empty); the archived search equals
    the stored one after the store is purged; an unknown session finds
    nothing.
  - `search_session_prompts_handler_test.dart`: route matching, an empty
    answer for an unknown session, 400 for an empty session id.
- **In `client/module_app_ui/`:** `flutter test test/features/session_prompts`
  (28 tests); `dart analyze --fatal-infos`.
- **Architecture review:** `architecture-implementation-review`, pass 1,
  approved with no findings.
- **Size:** about 800 changed lines, of which about 385 are generated Freezed
  and JSON code.
