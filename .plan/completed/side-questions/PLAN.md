# Side Questions ("by the way")

## Goal

While a session works, the user can ask a quick question on the side. The agent
answers from what the session already knows, uses no tools, and doesn't
interrupt or change the main session. The side chat opens in a half-height sheet
over the session on a phone, or in a side panel on desktop. The main chat stays
visible and keeps streaming behind it. Follow-ups are allowed. Side chats are
stored by the bridge with their session, can be reopened later, and are never
written to the main transcript.

Phase 1 ships this for Claude Code and Codex, through their native seams. Every
other harness gets an honest reason when the user taps the entry.

## Decisions (final, from the session-branching round, 2026-11-14)

- Q7: answer from what the session already knows, with no tools.
- Q8: half-height sheet over the session on a phone, a side panel on desktop.
  The main chat stays visible and keeps streaming. Follow-ups are allowed.
- Q9: side chats are kept with the session, can be reopened, are stored on the
  bridge, and are never written to the main transcript.
- Decided without asking:
  - Claude Code uses its native side question if the pinned CLI supports it
    headlessly. It does (see Verified facts).
  - Codex uses its one-shot ask, `thread/sample`.
  - Every other harness uses a short-lived fork that is never listed. That is
    phase 2, and it depends on the fork plan's plugin capability.
- Analytics: report the side question with the harness kind and the outcome
  only.
- The user prefers simple, uniform behaviour on every harness.
- Round 2, B1 (2026-11-15): **D**. Two entry points: a side-question button in
  the composer's options pill, next to `+` and `/`, and a `/btw` command.
- Round 3, Q1 (2026-11-15): **B**. Typing "/btw " (with the space) switches the
  whole composer into "Side question" mode:
  - the "/btw " text disappears and the rest of what was typed stays;
  - a "Side question" label with a speech-bubble icon and ✕ appears above the
    field, and the field's border darkens;
  - ✕ returns to the normal composer, keeping the text;
  - Send opens the side sheet (the panel on desktop) with the question and
    its answer.
- Round 3, Q3 (2026-11-15): sending from a side chat back to its session never
  archives anything and shows no archive switch. That send is owned by the
  session-send plan.
- 2026-11-15: side-question answers don't stream, on any harness. Every
  harness shows "Thinking…" and then the whole answer at once, because Claude
  Code's `side_question` returns its answer in one piece. This includes the
  phase-2 fork fallback, even where a fork could stream, so the behaviour stays
  uniform.
- Round 4, q2 (2026-11-15): **A**. An archived session's notice shows a
  "Side chats (N)" link, only when the session has side chats. It sits where
  the composer's side-question button used to be and opens the side-chat sheet
  (the panel on desktop) read-only. See Client UX, Archived entry.
- Round 4, q3 (2026-11-15): **A**. Codex threads saved as attached threads of a
  parent (side chats made in Codex's own terminal) are hidden from Sesori's
  Codex session list, as Codex's own list hides them. This is a small Codex
  plugin change outside this plan's steps, shipped as its own PR.

The following are separate plans owned elsewhere. This plan only notes the
seams:

- **Edit and fork plan.** The phase-2 fallback is an unlisted fork, so it needs
  that plan's plugin fork operation.
- **Merge plan.** It owns "Send to main session" from a side chat. The side chat
  view leaves a slot for that action in each answer's actions (see Client UX).
  That send never archives the main session.
- **Composer mode.** The edit-and-fork plan's edit mode also takes over the
  composer header. Whichever plan lands first adds one sealed composer mode in
  `SessionDetailCubit` (normal, editing, side question), so the two modes can't
  overlap. Starting an edit leaves a side question, its words kept as plain
  text. A side question can't start while editing (Cancel the edit first), so
  it never silently discards an edit in progress.

## Verified facts (pinned versions, 2026-11-14)

### Claude Code (target 2.1.322, `claude_plugin_descriptor.dart:72`)

These were checked in the 2.1.322 binary and with live probes using haiku, for
a fraction of a cent.

- **Supported in headless mode.** `claude -p` stream-json handles the control
  request
  `{type:"control_request", request_id, request:{subtype:"side_question", question, history?:[{question, response}]}}`.
  The SDK's `askSideQuestion` and the TUI's `/btw` are other callers of the same
  core code.
- **Success response.** The CLI replies with `control_response` subtype
  `success`, whose `response` is `{response: string|null, synthetic: bool, refusal_fallback?: {original_model, fallback_model, content}}`.
  - `synthetic: true` means the model gave no usable text, and the CLI wrote a
    stand-in. Examples are "(The model tried to call X instead of answering
    directly…)" and "(API error: …)".
  - `response: null` means there was nothing to answer.
  - `refusal_fallback.content` is a notice that a fallback model answered after
    a refusal.
- **Runs alongside a running turn.** The live probe got an answer while the
  main turn was still streaming. The injected prompt tells the model the main
  agent isn't interrupted. An unfinished tool call shows up in its context as
  "still in progress". `interrupt` does not cancel side questions.
- **No busy refusal in the local CLI. The claim was false.**
  `side_question_busy` exists only in the error-code enum and docs for
  Anthropic's hosted server. The local CLI has no concurrency limit: the probe
  ran three side questions at once. The local CLI refuses only when the session
  is shutting down, or after an 11-minute deadline ("side_question timed out").
- **No tools, no transcript.**
  - `canUseTool` always denies, and the run is limited to one model turn
    (`maxTurns:1`).
  - Nothing is written to the session `.jsonl`; the probe checked this with
    unique marker strings.
  - The call reads the main session's prompt cache but never writes to it.
- **No streaming.** Before the answer, the CLI sends
  `system/control_request_progress` frames with status `started` or
  `api_retry`. Then one `control_response` arrives.
- **Cancel.** `{type:"control_cancel_request", request_id}` makes the CLI reply
  with the error "Side question cancelled". This was verified live.
- **Works on a freshly resumed process.** After `--resume <id>`, a side
  question sent as the very first frame, with no prompt, answered from the
  resumed conversation. So an idle session only needs to be made resident first.
- **Older CLIs.** The plugin's minimum CLI is 2.1.221. A CLI without the handler
  should reply `"Unsupported control request subtype: side_question"`, the
  generic dispatcher error, which was verified on 2.1.322 with a made-up
  subtype. The first CLI version with the handler is unknown; 2.1.321 to 2.1.325
  all have it.
- **How Sesori sends control requests today.**
  - `ClaudeStreamClient.sendControlRequest`
    (`bridge/sesori_plugin_claude/lib/src/api/claude_stream_client.dart:225-264`)
    writes the frame. Request ids are `sesori-<n>`, and a `Completer` waits in
    `_pending`.
  - `_handleLine` matches the `control_response` back to that completer
    (`:306-320`).
  - The default timeout is 60 s (`:44`). It is too short for a side question,
    and nothing sends `control_cancel_request` yet.
  - `ClaudeSessionProcessRepository` calls it for `set_model` and
    `set_permission_mode` (`:316`, `:323`), for `interrupt` (`:401-406`), and
    through its generic `sendControlRequest` (`:385-393`).
    `ensureResident` is at `:254`.

