# Send One Session Into Another

## Goal

From any session's menu, the user picks another session on the same computer. Sesori then sends the target a summary
written by the source session's agent, plus the absolute path of a Markdown file with the source's full transcript.
The target receives this at once as a normal prompt, with no preview.

Product decisions are final (user answers, 2026-11-14, `/tmp/rp/branching-brief.md`, Q10, Q11 and "Decided without
asking"). Edit and fork, and side questions, have their own plans. This plan only names their seams (see "Seams with
the sibling plans").

## Scope

Phase 1, this plan's steps:

- A bridge route that runs the whole send: it asks the source for a summary, writes the transcript file and prompts the
  target.
- A transcript-to-Markdown builder and the file store, with deletion tied to the session.
- A Claude Code read rule, so the target agent can read the file without an approval prompt.
- The client side: the "Send to another session…" menu entry, a session picker, and feedback after sending.
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
  - Claude queues them.
  - Codex, Pi, OpenCode and OMP steer them into the running turn.
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

- **It shows in the source transcript.** No harness can run a hidden turn through the normal prompt path. Hiding it
  would mean per-harness filtering of transcripts the harness owns (Claude's JSONL keeps it). A visible turn is honest
  and the same everywhere, and it leaves a record in the source of what was handed off. The user prefers uniform
  behaviour.
- **It uses the source's prompt defaults** (agent, model, variant, fast mode), like continuation does.
- **Draft wording**, kept short because the user sees it:

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
  - `sourceBusy` covers busy, retrying and queued;
  - `sourceAwaitingInput` covers a pending question or permission.
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
  Claude queues it, Codex, Pi, OpenCode and OMP steer it in, and ACP harnesses stop the running turn first.
- The picker labels running sessions, so the user sees this before choosing.
- Whether a running ACP target should be refused instead is open question Q2.

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
   an idle `NormalizedStatusEvent` for the source after that echo.
   - A session error event for the source fails with `summaryFailed`.
   - A user stop of the source fails with `summaryStopped`. Stopping is the natural way to cancel a send, and a half
     summary must never reach the target.
   - Fifteen minutes without an end fails with `summaryTimedOut`.
   - A pending question or permission doesn't stop the wait: the user answers it in the source.
5. **Read and split.** It reads the whole history once through `ChatHistoryService`.
   - The transcript is every message before the summarise user message.
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
| `SessionRepository` | Existence, root and archived checks, and statuses |
| `SessionViewService` | Session snapshots (title, directory, `pluginId`, created time) and prompt defaults, as continuation uses it |
| `PermissionRepository`, `QuestionRepository` | Awaiting-input checks |
| `SessionOperationDispatcher` | The source reservation in step 3 |
| `SessionPromptService` | Both sends |
| `SessionEventDispatcher` | Echo, idle and error events |
| `SessionAbortService` | `abortStartedSessions` |
| `ChatHistoryService` | The whole-history read |
| The transcripts `PromptUploadRepository` instance | Saving the file |
| `SessionTranscriptMarkdownBuilder` | Rendering |
| `PluginLifecycleService` | The harness display name, from the same metadata `GetPluginsHandler` returns |
| `Clock` | The 15-minute wait |

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
| Patch | The list of changed files |
| Compaction | `[Context compacted]` |
| Reasoning, step markers, snapshot, agent, retry, unknown | Left out |

- Leaving out reasoning keeps the file to the conversation itself, and some harnesses encrypt reasoning.
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
  - Claude Code asks today, so step 4 adds a read-only rule at every launch:
    `--allowedTools "Read(/<transcripts root>/**)"`. With the root's leading `/`, that is Claude's `//` absolute-path
    form. It goes through the plugin's existing `allowedTools` path. Every Claude process the bridge starts after an
    update carries it.
  - The Claude plugin's composer resolves `sesoriTranscriptsDirectory()` once and passes the root into
    `ClaudeLaunchSpec` as a value. The spec stays a pure argument builder, and the folder has one owner.
  - Codex, Pi, OMP, DeepSeek and Grok need nothing.
  - OpenCode and the four unverified ACP harnesses are checked live in step 7. Any that ask are recorded, and fixing
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
- **Picker.** `SessionPicker` is new in `module_app_ui/lib/src/features/session_picker/` and is modelled on
  `ProjectPicker`.
  - It opens a bottom sheet under touch and a popover under a pointer, with `PregoPickerSearchList` in both.
  - It is backed by `SessionSearchCubit`. Its search field searches across projects, and the blank state lists the
    newest sessions.
  - Picking a row closes the sheet with its normal transition.
- **Picker wiring in `module_core`.**
  - `SessionSearchCubit` gains a constructor `excludedSessionId`, so the source never shows. The desktop palette passes
    null.
  - `SessionSearchMatch` gains `isRunning`, computed in `module_core` from the rule behind
    `SessionWindowService._isRunning`. The widget shows a "Running" label from it and never rebuilds the rule.
  - `module_app_ui` has no `getIt`. Each shell gives `SessionListActionDispatcher` a session-search cubit factory,
    alongside the new `openSession` callback, as the desktop palette's shell wiring does today.
- **Stop from any surface.**
  - The list and sidebar only have `SessionActionsCubit`.
  - It gains `stopSession`, which delegates to `module_core`'s `SessionAbortService.abortSession` for the busy alert's
    Stop action.
- **What you see after sending.**
  - You stay where you are.
  - A popup alert says "Sending to <target>. <Source> is writing a summary first."
  - On the source page, the summarise prompt and its streaming reply appear as a normal turn. Nothing jumps, because
    it is the ordinary new-turn path.
  - When the bridge answers, a success alert says "Sent to <target>" with an **Open** action that opens the target. A
    failure alert gives the reason in plain words, for example "Couldn't send: the summary was stopped."
  - Alerts use the existing `PregoPopupAlertPresenter`. The presenter is captured before the request, so the alert
    still shows after the user leaves the page.
  - Whether to stay on the source or open the target at once is open question Q1.
- **Same computer.** This needs no filter, because the picker can only list the connected bridge's sessions. A
  computer switch during a send drops the response, and the client shows nothing more. The bridge still finishes.

### D9. Wire compatibility

New wire contracts, all additive:

- `SendToSessionRequest{sourceSessionId, targetSessionId}`.
- `SendToSessionErrorResponse{code, message}`, with a closed `SendToSessionErrorCode` enum and
  `@JsonKey(unknownEnumValue: SendToSessionErrorCode.unknown)`. The codes are:
  - `sameSession`
  - `sourceArchived`, `targetArchived`, `sourceNotRoot`
  - `sourceBusy`, `sourceAwaitingInput`, `sourceUnavailable`, `sourceEmpty`
  - `summaryStopped`, `summaryFailed`, `summaryTimedOut`, `summaryMissing`
  - `transcriptUnavailable`, `targetRefused`
  - `unknown`

How each pairing behaves:

| Pairing | Behaviour |
|---|---|
| New app, old bridge | The route is missing. The repository maps the 404 to `SendToSessionResult.unsupported`, with a `// COMPATIBILITY 2026-11-14 (v1.14.0): Bridges before session sending have no /session/send-to-session route. Remove the unsupported result once the minimum supported bridge has it.` comment, and the user sees the update alert. Nothing else breaks. |
| Old app, new bridge | The app never calls the route. A send started from another client looks like ordinary turns: a user prompt and reply in the source, and a user prompt in the target. |

No database or persisted-shape change.

### D10. Analytics

`session_sent_to_session` is recorded with the source harness kind and a closed outcome, following the decision's
"harness kind and outcome only".

- The outcome values are `sent`, `refused_busy`, `refused_other`, `failed`, `unsupported` and `unconfirmed`.
- It is reported from `SessionActionService.sendToSession` once the bridge's answer arrives. `ProductAnalyticsService`
  becomes a new dependency of that service.
- Follow the `add-analytics` skill checklist.

## Seams with the sibling plans

- **Side chat "Send to main session".**
  - It uses this feature with the side chat as the source and its main session as the target.
  - A side chat may not be a harness session. Claude `side_question` and Codex `thread/sample` are one-shot, so that
    plan owns how its summary and transcript are produced.
  - Steps 5–7 of D5 (render, store, prompt the target) are the reusable half. Keep them as a cohesive private method of
    `SessionSendService` now. Expose them when the side-chat plan needs them, not before.
- **Fork fallback.** It seeds a new session with earlier conversation text. `SessionTranscriptMarkdownBuilder` takes a
  plain message list, so the fork plan can pass the slice before the fork point. Any truncation option is added by
  that plan when it needs one.

## Complexity budget

- **New persistent state:** only the transcript files. There are no tables, columns or settings.
- **New in-memory parts, each living for one send:**
  - one event subscription (needed to see the echo and idle);
  - one subscription to the existing `abortStartedSessions` (stop means cancel);
  - one timeout timer (bounds a session that never goes idle);
  - local variables for the prompt id and user message id.
- **Client:** none. The menu awaits one request future.
- **Deliberately not added:**
  - an SSE outcome event, an in-flight send registry or a dedupe set (a double tap's second request hits the busy
    refusal, because step 3 checks and sends inside one source reservation);
  - recovery of an in-flight send after a bridge restart;
  - a hidden-turn mechanism or per-harness summarisers;
  - queueing until the source is idle;
  - an orphan-file sweep or a preview;
  - a capability flag on `GET /plugin` plus a client discovery cache (the missing-route 404 answers the tap instead);
  - a new abort stream (`abortStartedSessions` already exists).

### Safeguards and evidence

| Safeguard | Evidence |
|---|---|
| Busy-source refusal | Ordinary flow: sending from a running session. On ACP it would otherwise kill the turn. |
| Stop cancels the send | Ordinary flow. Without it, a half summary is delivered and can't be undone. |
| 15-minute bound | Theoretical stuck session. It costs one timer and keeps the request from hanging forever. |

**Accepted risks:**

- A bridge restart during the summary loses the send. The source keeps its summary turn and the user sends again.
- A client that disconnects gets no outcome. The target transcript shows the result.
- A failed folder deletion leaks a small local file. This is logged.
- The summary costs one source turn of tokens.

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
- No prompt or transcript text in logs.

```
1 ── 2 ── 3 ─┬─ 5 ── 6 ─┐
             └─ 4 ──────┴─ 7 ── 8
```

Step 4 needs only step 2's folder helper, but it ships after step 3 so the rule never lands without its feature. Steps
4 and 5 run in parallel. Steps 1 and 8 follow the docs-only PR rule. Step 7 also carries live checks, so it waits for
its normal review.

### Step 1: raise the plan

`🌱 [session-send] Raise the session sending plan [step 1/8]`

- **Complexity:** trivial. Documents only.
- **What:** adds `.plan/active/session-send/PLAN.md` and `TRACKER.md`.
- **Why:** pins the design before the bridge and client work starts.
- **Risk and test focus:** none. Check the diff is docs-only.
- **Expected result:** no user-visible or database change.

### Step 2: transcript Markdown and its file store

`⚙️ [session-send] Render a session transcript as Markdown and store it with the receiving session [step 2/8]`. About
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

`🚧 [session-send] Send one session into another from the bridge [step 3/8]`. About 1,450 lines, about 370 of them
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
- **Expected result:** with a new client, a send produces a summary turn in the source and a handoff prompt in the
  target, and writes a file under `~/.sesori/transcripts/`. Old clients see nothing new. No database change.

### Step 4: Claude reads the transcripts folder without asking

`🌿 [session-send] Let Claude Code read Sesori transcripts without a prompt [step 4/8]`. About 80 lines.

- **Complexity:** straightforward. One launch argument and its test.
- **What:**
  - the Claude plugin's composer resolves `sesoriTranscriptsDirectory()` once and passes the root into
    `ClaudeLaunchSpec` as a value;
  - the spec always adds the read rule for that root to `--allowedTools` (D7).
- **Why:** Claude asks before every read outside the working directory (verified on 2.1.319), and Claude is a primary
  target.
- **Risk and test focus:** low. Check that the existing granted rules are still passed, that the rule is read-only, and
  that a live Claude session reads a file there with no `can_use_tool` request.
- **Expected result:** a Claude target reads the transcript without an approval card. No database change.

### Step 5: the client send flow

`⚙️ [session-send] Send a session into another from its menu [step 5/8]`. About 1,250 lines including l10n output.

- **Complexity:** moderate. A new picker, menu wiring on four surfaces, and an async outcome.
- **What:**
  - adds `SessionApi.sendToSession` (16-minute timeout);
  - adds `SessionRepository.sendToSession`, which returns a sealed `SendToSessionResult`: sent, refused(code),
    failed(error), unsupported (missing route), or unconfirmed (timeout or lost connection);
  - adds `SessionActionService.sendToSession` and `SessionActionsCubit.sendToSession`;
  - adds `SessionActionsCubit.stopSession`, which delegates to `SessionAbortService.abortSession`;
  - gives `SessionSearchCubit` an `excludedSessionId`, and `SessionSearchMatch` an `isRunning` computed in
    `module_core` (D8);
  - adds the `SessionPicker`, the menu entry and the busy alert with Stop (D2);
  - adds the sending, success-with-Open, update-the-bridge and failure alerts (D8);
  - adds the `openSession` callback and the session-search cubit factory that both shells give
    `SessionListActionDispatcher`;
  - adds the strings.
- **Tests:** cubit and service tests for each result, and widget tests for the picker's exclusion and Running labels.
- **Visuals:** before-and-after screenshots of the menu and a short recording of a send, using fixture data only,
  hosted on `pr-media`.
- **Why:** this is the user-facing half.
- **Risk and test focus:** medium. Watch the menu on all four surfaces, sheet and popover transitions, alerts that show
  after leaving the page, and the desktop palette's search staying unchanged.
- **Expected result:** users see the entry and the picker, and get the agreed feedback. No database change.
- If the diff passes about 1,500 lines, split the picker into its own PR as step 5.a and update the series total.

### Step 6: analytics

`🌿 [session-send] Report sessions sent into another session [step 6/8]`. About 250 lines.

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

### Step 7: reconcile docs and harness rows

`🌿 [session-send] Document session sending and its harness differences [step 7/8]`

- **Complexity:** straightforward. Docs, plus live read checks.
- **What:**
  - adds `docs/regression/session-sending.md` and lists it in the README's Feature Index;
  - updates `docs/regression/session-archiving-and-deletion.md`: the transcript file is deleted with the target
    session and kept on archive;
  - adds a line to `docs/regression/projects-and-sessions.md` for the menu entry;
  - adds a "Sending a session into another" section to `docs/HARNESS_CAPABILITIES.md` (below).
- **Live check:** with the debug server, for every installed harness, check whether the target agent reads the file
  and whether it asks first. Mark runtimes that aren't installed as unverified.
- **Why:** these are the required feature and harness records.
- **Risk and test focus:** none in code. Check the docs against the live results.
- **Expected result:** no user-visible or database change.

### Step 8: verify and retire

`🌱 [session-send] Verify session sending and retire its plan [step 8/8]`

Run the matrix under Verification, record results in `TRACKER.md`, then move the plan to
`.plan/completed/session-send/`.

## Harness capability rows (step 7)

New section: "Sending a session into another", with the columns `Harness | Summary turn | Reads the transcript file |
Asks first`.

- **Summary turn: ✅ on every harness.** It goes through the normal prompt path. No harness offers a native merge, so
  Sesori builds it the same way everywhere.
- **Asks first:**

| Harness | Asks first |
|---|---|
| Claude | No, with step 4's rule |
| Codex, Pi, OMP, DeepSeek, Grok | No (expected from "Saved prompt files") |
| OpenCode | To check live; a stock config may ask through `external_directory` |
| Hermes, Cursor, Copilot, Antigravity | Unverified until checked live |

- **Notes:**
  - A busy source is refused in the bridge core for every harness. Readiness comes from session statuses and pending
    permissions and questions, which every plugin supplies.
  - A busy target follows "Transcript turn boundaries": ACP harnesses stop the running turn.

## Verification

Highest level: **L4.** L2 covers the main send, L3 a send across harnesses, and L4 the refusal, stop, failure and
per-harness read variants.

| Cell | Boundary | Plugins |
|---|---|---|
| Send from the session menu and from a list row, picker search, success alert, Open | Client end to end, iOS simulator | Claude source, Codex target |
| Send across harnesses, reversed | Client end to end, iOS simulator | Codex source, Claude target |
| Busy source: alert with Stop, then send | Client end to end, iOS simulator | Claude |
| Stop during the summary gives "summary was stopped", and the target receives nothing | Client end to end, iOS simulator | Claude |
| Old bridge (a build before step 3): picking a target shows the update alert | Client end to end, iOS simulator | Any |
| Target archived between the pick and the send, and session-error paths | Headless bridge with a fake plugin (automated) | None |
| Transcript file written, owner-only, deleted with the target, kept on archive | Headless bridge | Representative |
| The target reads the transcript file, and whether it asks | Live plugin | Every supporting production plugin; runtimes not installed are Blocked |

A reduction to this matrix needs the user's acceptance recorded here before retirement.

## Cleanup assessment

- No relevant cleanup was found. The feature adds a flow, and nothing it supersedes exists today.
- Readiness reuses the status and pending-request reads every plugin already supplies, so nothing is renamed.

## Risks

- **The relay may not hold a request for many minutes.** Step 3 checks this. The fallback is accept-then-SSE (D4).
- **The summarise prompt is visible** and costs a turn. Users may find it noisy. The later side-question path would
  address that.
- **A running ACP target has its turn stopped** (D3, Q2).
- **OpenCode and the unverified ACP harnesses may show one approval prompt** when the target reads the file.

## Later phases (rough)

- **Send without a summary**, for archived or unrestorable sources, a source whose plugin is down, and as a retry after
  a failed summary.
- **Remove the remaining read prompts** on any harness step 7 finds asking, starting with OpenCode, inside its plugin.
- **The side chat's "Send to main session"** (side-question plan) reuses the delivery half of `SessionSendService`.
- **The fork fallback** reuses `SessionTranscriptMarkdownBuilder` for its seed text.
- **A summary from the side-question primitives** (Claude `side_question`, Codex `thread/sample`), so the summary leaves
  no source transcript entry and works while the source is busy. Only if the visible turn proves annoying, since it
  breaks uniformity.
- **Sub-agent transcripts** inlined or linked in the Markdown file.
- **Warehouse reporting** for the send event.

## Open product questions

- **Q1. After sending, stay or jump?**
  - Default in this plan: stay on the source and show alerts, with Open on success.
  - Alternative: open the target at once and show a "receiving a summary" state there until it lands. That needs a new
    pending state in the target, and the target sits idle for the length of the summary.
- **Q2. Running ACP targets.**
  - Sending into a running Antigravity, Copilot, Cursor, DeepSeek, Grok or Hermes session stops its current turn, the
    same as typing a prompt there.
  - Default: allow it, with "Running" shown in the picker.
  - Alternative: refuse running ACP targets.
- **Q3. Claude's read rule for uploads.**
  - Step 4's rule could also cover `~/.sesori/uploads`, so files attached to prompts stop asking on Claude as well.
  - The earlier file-transfer decision (D1 there) left uploads asking unless the prompts proved annoying.
  - Default: transcripts only.

## Review record

Architecture plan review: see TRACKER.md.
