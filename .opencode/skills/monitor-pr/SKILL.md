---
name: monitor-pr
description: Monitor GitHub PRs with the pr_monitor tool and handle incoming "[PR Monitor]" reports. Use immediately after raising a PR, when the user asks to monitor/watch a PR, and whenever a "[PR Monitor]" message arrives in the session (CI results, new review comments, merge conflicts, approvals). Requires gh.
---

# monitor-pr

Watch a GitHub PR in the background via the `pr_monitor` tool and act on the
factual reports it delivers to this session.

## Starting a monitor

**Proactively start a monitor right after raising a PR** (e.g. after `gh pr create`):

```
pr_monitor(action: "start", pr: "owner/repo#123")
```

- The `pr` argument is always explicit — `owner/repo#123` or a full PR URL. Never a bare number.
- One monitor per PR; start several monitors for several PRs.
- Monitors belong to this session and **do not survive an opencode restart**. When
  resuming PR work in a fresh opencode instance, check `pr_monitor(action: "status")`
  and re-start monitors as needed.
- Tuning (debounce, poll interval, CI wait, ignored comment tag) lives in
  `.opencode/pr-monitor.json` — not in tool arguments.

## Handling a `[PR Monitor]` report

Reports state facts only (CI status, mergeability, reviews, comment counts). Decide and
act as follows, addressing everything in the report in one batch:

| Report says | Do this |
| --- | --- |
| `CI: failing (…)` | Inspect the failures (`gh pr checks <pr> --repo owner/repo`, `gh run view <run-id> --log-failed --repo owner/repo`), fix the root cause, commit and push. Never delete or weaken tests to go green. |
| `Mergeable: CONFLICTING` | Merge the latest base branch INTO the PR branch: `git fetch origin && git merge origin/main`. **NEVER rebase.** Resolve conflicts conservatively so functionality from both sides is preserved — when unsure, read the full context of both changes before choosing. Run the relevant tests, then push the merge commit. |
| New inline comments / `changes_requested` | Follow the `address-pr-comments` skill: fetch unresolved threads, assess validity, implement fixes, reply to every thread. |
| New issue comments | Read them (`gh pr view <number> --repo owner/repo --comments`) and act only if they request something. |
| Approved + CI passing + 0 unresolved threads | Nothing to fix — summarize the PR state to the user. |
| `— MERGED` / `— CLOSED` | The monitor already stopped itself. Nothing to do. |

## After handling a report — ALWAYS flush

Finish every handled cycle with:

```
pr_monitor(action: "flush", pr: "owner/repo#123")
```

This returns the current full status and advances the "new since last flush" baseline
past your own pushes and replies, so they are not echoed back as new activity. Skipping
this step causes a redundant wake-up report about your own follow-up comments.

## Other actions

- `pr_monitor(action: "status")` — list this session's monitors (also useful before ending a work session).
- `pr_monitor(action: "stop", pr: "owner/repo#123" | "all")` — stop watching without waiting for merge.
