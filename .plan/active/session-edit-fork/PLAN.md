# Session Edit And Fork

## Status and goal

- **Slug:** `session-edit-fork`
- **Date:** 2026-11-14
- **Status:** Planned. Phase 1 is planned in detail; later phases are rough bullets only.
- **Issues:** #2497 (edit and resend an earlier user message), #2495 (message-level fork for Codex and Claude Code).
- **Product decisions:** final, from the user's session-branching review page (round 1, 2026-11-14), summarised under
  "Decisions" below. Side questions and merging are separate plans owned elsewhere; this plan only names the seams it
  shares with them.
- **Architecture review:** see "Review record" at the end.

Let a user edit one of their earlier messages and resend it, which removes every later message from the session
(conversation only, files untouched), and fork a session from a chosen message into a new session in the same worktree
or directory. Both actions live in a new long-press (touch) or right-click (pointer) menu on transcript messages, on
phone and desktop.

## Decisions

From the user (final):

1. **Rewind in place.** Editing an earlier message removes it and every later message from this session, then sends
   the edited message. It stays one session.
2. **Conversation only, on every harness.** Files are never touched. The edit banner says files stay as they are.
3. **Message menu.** Edit and fork live in the long-press (touch) or right-click (pointer) menu of messages, with no
   extra buttons in the chat. Own messages: "Edit and resend", "Fork from here", "Copy". Agent replies: "Fork from
   here", "Copy".
4. **The fork opens at once**, with a "Forked from <title>" line at the top that links back. Both sessions stay alive.
5. **Same worktree or directory.** Nothing is copied.
6. **Fallback for harnesses without native support:** a new session that starts with the earlier chat as text context
   (no tool memory) and says so. Where native rewind is missing, Edit becomes "a copy with your edit".

Decided without asking (not vetoed):

- Native support first for Claude Code, Codex, OpenCode and Pi; the others use the fallback. Gaps go in
  `docs/HARNESS_CAPABILITIES.md`.
- Edit and fork are offered only at user messages and finished agent replies, never inside a running turn. While a turn
  runs, Edit waits or offers Stop first.
- A fork remembers and shows its origin, and is a normal row in the session list.
- Analytics for edit and fork carry only the harness kind and the outcome.
- The user prefers simple, uniform behaviour on every harness over partial per-harness safety features.

Decided in this plan (implementation choices that follow from the decisions; open product questions are listed under
"Open questions" and get provisional defaults marked as such):

- **Edit points are turn-opening prompts.** A turn is what the shared `splitPromptTurns` rule
  (`shared/sesori_shared/lib/src/transcript/prompt_turns.dart`) says it is. Codex can only cut at turn boundaries, and
  the user prefers uniform behaviour, so "Edit and resend" is offered on the user message that opens a turn on every
  harness, never on a follow-up steered into a running turn. Claude could cut finer; it doesn't.
- **Fork points are finished turns.** "Fork from here" on any message of a finished turn keeps the conversation through
  the end of that turn (see open question 1 for the user-message case). Codex forks at turn granularity
  (`lastTurnId`); Claude can cut at any record but follows the same rule.
- **Phase 1 ships native edit and fork for Claude Code and Codex only.** Every other harness shows only "Copy" until
  phase 2 adds OpenCode, Pi and the text fallback.
- **The bridge owns the cut.** The client names a message id; the bridge validates it against its stored history with
  the shared turn rule and hands the plugin a precise boundary. Plugins never see turn segmentation and the client
  never sees native ids.
- **Busy sessions:** the bridge refuses an edit while the session runs (`409`, code `sessionBusy`). The client checks
  first and offers "Stop and resend" (see the UX section). A fork from an earlier finished turn while a later turn runs
  is allowed where the harness can do it; Codex and Claude both can.
- **Prompt defaults are copied to a fork; the per-session approval override is not.** YOLO-style approval is a safety
  setting the user set for one session, so the fork follows the bridge-wide setting until the user changes it.

## Harness verification (pinned versions in the repo, 2026-11-14)

Pins: Claude Code `targetVersion 2.1.322`, `minVersion 2.1.221`
(`bridge/sesori_plugin_claude/lib/src/runtime/claude_plugin_descriptor.dart:69-72`); Codex `targetVersion 0.167.2`,
`minPathVersion 0.139.0` (`bridge/sesori_plugin_codex/lib/src/runtime/codex_runtime_manifest.dart:29-32`); OpenCode
`targetVersion 2.2.7`, PATH minimum `1.14.0`, v2 minimum `2.0.11`
(`bridge/sesori_plugin_opencode/lib/src/runtime/open_code_runtime_manifest.dart:27-30`,
`open_code_runtime_policy.dart:24`); Pi `targetVersion 1.5.2` (`bridge/sesori_plugin_pi/lib/src/runtime/pi_runtime_manifest.dart:13`).
The research brief quoted older pins (Claude 2.1.310, Pi 1.4.0).

### Claude Code (2.1.322 target, 2.1.221 minimum; checked live on the 2.1.322 binary and in the bundled code)

- **`--resume-session-at=<uuid>`: verified.** It is hidden from `--help`, has existed since 1.0.125, and is present at the
  2.1.221 minimum. With `--resume`, it keeps the chain up to and including the record with that `uuid` (any chain
  entry) and drops the rest in memory. The file is not rewritten: the next record gets `parentUuid` = the kept entry, so
  the `.jsonl` becomes a tree, and a later plain `--resume` follows the newest leaf (live check: after cutting turn "two"
  and sending "three", the model remembered "one, three"). An unknown uuid fails with
  `No message found with message.uuid of: …`. The SDK documents the same option (`resumeSessionAt`, `sdk.d.ts:2190`),
  so it is a supported contract that the CLI only hides.
- There is no live control request for a conversation rewind (stream-json has `rewind_files` only), so a rewind
  respawns the session's process.
- `--resume-drops-turn=<uuid>` (a guard against cutting more than one turn) exists at 2.1.322 but not at 2.1.221
  (`unknown option`). The plan does not use it; the bridge already validates the cut. `--rewind-files` restores files
  and is never used (decision 2).
- **`--resume X --fork-session --session-id NEW --resume-session-at <uuid>`: verified.** It writes `NEW.jsonl` holding
  only the kept chain with the new `sessionId`, keeps record uuids and assistant `message.id`s, and leaves the origin
  untouched. `--session-id` is accepted with `--resume` only together with `--fork-session`, so Sesori chooses the
  fork's id up front as it does for new sessions. Not yet checked: whether the fork file is written before the first
  prompt (step 11 spike).
