# Bridge Architecture

## Overview

The bridge app is a pure Dart CLI that connects a local AI assistant to mobile devices over an encrypted WebSocket relay. It authenticates via OAuth PKCE, manages relay connections, and routes E2E-encrypted traffic between phones and the local server.

## Layer Architecture

All code follows a strict layered architecture. Dependencies flow upward only — a lower layer must NEVER know about a higher layer.

```
Layer 0 — Foundation (transport primitives & base abstractions)
  └─ HOW we communicate, not WHAT. No business logic, no decisions.
  └─ Location: app/lib/src/foundation/

         ▲ consumed by

Layer 1 — API (data sources)
  └─ Dumb classes that execute operations. No decision-making logic.
  └─ All external data enters/exits through this layer.
  └─ Sub-groups: Database (Drift), GhCliApi, GitRemoteApi, SesoriServerApi
  └─ Location: app/lib/src/api/

         ▲ consumed by

Layer 2 — Repositories (data aggregation + mapping)
  └─ Combines data from one or more Layer 1 API sources.
  └─ Maps API/DB DTOs to internal models — ALL mapping happens here.
  └─ MANDATORY even when only one data source exists.
  └─ Location: app/lib/src/repositories/

         ▲ consumed by

Layer 3 — Services (business logic)
  └─ Decision-making, coordination, orchestration.
  └─ MUST use Repositories (Layer 2). MUST NOT call APIs (Layer 1) directly.
  └─ Location: app/lib/src/services/

         ▲ consumed by

Layer 4 — Request Handling, Trigger Listening, & Event Delivery
  └─ Routing: RequestRouter + handlers (use Repositories/Services only)
  └─ Listeners: one reactive/scheduled trigger lifecycle per class; delegate to
     Repositories/Services and expose typed output for Orchestrator delivery
  └─ SSE: SseService + BridgeEventMapper
  └─ Location: app/lib/src/routing/, app/lib/src/listeners/, app/lib/src/sse/

         ▲ all composed by

Layer 5 — Orchestration
  └─ Orchestrator — the ONLY class that wires layers together
  └─ Location: app/lib/src/orchestrator.dart
```

### Core Rules

- **Repository layer is MANDATORY** — even with one data source, the repository delegates.
- **Services MUST use Repositories** — never call APIs or DAOs directly.
- **Handlers MUST use Repositories/Services** — never call APIs, DAOs, or DTOs directly.
- **All mapping lives in repositories/mappers** — never in routing, services, or handlers.
- **Directory structure mirrors layers** — violations are visible in import paths.

## Subsystems

Six self-contained subsystems live outside the numbered layer hierarchy:

- **`runtime/`** — Bridge runtime lifecycle: CLI dispatch, startup, shutdown
  ordering, and the plugin generation/lease lifecycle. `PluginRuntime` is this
  subsystem's seam; repositories call it to reach a plugin, which is why it
  stays here rather than in `api/` — it owns lifecycle decisions, not data
  access, and moving it into Layer 1 would make Layer 1 depend upward on
  composition.
- **`auth/`** — Token lifecycle, login flow. No deps on core layers.
- **`push/`** — Push notification delivery. No deps on core layers.
- **`server/`** — Bridge instance and host services: single-live-bridge
  enforcement, startup mutex, plugin host abstractions.
- **`updater/`** — In-place update: download, verify, stage, apply.
- **`control/`** — Desktop control channel (`ControlChannelServer`,
  `ControlMessageDispatcher`, notifiers).

`models/` and `persistence/` hold bridge-wide config and diagnostics rather than
belonging to one layer or subsystem.

## Directory Structure

One tree, one layer per directory. Everything under `app/lib/src/` is either a
numbered layer or a self-contained subsystem — there is no second parallel tree.

```
app/lib/src/
├── foundation/              # Layer 0 — transport/process primitives
│   ├── relay_client.dart
│   ├── key_exchange.dart
│   ├── process_runner.dart
│   └── filesystem_permission_validator.dart
│
├── api/                     # Layer 1 — data sources, one class per tool
│   ├── database/            # Drift: tables, DAOs, migrations
│   ├── models/              # API-layer DTOs
│   ├── gh_cli_api.dart
│   ├── git_cli_api.dart
│   └── sesori_server_api.dart
│
├── repositories/            # Layer 2 — aggregation + mapping
│   ├── mappers/             # ALL mapping lives here
│   ├── models/
│   └── trackers/
│
├── services/                # Layer 3 — business logic
│
├── routing/                 # Layer 4 — request handlers
├── listeners/               # Layer 4 — reactive/scheduled triggers
├── sse/                     # Layer 4 — SSE delivery
│   ├── sse_manager.dart
│   └── bridge_event_mapper.dart
│
├── orchestrator.dart        # Layer 5 — the only cross-layer composition owner
├── debug_server.dart
│
├── runtime/                 # Subsystem — CLI entry, startup/shutdown ordering,
│                            #   and PluginRuntime (plugin generation lifecycle)
├── auth/                    # Subsystem — token lifecycle, login flow
├── push/                    # Subsystem — push notification delivery
├── server/                  # Subsystem — bridge instance/host services
├── updater/                 # Subsystem — in-place update
├── control/                 # Subsystem — desktop control channel
├── models/                  # Bridge-wide config models
└── persistence/             # Bridge-wide diagnostics persistence
```

`runtime/` is a subsystem, not a numbered layer: it owns the CLI entry point,
startup sequencing, shutdown ordering, and the plugin generation lifecycle.
Repositories reach a plugin through `PluginRuntime`, this subsystem's seam.

## Key Patterns

- **Request routing**: intercept-first handler chain. First match wins, proxy is fallback.
- **SSE pipeline**: Plugin → Orchestrator → SseService → per-phone encrypted delivery.
- **E2E encryption**: All phone↔bridge data encrypted with XChaCha20-Poly1305. No bypassing.
- **Plugin system**: `BridgePlugin` abstract contract. New backends implement the interface.
