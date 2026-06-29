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
> invariants (numbered below as I1–I8) intact.

## Already in flight / landed

- Second backend shipped: **Codex** plugin alongside OpenCode — proves
  multi-backend.
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

## Stage B — Multi-plugin parallelism + per-session model control

- **Outcome:** run multiple plugins concurrently; per-session model/agent
  selection in the client; a **capability descriptor** on `BridgePluginApi` so
  the client renders only what a given plugin supports.
- **Priority:** the next major capability after Stage A — and may run **in
  parallel with** it; this is ahead of multi-bridge.
- **Depends on:** additive plugin-interface evolution; independent of Stage A.
- **Unlocks:** own harness (D), master agent (G), a richer client.
- **Explicitly excluded:** moving a *live* session between plugins (VISION
  non-goal).
- **Invariants:** I1 (plugin boundary; capabilities declared, not special-cased).

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
  `BridgePluginApi`**, using the optional-capability mechanism from Stage B; no
  privileged path.
- **Depends on:** B (capability model).
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

- **B (multi-plugin) is the priority after A** and can run in parallel with A.
- **C (multi-bridge)** can follow or overlap B; the two are independent.
- **F** should not start before **C** is real (it depends on the bridge being
  "one of many" and fully headless).
- Nothing here is approved to build ahead of need — each stage earns its design
  at `aristotle-plan-review` time, against the then-current code.
