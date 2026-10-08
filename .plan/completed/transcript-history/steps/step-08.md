# Step 8 — Load Through A Prompt

Branch `transcript-history/load-through`. `sesori_shared`, the bridge,
`client/module_core` and docs. No store or database schema change, and no
screen change.

## Scope Delivered

- **Wire (`sesori_shared`):** `POST /session/messages/through` takes
  `SessionMessagesThroughRequest(sessionId, throughSeq, before,
  attachmentDelivery, storedOnly)` and returns the existing
  `MessageWithPartsResponse`.
- **Window:** a sealed `HistoryWindow` in
  `bridge/app/lib/src/repositories/models/` replaces the `limit` and `before`
  pair in `ChatHistoryService` and `ChatHistoryRepository`:
  `HistoryWindowAll`, `HistoryWindowNewest(limit, before)` and
  `HistoryWindowThrough(throughSeq, before)`. The DAO keeps plain parameters.
  `HistoryWindowAll` drops `before` on both the store and archive paths.
- **Repository:** `getSessionMessages` now delegates to the snapshot read,
  so the window switch lives in one place for the store. The archive slice
  switches on the same window. A through range returns
  `throughSeq <= seq < before`; its cursor is `throughSeq` while an older
  message exists and null otherwise, and its count is the users before
  `throughSeq`.
- **DAO:** `getRowsThroughWithSyncState` reads, in one transaction, the sync
  state, the range's rows, their parts through a subquery (no bound-variable
  limit), an exists query for an older message, and the user count.
- **Handler:** `GetSessionMessagesThroughHandler`, registered next to
  `GetSessionMessagesHandler`. An empty session id and
  `throughSeq >= before` are 400s. Freshness, backfill, `storedOnly`, the
  archive read, W2 and the attachment projection stay on the page's path.
- **App (`client/module_core`):**
  - `SessionApi.getMessagesThrough` → `SessionRepository.getMessagesThrough`
    → `SessionDetailLoadService.loadMessagesThrough` →
    `SessionDetailCubit.loadMessagesThrough`.
  - The repository returns a sealed `SessionMessagesThroughResult`. The
    router's route-not-found 404 maps to `SessionMessagesThroughUnsupported`,
    with a dated COMPATIBILITY marker (v1.9.1); the route's own 404 (a
    plugin that lost the transcript) stays a failure (PR review).
  - The cubit returns a sealed `LoadThroughOutcome`: `Loaded`,
    `TargetMissing`, `Failed`, `Superseded` or `Unsupported`. It shares
    `_prependOlderPage` with `loadOlderMessages`; the cursor and
    `userMessagesBeforeOldest` move as one pair and only toward older
    history (null is lowest).
- **Docs:** `docs/regression/session-history-and-recovery.md` gains the
  route's required behavior, failure signals, L5 coverage and sources.
  `docs/HARNESS_CAPABILITIES.md` is unchanged: the route reads only
  normalized history, so every harness behaves the same.
- **Compatibility:** a released app never calls the route. A released bridge
  answers it with the router's bare 404, which the app maps to Unsupported.

## Measurement

`dart run tool/benchmarks/load_through_benchmark.dart`, run from
`bridge/app/`. The synthetic session from step 7 now lives in
`tool/benchmarks/synthetic_session.dart`, shared by both benchmarks: 9,790
messages, 836 prompts, 16.7 MB of message JSON, in a database opened through
`ChatHistoryDatabase.create`. One `HistoryWindowThrough` covers the whole
session. Each stage runs 11 times; the first run is reported separately.
Dart 3.13.4 JIT on an Apple-silicon Mac.

| Stage | Isolate | Median | Max |
|---|---|---|---|
| Bridge read | bridge | 171 ms | 178 ms |
| Bridge encode | bridge | 297 ms | 302 ms |
| Bridge deflate | bridge | 33 ms synthetic, about 250 ms realistic | 33 ms |
| App inflate and decode | UI | 264–268 ms | 275 ms |

