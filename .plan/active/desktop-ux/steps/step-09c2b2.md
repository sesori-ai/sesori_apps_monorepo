# Step 9.c.2b.2 — Project inventory and lower-layer refresh workflow

Delivery 18/22; planned branch `desktop-ux/project-refresh-ownership`.
Depends on 9.c.2b.1's scoped recent-session inventory service and production adapter.

## Required outcome

- Move authoritative project fetch execution and retained result state below `ProjectListCubit`, with its production
  consumer updated in the same PR. Lower-layer execution must not require a mounted presentation Cubit.
- Preserve initial loading, retained/live-patched rows, optimistic mutations, local-hide publication, catalog/reconnect
  refresh, failure presentation, lifecycle staleness, and request supersession without a second inventory.
- Expose one typed desktop refresh workflow using the same scoped project/recent service instances as the consumers.
  No operation ports implemented by Cubits and no request bus dispatched upward to presentation owners.
- Explicit all-project refresh must report the eventual owning reads, including a later read started after an earlier
  successor completed. Preserve failure observability and avoid extra timers, queues, retry policies, or ranking rules.
- Register lower-layer owners through module DI. Keep the signed-in scope and its disposal explicit; no global cache
  lifetime or new auth-reset machinery merely to make DI sharing convenient.

Prepare a fresh code-informed plan and architecture plan review before implementation. Target ≤1,400 all-path
changed lines and split further at a clean boundary if necessary. This slice has no intended UI/database change;
9.c.2c / 19/22 adds refresh feedback and control presentation after this owner is in place.
