# Step 7 — Bridge Prompt Index

Branch `transcript-history/prompt-index`. `sesori_shared`, the bridge and
docs. No app change, and no store or database change.

## Scope Delivered

- **Wire (`sesori_shared`):** `POST /session/prompts` takes the existing
  `SessionIdRequest` and returns `SessionPromptIndexResponse(entries)`,
  oldest first. `SessionPromptIndexEntry` is a sealed Freezed union keyed by
  `kind`:
  - `opener(messageId, seq, number, createdAt, preview)`;
  - `followUp(…, openerMessageId)`.
  There is no fallback kind, as the plan's Complexity Budget says.
- **Handler:** `GetSessionPromptIndexHandler` is registered next to
  `GetSessionMessagesHandler`. It rejects an empty session id with 400 and
  never answers 404, so an unknown or empty session gets an empty list.
- **Service:** `ChatHistoryService.getPromptIndex`. Under P10, the private
  `_readStoredHistory<T>` decides the source (no stored session, the audit
  file of an archived session, or the store) for both the index and
  `_storedOnlyPage`. The index runs outside the session queue and never
  backfills.
- **Repository:**
  - The store path reads every row and part in one snapshot through the
    existing `getPageRowsWithSyncState(limit: null)`. No new DAO read.
  - The archive read, schema check, quarantine and store-only log moved out
    of `getArchivedSessionMessages` into `_readArchivedMessages`, which both
    archive paths now use.
  - `_indexPart` decodes a `stored_file` attachment as its metadata and
    never touches spill files (P11).
- **Mapper:** `repositories/mappers/prompt_index_mapper.dart`
  (`promptIndexOf`) folds with the shared `splitPromptTurns`. It numbers
  every user message from the start of the session; hidden ones take a
  number but get no entry. A prompt in the leading segment is an opener.
  The preview is `promptText` with leading whitespace trimmed, cut to 300
  UTF-16 code units without splitting a surrogate pair, and null rather
  than empty.
- **Docs:**
  - `docs/HARNESS_CAPABILITIES.md` "Transcript turn boundaries": the bridge
    applies the same shared rule. The index reads only normalized history,
    so no harness gap is added.
  - `docs/regression/session-history-and-recovery.md`: the index's required
    behavior (archived sessions included), failure signals and sources.
- **Compatibility:**
  - A released app never calls the route.
  - A released bridge answers it with the router's bare 404. Step 9 maps that
    404 to `SessionPromptIndexUnsupported`.

## Benchmark

`dart run tool/benchmarks/prompt_index_benchmark.dart`, run from `bridge/app/`:

- **Session:** a synthetic session the size of the largest measured one, in a
  database opened through `ChatHistoryDatabase.create`, the bridge's own
  opener: a background isolate in WAL mode. It has 9,790 messages, 836 prompts and
  16.7 MB of message JSON. The replies are completed shell tools and text.
- **What it times:** `ChatHistoryRepository.getPromptIndex`, over 11 runs.
  The first run is reported separately.
- **Result:**
  - median 173–176 ms, max 187 ms;
  - first run 212–218 ms, over two invocations.
- **Verdict:** inside the 300 ms budget. The narrower-projection escape hatch
  is not needed.

## Evidence

- Measured with Dart 3.13.4 from Flutter 3.47.5-stable, on code commit
  `9cb0eae3e2d9fb795852cd345e7f33a2d65a00a8` (tree
  `572659a5e0b29490d3224b53b68e9bdaa4323040`). The evidence commit changes no
  code. Every check passed.
- **In `shared/sesori_shared/`:**
  - `dart test test/models/session_prompt_index_test.dart`: both kinds
    round-trip, the `kind` key is present, and null fields are omitted;
  - `dart analyze --fatal-infos`.
- **In `bridge/app/`:**
  - `dart test test/bridge/routing/get_session_prompt_index_handler_test.dart
    test/bridge/routing/get_session_messages_handler_test.dart
    test/bridge/services test/bridge/repositories/mappers
    test/bridge/orchestrator_registration_test.dart` (589 tests);
  - `dart analyze --fatal-infos`.
- **New tests:**
  - `chat_history_prompt_index_test.dart` covers the store and archive paths
    over one transcript: an opener, a follow-up sent while a tool ran, a
    hidden user message, and an image-only prompt. The image-only prompt is
    listed after its spill files are deleted. The archived index equals the
    stored one after the store is purged. An unknown session lists nothing.
  - `prompt_index_mapper_test.dart` covers:
    - leading-segment prompts are openers;
    - preview trimming;
    - a whitespace-only prompt has a null preview;
    - the 300-unit cut;
    - the cut never splits a surrogate pair.
  - `get_session_prompt_index_handler_test.dart` covers route matching, an
    empty list for an unknown session, and 400 for an empty session id.
- **Architecture review:** `architecture-implementation-review`, pass 1,
  approved with no findings.
- **Size:**
  - about 1,300 changed lines, of which 380 are generated Freezed and JSON
    code;
  - that is about 400 lines over the plan's 900-line target, which counts
    generated code. The authored lines alone are about 920, so the overage is
    the generated output, kept with its source as AGENTS.md requires, and
    stays well under the 1,500-line soft cap.
