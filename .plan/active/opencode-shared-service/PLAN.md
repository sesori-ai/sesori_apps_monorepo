# Share OpenCode 2's Background Server

## Status

- **Plan slug:** `opencode-shared-service`
- **Status:** Active. Phase 1 shipped: Step 1 merged in #1923, Step 2 in #1924, Step 3 in #1925. Step 4 (phase-1
  verification and the phase-2 plan) merged in #1926. Step 5 (phase 2 start path) merged in #1927. Step 6 (re-attach after
  a drop) merged in #1933. Step 7 (docs reconcile) is in review. Phase 3 is dropped; see "Later phase".
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
- **Architecture review of phase 2 (2026-10-08):** the first pass rejected five points, all applied as written:
  - every degraded path in shared mode (attach failure and cold start, not only SSE) reports failure in step 6;
  - the acquisition workflow moves to a Layer 3 `OpenCodeSharedServerService`, leaving the repository thin;
  - the command Api returns typed, boundary-parsed results;
  - the version-probe owner and the step-5 constructors and composition are named;
  - the step-6 enum, its payload and its consumers are named.

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
  - Phase 3 (small): surface a Stop that returned `interrupted:false`. Dropped in step 7; see "Later phase".
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

## Phase 1 Verification

- **Automated (#1924):**
  - the full `sesori_plugin_opencode` suite (629 tests), including 6 descriptor routing tests and 10 discovery
    tests;
  - `dart analyze --fatal-infos` clean;
  - the app tests that cover OpenCode options;
  - CI 19/19 green on the merged head.
- **Isolated live check (2026-10-08, OpenCode 2.0.25, macOS): passed.**
  - Setup: `opencode serve --service --port 47901` ran with its own `HOME` and XDG directories, and a
    source-run bridge ran on a free dev slot with `XDG_STATE_HOME` pointed at the same state directory.
  - The bridge logged `using the shared OpenCode 2.0.25 service at http://127.0.0.1:47901`, spawned no private
    server, and held one SSE connection to the service.
  - Session create and two prompts ran through the bridge debug routes. The free model streamed `pong` back as a
    `message.part.delta`, then a final text part.
  - Stop moved a busy (retrying) turn to `idle`, twice.
  - On bridge shutdown the log showed `server is not bridge-owned; skipping active-work interruption`, and the
    service still answered `/api/info` afterwards.
  - Everything was then stopped. The user's own OpenCode service and bridge were not touched.
- **Observed, unrelated to sharing:** the v2 SSE parser logs "dropping malformed or unsupported SSE event" for
  event types it does not model, including `server.connected`, which has no `created` field. This is noise only;
  nothing failed.
- **Pending (the user, after merge):** the user's real-setup check. With their own `opencode serve --service`
  running, they run a bridge built from `main` and confirm the log line, one shared turn visible in both the TUI
  and the phone, and Stop from the phone. Record the result here when it arrives. It does not block phase 2.

## Phase 2 Design: the bridge starts the shared service

### Why

Phase 1 still spawns a private server whenever no usable service is registered when the plugin starts. If a TUI
then starts the service on the same database, the service resumes the bridge server's in-flight turns, so they run
twice (collision 1). A booting service (`503`) also leads to a private spawn. And a service that drops after attach
leaves the plugin degraded until its next start. Phase 2 removes the private server from the sharing path: the
bridge asks OpenCode to start its own service, then attaches to it.

### Evidence (OpenCode v2.0.25)

- `opencode service start` (`cli/src/commands/handlers/service/start.ts`) calls `Service.ensure` without a version
  requirement (`ServiceConfig.options()` leaves `version` undefined). `ensure`
  (`client/src/effect/service.ts:49`):
  - reuses a ready, compatible service;
  - waits while one is booting;
  - otherwise spawns a detached, unref'd `<self> serve --service` contender
    (`client/src/service-contender.ts`: `detached: true`, stdio ignored);
  - then prints the service URL.

  It never replaces a running service of another version. It does stop a registered service that timed out three
  probes in a row, which is OpenCode's own recovery, the same thing its TUI does.
- `ensure` gives up after 120 s (`client/src/service-timing.ts`).
- `opencode service start` does not read the user's `disabled` setting; only the TUI does
  (`cli/src/services/server-connection.ts:41`). `opencode service get disabled` prints `true` or `false`, which was
  verified on 2.0.25 in an isolated environment.
- The TUI's default `mismatch` is `ignore` (`server-connection.ts`), so a TUI of another version reuses a service the
  bridge started instead of replacing it.
- In the bridge:
  - `host.provisionedRuntimePath` is already the S4 choice: the PATH install when it meets the policy, otherwise the
    managed (bundled) runtime.
  - `HostProcessCommandExecutor` already runs bounded commands with capped output for setup probes.
  - `PluginRuntime._ensureStarted` starts a fresh generation on the next request after a generation fails.

### Behavior

In managed mode with sharing on (phase-1 rules unchanged), when discovery finds no usable service:

1. **Pick the binary (S4).** Use `host.provisionedRuntimePath`; an explicit `--opencode-bin` still turns sharing off.
   Read its version with the existing bounded `--version` probe.
   - Below 2.0.11 (OpenCode 1 has no service), or no binary: spawn a private server as today. Never start a v2
     service from the bundled runtime over a user whose PATH install is v1. The v2 first launch migrates the
     database one way, so the bridge's v1 support stays as it is.
2. **Respect OpenCode's opt-out.** Run `<binary> service get disabled`, bounded. If it prints `true`, spawn a private
   server as today and log one info line. Any failure of this probe also falls back to a private server, with a
   warning.
3. **Start the service.** Run `<binary> service start`, waiting as long as OpenCode's own 120 s start wait (a 130 s
   backstop for a hung CLI) and honouring `host.startAborted`; on abort
   or timeout, kill the CLI process. The environment is the parent environment, as the setup probes use. No Sesori
   password or port is passed: the service uses OpenCode's own service configuration.
