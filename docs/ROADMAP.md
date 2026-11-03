# Sesori — Implementation Roadmap

> A **dependency-ordered** suggestion for the order to build toward `VISION.md` —
> *not* a calendar and *not* a commitment (horizon is ≥ ~1 year, funding/team
> dependent). The *what / why* lives in `VISION.md`; the *how* (layer rules) in
> `AGENTS.md`; desktop distribution in `.plan/active/desktop-distribution/PLAN.md`.
>
> **Use it like this:** pick the earliest stage whose dependencies are met;
> stages can overlap. Every stage still goes through `architecture-plan-review`
> before code and `architecture-implementation-review` before a PR — this doc
> pre-approves no design. Ordering is by what *unblocks* what, biased to keep
> the `VISION.md`
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

## Stage A — Desktop app (multi-surface) — *macOS and Linux shipped; Windows pending*

- **Outcome:** a desktop app that supervises the headless bridge (tray +
  window) and renders the full client cockpit (shared adaptive UI split into
  `module_app_ui` + per-surface shells), distributed for all six native OS/CPU
  targets with updates.
- **Status:** macOS has been public since v1.9.1 and Linux since v1.10.1.
  `.plan/active/desktop-distribution/PLAN.md` owns the remaining Windows
  distribution (blocked on signing) and the platform ship gates.
- **Detail:** implementation in `.plan/completed/desktop-app/PLAN.md` (retired
  2026-11-02 with accepted coverage gaps); the desktop UX, UI polish, visual
  hierarchy, turn navigation, sign-in and auto-update work in their own
  `.plan/completed/` plans (`desktop-ux`, `desktop-ui-polish`,
  `visual-hierarchy`, `turn-navigation`, `desktop-sign-in`,
  `desktop-auto-update`).
- **Later consideration (recorded, not planned):** a loopback local data path
  for the desktop cockpit. The cockpit reuses the relay like the phone; a
  bridge-hosted loopback data transport (the `--debug-port` `DebugServer` is
  the working precedent) could remove the internet requirement against a
  same-machine bridge. The cockpit shipped (macOS v1.9.1, Linux v1.10.1);
  revisit when users report needing the desktop app offline, or relay latency
  hurts same-machine use (user decision 2026-11-02).
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

## Stage B2 — Setup-aware transient plugin lifecycle — *complete*

- **Outcome:** plugins report setup readiness, setup-ready plugins are selected
  automatically, enabled plugins wake on demand and stop after their idle
  policy, and each can be controlled from the headless API and the clients. See
  `.plan/completed/setup-aware-plugin-lifecycle/PLAN.md` and
  `docs/regression/plugin-setup-and-lifecycle.md`.
- **Invariants:** I1 (plugin boundary), I4 (headless-first), I9 (eligibility is
  not residency).

## Stage B3 — Phone-driven backend installation and login — *complete*

- **Outcome:** from the phone, a user can install a registered plugin's backend
  runtime and complete a plugin-owned login where the harness supports it. See
  `.plan/completed/phone-harness-install/`, `claude-code-login/` and
  `codex-mobile-login/`, and `docs/regression/plugin-runtime-installation.md`.
- **Invariants:** I1, I4, I6, I9.

## Stage C — Multi-bridge addressing — *complete*

- **Outcome:** a user can enumerate and choose among *their* bridges, and relay
  and auth route to a specific bridge. See `.plan/completed/multi-computer/`
  (retired with its live L4 cells accepted unexecuted) and
  `docs/regression/multi-computer.md`.
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

- Stages B, B2, B3 and C are complete. Stage A's remaining work is Windows
  distribution, blocked on signing.
- **D**, **E** and **G** build on the completed plugin and multi-session stages;
  **G** also needs **E**.
- **F** depends on **C**, which is complete, and on a fully headless bridge.
- Nothing here is approved to build ahead of need — each stage earns its design
  at `architecture-plan-review` time, against the then-current code.
