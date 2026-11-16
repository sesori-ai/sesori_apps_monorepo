# Session Edit And Fork

## Status and goal

- **Slug:** `session-edit-fork`
- **Date:** 2026-11-14
- **Status:** Planned. Phase 1 is planned in detail; later phases are rough bullets only.
- **Issues:** #2497 (edit and resend an earlier user message), #2495 (message-level fork for Codex and Claude Code).
- **Product decisions:** final, from the user's session-branching review pages (round 1, 2026-11-14; round 2,
  2026-11-15), summarised under "Decisions" below. Side questions and merging are separate plans owned elsewhere; this
  plan only names the seams it shares with them.
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
   here", "Copy". Long-press opens the menu, and "Select text" is one of its items (round 2, E3).
4. **The fork opens at once**, with a "Forked from <title>" line at the top that links back. Both sessions stay alive.
5. **Same worktree or directory.** Nothing is copied.
6. **Fallback for harnesses without native support:** a new session that starts with the earlier chat as text context
   (no tool memory) and says so. Where native rewind is missing, Edit becomes "a copy with your edit".

From the user, round 2 (final):

7. **"Fork from here" on your own message is "edit as fork" (E1).** The fork starts just before that message, and the
   message's text and attachments wait in the fork's composer. On an agent reply the fork starts after that reply.
8. **Fork is also in the session's ⋯ menu (E1 note).** It forks after the latest finished reply, and it is there on
   archived sessions too.
9. **The fork's title is the original title plus " (fork)" (E2).**
10. **Archived sessions can be forked (E4).**
11. **Editing brings the message's attachments back into the composer (E5)**, where each can be removed before sending.
12. **Follow-ups sent mid-turn show Edit (E6).** A tap explains that a message sent while the agent was working can't be
    edited, and offers Fork. Editing them in place on Claude Code, OpenCode and Pi, which can cut at a single message,
    is a later phase; Codex can't, because it cuts only between whole turns.
13. **Fork and replace (E7, the user's idea).** The bridge keeps its own `sessionId` apart from the harness's
    `backendSessionId`, so an edit can swap the harness session under the same Sesori session: create a new or forked
    harness session, point the row at it, then stop and delete the old harness session. It serves an edit of a
    session's first message and Pi's edit in place, instead of the copy fallback. Which harnesses use it is decided in
    "Edit mechanism" below.

From the user, round 4 (final):

14. **Forking an archived session whose worktree was removed recreates it.** The fork gets a fresh worktree on the kept
    branch, with its files as last committed. If the branch is gone too, the fork asks for a new worktree from the base
    branch. Its own PR (step 11.b), about 300 to 400 lines.
15. **"Fork from here" on a follow-up sent mid-turn keeps that whole turn** and puts the follow-up's text and
    attachments in the fork's composer (round 4's decided list; not vetoed).

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
  the user prefers uniform behaviour, so an edit runs only on the user message that opens a turn, on every harness.
  On a follow-up steered into a running turn, "Edit and resend" answers with the decision-12 explanation and its Fork
  action. Claude could cut finer; in phase 1 it doesn't.
- **Fork points are turn boundaries.** On an agent reply of a finished turn, the fork keeps the conversation through
  the end of that turn. On a user message that opens a turn, the fork keeps everything before that turn (decision 7);
  on the session's first message that is nothing, so the fork is an empty session in the same directory. On a
  follow-up sent mid-turn see decision 15. Codex forks at turn granularity (`lastTurnId`); Claude can cut at any
  record but follows the same rule. The ⋯ menu forks after the latest finished turn.
- **Edit mechanism: native rewind, plus a harness-session swap only where there is nothing to rewind to or no rewind.**
  The user asked whether fork-and-replace should be the single edit mechanism on every harness that can fork at a
  point. It should not, for reasons in the code:
  - **Codex:** a paginated `thread/fork` stores its kept prefix as a reference to the source rollout
    (`session_meta.history_base`), not a copy. The swap's "delete the old harness session" would delete the rollout the
    new thread reads from (`CodexPluginImpl.deleteSession` deletes the rollout file and its `session_index.jsonl`
    entry), so the old thread would have to stay on disk anyway. `thread/revert` keeps one thread id and needs no swap.
  - **OpenCode:** a fork gives every kept message a new id, so the client would see the whole kept conversation removed
    and re-added. `revert/stage {files: false}` keeps the ids.
  - **Claude Code:** `--resume-session-at` keeps one `.jsonl` with its sub-agent sidechains. A fork-and-replace at a
    later message would have to carry the sidechains the kept turns link to into the new session, or lose them when
    the old session is deleted; that is unverified extra work. The active-branch reader (step 7) is needed anyway for
    the live terminal-rewind bug.
  - **The swap is still the one path for an edit of a session's first message, on every harness.** There is nothing
    to keep, so the bridge creates a fresh harness session with the edited prompt through the existing
    `createSession`, which every plugin has. This replaces the Claude "first message" spike and the copy fallback the
    round-2 question offered, and it means `rewindAndSendPrompt` is never called for a first turn.
  - **Pi (phase 2) uses the swap for every edit**: it can fork but not rewind, and its RPC `fork {entryId}` already
    switches the running process to the new session file, which is exactly a swap.
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
  prompt (step 13 spike).
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
  - `POST /session/fork`, `ForkSessionRequest({required String sessionId, required ForkPoint point})`, answers the
    new `Session`. `ForkPoint` is a sealed union: `afterMessage(messageId)` (an agent reply), `beforeMessage(messageId)`
    (your own message, decision 7) and `latest()` (the ⋯ menu, decision 8). `ForkSessionHandler` →
    `SessionForkService.forkSession`.
  - Refusals of both routes use one new `SessionBranchErrorResponse({code: SessionBranchErrorCode, message})` with
    `{sessionBusy, branchPointUnavailable, nothingToFork, staleSessionOptions, refused, unknown}`
    (`unknownEnumValue: unknown`); `branchPointUnavailable` carries the plugin's `userFacingReason` in `message`.
    `nothingToFork` answers `ForkPoint.latest()` on a session with no finished turn, and the client shows its own
    localised "Nothing to fork yet" for it. `SendPromptErrorCode` is untouched.
    An edit of an archived session keeps the shared archived rejection; a fork of one is allowed (decision 10).
