# Sesori — Product Vision & Direction

> **What this is.** The north star: where Sesori is going, so day-to-day
> architectural choices bias toward that destination instead of locally-cheap
> solutions that weld a door shut.
>
> **What this is not.** A build order (see `ROADMAP.md`), a feature spec, or a
> licence to build the future early.
>
> **How to use it.** When two designs both satisfy the layer rules in
> `AGENTS.md`, prefer the one that does not *foreclose* something below. That is
> this doc's only job: break ties and stop us welding doors shut. It never
> overrides YAGNI or the cohesion/ownership rules — **do not add abstraction,
> generalization, or infrastructure for anything here until there is a concrete,
> present need.** Direction guides *reversibility*, not premature construction.
>
> Living document. Correct it the moment intent changes.

## The destination in one paragraph

Sesori is becoming an **ambient dev cockpit**: monitor and drive AI coding work
from any device, across multiple assistant backends, with a powerful local
**bridge** as the core - one that can *also* be run for you as a managed cloud
service. The bridge now runs ordered enabled plugins concurrently, and the
client can choose a plugin plus its scoped agent/model resources when creating a
session. The destination is many surfaces (phone, desktop, later web), many
bridges (your laptop, your desktop, managed VMs), more plugins (including our own
harness), opt-in autonomy over CI/review, and eventually a master agent that
coordinates work across sessions.

## Where this is going (the pillars)

### 1. Multi-surface clients, online-first, multi-bridge

The client is the same brain on every surface. `module_core` is the shared,
Flutter-free logic; each surface (mobile `client/app`, `client/desktop`, future
web) is a thin shell. The client is **online-first by design** — it caches almost
nothing locally, precisely so it can switch between bridges cheaply. A single
bridge already serves **multiple clients** concurrently; the new axis is
**multi-bridge**: the client (with the relay + auth server) lets a user choose
*which* bridge to talk to. The seam already exists
(`bridge_api` / `bridge_repository` / `registered_bridges_store` in
`module_core`).

- *Door to keep open:* per-bridge addressing/identity is first-class; never
  collapse it into "the user's one bridge", and don't bake phone-only
  assumptions into shared logic.

### 2. The bridge is the product's core

The bridge is, and will remain, the heavy part. It runs as a **headless daemon**
(terminal / VM, unchanged) *and*, on desktop, under a **Flutter supervisor app**
(tray/menu-bar popup + a main window that is the client UI with desktop-specific
changes) — the Tailscale model (`Tailscale.app` supervises `tailscaled`; the same
daemon also runs headless on a server). It runs **multiple plugins in parallel**
and owns the durable project/session catalog used for normal list reads.

- *Door to keep open:* the bridge must always be runnable headless; the desktop
  GUI supervises the *same* daemon and is never the only way to run it (this is
  what makes managed VMs possible). The active plan is `docs/desktop/PLAN.md`.

### 3. The plugin interface is a platform contract

Backends are truly pluggable. OpenCode, Codex, and Cursor descriptors can run
together; **our own harness will be just another plugin** behind
`BridgePluginApi`, with no privileged backdoor. Current capability differences
use the plugin interface's declared type shape, and composer data remains scoped
to the selected or stored plugin. Add an optional discoverable capability only
when a concrete backend cannot implement an existing operation; capability
differences are declared, not special-cased into the bridge or client.

- *Door to keep open:* nothing assistant-specific (OpenCode / Codex / own
  harness) leaks past the plugin boundary into `shared/`, the relay protocol, or
  the client.

### 4. Autonomy & integrations

Sesori moves up the workflow. **CI / PR review** becomes first-class — surface
PRs, comments, and checks (forge-neutral) and, with **opt-in auto-handle**, the
bridge posts a message into the relevant session to address a failed check or a
new review *automatically*, rather than only notifying. **Notifications are
already a core delivery channel.** Later, a **master agent** coordinates across
sessions — most likely itself a session plus a Sesori-authored plugin/MCP that
teaches it to list/inspect sessions and dispatch tasks through the *same*
session-control surface a human uses (exact shape not locked).

- *Door to keep open:* whatever a human uses to create/drive/inspect a session is
  the same API automation uses; autonomy (auto-handle, future auto-approve) lives
  at the **bridge interception layer**, opt-in and observable.

### 5. Managed service tier (future, paid)

Sesori will offer running sessions on **Sesori-controlled VMs**: pick a repo,
start working, no need to keep your own machine on. The value is convenience and
always-on; it is a **paid** tier and **not currently in play**.

- **Trust posture (explicit).** On a managed VM the bridge runs on Sesori
  infrastructure, so Sesori *can* see that session's data — the "zero-knowledge
  relay / E2E phone↔bridge" guarantee of **local mode does not hold** for managed
  sessions. This is an accepted, deliberate trade for convenience. Keep local
  mode (zero-knowledge) and managed mode (trusted VM) clearly separated in code,
  and surface the difference honestly in the UI; managed mode must never silently
  weaken the local guarantee. Architecturally a managed VM is "just another
  bridge" (see pillar 1).

## Directional invariants (the doors we must not weld shut)

1. **Plugin boundary is sacred** — no backend specifics past `BridgePluginApi`;
   our own harness is *just a plugin*; differing abilities are declared by the
   plugin contract rather than inferred by shared code or clients.
2. **The bridge is one of many** — per-bridge addressing across client / relay /
   auth (multi-client per bridge already works; multi-bridge is the new axis).
3. **Shared brain, thin shells** — `module_core` stays Flutter-free and
   surface-agnostic; the client is online-first with minimal local cache.
4. **Headless-first bridge** — GUI supervision is additive and gated; the
   standalone / VM path stays first-class.
5. **One session-control surface** — a human and a future master agent drive
   sessions through the same API; no automation backdoor.
6. **Two trust postures, kept apart** — local = zero-knowledge; managed = trusted
   VM; never let managed weaken local.
7. **Teams when concrete** — do not persist placeholder ownership while the
   product has one local owner. Add it with an explicit migration when a real
   multi-owner requirement exists.
8. **Autonomy at the bridge seam** — auto-handle / future auto-approve are
   opt-in, observable, and intercepted at the bridge, not scattered into clients
   or plugins.

## Explicitly NOT building (now, maybe ever)

Listed so nobody designs for them prematurely:

- **Cross-plugin live session migration** (moving a running session A→B).
  Dropped — an edge-case nice-to-have not worth the system complexity.
  *Corollary:* do **not** over-invest in a migration-grade canonical transcript;
  the bridge-owned system-of-record stays only as rich as today's needs require.
- **Cost / usage metering.** Out of scope for now.
- **A permission-policy framework up front.** Auto-approving known permissions is
  trivial to add later by intercepting at the bridge before the prompt reaches
  the client — so it is *not* a design constraint now.
- **Teams / multi-user implementation.** Later; only invariant 7 applies today.
- **Offline / local-first client caching.** Intentionally not pursued; the client
  stays online-first.

## Horizon

Realistically **≥ ~1 year** of work at a fast pace, gated by team size and
funding — so this is sequenced by **dependency, not calendar** (see
`ROADMAP.md`). The managed-service tier is *not currently in play*. Treat every
line here as intent, not commitment.

## Related docs

- `ROADMAP.md` — dependency-ordered implementation suggestion.
- `docs/desktop/PLAN.md` — the active desktop-app workstream (pillar 2).
- `AGENTS.md` — the *how* (layer architecture). This doc is the *where*.
