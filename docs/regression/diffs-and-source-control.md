# Diffs And Source Control

## Capability

Showing what a session changed on disk: the bridge-computed per-file diff
against the session's baseline, the project base-branch setting that defines
that baseline, and the branch and worktree facts a session carries.

## Required Behavior

- Diffs are computed by the bridge with local git and are plugin-agnostic; the
  only plugin contribution is the file-change signal that prompts a refresh.
- A dedicated-worktree session compares against the merge base with its recorded
  base branch; an in-place session compares against the exact HEAD commit
  captured at creation, even if local changes already existed.
- Untracked files count as additions; additions, deletions, and renames report a
  status with per-file counts. A file that cannot be shown returns an explicit
  skip reason (binary, too large, read error), never an empty change.
- An unreachable base and a base with no common ancestor are distinct
  client-visible failures, not empty change sets; a git failure is a failure.
  An archived session, or one whose worktree is gone, returns no diffs.
- The base branch can be read and set; setting rejects empty input and applies
  to later dedicated baselines, and the stable project identifier resolves to
  the live directory before git runs.
- A session reports its creation-time branch and dedicated-worktree facts; live
  current-branch and PR refresh belong to pull request monitoring. A mutating
  tool emits the diff refresh signal, and diffs stay encrypted from the relay.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because a meaningful diff requires a mutating live turn. |
| L2 Routine | Headless bridge, representative plugin: after a session edits files the diff lists them with before/after content and line counts; dedicated uses its base branch and in-place its creation-time commit. |
| L3 Release | Client end to end (phone), representative plugin: added, modified, deleted, and untracked files report correct status and counts; binary, too-large, and unreadable files return explicit skip reasons; base-branch read and set apply to later baselines; the diff list, per-file view, and refresh on the file-change signal render. |
| L4 Extended | Relay integration, every supporting production plugin: unreachable base and no-common-ancestor are distinct client-visible failures; archived sessions and removed worktrees return no diffs without erroring; a moved project still resolves git correctly; each plugin's file-change signal triggers a refresh reflecting the real change set. |
| L5 Full | Headless bridge for large mixed changes, non-git or commitless projects, and invalid base branches; relay integration to prove diff payload encryption. Representative plugin. |

## Exploration Guidance

Vary the change shape per run: single- and multi-file edits, new, deleted, and
renamed files, a binary asset, an oversized file, and mixes. Alternate dedicated
and in-place sessions, and default versus explicit base branches.

## Failure Signals

- The diff omits real changes, includes pre-session changes for an in-place
  session, or compares against the wrong base.
- A skipped file appears as an empty change instead of a skip reason, an
  unreachable base or missing ancestor flattens into an empty diff or opaque
  error, or an archived or missing worktree errors instead of returning nothing.
- Line counts disagree with content, especially untracked or deletion-only.
- Diffs never refresh after a mutating tool completes, or a moved project makes
  git run in the old directory.

## Known Limitations

- Per-file content is bounded; oversized files are skipped, not truncated.
- Diff rendering is phone-only; the desktop shell has no diff surface.
- Diffs require a git repository; non-git projects have no coverage by design.

## Sources

- Bridge: `bridge/app/lib/src/bridge/` session-diff and worktree services,
  `repositories/session_diff_repository.dart`, `api/git_cli_api.dart`, and the
  diff and base-branch handlers
- Contract: `shared/sesori_shared/lib/src/models/sesori/file_diff.dart`
- Client: `client/module_core/lib/src/cubits/session_diffs/`,
  `client/app/lib/features/session_diffs/`
- Tests: `bridge/app/test/bridge/services/session_diff_service_integration_test.dart`
