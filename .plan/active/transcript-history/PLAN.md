# Transcript History: Wire Savings And The Prompt Index

## Status

- Planned 2026-10-06 (step 1, #1859).
- Phase 1 is delivered: W2 (#1878), the bridge half of W1 (#1876) and the app
  half (#1879). On dev-account data, deflated pages are about 4.5× smaller on
  average, and the largest first page went from 26.9 KB to 9.6 KB
  (`steps/step-04.md`).
- Step 5 (2026-10-07) details phases 2 and 3 below and records their
  `architecture-plan-review` in [Plan Review](#plan-review). Steps 10 and 11
  each wait on one open question; see [Open Questions](#open-questions).
- Live status lives on GitHub:
  `gh pr list --state all --search "[transcript-history]"`. Evidence for a
  finished step lives in `steps/step-NN.md`, written only by that step's PR.

## Goal

Long sessions must stay cheap to open and easy to navigate.

1. **Wire savings.** Transcript pages cost fewer bytes on the relay link,
   without changing what the user sees:
   - W2 drops the tool title when it repeats the shell command;
   - W1 deflates relay responses for apps that ask;
   - W3 sends tool parts without their output and error, and fetches those
     when the user expands a row.
2. **Prompt index.** The Prompts screen lists every prompt in the session,
   not just the loaded range:
   - the bridge serves a prompt index;
   - tapping an unloaded prompt loads everything down to it in one request;
   - the pinned prompt works above unloaded turns;
   - search covers every prompt through a bridge search query.

## Sources

- Review page `/tmp/sesori-review-serve/prompt-index.html`, round 2: the
  measurements and the user's decisions W1–W3 and Q1–Q6.
- `.plan/active/turn-navigation/` (moving to `.plan/completed/turn-navigation/`
  when PR #1848 merges): D5, D29, D30, D39, D42, the tracker guardrails, and
  the Later Phases F1/F2. This plan supersedes parts of them. See
  [Supersession](#supersession-of-turn-navigation).

### Measured Facts (Review Page, Local Bridge Database)

- 769 sessions, of which 226 have more than one page and 16 have more than
  500 messages. The largest has 9,790 messages, 836 prompts, 196 pages and
  17.4 MB of page JSON.
- Prompts per session: p50 1, p90 3, p99 31, max 836. 59% of messages sit in
  turns that span more than one page; the longest turn has 1,792 messages.
- Prompt length: p50 436 characters, p99 30K.
- A page is 81 KB at the median and 110 KB at p90. An index query takes
  about 20 ms.
- Where page bytes go:

  | Share | Content |
  |---|---|
  | 16.5% | part ids |
  | 14% | tool output |
  | 13.5% | user text |
  | 13.2% | tool title; 12.1 points of it duplicate the shell command |
  | 13.1% | message info |
  | 12.3% | shell command |
  | 9.6% | assistant text |

- Savings over all pages of the largest session:

  | Option | Size |
  |---|---|
  | Today | 17.4 MB |
  | Slim tool parts | 15.1 MB |
  | Deflate | 3.45 MB (91 KB at p90; 13–22 KB per page) |
  | Deflate, slim parts and trims | 2.56 MB |

- Prompt list sizes for the same session:

  | List | Raw | Deflated |
  |---|---|---|
  | Every prompt in full | 2.47 MB | 545 KB |
  | 300-character previews | 668 KB | 86 KB |

## User Decisions (Final)

These are the user's decisions of 2026-10-06, made on the review page. Do not
reopen them.

| ID | Decision |
|---|---|
| W1 | Negotiated deflate at the frame level. A new app asks, an old bridge ignores the ask and replies plain, and an old app never asks. |
| W2 | Drop the tool title when it equals `shellCommand`. No wire change. First verify every place that renders a tool title on v1.9.0 and on `main`. |
| W3 | After compression lands, slim tool parts. A row's output and error are fetched when it expands, opt-in per request, through a new detail route. v1.9.0 apps keep full parts. Expanding must not make content jump: reserve space or animate, with a brief loading state. |
| Q1 | Option A: a bridge prompt index route. |
| Q2 | Fetch the index right after the first page, and only when older pages exist. |
| Q3 | The bridge sends each entry's kind (opener or follow-up). It uses the follow-up rule after that rule moves into `sesori_shared`, so one rule serves both sides. |
| Q4 | Index entries carry a 300-character preview. Search is a bridge query over the full text of every prompt. This reverses turn-navigation D30's "no bridge search route". |
| Q5 | Tapping a far, unloaded prompt loads everything between it and the loaded range in one request. A spinner appears only after about 150 ms. The new messages are prepended off-screen, so nothing visible moves. |
| Q6 | Against a v1.9.0 bridge, keep today's Prompts screen and wording: only loaded prompts are listed, and no pin appears over partial turns. |
| 2026-10-07 | The prompts UI stays a separate Prompts screen, not an in-place fold. The bridge stamps prompt times (turn-navigation D38, landed), and the list keeps the transcript's order. |

## Planning Decisions

Evidence-based choices made for this plan. Each can be revisited with new
evidence; none is a user decision.

| ID | Decision | Why |
|---|---|---|
| P1 | **Order:** W2 and W1 first, then the index and search, then W3. | W2 is trivial. W1 is the largest lever (about 5×) and helps every page and every later route, including the index and load-through responses. The index is the feature. W3 saves only 15–20% more once deflate is on, and it carries the most UI risk. |
| P2 | W2 projects in `ChatHistoryRepository`'s two page-assembly sites: `_assemblePage` and the archived page build in `getArchivedSessionMessages`. The projection is applied after `_rehydrateParts`, next to the existing `MessageAttachmentProjection`. Not in the routing handler, the mapper, the store, or `_rehydratePart`. | Those two sites assemble every page the route returns: live database, fresh, `storedOnly` and archived pages, including rows stored before this change. Their only consumer is the page route, through `ChatHistoryService`. Routing handlers do no mapping (architecture review). Semantic import matching calls `_rehydrateParts` directly, so it stays faithful. The live SSE projection keeps the title. Under W1 the duplicate there is nearly free, and SSE events are small. |
| P3 | W1's ask is a typed `RelayRequest` field, `acceptsDeflatedResponse`, rather than a header. | It avoids a magic header string, and it is decoded at the same boundary as every other request field. v1.9.0 bridges decode `RelayRequest` without key checks (verified in the v1.9.0 `messages.g.dart`), so they ignore the field. |
| P4 | The app asks on every request it sends through `RelayHttpClient` except the attachment fetch (`postWithTimeout`, whose only caller is `SessionApi.getAttachment`). The bridge deflates every routed response for an asking request. There is no size threshold. | One switch instead of a method per route. Session lists, project lists and later routes benefit for free. Tiny responses cost a few bytes and microseconds. Attachment responses carry up to 20 MiB of already-compressed image bytes in base64 (`attachments-and-images.md`); deflating them gains little and would block the bridge isolate for a large image (PR review). |
| P5 | The compressed plaintext is one marker byte `0x00` followed by raw deflate (`ZLibCodec(raw: true)`), inside the AEAD. The outer frame and its version byte `0x01` do not change. | `0x00` is never the first byte of JSON text, and plain plaintexts always start with `{`, so the reader needs no other signal. The relay sees the same frame format. |
| P6 | zlib stays in the Layer 0 transport code of the two packages that already depend on `dart:io`: a plaintext codec in the bridge's `foundation/`, and `RelayClient` in `module_core`. `sesori_shared` holds only the marker constant and the request field. | `sesori_shared` must not import platform libraries. Each side's codec call is about one line. |
| P7 | SSE events and app-to-bridge requests stay uncompressed. | SSE events are small and deflate poorly one by one. Request bodies are small; attachments are already compressed formats. |
| P8 | The prompt index has no revision counter (turn-navigation F1). The app refetches it when it replaces its whole message list, which is every place `SessionDetailCubit` bumps `_transcriptGeneration`: the snapshot build and the refresh (reconnect resyncs and history rewrites arrive as refreshes). Paging older messages and the load-through only prepend, so they never refetch it. An open Prompts screen keeps its opening snapshot, as turn-navigation already requires. It relists only through that screen's snapshot-refresh rule, which step 9 widens from "an older page landed" to "an older page or a load-through landed, or the index arrived". | Q2 fetches the index once per open. A refetch on replacement covers compaction and history rewrites. A stale entry fails one tap with an inline error. |
| P9 | **Revised by step 5.** The load-through (Q5) is its own route, `POST /session/messages/through`, with its own request type. It shares the page path in the service, the repository and the DAO through a sealed history window. | As a lower bound on `SessionMessagesRequest`, the bound would be valid only with `limit: null` and a non-null `before`, so two of the four field combinations would be invalid. A bridge that ignored the field would read `limit: null` as "the whole transcript", because `ChatHistoryDao.getMessages` ignores `before` when `limit` is null (verified). A separate route fails closed with a 404 instead. |
| P10 | The index, search and tool-output routes answer from the store alone. They run outside the session queue, read one database snapshot, never backfill, and read the audit file for an archived session. This mirrors `ChatHistoryService._storedOnlyPage`. One private helper in `ChatHistoryService` decides the source (no stored session, the audit file, or the store) for `_storedOnlyPage` and the three new routes. | The app calls them only after a page read, which has already backfilled when it could. A store that lags self-heals at the next list replacement (P8). Queueing would make them wait on a backfill they do not need. |
| P11 | The index and search decode stored attachments as metadata. They never touch spill files. | A stored row keeps an image as the bridge-internal `stored_file` source, which the shared `MessageAttachment` union decodes to `MessageAttachmentUnknown`. That would make an image-only prompt non-renderable and drop it from the index. Page reads avoid this through `_rehydrateAttachment`, which stats the spill file for every attachment. The index needs only the filename, which `_metadataAttachment` already keeps. |
| P12 | Search returns message ids and excerpts only. It scans user rows without the turn fold. | The app searches the bridge only when it holds an index, which already carries every kind, number and time. A user prompt's text alone decides a match. |
| P13 | A slim tool part is a second `ToolState` variant, not a flag. The page request opts in through an enum that mirrors `MessageAttachmentDelivery`. See [W3](#w3-slim-tool-parts-steps-12-and-13). | It satisfies the step 1 review's exclusivity constraint. It also keeps every existing `ToolState(` call site and the `MessagePart.tool` default valid. |
| P14 | Fetched tool output lives in a cubit map keyed by part id. The map survives list replacement. A full part for the same id always wins over it. | A refresh brings summary parts back. If the fetched output were merged into the messages, every refresh (each app resume) would collapse expanded rows back to loading, and they would jump when the output returned. |
| P15 | When an index is present, it decides every listed prompt's kind, number and time. Loaded prompts that the index lacks (sent after it was fetched) follow it, classified by the shared rule over the loaded range. | The index folds the whole history. The loaded-range fold can misread the first loaded user message (`docs/regression/transcript-turn-navigation.md`, Known Limitations). |

## Supersession Of Turn-Navigation

The turn-navigation plan is in retirement: PR #1848 is open, and its files move
to `.plan/completed/turn-navigation/` when it merges. Its files are not
edited. This plan records what it supersedes:

| Turn-navigation rule | Status under this plan |
|---|---|
| D30: search covers the loaded range only. "No bridge search route and no search index." | **Superseded by Q4.** The bridge answers a full-text prompt search. Loaded-range matches still appear immediately; bridge matches join after one round trip. Against a v1.9.0 bridge, D30's behavior stays as it is (Q6). |
| Guardrail: "Turns and the prompt list are derived from the rendered messages on every build. Nothing about turns is stored or cached." | **Narrowed.** The loaded range is still derived on every build. Entries older than the loaded range come from the bridge index. The app holds that index in memory while the session is open and drops it on list replacement (P8). The bridge stores nothing: it derives the index on each request. |
| D5: turns are derived, never stored. | **Kept.** Both sides derive with the same shared rule (Q3). |
| "Row numbers come from the bridge or not at all." | **Kept.** Index entries carry the bridge's numbers. |
| Prompts list order: chronological, and content already on screen never moves when earlier prompts load. | **Kept** for both the list and the transcript (Q5). |
| Explicitly Excluded: F1, F2, "any wire or storage change other than D29's additive count", and "a bridge search route or search index". | **Lifted** for the index route, the load-through bound, the search route and the W3 detail route. The bridge still keeps no stored index. |
| Later phase F1: a bridge turn index with a monotonic revision in `history_sync_state`. | **Replaced by Q1 plus P8.** The index ships without a revision; a refetch on list replacement replaces it. |
| Later phase F2: fetch one turn through an optional range on the messages request. | **Replaced by Q5 plus P9.** The request loads down to a prompt, so the loaded range stays contiguous. |
| Later phase: a full-session prompt list on top of F1 or F2. | **Delivered by Q1 and Q4.** |

## Current Behavior

### Relay Framing

- `shared/sesori_shared/lib/src/protocol/framing.dart`: `frame()` and
  `unframe()` produce `[0x01][XChaCha20-Poly1305 nonce, ciphertext, tag]`.
- A payload that starts with `{` outside encryption is a plaintext control
  message, such as key exchange or rekey.
- The decrypted plaintext is `utf8(jsonEncode(RelayMessage.toJson()))`.
  `RelayResponse.body` is a JSON string, so a page is JSON inside JSON.
- Nothing is compressed anywhere today.
- Bridge send path, `bridge/app/lib/src/orchestrator.dart`:
  - `_handleDecryptedMessage`, case `RelayRequest req`;
  - `_completeRoutedRequest`, then `_deliverRoutedResponse`, then
    `_encryptRelayMessage`, which JSON-encodes and frames;
  - `_bytesSentController` feeds `BandwidthTracker`, which only logs.
  - `_completeShutdownRejection` encrypts its rejection separately.
  - SSE frames are built in `sse/sse_manager.dart`.
- App receive path:
  - `client/module_core/lib/src/capabilities/relay/relay_client.dart`:
    `_decryptRelayMessage` unframes, decodes the JSON map, then calls
    `RelayMessage.fromJson`. It runs for resume, ready and the receive loop.
  - `client/module_core/lib/src/api/client/relay_http_client.dart`:
    `_sendViaRelay` builds every `RelayRequest` that `get`, `post`, `patch`
    and the other methods send.
  - `capabilities/server_connection/connection_service.dart` builds one more
    `RelayRequest`, for the health check.

### Tool Title And Shell Command

- Mapping, in `bridge/app/lib/src/repositories/mappers/plugin_to_shared_mapping.dart`,
  `ToolState.toShared({retainSummary})`:
  - when an adapter verified a shell command, `title` is set to that bounded
    command, as "the released title alias for older clients";
  - output and error survive only for shell tools, or when `retainSummary`
    is true (subtask summaries).
- `shellCommand` first shipped in v1.8.4 (#1221). v1.8.3 and older apps read
  the command from `title`.
- Rendering on v1.9.0 (`git show v1.9.0:` of `tool_part_widget.dart`): the
  title appears only when `command == null`. Shell tools render
  `_ShellToolPreview` from `shellCommand`.
- Rendering on `main`: `_ToolHeader` shows the shell command when present.
  Otherwise it shows the tool name plus the title. No other app code reads
  the tool title.
- Conclusion: removing the title from shell tools changes nothing for v1.8.4
  and newer apps. v1.8.3 and older apps would lose the command label on page
  reads. The user accepted this (see [O1](#answered-questions)).

### Pages, Turns And The Prompts Screen

- `POST /session/messages` takes `SessionMessagesRequest(sessionId, limit,
  before, attachmentDelivery, storedOnly)`.
- `GetSessionMessagesHandler` returns
  `MessageWithPartsResponse(messages, nextCursor, replayedPromptDefaults,
  awaitingHarnessSync, userMessagesBefore)`. The cursor is the oldest
  returned `seq`.
- Turn and prompt logic in the app:
  - `client/module_core/lib/src/cubits/session_detail/transcript_turns.dart`
    holds rule A: `_opensTurn`, `_outputEndOf` and `_partEnd`. It depends on
    `hasRenderableUserContent` and `promptText` in
    `session_detail_resolvers.dart`;
  - `transcript_prompt_list.dart` builds openers and follow-ups, numbered from
    the bridge's `userMessagesBefore` (D29).
- The Prompts screen:
  - it lives in `client/module_app_ui/lib/src/features/session_prompts/`
    and opens as a layer from `session_detail_body.dart`;
  - "Load earlier prompts" sits at the top;
  - search uses `promptSearchPattern` and `promptExcerpt` in
    `prompt_search.dart`.
- The pinned prompt is "the latest user message above the top edge" (D42),
  built from rendered user messages in `session_detail_message_list.dart`
  (`_stickyOpeners`).

### Facts Phases 2 And 3 Build On (Checked 2026-10-07)

**Bridge history read path:**

- `ChatHistoryService.getSessionMessages`
  (`bridge/app/lib/src/services/chat_history_service.dart`) makes three
  checks inside the per-session queue (`_enqueueRead`):
  - an archived session with an audit file is served from that file;
  - a fresh store is served from the store;
  - otherwise the session is backfilled from the harness, then read.
- `_storedOnlyPage` makes the same archive check outside the queue. It reads
  rows and sync state in one snapshot (`ChatHistoryDao.getPageRowsWithSyncState`).
- `ChatHistoryRepository` (`bridge/app/lib/src/repositories/chat_history_repository.dart`)
  assembles pages in two places:
  - `_assemblePage` decodes `infoJson`, rehydrates parts, and applies W2;
  - `getArchivedSessionMessages` checks the audit file's `schemaVersion`,
    quarantines an unreadable file, and slices the pages in memory.
- `ChatHistoryDao` (`bridge/app/lib/src/api/database/history/chat_history_dao.dart`):
  - `getMessages` returns the whole session when `limit` is null, ignoring
    `before`;
  - `countUserMessagesBefore` is raw SQL over
    `json_extract(info_json, '$.role') = 'user'`. `history_messages` has no
    role column.
- Stored part JSON keeps inline images as `{"source": "stored_file", …}`.
  That source is not a shared `MessageAttachment` union value, so a direct
  decode yields `MessageAttachmentUnknown`. Pages turn it back into a shared
  attachment in `_rehydrateAttachment`, which stats the spill file.
- Routes are registered in `bridge/app/lib/src/orchestrator.dart` next to
  `GetSessionMessagesHandler`. An unknown route gets a bare 404 from
  `RequestRouter._notFound`, in v1.9.0 too.

**App:**

- Unsupported routes in `SessionRepository`
  (`client/module_core/lib/src/repositories/session_repository.dart`):
  `getSessionDiffSummary` maps a bare 404 to `SessionDiffSummaryUnsupported`.
  It needs a typed error body only because that route's own handler also
  answers 404.
- `SessionDetailCubit.loadOlderMessages`:
  - drops a page whose `_transcriptGeneration` changed;
  - merges messages by id, then sets `olderMessagesCursor` and
    `userMessagesBeforeOldest` from the page.
  - The generation increments in two places: the snapshot build and the
    refresh.
- `SessionDetailLoadService` pages 50 messages
  (`initialPageSize`, `olderPageSize`).
- `RelayClient._decryptRelayMessage` and `RelayHttpApiClient` decrypt,
  inflate and JSON-decode on the calling isolate. No response decode uses
  `Isolate.run` or `compute`.
- The Prompts screen:
  - `_promptListOf` in `session_detail_body.dart` builds the list from
    `state.messages`, so the turn and prompt-list builders run in
    `module_app_ui` today;
  - a tap calls `_returnToPrompt`, which jumps the transcript beneath the
    open screen, then closes the screen;
  - the screen relists only when `isLoadingOlderMessages` goes from true to
    false.
- The analytics event `transcript_prompts_opened`, with its entry
  parameter, already reports Prompts screen use.

**Tool parts:**

- The shared `ToolState` (`shared/sesori_shared/lib/src/models/sesori/message_part.dart`)
  is one Freezed class: `status`, `title`, `shellCommand`, `output`, `error`
  and `attachments`.
- `PluginToolState.toShared` keeps output and error only for shell tools or
  with `retainSummary` (the subtask `taskState`). Each is bounded to
  `maxToolOutputLength` (500) characters.
- Only `ToolPartWidget`
  (`client/module_app_ui/lib/src/features/session_detail/widgets/tool_part_widget.dart`)
  reads output or error in the app. It also decides whether the disclosure
  shows (`hasDetails`). No app code reads a subtask `taskState`'s output.
- The panel is capped at 144 px (`shellTool.viewport`).
  `TranscriptDisclosure` scrolls the reversed list with the panel's opening
  animation, so the tapped header stays still.
- Semantic import fingerprints decode stored parts, then re-encode them
  (`_semanticMessageFingerprints` calls `_rehydrateParts`, then `toJson`). A
  new JSON key on `ToolState` therefore fingerprints the same on stored and
  imported parts.
- The shared `build.yaml` sets `include_if_null: false` and has no
  `disallow_unrecognized_keys`. Neither did v1.9.0's, so v1.9.0 apps ignore
  unknown keys.

**Harness behavior:** `docs/HARNESS_CAPABILITIES.md` "Transcript turn
boundaries" records which harnesses keep a follow-up inside the running turn.
The rule reads normalized history only, so moving it to the bridge adds no
harness gap.

## Phase 1 Architecture

### W2: Drop The Duplicated Shell Title (Step 2)

- Add a pure function in `bridge/app/lib/src/repositories/mappers/`, for
  example `withoutDuplicatedShellTitle({required MessageWithParts message})`.
  A `MessagePart.tool` whose `state.shellCommand` is non-null and equal to
  `state.title` gets `title: null`. Everything else passes through unchanged.
- `ChatHistoryRepository` applies it to the assembled messages in its two
  page-assembly sites:
  - `_assemblePage`, used by `getSessionMessages` and
    `getSessionMessagesWithSyncState`;
  - the archived page build in `getArchivedSessionMessages`.
  Both are applied after `_rehydrateParts`, alongside the existing attachment
  projection (P2). Together they cover every page path the service returns:
  database, fresh, archived and `storedOnly`.
- The routing handler is unchanged.
- Unchanged:
  - `toShared`, which keeps the alias for live SSE;
  - the store and existing rows;
  - `_rehydratePart`;
  - subtask `taskState`;
  - non-shell tool titles.
- Docs:
  - `docs/HARNESS_CAPABILITIES.md` "Explicit shell-command presentation":
    replace "the released title alias remains available to older clients"
    with the new split. Live events keep the alias; history pages omit the
    title when it equals the command.
  - `docs/regression/tools-and-file-changes.md`: the rendered command on a
    reloaded page comes from `shellCommand`.
- Tests:
  - the mapper function: a shell tool loses its title; a non-shell tool keeps
    it; a shell tool whose title differs from its command keeps it;
  - a repository page read and an archived page read each return a shell tool
    without its title.

### W1: Negotiated Deflate (Steps 3 And 4)

Step 3 covers the bridge and `sesori_shared`. Step 4 covers the app.

**Wire (`sesori_shared`):**

- `RelayRequest` gains:

  ```dart
  // COMPATIBILITY 2026-10-06 (v1.9.1): Released apps omit this field and read
  // only plain responses, so absence means plain. Make it required once every
  // supported app sends it.
  @Default(false) bool acceptsDeflatedResponse,
  ```

- `RelayProtocol` gains `deflatedPlaintextMarker = 0x00`. Its doc comment
  states the plaintext layout: marker byte, then a raw deflate stream of the
  UTF-8 JSON.
- `framing.dart` is unchanged, and so is `protocolVersion`.

**Bridge (step 3):**

- `_handleDecryptedMessage` passes `req.acceptsDeflatedResponse` into
  `_completeRoutedRequest`, as a required `bool deflateResponse`. From there
  it goes to `_deliverRoutedResponse` and `_encryptRelayMessage`.
- `PendingRoutedRequest` does not carry the request, so a parameter is the
  right shape for the flag.
- `_completeShutdownRejection` passes `false`, since its responses are tiny.
- Add a Layer 0 codec in `bridge/app/lib/src/foundation/`, for example
  `relay_plaintext_codec.dart` with
  `encodeRelayPlaintext({required List<int> json, required bool deflate})`:
  - when `deflate` is false, it returns the JSON bytes unchanged;
  - when it is true, it returns `[0x00]` followed by
    `ZLibEncoder(raw: true).convert(json)`.
  The orchestrator stays wiring only (architecture review).
- `_encryptRelayMessage({connID, message, deflate})` JSON-encodes as today,
  calls the codec, then calls `frame()` as today.
- `BandwidthTracker` receives the plaintext length actually framed, so its
  log reflects the compressed size. The verbose log line also prints the JSON
  length, so the compression ratio stays observable.
- Tests:
  - the codec: deflated output starts with `0x00` and inflates to exactly
    the input JSON; plain output is the input unchanged;
  - orchestrator or routed-response tests: an asking request gets a deflated
    plaintext, and a non-asking request gets today's bytes;
  - a shared JSON test: `RelayRequest` without the key decodes to `false`,
    and the key round-trips.

**App (step 4):**

- `RelayHttpClient._request` and `_sendViaRelay` gain a required
  `acceptsDeflatedResponse` and copy it into the `RelayRequest` (P4).
  `get`, `post`, `patch` and `delete` pass `true`. `postWithTimeout`, used
  only for the attachment fetch, passes `false`. The health request in
  `connection_service.dart` keeps the default.
- `RelayClient._decryptRelayMessage`:
  - after `unframe`, a plaintext whose first byte is the marker is inflated
    with `ZLibDecoder(raw: true)` from byte 1;
  - any other plaintext is handled exactly as today.
  - An inflate failure surfaces the same way a malformed JSON plaintext does
    today. It is not swallowed.
- Tests:
  - `relay_client` decodes both a deflated and a plain `RelayResponse` frame;
  - `relay_http_client` sends the flag.
- Docs:
  - `docs/SECURITY.md`: a short "Compression" paragraph under end-to-end
    encryption covering the decision below;
  - `docs/HOW_IT_WORKS.md`: one sentence in the phone-to-bridge section;
  - `docs/regression/bridge-connectivity.md`: required behavior and the
    compatibility checks for all three app and bridge pairings.

**Compatibility matrix:**

| App | Bridge | Result |
|---|---|---|
| New | New | Responses are deflated. |
| New | v1.9.0 | The bridge ignores the unknown key (verified in v1.9.0 generated code) and replies plain. The app reads plain as today. |
| v1.9.0 | New | The field is absent, so it decodes to `false`. Responses are plain, byte-for-byte as today. |

### Security And Privacy Of W1

- **Order:** compress, then encrypt. Compression happens inside the
  end-to-end channel, before XChaCha20-Poly1305. The relay still sees only
  opaque frames with the same outer format. Key exchange and rekey control
  messages are never compressed. Local E2E and managed trusted modes are
  equally unaffected.
- **Length leaks (CRIME/BREACH): decided not to mitigate. The risk is
  accepted.**
  - What it would take: a secret and attacker-controlled bytes in the same
    deflate stream; an attacker who can see ciphertext lengths; and many
    adaptive re-requests of that same response.
  - Can a transcript page mix the two? In principle, yes. Tool output can
    contain a secret, and agent-fetched web content can carry injected text.
  - What exploitation would require:
    - the attacker must change the injected text adaptively, many times per
      guessed byte;
    - that text must land within deflate's 32 KB window of the secret;
    - and the user must re-fetch the same page each time.
    The attacker does not control how often the app reloads a page.
  - Who can see lengths: only the relay and network observers. The relay is
    already a trusted routing endpoint (`docs/SECURITY.md`), and SSE already
    exposes finer-grained lengths of live content.
  - Credentials never travel in relay responses. The room key moves in
    plaintext control messages, which are not compressed, and auth tokens go
    to the auth server.
- **No inflate size cap.** The bridge is an authenticated peer behind the
  AEAD tag, and a frame that fails authentication is never inflated. A cap
  would defend against a peer that already holds the room key. It is
  deliberately not added.
- **Logs:** no new content is logged. The verbose byte counts already exist.

## Phases 2 And 3 Architecture

Detailed by step 5. Names marked "for example" are proposals; the step's PR
may rename them, but not change their shape or owner.

The step 1 architecture review set five constraints. This is where each one
is written in:

| Constraint | Where it lands |
|---|---|
| Bridge routes go handler → `ChatHistoryService` → `ChatHistoryRepository` → `ChatHistoryDao`. Cuts, entry mapping and the slim-part projection live in the repository or `repositories/mappers/`. The archived path is stated. | Steps [7](#prompt-index-route-step-7), [8](#load-through-route-step-8), [11](#search-every-prompt-step-11) and [12](#w3-slim-tool-parts-steps-12-and-13). Each names its archived path. Only the index has a narrower-projection escape hatch, and it does not apply to audit files. |
| An older bridge's 404 becomes a typed "unsupported" result in `SessionRepository`. The cubit never branches on a status code. | [Step 9](#the-index-in-the-app-step-9): `SessionPromptIndexUnsupported`. |
| Choosing the pin's index entry is business logic in `module_core`. `module_app_ui` only turns it into a `TranscriptStickyAbove` place, and `_stickyOpeners` stays layout-only. | [Step 10](#pin-above-unloaded-turns-step-10). |
| Merging loaded-range and bridge search matches belongs in `module_core`. | [Step 11](#search-every-prompt-step-11): `PromptSearchCubit`. |
| A slim tool part never pairs nullable output and error with a "has detail" flag. | [Step 12](#w3-slim-tool-parts-steps-12-and-13): `ToolState` gains a second variant. |

### Shared Follow-Up Rule (Step 6)

- A new `shared/sesori_shared/lib/src/transcript/prompt_turns.dart`, exported
  from the package, takes two things verbatim from `module_core`:
  - the `SessionMessagePresentation` extension (`hasRenderableUserContent`
    and `promptText`) from `session_detail_resolvers.dart`. Its consumers in
    `module_core` and `module_app_ui` already import `sesori_shared`, so only
    the declaration moves. `firstNonBlankLine` stays in the client, because
    only display code uses it;
  - rule A from `transcript_turns.dart`: `_opensTurn`, `_outputEndOf`,
    `_partEnd` and `_OutputEnd`.
- One public fold replaces the segment loop at the top of
  `TranscriptTurnBuilder.build`. For example,
  `splitPromptTurns({required List<MessageWithParts> messages})` returns a
  sealed `PromptTurnSegment` list:
  - `LeadingPromptSegment(messages)`: messages before the first opener;
  - `PromptSegment(opener, messages)`.
- `TranscriptTurnBuilder` keeps its signature. It maps a leading segment to
  `TranscriptPartialTurn` or `TranscriptPreamble` by `hasOlderMessages`, as
  it does today. The private helpers are deleted from the client, not
  wrapped.
- **Proof:** the existing `transcript_turns_test.dart` and
  `transcript_prompt_list_test.dart` pass unchanged. A few shared tests cover
  the fold directly, because the bridge will call it without the client.

### Prompt Index Route (Step 7)

**Wire** (`sesori_shared`):

- `POST /session/prompts` takes the existing `SessionIdRequest`.
- It returns `SessionPromptIndexResponse(entries)`, oldest first.
- `SessionPromptIndexEntry` is a sealed Freezed union keyed by `kind`:
  - `opener(messageId, seq, number, int? createdAt, String? preview)`;
  - `followUp(messageId, seq, number, int? createdAt, String? preview,
    openerMessageId)`.
  - A prompt in the leading segment is an opener, as
    `TranscriptPromptListBuilder` lists it today.
- `number` counts every user message from the start of the session,
  including hidden ones, exactly as `countUserMessagesBefore` and the client
  numbering do (D29). Hidden user messages get no entry.
- `createdAt` is the message's `time.created`. It is null when the harness
  gave none; the ACP family now has one (D38, `localUserMessageTime` in
  `bridge/sesori_plugin_acp/lib/src/acp_event_mapper.dart`).
- `preview` is `promptText` with leading whitespace trimmed, cut to at most
  300 UTF-16 code units without splitting a surrogate pair. It is null only
  when `promptText` is null (an attachment whose name is unknown). There is
  no "text continues" flag: the app shows previews as one line, and search
  goes to the bridge.
- The handler never answers 404. An unknown or empty session returns an
  empty list, so a 404 always means an older bridge (step 9).

**Bridge path:**

- `GetSessionPromptIndexHandler` → `ChatHistoryService.getPromptIndex` →
  `ChatHistoryRepository` → `ChatHistoryDao`, under P10.
- The service makes `_storedOnlyPage`'s archive check. An archived session
  with an audit file reads that file; any other session reads the store.
- Store path: the existing `ChatHistoryDao.getPageRowsWithSyncState` with
  `limit: null` already returns every message row and its parts in one
  transaction; no new DAO read. The repository decodes `infoJson`, decodes parts with the metadata attachment
  projection (P11), folds with `splitPromptTurns`, numbers the user
  messages, and maps entries in a pure mapper, for example
  `repositories/mappers/prompt_index_mapper.dart`.
- Archive path: the repository reads and validates the audit file through
  the same steps as `getArchivedSessionMessages`. Those steps move into one
  private helper that both callers use, so the schema check and the
  quarantine stay in one place. The fold and the mapper are shared with the
  store path.
- **Budget:** about 300 ms on the bridge for a synthetic session the size of
  the largest measured one (9,790 messages, 836 prompts), measured with
  `bridge/app/tool/benchmarks/`. The escape hatch, only if the measurement
  misses the budget, is a DAO projection that reads `infoJson` plus only the
  part fields rule A needs. It does not apply to the archive path, which
  already holds the whole file in memory.

**Docs:** `docs/HARNESS_CAPABILITIES.md` "Transcript turn boundaries" says
the client and the bridge apply the same shared rule.
`docs/regression/session-history-and-recovery.md` gains the index,
including archived sessions.

### Load-Through Route (Step 8)

**Wire:**

- `POST /session/messages/through` takes
  `SessionMessagesThroughRequest(sessionId, throughSeq, before,
  attachmentDelivery, storedOnly)`. Every field is required, because no
  older app sends it.
- It returns the existing `MessageWithPartsResponse` with every message
  where `throughSeq <= seq < before`, oldest first.
  - `nextCursor` is `throughSeq` when an older message exists, otherwise
    null. An exists query answers that, because the page is not cut by a
    limit.
  - `userMessagesBefore` is the count before `throughSeq`.
- 400 when `throughSeq >= before`.

**Bridge path:**

- A sealed `HistoryWindow` in `bridge/app/lib/src/repositories/models/`
  replaces the `limit` and `before` pair in `ChatHistoryService` and
  `ChatHistoryRepository`. It never reaches the DAO, which imports nothing
  from `repositories/` and keeps plain parameters:
  - `HistoryWindowAll()`: a request without `limit`, the whole session;
  - `HistoryWindowNewest(int limit, int? before)`: today's page;
  - `HistoryWindowThrough(throughSeq, before)`.
- Today the store ignores `before` when `limit` is null, but the archive
  slice applies it. No caller sends that pair (the app always sends a
  limit), so `HistoryWindowAll` drops `before` on both paths.
- The repository switches on the window. Newest and all call the existing
  `getPageRowsWithSyncState`. Through calls a new DAO read with plain
  parameters that returns, in one snapshot, the rows where
  `throughSeq <= seq < before`, their parts, whether an older message
  exists, and the user count before `throughSeq`.
- The page route builds `HistoryWindowAll` or `HistoryWindowNewest`; the new
  handler builds `HistoryWindowThrough`. Freshness, backfill, `storedOnly`,
  the archive slice, W2 and the attachment projection stay on the one shared
  path.

**App path:**

- `SessionApi.getMessagesThrough` → `SessionRepository` →
  `SessionDetailLoadService.loadMessagesThrough` →
  `SessionDetailCubit.loadMessagesThrough`.
- It takes the tapped entry's `messageId` and `seq`, and returns a sealed
  result: `Loaded`, `TargetMissing` (the load landed without that message),
  `Failed`, or `Superseded` (the generation changed while it ran).
- It shares the prepend with `loadOlderMessages`. The prepend keeps the
  older cursor and its count from the response, and an older page and a
  load-through that land together cannot move the cursor back: a null
  cursor wins.
- A 404 here can only come from a bridge released between steps 7 and 8,
  which has the index but not this route. It gets no special handling: the
  tap fails inline.

**Measure:** step 8 records, for the whole largest session in one response,
the bridge's deflate time and the app's decode time on the UI isolate. The
escape hatches are an isolate for the bridge's deflate and `Isolate.run` for
the app's decode, added only if the measurement shows a visible stall.

### The Index In The App (Step 9)

**Repository:** `SessionRepository.getPromptIndex` returns a sealed result:

- `SessionPromptIndexAvailable(entries)`;
- `SessionPromptIndexUnsupported`: any 404, with a dated COMPATIBILITY
  marker whose retiring condition is that no supported bridge predates the
  route;
- `SessionPromptIndexFailure`.

**Cubit and state:**

- `SessionDetailLoaded` gains `promptIndex`, a nullable entry list.
- The cubit fetches the index after each `_transcriptGeneration` bump when
  `olderMessagesCursor != null` (Q2, P8). It applies the result only if the
  generation still matches. `Unsupported` and `Failure` leave the index
  null; a failure is logged.
- `_promptListOf` (`session_detail_body.dart`) passes the index and the
  cursor through. The merge happens in `module_core`, inside
  `TranscriptPromptListBuilder`.

**Prompt list:**

- `TranscriptPromptListBuilder.build` gains `index` and
  `olderMessagesCursor`.
- Each entry gets a sealed source:
  - `TranscriptPromptLoaded(fullText)`;
  - `TranscriptPromptUnloaded(seq, preview)`.
- With an index, it decides every listed prompt's kind, number and time
  (P15). Loaded prompts the index lacks follow it, classified by the loaded
  range.
- Without an index the list is built exactly as today (Q6).

**Prompts screen:**

- With an index, "Load earlier prompts" goes and the count reads
  "{count} prompts" (a new string). Without one, today's strings stay.
- The screen relists when an older page lands, when a load-through lands, or
  when the index arrives (P8).
- **Far tap:**
  - the screen stays open while the load runs;
  - the tapped row shows a spinner after about 150 ms;
  - when the load lands, `_returnToPrompt` jumps and closes the screen as it
    does today;
  - `TargetMissing` or `Failed` shows an inline error on the screen;
  - a second tap replaces the target;
  - closing the screen cancels the jump, not the load.
- The pending target and its timer are UI-local state in the screen.

**Docs:** `docs/regression/transcript-turn-navigation.md` covers the full
list, the far tap and the older-bridge fallback.

### Pin Above Unloaded Turns (Step 10)

- A method next to `TranscriptPromptListBuilder.build`, in
  `client/module_core/lib/src/cubits/session_detail/transcript_prompt_list.dart`,
  returns the pin entry: the last index entry whose `seq` is below
  `olderMessagesCursor`, when the loaded range starts inside its turn.
- `session_detail_message_list.dart` prepends that entry as one more opener
  in the `TranscriptStickyAbove` place, ahead of `_stickyOpeners`'s output.
  `_stickyOpeners` stays layout-only.
- A tap on that pin runs the far-tap flow from step 9.
- What the pin shows is open question [O2](#open-questions). Step 10 waits
  on it.

### Search Every Prompt (Step 11)

**Shared:** `promptSearchPattern` and `promptExcerpt` move from
`client/module_app_ui/lib/src/features/session_prompts/prompt_search.dart`
to `sesori_shared`, so both sides match and cut alike.
`promptExcerptExtent` stays in `prompt_spine_row.dart`, because it is
layout.

**Wire:**

- `POST /session/prompts/search` takes
  `SessionPromptSearchRequest(sessionId, query)`.
- It returns `SessionPromptSearchResponse(matches)`, where each
  `SessionPromptSearchMatch(messageId, excerpt)` carries a
  `SessionPromptExcerpt(before, match, after)`.
- Empty session, empty query, or no matches: an empty list. Never 404 from
  the handler.

**Bridge path:**

- Handler → `ChatHistoryService.searchPrompts` (P10) → repository → a new
  DAO read of user rows only, using the existing
  `json_extract(info_json, '$.role') = 'user'` filter.
- The repository decodes with the metadata projection and matches
  `promptText` with the shared pattern. A pure mapper cuts the excerpt with
  the shared helper. There is no fold (P12).
- The archive path filters the audit file's user messages in memory.

**App:**

- `SessionRepository.searchPrompts` returns `Available(matches)` or
  `Failure`.
- A `module_core` `PromptSearchCubit` owns the query, the loaded-range
  matches and the bridge matches. It debounces the bridge query by 250 ms,
  and the latest query wins.
- `SessionPromptsView` creates it with `BlocProvider(create:)`, from the
  session id and a `SessionRepository` that `SessionDetailPresentationScope`
  gains as a new capability. Both shells (`client/app`'s
  `session_detail_screen.dart` and `client/desktop`'s
  `desktop_session_detail_screen.dart`) pass it in. The query moves out of
  `_SessionPromptsViewState`.
- The view hands the cubit its built prompt list, index entries included,
  through a named method on every relist. The cubit never reads
  `SessionDetailCubit`.
- The merge lives in that cubit: the bridge decides which prompts match, and
  the index and the loaded range supply their rows.
- Loaded-range matches show at once. Bridge matches join in chronological
  order, animating in with size and fade, and rows already on screen keep
  their place.
- What the count row says while the bridge searches, and after a failure, is
  open question [O3](#open-questions). Step 11 waits on it.

### Analytics And Harnesses

- **Analytics:** no new event. `transcript_prompts_opened` already answers
  whether people use the Prompts screen. The index, the far tap and search
  are improvements to that screen, not separate adoption questions.
- **Harnesses:** no new gap. The rule reads normalized history, and every
  harness's follow-up behavior is already recorded in "Transcript turn
  boundaries". W3 applies to every harness's tool parts on page reads.

### W3: Slim Tool Parts (Steps 12 And 13)

**Wire (step 12):**

- `ToolState` becomes a Freezed union keyed by, for example, `form`:
  - the default constructor stays the full part, so every existing
    `ToolState(` call site and the `MessagePart.tool` default still compile;
  - `ToolState.summary(status, title, shellCommand, attachments)` has no
    output and no error.
  - `fallbackUnion` decodes keyless JSON (stored rows, v1.9.0 bridges) as
    full.
  - Output and error leave the base type, so their readers switch on the
    variant. The only app reader is `ToolPartWidget` (`hasDetails` and
    `_ToolPanel`); on the bridge, the mappers build `ToolState` but read
    output and error only from the plugin type. Full parts gain a few bytes for the key; v1.9.0 apps ignore it,
    because the shared `build.yaml` has no `disallow_unrecognized_keys`.
- `SessionMessagesRequest` gains
  `@Default(ToolOutputDelivery.inline) ToolOutputDelivery toolOutputDelivery`,
  an enum of `inline` and `onExpand`. It carries the marker
  `// COMPATIBILITY 2026-10-07 (v1.9.1): v1.9.0 apps omit it and expect full
  tool parts; drop the default once no supported app predates the field.`
  `SessionMessagesThroughRequest` gets the field as required if no public
  release contains step 8 when step 12 lands. Otherwise it gets the same
  `@Default` and marker, because a released app would send the request
  without it.
- `POST /session/tool-output` takes
  `SessionToolOutputRequest(sessionId, messageId, partId)` and returns
  `SessionToolOutputResponse(String? output, String? error)`. It answers 404
  when the part is missing or is not a tool.

**Bridge (step 12):**

- A pure mapper in `repositories/mappers/`, for example
  `withSummarizedToolOutput()`, applies at the same two page-assembly sites
  as W2, after it, only when the request asks for `onExpand`.
- It summarizes only completed, error or cancelled tools that have output or
  error. Running tools and subtask summaries stay full.
- The tool-output route goes `GetSessionToolOutputHandler` →
  `ChatHistoryService.getToolOutput` (P10) → `ChatHistoryRepository` →
  a new `ChatHistoryDao.getPart` by the table's primary key (`sessionId`,
  `messageId`, `partId`), or a lookup in the audit file for an archived
  session.
- SSE live parts stay full.

**App (step 13):**

- Page reads and load-throughs ask for `onExpand`.
- `SessionApi.getToolOutput` → `SessionRepository.getToolOutput`, which
  returns a sealed `ToolOutputResult`: `Available(output, error)` or
  `Failure`.
- `SessionDetailCubit` holds a map from part id to a sealed
  `ToolOutputFetch`: `Loading`, `Loaded(output, error)` or `Failed` (P14).
  `fetchToolOutput(messageId, partId)` fills it.
- `ToolPartWidget` shows the disclosure for every summary part, because the
  bridge summarizes only parts that have output or error. No flag is needed.
- On expand:
  - the panel opens at once to a fixed-height loading body;
  - the spinner appears after about 150 ms;
  - the panel then resizes to its fetched height. `TranscriptDisclosure`
    compensates the reversed list only while its own animation runs today,
    so step 13 extends that compensation to a resize of an open panel, and
    the header stays still;
  - a failure shows inline with Retry.

**Docs:** `docs/HARNESS_CAPABILITIES.md` and
`docs/regression/tools-and-file-changes.md` describe output fetched on
expand.

## Steps

PR titles are fixed in [TRACKER.md](TRACKER.md#fixed-pr-titles). Sizes count
added plus deleted lines against the merge base, including generated code.

| Step | Scope | Target (changed lines) | Complexity |
|---|---|---|---|
| 1 | This plan | ≤ 900 | 🌱 docs only |
| 2 | W2 repository page projection, tests, docs | ≤ 250 | 🌿 one pure projection at two sites |
| 3 | W1 shared field and marker, bridge codec and deflate, tests | ≤ 450, including generated Freezed and JSON | 🚧 encrypted transport, compatibility |
| 4 | W1 app ask and inflate, tests, security and connectivity docs | ≤ 400 | 🚧 encrypted transport, every response path |
| 5 | Detail phases 2 and 3, then architecture review | ≤ 700 | 🌱 docs only |
| 6 | Move the follow-up rule and the prompt extension into `sesori_shared` | ≤ 600 | ⚙️ cross-package move with parity |
| 7 | `POST /session/prompts`: wire union, store and archive paths, benchmark | ≤ 900, including generated | 🚧 new wire contract, archived path |
| 8 | `POST /session/messages/through`, `HistoryWindow`, app load-through | ≤ 600, plus generated | 🚧 paging and wire change |
| 9 | Index fetch, full Prompts list, far-tap flow | ≤ 1,300 | 🚧 scroll stability and lifecycle |
| 10 | Pin over unloaded turns (waits on O2) | ≤ 500 | ⚙️ |
| 11 | Bridge search route, shared search helpers, `PromptSearchCubit` (waits on O3) | ≤ 800 | ⚙️ |
| 12 | W3 `ToolState` union, opt-in, summary mapper, tool-output route | ≤ 900, including generated | 🚧 wire opt-in, compatibility |
| 13 | W3 app opt-in, output map, expand loading | ≤ 700 | ⚙️ motion and state merge |
| 14 | Reconcile regression docs | ≤ 300 | 🌱 |
| 15 | Run the L3 matrix and retire | ≤ 250 | 🌱 |

Steps 3 and 4 are split on purpose. Each is a transport and security change
reviewed on its own, and step 3 is valid alone because no app asks yet. Step 5
kept 15 steps. Step 9 is the largest because the list merge, the screen and
the far tap must land together to be valid; if it grows past its target, the
far tap splits out as its own PR.

### Step Dependencies

- Step 2 depends on step 1. The user accepted O1 on 2026-10-07.
- Step 3 depends on step 1. Step 4 depends on step 3.
- Step 5 depends on steps 2–4 having merged, so that it details phases 2 and
  3 with phase 1's evidence (real compressed sizes).
- Step 6 depends on step 5. Step 7 depends on step 6.
- Step 8 depends on step 5. It can run in parallel with steps 6 and 7.
- Step 9 depends on steps 7 and 8.
- Step 10 depends on step 9 and on O2. Step 11 depends on step 9 and on O3.
- Step 12 depends on step 8, because both change the page path and the
  through request gains W3's field. Step 13 depends on step 12.
- Step 14 depends on steps 2–13. Step 15 depends on step 14.

## Verification

- **Each code step:**
  - run the directly relevant tests;
  - run `dart analyze --fatal-infos` for every touched package
    (`sesori_shared`, `bridge/app`, `module_core`, `module_app_ui`);
  - regenerate after changing Freezed or JSON sources.
  - CI runs the full matrix.
- **Step 2:** the mapper and repository tests, plus a manual page read
  through the debug server that shows no title on a shell tool.
- **Steps 3–4:** byte-exact inflate tests on both sides, plus one relay
  integration check per compatibility pairing. Step 4 records the compressed
  page sizes it observes in `steps/step-04.md`.
- **Step 6:** the existing turn and prompt-list tests pass unchanged.
- **Step 7:** repository tests for the store and archive paths, including an
  image-only prompt (P11) and a hidden user message; the benchmark result in
  `steps/step-07.md`.
- **Step 8:** DAO and repository tests for the window bounds and the
  cursor; the measured deflate and decode times in `steps/step-08.md`.
- **Steps 9–11 and 13:** cubit and builder tests, plus a recording.
- **Step 12:** mapper tests for every status, and a JSON test that keyless
  `ToolState` JSON decodes as full.
- **Steps 5 and 14:** docs only. No Dart suites.

## Regression Coverage

**Affected feature documents:**

- `docs/regression/bridge-connectivity.md` (W1);
- `docs/regression/tools-and-file-changes.md` (W2, W3);
- `docs/regression/transcript-turn-navigation.md` (index, far tap, pin and
  search);
- `docs/regression/session-history-and-recovery.md` (load-through and the
  archived index).

Each feature step updates its document. Step 14 reconciles them all.

**Highest level:** L3 Release.

**Boundaries:**

| Boundary | What it proves |
|---|---|
| Relay integration | W1 across the three app and bridge pairings. |
| Headless bridge | The W2 projection, and the index, search, load-through and tool detail routes, including archived sessions. |
| Client end to end | The full Prompts list; the far tap with no visible jump and the delayed spinner; the pin over unloaded turns; merged search; tool expand without a jump. |
| Automated | The shared rule's parity with today's client turns. |

**Plugins:**

- W1, W2 and W3: Representative. The bridge owns them after the normalized
  plugin boundary.
- W2 and W3 need a plugin with verified shell commands, for example Claude.
- The index: one steering harness (Claude) and one ACP-family harness, whose
  follow-ups open new turns. The two exercise both outcomes of the shared
  rule on real history. The rule itself is shared code over normalized
  history, and its parity is proven Automated.

**Platforms:**

- iOS as the release-target app platform;
- macOS desktop;
- an Android smoke check of deflated responses and the far tap;
- macOS as the release-target bridge host.

**Compatibility checks:**

| App | Bridge | Expected |
|---|---|---|
| New | v1.9.0 | Plain responses, today's Prompts screen and wording, full tool parts. |
| v1.9.0 | New | Plain responses, unchanged rendering, full tool parts. |

Any reduction of this matrix needs the user's explicit acceptance, recorded
here before step 15 retires the plan.

## Complexity Budget

**New persistent state:** none. The bridge derives the index and search
results per request and adds no table or column.

**New in-memory mutable state:**

| Phase | State | Why |
|---|---|---|
| 1 | None. One boolean travels with a request through the orchestrator's existing call chain. | — |
| 2 | One nullable prompt index in the session detail state, replaced on list replacement (P8). | Q1/Q2 need it. |
| 2 | One pending far-tap target and its spinner timer, local to the Prompts screen. | Q5 needs it. |
| 2 | `PromptSearchCubit`: the query, the two match sets and the debounce timer. | Q4 needs it. |
| 3 | One map from part id to `ToolOutputFetch` in the cubit (P14). | W3 needs it. |

**Persistent change:** the `ToolState` union key adds a few bytes to tool
parts stored after step 12. Older rows decode through `fallbackUnion`.

Deliberately not added:

- a bridge-stored index, or a revision counter (F1);
- an inflate size cap, a compression size threshold, or per-route
  compression opt-in;
- compression of SSE events or of requests;
- a search index (the query scans prompt rows);
- client caching of the index across session opens;
- a role column on `history_messages`;
- a fallback for an unknown entry kind (every kind ships in one release);
- a "preview truncated" flag;
- cancelling a load-through;
- summarizing running tools or subtask summaries.

## Proportionality And Accepted Risk

| Risk | Evidence level | Accepted outcome |
|---|---|---|
| v1.8.3 and older apps lose the shell command label on page reads (W2). | Reasoned from the v1.8.4 release history. | Cosmetic, on apps two releases old. Accepted by the user on 2026-10-07 (O1). |
| A stale index entry after a background history rewrite that has not yet triggered a refetch (P8). | Theoretical interleaving. | One tap shows an inline error. The next list replacement refetches. |
| CRIME/BREACH-style length inference on deflated transcript pages. | Theoretical. Needs adaptive injection, length observation and repeated user re-fetches. | Not mitigated. See [Security And Privacy Of W1](#security-and-privacy-of-w1). |
| Bridge CPU spent deflating a very large load-through response. | Measured sizes: up to 17.4 MB for the largest session. | Measured in step 8. Isolate offload only if the bridge stalls visibly. Attachment responses are never deflated (P4). |
| The app decodes a whole-session load-through on the UI isolate. | Same 17.4 MB worst case; decode runs on the calling isolate today. | Measured in step 8. `Isolate.run` only if a frame stall is visible. |
| The index takes too long for the largest session. | About 20 ms for the review page's query; the fold over every part is new. | Measured in step 7 against a 300 ms budget. A narrower projection only if it misses. |
| A bridge released between steps 7 and 8 has the index but not the load-through route. | Release timing. | A far tap fails inline; loaded prompts still work. |
| The loaded-range fold and the index disagree on a prompt's kind. | Known limitation at the loaded edge. | The index wins (P15). |

## Cleanup Assessment

| Step | Cleanup |
|---|---|
| 2 | Removes the title from shell tools on page reads. The mapper's alias stays, because live SSE still feeds v1.8.3 and older apps. Its comment is updated to say only live events keep it. |
| 9 | Removes "Load earlier prompts" from the Prompts screen when the index is present. It stays for v1.9.0 bridges (Q6). |
| 6 | Moves rule A out of `transcript_turns.dart` and the prompt extension out of `session_detail_resolvers.dart`. The client copies are deleted, not kept as wrappers. |
| 7 | The archive read and validation in `getArchivedSessionMessages` becomes one private helper shared with the index, not a copy. |
| 8 | `limit` and `before` stop travelling as a loose pair through the service and repository; `HistoryWindow` replaces them. |
| 11 | Moves `promptSearchPattern` and `promptExcerpt` to `sesori_shared`, leaving no duplicate. |
| 12 | The full-part page path stays only for v1.9.0 apps, behind the opt-in's `@Default` with a `COMPATIBILITY` comment. Its retiring condition: every supported app opts in. |

No other obsolete code was found.

## Delivery Rules

- One branch per step: `transcript-history/<topic>`.
- Titles follow `<emoji> [transcript-history] <description> [step x/15]`.
- PR bodies include `## Complexity`, `## What`, `## Why`,
  `## Risk and test focus` and `## Expected result`, plus a verification
  section.
- User-visible steps (9, 10, 11 and 13) attach recordings made with fixture
  data only.
- Steps 3, 7, 8, 11 and 12 change wire contracts. Each needs a JSON test
  proving that the older peer's shape still decodes.
- Architecture-bearing steps (3, 4, 6, 7, 8, 9, 11, 12 and 13) get
  `architecture-implementation-review` through a sub-agent, within AGENTS.md's
  limits.

## Open Questions

**O2 — What a pin over an unloaded prompt shows (blocks step 10).** The
loaded range starts inside a turn whose opener is not loaded. The app has
only the index entry: a 300-character preview, with no attachments and no
bubble to measure.

- **A (suggested):** the preview in the normal pinned bubble, cut at the
  compact pin height like any long prompt. A tap loads through and jumps.
  It looks like every other pin, so the swap to the real bubble when the
  opener loads is invisible.
- **B:** a compact one-line pin holding the preview's first line. Visibly
  different from a loaded pin, and it changes height when the real opener
  loads.
- **C:** a chip with the prompt number and first line. Smallest, but a third
  pin style.

**O3 — The search count row while the bridge searches, and after a failure
(blocks step 11).**

- **A (suggested):** loaded-range matches show at once. After about 150 ms
  without a bridge answer, the count row reads "Searching earlier prompts…";
  then it reads "{count} matches". On failure it reads "Couldn't search
  earlier prompts" with Retry, and the loaded matches stay.
- **B:** show no count until the bridge answers. Loaded matches still show at
  once. A failure shows only the loaded matches with today's "in the prompts
  loaded so far" wording.

## Answered Questions

**O1 — W2 on v1.8.3 and older apps: accepted (user, 2026-10-07).** Those apps
predate the separate `shellCommand` field and render the shell command from
`title`, so after W2 their reloaded shell rows show only the tool name. That
is accepted as cosmetic. Skipping W2 and gating it on an app opt-in were
declined.

## Plan Review

**`architecture-plan-review`, 2026-10-06, first pass: rejected.** The
reviewer marked it not "too vague". It raised two blocking phase 1 findings,
both applied without re-review as AGENTS.md allows:

1. The W2 projection was planned in a routing handler, and routing does no
   mapping. It moved to `ChatHistoryRepository`'s two page-assembly sites,
   with a pure function in `repositories/mappers/` (P2 and the W2 section).
2. The deflate codec was planned inline in the orchestrator. It moved to a
   Layer 0 codec in the bridge's `foundation/` (P6 and the W1 bridge
   section).

Five direction findings for phases 2 and 3 were recorded as constraints
step 5 must write in. See [Phases 2 And 3 Architecture](#phases-2-and-3-architecture).

No violations were found in:

- the typed request field, its `@Default` and its compatibility marker;
- the marker constant, with the frame format unchanged;
- keeping `sesori_shared` platform-free;
- the trust postures;
- the plugin boundary;
- the rule move into `sesori_shared`.

This corrected version was not re-reviewed. Step 5 sends the detailed
phases 2 and 3 through review again.

**`architecture-plan-review` of phases 2 and 3, 2026-10-07 (step 5):
rejected, then corrected.** Three blocking and five non-blocking findings,
all applied without re-review as AGENTS.md allows:

1. `HistoryWindow` would have reached the DAO, a lower layer, and its newest
   variant kept the ambiguous `limit: null` pair. It now stops at the
   repository, has three exclusive variants, and the through window gets its
   own plain DAO read.
2. `PromptSearchCubit` had no creation site or inputs. The Prompts view now
   creates it from a new `SessionDetailPresentationScope` capability, and
   the view pushes its built list into it.
3. A required W3 field on the step 8 request would break a released app. It
   is required only if no public release contains step 8 by then.
4. One service helper decides the history source for every store-only
   route.
5. The index reuses `getPageRowsWithSyncState` instead of a new DAO read.
6. The pin chooser lives next to `TranscriptPromptListBuilder`.
7. `loadMessagesThrough` reports `TargetMissing`, so the screen decides
   nothing about history.
8. The tool-output layers, the variant switch for output readers, and the
   2026-10-07 user decisions are now named in this plan.

No violations were found in P11, P12, P14, the step 6 and step 11 moves,
the step 7 store and archive paths, the "unsupported" mapping, the
`ToolState` union, the plugin boundary, or headless operation.
