# Pull Request Monitor

## Capability

An agent in a Sesori session can hand a GitHub pull request to the bridge to watch. The bridge's `pr_monitor` tool
group on the [Sesori MCP](sesori-mcp.md) polls each watched PR through the user's own `gh` CLI, once a minute per PR
however many sessions watch it, and messages every watching session a `[PR Monitor]` report, shown as a Sesori row,
when CI, reviews, comments, mergeability or the PR's state change. Watches are stored per session and resume after a
bridge restart. When a PR is ready the bridge adds the `agent-ready` label, handing it to a human, and with
auto-merge on it makes one squash merge pinned to the head. The app shows the watched PRs on session rows, in the
composer chip, and in a Pull requests list: a home button and sheet on the phone, a sidebar row and page on desktop.

`gh` is an optional dependency: the group's tools are listed without it, and a call that needs GitHub answers with
what to do ("Install it from https://cli.github.com, then run `gh auth login`", or "Run `gh auth login`, or check
`gh auth status`"). The bridge never reads or passes a GitHub token; `gh` uses its own sign-in.

| Tool | Read-only | Effect |
|---|---|---|
| `watch_pr` | no | Starts this session's watch of `owner/repo#N` or a PR URL, with optional `auto_merge`; the result is the PR's first report. |
| `unwatch_pr` | no | Ends this session's watch only. |
| `pr_watch_status` | yes | This session's watches (buffered or held report, time since the last report, poll failures, readiness), the number of PRs this computer polls, and the settings. |
| `get_pr_report` | yes | Fetches the PR now and returns this session's report, which then counts as reported to it. |
| `get_pr_feedback` | yes | The feedback still awaiting a reply, with bodies and review-thread ids. Needs no watch. |
| `reply_on_pr` | no | Posts a `[Sesori reply]` reply, in a thread with `thread_id`, else as a PR comment. Needs no watch. |
| `mark_pr_ready`, `unmark_pr_ready` | no | Adds or removes `agent-ready`; on a watched PR with auto-merge, a mark is the merge approval. |
| `set_pr_auto_merge` | no | Turns auto-merge on or off for this session's watch. |
| `configure_pr_monitor` | no | The bridge-wide auto-merge default, per-repository overrides and report timings. |

The how-to lives in the group's guide, served as the `sesori-pr-monitor` skill where the harness takes one and through
`get_guide` everywhere (see [Sesori MCP](sesori-mcp.md)).

## Required Behavior

### Bridge

- The group is `pr_monitor`, on by default, and follows the Sesori MCP's gating: listed only while it and
  `agent-tools` are on, fixed per token at mint. While either is off the poll ticks do nothing, no report or reminder
  goes out, and the watches stay stored; they are left out of `Session.pullRequestWatches` and
  `GET /pull-request-watches`. Turning the group off republishes every watched session at once; turning it on polls
  the due PRs first, then republishes them, so they come back with fresh statuses.
- A watch belongs to the caller's root session, as wake-ups do, so a sub-agent's watch reports to its root. The
  bridge resolves its `gh api user` login once, retrying after a failure, before the first watch. `watch_pr` refuses
  a merged or closed PR, and a second watch from the same session answers with the first one's status. The first
  report counts every existing comment as new.
- A 30-second tick polls each watched PR whose last poll is at least 60 seconds old, one PR at a time through that
  PR's queue, skipping a PR whose operation is still running. Each `gh` call has a 60-second limit; a timeout is an
  ordinary poll failure. One poll serves every watcher of the PR, and each watcher keeps its own baseline (comment,
  review and thread ids with their signatures, CI, state and mergeability, never comment bodies), so a watcher the
  snapshot already covers gets nothing.
- Activity (a state or head change, a definite mergeable change, a review change, new or changed threads, new
  comments, CI concluding or its failures changing) makes a report due after the quiet window (default 2 minutes after
  the latest activity, rolling). While CI runs on an open PR a due report waits, up to the CI wait (default 30
  minutes), then goes out with a line saying CI is still running. A newly failing check (once per head), a new
  conflict, a merge or a close, and a withdrawn ready label report at once. CI starting or progressing is quiet, and a
  `[Sesori reply]` is never activity.
- Reports use the notice's derived timing: a steering harness takes one into its running turn, the others after the
  turn, and a scheduled run's session always after the turn. The summary reads `PR monitor: owner/repo#12 — <reason>`
  and the report is the agent's guidance. Reports leave comment bodies out; the agent reads them with
  `get_pr_feedback`.
- An idle reminder goes to each watcher of an open PR with no activity and no report for the idle delay (default 25
  minutes), after the turn, and repeats one delay later. It never goes out while reminders are off or while the PR
  carries the ready label without auto-merge.
- Each watch has at most one delivery in flight; activity meanwhile goes into the next report. Right before the send,
  the session's lane checks the watch still stands with the baseline the report was built on; otherwise the report is
  dropped. A sent report advances that watcher's baseline. A delivery the bridge drops is sent again at the next
  poll, and one to an archived or deleted session ends that watch. `get_pr_report` advances only the caller's
  baseline and changes nothing on GitHub: labelling and merging wait for the next due report.
- A watch ends on `unwatch_pr` or the app's Stop (no notice), when its session is archived or deleted (at the next
  poll), and, with a stop notice, when GitHub says the PR is not found or not visible to the account. Any other poll
  failure (network, GitHub 5xx, rate limit, timeout, `gh` signed out or missing) keeps the watch and its schedule:
  after 10 failed polls in a row (about 10 minutes) each watcher gets one "GitHub can't be reached; still watching"
  notice with the last error's first line, and no other during that streak. The first successful poll ends the
  streak, and the next report covers what changed meanwhile. The streak lives in memory, so a restart starts it
  again. The log records a streak's first error, its notice and its end, not every failed poll. A closed
  PR's report is its last, and its record is deleted. A merged PR's report is its last too, but the record stays as
  `merged` with its time, unpolled and across restarts, until the first poll after the bridge computer's local
  midnight. Deleting a session deletes its records.