### Codex (target `rust-v0.167.2`, `codex_runtime_manifest.dart:32`; PATH minimum 0.139.0)

Checked in the upstream source at the tag, and in the local 0.169.0 schema.

- **`thread/sample` exists and is experimental.** It is marked
  `#[experimental("thread/sample")]` in `app-server-protocol/src/protocol/common.rs:573-585`.
- **Sesori's existing opt-in covers it.** The server rejects experimental
  methods unless `initialize` sent `capabilities.experimentalApi`. Sesori
  already sends that (`bridge/sesori_plugin_codex/lib/src/codex_app_server_client.dart:162`).
- **Params:** `threadId`, `expectedTurnId` and `prompt`, plus optional `effort`,
  `disableMcp` and a few others.
- **Response:** `{sourceTurnId, responseId, text: string|null, inputTokens?, cachedInputTokens?, outputTokens?}`.
  `text` is null when the model tried a tool call or gave no text.
- **No tools and no history writes.** A tool call is never run. The sample is
  an ephemeral fork of the latest model context, with no rollout file, and is
  removed afterwards. The upstream test asserts the parent rollout is
  byte-identical afterwards.
- **One result, bounded.** There is no streaming. The server stops at 30 s, and
  caps the prompt at 4,000 bytes and the output at 64 KiB.
- **Cancel exists but Sesori can't reach it yet.** `thread/sample/cancel {requestId}`
  takes the JSON-RPC id of the pending sample, but Sesori's transport hides that
  id.
- **History.** There is no `history` parameter. Earlier side Q&A has to go
  inside `prompt`, within the 4,000-byte cap.
- **The pin can't ask mid-turn. The claim was false for the pin.**
  `allowInProgressTurn` does not exist at 0.167.2 or 0.168.0.
  - At the pin, a sample needs an idle thread, and `expectedTurnId` must be its
    latest finished turn. Otherwise it fails with "sample source must be idle".
  - `allowInProgressTurn` arrives in 0.169.0. With it, the latest turn may still
    be running, and the server adds a note that the copy was taken mid-turn.
  - So phase 1 raises the Codex target to at least 0.169.0.
- **The thread must be loaded.** The source thread must be loaded in this
  app-server process ("thread/sample requires a loaded source"). The plugin
  already has `CodexSessionService.resumeThreadIfNeeded`
  (`services/codex_session_service.dart:576`).
- **Where Sesori sends requests.** `CodexAppServerTransport.request({method, params, timeout})`
  sends them (`codex_app_server_client.dart:68`, WebSocket at `:221-249`). New
  calls sit in `CodexAppServerApi` (`api/codex_app_server_api.dart`), next to
  `startTurn`.

### Sesori today

- No harness integration calls any side-question operation.
- **Optional plugin operations** are interfaces that a plugin implements and
  that bridge repositories match with `if (plugin case final XPluginApi api)`.
  Examples are `SessionExternalActionsPluginApi` and `McpManagementPluginApi`.
- **Client-visible plugin capabilities** come from descriptor getters
  (`supportsPromptAttachments`, `namesCommandInvocations`), passed through
  `PluginLifecycleService` into `PluginMetadata`. Bridge-wide capabilities sit
  on `PluginListResponse`, such as `supportsFileUploads`.
  - Both kinds use `@Default(false)` with a dated compatibility comment.
  - The client reads them once per session in
    `SessionDetailLoadService._loadPluginCapabilities`.
- **Routes.** Session reads are `POST` with a `SessionIdRequest` body, for
  example `/session/questions`. Unknown routes return 404.
- **Relay timeout.** It defaults to 30 s; individual calls pass longer ones, for
  example 3 min 30 s for MCP (`client/module_core/lib/src/api/mcp_api.dart:16`).
- **Bridge database.** It is at schema version 24
  (`bridge/app/lib/src/api/database/database.dart:48`), with foreign keys on.
  - Session-owned tables reference `SessionTable.sessionId` with
    `onDelete: KeyAction.cascade`, for example `session_continuations`.
  - Deleting a session deletes its row (`daos/session_dao.dart:781`).
- **Phone session screen.**
  - The top bar is full.
  - The overflow menu holds MCP and the session actions
    (`client/app/lib/features/session_detail/session_detail_screen.dart:168`).
  - The composer's options pill opens from a chevron and holds `+` (attach) and
    `/` (commands) (`module_app_ui/.../composer_options_accordion.dart`).
- **Sheets.** `showPregoBottomSheet` offers fixed natural, 70% and full sizes,
  with no snap points. Nothing in the client uses `DraggableScrollableSheet`.
- **Desktop session page.** It has a toolbar with Changes, Prompts and a menu,
  and no side panel yet. The cockpit sidebar slides by transform so the page
  doesn't jump (`client/desktop/lib/core/widgets/desktop_cockpit_shell.dart:339`).

## Design

### Behaviour, uniform across supporting harnesses

1. The user opens the side chat from the session and types a question.
2. The bridge asks the harness, passing this side chat's earlier exchanges as
   history. The main session keeps running: Sesori neither queues the main turn
   nor waits on it.
3. The answer arrives in one piece. The sheet shows "Thinking…" while it waits,
   then the whole answer. No harness streams side answers, including the
   phase-2 fallback: Claude Code's `side_question` returns all at once, and
   every harness behaves the same way (see Decisions).
4. On success, the bridge stores the exchange: question, answer and optional
   notice. A refused or failed ask is not stored. The sheet shows why in place,
   with Retry, and the question stays in the field.
5. Closing the sheet while waiting doesn't cancel the ask. The answer is still
   stored, and it shows the next time the chat is opened.
6. Opening the entry starts a new side chat. The header lists this session's
   earlier side chats, newest first, titled by their first question; any of them
   can be reopened and continued.
7. Archived sessions show their side chats read-only. Sub-agent (child)
   sessions don't offer the entry.

### Plugin contract (`sesori_plugin_interface`)

- `BridgePluginDescriptor.supportsSideQuestions` is a `bool` that defaults to
  `false`. It is the client-visible declaration and works before the plugin
  starts, like `supportsPromptAttachments`. Claude and Codex return `true`.
- `abstract interface class SideQuestionPluginApi` is the operation:

  ```dart
  /// Answers [question] from what the session already knows, without running
  /// tools and without writing to the session's transcript, while any running
  /// turn continues. [history] is this side chat's earlier exchanges, oldest
  /// first. May make an idle session resident; never starts or queues a turn,
  /// and never changes or restarts a running one. Returns the whole answer at
  /// once; side answers never stream.
  Future<PluginSideAnswer> askSideQuestion({
    required String sessionId,
    required String question,
    required List<PluginSideExchange> history,
  });
  ```

