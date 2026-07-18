# Sesori — Implementation Roadmap

> A **dependency-ordered** suggestion for the order to build toward `VISION.md` —
> *not* a calendar and *not* a commitment (horizon is ≥ ~1 year, funding/team
> dependent). The *what / why* lives in `VISION.md`; the *how* (layer rules) in
> `AGENTS.md`; the active desktop workstream in `docs/desktop/PLAN.md`.
>
> **Use it like this:** pick the earliest stage whose dependencies are met;
> stages can overlap. Every stage still goes through `aristotle-plan-review`
> before code and `aristotle-impl-review` before a PR — this doc pre-approves no
> design. Ordering is by what *unblocks* what, biased to keep the `VISION.md`
> invariants (numbered below as I1–I9) intact.

## Already in flight / landed

- Second backend shipped: **Codex** plugin alongside OpenCode — proves
  multi-backend.
- Ordered **parallel-plugin runtime** is implemented: repeated CLI selection or
  persisted `enabledPlugins`, isolated lifecycle/failure, per-plugin imports and
  events, and database-only mixed catalog reads.
- Client **plugin selection and scoped composer resources** are implemented for
  new and existing sessions.
- Stage 9's fixed-host parallel-plugin performance and concurrency gates passed;
  the completed bridge catalog no longer requires plugin I/O for normal lists.
- Bridge **control channel** + supervised mode — desktop-supervision groundwork.
- Shared **runtime provisioning** — auto-installs backend runtimes on first run.
- Multi-bridge **seam** on the client (`bridge_api` / `bridge_repository` /
  `registered_bridges_store`).

## Stage A — Desktop app (multi-surface) — *in progress*

- **Outcome:** a downloadable desktop app that supervises the headless bridge
  (tray + window), and a client split into shared UI + per-surface shells.
- **Detail:** owned entirely by `docs/desktop/PLAN.md` (Phases 0–5); not
  duplicated here.
- **Unlocks:** always-on ergonomics; proof the core is surface-agnostic; the
  `module_app_ui` shared-UI split.
- **Invariants:** I3 (shared brain / thin shells), I4 (headless-first).

## Stage B — Multi-plugin parallelism + per-session model control — *complete*

- **Implemented outcome:** run ordered enabled plugins concurrently with
  independent lifecycle/failure; browse one database-backed catalog; import each
  plugin independently; choose a plugin and its agents/models/commands in the
  client. Existing-session composer requests use the stored plugin identity.
- **Compatibility:** the bridge's enabled/default marker is separate from the
  fixed OpenCode identity used only when released peers omit `pluginId`.
- **Final evidence:** Stage 9's controlled fixed-host matrix, publication runs,
  import/event soak, Codex soak, and startup runs passed all release gates. The
  raw results are retained in the versioned parallel-plugin baseline artifact.
- **Capability policy:** current backends satisfy the declared plugin API shape;
  no speculative all-true capability descriptor was added. Introduce an
  optional capability only for a demonstrated backend difference.
- **Depends on:** independent of Stage A.
- **Unlocks:** own harness (D), master agent (G), a richer client.
- **Explicitly excluded:** moving a *live* session between plugins (VISION
  non-goal).
- **Invariants:** I1 (plugin boundary; capabilities declared, not special-cased).

## Stage B2 — Setup-aware transient plugin lifecycle — *planned next; bridge onboarding complete*

- **Outcome:** registered plugins report bounded read-only setup readiness;
  setup-ready plugins are selected automatically when no explicit policy exists;
  enabled plugins wake for concrete operations, stop after their effective idle
  policy, and can be enabled/started, disabled/stopped, or restarted independently
  through the headless bridge API and mobile UI. The bridge and durable catalog
  remain online with zero active plugins.
- **Resource policy:** idle configuration is per-plugin-capable
  (`suspendAfter(duration)` or `alwaysOn`) with a ten-minute inherited default.
  Headless callers may set overrides; the first mobile UI intentionally exposes
  only one apply-to-all control, including `Never`/always-on.
- **Authority:** a deliberate phone selection becomes durable and wins across
  bridge restarts until a local reset returns authority to CLI/settings/automatic
  selection.
- **Delivery:** four value-bearing, independently releasable stages cover setup
  detection/automatic mode, transient activation, headless hot control, and
  mobile control. Any internal migration PR preserves eager behavior until the
  complete acquisition cutover is safe to activate.
- **Dependency status:** B is complete and bridge-app-onboarding W02 merged in
  PR #504. The detailed plan re-audited its `BridgeRuntimeRunner` checkpoint and
  names the exact zero-plugin integration delta before provisioning and start.