- **Stages:** the read is the repository's store path. The encode is
  `jsonEncode` of the body and the `RelayResponse` envelope, then UTF-8.
  The deflate is `ZLibEncoder(raw: true)` over the 17.6 MB plaintext. The
  app stage is `ZLibDecoder(raw: true)`, UTF-8, the envelope's and the
  body's `jsonDecode`, and `MessageWithPartsResponse.fromJson`.
- The synthetic text is repetitive, so it deflates 60× (17.6 MB to 0.3 MB)
  and deflates far faster than real transcripts, which deflate about 4.5×.
  A one-off control deflated 17.6 MB of the repository's Dart source (6×):
  median 250 ms to deflate and 21 ms to inflate. The app's decode is
  dominated by JSON decoding of the 17.6 MB plaintext, which does not depend
  on the ratio.
- **Bridge verdict:** about 0.7 s of read, encode and deflate on the bridge
  isolate for the worst case, which only delays other relay traffic for that
  moment. No UI runs there, so the bridge isolate escape hatch is not added.
- **App verdict, decided for step 9 (this step still decodes on the UI
  isolate):** the load-through response decodes via `Isolate.run` (measured
  264–268 ms on the UI thread on a Mac for the worst-case session).

## Evidence

- Measured with Dart 3.13.4 from Flutter 3.47.5-stable, on code commit
  `bb763f5978938780eb49bbd5da1cd453b9944078` (tree
  `1c06cfedc2a0c79574202782a6b972dd9d427728`). The evidence commit changes
  no code. Every check passed.
- **In `bridge/`:** `dart analyze --fatal-infos` (covers `tool/`).
- **In `bridge/app/`:** `dart test test/bridge/services test/bridge/routing
  test/bridge/orchestrator_registration_test.dart test/bridge/repositories`
  (1,289 tests).
- **In `shared/sesori_shared/` and `client/module_core/`:**
  `dart analyze --fatal-infos`; `client/module_core` tests (391 pass,
  including `session_detail_paging_test.dart` and
  `session_repository_test.dart`).
- **In `client/`:** `dart analyze --fatal-infos` over `module_app_ui`, `app`,
  `desktop` and `module_desktop_core`.
- **New tests:**
  - `chat_history_pagination_test.dart`, "loading through a prompt": the
    range with its cursor and count on the store and store-only paths, the
    cursor ending at the first message, and the archived slice equal to the
    stored one after a purge.
  - `get_session_messages_through_handler_test.dart`: route matching, 400
    for `throughSeq >= before` and for an empty id, and the request
    round-trip.
  - `session_repository_test.dart`, "getMessagesThrough": the range passes
    through, the router's route-not-found 404 reads as Unsupported, and the
    route's own 404 and any other status stay a Failure.
  - `session_detail_paging_test.dart` also checks that a load asked for
    during a refresh is not sent (PR review).
  - `session_detail_paging_test.dart`, "loading through a prompt": the
    prepend takes the range's cursor and count, an already-loaded target
    sends no request, a range without the target reports it missing but
    still prepends, an older bridge and a failure leave the transcript as it
    was, a range landing after a refresh is dropped, and an older page
    landing after a farther range keeps the farther cursor.
  - The pagination file drops the test that compared the snapshot read's
    page with the plain read's, since `getSessionMessages` now is the
    snapshot read, and turns its count twin into a store-only count check.
- **Architecture review:** `architecture-implementation-review`, pass 1
  rejected one finding: the cubit mapped the wire `MessageWithPartsResponse`.
  Fixed in `6184df8f48`, where `SessionMessagesThroughAvailable` carries
  domain fields mapped by the repository; that commit touches only
  `client/module_core`, whose analyze and tests passed again. Pass 2
  approved with no findings.
- **Size:** about 1,370 changed lines, of which 177 are generated Freezed and
  JSON code. That is over the plan's 600-line target. About 300 lines are
  measurement tooling (the load-through benchmark and the move of the
  synthetic session into a shared file, which git shows as a delete and an
  add) and about 330 are tests; production code is about 500 lines. The PR
  stays under the 1,500-line soft cap.