- `PluginSideExchange({required String question, required String answer})`.
- `sealed PluginSideAnswer` has two variants:
  - `PluginSideAnswered({required String text, required String? notice})`.
    `notice` is, for example, Claude's fallback-model notice.
  - `PluginSideRefused({required PluginSideRefusal reason})`.
- `enum PluginSideRefusal` has these values:
  - `harnessUpdateRequired`: the installed harness lacks the seam, or can't ask
    mid-turn.
  - `noTurnYet`: there is nothing to answer from.
  - `tooLong`.
  - `noAnswer`: the model tried a tool, gave no text, or gave a stand-in.
- Transport errors and timeouts are thrown as usual, and the bridge returns
  them as request failures.
- Each implementing plugin gets a test that the descriptor flag and the
  interface agree.

The plugin owns how history reaches its harness. That is backend semantics,
because Claude takes a list and Codex needs the history inside one prompt.

### Bridge (`bridge/app`)

- **Storage.** Schema v25 adds one table, `side_chat_exchanges`
  (`SideChatExchangesTable`, `SideChatExchangeDto`) with these columns:
  - `id` (text, primary key)
  - `sessionId` (references `SessionTable.sessionId`, cascades on delete)
  - `sideChatId` (text)
  - `question`
  - `answer`
  - `answerNotice` (nullable: absence is meaningful)
  - `askedAt`
  - `answeredAt`

  It has an index on `(sessionId, sideChatId, answeredAt)`. A side chat is the
  group of rows sharing a `sideChatId`; there is no separate table. Only
  successful exchanges are written, in one write after success, so there are no
  pending rows, no startup repair, and nothing to reconcile. Rows go when the
  session is deleted, and stay when it is archived. If another plan lands a v25
  first, move this to the next version, following the Drift conflict rule in
  `bridge/AGENTS.md`.
- **Layers.**
  - `SideChatDao` is a dumb insert plus a list for one session.
  - `SideChatRepository` maps rows to wire models and groups them into chats.
    `listForSession({sessionId})` returns `SideChatListResponse`.
    `historyFor({sessionId, sideChatId})` returns the chat's
    `PluginSideExchange`s oldest first, or none for a null id.
    `recordExchange({sessionId, sideChatId?, question, answer, notice, askedAt})`
    mints the side-chat id when it is null and the exchange id, both with
    `randomHexId` (`repositories/random_hex_id.dart`), writes the row, and
    returns `(sideChatId, SideChatExchange)`.
  - `SessionRepository.askSideQuestion` is a thin plugin-backed operation, under
    the new `SessionOperation.askSideQuestion`. It is the one owner of "this
    harness supports it":
    1. Resolve the binding to the plugin id and backend session id.
    2. Check `PluginRuntime.supportsSideQuestions({pluginId})`. This is new,
       next to `supportsPromptAttachments`, and plumbed through
       `bridge_runtime_runner.dart`. The check comes before `_runtime.use`, so
       an unsupported harness is never started. If the check fails, return
       `harnessUnsupported`.
    3. Call `_runtime.use`, so an idle plugin starts the way it does for a
       prompt.
    4. Match on `SideQuestionPluginApi`. If it doesn't match, return
       `harnessUnsupported`.
    5. Map the `PluginSideAnswer` to `SideQuestionAskResult`, using
       `PluginSideAnswerMapper` in `repositories/mappers/`.
       `SideQuestionAskResult` is a sealed repository model in
       `repositories/models/`: `SideQuestionAnswered({text, notice})` or
       `SideQuestionRefused({SideQuestionRefusal reason})`, where the reason
       is already the `sesori_shared` wire enum.
  - `SideQuestionService` orchestrates one ask:
    1. Call `ArchivedSessionValidator.requireNotArchived`. This is the single
       archive rule. The existing handler path turns its exception into the
       archived rejection, and an unknown session gives the existing 404.
    2. The returned stored session must be a root session. A child session
       throws a `PluginOperationException`, which is a 400; the client never
       offers the entry there.
    3. Read the side chat's history from `SideChatRepository.historyFor`.
    4. Call `SessionRepository.askSideQuestion`.
    5. On `SideQuestionAnswered`, call `SideChatRepository.recordExchange` and
       return `AskSideQuestionResponse.answered` with what it returns. On
       `SideQuestionRefused`, return `AskSideQuestionResponse.refused` with its
       reason. The service only picks the response variant; all DTO mapping
       stays in the two repositories.
    - **Not on a session lane.** The service does not use
      `SessionOperationDispatcher`. A family lane would hold that session's
      prompts, aborts and replies for up to 3 minutes behind the ask, and a
      side question writes nothing the lane protects. The only races are an
      archive or a delete during an ask. An archive leaves one more stored
      exchange on a now read-only chat, which is harmless. A delete makes the
      insert fail its foreign key, and that request fails, which is correct for
      a deleted session.
- **Routes.** Both are `BodyRequestHandler`s with Freezed bodies from
  `sesori_shared`:
  - `POST /session/side-chats` takes a `SessionIdRequest` and returns
    `SideChatListResponse` from `SideChatRepository.listForSession`.
  - `POST /session/side-question` takes an `AskSideQuestionRequest` and returns
    `AskSideQuestionResponse` from `SideQuestionService`.

  The names are kebab-case, like `/session/external-actions` and
  `/session/tool-output`.

  A request handler awaits only its own plugin call, so a side question never
  blocks the prompt path or the main turn's events.
- **Logs.** They keep the session id, the plugin id, the outcome, timings and
  the original errors. They never include question or answer text: that is
  prompt and transcript content with no debugging value.
- Bridge SSE gets no new events in phase 1 (see Complexity budget).

### Wire (`shared/sesori_shared/lib/src/models/sesori/side_chat.dart`)

- **Exchange and chat models.**
  - `SideChatExchange({id, question, answer, answerNotice?, askedAt, answeredAt})`
    stores times the way the session models do.
  - `SideChat({id, exchanges})` lists exchanges oldest first.
  - `SideChatListResponse({sideChats})` lists chats newest first, by their last
    answer.
- **Ask request.** `AskSideQuestionRequest({sessionId, sideChatId?, question})`.
  A null `sideChatId` starts a new chat, and the bridge mints its id.
- **Ask response.** `AskSideQuestionResponse` is a sealed union declared with
  `@Freezed(unionKey: "type", fallbackUnion: "unknown")`, like
  `abort_session_request.dart` and `form_field.dart`:
  - `answered({sideChatId, exchange})`.
  - `refused({reason})`, with `enum SideQuestionRefusal` values
    `harnessUnsupported`, `harnessUpdateRequired`, `noTurnYet`, `tooLong`,
    `noAnswer` and `unknown` (`unknownEnumValue: unknown`).
  - `unknown()`, which an older app shows with a generic reason.

  Archived sessions use the existing archived rejection, so the enum has no
  archived value.
