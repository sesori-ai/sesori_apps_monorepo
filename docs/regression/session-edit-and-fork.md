# Session Edit And Fork

## Capability

Every user prompt with text, command card with arguments and agent reply in a
transcript has a message menu, on phone and desktop alike, and so do queued
prompts and the pinned prompt. It holds what can be done with that message:
Edit and resend on a user prompt or command card, Fork from here where a fork
can start, then Copy and Select text. Copy and Select text are client-only;
they send nothing to the bridge.

The bridge can edit a prompt that opens a turn: `POST /session/rewind` removes
that prompt and every later message from the session's conversation and sends
the edited prompt in its place. Conversation only: files are never restored.
Each harness declares the branching operations it implements in
`PluginMetadata.sessionBranching`; today Claude Code and Codex declare `rewind`.
A first-message edit needs no plugin rewind, so the route accepts it on every
harness. Clients offer Edit and resend only where the session's harness
declares `rewind`, so a bridge that does not declare it shows no Edit.

The bridge can also fork: `POST /session/fork` creates a new root session whose
conversation is the origin's up to a turn boundary, in the same directory or
worktree, and leaves the origin unchanged. Claude Code and Codex declare
`fork`; on every other harness only a fork that keeps nothing (before the
first turn) succeeds today. Clients offer Fork only where the session's
harness declares `fork`.

## Required Behavior

### Message menu

- Under a finger or stylus, a long-press of about 0.4 s on a user bubble, a
  command card, a queued prompt or an agent reply opens a flat menu anchored
  to the message. It
  gives a light haptic and keeps the message sharp while the rest of the
  screen blurs back. Under a mouse or trackpad, a secondary click opens the
  compact menu at the pointer, with no blur and no haptic.
- The menu never moves the transcript. While it is open the transcript holds
  still, as when reading history, so a reply streaming in neither grows past
  its cut-out nor carries the message out from under the menu. Opening the
  menu does not bring up the Jump to latest pill; a reader already in history
  keeps theirs. Once it closes, a transcript that was following the latest
  edge follows it again and shows what streamed meanwhile, even when the
  message itself went while the menu was open (a queued prompt delivered).
- The pinned prompt's cut-out matches its bubble or card.
- While some of the message's text is selected, the copy item reads "Copy
  selected text" and copies only the selection, all of it when it runs on
  into other messages; a message outside the selection still offers Copy. Opening the menu, closing it
  and copying all leave that selection highlighted exactly as it was: a
  shift-click afterwards extends it, and a click elsewhere still clears it. With nothing selected the item reads "Copy" and
  copies the message's Markdown: a user prompt's text or a
  command's arguments, or the reply's text parts joined by blank lines, with
  streamed text as shown. A "Copied to clipboard" alert confirms it. A reply
  with no text has no Copy.
- Select text closes the menu and selects all of the message's text and
  nothing beyond it, with the selection's handles and toolbar, which can then
  extend it into the messages around it. Tapping elsewhere clears that
  selection.
- A long-press or right-click on the pinned prompt opens that prompt's menu,
  never the menu of the message under the pin. It has only Copy, which copies
  the whole prompt, not the pin's cut copy; a tap on the pin still jumps to
  the prompt.
- A prompt with only attachments, or a command with no arguments, has a menu
  only when it offers Edit and resend; otherwise there is nothing to copy or
  select. The pinned prompt's menu has no Edit.
- A long-press no longer selects a word. A held primary mouse button on a
  message still drag-selects, and a secondary click wins over the selection
  area's own right-click toolbar.
- Taps, one-finger scrolls, the timestamp peek, a code block's horizontal
  scroll and a pinch to Prompts all behave as before when they move or add a
  finger before the long-press fires.
- A session row's long-press and right-click menu uses the same trigger, and a
  screen reader still offers the row's long-press as an action on the row.
  A click opens the session; holding the mouse button down on a row does
  nothing, with no menu and no highlight, since rows are not selectable text.
- A screen reader offers the pinned prompt's menu as a long-press around the
  pin, which it can still activate to jump.

### Client edit and resend

- Edit and resend shows on every user prompt and command card of a live,
  continuable session whose harness declares `rewind`, outside the turn that
  is running, and not in read-only, archived or blocked sessions. The first
  prompt edits like any other.
