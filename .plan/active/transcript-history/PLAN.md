# Transcript History: Wire Savings And The Prompt Index

## Status

- Planned 2026-10-06. Step 1 (this plan) is the plan PR.
- Phase 1 (steps 2–4) is detailed and ready to implement.
- Phases 2 and 3 (steps 6–13) are rough. Step 5 details them and sends the
  revised plan through `architecture-plan-review` before step 6 starts.
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
| P8 | The prompt index has no revision counter (turn-navigation F1). The app refetches it when it replaces its whole message list: a refresh, a reconnect resync, or a history rewrite. Paging older messages and the load-through only prepend, so they never refetch it. An open Prompts screen keeps its opening snapshot, as turn-navigation already requires; a refetched index reaches it only through that screen's existing snapshot-refresh rule. | Q2 fetches the index once per open. A refetch on replacement covers compaction and history rewrites. A stale entry fails one tap with an inline error. |
| P9 | The load-through (Q5) is a lower bound on the existing page request, not a new route. | It reuses the cursor, the paging code and the projection. |

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

## Later Phases (Rough)

Step 5 turns these bullets into detailed steps. They are direction, not a
contract.

Architecture constraints step 5 must write in. They came from the step 1
architecture review:

- **Bridge routes (steps 7, 11 and 12).**
  - Each route goes handler → `ChatHistoryService` →
    `ChatHistoryRepository` → `ChatHistoryDao`.
  - Preview and excerpt cuts, entry mapping, and the slim-part projection
    live in the repository, not the handler (same placement as W2).
  - Step 5 states how the archived audit-file path serves the index and
    search. The narrower-database-projection fallback does not apply there.
- **Older bridges (step 9).** An older bridge's 404 becomes a typed
  "unsupported" result in the app's `SessionRepository`, following the
  existing pattern in `client/module_core/lib/src/repositories/session_repository.dart`.
  The cubit never branches on a status code.
- **Pin (step 10).** Choosing the index entry is business logic in
  `module_core`, in the cubit state or the turn model. `module_app_ui` only
  turns it into a `TranscriptStickyAbove` place. `_stickyOpeners` stays
  layout-only.
- **Search merge (step 11).** Merging loaded-range and bridge matches
  belongs in `module_core`, not in `session_prompts_view.dart`.
- **W3 wire shape (step 12).** A slim tool part must not pair nullable output
  and error with a separate "has detail" flag, because that allows
  contradictory states. Step 5 defines a sealed or otherwise exclusive shape
  in which each variant carries only its valid fields.

### Phase 2: Prompt Index And Search (Steps 6–11)

- **Shared rule (step 6).**
  - Move rule A into `sesori_shared` as a pure fold over `MessageWithParts`,
    together with the two message extensions it needs
    (`hasRenderableUserContent`, `promptText`).
  - The fold returns each user message's kind: opener, follow-up, or none.
  - `TranscriptTurnBuilder` delegates to it with no change in behavior. The
    existing turn tests are the parity proof.
- **Index route (step 7).**
  - A new route, for example `POST /session/prompts`, returns entries in
    chronological order. Each entry is an opener, or a follow-up carrying
    its opener's message id, with:
    - `messageId` and `seq`;
    - `number`;
    - `createdAt`;
    - a preview of at most 300 characters, plus whether the text continues.
  - It covers archived sessions.
  - Performance budget: the largest session within a few hundred
    milliseconds on the bridge. A narrower database projection is the escape
    hatch, added only if measurement demands it.
- **Load-through (step 8).**
  - `SessionMessagesRequest` gains an inclusive lower bound, for example
    `throughSeq`, where null means a normal page.
  - The bridge returns every message from that bound up to `before`.
  - The app's cubit prepends the result like an older page.
  - The worst case (the whole 17 MB session at once) is measured under W1.
    Running the deflate in an isolate is the escape hatch.
- **App index (step 9).**
  - After the first page, when `olderMessagesCursor != null`, fetch the index
    once (Q2). A 404 from an older bridge falls back to today's screen (Q6).
  - The Prompts screen lists every prompt. "Load earlier prompts" disappears
    when the index is present.
  - Tapping an unloaded prompt runs the load-through:
    - the spinner appears only after about 150 ms;
    - the new messages are prepended off-screen;
    - then the transcript scrolls to the prompt (Q5).
  - Replacing the whole message list drops the index and refetches it.
    Paging and the load-through do not (P8).
  - A tap on an entry the bridge no longer has shows an inline error.
- **Pin (step 10).** When the top of the loaded range sits inside a turn
  whose opener is not loaded, the pin uses the latest index entry older than
  the loaded range, as a synthetic `TranscriptStickyAbove`.
- **Search (step 11).**
  - A route, for example `POST /session/prompts/search`, does a full-text
    case-insensitive match over every prompt. It returns entries with an
    excerpt window.
  - `promptSearchPattern` and `promptExcerpt` move to `sesori_shared`, so
    both sides match and cut excerpts the same way.
  - Loaded-range matches still show instantly; bridge matches merge in by
    `seq`.
- **Analytics.** Considered; probably none. Prompt navigation is a
  convenience, not an activation or adoption question. Step 5 records the
  final answer.
- **Harness capabilities.** The index uses each harness's existing follow-up
  behavior. No new harness gap is expected. Step 5 confirms this against
  `docs/HARNESS_CAPABILITIES.md` "Transcript turn boundaries".

