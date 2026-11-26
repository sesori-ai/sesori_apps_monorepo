# PR monitor v0.10.0 behaviour (reference for the Dart port)

Read from `sesori-ai/opencode-pr-monitor` at `origin/main` `1fe61f6` (release
v0.10.0 is `2ac605e`). Paths are relative to that repo. This file records what
the plugin does; [PLAN.md](PLAN.md#pr-monitor) says where the bridge port
deliberately differs. Re-read the cited source when a rule here is unclear.

## 0. Target and identity

- A PR is `owner/repo#N` or `https://github.com/owner/repo/pull/N[/?#…]`.
  Nothing is inferred from the working directory. Invalid input:
  `Invalid PR identifier: "<input>". Use "owner/repo#123" or a full PR URL
  (https://github.com/owner/repo/pull/123).` (`core/target.ts:6-20`)
- The display key is `owner/repo#N`; the registry key lowercases owner and
  repo (`target.ts:22-28`).
- `selfLogin` is `gh api user --jq .login`, cached per session; a failed lookup
  retries next call (`runtime/monitor-session.ts:285-294`). A comment is local
  when its author equals `selfLogin`, case-insensitively (`github.ts:329-344`).

## 1. Actions

One tool `pr_monitor(action, pr, autoMerge?, thread?, body?)`; validation in
`monitor-session.ts:193-238`. `all` is accepted only by stop and flush.

- **start(pr, autoMerge?)** (`:332-541`)
  - Already watched: `Already monitoring X in this session.` plus the status
    line. A start in flight: "A monitor for X is already starting…".
  - Sequence: load config (the argument overrides it for this watch); resolve
    `selfLogin` (failure: "Cannot start monitor: resolving the authenticated gh
    user … Run `gh auth status`"); fetch the first snapshot (failure: `Cannot
    start monitor for X: <msg>`); refuse a MERGED or CLOSED PR; with auto-merge
    on and the ready label present, remove the label first (the startup safety
    reset; a failed removal aborts the start); register the watch and its
    interval timer (no immediate tick); with `announceOnStart`, deliver the
    initial report.
  - Result: `Started monitoring X — "<title>".`, plus the auto-merge guidance
    (`report.ts:15-19`) and the startup-reset text.
- **stop(pr|all)**: stops the watch and drains an in-flight readiness
  mutation; does not wait for a stalled fetch (`watch.ts:501-522`). Texts at
  `monitor-session.ts:556-578`.
- **flush(pr|all)**: re-fetches, applies the snapshot, runs automatic
  readiness if dirty, builds the report against the baseline, resets the
  baseline, and returns the report as the tool result. Stops a terminal watch.
  On a fetch failure it returns the previous report plus `(note: refresh
  failed — <msg>; data is from the previous poll; baseline NOT reset)`
  (`watch.ts:465-499`).
- **status**: one line per watch (`watch.ts:150-165`): `owner/repo#N —
  watching|ci-hold, activity buffered|quiet, baseline <m>m ago[, K consecutive
  poll failures][, ready: yes|no][, auto-merge: squash]`.
- **mark_ready / unmark_ready(pr)**: work without a watch (`:603-632`).
  Watched path (`watch.ts:203-236`), serialized with polls: sets
  `lastReportAt`, clears a pending auto-merge notice and
  `readinessResetPending`, adds or removes the label, patches the local
  snapshot. Ready triggers one auto-merge attempt if enabled, using the last
  polled title and head. Unready while still eligible marks the watch dirty,
  so the next quiet report re-adds readiness.
- **set_auto_merge(pr, autoMerge)**: needs a watch (`:641-660`,
  `watch.ts:243-279`). Disabling never touches labels. Enabling on a PR that
  carries the label removes it first and asks the agent to reassess and call
  mark_ready. The choice lives in the watch, not in config.
- **feedback(pr)** and **reply(pr, thread?, body)**: section 9.

## 2. GitHub I/O

- Runner (`runtime/node-gh.ts:6-23`): `execFile("gh", args)` on PATH, 32 MB
  buffer, **no timeout**, gh's own auth. `notFound` when stderr matches
  `/could not resolve to|not found|404/i` but not `/could not resolve host/i`;
  the HTTP status is parsed from `/\bHTTP\s+(\d{3})\b/`. No rate-limit or
  backoff handling: a failed poll waits for the next interval.
- Poll: one `gh api graphql` per PR (`github.ts:72-116`). `pullRequest`:
  `title url state mergeable headRefOid`;
  `commits(last:1).commit.statusCheckRollup.contexts(first:100)`
  (`CheckRun{id name status conclusion}`, `StatusContext{context state
  createdAt}`); `reviewRequests(first:50)` (User login, Team slug, Bot login;
  not paginated); `latestReviews(first:50){id author{login __typename} state
  submittedAt body comments(first:1){totalCount}}`;
  `reviewThreads(first:100){id isResolved path line originalLine
  comments(last:100){id author body createdAt pullRequestReview{state}}}`;
  `comments(last:100){totalCount; id author body createdAt}` (not paginated);
  `labels(first:100){name}`.
- Follow-up pages only on `hasNextPage` for checks (via
  `repository.object(oid: headRefOid)`), latest reviews, threads and labels
  (`github.ts:118-180, 204-258, 284-315`). A repeated cursor or a vanished
  connection is an error.
- Any GraphQL `errors` array is a retryable poll error even with partial data
  (`:190-200`); a clean payload with a null `pullRequest` is `notFound`.
- Normalization (`:346-449`): a CheckRun not COMPLETED is pending;
  SUCCESS/NEUTRAL/SKIPPED succeed; anything else fails. StatusContext SUCCESS
  succeeds, PENDING/EXPECTED are pending, the rest fail. CI phase is `none`,
  `running` (any pending) or `concluded`. Reviews are latest reviews with an
  author and state not PENDING; review summaries are those with a non-blank
  body, or CHANGES_REQUESTED with no inline comments. A thread's line is `line
  ?? originalLine`. Each comment records author (`ghost` if null), `isBot`,
  `createdAt`, `isLocal`, `isAgentReply` (local and starts with the prefix) and
  review state. `issueCommentsTotal` excludes prefixed replies in the fetched
  window. Labels compare case-insensitively.
- REST through `gh api`: `GET repos/o/r/pulls/N` (preflight and merge
  reconciliation), `POST repos/o/r/labels` (errors ignored), `POST
  repos/o/r/issues/N/labels`, `DELETE repos/o/r/issues/N/labels/<l>` (404 means
  not carried), `PUT repos/o/r/pulls/N/merge`, `POST repos/o/r/issues/N/comments
  --jq .html_url`, and the GraphQL mutation `addPullRequestReviewThreadReply`.

## 3. Per-watch state (all in memory today; `watch.ts:68-126`)

- The last snapshot, and `lastDefiniteMergeable` (the last MERGEABLE or
  CONFLICTING, surviving UNKNOWN polls).
- `dirty`, `urgent`, `lastActivityAt`, `holdStartedAt` (CI hold).
- The baseline: `lastFlushAt` and `lastFlushedSnapshot`. "New" means an id
  absent from the baseline snapshot. The initial announcement uses an empty
  baseline, so every existing comment counts as new.
- `lastReportAt` (idle timer), `ciFailureFlushedSha` (one instant CI report per
  head), `consecutiveFailures`, `deliveryFailures`, readiness retry and error
  fields, a one-shot auto-merge notice, `mergeStuck`, `readinessResetPending`,
  `autoReadyAfterInvalidation`.
- One op queue serializes poll, flush, ready and merge. A tick is skipped, not
  queued, while an op is pending (`:282-289`).
- **Handled** (`readiness.ts:16-59`). Channels are each review thread
  (resolved or not) plus one unthreaded channel (issue comments and review
  summaries). A channel is acknowledged when it is non-empty and every comment
  at its latest `createdAt` is an agent reply (local account, prefixed).
  Same-second mixed ties are unacknowledged. Resolution, `original_commit_id`
  and outdated state play no part. An unprefixed comment from the local account
  is human feedback.

## 4. Activity and timing

- Activity (`activity.ts:106-134`): a state change; a head change; a definite
  mergeable change (UNKNOWN ignored); a review signature change (login, state,
  submittedAt, pending reviewers); a thread vanishing, appearing with relevant
  comments or unresolved, flipping resolution, or gaining a non-reply comment;
  an issue-comment total change or a new non-reply issue comment or summary;
  CI becoming concluded, or its concluded signature (head plus failed ids)
  changing. CI starting or progressing is quiet.
- Activity sets `dirty` and `lastActivityAt`, clears the CI hold and
  `readinessResetPending` (`watch.ts:318-323`).
- A report is due 2 minutes after the last activity (rolling, no cap;
  `watch.ts:573`). If CI is running and the PR is open, it holds; after 30
  minutes of hold it goes out anyway with a forced CI line (`:574-579`). New
  activity restarts the hold.
- Urgent, sent in the same poll: a newly failing check, once per head (a
  failure present at start is not new; `:324-334`, `activity.ts:91-97`); a
  newly definite CONFLICTING; OPEN to MERGED or CLOSED (`:335-339`); a ready
  PR's readiness invalidation (`:392-404`); a new readiness-mutation error; a
  readiness retry resolved (`:352-390`).
- A failed delivery rolls back the baseline, dirty, urgent and hold, and
  retries next poll (`:590-603`).
- Ten consecutive poll failures stop the watch with `Monitor stopped: 10
  consecutive poll failures. Last error: <m>`. `notFound` stops it at once
  (`:543-566`). Ten consecutive delivery failures also stop it (`:640-667`).
- A terminal (merged or closed) report ends the watch once delivered
  (`:862-864`). Ready does not end a watch.
- Idle reminder (`:613-638`), checked after each poll: when
  `idleReminderMinutes > 0`, not dirty, the PR is open, not (ready label
  present and auto-merge off), and 25 minutes have passed since
  `max(lastActivityAt, lastReportAt)`. It repeats every 25 minutes.
  `lastReportAt` is bumped by start, manual ready, set_auto_merge, every
  delivered report and flush.

## 5. Report content (`report.ts`)

- Full report (`:247-293`), one line each:
  - `[PR Monitor] [owner/repo#N](<url>) — "<title>"[ — MERGED|CLOSED]`
  - `- CI: none` / `passing (t/t)` / `failing (f/t failed: a, b)` / `running
    (d/t done[, f failed so far: …])` / forced `running for Mm+ (in_progress:
    names)`
  - `- Mergeable: MERGEABLE|CONFLICTING|UNKNOWN`
  - `- Reviews: login ✓ approved · login ✗ changes_requested · ✦ commented · ⊘
    dismissed · login ⏳ pending` or `none`
  - `- [comment:review] …` summaries line (`ACTION REQUIRED: n new relevant
    review summary(s) since last flush (<authors>).` when any).
  - `- [comment:inline] …` (`:68-117`): quiet form, or `ACTION REQUIRED: n
    thread(s) received m new relevant comment(s) since last flush (x currently
    unresolved, y currently resolved; <authors>). … Changed threads:
    `path:line` [thread `PRRT_…`] (resolved|unresolved; <authors>); …`, with
    the local-unprefixed and pending-review notes.
  - `- [comment:issue] T total (0 new since last flush | n new relevant since
    last flush: <authors>)`; author breakdowns sorted by count.
  - Readiness (`:158-201`): `- Ready: YES — label "<l>" is present.` or `NO —
    … absent.`; the auto-merge line; any readiness failure; any auto-merge
    notice; when not ready and open, `- Automatic readiness blocked by: …` and
    `- Required next step: …` naming the reply prefix.
  - `- Labels: …`; terminal `- Monitor stopped: PR merged|closed`.
- Startup report (`watch.ts:836-843`) adds the startup reset and a "Startup/
  restart assessment" paragraph.
- Idle reminder (`:205-245`): header `… — idle reminder`, an `- Idle:` line,
  CI, mergeable, reviews, unresolved-thread count, readiness lines, plus a
  retry step when auto-merge is stuck.
- Reports never carry comment bodies.

## 6. Readiness

- Eligible (`readiness.ts:66-102`): open; CI none or all checks succeeded;
  MERGEABLE; every thread acknowledged; the unthreaded channel empty or
  acknowledged. Resolution, stale CHANGES_REQUESTED, pending reviewers and
  draft state are ignored. Blocker texts: `CI is running`, `CI is failing`,
  `the PR has a merge conflict`, `mergeability is still unknown`, `N review
  thread(s) await(s) a prefixed reply from the local GitHub account`,
  `issue or review-summary feedback awaits a prefixed reply …`.
- The label is added automatically only when a report is about to go out
  (`watch.ts:669-688`), so it lands after the quiet window. Skipped when not
  open, already labelled, `readinessResetPending`, after an invalidation (the
  invalidating report goes first), or when the start snapshot was already
  eligible and nothing happened since (the agent judges).
- Invalidation of a present label (`:120-135`): head change, new conflict, CI
  ready to not ready, new CI failure, an acknowledgement regression, a new
  relevant comment. Effect: urgent report and label removal; re-adding waits
  for the next quiet window (`:769-789`). Resolution-only changes, approvals,
  transient UNKNOWN, merge and close do not invalidate.
- An externally removed label notifies (debounced); an externally added one is
  only observed and never triggers a merge.
- Label: color `0e8a16`, description "The agent finished its work on this PR";
  preflight needs an open PR (`label.ts:24-79`).
- No bot-specific logic anywhere: a Codex or cubic comment is ordinary feedback.

## 7. Auto-merge (`core/merge.ts`)

- Triggered only by a label add the monitor performs (automatic or
  mark_ready; `watch.ts:690-751`).
- `PUT pulls/N/merge` with `merge_method=squash`, `sha=<accepted head>`,
  `commit_title=<PR title>`, `commit_message=""`.
- A definitive 4xx other than 408: 409 is "head changed", others fail with the
  reason. A transport error, 5xx or bad JSON triggers one `GET pulls/N`: MERGED
  at the same head is success, OPEN at another head is "head changed", anything
  else is "outcome unknown" (`:197-250`).
- Success: `Auto-merge succeeded: squash-merged X at <sha> using only the PR
  title.`, then a best-effort `automatically-merged` label (color `1d76db`,
  "Merged automatically by Sesori PR Monitor").
- A rejected or unknown merge sets `mergeStuck`: the label stays, no automatic
  retry, and the idle reminder asks the agent to fix and re-mark. Head changed
  is not stuck; the next poll invalidates.
- Standalone mark_ready re-reads head and title before and after labelling and
  cancels (removing the label) when the head changed (`monitor-session.ts:662-754`).

## 8. Configuration (`core/config.ts:41-65, 86-229`)

Layers: defaults; global `~/.config/pr-monitor/config.json`; the first project
file (`.pr-monitor.json`, `.claude/pr-monitor.json`, …); the env
`SESORI_PR_MONITOR_AUTO_MERGE`; the start or set_auto_merge argument.

| Key | Default |
|---|---|
| `debounceMinutes` | 2 |
| `maxCiWaitMinutes` | 30 |
| `pollIntervalSeconds` | 60 (30–86400) |
| `ignoreCommentTag` | `<!-- pr-monitor:reply -->` |
| `announceOnStart` | true |
| `flushOnCiFailure` | true |
| `idleReminderMinutes` | 25 (0 off) |
| `readyLabel` | `agent-ready` |
| `autoMerge` | false |
| `desktopNotifications`, `keepAlive`, `keepAliveMaxMinutes` | Claude only |

This monorepo's `.pr-monitor.json` sets `ignoreCommentTag: "[Sesori reply]"`,
`autoMerge: true` and `pollIntervalSeconds: 45`.

## 9. Feedback and reply (`core/feedback.ts`)

- feedback: the same fetch with bodies. Channels are every unacknowledged
  thread plus the unthreaded channel when non-empty and unacknowledged. Each
  lists non-reply comments since the latest agent reply, oldest first
  (`:26-32`). Bodies have HTML comments stripped, are cut at 4000 characters
  with `[truncated]`, and are quoted. Headers: `### Thread `id` on path:line
  (resolved|unresolved[, bot-only])` and `### PR comments and review summaries
  (reply without `thread`)`. Empty: `No feedback on X is awaiting a reply.`
- reply: the body gets the prefix unless it starts with it. Without a thread it
  posts a PR comment (`Posted a PR comment on X: <url>`); with one it calls
  `addPullRequestReviewThreadReply` (`Replied on thread T: <url>`). Neither
  needs a watch.

## 10. Harness-only parts the bridge replaces

Claude socket push and spool, the drain and await hooks, keep-alive and
handed-off tracking, the shutdown side channel, Codex thread routing, desktop
notifications, and the start-up assessment and label reset that exist because
watches die with the harness process.

## 11. Material failure signals (`docs/regression/pull-request-monitoring.md:272-306`)

Urgent events delayed by the quiet window; running-CI progress producing
reports; a failed delivery advancing the baseline; a same-second or thread
follow-up lost; prefixed replies showing as activity; an inline report missing
the thread id or location; a failed label mutation changing handoff; a
resolution-only change withdrawing readiness; a manual mark undone by state it
already accepted; a merge not pinned to the head or with a non-empty body; an
unknown merge outcome retried without reconciliation; an ordinary merge
failure removing readiness; idle reminders firing while a report is buffered,
after a recent report, for a handed-off ready PR with auto-merge off, or with
reminders off. Known limits: the 100-comment issue window; no shared baselines
across processes.

## 12. Surprises worth keeping in mind

1. No timeout on `gh`: a hung call blocks the op queue and every later tick.
2. gh exits non-zero on GraphQL errors, so "Could not resolve to a
   PullRequest" may read as not-found and stop the watch.
3. Watched mark_ready merges at the last polled head and relies on GitHub's 409.
4. The label lags eligibility by the quiet window and the CI hold.
5. The quiet window has no cap; steady activity postpones reports.
6. Resolving a thread never satisfies readiness; bot comments block automatic
   readiness until replied to or marked.
7. The startup report treats every existing comment as new.
8. Review requests, thread comments and issue comments are not paginated past
   their windows.