- **Capabilities.**
  - `PluginMetadata.supportsSideQuestions` (`@Default(false)`) is per harness.
  - `PluginListResponse.supportsSideQuestions` (`@Default(false)`) is per
    bridge. It says this bridge has the routes.
  - Both carry
    `// COMPATIBILITY 2026-11-14 (v1.14.0): Older bridges omit this capability because they have no side-question routes. Remove @Default and require the field once all supported production bridges send it.`
- **Compatibility.**
  - A new app talking to an older bridge reads both flags as false and never
    calls the routes.
  - An old app talking to a new bridge ignores the new fields and routes.
  - A newer bridge's unknown refusal reads as `unknown`, which shows a generic
    reason.

### Harness adapters

**Claude Code (`sesori_plugin_claude`)**

- **API: `ClaudeStreamClient.sendSideQuestion({question, history, timeout})`.**
  It sits next to `reconnectMcpServer`.
  - It writes the `side_question` control request, with `history` as
    `[{question, response}]`, and waits through the existing `_pending`
    completer.
  - It parses the reply into a Freezed `ClaudeSideQuestionResponseDto` in
    `api/models/`.
  - It raises `Unsupported control request subtype…` as a typed
    `ClaudeControlUnsupportedSubtypeException`.
  - It has its own 3-minute timeout. On timeout it writes
    `control_cancel_request` for that request id, so the CLI stops working on
    an ask nobody waits for.
- **Repository: `ClaudeSessionProcessRepository.sendSideQuestion({sessionId, question, history})`.**
  It sits next to `interrupt`.
  - It requires a resident process and throws otherwise, like
    `sendControlRequest`. It never starts or reconfigures a process.
  - It maps the DTO, or the typed exception, to `PluginSideAnswer` through
    `ClaudeSideAnswerMapper` in `repositories/mappers/`.
- **Service: `ClaudeSessionService.askSideQuestion({sessionId, directory, question, history})`.**
  The service already owns process residency for turns, so it owns it here.
  - If `_processes.isResident(sessionId)`, it sends as is. It never calls
    `ensureResident` on a resident process: that path reapplies the model and
    permission selection, and tears the process down when the effort differs,
    which would kill the running main turn.
  - Otherwise it calls `ensureResident` with `createNew: false`,
    `purpose: session`, a null model, effort and permission mode,
    `fastMode: false`, and `_approvals.allowedToolsForSession`, as the catalog
    probe does with its nulls. A fresh `--resume` answers correctly. A later
    prompt applies its own selection; if that restarts the process while an
    ask is still waiting, the ask fails and shows Retry.
  - Then it calls `_processes.sendSideQuestion`.
- **Plugin impl.** For a session it created that has no turn yet
  (`_unstartedSessions`), it returns `noTurnYet` without starting a process.
  Otherwise it resolves the directory with `_directoryForSession`, as prompts
  do, and delegates to `ClaudeSessionService.askSideQuestion`.
- Mapping:
  - A non-empty `response` with `synthetic: false` becomes `PluginSideAnswered`.
    Its `notice` is `refusal_fallback?.content`.
  - `synthetic: true` or a null response becomes `noAnswer`.
  - The error `Unsupported control request subtype…` becomes
    `harnessUpdateRequired`, which covers CLIs between 2.1.221 and the
    unknown first version with the handler.
  - "Session is shutting down" and other errors are thrown.
- `control_request_progress` frames stay logged at debug level. Nothing models
  them.
- Descriptor: `supportsSideQuestions => true`.

**Codex (`sesori_plugin_codex`)**

- First, raise the runtime target to the newest stable release at or above
  0.169.0, in its own step (see Steps). `minPathVersion` stays at 0.139.0, so a
  PATH Codex below 0.169 still works for everything else.
The Codex adapter follows the plugin's own chain: API, then
`CodexThreadRepository`, then `CodexSessionService`, then the plugin impl.

- **API: `CodexAppServerApi.sampleThread({threadId, expectedTurnId, prompt})`.**
  - It sends `thread/sample` with `allowInProgressTurn: true` and the default
    `disableMcp`, so the cached tool prefix is kept.
  - It returns a Freezed `CodexThreadSampleDto` in `api/models/`.
  - The client timeout is 40 s, so the server's own 30 s "timed out" error
    arrives first.
- **API: `CodexAppServerApi.listLatestTurn({threadId})`.** As built in step 5,
  it sends `thread/turns/list` with `limit: 1`, `sortDirection: desc` and
  `itemsView: notLoaded` (present since 0.139), instead of `thread/read` with
  `includeTurns: true`, which would load every turn's items on each ask. Live
  on 0.169.0 it reports a running turn too. A thread with no prompt yet fails
  with "thread … is not materialized yet", which means no turn.
- **Repository: `CodexThreadRepository.sampleThread`.** It returns
  `PluginSideAnswer`, mapped by `CodexSideAnswerMapper` in
  `repositories/mappers/`, the same shape as Claude. The mapper takes the DTO,
  or one of the "unknown variant `thread/sample`" and "sample source must be
  idle" errors (see Mapping).
- **Repository: `CodexThreadRepository.latestTurnId({threadId})`.** It calls
  `listLatestTurn` and returns that turn's id, or null when the thread has no
  turn.
- **Service: `CodexSessionService.askSideQuestion`.**
  1. `expectedTurnId` is the running turn id that the plugin impl passes in,
     from `_activeTurnByThread[threadId]`, if one runs.
  2. Otherwise it is `CodexThreadRepository.latestTurnId`. This is the one
     source for the idle case. No new state records finished turns.
  3. With no turn at all, it returns `noTurnYet`.
  4. It builds the prompt with the builder below; a null prompt returns
     `tooLong`. Then it calls `sampleThread` and returns its answer.
- **Plugin impl.** It makes the thread resident with `resumeThreadIfNeeded`
  and applies the resume the way the reconnect restore does, so a cold resume
  records the thread's model and directory, and a turn still running becomes
  the active turn. Then it passes in the active turn id and delegates.
- **Prompt builder.** `CodexSideQuestionPromptBuilder`
  (`services/codex_side_question_prompt_builder.dart`) owns the template and
  the byte budget. It has no dependencies; the service holds it as a `const`
  collaborator, the way `SessionRepository` holds its mappers. It returns the
  prompt, or null when it can't fit.
