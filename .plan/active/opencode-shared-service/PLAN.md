# Share OpenCode 2's Background Server

## Status

- **Plan slug:** `opencode-shared-service`
- **Status:** Active; Step 1 (this plan) in review.
- **Plan date:** 2026-10-08
- **Implementation base:** `main` at `2ad69c9545`
- **Scope:** OpenCode 2 only. OpenCode 1 has no background service, so it needs no work. No other harness has a
  comparable shared server, so `docs/HARNESS_CAPABILITIES.md` records this as OpenCode-specific.
- **Architecture review (2026-10-08):** the first pass rejected four points, all applied as written:
  - the endpoint value is renamed from a `Service` suffix to `OpenCodeSharedServerEndpoint`;
  - discovery is split into a Layer 1 registration Api and a Layer 2 repository, following the catalog-reader
    precedent, and the v2 minimum becomes a shared public constant;
  - the three-way `start()` routing is spelled out: v2 protocol and `mode: shared` for the shared branch;
  - stale owned-runtime cleanup runs before the shared attach.

  Per the review rules, the fixes are not re-reviewed.
- **Related work:** #1920 (merged) caps OpenCode sockets. #1922 (open) narrows the v2 cold start to
  `/api/debug/location` folders and touches the descriptor test file and `plugin-setup-and-lifecycle.md` in other
  hunks. Phase 1 changes only the descriptor's server selection, so it does not conflict in behavior. Whichever PR
  merges second merges `main` in.

## Goal

OpenCode 2's TUI and desktop app share one background server (`opencode serve --service`). Today the bridge always
spawns a private `opencode serve` on the same database. Two servers on one database collide: turns run twice, Stop
does not reach the other process, and events, permissions and forms stay in the process that created them. When
the user already runs OpenCode's shared service, the bridge should use it instead of starting a second server.

## User Decisions (2026-10-08, final)

Recorded as given. Do not re-litigate them in later steps or PRs.

- **S1:** phase 1 attaches to OpenCode 2's shared background service when it is running, healthy and compatible.
  Otherwise the bridge spawns its own server as today. Rough later phases:
  - Phase 2: when no service runs, the bridge starts `opencode serve --service` itself, never replacing an existing
    one, and re-discovers or re-attaches after a drop instead of falling back to a private server.
  - Phase 3 (small): surface a Stop that returned `interrupted:false`.
- **S2:** on by default, with a bridge flag to turn sharing off.
- **S3 (revised the same day, final):** mirror OpenCode's own client behaviour. The bridge attaches to whatever URL
  `service.json` lists, using its password, with no loopback or tunnel check and no refusal path. The user's words,
  when asked whether this meant copying OpenCode's client: "yes this is what I meant". This matches OpenCode's own
  client, which connects to the registered URL without a localhost check (`service-probe.ts:93`). The service and its
  URL are the user's own OpenCode configuration. Sesori's relay E2E path is unaffected: the password is sent only to
  that URL in the Basic-auth header, never over the relay and never into logs or diagnostics.
- **S4 (phase 2):** when the bridge starts the service, use the user's installed `opencode` CLI if it meets our
  minimum version, otherwise our bundled runtime.

## Evidence

From OpenCode v2.0.25 source and isolated two-server experiments.

- **Who uses the service:** by default the TUI and desktop call `Service.ensure`
  (`cli/src/services/server-connection.ts:41-51`). It spawns `opencode serve --service`
  (`client/src/effect/service.ts:61`).
- **Discovery contract:** a 0600 file `<XDG_STATE_HOME, or <home>/.local/state>/opencode/service.json` holds
  `{id?, version?, url, pid, password?}` (`service.ts` `Info` schema; path from `service-probe.ts` `fallback()` and
  `util/src/global-roots.ts`). An empty `XDG_STATE_HOME` falls back to the home path, and `<home>` is
  `os.homedir()` (`HOME`, or `USERPROFILE` on Windows). The `latest`, `dev`, `beta` and `next` channels share the
  name `service.json`; other channels use `service-<channel>.json`. The default port is 49374. Auth is Basic
  `opencode:<password>`, and the password persists across service restarts in the CLI's service config.
- **Readiness:** OpenCode's own probe (`service-probe.ts` `probeResult`) treats a service as usable when
  `GET /api/info` answers `200` with a JSON `{version, pid}` whose `pid` equals the registration's `pid`. A `503`
  means booting, a `500` means failed, and a `404` means an incompatible protocol.