4. **Attach.** Run phase-1 discovery again. When it returns an endpoint, take the phase-1 shared branch unchanged:
   cleanup of stale owned runtimes, `attach`, the v2 adapter, and `mode: shared`. Log one info line saying the bridge
   started the service.
5. **Fallback.** If the start fails, times out, or is still not discoverable, log one warning and spawn a private
   server as today.

**After a drop (step 6).** In shared mode, every path that would leave the plugin degraded reports `PluginFailed`
instead, after the existing 5-second debounce, unless `markConnected` arrives first. That covers three paths:

- a lasting SSE disconnect (`markDisconnected`);
- a failed attach health check at start (`markDegradedNow` at descriptor line 895);
- a failed or over-budget cold start (`markDegradedNow` in `ManagedRuntimeColdStartService`).

The runtime retires that generation, and the next request starts a fresh one. That start runs discovery and, if
needed, `service start` again, so the bridge re-attaches to the service wherever it now listens. Attach mode and
managed mode keep today's degrade-and-retry, because the plugin cannot re-discover their servers. The phase-1 test
"a shared attach that fails after discovery starts degraded with `mode: shared`" changes to expect `PluginFailed`
after the debounce.

### Lifecycle consequence (user-decided 2026-10-08)

**P1:** a service started by the bridge is OpenCode's own detached process. It outlives the bridge exactly as one
started by the TUI does, keeps running after the bridge stops, and is stopped with `opencode service stop`. This is
the behaviour S1 asked for ("the bridge starts `opencode serve --service` itself"). However, a headless bridge now
leaves a background OpenCode process behind where today its private server dies with it.

The opt-outs are `--opencode-no-shared-service` and OpenCode's own `opencode service set disabled true`. Under a
systemd unit with the default `KillMode=control-group`, stopping the unit still stops the detached service.

**Decision (user, 2026-10-08):** leave the service running when the bridge stops, as the TUI does. The bridge never
owns, stops or supervises the shared service.

### Ownership and files

All code stays inside `sesori_plugin_opencode`, except one runtime-package parameter in step 6.

- **Step 5:**
  - **Layer 1:** `lib/src/api/open_code_service_command_api.dart` (new), class `OpenCodeServiceCommandApi`.
    - Constructor: `({required HostProcessCommandExecutor executor})`.
    - It owns every OpenCode CLI command phase 2 needs, each with a bounded timeout, capped output and
      `startAborted` through the executor's abortable run. Each method parses its own output at the boundary:
      - `Future<SemanticRuntimeVersion> readVersion({binary, environment, startAborted})` runs `--version`, with the
        same parsing as the setup probe.
      - `Future<bool> readDisabled({binary, environment, startAborted})` runs `service get disabled`. It accepts
        exactly `true` or `false`.
      - `Future<void> startService({binary, environment, startAborted})` runs `service start`, with a 130 s backstop just past OpenCode's own 120 s wait.
    - A non-zero exit, a timeout or unparseable output throws `OpenCodeServiceCommandException(message, cause)`.
      An abort throws `PluginStartAbortedException`. The Api makes no decisions.
  - **Layer 2:** `OpenCodeSharedServerRepository` gains a required `commandApi` constructor parameter and three thin
    delegating methods: `readBinaryVersion`, `isServiceDisabled` and `startService`. `discover` is unchanged.
  - **Layer 3:** `lib/src/services/open_code_shared_server_service.dart` (new), class
    `OpenCodeSharedServerService`.
    - Constructor: `({required OpenCodeSharedServerRepository repository})`.
    - It has one method:
      `Future<OpenCodeSharedServerEndpoint?> acquire({required String? binary, required Map<String, String> environment, required StartAbortSignal startAborted})`.
    - `acquire` returns `discover()` when that finds a service. Otherwise it applies the version, disabled and start
      rules above, calls `discover()` again, and logs each fallback reason once. An abort is rethrown.
    - It owns the shared-server acquisition policy.
  - **Composition:** `start()` in the descriptor builds the executor from `host.processes`, then the Api, then the
    repository (with `_probeClientFactory`), then the service. There is no new descriptor constructor seam. The
    descriptor calls `acquire(binary: host.provisionedRuntimePath, ...)` instead of `discover(...)` when sharing
    applies. The routing is otherwise unchanged.
