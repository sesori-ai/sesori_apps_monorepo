---
name: pr-inline-comments
description: Fetch inline (code) review comments on a GitHub pull request, grouped into threads, with optional filtering by datetime. Use when the user asks to read or address PR comments, code review feedback, reviewer notes, or wants to see only recent review activity on a PR. Resolves natural-language time windows like "last 30 minutes", "since yesterday 5 PM", or "since commit abc123" into ISO 8601 before invoking the script. Requires gh and jq.
---

# pr-inline-comments

Returns inline code review comments on a PR, grouped into threads, optionally filtered by datetime and/or resolution status. Issue-level PR comments (those not anchored to a line of code) are not included.

Backed by the GitHub GraphQL API, which exposes review threads natively (with `isResolved` and `isOutdated`). The REST `/pulls/{n}/comments` endpoint does not expose resolution status.

## Output schema

A single JSON array of thread objects. Thread-level fields appear once per thread. Per-comment fields live only inside `comments[]`.

```json
[
  {
    "thread_id": 100,
    "path": "src/foo.ts",
    "line": 42,
    "side": "RIGHT",
    "start_line": null,
    "is_resolved": false,
    "is_outdated": false,
    "commit_id": "abc123",
    "diff_hunk": "@@ -40,3 +40,3 @@",
    "url": "https://github.com/o/r/pull/1#discussion_r100",
    "latest_at": "2026-04-29T13:30:00Z",
    "comments": [
      { "id": 100, "user": "alice", "body": "...", "created_at": "...", "updated_at": "...", "html_url": "..." },
      { "id": 101, "user": "bob",   "body": "...", "created_at": "...", "updated_at": "...", "html_url": "..." }
    ]
  }
]
```

Thread-level fields (`thread_id`, `path`, `line`, `side`, `start_line`, `is_resolved`, `is_outdated`, `commit_id`, `diff_hunk`, `url`, `latest_at`) come from the thread itself or its root comment. Replies do not repeat them. Per-comment fields are limited to `id`, `user`, `body`, `created_at`, `updated_at`, `html_url`.

`thread_id` is the GraphQL `databaseId` of the root comment, equivalent to the REST comment id (a stable integer).

`latest_at` is the maximum `createdAt` across all comments in the thread.

Threads are sorted by `path`, then `line`, then `thread_id`.

## Invocation

```bash
./scripts/fetch.sh <pr-number> [--since ISO_DATETIME] [--unresolved] [--repo OWNER/REPO]
```

Flags:

- `--since ISO_DATETIME`: keep only threads whose **latest comment** is at or after the given datetime. Inclusive. The whole thread is returned (including older replies) when it qualifies.
- `--unresolved`: keep only threads where `is_resolved == false`.
- `--repo OWNER/REPO`: override the current repo. Defaults to `gh repo view --json nameWithOwner`.

`--since` and `--unresolved` compose: a thread must satisfy both to be kept.

## `--since` accepted formats

The script validates input strictly and normalizes to UTC `Z` form internally. Any of these are accepted:

```
2026-04-29T14:30:00Z
2026-04-29T17:00:00+03:00
2026-04-29T17:00:00+0300
2026-04-29T14:30:00.123Z          # fractional seconds are accepted and stripped
```

Invalid inputs (no timezone, date only, wrong shape) cause the script to exit with a clear error before any API calls.

If the input is not already in canonical UTC `Z` form, the script prints a normalization line to stderr, e.g.:

```
Normalized --since: 2026-04-28T17:00:00+03:00 -> 2026-04-28T14:00:00Z
```

This is informational only and does not affect stdout.

## Resolving `--since` from natural language

Convert the user's expression to **any** valid ISO 8601 datetime with a timezone, then pass it to the script. The script handles UTC normalization regardless of platform. There is no need to use `date -d` (GNU) or `date -j -f` (BSD) directly.

### Relative durations

Examples: "last 30 minutes", "past 2 hours", "in the last day", "last week".

Use Python (always available on macOS and Linux, stdlib only):

