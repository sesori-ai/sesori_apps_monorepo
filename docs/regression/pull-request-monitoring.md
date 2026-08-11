# Pull Request Monitoring

## Capability

Each root session shows its directory's live current Git branch and, when one
exists, one GitHub pull request for it. The bridge refreshes both while a client
declares it is viewing the project, on a bridge-wide interval the client can
change. Bridge-owned, plugin-agnostic, backed by the user's local gh CLI.

## Required Behavior

- Only root sessions carry branch/PR state; sessions sharing a directory share it.
  Detached HEAD, a missing or non-Git directory, or resolution failure yields no
  branch and no PR; a named branch with a non-GitHub remote still shows.
- Selection matches canonical lowercase owner/repo plus the exact case-sensitive
  head branch, rejects fork heads, ignores author, and prefers newest open (drafts
  included), else newest merged/closed, by creation time then PR number.
- A branch or repository change invalidates the prior selection before any network
  work and never falls back to a previous branch's PR.
- Every PR-bearing read is gated on a fresh gh identity check; unknown, failed, or
  switched login returns session and branch without PR metadata instead of another
  account's cache. No token is stored, no GitHub login reaches clients, and logs
  carry no branch, repo slug, PR title, URL, or path.
- Presence is connection-scoped and unioned across devices; one timer serves the
  active set and none runs while it is empty. The interval defaults to 30s, is
  validated 15-3600s, changes live, and needs a restart for manual config edits;
  older bridges render as unsupported.
- PR changes emit only project-scoped sessionsUpdated: no unseen state, no push.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, no plugin: a session in a GitHub repository with a matching open PR returns its branch and one PR; a missing or unauthenticated gh still serves sessions and branches. |
| L2 Routine | Automated and headless bridge over fake gh/Git: open-before-terminal ordering, fork-head rejection, coworker PR acceptance, branch switch clearing a stale PR, detached/non-Git/non-GitHub outcomes, root-versus-child scope. |
| L3 Release | Client end to end on the release-target client platform: branch and PR rendered on list and detail, presence-driven refresh without manual pull, bounded explicit refresh, cadence read and changed from settings including out-of-range rejection. |
| L4 Extended | Relay integration with multiple clients: presence union across two devices and projects, release on background/disconnect, relay loss clearing claims, identity switch failing closed, transient GitHub failure retained versus invalidated, old bridge/client degrading. |
| L5 Full | Real authenticated GitHub account: batched targets beyond the per-command bound, pagination past newer fork heads, terminal fallback on a real merged PR, and a recheck that installed gh still returns the required fields. |

## Exploration Guidance

Vary repository and branch shape rather than tap order: dedicated worktree versus
plain directory, roots sharing a directory, draft, merged, coworker-authored, no
PR, moved path, non-GitHub remote. Vary cadence at and just outside both bounds and
alternate whether list or detail holds the claim.

## Failure Signals

- A PR from a previous branch, deleted directory, or another GitHub account stays
  visible; a child session shows a PR; a fork head or newer fork-head candidate
  beats an eligible same-repository PR.
- Branch updates but the stale PR remains, the branch clears merely because GitHub
  is unreachable, or the change bumps unseen state or sends a push notification.
- Refresh cycles overlap, run with no viewer, stop after an interval change, make a
  newly viewed project wait a full interval, or leak branch names, repo slugs, PR
  titles, URLs, or paths into normal-level logs.

## Known Limitations

- GitHub.com only. One PR per root session; no history, detail route, comments, or
  mutations. No filesystem watcher, so manual settings-file edits need a restart.
- Fakes cannot prove real GitHub behavior, rate limits, or gh schema drift; those
  stay partial unless L5 ran against a real account.

## Sources

Bridge gh_cli_api, git_cli_api, pr_source_repository, pull_request_repository,
pr_sync_service, project_view_tracker, viewed_project_pr_refresh_listener, PR
refresh settings; client project_viewing_service and bridge settings.