- History goes inside the prompt with one fixed template. The earlier exchanges
  come oldest first, labelled as earlier side questions that are not part of
  the main conversation. Then the new question, with a line asking for an
  answer from what the session already knows, without tools.
  - To fit the 4,000-byte cap, it drops the oldest exchanges first, then
    shortens the oldest remaining answer.
  - If the template plus the question alone are over the cap, it returns null,
    which the service turns into `tooLong`.
  - The template text is plugin-owned and covered by a unit test.
- Mapping (`CodexSideAnswerMapper`):
  - `text` non-null becomes `PluginSideAnswered` with a null notice.
  - `text` null becomes `noAnswer`.
  - "unknown variant `thread/sample`" (before 0.164.0) and "sample source must
    be idle" (0.164.0 to 0.168.x, which ignore `allowInProgressTurn`) become
    `harnessUpdateRequired`. Sesori always sends `experimentalApi`, so the
    "requires experimentalApi" error can't happen and isn't mapped.
  - Other errors are thrown.
- `thread/sample/cancel` isn't used in phase 1. The 30 s server deadline bounds
  an abandoned ask, and exposing request ids would mean changing the transport
  interface.
- Descriptor: `supportsSideQuestions => true`.

### Client core (`client/module_core`)

- `SideChatApi` sends `listSideChats` (30 s) and `askSideQuestion`
  (3 min 30 s, above the bridge's longest plugin bound) through
  `RelayHttpApiClient`. `SideChatRepository` sits over it and uses the shared
  models directly; there is nothing to transform.
- `SessionDetailLoadService._loadPluginCapabilities` adds `sideQuestions:
  SideQuestionAvailability`. The enum is defined in
  `client/module_core/lib/src/foundation/models/` and exported, because
  `module_app_ui` reads it too. Its values are:
  - `available`.
  - `bridgeUpdateRequired`, when `PluginListResponse.supportsSideQuestions` is
    false.
  - `harnessUnsupported`, when the plugin flag is false.
  - `unresolved`, when the plugin listing failed or the plugin is unknown.

  The value is carried on `SessionDetailSnapshot` and `SessionDetailLoaded`.
  In this step `SessionDetailCubit` gains nothing else; step 10 adds the
  composer mode.
- `SideChatCubit` lives in `cubits/side_chat/` and is created when the sheet or
  panel opens. It gets the session id, plugin id, availability, archived flag
  and a nullable `initialQuestion`. It loads the chats on open, and never
  polls. With an `initialQuestion` it starts on a new chat and asks it once
  the load finishes; this is how `/btw` mode hands over its text, so no cubit
  depends on another.
  - Its state is sealed:
    - `SideChatLoading`.
    - `SideChatLoadFailed`, with Retry.
    - `SideChatReady({earlierChats, thread, ask})`.
  - `thread` is `SideChatThread`: `newChat`, or `existing(chat)`.
  - `ask` is sealed: `idle`, `waiting(question)`, `refused(question, reason)`,
    or `failed(question)`.
  - Its intents are `ask(text)`, `retry()`, `openChat(id)`, `startNewChat()`
    and `reload()`.
  - Only one ask runs at a time; the send button is disabled while waiting.
- Analytics: add `ProductAnalyticsEvent` `side_question_asked` with
  `harness: AnalyticsHarness` and `outcome: answered | no_answer | unavailable | failed`.
  - The cubit reports it on the authoritative result of each ask, through
    `ProductAnalyticsService`.
  - It sends no text, no ids and no counts.
  - The `add-analytics` skill checklist applies, including the BigQuery and
    reporting notes it asks for.

### Client UX

**Entry points (B1 = D).** There are two, and both open the same side chat.

*The button.* A side-question button, icon `TablerRegular.message_question`,
sits in the composer's options pill next to `+` and `/`.

- It is the same on phone and desktop, and keeps the full top bar untouched.
- On a phone it folds behind the chevron while typing, like its neighbours.
- On sub-agent sessions it is hidden.
- When the session isn't `available`, the button still shows and a tap answers
  with the reason (never-ignore-taps rule). For `bridgeUpdateRequired`: "Update
  Sesori on this computer to ask side questions." For `harnessUnsupported`:
  "<Harness> can't answer side questions in Sesori yet."
- While `unresolved`, the button holds its place, disabled, like attach does.

*The `/btw` command (Q1 = B).* Typing "/btw " at the start of the composer
switches it into side-question mode.

- **Where it lives.** The mode is the `sideQuestion` variant of the sealed
  composer mode in `SessionDetailCubit` (see the composer-mode seam). The cubit
  holds one private sealed override (an edit or a side question), so the two
  modes never overlap, and one entry check guards both ways in. The
  cubit enters it when the composer text starts with "/btw " and the session is
  `available`. Matching is on the exact prefix "/btw " (any letter case), at
  the start of the text only.
- **How the text flows.** The text field's controller stays in the widget. The
  cubit already receives every edit through `onDraftChanged` →
  `saveComposerDraft`; the prefix check runs there, as a private cubit method,
  not in the widget. On a match the cubit enters the mode, saves the draft
  without the prefix, and bumps the existing `composerRestorations` counter,
  so the field takes the stripped text through the seam it already uses for
  restored drafts. On Send in this mode the widget calls
  `SessionDetailCubit.submitSideQuestion()`. It leaves the mode, clears the
  draft, and returns the trimmed text, or null when it is empty. The widget
  then opens the sheet or panel with that text as the `SideChatCubit`'s
  `initialQuestion`.
- **What changes on screen.** The "/btw " prefix is removed from the field and
  the caret stays after the text that remains. The strip above the input,
  which today shows a staged command's chip (`prompt_input.dart`, the
  `stagedCommand` header), shows a "Side question" label with the speech-bubble
  icon and ✕ instead. The field's border darkens. The label grows in and the
  border colour eases, with the motion the staged-command chip already uses;
  with reduced motion they appear without animation. The transcript above does
  not move, because the strip's footprint is already reserved.
- **Leaving it.** ✕, or Backspace in an empty field, returns to the normal
  composer with the text kept. Picking a slash command or an attachment also
  leaves it, since a side question takes neither.
- **Sending.** Send in this mode does not send a prompt. It opens the side sheet
  on a phone, or the panel on desktop, on a new side chat, asks the typed text
  there, and clears the main composer. The sheet then shows the question and
  "Thinking…" until the whole answer arrives at once (no harness streams side
  answers; see Behaviour).
- **The `/` picker.** On `available` sessions, the command picker also lists a
  Sesori row, "btw: ask a side question", above the harness's commands; once
  a search is typed it follows the matching commands, so Enter keeps picking
  the best command match.
  Picking it enters the same mode and keeps whatever the field already holds,
  so no typed words are lost. While a command or images are staged, neither
  way enters the mode and the row is hidden, because a side question takes
  neither.
- **Unavailable sessions.** On a session that isn't `available`, "/btw " stays
  plain text and goes to the harness like anything else typed, and the picker
  has no btw row. The button still answers a tap with the reason, so the
  limitation is never silent.
