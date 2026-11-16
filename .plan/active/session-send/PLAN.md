# Send One Session Into Another

## Goal

From any session's menu, the user picks another session on the same computer. Sesori then sends the target a summary
written by the source session's agent, plus the absolute path of a Markdown file with the source's full transcript.
The target receives this at once as a normal prompt, with no preview. Both chats show the handoff as its own compact
item, and the source can be archived once the summary has landed.

Product decisions are final (user answers, 2026-11-14, `/tmp/rp/branching-brief.md`, Q10, Q11 and "Decided without
asking"; round 2 and round 3, 2026-11-15, listed below). Edit and fork, and side questions, have their own plans. This
plan only names their seams (see "Seams with the sibling plans").

Round 2 and 3 answers (final):

- **S1 = A.** You stay in the source: "Sending…", then "Sent to X · Open".
- **S2 = A.** Running ACP targets are allowed; the picker labels them "Running: sending stops its current turn".
- **S3 / Q2.** The summary request and reply get their own UI, different on each side:
  - source chat: a one-line centred marker, "Summary sent to <target> · Open". Tapping it shows the summary in a
    sheet. Sesori's request and the agent's reply are hidden behind it;
  - target chat: a card with the first few lines of the summary and "Show all". Its header reads "From <source>" and
    links to the source; the transcript file path sits below the summary. It never says "Archived after sending".
    Expanding grows the card in place, and nothing above it moves.
  - The bridge marks which messages are the handoff exchange, on every harness, so the client can render them.
- **S4 = B.** Claude Code's read-only rule covers Sesori's transcripts folder and the attachment uploads folder. This
  reverses the file-transfer plan's D1 ("Claude may ask once per read location … revisit only if annoying").
- **Q3 = A.** The send sheet has a switch, "Archive this session after sending", on by default, which remembers the
  last choice. The archive happens only after the summary has landed in the target, and a pinned source asks first as
  usual. Sending from a side chat back to its session has no switch and never archives.

## Scope

Phase 1, this plan's steps:

- A bridge route that runs the whole send: it asks the source for a summary, writes the transcript file and prompts the
  target.
- A transcript-to-Markdown builder and the file store, with deletion tied to the session.
- A Claude Code read rule for the transcripts and uploads folders, so the agent reads either without an approval
  prompt.
- A bridge-side handoff marker on the exchange's user messages, and its two chat renderings.
- A per-harness declaration of what a prompt to a busy session does, for the picker's Running label.
- The client side: the "Send to another session…" menu entry, the send sheet with its target picker and archive
  switch, feedback after sending, and archiving the source after a successful send.
- One analytics event.
- Regression docs and `docs/HARNESS_CAPABILITIES.md` rows.

Out of scope for phase 1: see "Later phases".

## Current behaviour (facts this plan relies on)

- **Prompt send.** `POST /session/prompt_async` → `SessionPromptService.sendPrompt`
  (`bridge/app/lib/src/services/session_prompt_service.dart:43`). This runs on the session's lane in
  `SessionOperationDispatcher` → `SessionRepository.sendPrompt` → `BridgePlugin.sendPrompt`. The call completes once
  the prompt is accepted, not when the turn ends. There is no hidden-prompt mechanism: everything in `parts` becomes
  the visible user message.
- **The only prompt the bridge sends on its own** is quota auto-continuation's "Continue."
  (`services/session_continuation_service.dart:105-207`). It checks readiness with
  `SessionRepository.getQuotaContinuationReadiness`, reads history, then sends with the session's `promptDefaults`.
  That is the template for this feature.
- **Prompts to a busy session are never rejected.**
  - Claude, Codex, Pi, OpenCode and OMP steer them into the running turn. Claude writes them with its `next`
    priority, so the running turn takes them at its next tool boundary.
  - The ACP family (Antigravity, Copilot, Cursor, DeepSeek, Grok, Hermes) stops the running turn and then sends
    (`docs/HARNESS_CAPABILITIES.md` "Transcript turn boundaries").
- **Turn tracking.** `SessionEventDispatcher.events` (`services/session_event_dispatcher.dart:31`) carries
  `NormalizedStatusEvent` (idle/busy), `NormalizedMessageEvent` and `NormalizedOtherEvent`, which includes session
  errors.
  - A live user echo carries the `promptId` it fulfilled (`Message.user.promptId`). Every harness publishes a
    correlated user message ("Accepted prompts without transcript output").
  - History reads carry no `promptId`.
- **Whole-transcript read.**
  - The call is `ChatHistoryService.getSessionMessages` (`services/chat_history_service.dart:125`), with
    `HistoryWindowAll()`, `ToolOutputDelivery.inline`, `MessageAttachmentDelivery.storedReference`,
    `storedOnly: false` and `backgroundRefresh: false`.
  - It reads the history store, backfills from the harness when the store is behind, and serves archived sessions from
    the audit file.
  - It returns normalised `MessageWithParts`: text, reasoning, tool, subtask, file, patch, compaction, and so on.
- **Archive's transcript audit record**
  - It is produced by `ChatHistoryRepository.exportSession` (`repositories/chat_history_repository.dart:1136`).
  - It is lossless versioned JSON under `<dataDirectory>/archive/`, and the archived read path pages through it again.
  - It has no rendering logic. A Markdown builder is new code, and it reuses only the idea of an atomic owner-only
    write.
- **Data folders** (`bridge/sesori_bridge_foundation/lib/src/sesori_data_directory.dart`)
  - `sesoriDataDirectory()` is `~/.local/share/sesori`, and `--data-dir` can override it. It holds `sesori.db`,
    `chat_history.db`, `archive/` and the auth tokens.
  - `~/.sesori/` holds `worktrees`, `scratch` and `uploads`. Its doc comment says its files sit "outside every project,
    so agents read them by absolute path".
- **Prompt uploads**
  - `PromptUploadRepository` (`repositories/prompt_upload_repository.dart`) writes owner-only files under
    `~/.sesori/uploads/<sessionId>/<date>-<random>/<name>` and returns the absolute path.
  - It is constructed with its root, and `deleteSessions({sessionIds})` removes the folders.
  - `SessionDeletionService` calls that for the whole deleted family. Archive leaves uploads alone.
  - A separate 30-day sweep lives in `PromptPartDeliveryService`, not in the repository.
- **Reading a file outside the working directory** ("Saved prompt files", checked live 2026-11-08)
  - Claude Code asks once per read, because Sesori passes no `--add-dir` or read rule.
  - Codex, Pi, OMP, DeepSeek and Grok read without asking.
  - OpenCode read without asking on a config that allows reads. Its default agent has `external_directory: * → ask`,
    which is unverified on a stock config.
  - Hermes, Cursor, Copilot and Antigravity are unverified.
  - Claude already launches with `--allowedTools` (`sesori_plugin_claude/lib/src/api/claude_launch_spec.dart:144`).
- **Client**
  - Session actions come from `SessionListActionDispatcher.sessionMenuEntries`
    (`client/module_app_ui/lib/src/features/session_list/session_list_action_dispatcher.dart:70`). It feeds four
    surfaces: the list-row long-press or right-click, the mobile session "More" menu, the desktop session "…" menu,
    and the desktop sidebar.
  - It already receives `isRunning`.
  - The mobile page shows these entries only for root sessions.
- **Cross-project session search**
  - `SessionSearchCubit` (`client/module_core/lib/src/cubits/session_search/session_search_cubit.dart:24`) searches
    over `POST /sessions/page`. A blank query lists the newest sessions first.
  - The desktop command palette uses it. Phones have no session picker.
  - `ProjectPicker` (`module_app_ui/lib/src/features/project_picker/project_picker.dart:33`) is the pattern for a
    picker on both form factors. It opens a bottom sheet under touch and a popover under a pointer, with
    `PregoPickerSearchList` in both.
- **Same computer.** The client talks to one bridge at a time. Every session list comes from that bridge, so any
  session the picker shows is on the same computer. `Session` has no bridge id.
- **Detecting what an older bridge supports.** There is no version handshake. Features are gated on `@Default(false)`
  flags on `PluginListResponse` (`shared/sesori_shared/lib/src/models/sesori/plugin_list_response.dart:80-102`), for
  example `supportsFileUploads`. Older clients ignore unknown SSE types
  (`client/module_core/lib/src/capabilities/server_connection/connection_service.dart:667`).

## Design decisions

### D1. The summary comes from a normal, visible prompt on every harness

The bridge sends the source session a summarise prompt through the existing prompt path and captures the agent's reply.

- **It is a real turn in the source, which Sesori renders as a handoff marker (S3).** No harness can run a hidden turn
  through the normal prompt path, and filtering transcripts the harness owns (Claude's JSONL keeps it) would differ per
  harness. So the turn stays in the harness's history, the bridge marks it (D11), and the client folds it into the
  one-line marker (D12). The same rule holds on every harness.
- **It uses the source's prompt defaults** (agent, model, variant, fast mode), like continuation does.
- **Draft wording**, kept short. Sesori hides it behind the marker, but the harness's own transcript and terminal UI
  still show it:

  > Sesori is sending this conversation to another session, "<target title>". Write a handoff summary for the agent
  > there: the goal, what was done and decided, the current state, open questions and next steps, and the files that
  > matter. Reply with the summary only, and don't use tools.

- **No harness gets a summary-free path in phase 1.**
  - Every harness can run a normal prompt, and the decision asks for the agent's summary.
  - A transcript-only send helps only when the source can't take a turn: an archived or unrestorable source, a plugin
    that is down, or a retry after a failed summary. That is a later phase.
  - Claude's `side_question` and Codex's `thread/sample` could write the summary with no transcript entry, even while
    the source is busy. That would make Claude and Codex behave differently from the rest, so it stays a later option,
    used only if the visible turn turns out to annoy users.

### D2. A busy source is refused, with a reason and a Stop action

- The bridge sends the summarise prompt only when the source is idle.
- A busy source would mix the request into the running turn, and on ACP harnesses it would stop that turn.
- The bridge checks readiness right before sending and refuses with a typed code:
  - `sourceBusy` covers busy and retrying. Step 3 reads no queue: a prompt queues only behind a running turn, so a
    queue implies busy;
  - `sourceAwaitingInput` covers a pending question or permission.
  - A plugin listed in `unavailablePluginIds` whose backend is not running has no turn, so it counts as idle. A
    running backend listed there failed its status read, so readiness is unknown and the send is refused as
    `sourceUnavailable`. Any other failure of the summarise send itself, including a refusal, is also
    `sourceUnavailable`.
- A stale-options rejection of a bridge send is its own code: `sourceOptionsUnavailable` for the summarise send (step 3)
  and `targetOptionsUnavailable` for the handoff to the target (step 3). It means the harness no longer offers that
  session's saved model, agent or variant. The session keeps its own model and the bridge never swaps it silently,
  because a typed prompt fails the same way and lets the user pick a replacement. The user sends that session a
  message, which the app corrects for a stale agent or variant and which needs another model for a stale one, then
  sends again.
- Readiness comes from sources that every plugin supplies:
  - `SessionRepository.getSessionStatuses()` decides idle, busy or retrying;
  - `PermissionRepository.getPendingPermissions` and `QuestionRepository.getPendingQuestions` decide awaiting input.
- `getQuotaContinuationReadiness` is not used. Only Claude and Pi implement it, and every other harness answers
  `unavailable`.
- The client checks `isRunning` first and answers the tap with an alert: "<Source> is still working. Send it when it
  finishes." The alert has a **Stop** action that calls the existing stop. This matches the agreed Edit rule ("Edit
  waits or offers Stop first"). After stopping, the user sends again. Nothing is queued.

### D3. A busy target behaves exactly like a typed prompt

- The decision says the target receives the send "as a normal prompt", so it follows each harness's normal rule.
  Claude, Codex, Pi, OpenCode and OMP steer it in, and ACP harnesses stop the running turn first.
- Running targets are allowed on every harness (S2). The picker labels them before the user chooses:
  - "Running: sending stops its current turn" where a prompt to a busy session stops its turn (the ACP family);
  - "Running" where it steers (Claude, Codex, OpenCode, Pi, OMP).
- The client can't tell those apart today: no `PluginMetadata` field says it, and naming harnesses in the client would
  leak backend behaviour out of the plugins. So each plugin declares it. There are two enums, because
  `sesori_plugin_interface` doesn't depend on `sesori_shared`:
  - `PluginBusyPromptHandling {steer, stopTurn}` in `sesori_plugin_interface`, read through the abstract
    `BridgePluginDescriptor.busyPromptHandling` getter with no default (every plugin states it);
  - `BusyPromptHandling {steer, stopTurn, unknown}` in `sesori_shared`, on `PluginMetadata.busyPromptHandling`
    with `@JsonKey(unknownEnumValue: BusyPromptHandling.unknown)` and an honest `@Default(BusyPromptHandling.unknown)`:
    `// COMPATIBILITY 2026-11-15 (v1.14.0): Bridges before session sending omit busyPromptHandling; the picker shows
    a plain "Running" for them. Remove @Default once the minimum supported bridge sends it.`
  - The bridge maps one to the other with a `toShared()` extension in
    `bridge/app/lib/src/repositories/mappers/plugin_to_shared_mapping.dart`. `PluginLifecycleService._rebuildMetadata`
    sets the field next to `namesCommandInvocations`.
  - The values follow `docs/HARNESS_CAPABILITIES.md` "Transcript turn boundaries".
  - Step 6 dropped the planned `queue` value: Claude steers (#977), so no harness would declare it. A harness that
    really queues can add it later; older clients read the new value as `unknown` and show plain "Running".

### D4. One bridge-owned operation: a long request, no new event

- `POST /session/send-to-session` runs the whole flow and answers when the target has accepted the prompt, or with a
  typed failure. The bridge owns it so that a phone that backgrounds partway through doesn't break the send. It also
  means automation can use the same API.
- The request stays open for the length of the summary turn.
  - Client timeout: 16 minutes. Bridge wait: 15 minutes. The MCP routes already hold relay requests for 3.5 minutes.
  - If the client times out or loses the connection, it shows "Couldn't confirm the send. Check <target>." The bridge
    finishes regardless.
- There is no SSE outcome event, no in-flight registry, and nothing persisted. Step 3 checks that the relay keeps a
  request open that long. If it can't, step 3 switches to "accept, then report through an SSE event" and records that
  change here. That fallback adds an orchestrator-emitted event and a new wire model. It is a
  considerable change, so it gets another architecture plan review before it is built.
- Step 3 result: no fallback is needed. The relay server (`sesori_relay_server`) forwards opaque E2E frames between
  the phone and bridge sockets and has no per-request state or timeout; the sockets stay up with 30-second pings. The
  bridge sets no route timeout either. The only limit is the client's per-call timeout, which step 4 sets to 16
  minutes. The live run went through the bridge's debug server, since no client calls the route yet.

### D5. Flow inside the bridge

`SessionSendService.send({sourceSessionId, targetSessionId})` runs these steps:

1. **Validate.** The ids must differ. Both sessions must exist and be unarchived, and the source must be a root
   session. Each failure has its own typed code.
2. **Subscribe first.** It subscribes to `SessionEventDispatcher.events` and to the existing
   `SessionAbortService.abortStartedSessions` before sending, so the echo can't be missed. `abortStartedSessions`
   fires on every user Stop, and on archive's stop, before the plugin confirms.
3. **Check and send in one reservation.** Inside one `SessionOperationDispatcher.dispatch` on the source, it runs the
   readiness check (D2) and then `SessionPromptService.sendPromptAlreadyReserved` with a fresh prompt id. This is the
   continuation template (`session_continuation_service.dart:153-178`). No other prompt can slip in between the check
   and the send. The reservation is released before the wait, so the user can still stop the turn or answer its
   questions.
4. **Wait for the turn to end.** It records the user message whose live echo carries the prompt id. It then waits for
   an idle for the source after that echo. Step 3 found that harnesses report idle either as an idle
   `NormalizedStatusEvent` or as `BridgeSseSessionIdle` (Claude uses the latter), so both count. A terminal handoff
   (the plugin stopping mid-turn) fails with `summaryFailed`, and so does an error message for the source after the
   echo (Codex ends a failed turn with an error message and a plain idle). Bridge shutdown ends an open wait as
   `summaryStopped`, so the route does not hold shutdown for the rest of the 15 minutes; a send that reaches the
   source reservation after shutdown began sends nothing and fails as `sourceUnavailable`.
   - A session error event for the source fails with `summaryFailed`.
   - A user stop of the source fails with `summaryStopped`. Stopping is the natural way to cancel a send, and a half
     summary must never reach the target.
   - Fifteen minutes without an end fails with `summaryTimedOut`.
   - A pending question or permission doesn't stop the wait: the user answers it in the source.
5. **Read and split.** It reads the whole history once through `ChatHistoryService`.
   - Step 3 divergence: it first calls `ChatHistoryService.backfillSession` for the source, as archive export does,
     because the live capture of the reply's parts can trail the idle event. A failed refresh is logged and the read
     uses the stored history.
   - A refresh can replace the live echo with a replayed message under another id (ACP replays do), so the split
     finds the request by its echo id, or failing that by its exact text, taking the last match. The summary stops at the next user
     message, so a prompt queued behind the summary stays out of it.
   - The transcript is every message before the summarise user message, without the summary exchanges of earlier
     sends. Step 4 divergence: each earlier prompt turn whose opening user message carries a source-side stamp
     (`handoff.sent` or `handoff.notSent`, D11) is dropped, from that message up to the next user message, because
     those exchanges stay hidden behind their marker in the source. A target-side `handoff.received` message stays:
     it is real context. The split in `SessionSendService` does this; the builder stays a pure function of its list.
   - The summary is the text parts of the assistant messages after it.
   - No text fails with `summaryMissing`.
6. **Render and store.** It renders the transcript with `SessionTranscriptMarkdownBuilder` (D6) and saves it for the
   target (D7). A write failure fails with `transcriptUnavailable`.
7. **Send to the target.** It sends with `SessionPromptService.sendPrompt` on the target, using the target's prompt
   defaults. A refusal or failure fails with `targetRefused`. Draft wording:

   > This is a handoff from another Sesori session, "<source title>" (<harness>, in `<source directory>`). Its agent
   > wrote this summary:
   >
   > <summary>
   >
   > The full transcript is at `<absolute path>`. Read it only if you need details the summary leaves out.

The route maps `SessionSendRejectedException(code)` to HTTP 409 with a `SendToSessionErrorResponse`. A missing session
returns 404. The exception lives in `bridge/app/lib/src/services/`, next to `session_prompt_refused_exception.dart`.

`SessionSendService` (bridge `services/`) takes these collaborators:

| Collaborator | Used for |
|---|---|
| `SessionRepository` | Existence, root and archived checks, statuses, and `markHandoffNotSent` on a failed send (D11) |
| `SessionViewService` | Session snapshots (title, directory, `pluginId`, created time) and prompt defaults, as continuation uses it |
| `PermissionRepository`, `QuestionRepository` | Awaiting-input checks |
| `SessionOperationDispatcher` | The source reservation in step 3 |
| `SessionPromptService` | Both sends, each with its handoff stamp (D11) |
| `SessionEventDispatcher` | Echo, idle and error events |
| `SessionAbortService` | `abortStartedSessions` |
| `ChatHistoryService` | The whole-history read, and `markHandoffNotSent` on a failed send (D11) |
| The transcripts `PromptUploadRepository` instance | Saving the file |
| `SessionTranscriptMarkdownBuilder` | Rendering |
| `PluginLifecycleService` | The harness display name, from the same metadata `GetPluginsHandler` returns |
| `Clock` | The export time in the Markdown header. The 15-minute wait is a constructor `Duration`, so tests can shorten it |

**Logs** carry session ids, prompt ids, message counts, byte sizes, the file path and the failure code. They never carry
the summary, the transcript or prompt text.

### D6. The Markdown builder

`SessionTranscriptMarkdownBuilder` (bridge `repositories/mappers/`) is a pure transformation. It takes the source
`Session`, the harness display name, the export time and a `List<MessageWithParts>`, and returns a `String`.

- **Header:** title, harness, directory, created and exported times (UTC), and the message count.
- **Messages:** each one gets a numbered heading with its role, the agent and model for assistants, and its time.
  Error messages show their name and message.
- **Parts:**

| Part | Rendered as |
|---|---|
| Text | Verbatim |
| Tool | One line with the title or shell command and the status, then the error if any, then the output capped at 4 KB with a "[truncated: N characters]" note |
| File | `[Attached file: name (mime)]`, without the bytes |
| Subtask | `[Sub-agent: description]`. Child transcripts are not inlined |
| Compaction | `[Context compacted]` once it completed; a running or failed one is left out |
| Reasoning, step markers, snapshot, patch, agent, retry | Left out |

- Leaving out reasoning keeps the file to the conversation itself, and some harnesses encrypt reasoning.
- Patch is left out because the part carries no file list on the wire or in the plugin interface (step 2
  finding); the tool lines already name the edited files. `MessagePart` has no unknown variant.
- No redaction: the file stays on the same computer, in an owner-only folder.

### D7. Where the file lives, and when it is deleted

- **Location: `~/.sesori/transcripts/<targetSessionId>/<date>-<random>/<name>.md`.** This is a second
  `PromptUploadRepository` instance rooted at a new `sesoriTranscriptsDirectory()`. Its layout, owner-only
  permissions and `deleteSessions` are reused as they are. The 30-day upload sweep is not wired to it.
  - **Why `~/.sesori` rather than `~/.local/share/sesori`.** The brief says "Sesori's data folder". The strict data
    directory holds auth tokens and databases, so a read rule for agents there would expose them. `~/.sesori` is the
    folder Sesori already uses for files that agents read by absolute path.
  - **Why not the target's worktree.** That folder is inside the agent's working directory, so it would avoid prompts
    on every harness. But it would dirty `git status` in the user's repo, or need `.git/info/exclude` edits, and a
    scratch session has no repo at all.
- **Owner: the target session.** The path is part of the target's prompt, and the target agent may read the file again
  later. So the file is deleted with the target session: `SessionDeletionService.onDeleted` removes the family's
  transcript folders as best effort, next to `_deletePromptUploads`. Deleting the source leaves the target's copy.
  Archiving keeps the file, because an archived session can be unarchived.
- **Approval prompts.**
  - Claude Code asks today, so step 5 adds two read-only rules at every launch (S4 = B):
    `--allowedTools "Read(/<transcripts root>/**)" "Read(/<uploads root>/**)"`. With each root's leading `/`, that is
    Claude's `//` absolute-path form; a Windows drive path is written in the POSIX form Claude matches
    (`C:\Users\a` as `/c/Users/a`). They go through the plugin's existing `allowedTools` path. Every Claude process
    the bridge starts after an update carries them. The rules are read-only and grant no write access; only a write rule the user approves for the session could.
  - The uploads rule covers files the user attached to prompts (`~/.sesori/uploads`, written by
    `PromptUploadRepository`), so attachments stop asking on Claude Code too. That reverses the file-transfer plan's D1
    (`.plan/completed/file-transfer/PLAN.md`, kept as history). The live records that still say Claude asks are updated
    in the same step: the Claude Code row of `docs/HARNESS_CAPABILITIES.md` "Saved prompt files" ("Yes: one permission
    request per read outside the working directory, since Sesori passes no `--add-dir`") and, if its wording then
    names Claude, the "some harnesses ask before reading them" line in `docs/regression/attachments-and-images.md`.
  - The Claude plugin's composer resolves `sesoriTranscriptsDirectory()` and `sesoriUploadsDirectory()` once and passes
    both roots into `ClaudeLaunchSpec` as values. The spec stays a pure argument builder, and each folder has one
    owner.
  - Codex, Pi, OMP, DeepSeek and Grok need nothing.
  - OpenCode and the four unverified ACP harnesses are checked live in step 11. Any that ask are recorded, and fixing
    them is a later-phase item. Most targets won't read the file at all, because the summary comes first.

### D8. Client UX

- **Entry.** "Send to another session…" goes in `sessionMenuEntries`, after Mark read/unread and before Archive, so it
  shows on all four surfaces.
  - It is hidden for archived sessions and child sessions.
  - There is no capability flag. Against an older bridge the send gets the router's missing-route 404, which the
    repository detects with the existing `_isMissingRoute`. The client then answers with an alert: "Update Sesori on
    this computer to send sessions."
  - This costs one wasted pick, only for a new app on an old bridge. Bridges update themselves in place. That is cheaper
    than a new flag plus a discovery cache that no list surface holds today.
- **Send sheet (Q3).** The entry opens a small "Send to another session" sheet (a popover under a pointer) with three
  rows: "To", showing the chosen target or "Choose a session" with a chevron; the switch "Archive this session after
  sending"; and Send, disabled until a target is chosen.
  - The switch is on by default and remembers the last choice on this device, as one boolean. It is not shown when
    the source is a side chat (a later phase), which never archives.
  - The boolean lives in a new `ArchiveAfterSendPreferenceStorage` (`module_core/lib/src/repositories/`), modelled on
    `DedicatedWorktreePreferenceStore`: `read()` defaults to true, `write({value})` logs a failed write. It sits on
    `PersisterRepository` with a new `BoolPreferenceKey.archiveAfterSend`.
  - `SessionActionsCubit` takes the storage directly, as `NewSessionCubit` takes its preference store, and exposes
    `archiveAfterSend()` and `setArchiveAfterSend({value})` as futures, keeping the cubit stateless. The sheet keeps
    the switch's current value as widget state.
  - Tapping "To" opens the picker. Picking a row returns to the sheet with the target filled in, using the sheet's
    normal push and pop transition.
- **Picker.** `SessionPicker` is new in `module_app_ui/lib/src/features/session_picker/` and is modelled on
  `ProjectPicker`.
  - It opens as the send sheet's second page under touch and a popover under a pointer, with
    `PregoPickerSearchList` in both.
  - It is backed by `SessionSearchCubit`. Its search field searches across projects, and the blank state lists the
    newest sessions.
  - Running rows carry the D3 label: "Running: sending stops its current turn" for `stopTurn` harnesses, "Running"
    otherwise.
- **Picker wiring in `module_core`.**
  - `SessionSearchCubit` gains a constructor `excludedSessionId`, so the source never shows. The desktop palette passes
    null.
  - `SessionSearchMatch` gains `running: RunningTarget?` (null when idle). `RunningTarget` is an enum, `stopsTurn` or
    `keepsTurn`. `SessionSearchCubit` computes it, and the widget only picks its label from it.
    - Running comes from a new `SseEventTracker` dependency: the cubit subscribes to `sessionActivity` and reads
      `isRunning` per row, the same signal `SessionWindowService._isRunning` reads.
    - The harness behaviour comes from a new `PluginRepository` dependency: one `listPlugins()` when the cubit opens,
      kept as a `pluginId → busyPromptHandling` map and matched on `Session.pluginId`. `stopTurn` gives `stopsTurn`;
      every other value, an unknown plugin and a failed listing give `keepsTurn`, whose label is the plain "Running".
  - A new `createSessionSearchCubit({locator, window})` in `module_core/lib/src/di/cubit_composition.dart` holds the
    collaborator list, next to `createSessionActionsCubit`. The desktop palette and both shells use it.
  - `module_app_ui` has no `getIt`. Each shell gives `SessionListActionDispatcher` a session-search cubit factory built
    on `createSessionSearchCubit`, alongside the new `openSession` callback.
- **Stop from any surface.**
  - The list and sidebar only have `SessionActionsCubit`.
  - It gains `stopSession`, which delegates to `module_core`'s `SessionAbortService.abortSession` for the busy alert's
    Stop action.
- **What you see after sending (S1 = A).**
  - You stay where you are. The sheet closes with its normal transition.
  - A popup alert says "Sending to <target>. <Source> is writing a summary first."
  - On the source page, the marker of D12 appears where the turn would, in its "Writing a summary…" state, through the
    ordinary new-turn arrival. Nothing jumps.
  - When the bridge answers, a success alert says "Sent to <target>" with an **Open** action that opens the target. A
    failure alert gives the reason in plain words, for example "Couldn't send: the summary was stopped."
  - Alerts use the existing `PregoPopupAlertPresenter`. The presenter is captured before the request, so the alert
    still shows after the user leaves the page.
  - With the archive switch on, a success then archives the source (D13).
- **Same computer.** This needs no filter, because the picker can only list the connected bridge's sessions. A
  computer switch during a send drops the response, and the client shows nothing more. The bridge still finishes.

### D9. Wire compatibility

New wire contracts, all additive:

- `SendToSessionRequest{sourceSessionId, targetSessionId}`.
- `SendToSessionErrorResponse{code, message}`, with a closed `SendToSessionErrorCode` enum and
  `@JsonKey(unknownEnumValue: SendToSessionErrorCode.unknown)`. The codes are:
  - `sameSession`
  - `sourceArchived`, `targetArchived`, `sourceNotRoot`
  - `sourceBusy`, `sourceAwaitingInput`, `sourceUnavailable`, `sourceOptionsUnavailable`, `sourceEmpty`
  - `summaryStopped`, `summaryFailed`, `summaryTimedOut`, `summaryMissing`
  - `transcriptUnavailable`, `targetRefused`, `targetOptionsUnavailable`
  - `unknown`

How each pairing behaves:

| Pairing | Behaviour |
|---|---|
| New app, old bridge | The route is missing. The repository maps the 404 to `SendToSessionResult.unsupported`, with a `// COMPATIBILITY 2026-11-14 (v1.14.0): Bridges before session sending have no /session/send-to-session route. Remove the unsupported result once the minimum supported bridge has it.` comment, and the user sees the update alert. Nothing else breaks. |
| Old app, new bridge | The app never calls the route and ignores the unknown `handoff` key. A send started from another client looks like ordinary turns: a user prompt and reply in the source, and a user prompt in the target. |
| New app, bridge with the route | Markers render as D12. |

Three more additive fields:

- `Message.user` gains a nullable `handoff: MessageHandoff?` (D11). Null is the honest meaning for every other
  message, so it needs no `@Default` or compatibility comment.
- `PluginMetadata.busyPromptHandling` (D3).
- `QueuedSessionPrompt` gains the same nullable `handoff` (step 8.a), so a queued handoff prompt renders as its
  marker or card before its echo. Null is again the honest meaning for every other prompt.

No `sesori.db` schema change. The history store's stored message JSON gains the optional `handoff` key; its schema
does not change.

### D10. Analytics

`session_sent_to_session` is recorded with the source harness kind and a closed outcome, following the decision's
"harness kind and outcome only".

- The outcome values are `sent`, `refused_busy`, `refused_other`, `failed`, `unsupported` and `unconfirmed`.
- It is reported from `SessionActionService.sendToSession` once the bridge's answer arrives. `ProductAnalyticsService`
  becomes a new dependency of that service.
- The service holds no sessions, so the send flow passes the source's plugin id through `SessionActionsCubit`. A
  send that ends after a computer switch is still reported: it ran on the computer the app left.
- Follow the `add-analytics` skill checklist.

### D11. The handoff marker, stamped by the bridge on every harness

The bridge marks the two user messages of a send, so every client can render them (S3). It follows the command
invocation precedent exactly: `CommandInvocationTracker` records an invocation by `(sessionId, promptId)`,
`SessionRepository.stampLiveInvocation` stamps it on the live echo, and the history store keeps it across later updates
and replays (`ChatHistoryRepository._withStoredInvocation`).

- **Model** (`sesori_shared`): a sealed Freezed `MessageHandoff`, union key `kind`, `fallbackUnion: "unknown"` so an
  older client survives a later variant:
  - `sent({required String targetSessionId, required String? targetTitle})` on the summarise prompt in the source;
  - `notSent({required String targetSessionId, required String? targetTitle})` on the summarise prompt of a send that
    did not complete (step 4 divergence, see below);
  - `received({required String sourceSessionId, required String? sourceTitle, required String summary, required
    String transcriptPath})` on the handoff prompt in the target. The card needs the summary and path apart from the
    prompt's wording, so the bridge stores them rather than having the client parse the prompt text;
  - `unknown()`.
  - Titles are snapshots taken at send time, null when the session had none. Ids are kept as they are. Opening a
    deleted session through the marker gets the existing "session not found" answer; nothing nulls them on delete.
- **Bridge.**
  - **One prompt-stamp record, not a second tracker.** `CommandInvocationTracker`
    (`repositories/trackers/command_invocation_tracker.dart`) becomes `PromptStampTracker`. It keeps its key, capacity
    and eviction, and stores a sealed `PromptStamp` (bridge-internal, beside the tracker):
    `PromptStampCommand(invocation)` or `PromptStampHandoff(handoff)`. A prompt is either a command or a handoff, never
    both. `stampQueuedPrompts` applies a command's source or a handoff to each queued prompt.
  - **Recorded inside the send, as commands are.** `SessionRepository.sendPrompt` gains
    `required MessageHandoff? handoff`. When it is set, the repository records it under the prompt id before the plugin
    call, because the echo can arrive before the call returns. It forgets it again on a definite 4xx refusal, exactly as
    `sendCommand` does. `SessionPromptService.sendPrompt` and `sendPromptAlreadyReserved` gain the same parameter and
    pass it through. The prompt route and continuation pass null. `SessionSendService` passes `sent` with the summarise
    send and `received` with the target send, and never touches the tracker.
  - `SessionRepository.stampLiveInvocation` becomes `stampLiveMessage` and applies either stamp kind, so there is one
    live stamping seam (`SessionEventService` is its only caller).
  - `_withStoredInvocation` becomes `_withStoredStamps` and keeps a stored `handoff` the same way it keeps an
    invocation. Archive's audit export carries the stored JSON, so archived sessions keep their markers.
  - **A failed send keeps the summary exchange hidden** (step 4 divergence, user decision). Sesori's request to the
    source agent is never shown as a plain message, so a failure does not clear the stamp: it turns `sent` into
    `notSent`. On any failure after the source checks, `SessionSendService` calls
    `SessionRepository.markHandoffNotSent({sessionId, promptId})`, which replaces a tracked `sent` stamp, so a late
    echo or a later live update of the echo is stamped `notSent`. Once the echo has arrived it also calls
    `ChatHistoryService.markHandoffNotSent({sessionId, messageId})`, which runs on the session's history write lane
    and replaces the stored `sent` stamp; when the refresh before the split replaced the echo with a replayed message
    under another id, that id is marked too. A harness can also store the request without ever echoing it live
    (a Claude source stopped before its echo). For a failure before the echo, `SessionSendService` waits up to ten
    seconds for the source's next idle. It then refreshes the history and finds the last user message with the exact
    request text. When that message has no stamp, the store stamps it `notSent`; a stamped match is an earlier
    send's request and stays as it is. A definite 4xx refusal of the summarise prompt still forgets the stamp in
    `sendPrompt`, because no turn happened, so the mark finds nothing. A stored mark pushes a history refresh, so an
    open chat turns its marker into "Couldn't send" without a reload; the requesting client also gets the failure
    alert.
  - The history store's replay matching ignores `handoff` as it ignores `invocation`, so a replay under another id
    still pairs with the stamped live row and keeps its stamp. Marking a stored stamp `notSent` refreshes the row's
    `updatedAt`, so the next replay still treats the row as current and pairs it.
- **Logs** carry the ids and the handoff kind, never the summary.
- A bridge restart during the summary loses the tracker entry. That send is already lost (accepted risk). An echo that
  arrives after the restart is unstamped and shows as an ordinary exchange; one stored before it keeps `sent`, because
  nothing is left to mark it `notSent`.

### D12. How the handoff renders (Q2)

- **Source chat: a one-line centred marker.** The client folds the whole prompt turn whose opener carries
  `handoff.sent` (`TranscriptPromptTurn` in `module_core`'s `transcript_turns.dart`) into one row:
  - while the turn runs: "Writing a summary for <target>…";
  - once it ends: "Summary sent to <target> · Open". **Open** opens the target.
  - Tapping the line opens a sheet with the summary, which is the turn's assistant text. Sesori's request and the
    agent's reply stay hidden.
  - The row arrives through the ordinary new-turn path and keeps one height in both states, so nothing jumps when
    the turn ends.
  - A turn whose opener carries `handoff.notSent` folds the same way into "Couldn't send to <target>". Tapping it
    shows the agent's reply in the same sheet when there is one. Sesori's request never shows as a plain message.
- **Target chat: a card in place of the user bubble** for a message carrying `handoff.received`:
  - header "From <source>", linking to the source (archived sources open read-only, as today);
  - the first lines of the summary, faded at the bottom, with "Show all";
  - the transcript path below the summary, in monospace, selectable;
  - it never says "Archived after sending".
  - "Show all" grows the card downward in place. The card's top edge and everything above it stay where they are,
    whichever way the list is anchored. "Show less" collapses it the same way.
- **Both renderings live in `module_app_ui`**, from view models the `module_core` transcript builder produces, so the
  widgets hold no folding rules.

### D13. Archive the source after sending (Q3)

- **Client-owned.** After a `sent` result with the switch on, the client runs the ordinary archive of the source through
  the existing archive flow, so its refusal modal and Undo window apply unchanged. The bridge route stays
  archive-free, and automation decides for itself.
- **Owner: `SessionListActionDispatcher`'s send flow** (`module_app_ui`), which already composes the archive gesture
  (`_archive`). Before the request, it captures the `PendingSessionArchiveCubit` from the stable list or page
  context, together with the alert presenter. On `SendToSessionSent` with the switch on, it calls
  `PendingSessionArchiveCubit.archive(session:, deleteWorktree: session.hasWorktree)`, the same call `_archive`
  makes, and then calls `onSessionArchived` if the context is still mounted. The confirmation was already asked
  before the send, so it doesn't ask again. No `module_core` class learns about archiving after a send.
- **Pinned sources ask first.** When the source is pinned and the switch is on, tapping Send shows the usual pinned
  archive confirmation before anything is sent. Cancelling it keeps the sheet open. Confirming sends, and the later
  archive doesn't ask again. This keeps the question next to the tap rather than a minute later.
- **Only after the summary landed.** `refused`, `failed`, `unsupported` and `unconfirmed` results never archive. An
  unconfirmed send leaves the source in place even if the bridge finished; the user can archive it by hand.
- **Feedback.** With archiving, the success alert reads "Sent to <target>. Archived <source>." with **Open** and
  **Undo**; Undo is the archive flow's own. When the user is on the source page, the page does what archiving from it
  does today.
- **Side-chat sends** have no switch and never archive (sibling plan).

## Seams with the sibling plans

- **Side chat "Send to main session".**
  - It uses this feature with the side chat as the source and its main session as the target.
  - A side chat may not be a harness session. Claude `side_question` and Codex `thread/sample` are one-shot, so that
    plan owns how its summary and transcript are produced.
  - Steps 5–7 of D5 (render, store, prompt the target) are the reusable half. Keep them as a cohesive private method of
    `SessionSendService` now. Expose them when the side-chat plan needs them, not before.
  - Its send sheet has no archive switch and never archives (D13).
  - The target card of D12 applies unchanged; the source marker does not, because the side chat has its own UI.
- **Fork fallback.** It seeds a new session with earlier conversation text. `SessionTranscriptMarkdownBuilder` takes a
  plain message list, so the fork plan can pass the slice before the fork point. Any truncation option is added by
  that plan when it needs one.
- **Edit and fork.** A fork that copies a marked turn keeps its stored stamps only where the fork plan copies stored
  history; no handling is owed here.

## Complexity budget

- **New persistent state:** the transcript files, and the optional `handoff` key inside stored message JSON. No tables
  or columns.
- **New in-memory parts:**
  - per send: one event subscription, one subscription to the existing `abortStartedSessions`, one timeout timer, and
    local variables for the prompt id and user message id;
  - no new tracker: handoff stamps share the existing bounded prompt-stamp record (D11).
- **Client:** one remembered boolean for the archive switch. The sheet awaits one request future.
- **Deliberately not added:**
  - an SSE outcome event, an in-flight send registry or a dedupe set (a double tap's second request hits the busy
    refusal, because step 3 checks and sends inside one source reservation);
  - recovery of an in-flight send after a bridge restart;
  - a hidden-turn mechanism or per-harness summarisers;
  - queueing until the source is idle;
  - an orphan-file sweep or a preview;
  - a capability flag on `GET /plugin` plus a client discovery cache (the missing-route 404 answers the tap instead);
  - a new abort stream (`abortStartedSessions` already exists);
  - a handoff table, delete cascades for marker ids, or a bridge-side archive step.

### Safeguards and evidence

| Safeguard | Evidence |
|---|---|
| Busy-source refusal | Ordinary flow: sending from a running session. On ACP it would otherwise kill the turn. |
| Stop cancels the send | Ordinary flow. Without it, a half summary is delivered and can't be undone. |
| 15-minute bound | Theoretical stuck session. It costs one timer and keeps the request from hanging forever. |
| Failed send marks the source stamp not sent | Ordinary flow (stop, error, target refusal). Otherwise the source says "Summary sent" for a send that never happened, permanently, or Sesori's request shows as a plain message. |
| Archive only on `sent` | Ordinary flow. Archiving on failure would hide the only copy of the work from the list. |

**Accepted risks:**

- A bridge restart during the summary loses the send. An echo after the restart is unstamped and the source shows the
  summary turn as an ordinary exchange; an echo stored before it keeps its `sent` marker (D11). The user sends again.
- A client that disconnects gets no outcome and doesn't archive. The target transcript shows the result.
- A failed folder deletion leaks a small local file. This is logged.
- The summary costs one source turn of tokens.
- On a steering harness (Codex, Pi, OpenCode, OMP), a follow-up the user types during the summary joins that turn and
  is folded into the marker. The marker's sheet doesn't show it. Rare, since the user just asked to hand off.

## Steps

Merge gate, for every implementer:

> Right before `gh pr merge`, check all three:
>
> - Re-fetch the inline comments and confirm each one whose `original_commit_id` matches the head has a reply or a fix.
> - Confirm Codex's completion comment names that exact head.
> - Wait at least 3 minutes after Codex's last comment.
>
> If Codex is still "Running" after about 30 minutes, or was triggered on an older head, and CI is green, cubic has
> approved and every thread has a reply, use the PR monitor's `mark_ready`.

Testing rule, for every implementer:

> Run on-screen and device checks only on a headless iOS simulator: `xcrun simctl boot` without opening Simulator.app,
> on the device the project's local testing setup assigns. Don't cross-test on macOS desktop, Android or real devices.

Worktrees go under `~/.claude-worktrees/sesori_apps_monorepo/<name>`. Never use `git stash`.

Dart rules:

- Named `required` parameters.
- Sealed Freezed classes.
- No null assertions.
- No prompt, summary or transcript text in logs.

```
1 ── 2 ── 3 ─┬─ 4 ────────────── 8 ── 8.a ┐
     │       ├─ 5                         ├─ 11 ── 12
     │       └──────── 7 ─┬─ 7.a ── 9 ────┤
     └─ 6 ─────────────┘  └─ 10 ──────────┘
```

- Step 5 needs only step 2's folder helper, but it ships after step 3 so the rule never lands without its feature.
- Step 6 is independent of the send flow and can start right after step 1.
- Step 7 needs 3 and 6. Step 8 needs 4, and is built against fixture messages, so it runs in parallel with 7.
- Step 8.a needs 8. It came out of step 8's live run.
- Step 7.a needs 7. Step 9 needs 7.a, whose send flow it extends with the archive. Step 10 needs only 7.
- Steps 1 and 12 follow the docs-only PR rule. Step 11 also carries live checks, so it waits for its normal review.

### Step 1: raise the plan

`🌱 [session-send] Raise the session sending plan [step 1/14]`

- **Complexity:** trivial. Documents only.
- **What:** adds `.plan/active/session-send/PLAN.md` and `TRACKER.md`.
- **Why:** pins the design before the bridge and client work starts.
- **Risk and test focus:** none. Check the diff is docs-only.
- **Expected result:** no user-visible or database change.

### Step 2: transcript Markdown and its file store

`⚙️ [session-send] Render a session transcript as Markdown and store it with the receiving session [step 2/14]`. About
650 lines.

- **Complexity:** moderate. A pure builder with many part kinds, plus file lifetime wired into deletion.
- **What:**
  - adds `sesoriTranscriptsDirectory()` to `sesori_data_directory.dart`;
  - adds `SessionTranscriptMarkdownBuilder` (D6);
  - adds a second `PromptUploadRepository` instance for transcripts in the orchestrator;
  - makes `SessionDeletionService` delete transcript folders for the deleted family;
  - adds builder tests for every part kind, truncation and the empty transcript, plus a deletion test.
- **Why:** step 3's send flow needs both pieces, and keeping them separate keeps step 3 reviewable.
- **Risk and test focus:** low. Check that session deletion still runs every existing cleanup.
- **Expected result:** no user-visible or database change. Deleting a session also removes
  `~/.sesori/transcripts/<id>/` if it exists.

### Step 3: the bridge send flow

`🚧 [session-send] Send one session into another from the bridge [step 3/14]`. About 1,450 lines, about 370 of them
generated.

- **Complexity:** complex. A cross-layer flow with an event-driven wait, cancellation and new wire contracts.
- **What:**
  - adds the shared `SendToSessionRequest`, `SendToSessionErrorResponse` and `SendToSessionErrorCode`;
  - adds `SessionSendService` with the collaborators listed in D5, and `SessionSendRejectedException`;
  - adds `SendToSessionHandler` (`POST /session/send-to-session`);
  - adds orchestrator wiring.
- **Tests:** service tests with a fake plugin and event stream, covering:
  - success;
  - each refusal;
  - a stop during the summary;
  - a second send racing the first (it must be refused as busy);
  - a session error;
  - a timeout (fake clock);
  - a missing summary;
  - a target refusal;
  - confirming that no prompt text reaches a log.
- **Live check:** a real Claude source and a real Codex target through the debug server or a local client. Confirm the
  relay holds a request for several minutes (D4). Use the `sesori-local-testing` skill.
- **Why:** this is the feature's core. The client can't ship without it.
- **Risk and test focus:** medium. Watch the source lane (the user's own prompts and stop must keep working during the
  wait), and the busy and stop paths.
- **Expected result:** a send produces a summary turn in the source and a handoff prompt in the target, and writes a
  file under `~/.sesori/transcripts/`. No client calls it yet. No database change.

### Step 4: the handoff marker in the bridge

`🚧 [session-send] Mark handoff messages in the bridge [step 4/14]`. About 650 lines, about 350 of them generated.

- **Complexity:** complex. A new field on the core message model, stamped live and kept through the history store's
  merge and replay paths.
- **What:**
  - adds `MessageHandoff` and `Message.user.handoff` in `sesori_shared` (D11);
  - turns `CommandInvocationTracker` into `PromptStampTracker` with the sealed `PromptStamp`, renames
    `stampLiveInvocation` to `stampLiveMessage` and applies either stamp kind;
  - adds `required MessageHandoff? handoff` to `SessionRepository.sendPrompt`, `SessionPromptService.sendPrompt` and
    `sendPromptAlreadyReserved`, recorded before the plugin call and forgotten on a definite refusal; existing callers
    pass null;
  - renames `_withStoredInvocation` to `_withStoredStamps` and keeps a stored `handoff`;
  - adds the `notSent` variant, `SessionRepository.markHandoffNotSent` (tracker) and
    `ChatHistoryService.markHandoffNotSent` (stored history);
  - `SessionSendService` passes both stamps with its sends, marks the source stamp not sent on failure, and leaves
    earlier stamped summary exchanges out of the transcript;
  - shares the prompt-defaults mapping of both sends and continuation as `SessionPromptService.settingsFrom`.
- **Tests:** stamping on the live echo; the stamp surviving a later update, a harness replay and archive export; the
  not-sent mark after each failure kind, before and after the echo; the transcript skipping stamped turns; an older
  client's JSON parse ignoring the key; an unknown kind parsing to `unknown`.
- **Why:** both chats need to know which messages are the handoff, on every harness (S3).
- **Risk and test focus:** medium. The history merge runs on every message; check invocation stamping is unchanged.
- **Expected result:** no user-visible change until step 8. Stored history JSON gains the key on handoff messages only.
  No schema change.

### Step 5: Claude reads the transcripts and uploads folders without asking

`🌿 [session-send] Let Claude Code read Sesori transcripts and uploads without a prompt [step 5/14]`. About 120 lines plus
docs.

- **Complexity:** straightforward. Two launch arguments, their test and two doc lines.
- **What:**
  - the Claude plugin's composer resolves `sesoriTranscriptsDirectory()` and `sesoriUploadsDirectory()` once and
    passes both roots into `ClaudeLaunchSpec` as values;
  - the spec always adds both read rules to `--allowedTools` (D7);
  - updates the Claude Code row of `docs/HARNESS_CAPABILITIES.md` "Saved prompt files" and, if needed, the line in
    `docs/regression/attachments-and-images.md` (D7).
- **Why:** Claude asks before every read outside the working directory (verified on 2.1.319), and Claude is a primary
  target. S4 = B extends the rule to uploads.
- **Risk and test focus:** low. Check that the existing granted rules are still passed, that the rules are read-only,
  and that a live Claude session reads a transcript and an attached upload with no `can_use_tool` request.
- **Expected result:** a Claude target reads the transcript, and a Claude session reads an attached file, without an
  approval card. No database change.

### Step 6: declare what a prompt to a busy session does

`🌿 [session-send] Declare each harness's busy-prompt behaviour [step 6/14]`. About 300 lines, mostly generated.

- **Complexity:** straightforward. One required descriptor field per plugin and one wire field.
- **What:**
  - adds `PluginBusyPromptHandling {steer, stopTurn}` and the abstract
    `BridgePluginDescriptor.busyPromptHandling` in `sesori_plugin_interface`;
  - sets it in every plugin from "Transcript turn boundaries";
  - adds the shared `BusyPromptHandling` with `unknown` on `PluginMetadata.busyPromptHandling` with its compatibility
    comment, the `toShared()` mapping in `plugin_to_shared_mapping.dart`, and the field in
    `PluginLifecycleService._rebuildMetadata` (D3).
- **Why:** the picker's Running label (S2) must come from the plugin, not from harness names in the client.
- **Risk and test focus:** low. Check each plugin's value against the doc.
- **Expected result:** no user-visible or database change.

### Step 7: the client send and stop pipeline

`⚙️ [session-send] Add the client send and stop pipeline [step 7/14]`. About 600 lines.

- **Complexity:** moderate. A sealed result over a long request, new cubit dependencies with a live subscription, and
  the desktop palette moving to a factory.
- **What:** everything in `module_core`:
  - adds `SessionApi.sendToSession` (16-minute timeout);
  - adds `SessionRepository.sendToSession`, which returns a sealed `SendToSessionResult`: sent, refused(code),
    failed(error), unsupported (missing route), or unconfirmed (timeout or lost connection);
  - adds `SessionActionService.sendToSession`, which also turns an answer that arrives after a computer switch into
    `computerSwitched`, because its ids belong to the computer left, and `SessionActionsCubit.sendToSession`;
  - adds `SessionActionsCubit.stopSession`, which delegates to `SessionAbortService.abortSession` and records the stop
    for the feedback prompt as the session page does;
  - gives `SessionSearchCubit` an `excludedSessionId` and the `SseEventTracker` and `PluginRepository` dependencies
    behind `SessionSearchMatch.running`, and adds `createSessionSearchCubit` to `cubit_composition.dart` for the
    palette and both shells (D8).
- **Tests:** repository, service and cubit tests for each result and stop outcome, and search-cubit tests for the
  exclusion and the running labels.
- **Why:** the pipeline step 7.a puts behind the menu.
- **Risk and test focus:** result mapping, unconfirmed versus failed, and the desktop palette's search staying
  unchanged.
- **Expected result:** no user-visible or database change.
- **As built (2026-11-15):** the original step 7 came to about 1,680 lines (about 1,330 authored, 350 generated l10n),
  so it split into this step and 7.a, and the series total is now 13. The sheet and picker cannot land without the
  menu entry that opens them, so the split runs along the layer boundary instead of the planned sheet-and-picker cut.

### Step 7.a: send from the session menu

`⚙️ [session-send] Send a session into another from its menu [step 7.a/14]`, stacked on step 7. About 1,150 lines
including l10n output.

- **Complexity:** moderate. A new sheet and picker, menu wiring on four surfaces, and an async outcome.
- **What:**
  - adds the send sheet (target row, archive switch shown but not yet acted on, Send), the `SessionPicker`, the menu
    entry and the busy alert with Stop (D2);
  - adds the sending, success-with-Open, update-the-bridge and failure alerts (D8);
  - adds the `openSession` callback and the session-search cubit factory that both shells give
    `SessionListActionDispatcher`;
  - adds the strings.
- **Tests:** widget tests for the picker's exclusion and both Running labels, and the menu entry's gating.
- **Visuals:** before-and-after screenshots of the menu and a short recording of a send, using fixture data only,
  hosted on `pr-media`.
- **Why:** this is the user-facing entry.
- **Risk and test focus:** medium. Watch the menu on all four surfaces, sheet-to-picker and popover transitions, and
  alerts that show after leaving the page.
- **Expected result:** users see the entry, the sheet and the picker, and get the agreed feedback. No database change.
- The switch is hidden until step 9 if step 9 won't land in the same release.
- **As built (2026-11-15):**
  - `openSession` is context-free (`{projectId, projectName, session}`): the shells open the target through their
    global router, because the Open action can fire after the sending page is gone.
  - The picker under touch is a second bottom sheet stacked over the send sheet, as `ProjectPicker` opens, rather than
    an in-sheet second page; Prego has no paged-sheet pattern yet. Under a pointer the send sheet is a centred dialog
    and the picker a popover anchored to its "To" row.
  - The archive switch is shown, on by default, kept as widget state and not yet acted on; step 9 adds the storage and
    the archive.

### Step 8: the handoff marker and card in the chats

`⚙️ [session-send] Show handoffs as a marker in the source and a card in the target [step 8/14]`. About 900 lines.

- **Complexity:** moderate. Turn folding in the transcript builder, two new transcript items and an in-place expansion.
- **What:**
  - a new `module_core` `TranscriptHandoffBuilder`, layered on the shared turn builder's turns, folds a turn whose
    request carries `handoff.sent` or `handoff.notSent` into a marker item ("Couldn't send to <target>" for
    `notSent`, D12), and turns a `handoff.received` user message into a card item (D12);
  - adds the marker row, its summary sheet and the card with "Show all" in `module_app_ui`;
  - adds the strings.
- **Tests:** builder tests for folding (running and ended, with steered follow-ups inside the turn) and for the card;
  widget tests for the marker states and the card's expansion keeping its top edge fixed.
- **Visuals:** screenshots of both chats and a short recording of "Show all", fixture data only, on `pr-media`.
- **Why:** this is the Q2 rendering.
- **Risk and test focus:** medium. Watch for jumps when the summary turn ends, when the card expands near the bottom
  of the list, and when older pages load above a marker.
- **Expected result:** handoffs read as a marker in the source and a card in the target. No database change.
- **As built:**
  - The folding lives in a separate `TranscriptHandoffBuilder`, layered on the turns the turn builder already
    splits. The shared turn builder, the prompt list and their exhaustive switches stay untouched.
  - The handoff stamp carries the other session's id and title, not its project. The marker and the card show the
    stamped title. A tap on Open or on the card's header reads the session first, to find its project and whether it
    is archived. A session that can't be read answers the tap with an alert.
  - When the card's top is scrolled off screen, "Show less" moves the card's top down as the card shrinks, so the
    toggle stays under the finger. Holding the top off screen would throw the whole card off the screen. Otherwise
    the top stays put, as planned.
  - Once a send has stopped, only the reply up to the next user message folds, so a prompt the turn rule joins to an
    unanswered request keeps its own rows. A handoff from another session never folds; it keeps its card.
  - A transcript shorter than the screen can't scroll, so before the card grows the list keeps the empty space above its
    oldest row, plus the growth to come, as top padding (`TranscriptTopReserve`), and the card starts growing once that
    has laid out. Every hold then stays in range (a hold past the end starts a spring back, whose end notification lands
    mid-layout). The room ahead goes back once the card has grown, the rest once it has collapsed.

### Step 8.a: queued handoff prompts stay hidden, and a failed send updates live

`⚙️ [session-send] Keep queued handoff prompts hidden and show a failed send live [step 8.a/14]`.

- **What:** stamp the handoff on the queued-prompt wire model (`QueuedSessionPrompt`) and have the bridge stamp it,
  so the source's request and the target's handoff prompt never show as a raw bubble before their echo. Push a
  message update after the bridge marks a request not sent, so an open chat turns "Summary sent" into "Couldn't
  send". Decide whether the stamp also carries the other session's project id.
- **Why:** step 8's live run showed both gaps; each needs a bridge or wire change.
- **As built:**
  - `QueuedSessionPrompt.handoff` reuses `MessageHandoff`. `SessionRepository.stampQueuedPrompts` (was
    `stampQueuedCommandSources`) applies whichever stamp the tracker holds for each queued prompt.
  - The transcript builder turns a queued `sent` or `notSent` prompt into a marker and a queued `received` prompt into
    a card, keyed by prompt id. The message list shows them in the queued prompt's own row, so the row keeps its
    place and its element when the echo arrives. The source's queued marker has no Cancel, as the source must be idle
    to hand off. The target's queued card waits under the usual Queued and Cancel line, because once the source has
    finished its summary, only the target can withdraw the prompt.
    The queued marker stays while the bridge still lists the prompt, because a user message can arrive before its
    parts, and a row with nothing to render falls back to the queue.
  - The Claude Code, Pi and ACP plugins now list a new queued prompt before they report the session busy. The
    projects-summary rebuild that follows busy held the queue update back by about 150 ms, so "Working…" showed
    before the marker.
  - `ChatHistoryService.markHandoffNotSent` adds a history refresh when it marked a stored row. Clients already reload
    on that event, so no new event type was needed.
  - The stamp carries no project id. Open already reads the session to learn whether it is archived, and that read
    returns its project, so a stamped id would save nothing and could go stale.

### Step 9: archive the source after sending

`🌿 [session-send] Archive the source after a send when asked [step 9/14]`. About 350 lines.

- **Complexity:** straightforward. Reuses the archive flow behind a remembered switch.
- **What:**
  - adds `ArchiveAfterSendPreferenceStorage` and `BoolPreferenceKey.archiveAfterSend` (default on), read and written
    through `SessionActionsCubit` (D8);
  - asks the pinned confirmation before sending a pinned source with the switch on;
  - in `SessionListActionDispatcher`'s send flow, runs `PendingSessionArchiveCubit.archive` after a `sent` result, with
    the combined success alert and Undo (D13).
- **Tests:** service and cubit tests for each result (only `sent` archives), the remembered value, and the pinned
  confirmation order.
- **Why:** Q3 treats sending as a move.
- **Risk and test focus:** low to medium. Check the refusal modal and Undo behave as in a plain archive, and that
  leaving the source page during the send still archives it.
- **Expected result:** with the switch on, the source is archived after the summary lands. No database change.

### Step 10: analytics

`🌿 [session-send] Report sessions sent into another session [step 10/14]`. About 250 lines.

- **Complexity:** straightforward. A closed event that follows the existing pattern.
- **What:**
  - adds `SessionSentToSessionEvent` (D10);
  - updates the exhaustive switches in `deferred_product_analytics_candidates.dart` and
    `desktop_product_analytics_delivery_service.dart`;
  - adds event tests;
  - updates `docs/regression/analytics.md`.
- **Why:** this is the agreed send analytics.
- **Risk and test focus:** low. Check exact wire names, that it is emitted only from the bridge's answer, and that a
  failure doesn't change the product's behaviour.
- **Expected result:** no user-visible or database change. Accounts that opted in report one event per send.

### Step 11: reconcile docs and harness rows

`🌿 [session-send] Document session sending and its harness differences [step 11/14]`

- **Complexity:** straightforward. Docs, plus live read checks.
- **What:**
  - adds `docs/regression/session-sending.md` (send sheet, picker labels, marker, card, archive switch) and lists it
    in the README's Feature Index;
  - updates `docs/regression/session-archiving-and-deletion.md`: the transcript file is deleted with the target
    session and kept on archive, and a send can archive its source;
  - adds a line to `docs/regression/projects-and-sessions.md` for the menu entry;
  - adds a "Sending a session into another" section to `docs/HARNESS_CAPABILITIES.md` (below).
- **Live check:** with the debug server, for every installed harness, check whether the target agent reads the file
  and whether it asks first, and that the marker and card appear. Mark runtimes that aren't installed as unverified.
- **Why:** these are the required feature and harness records.
- **Risk and test focus:** none in code. Check the docs against the live results.
- **Expected result:** no user-visible or database change.

### Step 12: verify and retire

`🌱 [session-send] Verify session sending and retire its plan [step 12/14]`

Run the matrix under Verification, record results in `TRACKER.md`, then move the plan to
`.plan/completed/session-send/`.

## Harness capability rows (step 11)

New section: "Sending a session into another", with the columns `Harness | Summary turn | Handoff marker | Reads the
transcript file | Asks first | Running target`.

- **Summary turn and handoff marker: ✅ on every harness.** Both go through the normal prompt path and the bridge's live
  echo. No harness offers a native merge, so Sesori builds it the same way everywhere.
- **Asks first:**

| Harness | Asks first |
|---|---|
| Claude | No, with step 5's rule |
| Codex, Pi, OMP, DeepSeek, Grok | No (expected from "Saved prompt files") |
| OpenCode | To check live; a stock config may ask through `external_directory` |
| Hermes, Cursor, Copilot, Antigravity | Unverified until checked live |

- **Running target:** steered in (Claude, Codex, Pi, OpenCode, OMP), or stops the running turn (the ACP
  family), from each plugin's `busyPromptHandling`.
  OMP's value is static: an older OMP on PATH that does not advertise `_session/steering` stops the turn without
  the picker's warning. Record that limitation in the OMP row.
- **Notes:**
  - A busy source is refused in the bridge core for every harness. Readiness comes from session statuses and pending
    permissions and questions, which every plugin supplies.
  - The summarise prompt stays in the harness's own transcript; only Sesori folds it.

## Verification

Highest level: **L4.** L2 covers the main send, L3 a send across harnesses, and L4 the refusal, stop, failure,
archive and per-harness read variants.

| Cell | Boundary | Plugins |
|---|---|---|
| Send from the session menu and from a list row, picker search, success alert, Open | Client end to end, iOS simulator | Claude source, Codex target |
| Source marker: "Writing a summary…" then "Summary sent to … · Open", summary sheet, no jump when the turn ends | Client end to end, iOS simulator | Claude source |
| Target card: "From <source>" link, path, "Show all" grows in place | Client end to end, iOS simulator | Codex target |
| Send across harnesses, reversed | Client end to end, iOS simulator | Codex source, Claude target |
| Archive switch on: source archived after success, Undo restores it; switch off: kept; choice remembered | Client end to end, iOS simulator | Claude source |
| Pinned source with the switch on: confirmation before sending; cancel keeps the sheet | Client end to end, iOS simulator | Any |
| Busy source: alert with Stop, then send | Client end to end, iOS simulator | Claude |
| Stop during the summary gives "summary was stopped", the target receives nothing, the source isn't archived, and the exchange shows as a "Couldn't send to …" marker after reload | Client end to end, iOS simulator | Claude |
| Picker labels: "Running: sending stops its current turn" on a running ACP session, "Running" on a running Codex session | Client end to end, iOS simulator | One ACP harness, Codex |
| Old bridge (a build before step 3): picking a target shows the update alert | Client end to end, iOS simulator | Any |
| Target archived between the pick and the send, and session-error paths | Headless bridge with a fake plugin (automated) | None |
| Transcript file written, owner-only, deleted with the target, kept on archive | Headless bridge | Representative |
| Markers survive a history replay and an archived read | Headless bridge | Claude, Codex |
| Claude reads a transcript and an attached upload without an approval card | Live plugin | Claude |
| The target reads the transcript file, and whether it asks | Live plugin | Every supporting production plugin; runtimes not installed are Blocked |

A reduction to this matrix needs the user's acceptance recorded here before retirement.

## Cleanup assessment

- `CommandInvocationTracker`, `stampLiveInvocation` and `_withStoredInvocation` are generalised in place into one
  prompt-stamp record and seam rather than duplicated (step 4).
- Step 3 left the prompt-defaults mapping (remembered defaults to a prompt's variant, fast mode, agent and model) in
  `SessionSendService` and `SessionContinuationService`. Step 4 shares it as `SessionPromptService.settingsFrom`,
  beside `generatePromptId`, which both already use.
- No other relevant cleanup was found. Readiness reuses the status and pending-request reads every plugin already
  supplies, so nothing is renamed.

## Risks

- **The relay may not hold a request for many minutes.** Step 3 checks this. The fallback is accept-then-SSE (D4).
- **The summary costs a turn**, and the request stays visible in the harness's own UI.
- **A running ACP target has its turn stopped** (D3, S2). The picker says so first.
- **OpenCode and the unverified ACP harnesses may show one approval prompt** when the target reads the file.
- **The card's in-place expansion** may fight the chat list's anchoring near the bottom. Step 8 tests it on the
  simulator before review.
- **Claude Code prunes its transcripts after 30 days** by default; Sesori's own Markdown copy is unaffected.

## Later phases (rough)

- **Send without a summary**, for archived or unrestorable sources, a source whose plugin is down, and as a retry after
  a failed summary.
- **Remove the remaining read prompts** on any harness step 11 finds asking, starting with OpenCode, inside its plugin.
- **The side chat's "Send to main session"** (side-question plan) reuses the delivery half of `SessionSendService`.
- **The fork fallback** reuses `SessionTranscriptMarkdownBuilder` for its seed text.
- **A summary from the side-question primitives** (Claude `side_question`, Codex `thread/sample`), so the summary leaves
  no source transcript entry and works while the source is busy. Only if the visible turn proves annoying, since it
  breaks uniformity.
- **Sub-agent transcripts** inlined or linked in the Markdown file.
- **Warehouse reporting** for the send event.

## Product questions

All answered (rounds 1–3). S1, S2, S4 and Q1–Q3 of the earlier draft are folded into the decisions above.

## Review record

Architecture plan review: see TRACKER.md. The round 2 and 3 changes were reviewed on 2026-11-15, and the findings are
applied above.