- A prompt sent while a turn ran, or a command, skill or MCP prompt invocation,
  still shows Edit; tapping it opens a popup explaining why it cannot be edited, with OK,
  plus Fork from here for a mid-turn prompt in a session that forks (see Client fork).
- Edit sets aside what the composer held (text, attachments, staged command),
  brings the prompt's text and attachments back into the composer and focuses
  it. The prompt's bubble takes an outline, and a banner over the composer
  says Resend replaces this message and everything after it, with Cancel.
  Attachments the computer can no longer provide are counted in the banner.
  The banner grows in and folds out with the composer's motion; under reduced
  motion it appears at once.
- Cancel, or Escape on a keyboard, gives the composer back exactly what it held.
  Nothing typed during an edit is saved as the session's draft. The menu of
  the message being edited offers no Edit.
- Send reads Resend. On an idle session it sends the edit; on acceptance the
  composer gets back what it held and the edit's echo arrives as the new
  prompt, while the removed messages fold out of the transcript.
- While a turn runs, Resend opens a popup offering Stop and resend or Cancel.
  Stop and resend stops the session, sub-agents included, waits until it is
  idle (up to 15 s), then sends; the banner reads Stopping, then Sending. A
  stop that fails or does not finish keeps the edit and says so.
- While the edit is Stopping or Sending, the composer dims to 60 % opacity and takes
  no input: typing, paste, drops, adding or removing attachments, voice and the
  expanded editor all answer with "Sending your edit. You can type again in a
  moment." instead, and so does a tap anywhere on it. A focused field keeps the
  keyboard up, so nothing moves. The dimming fades in and out over about
  200 ms, at once under reduced motion. Phone and desktop share this through
  the composer.