- **Step 6:**
  - `enum ManagedRuntimeDisconnectOutcome() { degrade, fail }` goes in
    `sesori_plugin_runtime/lib/src/managed_runtime_status_reporter.dart` and is exported from
    `sesori_plugin_runtime`.
  - `ManagedRuntimeStatusReporter` gains the required constructor parameter
    `ManagedRuntimeDisconnectOutcome disconnectOutcome`. Under `fail`, both `markDisconnected` and `markDegradedNow`
    set `PluginFailed(reason: "the server stopped answering", cause: null)` after the debounce, unless
    `markConnected` arrives first.
  - Consumers updated in lockstep:
    - `codex_plugin_descriptor.dart` passes `degrade`;
    - `open_code_plugin_descriptor.dart` passes `fail` in shared mode and `degrade` otherwise;
    - the reporter, cold-start and bridge-plugin tests in `sesori_plugin_runtime/test/`.

### Tests that matter

- **Step 5, command Api:** `readDisabled` parses `true`, `false` and garbage; a timeout or non-zero exit throws.
- **Step 5, service (`acquire`):**
  - A service that is already discoverable never runs a command.
  - A version below 2.0.11, or no binary, never runs `service`.
  - `disabled` = `true`, or a failing `get`, returns `null` without a start.
  - A successful start followed by discovery returns the endpoint.
  - A start that fails, times out or aborts returns `null`, and an abort is rethrown.
  - The service is still undiscoverable after a successful start: returns `null`.
- **Step 5, descriptor:**
  - The service started by the bridge is attached with `mode: shared` and nothing spawned or owned.
  - A start fallback spawns the private server.
  - The opt-out flag and an explicit binary never run `service`.
- **Step 6:**
  - A shared-mode disconnect past the debounce reports `PluginFailed`; a reconnect inside it does not.
  - A shared start whose attach health check fails ends in `PluginFailed`. This replaces the phase-1 degraded
    expectation.
  - Attach and managed modes still degrade.
  - The reporter's existing tests stay green for Codex.

### Live check (isolated, step 5 and step 6)

Use the phase-1 setup: a separate `HOME` and XDG directories, a free dev slot, and `ulimit -n 8192`. Never touch the
user's own processes.

- **With no service registered:** the bridge runs `service start` with the PATH CLI, attaches, and a prompt and
  Stop work.
- **Repeat with PATH hiding the CLI:** the bundled runtime starts the service.
- **`opencode service set disabled true`:** a private server is spawned.
- **Step 6:** `opencode service stop`, then a request. The plugin reports failed, then re-attaches to a fresh
  service and a prompt runs.
- Stop the isolated service at the end with `opencode service stop`.

### Phase 2 complexity budget

- **New persistent state:** none. OpenCode owns the service process, its registration and its configuration.
- **New in-memory mutable state:** none. The additions are one stateless command Api, three thin repository
  methods, one stateless service built per start, and one closed enum parameter on the reporter.
- **Deliberately not added:**
  - bridge ownership or supervision of the service process;
  - a bridge-side restart monitor, re-discovery timer or file watcher;
  - re-implementing `Service.ensure`'s contender logic;
  - version-skew negotiation;
  - reading OpenCode's service configuration file directly (the CLI owns it).

### Phase 2 accepted risks

