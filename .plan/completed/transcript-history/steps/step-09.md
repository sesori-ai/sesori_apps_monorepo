# Step 9 — List Every Prompt And Jump To Unloaded Ones

Branch `transcript-history/prompts-list`. `client/module_core`,
`client/module_app_ui` and docs. No bridge, wire or database change.

## Scope Delivered

- **API (`client/module_core`):** `SessionApi.getPromptIndex` posts
  `/session/prompts`. `getMessagesThrough` now decodes through
  `RelayHttpClient.postDecodedInBackground`, which runs the body's
  `jsonDecode` and `fromJson` in `Isolate.run`.
- **Repository:** `SessionRepository.getPromptIndex` returns a sealed
  `SessionPromptIndexResult`: `Available(entries)`, `Unsupported` or
  `Failure(error)`. Like `getMessagesThrough`, only the router's
  `no handler found for` 404 maps to Unsupported (dated COMPATIBILITY
  marker, v1.9.1); both share one `_isMissingRoute` check.
- **Service:** `SessionDetailLoadService.loadPromptIndex` logs a failure.
- **Cubit:** `SessionDetailLoaded.promptIndex` is null until the index
  arrives. It is fetched after a load and after a refresh, only while the
  transcript has older history, and dropped when the transcript is replaced
  or a refresh lands. A late index for a replaced transcript is ignored.
- **List:** `TranscriptPromptListBuilder` merges the index (P15): the index
  decides kind, number and time; a prompt before `olderMessagesCursor` is
  `TranscriptPromptUnloaded(seq, preview)`; an indexed prompt in the loaded
  range the transcript lacks is dropped; loaded prompts the index lacks
  follow it. Search reads the full text of loaded prompts and the preview of
  unloaded ones.
- **Screen (`client/module_app_ui`):** with an index the list ends with
  "{n} prompts" and hides "Load earlier prompts". A tap on an unloaded row
  calls `SessionDetailCubit.loadMessagesThrough`; its row shows a spinner
  after 150 ms, a second tap replaces the target, and on success the screen
  closes onto the prompt as for a loaded row. A failure shows an inline
  notice: retry, "no longer in the session", or "Update the bridge" for an
  older bridge.
- **Compatibility:** a v1.9.0 bridge answers both routes with the router's
  404, so the screen keeps today's loaded-only list and wording.

## Measurement

Measured once on the uncommitted step 9 tree over `origin/main` at
`a377e6ddea`, with a throwaway harness, `dart run
tool/benchmarks/tmp_isolate_decode.dart` from `bridge/app/`, deleted after
the run, so the figures are not reproducible from the checked-in tree. It
decoded the step 7 synthetic session (`tool/benchmarks/synthetic_session.dart`):
9,790 messages, a 16.6 M-character `MessageWithPartsResponse` body.
Dart 3.13.4 JIT on an Apple-silicon Mac, 11 runs, the first discarded. The
UI stall is the longest gap of a 1 ms periodic timer on the calling isolate.

| Stage | Longest stall (median) | Max | Wall (median) |
|---|---|---|---|
| Body decode inline (before) | 95 ms | 95 ms | 95 ms |
| Body decode via `Isolate.run` (now) | 6 ms | 6 ms | 96 ms |
| Envelope inflate, UTF-8, `jsonDecode` and `RelayMessage.fromJson` (inline, unchanged) | 169 ms | 175 ms | 168 ms |

- **Verdict:** `Isolate.run` removes the body's ~95 ms from the UI isolate
  at no wall-time cost. The relay envelope stage in
  `RelayClient._decryptRelayMessage` still runs about 170 ms on the UI
  isolate for the worst-case session. Moving it changes the generic relay
  path for every response, so it is left for a separate decision.

## Deferred

- The "Update the bridge" notice has no "How to update" link.
- The relay envelope decode above.
- Search over unloaded prompts matches only their previews until step 11.

## Evidence

Run on the uncommitted tree that became `60340a272d`, then again after the
review fixes, from each package directory; every check passed.

- `dart analyze --fatal-infos` in `client/module_core`,
  `client/module_app_ui`, `client/app` and `client/desktop`.
- Tests, targeted:
  - `module_core`: `relay_http_client_test.dart` (a background decode runs
    off the calling isolate and still reports bad JSON),
    `session_repository_test.dart` ("getPromptIndex"),
    `test/cubits/session_detail/` (the index arriving, skipped with no older
    history, null on failure, refetched on refresh; the builder's merge),
    `state_defaults_test.dart`, the analytics listener and load service tests.
  - `module_app_ui`: `test/features/session_prompts/` (the full count, the
    delayed spinner and the move, a second tap replacing the first, the
    older-bridge notice), plus the activity-owner and reasoning-modal tests.
  - `app`: `session_detail_body_test.dart`, the "Prompts" group plus the index
    listing an unloaded prompt that a tap loads and moves to.
  - PR review: the open list relists only when the index arrives onto none,
    not on every later change (Freezed's list getter is a new view per read)
    or when a refresh drops it, and a far tap's load landing after the screen
    closed moves nothing. Two `session_detail_body_test.dart` tests fail
    without either fix.
- No database change; generated churn is Freezed and l10n only.
- **Architecture review:** `architecture-implementation-review` pass 1
  approved. Its one non-architecture note (the Unsupported doc claimed asking
  again cannot succeed, though each refresh asks) is fixed in the doc comment.
- **Size:** about 1,130 changed lines, about 76 of them generated, under the
  1,300-line target, so the far tap did not split out.