- **Registration URL:** `http://<hostname>:<port>` with an IPv6 host bracketed (`server-process.ts` `serviceURL`).
  The hostname defaults to `127.0.0.1` and can be changed with `opencode service set hostname`.
- **Opt-out on OpenCode's side:** `opencode service set disabled true` stops the service and removes its file.
- **Collisions with today's separate servers on one database:**
  1. On boot the service resumes in-flight turns that the bridge's server owns, so turns run twice
     (`core/src/session/execution/restart.ts`). Verified.
  2. Stop does not cross processes. Verified.
  3. SSE events, permissions and forms are per process. Verified.
  4. Concurrent prompts race. Inferred.
  5. Version skew: bundled 2.0.24 versus CLI 2.0.25, with a recent database migration.
- **Existing seam:** `--opencode-no-auto-start --opencode-port N` already attaches to an existing server
  (`open_code_plugin_descriptor.dart` `start()`). It never kills the server, arms no restart monitor and probes only
  at startup. `ManagedRuntimeBridgePlugin(interruptOwnedOnly: true)` skips active-work interruption for a server the
  bridge does not own, so idle suspension, disable and bridge shutdown never stop the user's TUI turns.

## Phase 1 Design

### Behavior

On every OpenCode plugin start in managed mode (no `--opencode-no-auto-start`), unless sharing is off:

1. Resolve the registration file from `host.environment`: a non-blank `XDG_STATE_HOME`, else
   `resolveUserHomeDirectory(environment:)` + `.local/state`, then `opencode/service.json`. With neither value,
   there is no file.
2. A missing file means no service: spawn our own server as today, with a debug log line.
3. Decode the file. Require `url` and a positive `pid`; `password` is optional. Parse `url` with `Uri`; require the
   `http` scheme, a host, an explicit port and no path beyond `/`. A wildcard host goes through the existing
   `resolveOpenCodeConnectHost` (`0.0.0.0` → `127.0.0.1`, `::` → `::1`). There is no loopback or tunnel check (S3).
4. Probe `GET /api/info` with the registration's password, using the existing bounded probe helper (5 s timeout,
   64 KiB cap). The service is usable only when the response is `200` JSON whose `pid` equals the registration's
   `pid` and whose `version` parses as at least 2.0.11 (the existing v2 minimum).
5. Usable: attach. The plugin reaches the server at the registered host and port with the registered password, and
   selects the v2 adapter from the probed version. It never owns, kills or restarts the service. Diagnostics report
   `mode: shared` and the endpoint URL, never the password. One info line logs the URL, pid and version.
6. Unusable (corrupt file, bad URL, unreachable, booting, failed, pid mismatch, below 2.0.11): one warning line with
   the reason, then spawn our own server as today.

The probe happens before the existing attach path. If the service disappears between the probe and the attach health
check, the existing attach fail-soft applies: the plugin starts degraded and its background cold start and SSE keep
retrying the same URL. A service restarted by OpenCode's TUI comes back on the same configured port and password.

### When sharing applies

- **On** by default in managed mode.
- **Off** with the new flag `--opencode-no-shared-service` (`PluginFlagOption`, name `no-shared-service`,
  default `false`, not negatable, matching `--opencode-no-password`).
- **Off** in attach mode (`--opencode-no-auto-start`): the user already named the server.
- **Off** with an explicit `--opencode-bin`. An explicit binary may belong to another OpenCode channel, whose service
  file has a different name. The catalog reader already distrusts its channel for the same reason, and the user asked
  the bridge to run that binary.
- `--opencode-port`, `--opencode-host`, `--opencode-password` and `--opencode-no-password` shape only the fallback
  private server. They do not turn sharing off.

Residency, activation, setup inspection, runtime provisioning, management capabilities and catalog reads stay
config-derived and unchanged. Idle suspension disposes the API without touching the service. The next on-demand
start runs discovery again, so a service started after an earlier private fallback is picked up at the next plugin
start.

### Ownership and files

All code stays inside `sesori_plugin_opencode` (backend quirk, plugin-owned).

- `lib/src/models/open_code_service_registration.dart` (new): Freezed DTO for `service.json`
  (`url`, `pid`, `password?`), checked JSON decoding like `OpenCodeProbeResponse`. Generated files regenerated.
- `lib/src/models/open_code_probe_response.dart`: gains an optional `pid`. Generated files regenerated.
The layering mirrors the catalog reader (`api/open_code_catalog_database_api.dart` →
`repositories/open_code_catalog_repository.dart`).

