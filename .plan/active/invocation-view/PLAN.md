# Invocation View: Command And Skill Runs Get Their Own Card

## Status

- **Plan slug:** `invocation-view`
- **Status:** Active. Step 1 raises this plan.
- **Plan date:** 2026-11-12
- **Base:** `origin/main` at `4029c2478a`
- **User decisions:** review page
  `/Users/alexandrudochioiu/.review-pages/command-invocation-view/round-1.html`,
  answered 2026-11-12 (D1–D8 below). Do not re-ask them.
- **Parallel work:** the `command-bubble` series. #2540 (OpenCode 2) has
  merged. #2541 (Codex) and #2542 (Pi) are open and owned by another agent.
  Steps 2–4 stay off the files those PRs touch. The plugin steps start only
  after both merge.

## Goal

A command, skill or MCP prompt run from the command picker shows in the
transcript as an event card ("You ran /name", a kind tag, then the user's
text), not as a chat bubble holding `/name args`. The card looks the same live,
while sending or queued, pinned at the top, in the prompt list, after the
session is reopened and after a bridge restart. Nothing jumps on the way.

## Decisions

User decisions (D1–D8):

- **D1 Look.** Option B, the event card in the visual language of the
  "Automation" card (`SystemMessageCard`): neutral `bgSecondary` surface,
  `borderSecondary` border, `x2l` radius, a `PregoTag` header. The user's
  note: it "doesn't have to be full screen". The card fits its content up to
  the bubble's maximum width (76 % of the row, `UserMessageBubble.maxContentWidth`).
  It sits at the leading edge, like the Automation card.
- **D2 Tap.** Nothing happens on tap. The card is a label, not a button: no
  ink or press state, no disclosure, and screen readers don't announce it as a
  button. Long-press selection of the user's text works as it does on other
  turns.
- **D3 Kinds.** Commands, skills and MCP prompts use the same card. Each kind
  has its own icon and label, worded as in the command picker: Command, Skill,
  MCP, and Custom for `CommandSource.unknown`.
- **D4 Forgetful harnesses.** OpenCode 2 native commands, Pi prompt templates
  and Oh My Pi commands after a reload don't record which command ran. For
  these the bridge remembers what it sent, in its own database, so the card
  survives reopening the session and restarting the bridge.
- **D5** applies to all harnesses, with one look on phone and desktop.
- **D6** The pinned prompt, the prompt list, and the sending and queued states
  use the same card. Its shape doesn't change between "Sending…", queued and
  confirmed: only the status line under the card fades (240 ms, instant with
  reduced motion).
- **D7** The bridge names the invocation; the app never parses `/name` out of
  the text. Older apps keep the `/name args` bubble. A new app on an older
  bridge shows today's bubble.
- **D8** The PR split is the agent's call.

Planning decisions from code evidence (P1–P9):

- **P1 Wire shape.** A new shared value
  `CommandInvocation({required String name, required CommandSource source, required String? arguments})`,
  added as `MessageUser.invocation` (`required CommandInvocation? invocation`).
  `name` is the bare name without `/`. `arguments` is the user-visible text,
  `null` when there is none, never empty. `source` reuses the existing closed
  `CommandSource` enum (`@JsonKey(unknownEnumValue: CommandSource.unknown)`)
  instead of adding a parallel enum. It is not a new `MessagePart`:
  `MessagePart` has no unknown-type fallback, so older apps would fail to
  parse a new part, while every peer ignores an unknown message field. `null`
  honestly means "this turn is not a known invocation", so no `@Default` or
  compatibility marker is needed.
- **P2 Kind comes from the picker.** The app knows the `CommandInfo.source`
  of the command the user staged. `SendPromptRequest` and
  `CreateSessionRequest` gain `required CommandSource? commandSource`; older
  bridges ignore it. When an older app omits it, the bridge records
  `CommandSource.unknown`. The bridge doesn't look kinds up in the session
  options cache: the app's picker reads `/command` directly, so that cache can
  be cold. The app sends no name or text guessed from the text.