- **If the flag is removed,** the CLI fails at spawn with `unknown option`; the plugin turns that into
  `PluginBranchPointUnavailableException` ("This Claude Code version can't edit or fork from Sesori"). Replacements, in
  order: write the kept chain into a new file the way the SDK's documented `forkSession(sessionId, {upToMessageId})`
  does, or the phase-2 text fallback. The runtime refresh (`update-backend-runtimes`) gets a live check of both flags.
- **Design flag: Sesori's Claude transcript reader is linear.** `readTranscript` decodes every line in file order and
  the record DTO has no `parentUuid` (`claude_transcript_api.dart:172-176`, `claude_transcript_record_dto.dart:17-55`).
  After an in-place rewind it would show both branches. A rewind in the Claude Code terminal (Esc Esc) already produces
  such a tree today, so this is also a live bug. The reader must follow the active branch back from the leaf
  (`last-prompt` records carry `leafUuid`).
- **Ids:** a Sesori user message id is the record `uuid` (`claude_transcript_catalog_repository.dart:528-531`; live
  messages use the replayed uuid from `--replay-user-messages`). An assistant message id is the API `message.id`, which
  several records share (`claude_history_mapper.dart:67`). One long-lived process runs per session
  (`claude_launch_spec.dart:42-46`), started with `--session-id=` or `--resume=`.

### Codex (0.167.2, app-server JSON-RPC; source at tag `rust-v0.167.2`)

- **`thread/revert {threadId, beforeTurnId}`: verified.** Not experimental. "This only changes persisted conversation
  history. It does not revert local file changes." `beforeTurnId` is excluded together with every later turn. The
  server also sends `thread/reverted {threadId}`. Limits: the thread must be loaded in this app-server, must not be
  ephemeral, and must use paginated history (new threads do when the state DB exists; older rollouts migrate in the
  background at startup). A revert interrupts an active turn and reloads the thread, keeping subscriptions.
- **`thread/rollback` was removed** at 0.167.2 ("Use `thread/revert` for paginated threads instead"). It exists at the
  PATH minimum 0.139.0 (`{threadId, numTurns}`, history only), and Sesori already replays its rollout markers
  (`codex_message_repository.dart:62-147`).
- **`thread/fork`: partly as claimed.** `lastTurnId` is stable and inclusive (and must not be in progress);
  `beforeTurnId` is experimental, exclusive, and can't be combined with `lastTurnId`. The fork gets a new thread id and
  inherits the source's cwd. The source does not need to be loaded or idle. With a paginated source, `ephemeral` needs
  `excludeTurns: true`. Sesori already sends `experimentalApi: true` (`codex_app_server_client.dart:162`). At 0.139.0
  `thread/fork` has no turn parameter, so it can only fork the whole thread.
- **Design flag: Sesori's rollout reader cannot see a revert or a paginated fork.** Revert and paginated fork write a
  new rollout named `rollout-<ts>-<threadId>_<rolloutId>.jsonl` whose kept prefix is a reference
  (`session_meta.history_base = {thread_id (a rollout id), end_ordinal_exclusive, end_byte_offset}`), not a copy. The
  old file is kept. Sesori's file-name parser (`codex_catalog_repository.dart:468-475`) and rollout lookup
  (`codex_rollout_api.dart:147`) reject the new name, so after a revert Sesori would keep showing the old history and
  miss new turns, and a fork would show only its post-fork turns. Phase 1 must fix this before either feature ships.
- **Message ids:** Sesori exposes Codex item ids (user message item id, agent `itemId`), never turn ids. Turn ids are
  derivable (`item/*` notifications carry `turnId`; replay tracks `task_started.turn_id`; `thread/turns/list` returns
  `Turn{id, items[]}`). Legacy rollouts with replay-local `m-<n>` ids can't be mapped back.
- **One app-server process serves every session** (`codex_plugin_impl.dart:43,111`).

### OpenCode (2.2.7; v1 on PATH from 1.14.0) — phase 2