- **Drafts.** The mode is not saved with the composer draft: a restored draft
  comes back as plain text.

**Phone sheet.** This is a new reusable Prego component, `showPregoDetentSheet`
in `module_prego/lib/components/surfaces/`.

- It is a modal route with two resting heights: half the screen, and full
  (capped below the status bar).
- The drag follows the finger continuously. On release it snaps by position and
  velocity: up to full, down to half, and down from half closes it.
- The scrim is light at half height, so the streaming chat behind stays
  readable. It deepens toward full height, and a tap on it closes the sheet.
- When the keyboard opens, it lifts the sheet's input. The sheet never covers
  the status bar.
- With reduced motion, it changes height without the spring.
- The session page under it stays mounted, so the main transcript keeps
  streaming and keeps its scroll position.

**Shared content.** `SideChatView` in `module_app_ui/lib/src/features/side_chat/`
is used by both shells.

- **Header.** The title is "Side question", or the first question of a reopened
  chat. "Earlier (n)" opens the list of earlier side chats in place, with a
  cross-fade. "New" starts a new chat.
- **Body.** Each question is a compact bubble, and each answer renders with the
  transcript's Markdown renderer. A notice shows as a small caption.
- **Answer actions.** Each answer has a Copy action and an actions slot. The
  merge plan's "Send to main session" goes in that slot.
- **New exchanges and scrolling.** A new exchange slides in at the bottom. The
  list follows the bottom only while the user is already there, so nothing
  under their eyes jumps.
- **Waiting.** It shows a quiet "Thinking…" row with the activity glyph the
  transcript uses. A refusal or failure replaces that row, in place, with its
  reason and Retry.
- **Input.** A single-line field that grows to a few lines, and Send. No voice,
  attachments or commands in phase 1.
- **Footnote.** "Answers from what this session already knows. No tools, and
  nothing is added to the chat."
- **Archived sessions.** Instead of the input it says: "This session is
  archived. Its side chats are read-only."

**Archived entry (round 4, q2 = A).** An archived session has no composer, so
the options-pill button isn't there.

- `SessionDetailArchivedNotice` shows a "Side chats (N)" link where the
  composer's button used to be, only when the session has at least one side
  chat. Tapping it opens the same sheet (the panel on desktop) on the newest
  chat, read-only, with the earlier list available.
- The count comes from one `listSideChats` call when an archived session's
  detail loads, made only when the bridge supports side questions
  (`PluginListResponse.supportsSideQuestions`), whatever the harness flag says,
  since stored chats stay readable. It is carried only for archived sessions.
  With no chats, a failed call or an older bridge, there is no link, and the
  notice looks as it does today. No reason is needed, because nothing tappable
  is shown.
- The link fades in when the count arrives, without moving the notice's text.

**Desktop panel.**

- It is a trailing floating panel over the session page, about 380 pt wide and
  full height under the toolbar.
- It slides in from the window's right edge by transform, like the sidebar's
  motion. The transcript column doesn't move or reflow.
- Escape or its close button closes it. Switching sessions closes it.
- It is opened by the same composer button, and by sending in side-question
  mode.
- It holds the same `SideChatView`. The page behind stays interactive, so the
  user can keep reading and scrolling the main chat.

## Complexity budget

New persistent state:

- **One table, `side_chat_exchanges`.** It is the only place a side chat
  exists. It is written once per successful answer.

New in-memory state:

- **Claude: none.** Each ask is one entry in the existing `_pending` completer
  map.
- **Codex: none.** It uses the existing JSON-RPC pending map.
- **Client: one `SideChatCubit` while the sheet or panel is open.** Its `ask`
  state has four variants.

Deliberately not added:

- **No pending or in-flight rows, and no startup repair.** An abandoned answer
  still lands as one row.
- **No SSE event or live sync of side chats across surfaces.** Another device
  sees new exchanges the next time it opens the sheet. The damage is a stale
  list until reopen, which is low.
- **No cancel route or cancel button.** The plugins bound every ask: 3 minutes
  for Claude with a CLI cancel, and the 30 s server deadline for Codex.
- **No streaming, on any harness.** Claude Code's `side_question` returns the
  whole answer at once, so every harness, including the phase-2 fallback,
  shows "Thinking…" and then the whole answer.
- **No client-sent history.** The bridge reads it from its database.
- **No per-harness busy tracking or concurrency limit.** Claude has none
  locally, and with `allowInProgressTurn` Codex samples mid-turn.
- **No guard for two clients asking in the same chat at once.** Both rows are
  stored, in time order.
- **No first-version probing for old Claude CLIs.** The CLI's own
  unsupported-subtype error maps to an honest reason.

## Steps

PR titles follow `<emoji> [side-questions] <description> [step x/12]`. The
sizes are estimates of added plus deleted lines, with generated code counted
separately.

### Step 1: raise the plan, `🌱 [side-questions] Plan side questions [step 1/12]`

This branch. Plan files only.

### Step 2: bridge contract, storage and routes, `🚧 … Store side chats and add the side-question routes on the bridge [step 2/12]`

**Includes:**

- The plugin interface types, and the descriptor flag defaulting to false.
- The `sesori_shared` wire models and the capability fields.
- Schema v25, the DAO, `SideChatRepository`, `SessionRepository.askSideQuestion`,
  `SideQuestionService`, the two handlers and the metadata plumbing.
- `PluginListResponse.supportsSideQuestions = true` is sent from this step,
  while no plugin flag is set yet. Clients then show `harnessUnsupported`,
  which is true.

**Tests:**

- The DAO and repository grouping.
- Cascade on session delete.
- The archived rejection, through `ArchivedSessionValidator`.
- The child-session 400.
- `harnessUnsupported`, without starting the plugin.
- Handler parse failures.
- The wire round-trip with omitted fields.

**Size:** about 900 authored lines, plus about 1,200 generated (Drift schema
snapshot and steps, freezed). It goes over the soft cap through generated churn
only. Report the split in the PR.

**Complexity:** 🚧, because of persistence, a migration and a new wire contract.

**Expected result:** no user-visible change, and one new table.

### Step 3: Claude native side questions, `⚙️ … Answer side questions on Claude Code [step 3/12]`

**Includes:**

- The stream client method, with cancel on timeout.
- The process repository method.
- The plugin implementation, the mapping and the descriptor flag.
- A `docs/HARNESS_CAPABILITIES.md` "Side questions" section, with every row.

**Tests:**

- Fake-process tests covering:
  - The frame shape, including `history`.
  - Success, synthetic, null and fallback-notice mapping.
  - The unsupported-subtype mapping.
  - Timeout writing `control_cancel_request`.
  - A resident process is used as is, with no selection change or teardown,
    while a turn runs.
  - A non-resident session is resumed before the send.
  - An unstarted session returns `noTurnYet` without a process.