- **P3 One live stamping seam.** `SessionRepository.sendCommand` is the one
  bridge-core path for both prompt-time and creation-time commands. Before it
  calls the plugin, it records `(bridge sessionId, promptId) → CommandInvocation`
  in a bounded in-memory tracker (`CommandInvocationTracker`). `SessionEventService.toNormalized` already
  enriches delivered payloads through the repository (`_observeBusy` →
  `stampLiveStatus`). It also stamps `invocation` on every
  `NormalizedMessageEvent` whose `MessageUser` carries a registered `promptId`.
  Live capture (`ChatHistoryListener`) and client delivery consume that same
  normalized value, so storage and the wire can't diverge. The tracker lives
  only in memory. A queued prompt dies with the bridge anyway, because plugin
  queues are in memory too. So a restart can lose the name only in the short
  gap after the harness accepted the command and before its user turn
  reached the bridge. The cost is that one turn shows as a plain bubble. The
  guarantee is therefore: the card survives reopening and restarts once the
  user turn is recorded. Writing the outbound invocation to the store before
  the plugin call isn't worth it, because the store has no row for that turn
  yet, and correlating one later would add state.
- **P4 Persistence is the history store.** The stamped message is stored as
  `infoJson` in `chat_history.db` and copied into the archive file (both
  serialize `Message`). That store is D4's "small local record". There is no
  new table. Two writes would lose it today, so both carry it over:
  `ChatHistoryRepository.upsertMessage` keeps a stored `invocation` when a
  later update of the same message has none, and `replaceSessionMessages`
  copies a stored row's `invocation` onto the imported message with the same
  id when the import has none. A plugin-provided invocation wins. The replay
  semantic fingerprint (`_semanticMessageFingerprints`) excludes `invocation`
  as it excludes `promptId`, so a stamped live row still matches its replay.
  Carry-over follows the store's existing replay matching: an exact id, or
  the content match the store already makes between a live row and its
  replay. That match is a one-line reuse, so a harness with unstable ids
  keeps the card after the first backfill. Content matching adds no new
  machinery. Where neither match holds, the plugin fills the field from
  history (Phase 2).
- **P5 Queued state.** `QueuedSessionPrompt` gains
  `required CommandSource? commandSource`. Bridge core fills it from the
  tracker by prompt id, in the repository read path (`getQueuedPrompts`) and
  in event normalization (`NormalizedQueuedPromptsEvent`). Plugin queue
  models don't change.
- **P6 Prompt list.** `SessionPromptIndexEntry` (opener and follow-up) gains
  `required CommandInvocation? invocation`, copied from the stored message.
  `preview` keeps today's text, so older apps still list `/name args`.
  Prompt search stays text-based.
- **P7 Honest per-plugin capability.** The app shows the card in the sending
  state before the bridge has answered, so it must know the confirmed turn
  will carry `invocation`. Otherwise "Sending…" as a card would turn into a
  bubble. `BridgePluginDescriptor` gains
  `bool get namesCommandInvocations => false`. It is reported as
  `PluginMetadata.namesCommandInvocations` with `@Default(false)` and a
  `COMPATIBILITY 2026-11-12 (v1.13.0)` marker (older bridges never name
  invocations), and reaches the session detail state the way
  `supportsPromptAttachments` does. A plugin opts in only when its live
  command echo carries the command's prompt id. Step 2 opts in Codex, Claude
  and every ACP-family descriptor. OpenCode and Pi wait for their own steps.
  The app renders the card if and only if:
  - local sending: the plugin capability is set and a command is staged. A
    command without a known source is a "Custom" card from the start, as the
    bridge names it (user, round 2 Q3 C: never a bubble that turns into a
    card);
  - bridge-queued: the plugin capability is set and the bridge gave the
    entry a `commandSource`, which it does only for a command it sent and
    will name;
  - confirmed: `invocation != null`.
  Otherwise it renders today's bubble, for the whole turn.
- **P8 Card content.** The card shows `invocation.arguments`, not the
  message's text parts. The text parts still hold `/name args` or, on
  OpenCode 2 native commands, the expanded template, for older apps.
  Attachments (file parts) render inside the card. The status rail
  (Sending…, Queued + Cancel, failed + Retry/Remove) stays under the card,
  aligned with its leading edge, so the card's own size never changes between
  states (D6).