- `lib/src/api/open_code_service_registration_api.dart` (new, Layer 1, `OpenCodeServiceRegistrationApi`). It reads
  the file at a given path and returns the decoded `OpenCodeServiceRegistration`, or `null` when the file is
  missing. Read and decode failures throw a typed `OpenCodeServiceRegistrationException` that keeps the original as
  `cause`. It makes no decisions.
- `lib/src/runtime/open_code_shared_server_endpoint.dart` (new): the immutable value `OpenCodeSharedServerEndpoint`
  (`host`, `port`, `password?`, `version` as `SemanticRuntimeVersion`). It has no mutable state.
- `lib/src/repositories/open_code_shared_server_repository.dart` (new, Layer 2, `OpenCodeSharedServerRepository`).
  It:
  - resolves the `XDG_STATE_HOME`-or-home path;
  - calls the Api;
  - validates the URL and applies `resolveOpenCodeConnectHost`;
  - probes `/api/info`;
  - applies the `pid` and minimum-version rules.

  It returns `Future<OpenCodeSharedServerEndpoint?>` and writes the debug line (no file) or the warning (unusable)
  itself.
- `lib/src/runtime/open_code_runtime_policy.dart`:
  - a public top-level `probeOpenCodeInfo(...)` wraps the existing private `_getOpenCodeJson`, so there is still one
    bounded probe helper;
  - the 2.0.11 minimum moves here from the descriptor as the public `openCodeMinimumV2Version`, used by both the
    repository and the descriptor's existing below-minimum check.
- `lib/src/runtime/open_code_plugin_descriptor.dart`: the new option and the `start()` routing below. `start()`
  builds the repository from `_probeClientFactory`, so no new constructor seam is needed.

### `start()` routing

The discovered `OpenCodeSharedServerEndpoint?` is the shared-branch discriminator. It is one non-null local value,
with no new booleans. Three branches:

- **Attached** (`--opencode-no-auto-start`): unchanged. Host, port and password come from config. Protocol is
  `handle == null ? v1 : probe`.
- **Shared** (endpoint found):
  - Host, port and password come from the endpoint, never from config.
  - First call `service.cleanupStaleOwnedRuntimes(terminatedBridgeIdentities: host.bridge.terminatedBridgeIdentities)`,
    so an orphaned private server left by a replaced or crashed bridge is reclaimed exactly as the managed path does
    today. Then call `service.attach(...)`.
  - The protocol is always `OpenCodeProtocolV2(version: endpoint.version)`, whether or not the attach health check
    succeeds. When it fails, the plugin starts degraded on the v2 adapter through the existing fail-soft.
- **Managed** (no endpoint): unchanged spawn, including the degraded path when no binary is available.

Diagnostics `mode` comes from the selected branch (`attached`, `shared` or `managed`), not from `ownedRecord`.

### Tests that matter

A new `test/repositories/open_code_shared_server_repository_test.dart` covers discovery. A descriptor group in
`test/runtime/open_code_plugin_descriptor_test.dart` covers routing.

- A missing `service.json`, or no home or `XDG_STATE_HOME`, spawns our own server.
- A healthy compatible service attaches: no spawn, unowned, `mode: shared`, v2 adapter, the registered password in
  the auth header, and the password absent from diagnostics.
- An unhealthy service spawns our own server: unreachable, booting `503`, failed `500`, `404`, non-JSON, or pid
  mismatch.
- A service below 2.0.11 spawns our own server.
- Corrupt JSON, or a URL with a non-http scheme, a path or no port, spawns our own server.
- `--opencode-no-shared-service` and an explicit `--opencode-bin` never read the file. Attach mode is unchanged.
- `XDG_STATE_HOME` wins over the home path, and a blank value falls back to it.
- Shutdown of a shared plugin never signals the service or interrupts its active work.
- The shared attach health check fails after discovery: the plugin starts degraded on the v2 adapter with
  `mode: shared`.
- A stale owned record from a terminated bridge is reclaimed before the shared attach, and the shared service is
  never signalled.

No loopback or tunnel refusal test exists, because S3 removed that behavior.

### Live check (isolated)

Run a private `opencode serve --service` with a separate `HOME` and XDG directories on a free port. Attach a
source-run bridge on a free dev slot (`sesori-local-testing`, `ulimit -n 8192` first) whose environment points at
the same XDG state directory. Confirm the bridge log selects the shared service, events arrive, a prompt runs and
Stop interrupts it through the shared server. Then stop everything. Never touch the user's real OpenCode service,
their running bridge, or any other process.