- **`service start` fails, or the CLI hangs past the 130 s backstop:** a private server is spawned, and a service
  started later can still resume its turns twice. This is rare: it needs a broken first boot or a hung CLI. The bridge waits as long as
  OpenCode does (decided in #1927), because a shorter bound would fall back while the detached service is still
  booting on the same database.
- **A shared-mode generation fails on any lasting disconnect,** including a TUI-triggered `service restart`. The
  next request re-attaches. In-flight relay requests during that window fail once.
- **The bundled runtime binary starts the service:** a later bridge runtime upgrade or cleanup may delete that
  binary while the service runs. The running process is unaffected, and the next `service start` uses the current
  binary.

### Later phase (dropped)

- **Phase 3: surface a Stop that did not interrupt.** Dropped as a follow-up on 2026-10-08.
  - What it was: when OpenCode answers Stop with `interrupted:false`, tell the user instead of silently succeeding.
  - Why dropped: the shared service removes the two-server case that motivated it. In the remaining private
    fallback, a turn running on another server never shows as busy through the bridge, because session status comes
    from the bridge's own server, so the app offers no Stop for it. A turn that settles just before Stop also answers
    `interrupted:false`, and reporting that as a failure would be wrong. Nothing live needs it.
  - The behavior today: `OpenCodeV2Service.abortSession` ignores the `interrupted` result and reports the abort as
    accepted.

## Steps

Merged PRs keep their original `/4` titles. From step 4 on, the series total is 8; phase 3 adds no steps.

| Step | Title | Contents |
|---|---|---|
| 1 | `🌱 [opencode-shared-service] Plan sharing OpenCode 2's background server [step 1/4]` | Merged in #1923. |
| 2 | `🚧 [opencode-shared-service] Attach to OpenCode 2's shared background server [step 2/4]` | Merged in #1924. Phase 1. |
| 3 | `🌱 [opencode-shared-service] Reconcile the regression docs [step 3/4]` | Merged in #1925. Phase-1 docs. |
| 4 | `🌱 [opencode-shared-service] Record phase-1 verification and plan phase 2 [step 4/8]` | Merged in #1926. The phase-1 verification record and the phase-2 design and steps. Docs only. |
| 5 | `🚧 [opencode-shared-service] Start OpenCode's shared service instead of a private server [step 5/8]` | Merged in #1927. Phase 2 start path: the command Api, the repository delegates, `OpenCodeSharedServerService.acquire`, descriptor routing, tests, the isolated live check (PATH CLI, bundled runtime, disabled), and the regression bullets for the new behavior. About 500 to 700 changed lines, half of them tests. Complexity `🚧`: start-path lifecycle and an external process that outlives the bridge. No database change. User-visible: with sharing on, the phone and the TUI always share one server, even when the bridge starts first. |
| 6 | `⚙️ [opencode-shared-service] Re-attach after the shared service drops [step 6/8]` | Merged in #1933. `ManagedRuntimeDisconnectOutcome` on the reporter (covering both `markDisconnected` and `markDegradedNow`), shared mode reporting failure, the Codex and OpenCode consumers updated in lockstep, tests, and the live stop-then-request check. About 200 to 300 changed lines. No database change. User-visible: after the service restarts or moves, the next request reconnects without a bridge restart. |
| 7 | `🌱 [opencode-shared-service] Reconcile the regression docs [step 7/8]` | Reconcile `plugin-setup-and-lifecycle.md`, `HARNESS_CAPABILITIES.md` and the `bridge/app/README.md` flag notes with everything shipped. |
| 8 | `🌱 [opencode-shared-service] Record verification and retire the plan [step 8/8]` | Run the recorded coverage, record it, and move the plan to `.plan/completed/`. |

## Regression Coverage

- **Affected documents:** `docs/regression/plugin-setup-and-lifecycle.md` (OpenCode lifecycle bullets, failure
  signals and coverage), and `docs/HARNESS_CAPABILITIES.md` (an OpenCode-specific shared-service note).
- **Highest level:** L2 Routine.
  - Automated descriptor and discovery fixtures cover the selection rules.
  - A live-plugin check covers a real OpenCode 2 service: attach, events, a prompt and Stop through the shared server.
  - Phase 2 adds live coverage for:
    - the bridge starting the service from the PATH CLI and from the bundled runtime;
    - the `disabled` opt-out;
    - re-attach after `opencode service stop`.
- **Matrix:** OpenCode 2 on macOS (live). Linux and Windows path resolution is covered only by automated tests:
  the code is the same, with Windows reading `USERPROFILE`. Client end to end is not required, because no client
  code changes and the wire contract is unchanged.

## Complexity Budget (phase 1)

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
  shared service is running. Phase 2 keeps this, because starting the service needs a binary (S4), and the bundled
  runtime covers it.

Phase 2 removes the first three risks above, except when `service start` itself fails (see the phase-2 accepted
risks).

## Cleanup Assessment

No obsolete code was found. `--opencode-no-auto-start` stays, because it attaches to a server the user names, not to
the discovered service. Phase 2 keeps the private-server spawn as the fallback, so nothing in it becomes obsolete.
