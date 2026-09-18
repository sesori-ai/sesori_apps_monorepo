# Step 9.c.2b — Lower-layer sidebar refresh ownership

Delivery 17/21; planned branch `desktop-ux/sidebar-refresh-ownership`.
Status: pending #1533 merge.

## Required outcome

- Move authoritative project and recent-session inventory fetch execution and retained result state below presentation
  Cubits. A lower-layer refresh must execute without a mounted `ProjectListCubit` or `RecentSessionsCubit`.
- Let Cubits consume lower-layer state/results while preserving existing initial loading, loaded-data retention, live
  patching, lifecycle-generation staleness, catalog/reconnect refresh, failure presentation and supersession behavior.
- Make explicit all-project refresh report the eventual owning reads' outcomes, including a later read that starts after
  an earlier successor completed.
- Register lower-layer owners through DI; desktop-core may depend only on those owners, never Cubit implementations.
- Add no second data cache, timer, backend request shape, project-view claim, ranking rule or speculative coordinator.

## Delivery boundary

Prepare a fresh code-informed plan and architecture plan review after 9.c.2a merges. Keep this change independent from
9.c.2c explicit-refresh and control composition. If a coherent implementation approaches the 1,400-line target,
split at an independently valid lower-layer boundary rather than adding temporary compatibility APIs or feeding an
oversized review loop.
