# Setup-Aware Transient Plugin Lifecycle: Tracker

## Plan State

- **Status:** Plan corrected after the second architecture review; onboarding
  W02 is complete and the plan is ready to implement after landing
- **Implementation base:** `main`
- **Initial audited tip:** `c491d7c40a0ef86c7bfeabf71ccbe1b9009849b0`
- **Post-W02 audited tip:** `2acd7b876667c4abeb7613ae6e46d0010a1241be`
- **Plan slug:** `setup-aware-plugin-lifecycle`
- **Predecessor:** parallel-plugin Stages 0-9 complete; PR #497 merged
- **Entry dependency:** satisfied — bridge-app-onboarding W02 merged in PR #504

## Current Pointer

- **Stage:** Planning
- **Next action:** Land this plan PR, then branch S10-P01 from the then-current
  `main` and reassess drift from the post-W02 audited tip. The second review
  findings were applied directly; this corrected version was not reviewed again
  and is not recorded as reviewer-approved.

## Plan Review

| Pass | Verdict | Reviewer | Date | Scope |
|---|---|---|---|---|
| 1 | `TOO_VAGUE` | `aristotle-plan-review` | 2026-07-18 | Initial `PLAN.md` and `TRACKER.md` against main through `120a6f41` |
| 2 | `REJECT` | `aristotle-plan-review` | 2026-07-18 | Clarified runtime/startup/migration/wire/client/file-boundary plan; seven blocking ownership/semantics gaps returned for direct correction |

## Value Stages

| Done | Stage | User value | Release-safe boundary |
|---|---|---|---|
| [ ] | Stage 10 — Setup-aware automatic plugins | Detect and auto-enable setup-ready plugins; explain blocked plugins; keep zero-plugin bridge online | Explicit CLI/settings behavior preserved; inspection has no install/login/start side effects |
| [ ] | Stage 11 — Transient on-demand runtime | Wake for real work and release idle plugin resources | Compatibility migration remains eager until every operation uses acquisition |
| [ ] | Stage 12 — Headless hot lifecycle control | API enable/start, disable/stop, restart, setup refresh, idle policy and safe force | Additive E2E API; one plugin action never stops bridge/catalog/peers |
| [ ] | Stage 13 — Mobile plugin control | Phone management, confirmations, default/order and idle timeout | New app degrades gracefully against old bridges; bridge API ships independently |

## Implementation PRs

PR boundaries are finalized against the then-current code before each stage.
Stage 11 is expected to use one compatibility-preserving acquisition migration
PR and one value-bearing dormancy cutover PR; other stages should remain one
focused PR unless drift demonstrates a concrete release-safety reason to split.

| Done | ID | Dependency | Purpose | PR |
|---|---|---|---|---|
| [ ] | S10-P01 | Onboarding W02 complete | Setup inspection, auto selection, zero-plugin bridge, setup API | — |
| [ ] | S11-P01 | S10 | Dynamic acquisition/generation boundary under unchanged eager behavior | — |
| [ ] | S11-P02 | S11-P01 | Demand activation, dynamic events and configurable idle suspension | — |
| [ ] | S12-P01 | S11 | Headless controls, remote authority, safe/force and lifecycle SSE | — |
| [ ] | S13-P01 | S12 | Module-core and mobile lifecycle management | — |

## Blockers And Staleness

- No implementation blocker is currently known. Bridge-app-onboarding W02
  merged in PR #504 at `2acd7b876667c4abeb7613ae6e46d0010a1241be`.
  Its advisory M01 manual checkpoint is not an entry dependency for this plan.
- The post-W02 audit confirms the checkpoint remains after authentication and
  concurrent enabled-plugin availability, and before predecessor wait, startup
  mutex, provisioning, and plugin start. S10 explicitly removes the current
  non-empty-availability exit/gate when zero-plugin startup becomes valid while
  preserving standalone/interactivity checks.
- The independent session-pull-request-monitoring plan may continue. Before each
  implementation PR, assess overlap in `Orchestrator`, session repositories,
  event flow and client session detail; stop for plan correction only when drift
  changes a locked lifecycle decision or release boundary.
- Desktop UI is not a dependency. Its future surface consumes module-core logic.
- Phone-driven runtime installation/authentication is a separate future plan and
  does not block Stages 10-13.