- A refusal (no branch point, another device's edit, refused by the harness)
  keeps the edit open with its text and shows the bridge's reason. Stale
  options reload the composer's options and keep the edit. A lost answer keeps
  the edit, and a retry reuses the same prompt id, so the bridge never applies
  one edit twice.
- `session_message_edited` records each answered Resend with the harness and a
  closed outcome: succeeded, refused_busy, branch_point_unavailable, refused
  or failed.

### Client fork

- Fork from here shows on a user prompt or command card, after Edit and
  resend, and on the last agent reply of a finished turn, in a top-level
  session whose harness declares `fork`, archived or read-only sessions
  included. It never shows in the turn that is running, on an earlier reply
  of a turn, or in a sub-agent's session.
- On a prompt that opens its turn the fork keeps everything before that turn
  (`beforeMessage`); on a follow-up sent mid-turn it keeps that whole turn, and
  on a reply it keeps everything through the reply (`afterMessage`). Forking
  from your own prompt or follow-up puts its text and attachments in the
  fork's composer, ready to send or change; the origin's composer is left
  alone.
- The session's ⋯ menu on phone and desktop, and a session row's long-press
  and right-click menu, offer Fork before Archive, for the latest finished
  turn (`latest`). An archived session offers it too.
- A fork that takes longer than 300 ms shows a Forking alert until the bridge
  answers. On success the fork's page opens, titled `<origin title> (fork)`;
  having left the origin meanwhile, the fork waits in the session list.
- Nothing to fork, a refusal (with the bridge's reason when it gives one) and
  a failure each answer with an alert, and nothing opens.
- When an archived origin's worktree is gone and kept nothing, a sheet asks
  whether to create a new worktree from where the session began; Create
  retries the fork that way and Cancel forks nothing.
- Edit and resend on a follow-up sent mid-turn explains why it can't be
  edited; in a session that forks, the explanation also offers Fork from here
  (`afterMessage`, the follow-up's text and attachments in the fork's
  composer), which closes it and runs the same fork. Otherwise it offers OK
  only, and a command's explanation never offers Fork.
- A fork's transcript starts with a quiet centred "Forked from <origin
  title>" line ("Forked from an untitled session" when the origin had no
  title), shown above the oldest message only once no older page is left to
  load. A tap reads the origin first, so an archived origin opens read-only
  from the start, and returns to it: back when the origin is the page below
  (phone) or the previous page (desktop), so origin, fork, origin never piles
  up; otherwise the origin opens. The phone pushes it, so back returns to the
  fork. Desktop selects it and replaces the page stack, as the parent-session
  link does. An origin that can't be read, such as one deleted since the page
  loaded, answers the tap with "Couldn't open that session". Once the
  origin's deletion reaches the fork, the line stays as plain text and a tap
  does nothing.
- `session_forked` records each answered fork with the origin's harness and a
  closed outcome: succeeded, branch_point_unavailable, refused or failed.

### Removed messages fold away

- When the bridge removes messages (`message.removed`), as an edit does to the
  edited prompt and everything after it, from this device or another, each
  removed row that was built, on screen or just out of view, folds away where
  it was, as it last looked: its height shrinks while it fades and slides up a
  little, over about 200 ms. Several removals in a row fold together. A row
  that was never built goes at once.
- Following the latest edge, the rows above ease down as the rows below fold,
  and the list stays at that edge.
- Following, rows removed while nothing is joining keep their room for up to
  300 ms, until the edit's prompt or the Working row starts to grow, and then
  fold as those grow. A device watching another's edit hears the removals some
  frames before the turn starts, and the rows above must move one way only,
  never down and then back up. With nothing to replace them they fold after
  the wait.
- Reading history, the removals still reach the frozen transcript, and the
  rows being read stay exactly where they are on screen while rows below or
  among them fold; only when the fold reaches the newest edge does the list
  follow again. Removed rows above the reader fold without moving anything.
- A new prompt that arrives with the removals, such as the edit's echo, even
  one that arrives before them, shows below the rows folding away and eases in
  as any arrival does.
- On the device that sent the edit, its prompt shows as soon as the bridge
  accepts it, above the Working row, which rises with it even before the busy
  status arrives, both while the removed rows fold; a later echo takes that
  row in place. Following the latest edge, the rows above settle in one move
  down, never springing back up when the echo or the busy status lands late
  (Codex echoes 10 to 100+ ms after the removals, and its busy status can lag
  them by tens of milliseconds). Other devices still show the prompt only once
  its echo arrives.
- Under reduced motion removed rows go at once.
- A refresh that replaces the transcript never folds rows away: a live row
  swapped for its history twin stays in place, and history the refresh drops
  goes at once. Neither does a prompt row turning into its message.
- The pinned prompt, the Working row and prompt numbering follow the
  transcript without the removed messages from the moment they are removed;
  only their rows linger while folding.

### Bridge edit route

- The edit runs on the session's lane, so it never interleaves with a send,
  stop or archive of the same session.
- An archived session answers the archived read-only rejection without
  reaching the plugin.
- The request carries a client-generated prompt id. A repeat of an accepted id
  succeeds without reaching the plugin, even after the rewind removed the
  edited message.
- A running session is refused with `sessionBusy`. This and the turn checks
  below run before anything changes, a pending quota auto-continuation
  included.
- The bridge reads the whole stored transcript, backfilling it first when the
  store is behind the backend, and finds the message's turn by the shared
  `splitPromptTurns` rule. A message that does not open a turn (a reply or a
  follow-up) is refused with `branchPointUnavailable`.
- An edit of the first turn never reaches a plugin rewind, so it works on
  every harness. The bridge creates a new harness session in the session's
  directory with the edited prompt as its first prompt (with the worktree
  context, for a dedicated worktree) and moves the same Sesori session onto
  it in one transaction. The new harness session's events reach clients under
  the unchanged session id, with no `session.created`. On Claude Code and
  Codex the edited prompt reaches clients no later than the removal of the old
  rows, so the transcript never shows only Working between them: Codex's
  running app-server echoes it at once, and Claude Code shows a new session's
  first prompt as soon as it is written, without waiting the seconds a new
  CLI process takes to echo it.
- The old harness session is deleted the way a session delete does it: it and
  its sub-agent sessions are tombstoned in that same transaction, so catalog
  import and startup cleanup never bring them back, and their sub-agent rows
  and history are removed. Its late events and `session.deleted` change
  nothing. A failed backend delete is only logged; the edit still succeeds.
  A row catalog import already bound to the new harness session is replaced.
- A harness that cannot rewind, or whose plugin cannot map the message to a
  native boundary, is refused with `branchPointUnavailable`. The plugin's own
  user-facing sentence travels as the message; transcript text never does.
- Stale prompt options answer `staleSessionOptions` after the options cache is
  invalidated; a plugin refusal answers `refused`.
- Every branch refusal is a 409 `SessionBranchErrorResponse` and leaves the
  transcript untouched; the archived rejection keeps its own shared shape.
- After the plugin accepts (or the new harness session is bound), the bridge removes exactly the messages it read
  before the call, by id, from the store and from clients
  (`message.removed`). The edited prompt's echo, captured during the call, is
  never among them.
- When the plugin fails after it may have rewound (anything other than a
  branch-point, stale-options or refusal rejection), the bridge reads the
  harness transcript once and removes, by exact id, the messages it read
  before the call that the harness no longer has, then returns the failure.
  A failure that changed nothing, or a harness read that comes back empty,
  removes nothing.
- An edit with no parts is rejected with 400 before anything changes.

### Claude Code edit

- The plugin finds the edited prompt on the transcript's active branch and
  resumes at its parent entry: it stops the idle process, respawns it with
  `--resume=<id> --resume-session-at=<entry>` and the edit's model, effort and
  permission mode, then sends the edited prompt with the same prompt id. The
  transcript changes only when that prompt is written; later respawns use plain
  `--resume`, which follows the edited branch.
- The edited prompt is queued before the session reports busy, so the Working
  row counts from the edit at 0 s during the respawn, never from a message the
  edit removes. A failed respawn, or a stop during the respawn, takes it out
  of the queue again.
- The session is held busy from the idle check until the edited prompt is
  sent: a second edit is refused as busy, and a send that arrives during the
  respawn runs after the edited prompt.
- Refused with a plain reason before the process is stopped: a prompt not on
  the active branch (or a session with no transcript), a prompt with no parent
  entry, and a prompt before the latest compaction, which the CLI cannot
  resume at.
- A CLI that does not know `--resume-session-at` exits at startup with
  `unknown option`; the edit is refused with a plain reason and a failed
  respawn is torn down, so the next prompt does not land on a rewound branch.

### Codex edit

- The edit maps the message to its native turn from the rollout's
  `UserMessage` items, resumes the thread if needed, calls
  `thread/revert {beforeTurnId}`, then starts the edited turn with the same
  prompt id. History follows the reverted rollout as soon as the edit is
  accepted.
- Refused with a plain reason without changing the conversation: a runtime without
  `thread/revert`, a legacy non-paginated thread, an ephemeral thread, an id
  the rollout does not have, a follow-up steered into a running turn, and an
  attachment or option the turn cannot take. A session 0.139.0 wrote has no
  `UserMessage` items, so its edit is refused as a session from an older Codex
  version (`legacySession`) before the runtime is asked.
- The edit's check reads the whole history, which for a session captured only
  live is its first import. 0.139.0 rollouts keep no reply ids or start times,
  so that import, like any other first import, pairs each replayed reply with
  its live row by content: the conversation keeps one copy of each reply, with
  its live time. A reply known only from the replay shows no time.
- If `turn/start` fails after the revert, the bridge reconcile above removes
  the reverted messages; the edit still fails and the client keeps its text.

### Bridge fork route

- The fork point is `afterMessage` (through the finished turn that holds the
  message, a mid-turn follow-up keeping its whole turn), `beforeMessage` (up
  to the turn the message opens) or `latest` (through the latest finished
  turn). Turns come from the whole stored transcript by `splitPromptTurns`,
  backfilled first when the store is behind; an archived origin is read from
  its archive record. Messages before the first prompt belong to no turn, so
  no fork keeps them.
- The fork runs on the origin's lane. The origin may be running: a point in
  the running turn is refused with `sessionBusy`, and an earlier finished turn
  forks. A message that is not a valid point is refused with
  `branchPointUnavailable`; `latest` with no finished turn, with
  `nothingToFork`. Only root sessions fork.
- A point that keeps messages calls the plugin's native fork through the last
  shown message of the kept turn; a harness without it, or one that no longer
  has the conversation (a pruned archived session), refuses with
  `branchPointUnavailable` and its reason. A point that keeps nothing creates
  an empty harness session on every harness; its first prompt, or a command's
  arguments, carries the worktree context as a new session's does.
- The fork is a new root row sharing the origin's project, directory,
  worktree, branch, base and prompt defaults, without its approval override.
  It is titled `<origin title> (fork)`, or untitled for an untitled origin,
  and `Session.forkedFrom` names the origin's id and title. Deleting the
  origin clears the id and keeps the title. A harness session the catalog
  already imported keeps its row and gains the fork columns. The fork's
  history is backfilled once it is created.
- A fork title too long for its line is cut before ` (fork)`, which stays
  whole: in the phone session header, the session list row, the desktop
  toolbar and breadcrumb, the command palette, the session picker and the
  send-to-session sheet. Screen readers still read the whole title.
- Archiving or deleting either session protects the shared worktree like any
  other sharing sessions.
- An archived origin whose dedicated worktree was removed gets it back at the
  same path before the harness is asked for anything, so the harness session's
  folder and the agent's remembered paths still hold, with the work committed
  there (see session-archiving-and-deletion.md for what archiving keeps). It
  checks out the branch the worktree was on when it still exists; otherwise
  it starts at the HEAD archiving pinned, on a new branch of that name or
  detached. A worktree that kept nothing (no branch and no pinned HEAD:
  removed by a bridge from before the pin, or its pin failed) answers
  `worktreeBranchMissing`; the retry with `recreateFromBase` adds it at the
  session's base commit (base branch for rows without one). A row with
  neither base field cannot be recreated and is refused with `refused`. A
  path that something other than a worktree of the project now holds (a
  folder, or a checkout of another repository), or a worktree git cannot
  add, is refused with `refused` and a plain reason.
  Refusals here create nothing. The archived origin is no sharer, so the
  fork's own archive or deletion that removes its worktree removes the
  recreated one.

### Claude Code fork

- The plugin writes the origin's active branch, through the last record of the
  turn that holds the message (parallel tool results included, rewound
  branches left out), to `<new id>.jsonl` beside the origin under the fork's
  id. The origin's file is only read and its process is never touched, so a
  later turn may be running; its records stay out of the fork.
- The fork has history at once and its first prompt resumes it with
  `--resume=<new id>`. The catalog lists it once, without the origin's
  sub-agents, and deleting it removes only its own transcript.
- A point before a compaction forks too: the fork keeps the full turns up to
  that point and leaves the compaction and everything after it behind, so it
  continues from the conversation that the compaction summarised.
- Refused with a plain reason before anything is written: a message off the
  active branch and an origin without a transcript.
- An empty fork has no transcript until its first prompt. After a bridge
  restart the bridge's directory hint marks it unstarted again, so its history
  reads empty and its first prompt starts it under its own id. Any bound
  Claude Code session without a transcript, such as one Claude Code pruned,
  reads the same way rather than as not found; forking it is still refused.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Message menu, automated widget tests: under touch, a long-press opens the spotlit menu with a light haptic and no word selection, while a tap and a drag open nothing; under a pointer, a secondary click opens the menu at the click with no spotlight, sees the drag selection made before it, keeps the selection toolbar shut, opens only the top item's menu where two overlap, and a held primary button opens nothing; Copy copies the Markdown or the selection and shows its alert; Select text selects the whole message; under a pointer, a selection survives the menu opening and closing, a shift-click afterwards extends it, and the item reads Copy selected text and copies only it; the reply's Markdown joins its text parts; a long-press on the pinned prompt copies that whole prompt, not the reply under it, and a screen reader reaches that menu; an open menu holds a streaming reply still and the list follows again once it closes, even when the item went meanwhile. Removal motion, automated widget tests: a removed row folds away while following with the rows above easing down; under reduced motion it goes at once; while detached a visible row and a built row out of view fold and an unbuilt row goes at once, all without moving the row being read by a pixel, and the reader's own drag during the fold moves the transcript by exactly the drag; an edit's echo and three removals in a row fold together with the echo below them; on the editing client an accepted edit's prompt, parked until its echo (cubit test, and not parked when the echo came first), shows above the working row before its echo, the echo replaces it in place, and the rows above settle in one move without springing back, both when the busy status arrives with the removals and when it lags them, since the working row rises with the parked prompt; a row whose message comes back mid-fold stays; following, removals that arrive three frames before the busy status and the edited prompt keep their room, fold as the prompt and Working row grow, and the rows above move one way only, and removals with nothing joining fold once the 300 ms hold ends; a refresh's history twins replace live rows with no fold. Bridge edit route, automated bridge tests with a fake rewind plugin: a later-turn edit removes exactly the read messages and keeps the echo captured during the call; a repeated prompt id succeeds without a second rewind; busy, non-opener, no-rewind harness, plugin branch-point, stale-options and archived refusals reach the right code before any change; a partial store backfills before validation; the route answers a refusal with a 409 `SessionBranchErrorResponse`; a failed resend after the harness rewound removes exactly the dropped messages, and a failure that changed nothing removes none. A first-turn edit binds the new harness session (with the worktree context in a dedicated worktree), tombstones and deletes the old one and its sub-agent rows and history, survives a failed old delete, replaces a stray imported row, and leaves the binding, rows and transcript untouched when the new session cannot be created; the event service releases the new session's held events under the old id and ignores the old session's late events. Codex plugin tests against a fake app-server: resume, revert and `turn/start` order with the prompt id; history follows the reverted rollout; steered, unknown-id, attachment and revert-error refusals happen before any revert. A bridge test replays a 0.139.0-shaped rollout over a live capture: the first import keeps one copy of each reply with its live time. Claude Code plugin tests against a fake CLI: the respawn's arguments and carried-over selection, then the prompt on the respawned process; a later plain `--resume`; an armed idle reap superseded; a second edit refused and a mid-respawn send ordered after the edit; no-entry, busy and unknown-option refusals before acceptance; the rewind point against recorded transcripts and a compaction. |
| L2 Routine (composer lock) | `prompt_input_lock_test.dart`: a locked composer dims to 60 % and answers a tap with its note, typing into a focused composer that locks changes nothing and keeps focus, attachments cannot be removed, and unlocking restores full opacity and typing. |
| L2 Routine (fork) | Client widget tests: the Forked from line shows only for a fork and only once the oldest page is loaded, returns to the origin only while it has an id, opens an archived origin read-only and alerts for one it can't read, the phone goes back to an origin page below instead of opening another, and desktop goes back to an origin below or otherwise selects it; Edit on a mid-turn follow-up hands its Fork to the explanation only where the session forks, and the explanation's Fork closes it and forks. Automated bridge tests with a fake fork plugin: each fork point keeps the right turn, a follow-up keeps its whole turn, `latest` skips a running turn, and busy, non-point, nothing-to-fork, no-fork harness, plugin reason and sub-agent refusals happen before anything is created; the fork row copies the origin's worktree and options, the origin's deletion clears the link and keeps the title, an imported binding is reused, an archived origin forks from its archive record, and an empty fork's first prompt alone carries the worktree context; an archived origin's removed worktree is recreated on its kept branch or at its pinned HEAD before the harness forks, a worktree that kept nothing answers `worktreeBranchMissing` and creates nothing until the `recreateFromBase` retry, and a taken path, a checkout of another repository or a failed add is refused; real-git repository tests recreate on a kept branch, after a hand-deleted folder (pruned), at a pinned detached HEAD after `gc --prune=now`, on a deleted branch from its pinned HEAD, from the base on a new branch and detached, and fail for a branch checked out elsewhere; a new session's worktree skips a path whose HEAD an archived session kept; a migration test covers the fork columns and their `ON DELETE SET NULL`. Codex plugin tests against a fake app-server: `thread/fork` names the native turn a reply or user message belongs to and leaves the source unloaded; the fork reads the kept history and lists once; unknown-id, missing-session, steered-turn and pre-0.143 runtime refusals happen before `thread/fork`, the pre-0.143 runtime reason winning over a message its rollout can't place, and its in-progress, unknown-turn and missing-rollout errors become reasons; deleting a source archives the rollouts its forks keep, and a thread no fork builds on archives nothing. Codex catalog tests on recorded rollouts: deleting an origin keeps the rollout its fork builds on, so the fork reads the same before and after a fresh catalog, and a later delete removes the rest. Claude Code plugin tests against recorded transcripts: the copied prefix for a linear, rewound and parallel-tool transcript, a running later turn left out, a fork from before and from after a compaction, the off-branch and missing-transcript refusals, a single catalog listing, a fork-only delete; against a fake CLI: the untitled created event, a `--resume` of the fork, and a restarted empty fork starting with `--session-id`. |
| L2 Routine (fork title) | `prego_kept_suffix_text_test.dart`: a long suffixed title cuts before ` (fork)` and keeps it whole, without overflow, centred as one line, with the whole title as its screen-reader label; a short one shows whole; a title without the suffix is a plain `Text`. |
| L3 Release | On a headless iOS simulator and on macOS: long-press and right-click a prompt and a reply, Copy each, and use Select text, while text streams and while reading history; the transcript must not move. On macOS, drag-select part of a reply, right-click it, and check the highlight stays through the menu; hold the mouse down on a session row and check nothing happens. On a headless iOS simulator against Codex and against Claude Code: edit the first and a later prompt of an idle session and check the bubble outline, banner and composer arrive without the transcript moving and the removed messages fold out; Cancel restores a half-typed draft; Resend during a running turn offers Stop and resend and completes. While it stops and sends, tapping, typing and pressing Enter in the dimmed composer each show the lock note, and nothing typed is kept. On a headless iOS simulator against Codex and against Claude Code: fork from a finished reply, from your own prompt (its text in the fork's composer) and from the ⋯ menu, check the fork opens titled `(fork)` with the right history and the origin unchanged, and fork an archived session. In the fork, scroll to its oldest message, tap "Forked from" and check it goes back to the origin without the transcript jumping, and that back from there does not return to the fork; open the fork from the session list and check the tap opens the origin. Fork from an archived session, then tap the fork's "Forked from" line and check the origin opens read-only without switching after it loads. Tap Edit and resend on a mid-turn follow-up and fork from its explanation. On macOS, right-click a reply and a session row and fork from each; tap a fork's "Forked from" line with the origin as the previous page (it goes back) and with the fork opened from the sidebar (it selects the origin). |
| L4 Extended | Long-press a message near the screen's edges and at the largest text size; open the menu during a pinch, a peek and a code-block scroll. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Try messages that are only an image, a command with no arguments, a reply
that is only tool steps, and a reply still streaming. Try a long-press with a
slight finger drift, and a right-click with a selection that spans two
messages. Long-press a pinned prompt over a reply, and a pin whose prompt is
not loaded yet.

## Failure Signals

- The transcript scrolls, jumps or stops following when the menu opens or
  closes.
- A long-press selects a word or shows the selection toolbar instead of the
  menu, or a right-click shows the selection toolbar.
- Copy copies the wrong message, stale streaming text, or the whole message
  while a part of it was selected.
- Select text leaves nothing selected, or the selection vanishes as the menu
  closes.
- A tap, scroll, peek, pinch or code-block scroll opens the menu.
- An edit removes the edited prompt's echo, or leaves a removed message on
  screen until reload.
- A removed row vanishes in one frame instead of folding, folds under reduced
  motion, or stays on screen after its fold.
- While reading history, a removal moves the rows being read, or a row
  removed below the screen is still there on returning to the latest edge.
- A refresh folds rows away, or a re-keyed row (a history twin, a prompt row
  turning into its message) plays a fold.
- The edit's echo shows above the rows it replaces while they fold.
- A retried edit rewinds twice.
- A refusal changes the transcript, or its message carries transcript text.
- After a first-message edit the session shows twice, the old conversation
  comes back after a catalog refresh or restart, or the new prompt's replies
  never arrive.
- After a first-message edit the old rows go before the edited prompt shows,
  leaving only Working, or a new Claude Code session shows its first prompt
  twice.
- A Codex edit whose resend failed leaves the reverted messages on screen.
- A Claude Code edit continues from the old branch, or a later prompt lands on
  a rewound branch the edit never used.
- An edit reaches the plugin while the session runs or after it was archived.
- Edit shows for a harness without `rewind`, or a tap on Edit does nothing.
- Cancel or a finished edit loses the draft the composer held before the edit,
  or the edit's text is saved as the session's draft.
- A refused edit loses the edited text.
- Input given while an edit is Stopping or Sending is taken and then lost, or
  is refused without the note.
- A fork changes its origin, includes part of a running turn, or loses the
  worktree its origin uses.
- A Claude Code fork shows the origin's later or rewound messages, keeps a
  compaction from after its fork point, is listed twice, deletes the origin's
  transcript or sub-agents, or answers "not found" for an empty fork after a
  bridge restart.
- Fork from here shows in a running turn, on a reply that does not end its
  turn, in a sub-agent's session or for a harness without `fork`; a tap on
  Fork answers nothing; the fork's composer misses the prompt it was forked
  from, or the origin's composer changes.
- The "Forked from" line shows on a session that is not a fork, before the
  oldest page is loaded, more than once, or moves the rows being read as it
  arrives; a tap on it piles another origin page over the stack, opens the
  wrong session, or a deleted origin's line still reacts.
- The mid-turn explanation offers Fork where the session cannot fork, or its
  Fork forks from the wrong point or leaves the explanation open.
- A fork of an archived origin whose worktree was removed points at a missing
  folder, lands in a folder something else holds, or leaves a worktree behind
  after a restoration refusal.

## Known Limitations

- Select text selects the whole message, not the word under the press:
  Flutter has no public API to select a word at a point.
- A pinned prompt that is not loaded yet has no menu, since only its start is
  known; a long-press on it reaches the message under the pin.
- A long-press tooltip inside a message no longer shows, because the menu
  takes the long-press first.
- Only Claude Code and Codex implement rewind; every other harness refuses an
  edit after the first turn.
- Claude Code cannot edit a prompt from before the latest compaction.
- Only Claude Code and Codex implement native fork; on every other harness
  only a fork that keeps nothing succeeds.
- Codex forks only whole native turns, so a fork through a reply that a
  steered follow-up continued in the same native turn is refused.
- Deleting a Codex session keeps the rollouts a fork's history builds on and
  archives them in Codex, so the session leaves Codex's thread list. When the
  app-server is not connected at the delete, it stays listed there (not in
  Sesori).
- Those archived rollouts stay in Codex's archive after the last fork that
  needs them is deleted.
- Uncommitted changes in a worktree that archiving removed (forced) are not
  kept, so the recreated worktree lacks them.
- A worktree removed before archiving pinned HEADs (or whose pin failed),
  whose branch is gone, can only be recreated from the base: it starts where
  the session started. A row with no base at all cannot be recreated.
- A worktree recreated for a fork the harness then refuses stays on disk until
  the archived origin is deleted with its worktree.
- A fork of an untitled origin that was later deleted reads as an ordinary
  session.
- An edit the plugin refuses keeps the attachment files the bridge saved for
  it, as a refused send does.
- A fork's restored saved-file attachments still point at the origin's uploads
  folder (restored images are fetched again), so one is
  missing if the origin is deleted (or the 30-day sweep runs) before the
  fork's first send; the agent then gets a note naming the missing file.
- A removal that lands in the same frame as a refresh goes at once instead of
  folding, since the refresh replaces the transcript.
- A message menu left open on a row another device removes stays open; its
  Copy and Select text act on the message as it was shown, all on this device.

## Sources

- `client/module_prego/lib/interactions/prego_context_menu.dart`
- `client/module_prego/lib/components/prego_readable_selection_area.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/transcript_message_menu.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/session_detail_message_list.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/transcript_laid_out_list_view.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/transcript_motion.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/user_message_card.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/queued_message_bubble.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/transcript_sticky_prompt_overlay.dart`
- `client/module_app_ui/lib/src/features/session_list/session_tile.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/edit_message_banner.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/edit_message_dialogs.dart`
- `client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart`
- `client/module_core/lib/src/cubits/session_detail/transcript_turns.dart`
- `client/module_core/lib/src/repositories/session_repository.dart`
- `client/module_core/lib/src/services/session_action_service.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/session_fork_flow.dart`
- `client/module_app_ui/lib/src/features/session_list/session_list_action_dispatcher.dart`
- `bridge/sesori_plugin_interface/lib/src/session_rewind_plugin_api.dart`
- `bridge/app/lib/src/routing/rewind_session_handler.dart`
- `bridge/sesori_plugin_interface/lib/src/session_fork_plugin_api.dart`
- `bridge/app/lib/src/routing/fork_session_handler.dart`
- `bridge/app/lib/src/services/session_fork_service.dart`
- `bridge/app/lib/src/services/worktree_service.dart`
- `bridge/app/lib/src/repositories/worktree_repository.dart`
- `shared/sesori_shared/lib/src/models/sesori/fork_session_request.dart`
- `bridge/app/lib/src/services/session_prompt_service.dart`
- `bridge/app/lib/src/repositories/session_repository.dart`
- `bridge/app/lib/src/services/session_event_service.dart`
- `bridge/app/lib/src/services/chat_history_service.dart`
- `bridge/sesori_plugin_claude/lib/src/services/claude_session_service.dart`
- `bridge/sesori_plugin_claude/lib/src/repositories/claude_transcript_catalog_repository.dart`
- `bridge/sesori_plugin_claude/lib/src/claude_plugin_impl.dart`
- `bridge/sesori_plugin_codex/lib/src/services/codex_session_service.dart`
- `bridge/sesori_plugin_codex/lib/src/repositories/codex_message_repository.dart`
- `shared/sesori_shared/lib/src/models/sesori/session_branch_error_response.dart`