- A live probe against the pinned CLI, recorded in the PR:
  - Ask mid-turn.
  - Ask after a cold resume.
  - Check that the transcript is untouched.

**Size:** about 500 lines.

### Step 4: Codex runtime target to at least 0.169, `⚙️ … Raise the Codex runtime target to <version> [step 4/12]`

**How:**

- Follow the Codex section of the `update-backend-runtimes` skill for this one
  harness: manifest version, asset digests, the release audit, and the focused
  plugin tests.
- Record any behaviour change the audit finds.
- Ask before adopting any other new Codex feature.

**Size:** about 150 lines. It can run in parallel with steps 2 and 3.

**Risk:** a runtime bump touches every Codex session. The release audit and the
existing Codex regression entries are the check.

### Step 5: Codex native side questions, `⚙️ … Answer side questions on Codex [step 5/12]`

**Depends on:** steps 2 and 4.

**Includes:**

- `sampleThread`, plus resolving the thread and turn (`listLatestTurn`,
  `latestTurnId`).
- The history-in-prompt template with its byte budget.
- The mapping and the descriptor flag.
- Updated Codex rows in `HARNESS_CAPABILITIES.md`.

**Tests:**

- The budget and trimming.
- The `noTurnYet` path.
- Error mapping for an old PATH Codex.
- `text: null`.
- A live probe on the new pin, recorded in the PR: ask mid-turn and idle,
  ask a follow-up, and check the rollout is unchanged.

**Size:** about 500 lines.

### Step 6: client core, `⚙️ … Load and ask side questions in the app core [step 6/12]`

**Depends on:** step 2.

**Includes:**

- `SideChatApi` and `SideChatRepository`.
- Availability in the session-detail snapshot and state.
- `SideChatCubit`.
- The analytics event, with its reporting notes, per the `add-analytics` skill.
- DI registration in `configureCoreDependencies`.

**Tests:** pure Dart cubit tests for each `ask` variant, chat switching, the
archived read-only state, availability mapping including older bridges, and the
analytics outcome.

**Size:** about 900 lines.

### Step 7: Prego detent sheet, `⚙️ … Add a two-height drag sheet to Prego [step 7/12]`

**Includes:**

- `showPregoDetentSheet`.
- The design-catalog entry.
- Widget tests for snapping, closing, the keyboard and reduced motion.

**Checks:** feel, using a headless iOS simulator recording (see Verification).

**Size:** about 600 lines. It can run in parallel with steps 2 to 6.

### Step 8: phone side chat, `🚧 … Ask side questions from the session on the phone [step 8/12]`

**Depends on:** steps 6 and 7.

**Includes:**

- `SideChatView`.
- The composer entry, with its reasons.
- The sheet wiring in the mobile session screen.
- The archived entry: the "Side chats (N)" link on the archived notice, opening
  the sheet read-only (see Client UX, Archived entry). If the step runs over
  the soft cap, split this into its own PR after the rest of step 8.
- Localised strings.

**Checks:**

- Widget tests, including the archived link's presence rules.
- A headless iOS simulator recording against a fixture or dev account. It
  shows:
  - asking while the main turn streams,
  - a follow-up,
  - reopening an earlier chat,
  - the main transcript not jumping.
- The recording goes in the PR, on the `pr-media` branch.

**Size:** about 1,200 lines.

### Step 9: desktop side panel, `⚙️ … Show side chats in a panel on desktop [step 9/12]`

**Depends on:** step 8.

**Includes:**

- The trailing floating panel in `DesktopSessionDetailScreen`.
- The composer entry on desktop.
- Escape to close.

**Checks:** widget tests, and a short macOS desktop recording, since this is
desktop-specific UI.

**Size:** about 500 lines.

### Step 10: `/btw` side-question mode, `⚙️ … Ask side questions by typing /btw in the composer [step 10/12]`

**Depends on:** steps 8 and 9.

**Includes:**

- The sealed composer mode in `SessionDetailCubit`, unless the edit-and-fork
  plan has already added it; then only its `sideQuestion` variant.
- Prefix detection in `saveComposerDraft`, leaving the mode, and
  `submitSideQuestion()` handing the text to the sheet's `SideChatCubit` as
  `initialQuestion`, as described in Client UX.
- The "Side question" strip and the darker border in `PromptInput`, through
  the staged-command header slot.
- The Sesori "btw" row in the command picker.
- Strings.

**Checks:**

- Cubit tests for entering, leaving, keeping the text, unavailable sessions and
  the draft rule.
- Widget tests for the strip, the border and the picker row.
- A headless iOS simulator recording against a fixture or dev account: type
  "/btw ", see the mode, ✕ back, type again and send, and the sheet opening
  with the question while the main transcript doesn't move. It goes in the PR,
  on the `pr-media` branch, with before and after screenshots of the composer.

**Size:** about 600 lines.

**Complexity:** ⚙️, because composer state, gesture and motion meet here.

**Expected result:** typing "/btw " on a Claude Code or Codex session switches
the composer into side-question mode, and sending asks a side question. No
database or wire change.

### Step 11: reconcile regression docs, `🌱 … Document side questions for regression runs [step 11/12]`

Covers the documents listed below, plus the final `HARNESS_CAPABILITIES.md`
wording.

### Step 12: verify and retire, `🌱 … Verify side questions and retire the plan [step 12/12]`

1. Run the matrix below.
2. Record the results in `TRACKER.md`.
3. Move the plan to `.plan/completed/side-questions/`.

## Later phases (rough)

- **Phase 2: fallback for every other harness.**
  - It uses a short-lived fork that is never listed, taken with the fork plan's
    plugin fork operation.
  - The prompt carries the earlier side Q&A and asks for an answer without
    tools. Any permission request is denied.
  - The fork is deleted after the answer, and is never imported into the
    catalog.
  - It returns the whole answer at once, like the native seams, even where the
    fork could stream.
  - The plugin declares `supportsSideQuestions`, so the client needs no change.
- **Phase 3: "Send to main session".** This is owned by the merge plan, and
  fills the answer-actions slot.
- **Possible follow-ups.** Each needs its own case:
  - Live sync of side chats across surfaces.
  - Cancel from the UI.
  - Voice dictation in the side composer.

## Regression documents

- **New: `docs/regression/side-questions.md`.** Add it to the README index. It
  covers the capability; the behaviour list above; levels L1 to L5; and failure
  signals:
  - main turn interrupted or delayed,
  - side text in the main transcript,
  - a tool run,
  - a lost answer after closing the sheet,
  - transcript scroll jumps,
  - a tap that does nothing,
  - "/btw " sent to the harness as a prompt on a session that supports side
    questions, or the composer text lost when leaving the mode.
- **`session-archiving-and-deletion.md`.** Side chats are deleted with their
  session, and are read-only when the session is archived.