- **Detail:** `.plan/active/setup-aware-plugin-lifecycle/PLAN.md`.
- **Unlocks:** scaling to many plugins without resident CPU/memory cost and the
  later phone-driven backend setup stage.
- **Invariants:** I1 (plugin boundary), I4 (headless-first), I9 (eligibility is
  not residency).

## Stage B3 — Phone-driven backend installation and login — *later, not yet planned*

- **Outcome:** from the phone, a user can initiate installation/provisioning of
  the backend runtime for a registered plugin and complete a plugin-owned login
  flow, with progress and failures surviving normal relay reconnects.
- **Boundary:** this installs backend runtimes for trusted registered
  descriptors; it does not download arbitrary plugin implementation code.
- **Depends on:** B2 setup states, zero-plugin bridge operation, dynamic
  activation, progress/status APIs, durable remote authority, and mobile plugin
  management.
- **Planning:** authentication UX, secret handling, OAuth/device-code behavior,
  cancellation, and per-plugin installation capabilities require a separate
  future architecture plan when implementation is near.
- **Invariants:** I1, I4, I6, I9.

## Stage C — Multi-bridge addressing

- **Outcome:** a user can enumerate and choose among *their* bridges (laptop,
  desktop, later a VM); the client aggregates sessions across bridges; relay +
  auth route to a specific bridge.
- **Depends on:** little new plumbing — multi-client per bridge already works and
  the client seam exists; this is mostly addressing/selection + relay/auth
  routing by bridge identity. Independent of Stage B.
- **Unlocks:** the cockpit across machines; **prerequisite for managed VMs** (a
  VM is "just another bridge").
- **Invariants:** I2 (bridge is one of many), I3.

## Stage D — Sesori's own harness (as a plugin)

- **Outcome:** a first-party agent harness implemented **behind
  `BridgePluginApi`**, with no privileged path. Add an optional capability only
  if this concrete backend cannot implement an existing contract operation.
- **Depends on:** B (parallel composition and plugin-scoped client routing).
- **Invariants:** I1.

## Stage E — CI / review integration with opt-in auto-handle

- **Outcome:** forge-neutral PRs / comments / checks surfaced in the client; an
  **opt-in** mode where the bridge posts a message into the relevant session to
  address a failed check or new review automatically.
- **Depends on:** a stable session-control surface; notifications (already core);
  bridge-side forge access (keeps local E2E — the bridge holds the creds).
- **Invariants:** I5 (one session-control surface), I8 (autonomy at the bridge
  seam).

## Stage F — Managed service (paid)

- **Outcome:** run sessions on Sesori-controlled VMs — pick a repo, work without
  keeping your machine on. A cloud control-plane: VM provisioning/lifecycle, repo
  selection, **secure secret/credential injection**, the headless bridge running
  on the VM, and billing.
- **Depends on:** C (a managed VM is just another bridge), I4 (headless-first
  bridge), and an explicit trust-posture boundary (I6). Largest, cloud-heavy
  effort. **Not currently in play.**
- **Invariants:** I6 (two trust postures kept apart), I2.

## Stage G — Master agent / orchestrator

- **Outcome:** an agent that navigates across sessions, dispatches and manages
  tasks, and holds the big picture — most likely a **session + Sesori-authored
  plugin/MCP** that drives the *same* session-control surface a human uses (shape
  not locked).
- **Depends on:** B (multi-session control/visibility), E (acting on outcomes),
  and I5. Most speculative; furthest out.
- **Invariants:** I5.

## Deferred / non-goals (mirror of `VISION.md`)

- Cross-plugin live session migration — dropped.
- Cost / usage metering — out for now.
- Permission-policy framework up front — trivial late add at the bridge seam.
- Teams / multi-user implementation — later (I7 keeps the door open).
- Offline / local-first client caching — intentionally not pursued.

## Notes on ordering

- **B (multi-plugin)** implemented its production path in parallel with A and
  passed all fixed-host release gates.
- **B2 (transient lifecycle)** is now unblocked after bridge-app-onboarding W02.
  Session PR-monitoring work may continue independently, but each B2 PR assesses
  drift in shared orchestrator/session/client paths before implementation.
- **B3 (phone setup)** follows B2 and is intentionally not part of the current
  lifecycle plan.
- **C (multi-bridge)** can follow or overlap B; the two are independent.
- **F** should not start before **C** is real (it depends on the bridge being
  "one of many" and fully headless).
- The desktop workstream remains paused for human reassessment after parallel
  plugins; this roadmap does not choose its next desktop PR or phase.
- Nothing here is approved to build ahead of need — each stage earns its design
  at `aristotle-plan-review` time, against the then-current code.