- v2 routes verified (present since 2.0.11; the brief's "2.1.4" is wrong): `POST /api/session/{id}/revert/stage
  {messageID, files?}`, `DELETE /api/session/{id}/revert`, `POST /api/session/{id}/revert/commit`,
  `POST /api/session/{id}/fork {before?}`. Neither Sesori allowlist (`tool/opencode_v2_surface.json`,
  `tool/opencode_v1_surface.json`) includes them yet.
- **Revert restores files by default.** v2 skips that only with `files: false`. v1 always restores files, so v1 can't
  use revert for a conversation-only rewind (fork, or `DELETE /session/:id/message/:messageID`, which Sesori already
  wraps, are the conversation-only options).
- A staged revert commits on the next prompt and deletes the boundary message and everything after it, so edit maps to
  "stage `{messageID, files: false}`, then send".
- Fork `before` (v2) and `messageID` (v1) are exclusive; the fork keeps the directory, is top-level, and gets new message
  ids.
- The unused `forkSession` the brief cites was removed on 2026-11-02 (commit 4168736ed9).
- OpenCode v1 is being sunset; phase 2 should not add v1-only machinery.

### Pi (1.5.2, RPC mode) — phase 2

- **No rewind command over RPC: verified, but Sesori's injected extension can rewind.** The RPC command switch has no
  tree navigation, but extension commands get `navigateTree`, and Sesori already loads its own extension
  (`pi_process_factory.dart:41`). A Sesori `/` command calling `ctx.navigateTree(<user entry id>)` moves the leaf to
  that entry's parent. The move is in memory only (on reopen the leaf is the file's last entry), so the edited prompt
  must be sent in the same process straight after.
- **`fork {entryId}`: verified, with caveats.** It accepts user-message entries only, writes a new session file with the
  root-to-parent path, keeps entry ids, picks a random session id Sesori can't choose, switches the running process to
  the new session, and returns no id (`get_state` has it). That clashes with Sesori's one process per session and
  chosen ids; spawning `--fork <parent> --session-id NEW` (which copies every branch) and then moving the leaf with the
  extension fits better. `get_fork_messages` lists user entries of every branch, not only the active one.
- **Ids:** Sesori's Pi message ids are synthetic (`pluginId:sessionId:role:timestamp:ordinal`,
  `pi_message_identity_builder.dart:86-92`), so the plugin needs a lookup back to entry ids. History already follows the
  active branch from the leaf (`pi_history_mapper.dart:500-532`).

## Current behaviour (what exists today)

- **No rewind or fork anywhere.** Sesori calls none of these harness operations; the only exception is Pi's
  whole-session `--fork` launch flag (`bridge/sesori_plugin_pi/lib/src/api/pi_launch_spec.dart:72-79`).
- **Plugin capabilities** are declared on the descriptor and mirrored into `PluginMetadata` in the plugin list
  (`supportsPromptAttachments`, `namesCommandInvocations`, `mcpScopes`):
  `BridgePluginDescriptor` getter → `bridge_runtime_runner.dart:~644` registration → `plugin_lifecycle_service.dart:~1164`
  → `shared/.../plugin_list_response.dart` `PluginMetadata`. Optional plugin operations are optional interfaces the
  plugin implements (`SessionExternalActionsPluginApi`, `PersistedSessionCleanupApi`, MCP interfaces), with the
  descriptor declaring what the started plugin implements (`mcpCapabilities`).
- **The client reads per-harness capabilities for a session** in `SessionDetailLoadService._loadPluginCapabilities`
  (`client/module_core/lib/src/services/session_detail_load_service.dart:~420`) from the session's `pluginId`.
- **Message ids** are whatever the plugin supplies; the bridge copies them unchanged
  (`bridge/app/lib/src/repositories/mappers/plugin_message_mapper.dart`). The bridge's history store
  (`history_messages`, keyed `(sessionId, messageId)` with a per-session `seq`) is what clients page through. A
  backfill replaces it wholesale from the harness snapshot (`ChatHistoryService._backfillSession` →
  `replaceSessionMessages`), inside the session's history write queue so later captures apply after it.
- **Removal reaches clients** as `SesoriMessageRemoved` (orchestrator `:1714` stores it; the client's
  `SessionDetailCubit._onMessageRemoved` filters it out with no animation). `TranscriptPresence` already has an exit
  animation (shrink, fade, slide; 200 ms), but list rows pass `exiting: false`
  (`client/module_app_ui/lib/src/features/session_detail/widgets/session_detail_message_list.dart:~1218-1230`).
- **Sessions:** `sessions_table` holds `sessionId`, `backendSessionId`, `projectId`, `parentSessionId` (sub-agent
  children only; cascades on delete), `directory`, `worktreePath`, `branchName`, `isDedicated`, `baseBranch`,
  `baseCommit`, prompt defaults, `title`/`catalogTitle`, `approvalOverride`. Schema version 23
  (`bridge/app/lib/src/api/database/database.dart:48`).
- **Shared worktrees are already safe on archive and delete.** Archive and delete send `deleteWorktree` for a session
  with a worktree. `SessionLifecycleService._cleanupRejection` refuses removal with `CleanupIssue.sharedWorktree()` when
  another non-archived session in the same project has the same `worktreePath`
  (`SessionDao.getOtherActiveSessionsSharing`), checked before the git safety check. The client's
  `SessionCleanupService._cleanUp` then retries at once with `deleteWorktree: false` and shows the
  "shared worktree kept" alert; a shared worktree mixed with any other issue becomes the ordinary refusal
  (`docs/regression/session-archiving-and-deletion.md` lines 61-65, 311-317). A "No project" session's own folder is
  kept on delete while any stored session still uses it (`ScratchRepository.deleteSessionDirectoryIfUnused`). A fork
  that copies its origin's `projectId` and `worktreePath` is therefore protected with no new code; the last of the two
  to be archived or deleted removes the worktree as today.
- **Client UI:** no long-press, right-click or context menu exists on messages; text is selectable through
  `PregoReadableSelectionArea` in both cards. The session row's menu is the pattern to reuse: `PregoAnchorMenu`
  (touch: `flat: true`, `spotlight: PregoMenuSpotlight.listRow`; pointer: secondary click at the pointer) wired through
  `GestureDetector(onSecondaryTap:)` and `InkWell(onLongPress:)`
  (`client/module_app_ui/lib/src/features/session_list/session_tile.dart:100-170`). Copy goes through
  `copyTextToClipboard`; the "Copy" string exists (`sessionDetailCopy`). The composer has a `header` slot
  (`prompt_input.dart:225`) the session composer leaves `null`; the new-session composer fills it with an animated
  banner (`new_session_view.dart:613`, `_AnimatedBanner`). Text is set programmatically only through the restoration
  mechanism (`saveComposerDraft` + `composerRestorations` + `initialDraft`). Nothing renders at the oldest edge of the
  transcript. Opening another session goes through `SessionDetailPresentationScope.openSession`.

## Design

### Plugin contract (`sesori_plugin_interface`)

- `enum PluginSessionBranching { rewind, fork }` in `lib/src/lifecycle/plugin_session_branching.dart`.
- `BridgePluginDescriptor.sessionBranching` getter, default `const {}`. Like `mcpCapabilities`, it must match the
  interfaces the started plugin implements and is readable while the plugin is dormant.
- Two optional interfaces, one per capability, because a harness can have one without the other (OpenCode v1 forks
  from a message but can only rewind by restoring files):

  ```dart
  /// Optional native rewind. Conversation only: an implementation never restores or edits files.
  abstract interface class SessionRewindPluginApi() {
    /// Removes [beforeMessageId] and every later message from [sessionId]'s conversation, then sends [parts] as the
    /// session's next prompt. Same acceptance, promptId and stale-options contract as `sendPrompt`. The bridge calls it
    /// only for an idle session and only with a message that opens a turn.
    Future<void> rewindAndSendPrompt({
      required String sessionId,
      required String beforeMessageId,
      required String promptId,
      required List<PluginPromptPart> parts,
      required PluginSessionVariant? variant,
      required bool fastMode,
      required String? agent,
      required ({String providerID, String modelID})? model,
    });
  }

  /// Optional native fork. The new session shares [sessionId]'s directory; nothing on disk is copied.
  abstract interface class SessionForkPluginApi() {
    /// Creates a backend session whose conversation is [sessionId]'s through [throughMessageId], inclusive, the last
    /// message of a finished turn. Returns it with its real directory, and emits `BridgeSseSessionCreated` for it the
    /// same way `createSession` does, so every client learns of the fork.
    Future<PluginSession> forkSession({required String sessionId, required String throughMessageId});
  }
  ```

  Rewind and resend are one plugin call because several harnesses apply a rewind only when the next prompt starts
  (Claude's resume point, OpenCode's staged revert); a separate "rewind now" call would leave those sessions in a state
  their transcript can't show.
- `PluginBranchPointUnavailableException({required String operation, required String? userFacingReason})`: the plugin
  cannot map the message to a native boundary (legacy ids, compacted history, a runtime too old for the operation). The
  reason is written for the user and must not carry transcript text.

### Bridge (`bridge/app`)

- **Capability publishing:** the descriptor's `sessionBranching` flows through the runtime registration and
  `PluginLifecycleService` into `PluginMetadata.sessionBranching`, like `namesCommandInvocations`. The enum mapping
  (`PluginSessionBranching` → `SessionBranchingOperation`) is a `toShared()` extension in
  `bridge/app/lib/src/repositories/mappers/plugin_to_shared_mapping.dart`; `PluginLifecycleService` only calls it.
- **Gating:** both operations are gated the same way, inside `SessionRepository`: within `use`/`useAndCommit` it
  pattern-matches the plugin against `SessionRewindPluginApi` or `SessionForkPluginApi` (the
  `_requirePersistedSessionCleanupApi` precedent), and a plugin that doesn't implement it becomes
  `branchPointUnavailable`. No runtime-side capability reader is added; the declaration only feeds the client.
- **Routes** (handlers in `bridge/app/lib/src/routing/`, request models in `sesori_shared`):
  - `POST /session/rewind`, a flat `RewindSessionRequest({sessionId, messageId, promptId, parts, agent, model, variant,
    fastMode})` (no command fields: an edit resends text, not a command), answers `SuccessEmptyResponse`.
    `RewindSessionHandler` → `SessionPromptService.rewindAndSendPrompt`.
  - `POST /session/fork`, `ForkSessionRequest({required String sessionId, required String messageId})`, answers the
    new `Session`. `ForkSessionHandler` → `SessionForkService.forkSession`.
  - Refusals of both routes use one new `SessionBranchErrorResponse({code: SessionBranchErrorCode, message})` with
    `{sessionBusy, branchPointUnavailable, staleSessionOptions, refused, unknown}` (`unknownEnumValue: unknown`);
    `branchPointUnavailable` carries the plugin's `userFacingReason` in `message`. `SendPromptErrorCode` is untouched.
    Archived sessions keep the shared archived rejection.
- **Edit flow** — `SessionPromptService.rewindAndSendPrompt` (same class as `sendPrompt`, because the edit is a send
  with a different plugin call; it reuses the accepted-prompt dedupe, attachment delivery, stale-options mapping and
  prompt-defaults update in `_sendPrompt`, whose `send` closure becomes the only difference). On the session lane
  (`SessionOperation.rewindSession`):
  1. require not archived; repeated `promptId` → succeed as before;
  2. refuse with `sessionBusy` when `SessionRepository.isSessionRunning`;
  3. `ChatHistoryService.removalForRewind({sessionId, messageId})` reads the stored history (backfilling first when the
     store is behind), checks with `splitPromptTurns` that `messageId` opens a prompt turn, and returns the ids of that
     message and every later stored message; otherwise `branchPointUnavailable`;
  4. `SessionRepository.rewindAndSendPrompt` calls the plugin through the `SessionRewindPluginApi` interface
     (`PluginBranchPointUnavailableException` → `branchPointUnavailable`);
  5. after acceptance, `SessionMutationDispatcher` publishes `SessionMessagesRewound({session, removedMessageIds})`.
     The orchestrator's `_mapLocalMutation` (widened to return a list of events) maps it to one
     `BridgeSseMessageRemoved` per id through the existing local-event pipeline, whose handler already calls
     `ChatHistoryService.captureMessageRemoved` inside the history write queue and fans `message.removed` out to every
     client. Removal is by exact id, never "everything after seq N", because the new prompt's own capture may already
     have landed.
  A later backfill must agree with the store, so each plugin's `getSessionMessages` must stop returning the removed
  messages; that is part of each plugin step.
- **Fork flow** — new `SessionForkService` (Layer 3, beside `SessionCreationService`, which it mirrors but which it
  doesn't belong in: it creates no worktree, sends no prompt and generates no title). Constructor:
  `SessionRepository`, `ChatHistoryService`, `ArchivedSessionValidator`, `SessionViewService`,
  `SessionOperationDispatcher`. It runs on the origin's lane as `SessionOperation.forkSession`:
  1. requires the origin routable and not archived (open question 4);
  2. `ChatHistoryService.forkBoundary({sessionId, messageId})` finds the prompt turn holding `messageId`, refuses a turn
     that is still running, and returns that turn's last stored message id;
  3. `SessionRepository.forkSession` calls `SessionForkPluginApi.forkSession` through `useAndCommit` and commits a new
     row copying the origin's `projectId`, `directory`, `worktreePath`, `branchName`, `isDedicated`, `baseBranch`,
     `baseCommit`, `lastAgent`, `lastAgentModel` and `fastMode`; `approvalOverride` stays null; `parentSessionId` stays
     null so it is a root row. A backend session that catalog import already bound keeps its row and gains the fork
     columns (same rule as `createSession`'s existing-binding branch);
  4. backfills the fork's history from the harness, so it opens with the kept turns;
  5. returns the `Session` enriched by `SessionViewService`; other clients learn of it from the `session.created` event
     the plugin contract requires.
- **Database (schema 24):** `sessions_table` gains `forkedFromSessionId TEXT NULL REFERENCES sessions_table(sessionId)
  ON DELETE SET NULL` and `forkedFromTitle TEXT NULL`, a snapshot of the origin's displayed title when the fork was
  made. The snapshot avoids a join on every session page; a later rename of the origin is not reflected (accepted: the
  line is a pointer, not live data). Deleting the origin nulls the id, so the line stays as plain text. No backfill:
  existing rows were never forked.
- **Wire:** `Session.forkedFrom: SessionForkOrigin?`, with
  `SessionForkOrigin({required String? sessionId, required String? title})`. Null on non-forks. `sessionId` null means
  the origin was deleted; `title` null means the origin was untitled. Old apps ignore the field and see an ordinary
  session.
- **Title of the fork:** provisional default "the origin's title" in the `title` column, pending open question 2. No
  generated title (the fork has no first message of its own).

### Client↔bridge compatibility

- `PluginMetadata.sessionBranching: Set<SessionBranchingOperation>` with
  `@JsonKey(unknownEnumValue: SessionBranchingOperation.unknown)` and an honest `@Default({})`:
  `// COMPATIBILITY 2026-11-14 (v1.14.0): Bridges before edit and fork omit sessionBranching, so their harnesses offer
  neither. Remove @Default once the minimum supported bridge sends it.`
- New app with an old bridge: the set is empty, the menu shows only "Copy", and the new routes are never called. An old
  bridge would answer them `404` anyway.
- Old app with a new bridge: the app never calls the routes, ignores `sessionBranching` and `forkedFrom`, and shows a
  fork as an ordinary session. It still receives `message.removed` when another device rewinds, which it already
  handles.
- `SessionBranchErrorResponse` is new and only answers the new routes, which older apps never call.

### Message-id mapping (each plugin, inside the plugin)

The client and bridge only pass the Sesori message id the plugin produced. Each plugin maps it:

| Plugin | Edit (`beforeMessageId`, a turn-opening user message) | Fork (`throughMessageId`, a turn's last message) |
|---|---|---|
| Claude Code | record `uuid` → respawn with `--resume=<id> --resume-session-at=<its parentUuid>`, then the prompt | `message.id` → the last chain record of that turn (the next user record's `parentUuid`, or the leaf) → `--resume --fork-session --session-id NEW --resume-session-at=<uuid>` |
| Codex | item id → its turn id (from live `turnId`, the replayed `task_started.turn_id`, or `thread/turns/list`); `thread/revert {beforeTurnId}` then `turn/start` | item id → its turn id; `thread/fork {lastTurnId}` |
| OpenCode (phase 2) | native `messageID`; v2 `revert/stage {messageID, files: false}` then the prompt | v2 `fork {before: <next message after the turn>}`, or no `before` when the turn is the last |
| Pi (phase 2) | synthetic id → entry id (plugin lookup); extension `navigateTree(entryId)`, then the prompt in the same process | the next turn's user entry; spawn `--fork <parent> --session-id NEW`, then move the leaf there with the extension (no move when the turn is the last) |

### Client UX

All shared UI lives in `client/module_app_ui/lib/src/features/session_detail/`; both shells compose it. Pointer and touch
differences go through `module_prego` interaction wrappers, never inline mode reads.

- **Message menu.** A new `TranscriptMessageMenu` wrapper (module_app_ui) around the user bubble and the agent reply
  card, built on `PregoAnchorMenu` like the session row. The touch/pointer trigger is a new named interaction wrapper in
  `module_prego/lib/interactions/` (long-press with a flat spotlit menu on touch, secondary click at the pointer), not
  the inline `PregoInteractionScope` reads `session_tile.dart` uses; moving the session row onto it is optional and
  removes that row's `pending` marker. Touch: long-press opens a flat menu with the pressed message
  spotlit (`PregoMenuSpotlight.listRow`) and a light haptic, the rest of the transcript blurred behind it. Pointer:
  right-click opens it at the pointer. Items:
  - own message that opens a finished turn: "Edit and resend", "Fork from here", "Copy";
  - own message inside a finished turn but not opening it (a steered follow-up): "Fork from here", "Copy";
  - the last agent reply of a finished turn: "Fork from here", "Copy";
  - any other agent message, and everything in the running turn: "Copy" only.
  - Edit and Fork appear only when the session's harness declares them and the session is not archived. Copy copies
    the message's markdown; on pointer with a text selection inside the message, it copies the selection.
  - Which actions a message gets is worked out in `module_core`, not in the widget: `cubits/session_detail/
    transcript_turns.dart` (which already applies `splitPromptTurns`) gives each message its branch actions in the
    loaded state, from the turn shape, the archived flag and `sessionBranching`, which
    `SessionDetailLoadService._loadPluginCapabilities` carries. The menu only renders the actions it is given.
  Whether long-press keeps selecting text is open question 3; provisional default: long-press opens the menu, and the
  menu adds "Select text", which enters the existing selection.
- **Edit mode.** "Edit and resend" puts the composer into edit mode:
  - the current draft is saved aside, and the message's text fills the composer through the restoration mechanism,
    with the caret at the end;
  - the composer's `header` slot shows an edit banner that grows in (size + fade, the `_AnimatedBanner` motion, reduced
    motion honoured): "Editing your message · Files stay as they are" and a Cancel button. Cancel, or Escape on pointer,
    shrinks the banner away and restores the saved draft;
  - the transcript does not move when edit mode starts. The edited bubble gets a subtle highlight so the reader sees
    which message the banner refers to;
  - Send runs the edit. On success the banner shrinks away and the saved draft comes back.
  - Attachments of the original message are open question 5; provisional default: text only, with a one-line note in
    the banner when the original had attachments.
- **Busy session.** If a turn is running when Send is pressed in edit mode, a popup offers "Stop and resend" and
  "Cancel". "Stop and resend" runs the ordinary Stop, waits for the idle status, then sends the edit; Cancel keeps edit
  mode and the text. The menu's "Edit and resend" itself is offered whenever the message opens a finished turn, also
  while a later turn runs. A `sessionBusy` refusal (another device started a turn) shows the same popup.
- **Removal motion.** Removed rows animate out instead of vanishing. The cubit just removes messages. The list
  widget (`session_detail_message_list.dart`, which already owns `enteringRowIds` and `_easedInRowIds`) compares its
  previous rows with the new ones, keeps a removed row as a leaving row with `exiting: true` on `TranscriptPresence`
  (the existing 200 ms shrink, fade and slide), and drops it in `onExited`. While the reader is detached, the widget's
  frozen snapshot must let removals through (today it only lets prepends and delivered prompts through). The rows the reader is on must not
  move: the edited message stays where it is while everything after it folds away beneath it, and only then does the
  new bubble arrive under it with the ordinary sent-bubble arrival; following resumes from there. The same path serves
  a rewind made on another device.
- **Fork.** "Fork from here" closes the menu with the ordinary exit motion and calls the fork route. When it answers,
  the fork opens with the platform's normal navigation transition: phone pushes the session-detail route; desktop
  selects it in the cockpit. If the answer takes longer than about 300 ms, the pressed message shows a small inline
  progress indicator so the tap is visibly answered; a failure shows the ordinary alert with the bridge's reason.
- **"Forked from" line.** A new synthetic row at the oldest edge of a forked session's transcript, shown once the oldest
  page is loaded: "Forked from <title>" (or "Forked from an untitled session"), styled as quiet metadata, tappable when
  `forkedFrom.sessionId` is not null. Tapping returns to the origin through a new shell-composed callback on
  `SessionDetailPresentationScope` (for example `returnToSession`), which each shell implements: back if the origin is
  the page below (phone) or the previous selection (desktop), otherwise open it, the pattern desktop's
  `onOpenParentSession` already follows. A deleted origin leaves the line as plain text.
- **Session list:** a fork is an ordinary root row; no new list UI.
- **Strings** are added to `app_en.arb` and its translations by the usual flow.

### Analytics

Use the `add-analytics` skill in each client step. Two closed events, both at the authoritative outcome (the bridge's
answer), from phone and desktop:

- `session_message_edited` with `harness` (`AnalyticsHarness`) and `outcome` (`succeeded`, `refused_busy`,
  `branch_point_unavailable`, `failed`);
- `session_forked` with `harness` and `outcome` (`succeeded`, `branch_point_unavailable`, `failed`).

Both widen the approved `harness` exception, which today covers only `session_message_sent` and
`session_created_with_message`; the user approved harness kind for these events, so the skill and
`docs/regression/analytics.md` record the widened list. Phase 2 adds a `mode` parameter (`native`, `text_copy`) when the
fallback lands.

### Shared seams with the other plans

- **Merge** writes a full-transcript Markdown file and sends a summary. Phase 2's text fallback needs a
  transcript-to-text renderer over normalized `MessageWithParts`. Whichever plan lands first puts that renderer in
  `sesori_shared` (`lib/src/transcript/`) as a pure function; the other reuses it.
- **Side questions** plan a "short-lived fork that is never listed" for harnesses without a native side question.
  `SessionForkPluginApi.forkSession` is not that: its fork persists in the harness and emits `session.created`, so
  catalog import would list it. A never-listed fork needs its own contract, which the side-question plan defines; it
  can reuse the plugins' turn-boundary mapping from this plan.

## Steps

Phase 1 is thirteen PRs. Titles use `<emoji> [session-edit-fork] <description> [step <x>/13]`.

### Step 1: raise the plan

`🌱 [session-edit-fork] Raise the session edit and fork plan [step 1/13]`. This file and `TRACKER.md`. Docs only.

### Step 2: message menu with Copy

`⚙️ [session-edit-fork] Add a long-press and right-click menu to transcript messages [step 2/13]`

- **What:** the `module_prego` context-menu interaction wrapper, and `TranscriptMessageMenu` on user bubbles and agent
  reply cards, phone and desktop, with only "Copy" (and "Select text" if open question 3 confirms it). Client only.
- **Why:** it is the surface both features need, it is useful alone, and it settles the long-press/selection feel before
  edit and fork depend on it.
- **Risk and test focus:** gesture conflicts with selection, the timestamp-peek drag, pinch-to-Prompts and code-block
  scrolling; the menu must not move the transcript. Widget tests for both interaction modes; a headless iOS simulator
  recording of long-press, menu, copy.
- **Expected result:** long-press or right-click on a message opens a menu that copies it. No database or wire change.
- **Estimate:** ~600 lines.

### Step 3: edit contract and bridge route

`🚧 [session-edit-fork] Add the bridge route that rewinds a session and resends an edited message [step 3/13]`

- **What:** `PluginSessionBranching`, `SessionRewindPluginApi`, `PluginBranchPointUnavailableException`; descriptor
  getter and its flow into `PluginMetadata.sessionBranching`; `RewindSessionRequest`; `RewindSessionHandler`; `SessionPromptService.rewindAndSendPrompt`;
  `ChatHistoryService.removalForRewind`; `SessionMessagesRewound` mutation and the list-returning
  `_mapLocalMutation`; `SessionBranchErrorResponse`; the `toShared()` capability mapping. No plugin declares `rewind` yet.
- **Why:** one backend-neutral path that both native plugins plug into.
- **Risk and test focus:** ordering between store removal and the new prompt's capture; idempotent retry by `promptId`;
  busy refusal; turn validation on partial stores; archived rejection. Bridge tests with a fake plugin implementing the
  interface.
- **Expected result:** no user-visible change; `PluginMetadata` gains an empty `sessionBranching` for every harness.
- **Estimate:** ~900 authored + ~300 generated.

### Step 4: Codex reads reverted and forked rollouts

`🚧 [session-edit-fork] Read Codex history across revert and fork rollouts [step 4/13]`

- **What:** teach the Codex plugin the `<threadId>_<rolloutId>` rollout names and `session_meta.history_base`, so
  history follows the kept prefix of a reverted or forked thread (resolving the base rollout in the sessions and
  archived-sessions folders). Starts with a live spike at 0.167.2 that pins the file naming and checks whether the
  background "migrate to paginated" pass already renames existing rollouts (if it does, that is a live bug today and
  this step fixes it for every user). If base rollouts can't be located reliably, read affected threads through
  `thread/turns/list` + `thread/items/list` instead. Owners: rollout-name parsing and reading a base prefix in
  `CodexRolloutApi` (Layer 1, no decisions); resolving which base to follow in `CodexCatalogRepository` and
  `CodexMessageRepository`; any `thread/*/list` wrappers in `CodexAppServerApi`.
- **Why:** without it, a Codex revert leaves Sesori showing the old history and a fork shows only its new turns.
- **Risk and test focus:** catalog import and history replay for ordinary, reverted, forked and sub-agent threads;
  fixtures recorded from the live spike.
- **Expected result:** no visible change for ordinary threads; reverted and forked threads read correctly.
- **Estimate:** ~800 lines.

### Step 5: Codex native edit

`⚙️ [session-edit-fork] Rewind and resend Codex sessions natively [step 5/13]`

- **What:** `CodexPluginImpl` implements `SessionRewindPluginApi` and only delegates. `thread/revert` gets a wrapper in
  `CodexAppServerApi`; item-to-turn mapping lives in `CodexMessageRepository`; `CodexSessionService` runs the sequence:
  make sure the thread is loaded (`thread/resume` when needed), `thread/revert {beforeTurnId}`, then the ordinary
  `turn/start` path with the same `promptId`. Declares `rewind`. A runtime without `thread/revert` (JSON-RPC method-not-found, e.g. the 0.139 PATH
  minimum) or an unmappable id throws `PluginBranchPointUnavailableException` with a reason such as "Update Codex to
  edit messages". `docs/HARNESS_CAPABILITIES.md` gets the edit row.
- **Risk and test focus:** paginated versus legacy threads; ephemeral threads refused; revert's reload not dropping
  subscriptions; history after revert agrees with the store. Live plugin check at the pinned version.
- **Expected result:** Codex sessions report `rewind`; a phone on step 3's bridge and a later client can use it.
- **Estimate:** ~600 lines.

### Step 6: Claude reads the active branch of a transcript

`🚧 [session-edit-fork] Read the active branch of Claude Code transcripts [step 6/13]`

- **What:** parse `parentUuid` (and `last-prompt.leafUuid`) in the Claude transcript record DTO;
  `ClaudeTranscriptApi.readTranscript` stays a raw record reader, and `ClaudeTranscriptCatalogRepository` builds history
  and catalog previews from the chain ending at the active leaf instead of every record in file order. Keep today's
  compaction and sidechain (sub-agent) behaviour.
- **Why:** an in-place rewind leaves the old branch in the file. A rewind in the Claude Code terminal already does, so
  this also fixes a live bug.
- **Risk and test focus:** leaf choice when no `last-prompt` record exists (newest record); compaction boundaries whose
  parent is null; sidechains; one pass over large files. Fixtures recorded live at 2.1.322.
- **Expected result:** no change for linear transcripts; branched ones show only the active branch.
- **Estimate:** ~600 lines.

### Step 7: Claude native edit

`🚧 [session-edit-fork] Rewind and resend Claude Code sessions natively [step 7/13]`

- **What:** `ClaudePluginImpl` implements `SessionRewindPluginApi` and only delegates: `ClaudeSessionService` runs the
  sequence and `ClaudeSessionProcessRepository` launches a new `ClaudeSessionLaunch` variant that resumes at a chain
  entry; the uuid → `parentUuid` lookup lives in `ClaudeTranscriptCatalogRepository`. Stop the session's idle process, respawn with `--resume=<id> --resume-session-at=<parentUuid of the
  edited user record>`, and send the prompt through the ordinary path with the same `promptId`. Later respawns use plain
  `--resume`, which follows the new leaf. Declares `rewind`. An unknown uuid, a first message with no earlier chain
  entry (open question 7) or an `unknown option` spawn failure → `PluginBranchPointUnavailableException`. Harness matrix
  row. Starts with a short live spike on the first-message case.
- **Risk and test focus:** the respawn racing the idle reaper or a pending permission; the respawn keeping model, agent
  and permission mode; history after the rewind agreeing with the store (step 6). Live plugin check at 2.1.322 and at
  the 2.1.221 minimum.
- **Expected result:** Claude Code sessions report `rewind`.
- **Estimate:** ~600 lines.

### Step 8: client edit flow

`🚧 [session-edit-fork] Edit and resend earlier messages from the transcript [step 8/13]`

- **What:** "Edit and resend" in the message menu; edit mode in `SessionDetailCubit` (it owns the composer draft and
  restorations, and a sibling cubit couldn't depend on it) with saved draft, banner, Cancel, and send through a new
  client `SessionRepository.rewindSession` → `SessionApi.rewindSession`; the busy popup, where "Stop and resend" is run
  by the cubit: `SessionAbortService` stop, wait for idle on its own status stream, then the rewind; removal exit motion for
  `message.removed` rows, including while detached; `session_message_edited` analytics.
- **Risk and test focus:** feel. No jump when entering edit mode, when rows fold away, or when the new bubble arrives;
  reduced motion; draft restoration; another device's rewind arriving mid-read. Cubit tests with fakes; widget tests;
  a headless iOS simulator recording of the whole edit, which goes in the PR body.
- **Expected result:** users of Claude and Codex sessions can edit an earlier message; later messages fold away and the
  new answer streams in. No database change.
- **Estimate:** ~1,300 lines.

### Step 9: fork contract, origin link and bridge route

`🚧 [session-edit-fork] Fork a session from a message on the bridge [step 9/13]`

- **What:** `SessionForkPluginApi`; `ForkSessionRequest`; `ForkSessionHandler`; `SessionForkService`;
  `ChatHistoryService.forkBoundary`; `SessionRepository.forkSession`; schema 24 with `forkedFromSessionId` and
  `forkedFromTitle`; `Session.forkedFrom` in `SessionCatalogMapper`. No plugin declares `fork` yet.
- **Risk and test focus:** the copied worktree fields (archive or delete of either session keeps the worktree while the
  other is live, then the last one removes it); origin deletion nulls the link; an already-imported backend binding;
  running-turn refusal. Drift migration test.
- **Expected result:** no user-visible change; sessions gain an always-null `forkedFrom`.
- **Estimate:** ~800 authored + Drift schema snapshot and steps (likely ~800 generated; report the split).

### Step 10: Codex native fork

`⚙️ [session-edit-fork] Fork Codex sessions from a turn [step 10/13]`

- **What:** `CodexPluginImpl` implements `SessionForkPluginApi` and delegates to `CodexSessionService`, which calls a
  new `CodexAppServerApi` `thread/fork {lastTurnId}` wrapper (not ephemeral) with the turn id from
  `CodexMessageRepository`, maps the new thread to a `PluginSession` in the same cwd, and emits `session.created`
  unless the spike shows `thread/started` already produces it. Declares `fork`; method-not-found on old runtimes →
  `PluginBranchPointUnavailableException`. Harness matrix row.
- **Risk and test focus:** the fork's history reads through step 4; the fork does not appear twice after catalog import;
  forking while a later turn runs.
- **Estimate:** ~500 lines.

### Step 11: Claude native fork

`🚧 [session-edit-fork] Fork Claude Code sessions from a message [step 11/13]`

- **What:** `ClaudePluginImpl` implements `SessionForkPluginApi` and delegates to `ClaudeSessionService` (the turn's
  last chain record comes from `ClaudeTranscriptCatalogRepository`): choose the new session id, launch `--resume=<origin> --fork-session --session-id=<new>
  --resume-session-at=<uuid>`, and return the `PluginSession` in the origin's directory. Declares `fork`. Starts with a
  spike: is `<new>.jsonl` written before the fork's first prompt? If not, the plugin writes the kept chain into the new
  file itself, the way the SDK's documented `forkSession` does, so the fork exists on disk at once and survives a bridge
  restart. Emits `BridgeSseSessionCreated` as `createSession` does. Harness matrix row.
- **Risk and test focus:** forking while a later origin turn runs; catalog import not listing the fork twice; deleting
  the fork removes only its own `.jsonl` (`PersistedSessionCleanupApi`); history of the fork shows only the kept chain.
- **Expected result:** Claude Code sessions report `fork`.
- **Estimate:** ~600 lines.

### Step 12: client fork flow

`⚙️ [session-edit-fork] Fork from a message and show where a fork came from [step 12/13]`

- **What:** "Fork from here" in the menu; `SessionDetailCubit` calls client `SessionRepository.forkSession` →
  `SessionApi.forkSession`, with inline progress after ~300 ms; the view navigates through
  `SessionDetailPresentationScope.openSession` and the new `returnToSession` callback each shell implements; the
  "Forked from" row at the oldest edge with its back-or-open behaviour; `session_forked` analytics.
- **Risk and test focus:** navigation stack on phone (origin → fork → origin must not pile up); desktop selection; the
  row only once the oldest page is loaded; feel of the transition. Headless iOS simulator recording in the PR body.
- **Expected result:** forking a Claude or Codex session opens the fork with the kept conversation and a working
  "Forked from" link.
- **Estimate:** ~900 lines.

### Step 13: reconcile docs, verify and retire

`🌱 [session-edit-fork] Reconcile edit and fork docs and retire the plan [step 13/13]`

The plan-maker lifecycle asks for the regression reconciliation and the verified retirement as the last two steps. They
are folded into one here because each feature step already updates its regression and harness rows; if reconciliation
finds more than small fixes, split this into 13.a (docs) and 13.b (run and retire).

- Reconcile the regression documents listed below, run the verification matrix, record the result in `TRACKER.md`, and
  move the plan to `.plan/completed/session-edit-fork/` only when the matrix passes.

## Regression documents

- **New:** `docs/regression/session-edit-and-fork.md` (capability, required behaviour, levels), added in step 3 and
  completed in steps 8 and 12.
- **Update:** `docs/regression/session-archiving-and-deletion.md` (a fork shares its origin's worktree: archive or
  delete of either keeps it for the other), `docs/regression/transcript-turn-navigation.md` (edit points are
  turn-opening prompts; removed rows fold away without moving the rows being read), `docs/regression/session-turns.md`
  (an edit sends through the same prompt identity and refusals), `docs/regression/projects-and-sessions.md` (a fork is
  an ordinary root row), `docs/regression/analytics.md` (two new events, widened harness exception),
  `docs/regression/session-history-and-recovery.md` (Codex history across revert and fork rollouts; Claude history
  follows the active branch of a rewound transcript).

## `docs/HARNESS_CAPABILITIES.md` rows

A new "Edit and fork" section with one row per registered harness and two capability columns, "Edit and resend
(rewind in place)" and "Fork from a message":

| Harness | Edit and resend | Fork from a message |
|---|---|---|
| Claude Code | ✅ after step 7 | ✅ after step 11 |
| Codex | ✅ after step 5 (needs `thread/revert`; older PATH runtimes refuse with a reason) | ✅ after step 10 (needs `thread/fork lastTurnId`) |
| OpenCode | ⬜ (v2 `revert/stage files:false`); v1 🚫 conversation-only revert | ⬜ (v2 `fork before`) |
| Pi | ⬜ (no RPC command; Sesori extension `navigateTree` + prompt) | ⬜ (`--fork` + leaf move) |
| Oh My Pi | ⬜ text copy (phase 2) | ⬜ text copy (phase 2) |
| Antigravity, Copilot, Cursor, DeepSeek, Grok, Hermes | ⬜ text copy (phase 2) | ⬜ text copy (phase 2) |

The ACP harnesses were not checked for native message-level rewind or fork in this plan; phase 2 checks each before
choosing the text copy, and marks 🚫 only what it verifies. Footnotes name the verified versions. Phase 2 adds a "text copy" column state when the fallback lands.

## Verification

Highest level: **L3 release** for the delivered behaviour, through these boundaries:

| Boundary | Claim | Matrix |
|---|---|---|
| Automated | turn validation, store removal ordering, fork row copy, migration, capability mapping, cubit edit state, menu items per message kind | — |
| Live plugin | native rewind and fork at the pinned versions, history after each agrees with the store, files untouched | Claude Code 2.1.322, Codex 0.167.2; a refusal check on Codex 0.139.0 and Claude at `minVersion` if it lacks the flag |
| Client end to end | menu, edit banner, busy popup, removal motion, fork navigation, "Forked from" link, archive/delete of a forked pair | headless iOS simulator (phone) and desktop macOS, each against Claude Code and Codex |
| Relay integration | a second client sees removed rows fold away and the fork appear | one plugin (representative) |

Per the user's testing rule, phone cells run only on a headless iOS simulator (`xcrun simctl boot`, no Simulator.app) on
the device the local testing setup assigns. Desktop is in the matrix because the right-click menu is desktop-specific.

## Complexity budget

New persistent state: two nullable columns (`forkedFromSessionId`, `forkedFromTitle`). New wire state: one capability
set, two request models, one error response, one nullable session field. New in-memory state: the client's edit-mode
draft (one saved draft and one target message id) and a set of leaving row ids during the exit motion.
Plugin state: none new in Codex (turn ids are read from history); Claude gains one launch variant.

Deliberately not added: no file snapshots or restore; no per-harness safety prompts; no queued edits that wait for a
turn to end (Stop and resend instead); no cut inside a turn; no join for the origin's live title; no new worktree
reference counting (the existing shared-worktree rule covers it); no plugin-side turn segmentation.

## Cleanup assessment

No existing code becomes obsolete. The Pi `--fork` launch flag stays (it serves session restore, not this feature).

## Risks

- **Claude's flag is undocumented** (see the Claude section): a removal would turn Claude edit and fork into
  branch-point refusals until the fallback or a replacement lands. The plugin's tests pin the flags' presence at the
  target version so a runtime refresh notices.
- **Codex rollout format drift**: step 4 depends on unstable on-disk details; its live fixtures guard runtime refreshes.
- **Feel of removal**: removing rows below a detached reader in a reversed list is the riskiest motion; step 8 needs a
  recording before it is called done.

## Open questions (for the user; provisional defaults are used until answered)

1. **"Fork from here" on your own message:** should the fork include that message and the agent's replies to it
   (provisional), or stop just before it and put its text in the fork's composer, ready to change?
2. **Fork title:** the same title as the original (provisional), the title with "(fork)" added, or a new title written
   by the agent?
3. **Long-press and text selection:** today a long-press selects text in a message. Should long-press open the new
   menu with a "Select text" item (provisional), or should the menu need some other gesture on phones?
4. **Archived sessions:** should "Fork from here" work on an archived session, as a way to pick an old conversation up
   again? Provisional: no, archived sessions only offer "Copy".
5. **Attachments:** when you edit a message that had images or files, should they be sent again with the edited text?
   Provisional: text only, and the edit banner says the attachments are not included.
6. **Follow-ups sent while the agent was working:** they belong to the running turn, so "Edit and resend" is not
   offered on them (only "Fork from here" and "Copy"). Is that acceptable, or should Edit there cut at the start of the
   whole turn?
7. **The first message of a Claude Code session** may not be editable in place (to be confirmed in step 7). If it isn't,
   should Edit there say it can't, or start a new session with the edited message (linked as "Forked from")?

## Later phases (rough)

- **Phase 2 — OpenCode and Pi native.** OpenCode v2 edit through `revert/stage {files: false}` + prompt and fork through
  `fork {before}`; add the routes to the v2 surface allowlist. Pi edit through a Sesori extension command that moves the leaf
  (`navigateTree`) and sends in the same process; Pi fork by spawning `--fork` and moving the leaf. Why: the two other harnesses the user named for native support.
- **Phase 2 — text fallback.** Bridge-owned: a new session seeded with the earlier conversation as text (no tool memory),
  labelled as such, for every harness without native support, and Edit as "a copy with your edit" where rewind is
  missing. Shares the transcript renderer with the merge plan. Why: parity across harnesses (decision 6).
- **Later — whole-session ACP forks** where a harness grows message-level fork or rewind over ACP; re-check on runtime
  refreshes. Why: replace the fallback with native behaviour when it becomes possible.

## Review record

- 2026-11-14, `architecture-plan-review` (opus sub-agent): rejected with 13 findings, all applied directly: one removal
  path through the existing local-event pipeline; removal animation owned by the list widget; named layer owners in
  every plugin step; capability mapping as a Layer 2 `toShared()`; uniform gating in `SessionRepository` with no
  runtime reader; per-message actions derived in `module_core`; edit mode and Stop-and-resend owned by
  `SessionDetailCubit`; a `module_prego` interaction wrapper for the menu; a shell-composed `returnToSession`; a flat
  rewind request and a shared `SessionBranchErrorResponse`; the fork contract emits `session.created`; the
  `SessionForkService` constructor and lane; the side-question seam corrected.
