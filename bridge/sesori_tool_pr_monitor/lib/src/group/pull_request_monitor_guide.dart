import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGuide;

import "../repositories/models/pull_request_snapshot.dart" show sesoriReplyPrefix;

/// The PR monitor's how-to, adapted from the `pr-monitor` plugin's
/// `monitor-pr` skill (v0.10.0) to the bridge's tools: reports simply arrive,
/// so there is no keep-alive and no waiter command.
const SesoriToolGuide pullRequestMonitorGuide = SesoriToolGuide(
  name: "pr-monitor",
  whenToUse:
      "Use right after you open a GitHub PR, when asked to watch or babysit a PR, and every time a "
      "[PR Monitor] message arrives.",
  body: _body,
);

const String _body =
    """
# Sesori PR monitor

Own a PR from creation until it is handed to a human reviewer, or merged when the user turned auto-merge on. Sesori
polls GitHub through the user's `gh` CLI once a minute and messages this session a `[PR Monitor]` report when CI
finishes or fails, a review or comment arrives, a conflict appears, or the PR is merged or closed. When the PR is
ready, Sesori adds the `agent-ready` label: your work is done and a human reviews next, or, with auto-merge on, Sesori
makes one squash-merge attempt.

If a tool named here is missing from your tool list, the PR monitor is turned off for this session or that tool is
not on this bridge yet: skip what needs it. When a `pr_monitor` tool from the separate PR Monitor plugin is also
present, use only Sesori's tools.

## 1. Watch right away

After `gh pr create`, call `watch_pr` with the PR as `owner/repo#123` or its URL. The result is the PR's first
report. A watch belongs to this session (a sub-agent's belongs to its root session), survives bridge and harness
restarts, and ends by itself when the PR is merged or closed. Don't watch it again after a restart; use
`pr_watch_status` once if you are unsure what this session watches.

Auto-merge is off unless the user turned it on with `configure_pr_monitor` for every repository or this one. Pass
`auto_merge` to `watch_pr`, or call `set_pr_auto_merge` on a watched PR, only when the user explicitly asks for it on
this PR. Where the default is off, the user may be asked to allow it; the result says so. Until they answer, the PR
has no auto-merge, and a message tells you their answer, so end your turn instead of waiting. With auto-merge on, the
user has chosen to merge without waiting for a human: `mark_pr_ready` is the merge approval. Call it once checks and
automated reviews have settled, CI is green, the PR is mergeable and nothing actionable remains; never hold it back so
that a human can look first.

## 2. Assess the first report

The first report counts every existing comment as new. Inspect the current head's checks, the automated reviews you
expect, and all existing feedback:

- **Just created or just pushed:** no checks, reviews or comments yet may only mean they haven't arrived. Don't call
  `mark_pr_ready` from that absence; the next reports bring them.
- **Already settled:** checks and automated reviews have finished or don't apply, the PR is mergeable, and all
  feedback is handled or non-actionable. Call `mark_pr_ready` now without waiting for a new event.

PR age proves nothing: an old PR can have a new head. A report that starts with "Resumed after the bridge restarted"
covers what changed while the bridge was off; assess it the same way.

## 3. Handle every report

- **Failing CI:** inspect the named check, fix the root cause, test, commit and push. Never weaken tests.
- **`Mergeable: CONFLICTING`:** merge the actual base branch into the PR branch. Never rebase or force-push;
  preserve both sides and test.
- **`ACTION REQUIRED` inline feedback:** inspect every thread that received a new comment, resolved and unresolved
  ones included. An unchanged unresolved-thread count does not mean there is no new feedback.
- **New review summaries and PR comments:** reports leave out comment bodies. Read them with `get_pr_feedback`.
- **An unprefixed comment from the account you use** is the human owner speaking: treat it as an instruction.
- **An auto-merge that did not go through:** the label stays and Sesori does not retry an unchanged PR. Find out
  why, fix what you can, and call `mark_pr_ready` again only when a new attempt is warranted; otherwise tell the
  user what blocks it.
- **An idle reminder:** the PR had no activity and no report for a while. Re-check the current head's checks,
  expected reviews and feedback now; act on what is left, or call `mark_pr_ready` when nothing is.
- **Merged or closed:** the report is the last one; the watch has ended.

A delivered report already counts as reported. Don't call `get_pr_report` after handling one; use it only when you
need the current state before the next report arrives.

## 4. Reply to feedback

`get_pr_feedback` lists the feedback still awaiting a reply, with its bodies and thread ids.

- Assess every comment against the code. Assume a human is right unless you have strong evidence otherwise; when you
  disagree, explain why, and do the work if they insist.
- Commit and push a fix **before** replying, so the reply can cite the commit.
- Reply with `reply_on_pr`, passing `thread_id` for an inline thread and leaving it out for review summaries and PR
  comments. It starts the reply with `$sesoriReplyPrefix`, which tells Sesori the feedback was handled. A reply you
  post another way must start with that exact prefix.
- Reply only once the feedback is handled: "Addressed in <commit>: …" or "Not addressed: <reason>". If work or a
  question remains, finish it or ask the user; never post an interim reply.
- Resolve a thread only when you addressed it and `get_pr_feedback` marks it bot-only:
  `gh api graphql -f query='mutation{resolveReviewThread(input:{threadId:"PRRT_..."}){thread{isResolved}}}'`.
  Never resolve a thread with a human comment, or one you did not fully address.

## 5. Follow readiness, don't reconstruct it

Every report says `Ready: YES` or `Ready: NO`.

- `YES`: the label is on. A report that only shows a resolved thread or an approval is no reason to call
  `unmark_pr_ready`.
- `NO`: keep working, or call `mark_pr_ready` when inspection shows nothing actionable remains.

Sesori marks a PR ready by itself when CI passes or there is none, the PR is definitely mergeable, and a prefixed
reply from your account follows the latest feedback. It ignores the unresolved-thread count, stale change requests,
pending reviewers and draft state. A new commit, a new relevant comment or review, a CI regression or a conflict
withdraws readiness; resolving a thread does not.

`mark_pr_ready` accepts everything the watch has seen so far and adds the label; only later activity withdraws it.
Claim the handoff only after it confirms success. With auto-merge on it also makes one squash merge pinned to the
current head, whose commit message is only the PR title. Never run your own merge after "Auto-merge succeeded".
`unmark_pr_ready` removes the label now; a later clean assessment can add it again.

## 6. Don't acknowledge an acknowledgement

A bot may post a non-actionable comment after a fix, such as an acknowledgement, a clean review ("0 issues found")
or a quota notice. Its comment correctly withdraws readiness. Read it with `get_pr_feedback`, but don't reply just to
make the bot acknowledge your reply. When CI is green, the PR is mergeable and nothing actionable remains, call
`mark_pr_ready` yourself. If the comment asks for work, do the work and reply instead.

A bot finding earns a code change only when it is plausible and consequential. Decline contrived findings with one
reasoned reply. When review rounds keep landing on one seam, fix the seam once or raise it with the user instead of
patching each finding.

## 7. Never invent a wait

Reports arrive on their own as `[PR Monitor]` messages, even while the session is idle, and start a new turn. Waiting
is never your job: no `sleep`, delayed commands, cron, background loops, repeated `gh pr checks`, or routine
`pr_watch_status` or `get_pr_report` calls. When nothing is left to handle, end your turn.

## Other tools

- `pr_watch_status`: this session's watches, their state and how many PRs this computer polls. Each watched PR costs
  about 60 GitHub GraphQL points an hour of the user's 5,000.
- `unwatch_pr`: stop this session's watch without waiting for the merge, when the user asks. Other sessions watching
  the PR keep theirs.
- `configure_pr_monitor`: change the auto-merge default (for every repository or one) and the report timings, only
  when the user asks. Turning auto-merge on asks the user to allow it first.
""";
