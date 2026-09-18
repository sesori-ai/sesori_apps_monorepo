# Step 9.c.2c — Typed sidebar refresh and purposeful controls

Planned delivery 19/22, after project inventory ownership (18/22) merges.
This successor owns both the typed refresh workflow and its first production control, not presentation alone.
Target ≤1,450 all-path changed lines, including generated output, tests and documentation;
remeasure before publishing.

## Required behavior

- Compose the existing scoped `ProjectInventoryService` and `RecentSessionInventoryService` instances below
  presentation. Neither Cubits nor widgets implement operation ports, complete request buses, or perform sequencing.
- Explicit refresh updates current projects and their recent-session inventories. Follow eventual winning reads even
  when a later owning read supersedes a successor that has already completed. Preserve failure and supersession
  observability; useful rows remain visible. Add direct lower-layer tests for these sequences before claiming them.
- Ship the workflow with its first refresh control and typed busy/failure presentation. No future-only API, second
  inventory, new automatic retry policy, timer, global registry, or per-row persistence is justified by this delivery.
- Keep `_SidebarInventory` render-only and the Activity projection Flutter/Prego-free at desktop-core Layer 4.
  Preserve all-project Activity, priority exclusions, selected-session pinning, independent action scopes and leases.
- Simplify controls using plain-language local-computer wording. Keep local supervision distinct from a connected
  remote computer; Quit remains app-scoped. Retain useful-only hints, semantics, stable keys, reduced motion and
  native Apple indicators. Any applicable analytics use existing authoritative outcomes, not arbitrary tap tracking.

## Execution boundary

Selectively reuse the local stash named `sidebar-activity-controls-successor`, object
`1bfa2c1ff8ad859773303eb60e7a81902d7d8668` (created on `desktop-ux/sidebar-activity-controls`).
Find it by that identity, not a mutable stash-list position. Do not restore superseded Activity ownership or obsolete
refresh-bus code. Create a concrete code-informed plan and obtain its scoped architecture plan review before
implementation. This document records the accepted PR boundary and retained requirements, not implementation approval.

Run focused fake-backed service/adapter/control tests and owning analyzers. Do not bootstrap production DI, relaunch
the real GUI, stop/take over a bridge/helper, touch authentication/preferences/registration or run the app smoke
locally.
Synthetic previews, automated tests and architecture review do not establish native qualification.