## Steps

The series total grows when phases 2 and 3 are detailed. Their steps go before the documentation reconciliation
step, and every open title is updated then.

| Step | Title | Contents |
|---|---|---|
| 1 | `🌱 [opencode-shared-service] Plan sharing OpenCode 2's background server [step 1/4]` | This plan. |
| 2 | `🚧 [opencode-shared-service] Attach to OpenCode 2's shared background server [step 2/4]` | Phase 1 as designed above: discovery, flag, attach routing, tests, regression doc and `HARNESS_CAPABILITIES.md` updates, isolated live check. Estimated about 600 to 800 changed lines, half of them tests, plus a few hundred generated lines. |
| 3 | `🌱 [opencode-shared-service] Reconcile the regression docs [step 3/4]` | Reconcile `plugin-setup-and-lifecycle.md` and `HARNESS_CAPABILITIES.md` with everything shipped. |
| 4 | `🌱 [opencode-shared-service] Record verification and retire the plan [step 4/4]` | Run the recorded coverage and move the plan to `.plan/completed/`. |

Step 2's PR body states complexity `🚧` (start-path lifecycle and a local credential), no database change, and the
user-visible effect: with OpenCode's service running, phone and TUI see the same live turns, Stop and prompts.

### Later phases (rough)

- **Phase 2: the bridge starts and keeps the shared service.**
  - What: when no usable service is registered, run `opencode serve --service` with the user's CLI if it meets our
    minimum, else the bundled runtime (S4). Never replace an existing service. After a drop, re-discover and
    re-attach instead of falling back to a private server.
  - Why: phase 1 still spawns a private server when the bridge starts first. A TUI opened later then starts the
    service on the same database, which resumes the bridge server's turns twice (collision 1). Owning the service
    start removes the second server entirely.
- **Phase 3: surface a Stop that did not interrupt.**
  - What: when OpenCode answers Stop with `interrupted:false`, tell the user instead of silently succeeding.
  - Why: with two processes, or a turn owned elsewhere, Stop can be a no-op that the user cannot see.

## Regression Coverage

- **Affected documents:** `docs/regression/plugin-setup-and-lifecycle.md` (OpenCode lifecycle bullets, failure
  signals and coverage), and `docs/HARNESS_CAPABILITIES.md` (an OpenCode-specific shared-service note).
- **Highest level:** L2 Routine.
  - Automated descriptor and discovery fixtures cover the selection rules.
  - A live-plugin check covers a real OpenCode 2 service: attach, events, a prompt and Stop through the shared server.
- **Matrix:** OpenCode 2 on macOS (live). Linux and Windows path resolution is covered only by automated tests:
  the code is the same, with Windows reading `USERPROFILE`. Client end to end is not required, because no client
  code changes and the wire contract is unchanged.

## Complexity Budget

- **New persistent state:** none. The bridge reads OpenCode's file and never writes it.
- **New in-memory mutable state:** none. The additions are one immutable endpoint value, a stateless Api and
  repository built per start, one registration DTO and one flag.
- **Deliberately not added:** a file watcher, a re-discovery timer, a restart monitor for the shared service, a
  "waiting" retry loop, version-skew negotiation and a loopback or tunnel policy (S3). Phase 2 owns the start and
  re-attach machinery.

## Accepted Risks (phase 1)

- **The bridge starts first, the TUI starts the service later:** collision 1 (a duplicate resume) still happens for
  turns in flight on the bridge's private server. This is an ordinary flow, removed by phase 2. Phase 1 still
  removes every collision whenever the service is already running at plugin start.
- **The service is booting (`503`) at plugin start:** the bridge spawns a private server. This is rare (the TUI and
  the bridge must start within seconds of each other) and is removed by phase 2.
- **The service drops after attach and returns on another port:** the plugin stays degraded until its next start
  (manual restart or idle suspension then on-demand start). The same port and password, which is OpenCode's default
  behavior, recover through the existing SSE retry.
- **OpenCode Desktop without a CLI on PATH:** setup inspection still needs a PATH or managed runtime even when a
  shared service is running. This is unchanged from today; revisit it in phase 2.

## Cleanup Assessment

No obsolete code was found. `--opencode-no-auto-start` stays, because it attaches to a server the user names, not to
the discovered service.