### Phase 3: Slim Tool Parts (Steps 12–13)

- **Bridge (step 12).**
  - `SessionMessagesRequest` gains an honest `@Default` opt-in for summary
    tool parts. v1.9.0 apps omit it and keep full parts.
  - When opted in, shell tools are sent without output and error, in a
    shape that still tells the app whether detail exists, so the disclosure
    still shows. The shape follows the constraints above.
  - A new route returns one tool part's output and error.
  - SSE live parts stay full.
- **App (step 13).**
  - Opt in on page reads.
  - On expand:
    - the row opens at once to a fixed-height loading body;
    - the spinner appears after about 150 ms;
    - the body then animates to its fetched height;
    - a failure shows inline with a retry.
  - The fetched detail is merged into the cubit's message so it survives
    rebuilds.
- `docs/HARNESS_CAPABILITIES.md` and `tools-and-file-changes.md` gain the
  "fetched on expand" behavior.

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
| 6 | Move the follow-up rule into `sesori_shared` | ≤ 600 | ⚙️ cross-package move with parity |
| 7 | Bridge prompt index route | ≤ 900, including generated | 🚧 new wire contract, archived path |
| 8 | Load-through bound, bridge and cubit | ≤ 600 | 🚧 paging and wire change |
| 9 | Index fetch, full Prompts list, far-tap flow | ≤ 1,000 | 🚧 scroll stability and lifecycle |
| 10 | Pin over unloaded turns | ≤ 500 | ⚙️ |
| 11 | Bridge search route and app merge | ≤ 800 | ⚙️ |
| 12 | W3 bridge summary parts and detail route | ≤ 700 | 🚧 wire opt-in, compatibility |
| 13 | W3 app opt-in and expand loading | ≤ 700 | ⚙️ motion and state merge |
| 14 | Reconcile regression docs | ≤ 300 | 🌱 |
| 15 | Run the L3 matrix and retire | ≤ 250 | 🌱 |

Steps 3 and 4 are split on purpose. Each is a transport and security change
reviewed on its own, and step 3 is valid alone because no app asks yet. Step 5
may split steps 6–13 into substeps; when it does, it updates the totals and
titles.

### Step Dependencies

- Step 2 depends on step 1. The user accepted O1 on 2026-10-07.
- Step 3 depends on step 1. Step 4 depends on step 3.
- Step 5 depends on steps 2–4 having merged, so that it details phases 2 and
  3 with phase 1's evidence (real compressed sizes).
- Steps 6–13 follow the order step 5 records.
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
| 2 | One nullable prompt index in the session detail state, dropped on list replacement. | Q1/Q2 need it. |
| 2 | One pending far-tap target, so the spinner can appear after 150 ms. | Q5 needs it. |
| 3 | Fetched tool details merged into the cubit's messages, plus one loading flag per expanding row. | W3 needs them. |

Deliberately not added:

- a bridge-stored index, or a revision counter (F1);
- an inflate size cap, a compression size threshold, or per-route
  compression opt-in;
- compression of SSE events or of requests;
- a search index (the query scans prompt rows);
- client caching of the index across session opens.

## Proportionality And Accepted Risk

| Risk | Evidence level | Accepted outcome |
|---|---|---|
| v1.8.3 and older apps lose the shell command label on page reads (W2). | Reasoned from the v1.8.4 release history. | Cosmetic, on apps two releases old. Accepted by the user on 2026-10-07 (O1). |
| A stale index entry after a background history rewrite that has not yet triggered a refetch (P8). | Theoretical interleaving. | One tap shows an inline error. The next list replacement refetches. |
| CRIME/BREACH-style length inference on deflated transcript pages. | Theoretical. Needs adaptive injection, length observation and repeated user re-fetches. | Not mitigated. See [Security And Privacy Of W1](#security-and-privacy-of-w1). |
| Bridge CPU spent deflating a very large load-through response. | Measured sizes: up to 17.4 MB for the largest session. | Measured in step 8. Isolate offload only if the bridge stalls visibly. Attachment responses are never deflated (P4). |

## Cleanup Assessment

| Step | Cleanup |
|---|---|
| 2 | Removes the title from shell tools on page reads. The mapper's alias stays, because live SSE still feeds v1.8.3 and older apps. Its comment is updated to say only live events keep it. |
| 9 | Removes "Load earlier prompts" from the Prompts screen when the index is present. It stays for v1.9.0 bridges (Q6). |
| 11 | Moves the client-only `prompt_search.dart` helpers to `sesori_shared`, leaving no duplicate. |
| 6 | Moves rule A out of `transcript_turns.dart`. The private helpers are deleted, not kept as wrappers. |
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
- Steps 3, 7, 8 and 12 change wire contracts. Each needs a JSON test proving
  that the older peer's shape still decodes.
- Architecture-bearing steps (3, 4, 7, 8, 9 and 12) get
  `architecture-implementation-review` through a sub-agent, within AGENTS.md's
  limits.

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
step 5 must write in. See [Later Phases](#later-phases-rough).

No violations were found in:

- the typed request field, its `@Default` and its compatibility marker;
- the marker constant, with the frame format unchanged;
- keeping `sesori_shared` platform-free;
- the trust postures;
- the plugin boundary;
- the rule move into `sesori_shared`.

This corrected version was not re-reviewed. Step 5 sends the detailed
phases 2 and 3 through review again.