- **`desktop-cockpit-shell.md`.** The side panel's motion, and that it closes
  on Escape and on session switch.
- **`analytics.md`.** The `side_question_asked` event and its bounded
  parameters.
- **`plugin-runtime-installation.md`.** The new Codex target, if the doc names
  versions.
- **`design-catalog.md`.** The detent sheet entry, if the catalog doc lists
  components.

## `docs/HARNESS_CAPABILITIES.md` rows (new "Side questions" section)

| Harness | Native seam | Sesori availability |
|---|---|---|
| Claude Code | `side_question` control request in `-p` stream-json, with `history` (verified 2.1.322) | ✅ Native, mid-turn, no tools, no transcript write. CLIs without the handler get "update Claude Code" |
| Codex | Experimental `thread/sample` (mid-turn from 0.169.0) | ✅ Native from step 5. History goes in the 4,000-byte prompt. PATH Codex 0.139–0.168 gets "update Codex" |
| OpenCode | `/btw` only on its dev branch; session fork exists | ⬜ Phase-2 fork fallback |
| Pi | No side question; RPC `fork`/`clone` | ⬜ Phase-2 fork fallback |
| Oh My Pi | RPC-only `btw`, not over ACP; ACP `session/fork` | ⬜ Phase-2 fork fallback |
| Hermes, Grok Build, Cursor, GitHub Copilot, Antigravity, DeepSeek | TUI-only; whole-session fork via the vendor or the ACP draft | ⬜ Phase-2 fork fallback where the fork plan provides a fork. Otherwise 🚫, with the verified version |

## Verification

The retirement level is L3 for `side-questions.md`, with the lower levels
included.

| Cell | Boundary | What passes |
|---|---|---|
| Bridge contract | Automated + headless bridge (debug server) | Routes, refusals, storage, cascade on delete, archived read-only, history order |
| Claude Code | Live plugin | Mid-turn answer while the main turn keeps streaming. Follow-up uses history. Cold-resume answer. Session `.jsonl` unchanged |
| Codex (new pin) | Live plugin | Same as Claude Code. Rollout unchanged. Over-budget history is trimmed |
| iOS simulator, headless, Claude and Codex | Client end to end | Both entries (button and "/btw " mode, including ✕ back with the text kept, and the picker's btw row), sheet heights and drag, ask during streaming, follow-up, reopen earlier, close while waiting then reopen to see the answer, no main-transcript jump. Reason on tap for an unsupported harness and for an older bridge |
| macOS desktop (platform-specific panel) | Client end to end | Panel slides in without the transcript moving, ask and follow-up, Escape closes, session switch closes |
| Analytics | Automated | One `side_question_asked` per ask, with bounded parameters |

- Device checks use a headless iOS simulator only (`xcrun simctl boot`,
  Simulator.app never opened), on the device the `sesori-local-testing` skill
  assigns.
- Recordings and screenshots use fixture or dev-account data only.

## Cleanup assessment

No existing code becomes obsolete. The feature is additive. The one adjacent
fix is the stale comment beside `experimentalApi` in the Codex client, which
names only collaboration mode. Step 5 updates it to mention `thread/sample`.

## Risks and accepted limitations

- **Both native seams are unofficial.** Claude's control request is
  undocumented, and Codex's method is experimental. Either can change with a
  runtime refresh. Mitigation: steps 3 and 5 add a live side-question probe to
  the Claude and Codex checks in the `update-backend-runtimes` skill's audit
  list. That one-line skill edit goes in the same PRs.
- **Claude's first supporting version is unknown.** Older CLIs get a correct
  "update Claude Code" reason, based on the CLI's own generic error, which was
  verified on 2.1.322.
- **Codex follow-ups lose the oldest context.** The 4,000-byte cap means long
  side chats keep only their newest exchanges. This is accepted, and the plugin
  trims honestly.
- **Cost.** Each ask is a model call that reads the session's prompt cache.
  Claude never writes to the cache, and Codex shares its prefix. This is
  accepted, and analytics shows usage.
- **Other surfaces show a stale list.** It stays stale until reopened. This is
  accepted, as described in the complexity budget.
- **Evidence level.** Every safeguard here addresses a verified behaviour or an
  ordinary flow. None defends a theoretical interleaving.

## Product questions

None open. Round 2 B1 = D, round 3 Q1 = B, and round 4 q2 = A (archived
entry) and q3 = A (hide Codex attached threads) are answered (see Decisions).

## Review record

`architecture-plan-review`, first pass (2026-11-14): rejected with ten concrete
findings, all fixes to the plan text rather than a redesign. All ten are now
applied. They are:

1. Answer mapping moves into the repository, with mappers.
2. The archived check reuses `ArchivedSessionValidator`, so the wire enum drops
   its archived value.
3. A child session is a 400.
4. The support check has one owner, `SessionRepository` through
   `PluginRuntime.supportsSideQuestions`, and there is a
   `SessionOperation.askSideQuestion`.
5. Codex follows its API → repository → service chain, and has a prompt
   builder.
6. The idle Codex turn id comes from `thread/read`.
7. Claude gets a typed DTO, a typed exception and a mapper.
8. The response union has a `fallbackUnion`.
9. The routes are kebab-case.
10. `SideQuestionAvailability` lives in `module_core` foundation models.

Per the skill, the fixes were not reviewed again.

2026-11-15: updated for round 2 (B1 = D) and round 3 (Q1 = B). The change is
client-only (the `/btw` mode step) and adds no layer or contract, so it was not
sent for another review.

`architecture-plan-review`, second pass (2026-11-15): rejected with six
findings, all applied:

1. Claude residency moves into `ClaudeSessionService.askSideQuestion`. The
   repository's `sendSideQuestion` had none of the inputs `ensureResident`
   needs, and `ensureResident` on a resident process reapplies the selection
   and can tear the process down, killing the main turn. A resident process is
   now used as is, and an unstarted session returns `noTurnYet`.
2. The idle Codex turn comes from a new `readThreadTurns` and `latestTurnId`.
   The existing `readThread` sends `includeTurns: false` and models no turns.
3. Codex answer mapping sits in `CodexSideAnswerMapper`, under the
   repository. The service owns `noTurnYet` and `tooLong`, and the prompt
   builder has a location and an owner.
4. The bridge repository result is the named `SideQuestionAskResult`, and
   `SideChatRepository.recordExchange` mints the ids.
5. `SideQuestionService` explicitly stays off `SessionOperationDispatcher`
   lanes, with the archive and delete races accepted.
6. `/btw` mode hands its text to `SideChatCubit` through `initialQuestion`
   and `submitSideQuestion()`, with no cubit-to-cubit dependency. Prefix
   detection stays in the cubit, through the existing `composerRestorations`
   seam.

Also recorded: answers never stream on any harness (see Decisions). Per the
skill, the fixes were not reviewed again.
