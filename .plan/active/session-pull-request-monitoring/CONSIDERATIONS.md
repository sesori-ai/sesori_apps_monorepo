# Current-Branch Pull Request Monitoring: Considerations

> **Non-authoritative.** Product and architecture decisions live in `PLAN.md`;
> execution state lives in `TRACKER.md`. This file records intentionally
> rejected alternatives and superseded context.

## Superseded Historical Design

The 2026-07-14 plan retained every named branch visited by a root session,
stored all associated PRs, rendered collapsed history, watched git `HEAD`
continuously, froze archive snapshots, and used adaptive per-project polling.

Rejected after the durable multi-plugin catalog shipped and the user
re-evaluated product value. Prior-branch history is noisy, has no approved
qualitative presentation, and forced branch-history, archive, reconciliation,
and lifecycle machinery that the current one-PR requirement does not need.

## Rejected Alternatives

### Account-wide authored PR cache

GitHub can globally search `author:@me`, but users sometimes take ownership of a
coworker's same-repository PR. Author-scoped discovery would silently miss that
core workflow. The final design queries exact active repository/branch targets
without an author filter.

### Globally search every visible PR

An unscoped global search is noisy, capped, and cannot safely discover every PR
that might match a local branch. Exact known repository/branch GraphQL
connections are smaller and deterministic.

### Repository-wide all-PR reconciliation

Fetching all PRs for every active repository wastes rate budget and recreates a
history cache the product no longer uses. The GraphQL query asks for only the
newest open and newest merged/closed candidate for each exact current target.

### Fork-head PR support

A coworker branch in the shared base repository is supported. A fork head also
needs local upstream/head-repository identity to prevent same-name branch
collisions. The user chose same-repository only for this plan.

### Filesystem branch watchers

Rejected because no branch history survives. Resolving current `HEAD` during
activation, each scheduled refresh, and explicit refresh provides the required
freshness without watcher enrollment/recovery/disposal state.

### Reuse creation `branch_name` for live state

Rejected because cleanup/restoration must continue targeting the bridge-created
worktree branch. A separate internal current branch is the only safe writer
boundary. The shared presentation field may map current state without changing
the persisted cleanup field.

### One selected PR row per session

Considered for simple reads, but it duplicates identical PR metadata across
sessions sharing a directory/branch. A scoped project/repository PR cache plus
current session repository/branch join deduplicates storage while still exposing
only one selected row per current target.

### One timer per project

Rejected because users may have several devices on different projects. One
connection-scoped active set and one aggregate completion-based timer can batch
all unique targets without independent timer/dispatcher state machines.

### Adaptive 15/90-second cadence

Rejected in favor of one fixed configurable interval. The user selected 30
seconds by default and values in seconds per bridge.

### JSON file watcher

Rejected. App/API mutations publish in-process changes for live timer updates;
manual JSON changes become active after restart.

### Archive-specific behavior

Rejected entirely. Archive neither freezes nor restarts PR tracking and adds no
snapshot/final-attempt persistence.

### Multiple-PR/history UI

Deferred to separate designer-led work if a valuable presentation emerges.
`pullRequestHistory` remains an empty compatibility field.

### Product analytics event

Rejected for this plan. PR rendering is passive, relevant identifiers are
privacy-sensitive, and no concrete product/retention decision currently
justifies a new event plus warehouse model.