```bash
# 30 minutes ago, in UTC Z form
python3 -c "from datetime import datetime, timedelta, timezone; print((datetime.now(timezone.utc) - timedelta(minutes=30)).strftime('%Y-%m-%dT%H:%M:%SZ'))"

# 2 hours ago
python3 -c "from datetime import datetime, timedelta, timezone; print((datetime.now(timezone.utc) - timedelta(hours=2)).strftime('%Y-%m-%dT%H:%M:%SZ'))"

# 1 day ago
python3 -c "from datetime import datetime, timedelta, timezone; print((datetime.now(timezone.utc) - timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))"
```

For "current UTC now" without a library, POSIX `date` works on both platforms:

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

### Clock-time references

Examples: "since yesterday 5 PM", "since Monday 9 AM", "since this morning".

Resolve in the user's local timezone (assume system local unless they explicitly state otherwise). Produce an ISO 8601 datetime with the local offset; the script will convert to UTC.

```bash
# Yesterday 17:00 local
python3 -c "
from datetime import datetime, timedelta
local_now = datetime.now().astimezone()
target = (local_now - timedelta(days=1)).replace(hour=17, minute=0, second=0, microsecond=0)
print(target.strftime('%Y-%m-%dT%H:%M:%S%z'))
"
# e.g. 2026-04-28T17:00:00+0300
```

The script accepts `+0300` and `+03:00` equivalently. For "Monday 9 AM" or other named days, compute the target date in Python with `weekday()` arithmetic.

For ambiguous expressions like "this morning", pick a sensible boundary (e.g., 06:00 local) and state it back to the user.

### Commit references

Examples: "since commit abc123", "since the latest commit on main", "since I pushed".

```bash
SHA=abc123
gh api "/repos/${REPO}/commits/${SHA}" --jq '.commit.committer.date'
# -> 2026-04-29T12:34:56Z
```

Use `.commit.committer.date` for "when this commit landed on the branch", which is the usual interpretation. Use `.commit.author.date` only if the user explicitly means when the commit was originally written (different on rebased history).

For "since the head of the PR":

```bash
gh pr view <pr-number> --json commits --jq '.commits[-1].committedDate'
```

For "since the last commit on the current branch":

```bash
SHA=$(git rev-parse HEAD)
gh api "/repos/${REPO}/commits/${SHA}" --jq '.commit.committer.date'
```

### Confirming back to the user

Before running the script, print one line confirming the resolved value:

```
Resolved "yesterday 5 PM" to 2026-04-28T17:00:00+03:00 (your local 17:00 EEST).
```

If the script then emits a `Normalized --since: ...` line on stderr, that's expected.

## Common workflows

- "Show me unresolved comments on PR 123" → `fetch.sh 123 --unresolved`
- "What review feedback came in since I pushed?" → resolve commit date, then `fetch.sh <pr> --since <date>`
- "What unresolved threads need my attention from the last day?" → `fetch.sh <pr> --unresolved --since <24h ago>`
- "Show me everything reviewers said on this PR" → `fetch.sh <pr>` (no flags)

## Threading details

- Threads come from the GraphQL `pullRequest.reviewThreads` connection, which already groups comments natively. No client-side chain walking is needed.
- `is_outdated` means the line the comment was anchored to has been changed in a newer push. Outdated comments may have `line: null`; the script falls back to `originalLine`.
- Inner comments per thread are capped at 100. If any thread exceeds that (extremely rare in practice), the script prints a warning to stderr.

## Dependencies

- `gh` (authenticated via `gh auth login`)
- `jq` 1.6+
- `python3` (standard library only, used for natural-language datetime conversion)
- POSIX shell

## Notes

- The script always emits a single JSON array, including the empty case `[]` when no threads match.
- Outer pagination (more than 100 threads on a PR) is handled by `gh api graphql --paginate`.
- Platform differences (Linux GNU `date` vs macOS BSD `date`) are handled inside the script. The agent does not need to branch on platform.