- **P9 No analytics.** Showing a card answers no product question that the
  existing send events don't already answer. Command sends are already an
  authoritative action, so no new event is added.

## Current Behavior (verified in code, 2026-11-12)

- A confirmed user turn is `Message.user` (`id`, `sessionID`, `agent`,
  `time`, `promptId`) plus text parts. Nothing names the command.
  `UserMessageCard` renders every `MessageUser` as a right-aligned
  `UserMessageBubble`. The pinned prompt (`TranscriptStickyPromptOverlay`, a
  custom render object) repaints `UserMessageBubbleContent` on a bubble-shaped
  surface. The prompt list reads `SessionPromptIndexEntry.preview`.
- Sending is structured: `SendPromptRequest.command`,
  `CreateSessionRequest.command`, `QueuedSessionPrompt.command`, and
  `BridgePlugin.sendCommand(promptId, command, arguments, userVisibleArguments)`.
  `SessionPromptService._sendPrompt` and `SessionCreationService._maybeSendCommand`
  both go through `SessionRepository.sendCommand`. Locally, the app keeps
  `QueuedSessionSubmission.command(command: String)` and
  `NewSessionCommandSubmissionSnapshot`. `QueuedMessageBubble` shows "Queued
  command" under a terminal icon.
- Live user messages flow plugin → `SessionEventService` normalization
  (`toNormalized` → `_observeBusy`) → both `ChatHistoryListener._capture`
  (`upsertMessage`) and orchestrator delivery. History reads are served from
  `chat_history.db`. A backfill (`ChatHistoryService._backfillSession` →
  `replaceSessionMessages`) replaces stored rows by id or by semantic match.
  It runs on first read, after the backend advanced, and after an event-stream
  reconnect clears `syncedAt`.
- Per-plugin facts (code reading on an older checkout; re-verify on `main`,
  and live, in each plugin step):