- **Edit flow** — `SessionPromptService.rewindAndSendPrompt` (same class as `sendPrompt`, because the edit is a send
  with a different plugin call; it reuses the accepted-prompt dedupe, attachment delivery, stale-options mapping and
  prompt-defaults update in `_sendPrompt`, whose `send` closure becomes the only difference). Its constructor gains
  `ChatHistoryService` (the removal ids, the swap's child-history purge and the empty-fork first-send check);
  `ChatHistoryService` does not depend on `SessionPromptService`, so no cycle forms. On the session lane
  (`SessionOperation.rewindSession`):
  1. require not archived; repeated `promptId` → succeed as before;
  2. refuse with `sessionBusy` when `SessionRepository.isSessionRunning`;
  3. `ChatHistoryService.removalForRewind({sessionId, messageId})` reads the stored history (backfilling first when the
     store is behind), checks with `splitPromptTurns` that `messageId` opens a prompt turn, and returns the ids of that
     message and every later stored message; otherwise `branchPointUnavailable`;
  4. when the message opens the session's first turn, the edit becomes a harness-session swap (see "Harness-session
     swap" below). Otherwise `SessionRepository.rewindAndSendPrompt` calls the plugin through the
     `SessionRewindPluginApi` interface (`PluginBranchPointUnavailableException` → `branchPointUnavailable`);
  5. after acceptance, `SessionMutationDispatcher` publishes `SessionMessagesRewound({session, removedMessageIds})`.
     The orchestrator's `_mapLocalMutation` (widened to return a list of events) maps it to one
     `BridgeSseMessageRemoved` per id through the existing local-event pipeline, whose handler already calls
     `ChatHistoryService.captureMessageRemoved` inside the history write queue and fans `message.removed` out to every
     client. Removal is by exact id, never "everything after seq N", because the new prompt's own capture may already
     have landed.
  A later backfill must agree with the store, so each plugin's `getSessionMessages` must stop returning the removed
  messages; that is part of each plugin step.
  An edited message's attachments arrive as ordinary prompt parts (see "Edit mode"), so the edit route needs no
  attachment field of its own.
- **Harness-session swap** — `SessionRepository.replaceBackendSession`, used in phase 1 only for an edit of the first
  turn, on the session lane inside the same `rewindSession` operation. What keys on `backendSessionId` today, and how
  the swap treats it:
  - **`sessions_table` and the unique index `idx_sessions_plugin_backend (pluginId, backendSessionId)`.** The swap runs
    `_runtime.useAndCommit` like `createSession`: `prepare` calls `plugin.createSession(directory, parts: <the parts
    SessionPromptService passes in>)` on the row's directory, and `commit` updates the existing row's `backendSessionId` in one transaction
    instead of inserting a row. If catalog import already bound the new backend id to a row of its own (the
    `existingBinding` case `createSession` handles), that row is an import of this very replacement: the transaction
    deletes it before rebinding, so the unique index holds.
  - **The event tracker (`SessionEventTracker`, keyed `(pluginId, backendSessionId)`).** The new session's
    `session.created` and its first-prompt events are held as pending events for the binding generation, exactly as
    for a created session, and are released onto the existing Sesori id when the commit publishes the binding
    (`_publishBindingsCommitted` with a new `SessionBindingCommitKind.sessionReplacement`). So status, message and
    permission events of the new harness session reach clients under the same session id.
  - **The old harness session.** After the commit, the bridge deletes it the way session deletion does: tombstone
    every old backend id of the root and its sub-agent subtree in `deleted_sessions_table` and the in-memory tombstone
    set (so catalog import and startup reconciliation never bring the old session back), delete the old sub-agent
    child rows, then call `plugin.deleteSession(<old backend id>)`, which clears the plugin's own per-session caches
    (Claude's process and `_createdSessions`, Codex's turn and approval maps). Its `session.deleted` event names a
    backend id that no row binds any more, so it removes nothing. A failed backend delete is logged and left to
    startup reconciliation through the tombstone; the edit still succeeds. The tombstone-and-row-removal code is
    one private helper (`_tombstoneSubtree`) that `deleteSession` and `replaceBackendSession` share, not a second
    copy. Each keeps its own `plugin.deleteSession` call: a delete runs it first and tolerates an unreachable plugin,
    the swap runs it after the commit and only logs a failure.
    `replaceBackendSession` returns the removed child session ids, and `SessionPromptService` purges their history
    through `ChatHistoryService.purgeSessionsHistory`, the way `SessionDeletionService` coordinates the two stores
    (`SessionRepository` owns no history dependency).
  - **History, uploads and every other session-owned table** (`history_messages`, continuations, side chats, handoff
    markers, `~/.sesori/uploads/<sessionId>/`) are keyed by the Sesori `sessionId`, which does not change. The old
    messages are removed by exact id through the same `SessionMessagesRewound` path as a rewind.
  - **Clients** never see a backend id (no shared or client model carries one). They see the same session, its messages
    folding away, and the new prompt arriving: one continuous session.
  - **Worktree context.** A new session's first prompt carries the bridge's worktree context part
    (`buildWorktreeSystemContext`, which the message mapper strips before clients see it). The swap's first prompt is a
    new first prompt, so it carries the same part. `SessionPromptService` decides this and builds the parts (one
    private builder over `buildWorktreeSystemContext`, also used for an empty fork's first send); the repository only
    forwards the parts it is given.
- **Fork flow** — new `SessionForkService` (Layer 3, beside `SessionCreationService`, which it mirrors but which it
  doesn't belong in: it creates no new worktree (it only recreates an archived origin's removed one, step 11.b), sends no prompt and generates no title). Constructor:
  `SessionRepository`, `ChatHistoryService`, `WorktreeRepository`, `SessionViewService`,
  `SessionOperationDispatcher`. No `ArchivedSessionValidator`: archived origins are allowed, so nothing here refuses
  them. It runs on the origin's lane as `SessionOperation.forkSession`:
  1. requires the origin routable and a root session. An archived origin is allowed (decision 10): the fork reads the
     origin and never mutates it, so the archived read-only rule is not broken. Archive keeps the harness session (Claude
     and Codex archive only cancel pending approvals; `CodexPluginImpl.archiveSession` leaves the rollout in place), so
     a native fork works. An archived origin whose harness no longer has the session (Claude Code prunes transcripts
     after its `cleanupPeriodDays`, 30 days by default; the plugin reports it as
     `PluginBranchPointUnavailableException`) is refused with `branchPointUnavailable` and a plain reason until the
     phase-2 text copy. An archived origin whose dedicated worktree was removed at archive gets it recreated
     (decision 14, step 11.b): `SessionForkService` checks `WorktreeRepository.worktreeExists({path})` over
     `FilesystemApi` for an archived origin with a `worktreePath`, and when it is missing asks `WorktreeRepository` to
     add a worktree at the same path, so the harness session's cwd and the agent's remembered paths still hold and the
     files are as last committed. Archiving keeps that point: before it removes a dedicated worktree it records the
     branch HEAD is on in `branchName` (null when detached) on every row naming the worktree, and pins the HEAD commit
     under `refs/sesori/worktrees/<path hash>` so gc keeps detached work; deleting the last row naming the worktree
     deletes the ref. Recreation checks out `branchName` when it exists, else starts at the pinned HEAD (on a new
     `branchName`, or detached). Only a worktree that kept nothing (removed by an older bridge, branch gone) answers a
     new `SessionBranchErrorCode.worktreeBranchMissing`; the client offers "Create a new worktree from <base branch>",
     and the retry (`ForkSessionRequest.recreateFromBase: true`) starts it at `baseCommit` (`baseBranch` for rows
     without one) at the same path. A path now taken by something else, or a failed add, is refused with `refused`
     and a plain reason. The fork row copies the recreated path like any
     other; the archived origin doesn't count as a sharer, so archiving or deleting the fork removes the worktree as for
     any dedicated session;
  2. `ChatHistoryService.forkBoundary({sessionId, point})` reads the stored history (the archive audit record for an
     archived origin) and returns either `throughMessage(id)`, the last stored message of the kept turn, or `empty`
     when nothing is kept. `point` is the request's `ForkPoint`: `afterMessage(id)` keeps through the end of the
     finished turn holding the message; `beforeMessage(id)` keeps everything before the turn that the message opens;
     `latest()` keeps through the latest finished turn, and a session with no finished turn answers `nothingToFork`
     (`empty` comes only from `beforeMessage` on the first turn). `afterMessage` on a follow-up sent mid-turn keeps
     through the end of the finished turn holding it (decision 15). A turn that is still
     running is refused;
  3. `SessionRepository.forkSession` creates the backend session through `useAndCommit`: for `throughMessage` it calls
     `SessionForkPluginApi.forkSession`; for `empty` it calls the existing `plugin.createSession(directory, parts: [])`,
     which every plugin supports as an unstarted session. It commits a new row copying the origin's `projectId`,
     `directory`, `worktreePath`, `branchName`, `isDedicated`, `baseBranch`, `baseCommit`, `lastAgent`,
     `lastAgentModel` and `fastMode`; `approvalOverride` stays null; `parentSessionId` stays null so it is a root row.
     `SessionForkService` decides the title and passes `title` and `forkedFromTitle` in: the origin's displayed title
     plus " (fork)" (decision 9), or null for an untitled origin, whose fork stays untitled until its harness
     names it, as a new session does. A backend session that catalog import already bound keeps its row and gains the
     fork columns (same rule as `createSession`'s existing-binding branch). The commit publishes
     `SessionBindingCommitKind.sessionCreation`, so the fork's held `session.created` and first events are released
     onto its new id and the options refresh listener runs, as for any created session;
  4. backfills the fork's history from the harness, so it opens with the kept turns;
  5. returns the `Session` enriched by `SessionViewService`; other clients learn of it from the `session.created` event
     the plugin contract requires.
  An empty fork of a session with a worktree has had no first prompt yet, so its first send carries the worktree
  context part, as a new session's does: `SessionPromptService` adds it when the session has a worktree and no stored
  messages. That is the only new rule on the ordinary send path.
- **Database (schema 24):** `sessions_table` gains `forkedFromSessionId TEXT NULL REFERENCES sessions_table(sessionId)
  ON DELETE SET NULL` and `forkedFromTitle TEXT NULL`, a snapshot of the origin's displayed title when the fork was
  made. The snapshot avoids a join on every session page; a later rename of the origin is not reflected (accepted: the
  line is a pointer, not live data). Deleting the origin nulls the id, so the line stays as plain text. No backfill:
  existing rows were never forked.
- **Wire:** `Session.forkedFrom: SessionForkOrigin?`, with
  `SessionForkOrigin({required String? sessionId, required String? title})`. Null on non-forks. `sessionId` null means
  the origin was deleted; `title` null means the origin was untitled. Old apps ignore the field and see an ordinary
  session.
- **Title of the fork:** the origin's title plus " (fork)" in the `title` column (decision 9). The suffix is written by
  the bridge, like any stored title, so it is not localised.
- **Schema version.** This plan, the side-question plan and the session-send plan each add a migration. Each takes the
  next free version when it is implemented; the "24" here is only the version at planning time.

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
| Pi (phase 2) | swap: synthetic id → entry id (plugin lookup); RPC `fork {entryId}` writes the root-to-parent path as a new session file and switches the process to it; the plugin reads the new id from `get_state`, the bridge rebinds, then the prompt | the next turn's user entry; the same fork, but in a new process for the new Sesori session |

The first-turn edit is not in the table: on every harness it is the bridge's swap with a fresh `createSession`.

### Client UX

All shared UI lives in `client/module_app_ui/lib/src/features/session_detail/`; both shells compose it. Pointer and touch
differences go through `module_prego` interaction wrappers, never inline mode reads.

- **Message menu.** A new `TranscriptMessageMenu` wrapper (module_app_ui) around the user bubble and the agent reply
  card, built on `PregoAnchorMenu` like the session row. The touch/pointer trigger is a new named interaction wrapper in
  `module_prego/lib/interactions/` (long-press with a flat spotlit menu on touch, secondary click at the pointer), not
  the inline `PregoInteractionScope` reads `session_tile.dart` uses. The wrapper supersedes those inline reads, so the
  session row moves onto it in the same step (and loses its `pending` marker); two copies of the trigger are not left
  behind. Touch: long-press opens a flat menu with the pressed message
  spotlit (`PregoMenuSpotlight.listRow`) and a light haptic, the rest of the transcript blurred behind it. Pointer:
  right-click opens it at the pointer. Every menu ends with "Copy" and "Select text" (decision 3); "Select text" closes
  the menu and enters the existing `PregoReadableSelectionArea` selection on that message. Items before them:
  - own message that opens a finished turn: "Edit and resend", "Fork from here";
  - own message inside a finished turn but not opening it (a follow-up sent mid-turn): "Edit and resend", which answers
    with a popup, "Sent while the agent was working, so it can't be edited. Fork instead?", with Fork and Cancel
    (decision 12), and "Fork from here" (decision 15 says where that fork starts);
  - the last agent reply of a finished turn: "Fork from here";
  - any other agent message, and everything in the running turn: nothing before Copy.
  - Edit appears only when the session's harness declares `rewind` and the session is not archived. Fork appears when
    the harness declares `fork`, archived sessions included (decision 10). Copy copies the message's markdown; on
    pointer with a text selection inside the message, it copies the selection.
  - Which actions a message gets is worked out in `module_core`, not in the widget: `cubits/session_detail/
    transcript_turns.dart` (which already applies `splitPromptTurns`) gives each message its branch actions in the
    loaded state, from the turn shape, the archived flag and `sessionBranching`, which
    `SessionDetailLoadService._loadPluginCapabilities` carries. The menu only renders the actions it is given.
- **Session ⋯ menu.** "Fork" joins `SessionListActionDispatcher.sessionMenuEntries` (decision 8), so it shows on the
  four surfaces that list feeds (list-row long-press or right-click, the phone session "More" menu, the desktop session
  "…" menu, the desktop sidebar), on archived sessions too, for root sessions whose harness declares `fork`. The
  capability is decided in `module_core`: `SessionActionService` reads the harness's `sessionBranching` from the
  plugin listing `PluginManagementService.snapshots` already publishes, `SessionActionsCubit.canFork(session)` exposes
  it, and `sessionMenuEntries` takes the answer as a parameter and only renders it. It sends `ForkPoint.latest()`, so
  the bridge picks the latest finished turn and no transcript has to be loaded. A session with no finished turn yet
  answers the tap with "Nothing to fork yet" (the bridge's `nothingToFork`) rather than hiding the item.
- **One fork pipeline.** Both fork entry points (the message menu through `SessionDetailCubit`, the ⋯ menu through
  `SessionActionsCubit`) call one `SessionActionService.forkSession({sessionId, point})`, which calls client
  `SessionRepository.forkSession` → `SessionApi.forkSession`, maps the answer to a sealed `SessionForkResult`
  (`forked(session)`, `nothingToFork`, `branchPointUnavailable(reason)`, `failed`), and records `session_forked`
  once. `SessionActionService` gains `PluginManagementService` and `ProductAnalyticsService`; the cubits only render
  the result and navigate.
- **Restoring a message into a composer** (used by edit mode and by "Fork from here" on your own message). A new
  `MessageComposerRestoreService` (`module_core/lib/src/services/`, depending on `MessageImageRepository`, which
  already wraps `SessionApi.getAttachment`, and the shared note parser) turns a user message into a
  `RestoredComposer({draft, attachments, leftOutCount})` (`foundation/models/composer/`). `SessionDetailCubit` is its
  only consumer. It restores:
  - the text, without the bridge's saved-file notes (`Attached file "<name>": \`<path>\``, written by
    `PromptPartDeliveryService`). The note's builder moves to `sesori_shared` with a parser beside it, so the bridge
    writes and the client recognises one format;
  - each inline image part, fetched through the existing `POST /session/attachment` route into an ordinary
    `ComposerImageAttachment`;
  - each saved file named by a note, as a new `ComposerHostFileAttachment({path, filename})` that sends as the existing
    `PromptPart.filePath`, so the bridge reuses the file it already holds instead of a re-upload. The bridge's
    `PromptPartDeliveryService` turns a `filePath` part back into the shared saved-file note, so every harness gets the
    same delivery as the original send (plugins map raw paths differently; Codex would send any path as an image). An
    older bridge passes `filePath` through, so restore is offered only where the bridge declares edit or fork. It has no bytes, so
    `bytes` (and `mime`) move off the sealed `ComposerAttachment` base onto the variants that carry them
    (`ComposerImageAttachment`, `ComposerFileAttachment`), and the dozen or so consumers that read them switch on
    the variant; an empty-bytes sentinel is not used;
  - an attachment the bridge can no longer serve (the 30-day upload sweep, a pruned harness transcript) is left out,
    and the composer says how many were left out.
  The composer shows them as ordinary removable attachment chips (decision 11).
- **Edit mode.** "Edit and resend" puts the composer into edit mode:
  - the current draft is saved aside, and the message's text and attachments fill the composer (see above) through
    the restoration mechanism, with the caret at the end;
  - the composer's `header` slot shows an edit banner that grows in (size + fade, the `_AnimatedBanner` motion, reduced
    motion honoured): "Editing your message · Files stay as they are" and a Cancel button. Cancel, or Escape on pointer,
    shrinks the banner away and restores the saved draft;
  - the transcript does not move when edit mode starts. The edited bubble gets a subtle highlight so the reader sees
    which message the banner refers to;
  - Send runs the edit. On success the banner shrinks away and the saved draft comes back.
  - Seam with the side-question plan: its "/btw" side-question mode also takes over the composer header. Whichever
    plan lands first introduces one sealed composer mode in `SessionDetailCubit` (normal, editing, side question) so
    the two modes can't overlap; entering one leaves the other.
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
- **Fork.** "Fork from here" closes the menu with the ordinary exit motion and calls the fork route with
  `afterMessage` on an agent reply, `beforeMessage` on your own message that opens a turn, and `afterMessage` on a
  follow-up sent mid-turn (decision 15; its text and attachments still go to the fork's
  composer). When it answers, the fork opens with the
  platform's normal navigation transition: phone pushes the session-detail route; desktop selects it in the cockpit.
  On your own message, the restored text and attachments are handed to the fork before navigating, so the fork opens
  with them in its composer and the caret at the end (decision 7); there is no edit banner, because nothing is being
  replaced. `ComposerDraft` holds only text, so the handoff is a new in-memory, one-shot
  `ComposerDraftRepository.handOverForSession({sessionId, restored})` / `takeHandoverForSession({sessionId})`:
  the fork's `SessionDetailCubit` takes it at construction, as it takes a launch handoff today, saving the text as its
  draft and feeding the attachments through the existing restored-attachments path. Attachment bytes are never
  persisted. If the answer takes longer than about 300 ms, the pressed message (or the ⋯ menu's
  anchor) shows a small inline progress indicator so the tap is visibly answered; a failure shows the ordinary alert
  with the bridge's reason.
- **"No project" delete warning.** Deleting a "No project" session warns that its folder is deleted too, but the bridge
  keeps the folder while a fork still uses it (`ScratchRepository.deleteSessionDirectoryIfUnused`). The warning names
  that exception in its sentence ("…unless a fork of it still uses the folder"), so the client needs no fork lookup.
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

Phase 1 is eighteen PRs. Titles use `<emoji> [session-edit-fork] <description> [step <x>/18]`, where `<x>` is the PR
ordinal: steps 1 and 2 keep their number, 3.a is 3, 3.b is 4, steps 4 to 9 are 5 to 10, 9.b is 11, step 10 is 12, step
11 is 13, 11.b is 14, and steps 12 to 15 are 15 to 18. Steps 5 and 9 merged before the last renumbering, under the
titles "step 5/17" and "step 9/17".

Merge gate and testing rule for every implementer brief: right before `gh pr merge`, re-fetch the inline comments and
confirm each one on the head commit has a reply or a fix, confirm Codex's completion comment names that head, and wait
at least 3 minutes after Codex's last comment. On-screen and device checks run only on a headless iOS simulator
(`xcrun simctl boot`, Simulator.app never opened) on the device the local testing setup assigns; desktop macOS is used
only for the desktop-specific right-click menu. Worktrees go under `~/.claude-worktrees/sesori_apps_monorepo/<name>`.

### Step 1: raise the plan

`🌱 [session-edit-fork] Raise the session edit and fork plan [step 1/18]`. This file and `TRACKER.md`. Docs only.

### Step 2: message menu with Copy and Select text

`⚙️ [session-edit-fork] Add a long-press and right-click menu to transcript messages [step 2/18]`

- **What:** the `module_prego` context-menu interaction wrapper, and `TranscriptMessageMenu` on user bubbles and agent
  reply cards, phone and desktop, with "Copy" and "Select text". The session row moves onto the same wrapper.
  Long-press no longer starts a selection directly; "Select text" does. Client only.
- **Why:** it is the surface both features need, it is useful alone, and it settles the long-press/selection feel before
  edit and fork depend on it.
- **Risk and test focus:** gesture conflicts with selection, the timestamp-peek drag, pinch-to-Prompts and code-block
  scrolling; the menu must not move the transcript; "Select text" lands in the same selection a long-press gave before.
  Widget tests for both interaction modes; a headless iOS simulator recording of long-press, menu, copy, select.
- **Expected result:** long-press or right-click on a message opens a menu that copies it or starts a selection. No
  database or wire change.
- **Estimate:** ~650 lines.

### Step 3: edit contract and bridge route

Split at implementation into 3.a, `⚙️ [session-edit-fork] Declare session branching on plugins and add the rewind wire
models [step 3/18]` (#2606: plugin interface, capability flow, wire models), and 3.b, `🚧 [session-edit-fork] Add the
bridge route that rewinds a session and resends an edited message [step 4/18]` (#2602: route, service, history removal,
mutation pipeline).

- **What:** `PluginSessionBranching`, `SessionRewindPluginApi`, `PluginBranchPointUnavailableException`; descriptor
  getter and its flow into `PluginMetadata.sessionBranching`; `RewindSessionRequest`; `RewindSessionHandler`;
  `SessionPromptService.rewindAndSendPrompt`; `ChatHistoryService.removalForRewind`; `SessionMessagesRewound` mutation
  and the list-returning `_mapLocalMutation`; `SessionBranchErrorResponse`; the `toShared()` capability mapping. A
  first-turn edit is refused with `branchPointUnavailable` until step 4. No plugin declares `rewind` yet.
- **Why:** one backend-neutral path that both native plugins plug into.
- **Risk and test focus:** ordering between store removal and the new prompt's capture; idempotent retry by `promptId`;
  busy refusal; turn validation on partial stores; archived rejection. Bridge tests with a fake plugin implementing the
  interface.
- **Expected result:** no user-visible change; `PluginMetadata` gains an empty `sessionBranching` for every harness.
- **Estimate:** ~900 authored + ~300 generated.

### Step 4: first-message edits replace the harness session

`🚧 [session-edit-fork] Edit a session's first message by swapping in a new harness session [step 5/18]`

- **What:** `SessionRepository.replaceBackendSession` and its use from `rewindAndSendPrompt` for a first-turn edit, as
  in "Harness-session swap": `useAndCommit` with `createSession` and a rebinding commit, removal of a stray imported
  row for the new backend id, `SessionBindingCommitKind.sessionReplacement`, tombstones and child-row removal for the
  old subtree through the helper shared with `deleteSession`, the old backend delete, the removed children's history
  purge from `SessionPromptService`, and the worktree context part `SessionPromptService` builds for the new first
  prompt.
- **Why:** decision 13. It makes the first message editable on every harness that offers Edit, with no plugin-specific
  code, and is the base Pi's phase-2 edit builds on.
- **Risk and test focus:** events of the new harness session reaching clients under the old Sesori id; the old
  session's late events and `session.deleted` changing nothing; catalog import and startup reconciliation never
  re-importing the old session; a failed old delete leaving only a tombstone; the unique index under an import race.
  Bridge tests with a fake plugin; one live run on Claude Code and Codex through the debug server.
- **Expected result:** no user-visible change until a client offers Edit (step 10). No schema change (the tombstone
  table already exists).
- **Estimate:** ~700 lines.

### Step 5: Codex reads reverted and forked rollouts

`🚧 [session-edit-fork] Read Codex history across revert and fork rollouts [step 6/18]`

- **What:** teach the Codex plugin the `<threadId>_<rolloutId>` rollout names and `session_meta.history_base`, so
  history follows the kept prefix of a reverted or forked thread (resolving the base rollout in the sessions and
  archived-sessions folders). Starts with a live spike at 0.167.2 that pins the file naming and checks whether the
  background "migrate to paginated" pass already renames existing rollouts (if it does, that is a live bug today and
  this step fixes it for every user). If base rollouts can't be located reliably, read affected threads through
  `thread/turns/list` + `thread/items/list` instead. Owners: rollout-name parsing and reading a base prefix in
  `CodexRolloutApi` (Layer 1, no decisions); resolving which base to follow in `CodexCatalogRepository` and
  `CodexMessageRepository`; any `thread/*/list` wrappers in `CodexAppServerApi`. The spike also records whether a
  forked thread keeps the source's item ids, which the fork step relies on.
- **Why:** without it, a Codex revert leaves Sesori showing the old history and a fork shows only its new turns.
- **Risk and test focus:** catalog import and history replay for ordinary, reverted, forked and sub-agent threads;
  fixtures recorded from the live spike.
- **Expected result:** no visible change for ordinary threads; reverted and forked threads read correctly.
- **Estimate:** ~800 lines.

### Step 6: Codex native edit

`⚙️ [session-edit-fork] Rewind and resend Codex sessions natively [step 7/18]`

- **What:** `CodexPluginImpl` implements `SessionRewindPluginApi` and only delegates. `thread/revert` gets a wrapper in
  `CodexAppServerApi`, reached only through a new `CodexThreadRepository.revertThread` (beside `resumeThread` and
  `startTurn`); item-to-turn mapping lives in `CodexMessageRepository`; `CodexSessionService` runs the sequence
  through those repositories, never the API:
  make sure the thread is loaded (`thread/resume` when needed), `thread/revert {beforeTurnId}`, then the ordinary
  `turn/start` path with the same `promptId`. Declares `rewind`. A runtime without `thread/revert` (JSON-RPC
  method-not-found, e.g. the 0.139 PATH minimum) or an unmappable id throws `PluginBranchPointUnavailableException`
  with a reason such as "Update Codex to edit messages". A legacy (non-paginated) thread answers `thread/revert` with
  -32600 ("only supports paginated threads", step 5 spike), which also becomes the refusal. The plugin also confirms
  that `beforeMessageId` is the first user item of its native turn: `splitPromptTurns` can open a presentation turn at
  a follow-up steered in after commentary or reasoning, and reverting that native turn would remove more than the store
  does. A target that is not its native turn's first user item is refused with the mid-turn reason. After its own
  revert the plugin refreshes the catalog's current rollout at once (the step 5 reader otherwise keeps the old file
  until the next scan). The revert is destructive before the resend, so the plugin validates everything that can fail
  (attachments, options, the thread loaded) before `thread/revert`. If `turn/start` still fails after a successful
  revert, the bridge reconciles before returning the failure: it backfills the session from the harness and publishes
  the removal of the stored messages the harness no longer has, so clients don't keep showing history the harness has
  dropped (the client keeps the edited text in the composer). `docs/HARNESS_CAPABILITIES.md` gets the edit row.
- **Risk and test focus:** paginated versus legacy threads; ephemeral threads refused; a follow-up steered after
  commentary refused; a successful revert followed by a failed resend; revert's reload not dropping subscriptions; history after revert agrees with the store. Live
  plugin check at the pinned version.
- **Expected result:** Codex sessions report `rewind`.
- **Estimate:** ~600 lines.

### Step 7: Claude reads the active branch of a transcript

`🚧 [session-edit-fork] Read the active branch of Claude Code transcripts [step 8/18]`

- **What:** parse `parentUuid` (and `last-prompt.leafUuid`) in the Claude transcript record DTO;
  `ClaudeTranscriptApi.readTranscript` stays a raw record reader, and `ClaudeTranscriptCatalogRepository` builds history
  and catalog previews from the chain ending at the active leaf instead of every record in file order. Keep today's
  compaction and sidechain (sub-agent) behaviour.
- **Why:** an in-place rewind leaves the old branch in the file. A rewind in the Claude Code terminal already does, so
  this also fixes a live bug, and it can ship on its own.
- **Risk and test focus:** leaf choice when no `last-prompt` record exists (newest record); compaction boundaries whose
  parent is null; sidechains; one pass over large files. Fixtures recorded live at 2.1.322.
- **Expected result:** no change for linear transcripts; branched ones show only the active branch.
- **Estimate:** ~600 lines.

### Step 8: Claude native edit

`🚧 [session-edit-fork] Rewind and resend Claude Code sessions natively [step 9/18]`

- **What:** `ClaudePluginImpl` implements `SessionRewindPluginApi` and only delegates: `ClaudeSessionService` runs the
  sequence and `ClaudeSessionProcessRepository` launches a new `ClaudeSessionLaunch` variant that resumes at a chain
  entry; the uuid → `parentUuid` lookup lives in `ClaudeTranscriptCatalogRepository`. Stop the session's idle process,
  respawn with `--resume=<id> --resume-session-at=<parentUuid of the edited user record>`, and send the prompt through
  the ordinary path with the same `promptId`. Later respawns use plain `--resume`, which follows the new leaf. Declares
  `rewind`. An unknown uuid or an `unknown option` spawn failure → `PluginBranchPointUnavailableException`. The first
  message never reaches the plugin (step 4 swaps it), so no first-message spike is needed. Harness matrix row.
- **Risk and test focus:** the respawn racing the idle reaper or a pending permission; the respawn keeping model, agent
  and permission mode; history after the rewind agreeing with the store (step 7). Live plugin check at 2.1.322 and at
  the 2.1.221 minimum.
- **Expected result:** Claude Code sessions report `rewind`.
- **Estimate:** ~550 lines.

### Step 9: restore a message's text and attachments into a composer

`⚙️ [session-edit-fork] Bring a sent message's text and attachments back into the composer [step 10/18]`

- **What:** the saved-file note builder and parser in `sesori_shared` (the bridge's `PromptPartDeliveryService` uses
  the moved builder); `ComposerHostFileAttachment` and its `PromptPart.filePath` send path, with `bytes`/`mime` moved
  onto the byte-carrying variants; `MessageComposerRestoreService` and `RestoredComposer` (text without notes, images
  through `MessageImageRepository`, saved files by path, a count of attachments left out); attachment chips for the
  new kind. No feature uses it yet.
- **Why:** edit mode (step 10) and "Fork from here" on your own message (step 14) both need it (decisions 7 and 11), and
  together they would exceed the PR cap.
- **Risk and test focus:** the note format staying byte-identical for the bridge; a message with only attachments; a
  swept upload or a missing image; a host-file attachment sent to a bridge on another computer still resolving there
  (the path is on the bridge's computer). Unit tests for the parser and the service.
- **Expected result:** no user-visible change. No database change; no wire change (existing part kinds only).
- **Estimate:** ~600 lines.

### Step 9.b: retire the plugin-side file-path prompt part

`🌿 [session-edit-fork] Retire the unreachable file-path prompt part from plugins [step 11/18]`

- **What:** step 9 made the bridge's `PromptPartDeliveryService` turn every `PromptPart.filePath` into the shared
  saved-file note, so no `PluginPromptPartFilePath` reaches a plugin any more. Remove that plugin prompt part and its
  handler in every plugin, and settle in the delivery seam how an already-delivered part is modelled, so the bridge's
  `PromptPart` → `PluginPromptPart` mapping no longer needs a case for it.
- **Why:** AGENTS.md removes what a change makes obsolete; the dead per-plugin mappings (Codex sends a path as an
  image, Pi throws) would otherwise invite a wrong reuse.
- **Risk and test focus:** every plugin's prompt mapping and tests; no change on the wire.
- **Expected result:** no user-visible, wire or database change.
- **Estimate:** ~250 lines.

### Step 10: client edit flow

`🚧 [session-edit-fork] Edit and resend earlier messages from the transcript [step 12/18]`

- **What:** "Edit and resend" in the message menu; edit mode in `SessionDetailCubit` (it owns the composer draft and
  restorations, and a sibling cubit couldn't depend on it) with saved draft, restored attachments, banner, Cancel, and
  send through a new client `SessionRepository.rewindSession` → `SessionApi.rewindSession`; the sealed composer mode
  (if the side-question plan has not added it yet); the mid-turn follow-up explanation popup with its Fork action
  (calls step 14's fork when it exists, until then the popup offers only OK); the busy popup, where "Stop and resend" is
  run by the cubit: `SessionAbortService` stop, wait for idle on its own status stream, then the rewind; removal exit
  motion for `message.removed` rows, including while detached; `session_message_edited` analytics.
- **Risk and test focus:** feel. No jump when entering edit mode, when rows fold away, or when the new bubble arrives;
  reduced motion; draft restoration; another device's rewind arriving mid-read; a first-message edit looking the same
  as any other edit. Cubit tests with fakes; widget tests; a headless iOS simulator recording of the whole edit, which
  goes in the PR body.
- **Expected result:** users of Claude and Codex sessions can edit an earlier message, attachments included; later
  messages fold away and the new answer streams in. No database change.
- **Estimate:** ~1,300 lines.

### Step 11: fork contract, origin link and bridge route

`🚧 [session-edit-fork] Fork a session from a message on the bridge [step 13/18]`

- **What:** `SessionForkPluginApi`; `ForkSessionRequest` with `ForkPoint`; `ForkSessionHandler`; `SessionForkService`;
  `ChatHistoryService.forkBoundary` (including the archive audit record and `nothingToFork`);
  `SessionRepository.forkSession`, with the empty-prefix `createSession` path and the `sessionCreation` binding
  commit; the " (fork)" title decided in `SessionForkService`; the pruned-harness refusal for archived origins (the
  removed-worktree case is step 11.b); the worktree context on an empty fork's first send; the next schema version with `forkedFromSessionId` and `forkedFromTitle`;
  `Session.forkedFrom` in `SessionCatalogMapper`. No plugin declares `fork` yet (the empty-prefix path still needs the
  declaration before a client offers it).
- **Risk and test focus:** the copied worktree fields (archive or delete of either session keeps the worktree while the
  other is live, then the last one removes it); origin deletion nulls the link; an already-imported backend binding;
  running-turn refusal; archived origins with their worktree. Drift migration test.
- **Expected result:** no user-visible change; sessions gain an always-null `forkedFrom`.
- **Estimate:** ~900 authored + Drift schema snapshot and steps (likely ~800 generated; report the split).

### Step 11.b: recreate an archived origin's removed worktree for a fork

`⚙️ [session-edit-fork] Recreate an archived session's worktree when it is forked [step 14/18]`

- **What:** decision 14, as in "Fork flow" step 1: `WorktreeRepository.worktreeExists` and a worktree add at the
  origin's old path on the kept branch or at the HEAD archiving pinned (archive records the branch and pins the HEAD
  under `refs/sesori/worktrees/…`; the last session's deletion releases it), used by `SessionForkService` for an
  archived origin whose dedicated worktree is missing; `SessionBranchErrorCode.worktreeBranchMissing` when nothing was
  kept; `ForkSessionRequest.recreateFromBase` to start from `baseCommit` on the retry; a plain refusal when the old
  path is now taken by something else. The client's "Create a new worktree from <base branch>" prompt lands in step
  14. Delivered in #2636 (~1,040 lines with the archive-time pin).
- **Why:** the user chose recreation over refusal (round 4), so archived forks keep the agent's remembered paths.
- **Risk and test focus:** git worktree add on an existing branch versus a recreated one; the path taken by another
  directory; the fork's later archive or delete removing the recreated worktree while the archived origin doesn't
  count as a sharer; the `history_base`/cwd assumptions of Codex and Claude (both keep the old cwd). Bridge tests with a
  fake git; one live run.
- **Expected result:** no user-visible change until step 14 offers fork. No database change.
- **Estimate:** ~350 lines. Must merge before steps 12 and 13 declare `fork`.

### Step 12: Codex native fork

`⚙️ [session-edit-fork] Fork Codex sessions from a turn [step 15/18]`

- **What:** `CodexPluginImpl` implements `SessionForkPluginApi` and delegates to `CodexSessionService`, which calls a
  new `CodexThreadRepository.forkThread` over a `CodexAppServerApi` `thread/fork {lastTurnId}` wrapper (not
  ephemeral) with the turn id from `CodexMessageRepository`, maps the new thread to a `PluginSession` in the same cwd, and emits `session.created`
  unless the spike shows `thread/started` already produces it. Declares `fork`; method-not-found on old runtimes →
  `PluginBranchPointUnavailableException`. Harness matrix row. A paginated fork's kept prefix is a reference to the
  source rollout (`history_base`), and today `CodexCatalogRepository.deleteSession` deletes the source's rollout files,
  so deleting an origin (or the step 4 swap deleting the old harness session) would empty the fork's kept history.
  Decision 4 keeps both sessions alive, so a delete keeps every rollout file another thread's `history_base` still
  references and removes only the rest (Codex's own delete refuses in this case). Forks made in the Codex TUI benefit
  the same way.
- **Risk and test focus:** the fork's history reads through step 5; the fork does not appear twice after catalog import;
  forking while a later turn runs; forking an archived thread; the fork's kept history still reads after deleting the
  origin, after a first-message swap on the origin, and after a bridge restart.
- **Estimate:** ~500 lines.

### Step 13: Claude native fork

`🚧 [session-edit-fork] Fork Claude Code sessions from a message [step 16/18]`

- **What:** `ClaudePluginImpl` implements `SessionForkPluginApi` and delegates to `ClaudeSessionService` (the turn's
  last chain record comes from `ClaudeTranscriptCatalogRepository`): choose the new session id, have
  `ClaudeSessionProcessRepository` launch a fork variant of `ClaudeSessionLaunch`
  (`--resume=<origin> --fork-session --session-id=<new> --resume-session-at=<uuid>`), and return the `PluginSession`
  in the origin's directory. Declares `fork`. Starts with a spike: is `<new>.jsonl` written before the fork's first
  prompt? If not, the plugin writes the kept chain into the new file itself, the way the SDK's documented
  `forkSession` does, so the fork exists on disk at once and survives a bridge restart: the chain is chosen in
  `ClaudeTranscriptCatalogRepository` and written as raw records by `ClaudeTranscriptApi`. The same spike checks that an
  empty fork (an unstarted session from step 11) still takes its first prompt after a bridge restart. Emits
  `BridgeSseSessionCreated` as `createSession` does. A missing origin transcript (pruned) → branch-point refusal with a
  plain reason. Harness matrix row.
- **Risk and test focus:** forking while a later origin turn runs; catalog import not listing the fork twice; deleting
  the fork removes only its own `.jsonl` (`PersistedSessionCleanupApi`); history of the fork shows only the kept chain.
- **Expected result:** Claude Code sessions report `fork`.
- **Estimate:** ~600 lines.

### Step 14: client fork flow

`⚙️ [session-edit-fork] Fork from a message or the session menu and show where a fork came from [step 17/18]`

- **What:** "Fork from here" in the message menu and "Fork" in `sessionMenuEntries` (gated by
  `SessionActionsCubit.canFork`); `SessionDetailCubit` and `SessionActionsCubit` both call
  `SessionActionService.forkSession` (client `SessionRepository.forkSession` → `SessionApi.forkSession`, the sealed
  `SessionForkResult`, `session_forked` recorded once) with the right `ForkPoint`, with inline progress after
  ~300 ms; own-message forks hand the restored composer (step 9) to the fork through
  `ComposerDraftRepository.handOverForSession` before navigating; the view navigates through `SessionDetailPresentationScope.openSession` and the new
  `returnToSession` callback each shell implements; the "Forked from" row at the oldest edge with its back-or-open
  behaviour; the mid-turn follow-up popup's Fork action; the "Create a new worktree from <base branch>" prompt for
  `worktreeBranchMissing` (step 11.b), which retries with `recreateFromBase`. It shows only for sessions archived
  before the archive-time HEAD pin whose branch is gone, so the copy says the session's earlier work can't be
  restored and the new worktree starts where the session started (its base commit), without claiming a branch was
  deleted; the "No project" delete warning wording.
- **Risk and test focus:** navigation stack on phone (origin → fork → origin must not pile up); desktop selection; the
  row only once the oldest page is loaded; the composer draft present on the fork's first frame (no text popping in);
  forking an archived session from its ⋯ menu; feel of the transition. Headless iOS simulator recording in the PR body.
- **Expected result:** forking a Claude or Codex session opens the fork with the kept conversation, your message in
  its composer when you forked from your own message, and a working "Forked from" link.
- **Estimate:** ~1,200 lines. If it passes the cap, split the ⋯ menu entry into 14.b.

### Step 15: reconcile docs, verify and retire

`🌱 [session-edit-fork] Reconcile edit and fork docs and retire the plan [step 18/18]`

The plan-maker lifecycle asks for the regression reconciliation and the verified retirement as the last two steps. They
are folded into one here because each feature step already updates its regression and harness rows; if reconciliation
finds more than small fixes, split this into 15.a (docs) and 15.b (run and retire).

- Reconcile the regression documents listed below, run the verification matrix, record the result in `TRACKER.md`, and
  move the plan to `.plan/completed/session-edit-fork/` only when the matrix passes.

## Regression documents

- **New:** `docs/regression/session-edit-and-fork.md` (capability, required behaviour, levels), added in step 3 and
  completed in steps 4, 10 and 14.
- **Update:** `docs/regression/session-archiving-and-deletion.md` (a fork shares its origin's worktree: archive or
  delete of either keeps it for the other; archived sessions can be forked; the "No project" warning names the fork
  exception), `docs/regression/transcript-turn-navigation.md` (edit points are turn-opening prompts; removed rows fold
  away without moving the rows being read), `docs/regression/session-turns.md` (an edit sends through the same prompt
  identity and refusals; a first-message edit swaps the harness session under the same session),
  `docs/regression/projects-and-sessions.md` (a fork is an ordinary root row titled "<origin> (fork)"; Fork in the
  session menu), `docs/regression/attachments-and-images.md` (an edited or forked message brings its attachments back;
  saved files are resent by path), `docs/regression/analytics.md` (two new events, widened harness exception),
  `docs/regression/session-history-and-recovery.md` (Codex history across revert and fork rollouts; Claude history
  follows the active branch of a rewound transcript; a swapped session's old harness session is never re-imported).

## `docs/HARNESS_CAPABILITIES.md` rows

A new "Edit and fork" section with one row per registered harness and two capability columns, "Edit and resend
(rewind in place)" and "Fork from a message", plus a note that editing the first message swaps in a new harness
session on every harness that offers Edit:

| Harness | Edit and resend | Fork from a message |
|---|---|---|
| Claude Code | ✅ after step 8 (first message: swap, step 4) | ✅ after step 13 |
| Codex | ✅ after step 6 (needs `thread/revert`; older PATH runtimes refuse with a reason) | ✅ after step 12 (needs `thread/fork lastTurnId`) |
| OpenCode | ⬜ (v2 `revert/stage files:false`); v1 🚫 conversation-only revert | ⬜ (v2 `fork before`) |
| Pi | ⬜ (swap through RPC `fork {entryId}`) | ⬜ (RPC `fork` in a new process) |
| Oh My Pi | ⬜ text copy (phase 2) | ⬜ text copy (phase 2) |
| Antigravity, Copilot, Cursor, DeepSeek, Grok, Hermes | ⬜ text copy (phase 2) | ⬜ text copy (phase 2) |

Edits of follow-ups sent mid-turn: ⬜ for Claude Code, OpenCode and Pi (later phase), 🚫 for Codex (cuts only between
turns). The ACP harnesses were not checked for native message-level rewind or fork in this plan; phase 2 checks each
before choosing the text copy, and marks 🚫 only what it verifies. Footnotes name the verified versions. Phase 2 adds a
"text copy" column state when the fallback lands.

## Verification

Highest level: **L3 release** for the delivered behaviour, through these boundaries:

| Boundary | Claim | Matrix |
|---|---|---|
| Automated | turn validation, store removal ordering, the swap's rebind and tombstones, fork points, fork row copy, migration, capability mapping, message-to-draft restore, cubit edit state, menu items per message kind | — |
| Live plugin | native rewind and fork at the pinned versions, a first-message swap, history after each agrees with the store, files untouched, an archived origin forks | Claude Code 2.1.322, Codex 0.167.2; a refusal check on Codex 0.139.0 and Claude at `minVersion` if it lacks the flag |
| Client end to end | menu with Select text, edit banner with restored attachments, mid-turn follow-up popup, busy popup, removal motion, first-message edit, fork from a reply, from your own message (text in the fork's composer) and from the ⋯ menu, "Forked from" link, archive/delete of a forked pair, fork of an archived session | headless iOS simulator (phone) against Claude Code and Codex; desktop macOS for the right-click menu only |
| Relay integration | a second client sees removed rows fold away, a swapped session stay one session, and the fork appear | one plugin (representative) |

Per the user's testing rule, phone cells run only on a headless iOS simulator (`xcrun simctl boot`, no Simulator.app) on
the device the local testing setup assigns. Desktop is in the matrix only because the right-click menu is
desktop-specific.

## Complexity budget

New persistent state: two nullable columns (`forkedFromSessionId`, `forkedFromTitle`). The swap reuses the existing
tombstone table and adds no column. New wire state: one capability set, two request models with one sealed
`ForkPoint`, one error response, one nullable session field. New in-memory state: the client's edit-mode draft (one
saved draft and one target message id) and a set of leaving row ids during the exit motion. Plugin state: none new in
Codex (turn ids are read from history); Claude gains one launch variant. The bridge gains one binding-commit kind.

Deliberately not added: no file snapshots or restore; no per-harness safety prompts; no queued edits that wait for a
turn to end (Stop and resend instead); no cut inside a turn; no join for the origin's live title; no new worktree
reference counting (the existing shared-worktree rule covers it); no plugin-side turn segmentation; no swap for edits
that native rewind can do (see "Edit mechanism"); no re-upload of saved files (they are resent by path); no worktree
copying for archived origins (a removed worktree is recreated from git, decision 14).

## Cleanup assessment

Step 9 makes the plugin-side `PluginPromptPartFilePath` unreachable (the bridge turns file paths into notes); step
9.b removes it from every plugin. The Pi `--fork` launch flag stays (it serves session restore, not this feature). The
saved-file note builder moves from `PromptPartDeliveryService` to `sesori_shared` rather than being duplicated.

## Risks

- **Claude's flag is undocumented** (see the Claude section): a removal would turn Claude edit and fork into
  branch-point refusals until the fallback or a replacement lands. The plugin's tests pin the flags' presence at the
  target version so a runtime refresh notices.
- **Codex rollout format drift**: step 5 depends on unstable on-disk details; its live fixtures guard runtime refreshes.
- **Feel of removal**: removing rows below a detached reader in a reversed list is the riskiest motion; step 10 needs a
  recording before it is called done.
- **Swap events**: the swap depends on the event tracker holding the new session's events until the rebind commits, as
  it does for created sessions. Step 4's live run is the check.
- **Archived forks fail more than live ones**: Claude Code prunes transcripts after 30 days by default; that is refused
  with a reason until phase 2's text copy (accepted). A worktree removed at archive is recreated from git (step 11.b);
  a deleted branch needs the user's go-ahead to start again from the base branch.
- **A forked session's attachments live in its origin's upload folder.** Deleting the origin deletes them; the fork's
  agent already read them, and restoring them later just leaves them out (accepted, low damage).

## Open questions (for the user)

Round 2 answered the earlier seven (decisions 7 to 13). These are new:

1. ~~"Fork from here" on a follow-up sent mid-turn.~~ Settled in round 4 (decision 15).
2. ~~Forking an archived session whose worktree was removed at archive.~~ Answered in round 4: recreate it
   (decision 14, step 11.b).

## Later phases (rough)

- **Phase 2 — OpenCode and Pi native.** OpenCode v2 edit through `revert/stage {files: false}` + prompt and fork through
  `fork {before}`; add the routes to the v2 surface allowlist. Pi edit through the swap: RPC `fork {entryId}`, rebind
  to the new session id, then the prompt; Pi fork the same in a new process. Pi's synthetic message ids embed the
  session id, so phase 2 must keep the kept messages' ids stable across the swap. Why: the two other harnesses the user
  named for native support.
- **Phase 2 — text fallback.** Bridge-owned: a new session seeded with the earlier conversation as text (no tool memory),
  labelled as such, for every harness without native support, and Edit as "a copy with your edit" where rewind is
  missing. It also covers archived origins whose harness session is gone. Shares the transcript renderer with the
  merge plan. Why: parity across harnesses (decision 6).
- **Later — edit follow-ups sent mid-turn** on Claude Code, OpenCode and Pi, which can cut at a single message
  (decision 12). Why: removes the "can't be edited" answer where the harness allows it.
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
- 2026-11-15: updated for the round-2 answers (edit as fork, fork title, Select text, archived forks, attachments,
  mid-turn follow-ups, fork and replace).
- 2026-11-15, `architecture-plan-review` of the round-2 update: rejected with 13 findings, all applied directly: the
  swap's worktree context and the fork's title decided in services, not `SessionRepository`; the swap's removed
  children purged from history by `SessionPromptService`, with the tombstone code shared with `deleteSession`;
  `SessionPromptService` gains `ChatHistoryService`; `SessionForkService` drops the unused `ArchivedSessionValidator`
  and gains `WorktreeRepository` for the removed-worktree check; the fork commits as `sessionCreation`; a
  `nothingToFork` refusal for `latest()` and `afterMessage` for mid-turn follow-ups; Codex revert and fork through
  `CodexThreadRepository`; named Claude fork launch and chain-write owners; `MessageComposerRestoreService` named;
  `bytes`/`mime` off the sealed `ComposerAttachment` base; an in-memory composer handoff for forks; one
  `SessionActionService.forkSession` pipeline with a `module_core` capability gate for the ⋯ menu; the session row
  moves onto the new interaction wrapper. Open question 2's provisional default was left as it is.
- 2026-11-15: round 4 answered open question 2 (recreate the removed worktree, step 11.b); step 9.b added for the
  cleanup step 9 made necessary; the series is seventeen PRs.
