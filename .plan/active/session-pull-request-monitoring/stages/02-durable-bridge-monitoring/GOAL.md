# Stage S02: Durable Bridge Monitoring

## 0. Stage Metadata

- **Stage ID:** S02
- **Status:** Pending
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main`
- **PR count:** 4
- **Manual checkpoints:** 0

## 1. Outcome

The headless bridge durably observes root-session branches, discovers authored
same-repository PRs under the active local GitHub account/repository identity,
serves current and historical PR data, freezes terminal archive snapshots, and
schedules GitHub work only for viewed projects. Project/PR changes reach clients
through the existing `sessionsUpdated` SSE seam without changing unseen state.

## 2. Entry Criteria and Baseline

- S01 is merged to `main` and additive contracts are available to all bridge
  code.
- Each wave fetches `main`, assesses drift from the latest plan audit and prior
  merged wave, and pins the exact assessed repository/base tip in `TRACKER.md`.
- The current Drift schema and generated migration history are read before each
  schema-owning wave. The audit saw v10; no step assumes that number remains
  current.
- Parallel-plugin Stage 2 remains paused throughout S02.

## 3. Invariants and Non-Goals

- GitHub and git behavior stays outside `BridgePluginApi`.
- Local branch observation is push-based; GitHub polling is view-scoped and
  bounded because `gh` exposes no event stream.
- New Layer 4 consumers live under `lib/src/listeners/pr_monitor/`, own one
  trigger lifecycle each, and do not depend on peers.
- `Orchestrator` alone constructs/wires layers and emits SSE; `BridgeRuntime`
  owns lifecycle of the already-composed orchestrator only.
- Repository peers never depend on each other; services/consumers receive
  repositories or typed streams.
- One writer owns each directory, branch, live-cache, and terminal-snapshot
  concern.
- Every merged wave is independently releasable and migration-safe.
- No mobile sender or collapsed history presentation is included in S02.
- No push notification, unseen mutation, forge-neutral abstraction, or desktop
  process behavior is introduced.

## 4. Execution Waves

| Wave | ID | PR | Repository | Base | Can run in parallel | Merge barrier |
|---|---|---|---|---|---|---|
| W01 | S02-W01-P01 | Durable filesystem-driven branch observation | `sesori-ai/sesori_apps_monorepo` | `main` | No | Merge before W02 |
| W02 | S02-W02-P01 | Authored identity-scoped PR refresh | `sesori-ai/sesori_apps_monorepo` | `main` | No | Merge before W03 |
| W03 | S02-W03-P01 | Terminal archive snapshots and final attempt | `sesori-ai/sesori_apps_monorepo` | `main` | No | Merge before W04 |
| W04 | S02-W04-P01 | Viewed-project presence and adaptive scheduling | `sesori-ai/sesori_apps_monorepo` | `main` | No | Merge before S03 |

The waves are sequential because each consumes schema, repositories, and typed
streams introduced by the previous wave. They are not stacked PRs: each branch
starts from the current tip of `main` after its predecessor merges.

## 5. Integration and Manual Verification

- W01 integration proves one filesystem subscription can fan one branch change
  into independent session rows and typed project invalidation data.
- W02 integration proves request -> authored query -> identity recheck -> cache
  -> session headline/history -> `sessionsUpdated` without phone presence.
- W03 integration proves archive response does not await GitHub, terminal reads
  are immutable, and the one final request cannot restart or retry.
- W04 integration proves multi-connection project presence owns timers and that
  relay drop cancels all scheduled work.
- Each wave runs its migration/codegen/analyze/test commands. S02 exit runs the
  bridge-wide integration suite; real credentials remain reserved for the S03
  advisory manual checkpoint.

## 6. Exit Criteria

- All four S02 PRs are merged to `main` in wave order.
- Every schema version introduced by S02 remains exported and migration-tested.
- Branch watchers survive duplicates, shared checkouts, detach/reattach,
  failures, archive races, and shutdown without periodic git polling.
- Authored PR cache and archive snapshots remain account/repository/path-scoped;
  detected identity changes suspend live visibility and terminal refreshes fail
  closed.
- No unviewed project schedules GitHub work; branch observation continues.
- Existing wait/non-wait session request behavior and unseen behavior remain
  green.
- `TRACKER.md` points to S03/W01.

## 7. Stage-Specific Detail

S02 deliberately separates local branch truth from network freshness. A branch
transition is useful and visible even when `gh` is missing, unauthenticated, or
timed out; the persisted branch-change stream therefore drives its own
`sessionsUpdated` path independently from PR refresh completion.