| Plugin | Live command echo carries the prompt id | Live id = history id | History names the invocation |
|---|---|---|---|
| OpenCode 1 | Yes (`opencode_plugin_impl.dart` id→promptId map) | Yes | No (server text) |
| OpenCode 2 | Native command: no (`POST …/command` takes no id); compaction: yes | Yes (prompt id encoded in the message id) | Skills: yes (#2540); native commands: no |
| Codex | Yes (`clientUserMessageId`) | Not guaranteed | Skills: yes (#2541) |
| Pi | Only when the echo equals `/cmd args`; expanded templates and skills miss | Yes (deterministic ids) | Skills: yes, `<skill name=…>` envelope (#2542); templates: no |
| Claude Code | Yes (synthetic dispatch message) | No (`sesori-user-N`; history drops the command envelope) | Name and arguments are in `<command-name>`/`<command-args>`, kind is not |
| ACP family | Yes (`$promptId-user`) | No (replay ids are synthetic) | The `/name args` text Sesori sent; Oh My Pi commands expand |

## Explicitly Excluded

- No new `MessagePart` type. No migration, backfill or new table. Sessions
  from before this change keep their bubbles (low-damage old-data rule).
- No new content matching for `invocation` beyond the store's existing
  replay match (P4).
- No session-options-cache lookup of a command's kind (P2).
- No tap action, disclosure or description sheet (D2).
- No change to prompt search semantics (P6).
- No analytics (P9).

## Architecture (Phase 1)

### Step 2: wire and bridge core

Shared (`shared/sesori_shared`):

- `models/sesori/command_invocation.dart` defines the Freezed
  `CommandInvocation`. It is exported from the package.
- `Message.user` gains `invocation` (P1).
- `SendPromptRequest` and `CreateSessionRequest` gain `commandSource` (P2).
- `QueuedSessionPrompt` gains `commandSource` (P5).
- `SessionPromptIndexEntry.opener` and `.followUp` gain `invocation` (P6).
- `PluginMetadata` gains `namesCommandInvocations`, with `@Default(false)` and
  its marker (P7).
- Tests: JSON round-trip, an older payload without the fields parses to
  `null`/`false`, and an unknown `source` string parses to `unknown`.

Bridge core (`bridge/app`, `bridge/sesori_plugin_interface`):

- `CommandInvocationTracker` lives in
  `bridge/app/lib/src/repositories/trackers/command_invocation_tracker.dart`,
  beside `SessionEventTracker`. It is an in-memory, bounded (256 entries, oldest evicted) map from
  `(sessionId, promptId)` to `CommandInvocation`. Its owner is
  `SessionRepository`, which constructs it, writes it in `sendCommand`, and
  exposes reads only through `stampLiveInvocation({required Message message})`
  and `stampQueuedCommandSources({required String sessionId, required List<QueuedSessionPrompt> prompts})`.
  `SessionRepository.sendCommand` gains `required CommandSource? commandSource`
  and registers the entry before the plugin call. It registers before the call
  because the echo can arrive before acceptance returns. A send the plugin
  definitely refuses (a 4xx-class `PluginOperationException`) removes its
  entry again. A send whose outcome is unknown (timeout, 5xx, no status)
  keeps it, as the harness may still run it and its late echo must come
  back named. It registers only when the session's plugin
  declares `namesCommandInvocations`, so a plugin that does not name its runs
  never has a turn turn from a bubble into a card. The tracker has no
  lifecycle hooks and no timers.
- `SessionPromptService.sendPrompt`, `SessionCreationService` and their
  route handlers pass `commandSource` through.
- `SessionEventService._observeBusy` stamps
  `NormalizedMessageEvent(MessageUser)` through
  `_sessionRepository.stampLiveInvocation` (P3).
- `ChatHistoryRepository.upsertMessage` carries over a stored invocation the
  update lacks. `replaceSessionMessages` does the same for each imported
  message the store matches to a stored row, by exact id or by its existing
  content match, with the plugin's value winning. `_semanticMessageFingerprints` excludes
  `invocation` (P4). The DAO gains the small row read that `upsertMessage`
  needs.
- Queued prompts are stamped in two places (P5):
  - Live: `SessionEventMapper` (`repositories/mappers/session_event_mapper.dart`)
    normalizes `BridgeSseQueuedPromptsUpdated` into a new
    `NormalizedQueuedPromptsEvent({required String sessionId, required List<QueuedSessionPrompt> prompts})`
    in `normalized_bridge_event.dart`. `SessionEventService._observeBusy`
    fills `commandSource` through `_sessionRepository.stampQueuedCommandSources`, the
    same way it stamps messages. Orchestrator delivery emits
    `SesoriSseEvent.sessionQueuedPrompts` from that normalized value, and
    `BridgeEventMapper` (`sse/`) drops its queued-prompts branch, so `sse/`
    never reads a repository.
  - Read path: `SessionRepository.getQueuedPrompts` fills the field inside
    the repository.
- `PromptIndexMapper` copies `invocation` (P6).
- `BridgePluginDescriptor.namesCommandInvocations` defaults to `false`.
  `PluginLifecycleService` and `BridgeRuntimeRunner` report it, and the Codex,
  Claude and ACP-family descriptors (Cursor, Copilot, Grok, Hermes, DeepSeek,
  Antigravity, Oh My Pi) override it to `true` (P7). None of those descriptor
  files is touched by #2541 or #2542.
- `Message.user(...)` call sites (about 65, mostly tests) gain
  `invocation: null`. `PluginMessage.user` doesn't change in this step.
- Tests:
  - tracker stamping and eviction;
  - stamping through `toNormalized`, reaching both capture and delivery;
  - upsert carry-over, and replace carry-over with the plugin value winning;
  - fingerprint exclusion, so a stamped live row still matches its replay
    and isn't retained twice;
  - `commandSource` on both queued paths;
  - prompt-index `invocation`.

### Step 3: the card in the transcript

Client (`client/module_core`, `client/module_app_ui`):

- `module_core`: the staged command keeps its `CommandInfo.source`.
  - `QueuedSessionSubmission.command` and `.unavailableCommand` gain
    `required CommandSource? commandSource`.
  - `NewSessionCommandSubmissionSnapshot` gains the same.
  - The send API passes it as `SendPromptRequest.commandSource` /
    `CreateSessionRequest.commandSource`.
  - `PluginMetadata.namesCommandInvocations` reaches every state that
    renders a sending row. It reaches `SessionDetailLoaded` beside
    `supportsPromptAttachments`, through the session detail load snapshot.
    It reaches the new-session launch through `NewSessionCubit`, which reads
    the selected plugin's metadata.
  - The P7 rule lives in one pure calculator,
    `PromptTurnShapeCalculator`, in
    `client/module_core/lib/src/cubits/session_detail/`. It returns a sealed
    `PromptTurnShape`, with variants `PromptTurnShape.invocation(name, source, arguments)`
    and `PromptTurnShape.bubble()`. It is computed for confirmed messages,
    bridge-queued prompts, local submissions and launch submissions.
  - `SessionDetailCubit` applies it and puts the resolved shape in emitted
    state, for each prompt row and the launch follow-ups. `NewSessionCubit`
    does the same for the launch submission, carried on
    `SessionLaunchHandoff`.
  - Widgets in `module_app_ui` only switch on the sealed shape and never
    apply the rule themselves.
- `module_app_ui`: the new `InvocationCard` widget.
  - Leading-aligned, fits its content up to `UserMessageBubble.maxContentWidth`.
  - Header: `PregoTag` with a per-source icon and label (D3). Then "You ran
    /name" in the header text style, then the arguments as Markdown inside
    `PregoReadableSelectionArea`, then attachments.
  - No `InkWell` or `GestureDetector`. One `Semantics` label (for example
    "You ran skill fixture-greeter") with the arguments as readable text,
    no button role.
  - A pending outline animates as the bubble's does (240 ms, zero with
    reduced motion).
- `UserMessageCard`, `QueuedMessageBubble`, `SessionLaunchSubmissionView` and
  the launch/follow-up rows in `SessionDetailMessageList` pick the card or the
  bubble by switching on the `PromptTurnShape` the state carries. The status rail goes under the card, at its
  leading edge (P8). The existing `_animatedPromptRow` height easing stays.
- Copy: new ARB strings for "You ran /{name}" and the semantics label; the
  kind labels reuse `commandSource*`. Run the l10n generator.
- Tests: `PromptTurnShapeCalculator` unit tests, cubit tests that the
  shape reaches state, and widget tests that:
  - no tap, press or ink feedback;
  - semantics, with no button role;
  - the same card size across sending, queued and confirmed;
  - an old-bridge fallback to the bubble.
  Goldens or screenshot tests at phone and desktop widths: a command with no
  text, a skill with multi-line text, between normal turns.

### Step 4: pinned prompt and prompt list

- `TranscriptStickyPromptOverlay` / `RenderTranscriptStickyPrompts` learn a
  second pin geometry for an invocation opener. They paint the card's surface
  and content at the leading edge, pixel-identical to the row, the way the
  bubble pin copies `UserMessageBubbleContent` today. The opener's slot
  registration (`TranscriptPromptSlot`) carries which geometry applies.
- The prompt list (`transcript_prompt_list.dart` and its view) renders an
  entry with `invocation` as the kind icon, `/name` and the arguments. It
  falls back to `preview` when `invocation` is null.
- Tests:
  - the pin's geometry matches the row, at phone and desktop widths;
  - the pin and the card produce identical goldens;
  - prompt-list rows.

## Later Phases (rough intent only)

- **Plugin interface plus OpenCode.**
  - `PluginMessage.user` gains a plugin-side invocation, mapped in
    `plugin_message_mapper`.
  - OpenCode 2 native commands get a live prompt-id correlation for the
    command's user message, so core stamps them and stable ids carry the
    stamp across reloads. `POST …/command` takes no id, so the plugin's
    `OpenCodeV2CommandEchoTracker` gives the first inbox message admitted
    without a Sesori prompt id, while the command request is outstanding,
    that command's prompt id (accepted: a TUI message admitted in that same
    moment would take the name).
  - OpenCode 2 skills are named from history.
  - OpenCode 1 already echoes commands with their prompt id (Sesori names the
    message id), so it needs no change and the one shared descriptor opts in
    honestly for both protocols.
  - Opt in the descriptor.
- **Codex** (after #2541). Name skills from rollout history. Because ids are
  unstable, history fill is the persistence path.
  - The plugin names a skill from the `skill` input on the live `userMessage`
    item and on the rollout's `UserMessage` item, with the same rule that
    rewrites `$name args` to `/name args`, so a skill picked in the Codex CLI
    is named too.
  - The live echo carries the prompt id (`clientId`), so the descriptor's
    opt-in holds (verified live with Codex 0.167.2).
  - `/compact` is Codex's only command and adds no user turn, so there is no
    command to name.
- **Claude Code.**
  - Name commands from `<command-name>`/`<command-args>` in history (today
    dropped). Resolve the kind from the plugin's own command list, else
    `unknown`.
  - The synthetic live row and the history row collapse by exact id: the CLI
    records a command's envelope under the uuid of the stdin frame that sent
    it, so the live row takes that uuid instead of `sesori-user-N`. Claude
    records a command after the compaction it ran into, so history keeps it
    above that compaction row, where the live row sits.
- **ACP family.**
  - Name invocations from the `/name args` text Sesori sent, matched against
    the advertised commands, in the replay.
  - DeepSeek `/plan <text>` and Hermes `/queue <text>`: fold the
    harness-created argument turn, which Hermes stores before the command,
    into the invocation, so the card is the single representation.
- **Oh My Pi.** Verify live, then fix what is real:
  - a kept live row landing below the reply (the replay has no timestamps);
  - a kept live row dropped by a reload that doesn't mark the session out of
    sync;
  - a skill with an image showing the injected skill text;
  - skills looking right only because the replay skips a plain-string
    message.
  - Oh My Pi sessions listed from a Pi folder on a bridge with an empty store
    show the raw `<skill name=… location=…>` envelope as the user turn. Parse
    it as Pi's `PiPersistedUserTextCodec.decodeSkillRun` does (#2552).
  Commands after reload need the bridge's record despite unstable ids.
- Each plugin step records its result in `docs/HARNESS_CAPABILITIES.md`.
- **Regression docs** reconcile `session-turns.md`, `transcript-turn-navigation.md`
  and `session-history-and-recovery.md`.
- **Retirement** runs the matrix below and moves the plan.

## Complexity Budget

New mutable parts:

- `CommandInvocationTracker`: one in-memory bounded map owned by
  `SessionRepository`. It is needed because no other bridge-core owner knows
  which prompt id was a command at the moment its echo arrives.

New persistent parts: none. The invocation is a field of the already-stored
`Message` JSON.

Deliberately not added:

- a new database table;
- options-cache kind lookup;
- tracker eviction hooks or timers;
- a client-side parser of `/name`;
- a client-side merge of `invocation` across message updates (the bridge's
  stamp already covers re-emitted updates while the entry lives).

## Cleanup Assessment

- Step 3 removes the `isCommand` "Queued command" variant of the terminal
  icon only where the card replaces it. The bubble fallback for old bridges
  keeps it.
- No other obsolete code was found. The `/name args` text in plugins stays
  for older apps (D7).

## Proportionality And Accepted Risk

- **Tracker eviction.** After 256 newer commands across sessions, an
  evicted entry's late re-emitted echo is no longer stamped live. The store
  keeps the invocation (P4 upsert carry-over), but an open screen could
  render that one update as a bubble. Reaching that would need a re-emitted
  echo after 256 newer commands. No current flow produces one. Accepted.
- **Older app sending a command.** A newer surface watching the same session
  shows the "Custom" label. Accepted.
- **Between steps 2 and the plugin steps**, a turn with no exact-id or
  content match in the replay can still lose the card after a backfill: an
  OpenCode 2 native command or Oh My Pi command whose replay holds the
  expanded prompt, or a Claude command that history drops. A reconnect clears
  `syncedAt`, and the next read re-imports. Internal builds only, fixed by
  each plugin's step. Accepted inside the series.
- **Between steps 3 and 4**, a pinned invocation opener still shows the
  bubble pin. Steps 3 and 4 should merge back to back. Accepted inside the
  series.

## Regression Coverage

- Affected feature docs:
  - `docs/regression/session-turns.md`: card states, kinds, persistence;
  - `docs/regression/transcript-turn-navigation.md`: pin and prompt list;
  - `docs/regression/session-history-and-recovery.md`: card after reload,
    backfill and restart.
  - Steps 2–4 add their entries only if #2541/#2542 have merged by then,
    otherwise the regression-docs step adds them.
- Highest level: **L3 Release** for session turns, because sending a
  command is a critical journey across the production plugins. **L4** adds
  recovery: bridge restart, event-stream reconnect backfill, archived-session
  read.
- Matrix:
  - Platforms: headless iOS simulator via `sesori-local-testing`; desktop
    width through golden/screenshot tests (no macOS run).
  - Plugins, each for a command, a skill and an MCP prompt where the harness
    offers them, with no text and with text: OpenCode 2, Codex, Pi, Claude
    Code, Cursor, Copilot, Grok, Hermes, DeepSeek, Antigravity, Oh My Pi.
  - States: sending, queued with cancel, confirmed, reopened, after a bridge
    restart, after a reconnect backfill.
  - Compatibility: a new app against the previous production bridge shows
    bubbles; the previous production app against the new bridge shows
    bubbles.
  - Live model access goes through the local test proxy; a harness without a
    usable runtime is reported `Blocked`, never silently dropped.

## Delivery Rules

- PR titles: `<emoji> [invocation-view] <description> [step x/12]`. Body
  sections: Complexity, What, Why, Risk and test focus, Expected result,
  Verification.
- Soft cap: about 1,500 changed lines; report generated against authored
  lines.
- UI PRs carry phone and desktop screenshots made from fixture data, hosted
  on `pr-media` under `<pr-branch>/`.
- Worktrees only under `~/.claude-worktrees/sesori_apps_monorepo/<name>`.
- Run `architecture-implementation-review` (at most twice) on steps 2, 3
  and 4 and on the plugin-interface step.

## Steps

| Step | Title | Target (changed lines) | Needs |
|---|---|---|---|
| 1 | 🌱 [invocation-view] Raise the plan [step 1/12] | ≤ 450 | — |
| 2 | 🚧 [invocation-view] Name command and skill runs on the user turn from the bridge [step 2/12] | ≤ 1,500 (~400 generated) | — (base `origin/main`) |
| 3 | ⚙️ [invocation-view] Show command and skill runs as an event card [step 3/12] | ≤ 1,300 (~150 generated l10n) | 2 |
| 4 | ⚙️ [invocation-view] Pin and list command and skill runs as their card [step 4/12] | ≤ 900 | 3 |
| 5 | ⚙️ [invocation-view] Name OpenCode command and skill runs [step 5/12] | ≤ 700 | 2, #2541, #2542 merged |
| 6 | Codex naming from history | rough | 5 |
| 7 | 🌿 [invocation-view] Name Pi command and skill runs [step 7/12] | ≤ 200 | 5 |
| 8 | Claude Code naming from history | rough | 5 |
| 9 | ACP-family naming and the DeepSeek/Hermes argument turn | rough | 5 |
| 10 | Oh My Pi findings | rough | 9 |
| 11 | Regression docs | rough | 2–10 |
| 12 | Retire after the matrix run | rough | 11 |

## Open Questions

None blocking. The visible choices are settled by D1–D8. Detail picked within
them: the kind icons, and keeping the status rail under the card rather than
in its header. They are reported to the user for a veto.

## Plan Review Record

- **2026-11-12, `architecture-plan-review` (sub-agent): rejected.** It
  raised three findings, all applied directly as the review skill
  prescribes, without a second review:
  1. The in-memory registry was renamed `CommandInvocationTracker` and
     moved under `repositories/trackers/`.
  2. Live queued prompts are stamped through a new
     `NormalizedQueuedPromptsEvent` in the normalization path, not in `sse/`.
  3. The card-or-bubble rule became `PromptTurnShapeCalculator`, applied by
     the cubits into emitted state, with the capability reaching the launch
     state too.
  The reviewer found the rest compliant:
  - the wire shape (a field, not a part; `@Default(false)` with its marker);
  - the plugin capability on the descriptor;
  - history carry-over in `ChatHistoryRepository`;
  - no timers or extra abstractions.