- `origin/main` advanced first to the docs-only `120a6f41`, then to W02 merge
  `2acd7b87`. PR #504 added the bounded onboarding API/storage/repository/service
  path and the runner checkpoint; it introduced no plugin lifecycle boundary.

## User Decisions

- 2026-07-18: Automatic mode derives all setup-ready plugins.
- 2026-07-18: Durable phone authority overrides replayed CLI selection until a
  local reset.
- 2026-07-18: Enable starts and disable stops; restart is separate.
- 2026-07-18: Ordinary stop/restart is safe; confirmed force may interrupt.
- 2026-07-18: Idle policy is persisted per-plugin-capable as
  `suspendAfter(duration)` or `alwaysOn`, with a ten-minute inherited default.
  Headless API/config supports overrides now; mobile exposes only one
  apply-to-all selector and `Never` means `alwaysOn` for all.
- 2026-07-18: Concrete backend operations wake dormant plugins; catalog and
  management reads do not.
- 2026-07-18: “Install from phone” means backend runtime provisioning, not
  downloading plugin implementation code.
- 2026-07-18: Phone install/login is directionally required but belongs to a
  separate future plan.
- 2026-07-18: The bridge remains online and browseable with zero plugins.
- 2026-07-18: Mobile ships first with shared module-core ownership.
- 2026-07-18: Implement the full staged lifecycle refactor after onboarding W02.
- 2026-07-18: Stages must deliver real value, every PR must remain releasable,
  and tests are added only when they provide actual confidence.

## Findings And Plan Deltas

- 2026-07-18: Initial draft created from latest `main` after Stage 9 and the
  reduced onboarding plan merged. The plan separates setup inspection from
  availability/provisioning, selection from residency, and current lifecycle
  work from later phone install/login.
- 2026-07-18: First architecture review returned `TOO_VAGUE`. Blocking gaps were
  unnamed runtime/start ownership, no ordered zero-plugin startup model, an
  inventory rather than method-level acquisition migration, ambiguous settings
  layering, unspecified HTTP/SSE/shared contracts, undecided client ownership,
  phone provisioning contradicting the locked deferral, and no per-PR production
  file ledger.
- 2026-07-18: Clarified the plan with exact `PluginGenerationStarter`,
  `BridgePluginGenerationStarter`, `PluginRuntimeApi`,
  `PluginLifecycleRepository`, and `PluginLifecycleService` files,
  constructors, APIs and dependency direction; a raw-argv-to-zero-plugin phase
  model; generation/event/shutdown flow; method-level migration matrix; exact
  routes/DTOs/status codes/SSE; locked module-core service/cubit and mobile-shell
  ownership; explicit `existingOnly` remote enablement; and exact production
  files/cutover gates for S10-P01 through S13-P01.
- 2026-07-18: The permitted second review returned `REJECT`. It found a
  Layer-1/type-name collision, abort-controller ownership split across API and
  service, unsafe disable persistence outside the transition lock, backend
  events incorrectly resetting idle eligibility, two potential automatic
  catalog-hydration owners, a speculative phone-login capability, and an unnamed
  S10 setup-inspection handoff.
- 2026-07-18: Applied those findings directly: the runtime boundary is named
  `PluginRuntimeApi`; it exclusively owns per-generation abort controllers;
  disable uses a callback-scoped durable commit while the per-plugin transition
  lock remains held; only leases and work-state transitions affect idle timing;
  one replay-latest `PluginCatalogHydrationListener` owns automatic hydration;
  the deferred login capability was removed; and S10 now names
  `BridgeRuntimeRunner` as probe producer with an immutable setup map handed to
  `PluginLifecycleService.initialize`. Per review policy, no third approval pass
  was requested.
- 2026-07-18: Re-audited `origin/main` after onboarding PR #504 merged. The
  current runner invokes onboarding only for standalone interactive startup when
  at least one enabled descriptor passed availability, immediately before
  predecessor wait/start locking. No staged lifecycle architecture changed. S10
  now names its one integration delta: because an empty effective plugin set no
  longer exits, that still-live standalone interactive bridge runs the same
  bounded checkpoint without a non-empty-availability condition.