- At start the bridge loads every stored watch. Each PR's first poll compares each watcher's stored baseline with
  GitHub: a difference counts as activity at that moment, so a merge, close, conflict or new CI failure while the
  bridge was off reports at once and anything else after the quiet window, in a report that opens "Resumed after the
  bridge restarted; this covers changes since the last report." An unchanged PR stays quiet.
- Readiness: a PR is eligible when it is open, its CI has no checks or all of them passed, it is mergeable, and every
  review thread and the PR's comments and review summaries since the last reply are answered with `[Sesori reply]`.
  An eligible PR gets `agent-ready` (created with its colour when the repository lacks it) only as a quiet report goes
  out. A push, a new conflict, a new failure or new feedback withdraws a present label at once with an urgent report;
  a resolution-only change or an approval does not. A failed label change reports at once, is retried each poll, and
  reports again once it works. A merged or closed PR is never labelled. `mark_pr_ready` and `unmark_pr_ready` on a PR
  nobody watches change only the label; an unmarked PR that still qualifies is labelled again after its next quiet
  report.
- Auto-merge is stored per watch and applies to the PR while any watcher has it on; one watcher turning it off never
  vetoes another. With it on, the ready label (added on a quiet report or by `mark_pr_ready`) is the merge approval:
  one squash merge pinned to the head
  last polled, titled with the PR title and an empty body, then the `automatically-merged` label. HTTP 409 means the
  head changed; an indeterminate answer is reconciled against the PR (merged at that head is success, open at another
  head is a changed head, anything else unknown). A rejected or unknown merge keeps the label and is not retried on an
  unchanged PR; the result goes to every watcher once. A merge stays a success when the merged label cannot be added.
  Turning auto-merge on removes a ready label the PR already carries, so it merges only after a fresh judgment.
- An agent turning auto-merge on for one PR (`watch_pr` with `auto_merge: true`, or `set_pr_auto_merge` turning it
  on) asks the calling session's user with an Allow card while the repository's default is off, unless that session
  approves everything. `watch_pr` starts the watch at once without auto-merge. The root session hears the answer
  through a notice; an Allow for a watch that ended or was replaced meanwhile applies nothing and says so. Turning
  auto-merge off never asks, and neither does the app's own toggle.
- `configure_pr_monitor` sets the bridge-wide settings, stored in the group's bridge record and kept across restarts:
  auto-merge by default (off unless changed, with per-repository `owner/repo` overrides a call can set or clear), the
  quiet window (1–60 min, default 2), the CI wait (5–240 min, default 30) and the idle reminder (5–240 min, default
  25, or 0 for off). A change that turns auto-merge on by default anywhere, including clearing a repository's off
  override while the default is on, asks the calling session's user with an Allow card, unless that session approves
  everything. The call's timings and narrowing changes apply at once. Its root session hears the answer through a
  notice. If the auto-merge settings changed while the card was open, an Allow applies nothing and says so.
  `watch_pr` without `auto_merge` takes the repository override, else the default; watches already running keep
  their choice, while new timings apply to them from their next poll.
- `reply_on_pr` adds the `[Sesori reply]` prefix once, and a thread reply goes to that thread. A prefixed reply makes
  its thread or comment count as answered.
- Sessions carry their watches (`Session.pullRequestWatches`: repository, number, title, url, the session's
  auto-merge, and a status). The status is `needsYou` with its reasons (CI concluded and failing, a merge conflict,
  review feedback without a `[Sesori reply]`, or ready while no watch auto-merges it), otherwise `ready` when labelled
  ready, otherwise `waiting`, or `merged` with its time. The bridge stores the status after every poll, watch, unwatch
  and auto-merge change, and republishes each session whose watches changed plus a `pullRequestWatches.changed`
  event. `GET /pull-request-watches` lists every watch on the bridge with its session's id, title and project,
  skipping deleted sessions. `POST /session/pull-request-watch/stop` and `/session/pull-request-watch/auto-merge` end
  a watch or set its auto-merge without an Allow card or a notice to the agent, answer with the updated session (also
  when the watch was already gone), and refuse a repository that is not `owner/repo` with 400. Older bridges omit
  the list, which reads as no watches; an unknown status or reason from a newer bridge reads as `unknown`.

### App

- Only the current computer's PRs show, and only while the bridge sends them (the group and `agent-tools` on).
- A session row with watched PRs and no timed wake-up shows a pull-request glyph and the lead PR's `#number` in its
  status colour (red needs you, green ready, the accent waiting, grey merged or unknown), then a quiet `+N` for the
  others; the lead is the one that needs the user most (needs you, ready, waiting, unknown, merged), ties to the lower
  number. A timed arming wins over it, and it wins over the plain task mark. A status change cross-fades the mark in
  place.
- The composer chip also shows for watches: with a wake-up it keeps "Wakes <time>"; with only watches it is a
  pull-request glyph and "N pull requests", cross-fading between the two, and nothing above the composer moves. With
  only watches a tap opens the session's pull-request list; with a wake-up its menu lists the wake-ups, then an
  "N pull requests" row that opens the same list.
- The phone home bar has a pull-request button left of the computer and Settings buttons (on a tablet, in the sidebar
  footer). It fades and grows in while the computer has watched PRs and out when none are left, in its own reserved
  slot so the other buttons never move, and carries a red count of the PRs that need the user while there are any;
  the count rolls when it changes.
- The button opens the Pull requests sheet (a dialog under a pointer), which reloads on open and lists the watches
  under Needs you, Waiting (unknown statuses too), Ready and Merged today: open ones by repository and number, merged
  ones newest first. Each row shows the status glyph in its colour, the PR title, `owner/repo#N` with the reasons or
  status, an Auto-merge mark when on, and the session title. While the sheet stays open a row keeps its group and
  place and only its content changes; it regroups the next time it opens, a new watch joins the end of its group,
  and an ended one leaves. Tapping a row closes the sheet and opens its session; from the composer chip the sheet
  lists only that session's PRs and a tap just closes it.
- Swiping a row offers Auto-merge (or No auto-merge) and Stop, and a full swipe stops; a long press lists the same
  actions. Merged rows offer only Stop. Auto-merge moves at once and a failed change goes back and says so; Stop shows
  a spinner on the row, and a failed stop keeps the row and says so. A computer switch clears the list until the new
  computer's loads. A bridge without the list route shows an update note instead.
- On desktop the sidebar has an always-shown "Pull requests" row under Scheduled, with the same red needs-you count
  at its end (spoken and in its tooltip as "N need you"); the command palette has a Pull requests command for a
  window too narrow to show the sidebar. Both open the same list as a page over the main pane, with a close button
  and pull-to-refresh; a row opens its session over the page, so back returns to the list. The page reports the
  `sessions` screen ([analytics](analytics.md)); the list adds no product event.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated, in `bridge/sesori_tool_pr_monitor/test/`: `gh_cli_api_test.dart` (the poll query and its 60 s limit, page queries, not found, a GraphQL `errors` array, a missing `gh`, a timeout, unauthenticated), `pull_request_snapshot_repository_test.dart` (normalization and pagination on synthetic fixtures), `pull_request_activity_calculator_test.dart`, `pull_request_readiness_calculator_test.dart`, `pull_request_report_builder_test.dart` and `pull_request_feedback_builder_test.dart` (the ported plugin cases), `pull_request_action_repository_test.dart` (the pinned title-only squash, 409, reconciliation, the merged label, the ready label's preflight, the reply prefix and thread replies), `pull_request_watch_service_test.dart` (one poll for two sessions, per-watcher baselines, the quiet window, the CI hold, urgent reports, a merged watch kept until midnight across a restart, claim lost and dropped deliveries, restart resume, archived and deleted sessions, an outage notice once per failure streak with the watch kept and reports resuming after it, not found ending the watch, idle reminders, the group toggle; readiness and auto-merge across watchers; `configure`), `pull_request_monitor_tool_group_test.dart` (argument checks, the agent's per-PR auto-merge cards) and `pull_request_config_description_builder_test.dart`. Bridge app: `pull_request_watch_handlers_test.dart` (stop, auto-merge, a bad repository, the list route), `session_view_service_test.dart` (watches on sessions, left out while the group or agent tools are off) and `goldens/tools_list.json`. Wire: `pull_request_watch_test.dart` in `sesori_shared` (older bridges, unknown status and reason). App: `session_scheduled_mark_calculator_test.dart` (the lead, the count, a timed arming winning), `session_tile_states_test.dart` (the status colour in light and dark, the cross-fade in place), `session_wake_up_chip_test.dart` (the PR count giving way to a wake-up's time, the chip or its menu row opening the list), `pull_request_watch_list_cubit_test.dart` (the needs-you count, a reload on the changed event, a failed load retried, an older bridge, a computer switch, auto-merge applied or reverted, stop applied or kept), `pull_request_watch_sections_test.dart` (grouping and order, rows held in place while open, the session filter), `pull_request_watches_test.dart` (the home button and its count, rows changing in place, a failed stop) and `desktop_cockpit_shell_test.dart` (the sidebar row under Scheduled, opening the page, its spoken count). |
| L3 Release | Headless bridge with GitHub, on a private scratch repository with no real code and `gh` signed in: a report about 2 minutes after a comment, and at once after a failing check and after a merge; `reply_on_pr` makes its thread count as answered and the label lands with the next quiet report; `mark_pr_ready` with auto-merge squash-merges at the head with the title only and adds `automatically-merged`; a push after the mark cancels a stale merge; a restart mid-watch resumes it, and a merge during the downtime reports at once; two sessions on one PR cause one poll a minute and both get reports; the group off stops polling and listing; archiving a session ends its watch. `configure_pr_monitor`: widening shows the card and applies on Allow, applies with no card under Approve everything, and narrowing applies at once. Live plugin, on every harness that gets the Sesori MCP, through the local test proxy: the tools list only while the group is on, `watch_pr` works, a report arrives and the agent acts on it, the skill loads where its seam is wired and `get_guide` works everywhere, and a mid-turn report steers on Claude Code and waits on Grok; on OpenCode two sessions in one folder each get their own reports. Client on a headless iOS simulator: the chip with only watches and with a wake-up too, opening the session's list from it; the row mark against a timed arming; the home button appearing and leaving without moving the other buttons, the red count only for needs-you and its roll; the sheet's groups, tap to session, swipe Auto-merge and Stop, a row changing in place while open and regrouping on the next open, Merged today; dark mode; an older-bridge fixture with no chip and no button. Desktop shell: the sidebar row opens the page. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

### L3 run, 2026-11-26

This run used a headless bridge, an isolated home, the local test proxy and a private scratch repository with no
real code. Per-harness delivery timing is recorded in [harness capabilities](../HARNESS_CAPABILITIES.md).

- **Passed, bridge:**
  - **Report timing:** a comment reported after 2.5 to 3 minutes, the quiet window plus the next poll. A failing
    check reported at the next poll. A merge reported at the next poll, or 4 seconds after a restart when it
    happened while the bridge was stopped.
  - **Restart:** a restart mid-watch resumed the watch. A check that failed during the downtime reported at once to
    both watchers.
  - **One poll per PR:** two sessions, and later seven, on one PR caused one GraphQL poll a minute, and each
    session got each report once.
  - **Replies and readiness:** `reply_on_pr` posted with the `[Sesori reply]` prefix once and answered the comment.
    `agent-ready` landed with the next quiet report.
  - **Auto-merge:**
    - An agent's per-PR auto-merge showed the Allow card. Allow turned auto-merge on and removed the existing
      `agent-ready`.
    - `mark_pr_ready` then squash-merged at the head, with one parent, the title as the whole message, and
      `automatically-merged` added.
    - A push 2 seconds after a poll, followed by a mark before the next poll, got GitHub's 409, and the merge was
      cancelled. The next report removed the label. The agent judged the new head and marked it again, and it merged.
  - **Group toggle:** with the group off, there were no polls, the list route was empty, and a new session's tools
    had no PR monitor tools. Turning it back on polled at once and restored the watches.
  - **Archive:** archiving a session ended its watch at the next tick, and polling of that PR stopped.
  - **`configure_pr_monitor`:** widening the auto-merge default showed the card and applied on Allow. Under Approve
    everything it applied with no card. Narrowing and `clear_repository` applied at once.
  - **Idle reminder:** a reminder arrived after a long idle stretch.
- **Passed, privacy:**
  - **Tokens:** the `gh` token was absent from the bridge log, from a log of every `gh` argv, and from harness argv.
  - **Reply bodies:** `gh`'s errors for a rejected reply, a body that is too long or an unknown thread, carry only
    stderr, without the body, and the bridge logs only that message.
- **Passed, harnesses:**
  - Claude Code, Codex, Pi, Oh My Pi, Grok, GitHub Copilot and OpenCode each watched, got a report and acted on it.
  - The skill loaded where its seam is wired, and Codex called `get_guide` before `watch_pr`.
  - A mid-turn report steered on Claude Code and waited on Grok.
  - Two OpenCode sessions in one folder each got their own report.
- **Passed, client** (iOS simulator, `sesori-dev-1`, an integration test against this bridge):
  - **Home button:** it faded and grew in and out within about 250 ms when the group was toggled. The other home
    buttons kept exactly the same frames.
  - **Count:** the red count showed only needs-you PRs. It went from 2 to 3 when a watched PR got a comment, then
    back to 2 when the agent replied, rolling both times.
  - **Sheet:** it showed Needs you, Waiting and Merged today, in light and in dark mode.
- **Not run:**
  - **Hermes:** it does not get the Sesori MCP yet. The fix is upstream in hermes-agent#154438.
  - **Remaining client checks:** the composer chip, the row mark against a timed arming, tap to session, swipe
    actions, regrouping on the next open and the older-bridge fixture. These are covered by the L2 widget tests
    above.
  - **Desktop sidebar row:** agents may not launch a desktop debug build, because it raises keychain prompts on
    the owner's screen. It is covered by `desktop_cockpit_shell_test.dart`.

## Exploration Guidance

Vary who watches (one session, two sessions on one PR, a sub-agent and its root), when activity lands (during the
quiet window, while CI runs, mid-turn, while the bridge is stopped), and the ending (merge, close, a deleted
repository, `gh` signed out). Toggle the group and the master switch while watches stand and while the sheet is open.
Use only scratch repositories and fixture text.

## Material Failure Signals

- A report is duplicated, delivered to the wrong session, lost on an ordinary restart, or delayed by the quiet window
  when it should be urgent; running-CI progress produces reports.
- A PR is polled twice a minute, or a disabled group still polls, lists its tools or shows watches in the app.
- A failed delivery advances the baseline, or a prefixed reply shows as new feedback.
- A merge is not pinned to the head, carries a body, is retried on an unchanged PR, or an unknown outcome is retried
  without reconciling.
- An agent turns auto-merge on for a PR where the default is off without the calling session's Allow outside Approve
  everything, or an Allow applies to a later watch of the PR.
- Auto-merge turns on by default anywhere without the calling session's Allow outside Approve everything, an Allow
  applies after the auto-merge settings changed under its card, or a settings change alters an existing watch's
  auto-merge.
- A failed label change hands off the PR, a resolution-only change withdraws readiness, or an idle reminder fires
  while a report waits, soon after a report, for a ready PR without auto-merge, or with reminders off.
- A watch outlives its archived or deleted session, or a merged one stays past the next local midnight.
- A network outage or other passing poll failure ends a watch, the outage notice repeats within one streak, or the
  log gains a line for every failed poll.
- A GitHub token or the Sesori MCP token reaches logs or argv.
- The home button or the chip moves other controls as it appears, a sheet row jumps groups while the sheet is open, or
  the red count includes PRs that do not need the user.

## Known Limitations

- PR comments and each review thread's comments are read from the latest 100, and review requests from the first 50;
  older ones are not seen, as in the plugin this ports.
- Readiness retries and the last merge attempt live in memory. After a restart they start empty, so the first poll
  cannot withdraw a ready label for what changed while the bridge was off, and at most one extra idle reminder goes
  out.
- An Allow card for an agent's per-PR auto-merge still applies when that watch's auto-merge went on and back off while
  the card was open.
- On harnesses that load the skill per process (Codex's app-server until its next thread start, resume or fork; Oh
  My Pi and GitHub Copilot until the process restarts), a toggle leaves the skill loaded; its text says to skip tools
  that are missing.
- Polling, not webhooks: a report waits for the next 60-second poll, and each poll costs about one GraphQL point, so
  50 watched PRs use about 3,000 of the 5,000 points an hour.
- `gh` must be on the bridge's PATH; a supervised desktop bridge gets the user's login-shell environment.
- The labels and the `[Sesori reply]` prefix are fixed, and the plugin's config files are not read. Only agents change
  the settings, through `configure_pr_monitor`.
- The list shows only the current computer's PRs, and has no "checked N ago": the wire carries no poll time.
- GitHub Copilot asks its own permission before each tool that is not read-only. OpenCode gets no MCP `instructions`
  and has no skill seam, so `get_guide` is its only guide path.
- With the separate `pr-monitor` harness plugin also installed, a session has two monitors; the guide tells the agent
  to use only Sesori's tools.

## Harness Scope

The group is harness-neutral (`bridge/sesori_tool_pr_monitor`), so it covers every supporting production plugin: each
harness that gets the Sesori MCP (Claude Code, Codex, Pi, Oh My Pi, Grok, GitHub Copilot and OpenCode 2.2.0 and
newer). Delivery timing and skill seams differ per harness; see [harness capabilities](../HARNESS_CAPABILITIES.md).

## Related Coverage and Sources

- [Sesori MCP](sesori-mcp.md) (tool groups, gating, guides, notices), [scheduled tasks](scheduled-tasks.md) (the row
  mark it shares), [projects and sessions](projects-and-sessions.md) and
  [desktop cockpit shell](desktop-cockpit-shell.md).
- Bridge: `GhCliApi`, `PullRequestSnapshotRepository`, `PullRequestActionRepository`, `PullRequestWatchRepository`,
  `PullRequestWatchService`, `PullRequestMergeService`, `PullRequestPollListener`, `PullRequestMonitorToolGroup` and
  `pullRequestMonitorGuide` in `bridge/sesori_tool_pr_monitor`; `SessionViewService` and the pull-request watch
  handlers in `bridge/app`; the wire in `sesori_shared` (`pull_request_watch.dart`).
- App: `SessionScheduledMarkCalculator`, `PullRequestWatchListCubit` and `arrangePullRequestWatches` in `module_core`;
  `pullRequestWatchLook`, `session_wake_up_chip.dart` and `features/pull_request_watches/` in `module_app_ui`; the
  desktop sidebar and cockpit shell.
- Plan: [.plan/completed/bridge-pr-monitor/PLAN.md](../../.plan/completed/bridge-pr-monitor/PLAN.md), with the plugin
  behaviour it ports in `PR_MONITOR_SPEC.md`.
