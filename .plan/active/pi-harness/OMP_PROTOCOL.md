# Oh My Pi ACP And Runtime Protocol: Ground Truth

## Status And Sources

- **State:** researched from the exact release tag, official docs/source,
  release metadata, checksums, and a live isolated official binary.
- **Pinned baseline:** Oh My Pi `v17.2.13`.
- **Published:** 2026-08-11 at 14:41:52 UTC.
- **Tag commit:** `d3b22a0db6a4a0e2ef272a880e38286e0c466dc9`.
- **Observed:** 2026-08-11 on macOS arm64 with the official bare binary.
- **Repository:** `https://github.com/can1357/oh-my-pi`.
- **Package:** `@oh-my-pi/pi-coding-agent@17.2.13`; binary `omp`.
- **Primary ACP source:**
  `packages/coding-agent/src/modes/acp/{acp-agent,acp-mode,acp-client-bridge,acp-event-mapper}.ts`
  and `packages/utils/src/acp/{protocol,connection,transport,stream,schema}.ts`.
- **Primary storage/runtime source:**
  `packages/coding-agent/src/session/{session-manager,session-listing,session-paths}.ts`,
  `packages/utils/src/dirs.ts`, release scripts, and release assets.
- **License:** MIT.

This file covers `can1357/oh-my-pi` only. Pi's selected JSONL RPC contract is
recorded separately in `PROTOCOL.md`. The two products must not share launch,
wire, session-storage, runtime, or version assumptions merely because OMP began
as a Pi fork.

## 1. Identity And Fork Relationship

- CLI: `omp` (`omp.exe` as Sesori's normalized managed Windows filename).
- Version command: `omp --version`.
- `v17.2.13` output observed: exactly `omp/17.2.13` on stdout, exit 0.
- npm package engine: Bun >=1.3.14. Sesori's managed integration uses the
  standalone executable and does not invoke npm or require a separately
  installed Bun runtime.
- OMP describes itself as a fork of the Pi lineage, but it is an independent
  GitHub repository/release train rather than a GitHub fork object.
- OMP `17.2.13` and Pi `0.84.1` are not version-correlated compatibility
  releases. OMP ships its own packages, native modules, commands, storage,
  permissions, ACP implementation, and RPC dialect.

OMP releases frequently: twelve stable `17.2.x` releases were published from
2026-07-31 through 2026-08-11. Sesori pins an exact verified stable release and
does not treat upstream cadence as permission to download an untested latest
asset.

## 2. Selected Boundary: ACP V1

Invocation:

```text
omp acp
```

OMP also recognizes ACP as an internal mode, but Sesori uses the documented
subcommand. The process speaks JSON-RPC 2.0 over LF-delimited JSON objects on
stdin/stdout. Stderr is diagnostic only.

OMP vendors a behavior-compatible reimplementation of the ACP SDK surface in
`packages/utils/src/acp/`. Its declared `PROTOCOL_VERSION` is `1`.

Initialize request used by Sesori:

```json
{
  "jsonrpc":"2.0",
  "id":1,
  "method":"initialize",
  "params":{
    "protocolVersion":1,
    "clientCapabilities":{
      "fs":{"readTextFile":false,"writeTextFile":false},
      "terminal":false,
      "elicitation":{"form":{}}
    },
    "clientInfo":{"name":"sesori-bridge","version":"..."}
  }
}
```

The form capability is added in this series. Filesystem and terminal stay false
because OMP executes local tools itself; Sesori does not proxy laptop file or
terminal access through a phone connection.

Verified initialize result fields:

```text
protocolVersion: 1
agentInfo: name oh-my-pi, title Oh My Pi, version 17.2.13
agentCapabilities.loadSession: true
agentCapabilities.promptCapabilities: embeddedContext, image
agentCapabilities.sessionCapabilities: list, fork, resume, close
agentCapabilities.mcpCapabilities: http, sse
```

OMP advertises a terminal auth method only if the client advertises
`clientCapabilities.auth.terminal`. Sesori does not advertise it in this
series, so local OMP setup and `/login` remain the authentication path.

## 3. Why OMP RPC Is Rejected

OMP still exposes `--mode rpc`, but it is not Pi `v0.84.1` RPC:

| Pi dependency already merged | OMP RPC `v17.2.13` |
|---|---|
| no startup handshake | `ready` plus protocol versions 1/2 |
| one JSON object per physical frame | protocol 2 `rpc_chunk` base64 reassembly |
| `--session-id` caller-owned ID | no `--session-id` flag |
| `--approve` project trust | no `--approve`; OMP has approval modes |
| `get_entries`, `get_tree` | removed; OMP has paged messages instead |
| `get_commands` | removed; OMP pushes command updates |
| `get_available_thinking_levels` | removed; OMP uses other selection APIs |
| `agent_settled` completion | not the selected completion contract |

OMP RPC also adds host tools/URIs, subagents, login, handoff, fast mode, and
other OMP-only frames. Reusing `PiRpcClient` would require backend branches in
framing, startup, every launch, history, selection, commands, completion, and
failure handling. Implementing a second bespoke OMP transport would duplicate
ACP functionality that OMP already maintains for editor clients.

ACP is therefore the supported OMP boundary. Pi remains on its bespoke RPC;
there is no `sesori_plugin_pi_family` package.

## 4. Authentication And Setup

`initialize` always advertises the `agent` auth method. Calling:

```json
{"method":"authenticate","params":{"methodId":"agent"}}
```

acknowledges use of existing local credentials and returns `{}`. It does not
prove a model is configured or usable.

Verified no-model behavior:

- initialize and authenticate succeed;
- `session/new` succeeds and returns no model config option;
- `session/prompt` returns JSON-RPC error `-32603`, message `Internal error`;
- `error.data.details` begins `No model selected.` and includes local setup
  guidance plus the absolute `agent.db` path.

Sesori setup inspection therefore validates runtime only. Project-scoped catalog
discovery treats absent model options as failed and supplies bounded local
`/login` guidance. Prompt handling may classify the demonstrated prefix, but it
must not forward or log the returned local database path as user-facing text.
The original typed error remains available as a local cause where useful.

Credential/config sources include provider environment variables, OMP's local
SQLite-backed agent data, profiles, and project configuration. The launch
inherits the user's environment and does not create a Sesori-only OMP profile.

## 5. Sessions

### Create

```json
{
  "method":"session/new",
  "params":{"cwd":"/absolute/project","mcpServers":[]}
}
```

Response:

```text
sessionId, configOptions, modes
```

The ID is OMP's durable UUIDv7-style session ID. Unlike Pi RPC, Sesori does not
mint or pass it. OMP calls `ensureOnDisk()` for ACP `session/new`, so an empty
ACP-created session is immediately discoverable and needs no bridge pending-new
marker.

### Enumerate

```json
{"method":"session/list","params":{}}
{"method":"session/list","params":{"cwd":"/absolute/project"}}
{"method":"session/list","params":{"cursor":"opaque-next-cursor"}}
```

Each item contains:

```text
sessionId, cwd, title?, updatedAt?, _meta?
```

`_meta` currently carries message count and file size, which Sesori does not
need for identity. OMP sorts newest first and pages with an opaque string cursor.
The live empty-root probe returned a new session through the cwd-scoped list
immediately after `session/new`.

The selected ACP list has no parent-session field. OMP child-session lineage is
therefore unavailable in Sesori. The plugin does not parse OMP transcript files
solely to infer it.

### Load and resume

```json
{
  "method":"session/load",
  "params":{"sessionId":"...","cwd":"/absolute/project","mcpServers":[]}
}
```

`session/load` restores the session into the ACP process and replays history as
`session/update` notifications. `session/resume` restores without replay when a
client needs only residency. Sesori's generic ACP plugin prefers load because it
also supports history and current config capture.

OMP searches the cwd scope first and falls back to its global ID index for
legacy/moved buckets. The caller still supplies the best known real cwd.

### Close, rename, and delete

- Standard ACP `session/close` flushes/closes and removes a session from the
  current process. It does not delete persisted history.
- Standard ACP has no rename method. OMP advertises `/rename`; the generic
  Sesori rename remains a bridge-local title override, while users can invoke
  `/rename` when they want OMP storage updated too.
- OMP advertises `/session delete`. It routes through the active
  `SessionManager`, closes the writer, deletes the session and associated
  artifacts, and tells the caller to load another session.
- Persisted cleanup uses ACP list/load, `/session delete`, and close rather than
  directly mutating OMP JSONL or shared blob storage.

Not-found deletion is idempotent. The normal terminal handoff applies: exit a
terminal OMP session before operating on that same session from Sesori.

## 6. History And Live Updates

`session/load` emits replay through the same standard updates used live. OMP
emits these relevant `sessionUpdate` variants:

```text
agent_message_chunk
agent_thought_chunk
user_message_chunk
plan
current_mode_update
config_option_update
available_commands_update
session_info_update
usage_update
```

The existing ACP mapper handles text, reasoning, tools, tool diffs/content,
plans, command refresh, titles, and usage metadata. OMP includes optional
message IDs and maps its internal tool names into standard ACP tool kinds.
Unknown future variants are ignored at the ACP boundary rather than breaking
the run.

Turn execution:

```json
{
  "method":"session/prompt",
  "params":{"sessionId":"...","prompt":[{"type":"text","text":"..."}]}
}
```

The response's `stopReason` completes the turn. OMP queues a prompt behind an
in-flight cancellation/cleanup internally. ACP's server-initiated permission
and `elicitation/create` requests do not identify their originating session, so
Sesori enables an OMP-specific process-wide prompt lane. Independent sessions
remain resident in one ACP process, but only one OMP prompt is dispatched at a
time; the generic ACP default and Cursor retain per-session concurrency.

Abort is a `session/cancel` notification. Sesori also resolves pending ACP
permissions/forms so OMP is not left awaiting a client response.

## 7. Models, Thinking, Modes, And Commands

`session/new`, `session/load`, `session/resume`, and
`session/set_config_option` return `configOptions`.

OMP `v17.2.13` uses:

```text
id/category mode: select default/plan where enabled
id/category model: select values <provider>/<model-id>
id thinking, category thought_level: off, auto, and model-specific levels
```

Model values are built as `${provider}/${id}`. Model IDs can themselves contain
slashes, so the OMP mapper splits only the first slash and retains the exact
combined value for `session/set_config_option` writes.

Thinking options depend on the selected model. The isolated project probe
selects each model and captures the returned thinking options rather than
hardcoding provider rules.

Modes map to Sesori agents. Models group under their provider. Provider auth
type remains unknown because ACP config options do not report it.

Commands arrive in `available_commands_update` with name, description, and an
optional input hint. The live no-model probe received OMP built-ins, plugin
commands, and skills after `session/new`. Sesori maps names/descriptions but
never sends them to analytics.

Catalog probing launches `omp acp --session-dir <scratch>` in the project cwd,
creates one session, captures config/commands, sweeps selections, closes it, and
deletes only the plugin scratch directory. The user's normal OMP history is not
polluted.

## 8. Permissions And Form Elicitations

OMP setting `tools.approvalMode` supports:

```text
always-ask, write, yolo
```

The default is `yolo`. Sesori passes no override. When a stricter configuration
causes OMP to request permission, it sends standard
`session/request_permission` with a tool call and supplied options such as
allow-once, allow-always, reject-once, and reject-always. Sesori must echo the
selected OMP option ID; it must not infer a grant that OMP did not offer.

When the client advertises form elicitation, OMP maps reachable extension UI:

| OMP UI | ACP schema | Sesori presentation |
|---|---|---|
| `select` | string enum | single-select question |
| `confirm` | boolean | Yes/No question |
| `input` | string with description | custom-answer question |
| `editor` | string with default | custom answer with bounded labelled prefill |
| plan approval | string enum | approve/refine question |

Accepted form replies return typed scalar values by property key. Decline,
cancel, abort, process exit, and plugin disposal clear the corresponding phone
card. The process-wide OMP prompt lane makes the sole active turn the reliable
owner of each sessionless form request. Unsupported schemas are declined with
bounded diagnostics.

OMP's extension `notify` currently writes a local debug notification and sends
no ACP client notification. Custom components, themes, terminal input, and other
TUI decorations are unavailable/no-op in ACP mode.

## 9. Storage And Profiles

Normal default roots are based under `~/.omp`, with agent data normally under
`~/.omp/agent`. OMP also supports:

- `OMP_PROFILE`, with legacy `PI_PROFILE` fallback;
- `PI_CODING_AGENT_DIR` for the default-profile agent directory;
- `PI_CODING_AGENT_SESSION_DIR` for an explicit session directory;
- `PI_CONFIG_DIR`; and
- Linux XDG data/state/cache roots after OMP migration.

Auth/settings use `agent.db`; sessions remain JSONL. Current files begin with a
fixed 256-byte `type:"title"` slot, then a version-3 session header and entries.

The prose `docs/session.md` at `v17.2.13` still describes the short-lived
17.2.5-17.2.8 hashed bucket layout. Tagged source is authoritative: current
`session-paths.ts` restored path-derived home (`-...`), temp (`-tmp...`), and
absolute (`--...--`) buckets and retains the hash only to migrate sessions out
of that reverted format. This divergence is another reason not to reproduce OMP
path logic for catalog/history in Sesori.

Sesori inherits the active profile/environment and uses ACP for enumeration,
load, and deletion. It does not override OMP roots or parse OMP transcript
content merely to import sessions.

## 10. Official Standalone Distribution

Release URL template:

```text
https://github.com/can1357/oh-my-pi/releases/download/v<version>/<asset>
```

`v17.2.13` executable assets:

| Target | Asset | SHA-256 |
|---|---|---|
| macOS arm64 | `omp-darwin-arm64` | `2841151eb3381cfe094aaefef3fb7be3c926075821ba6bf3fa77dcb2ffbb8db7` |
| macOS x64 | `omp-darwin-x64` | `07d5f9603b9e3dc0dc918d94cbfd5c6ed50c13f72faed6eec83d677580739d7c` |
| Linux arm64 | `omp-linux-arm64` | `f8d22cfc74d51b41185e4d7188ad88eb0e1e5e388f762ae2f90c21b095d039dd` |
| Linux musl arm64 | `omp-linux-musl-arm64` | `c199ec7b4ac4e59c86b570bae3e9fd3e95843f79fa5807354de8997438107fee` |
| Linux musl x64 | `omp-linux-musl-x64` | `fbba26125946d1a98ced8fc84c55e381ffb60ef568487e13788ec9690664b0eb` |
| Linux x64 | `omp-linux-x64` | `9c6a0ceb2995da1ba0524fc858f85c39127fd0784226ec91d54e556b8028b951` |
| Windows x64 | `omp-windows-x64.exe` | `1f8077b14df8d010533d4fb814de83709215f39d0d550559417eca0c3c1d01dc` |

There is no Windows arm64 executable. The release also contains
`SHA256SUMS.txt` and a browser extension zip; neither is the managed runtime.

The executable assets are bare files, not zip/tar containers. Managed install
must use the direct-binary runtime variant, verify before placement, normalize
the final filename, mark Unix files executable, write the sentinel last, and
probe `omp/<version>` before reporting ready.

Linux selection must distinguish glibc from musl. The OMP-owned probe follows
upstream's ordinary host distinction (Alpine marker or `ldd` evidence) and does
not widen bridge-wide platform identity for one publisher.

## 11. Live Verification Record

The official macOS arm64 `v17.2.13` binary was downloaded from the GitHub
release and matched the published digest. In an isolated temporary cwd and
`PI_CODING_AGENT_DIR`, the probe verified:

1. `omp --version` -> `omp/17.2.13`.
2. ACP initialize negotiated v1 and advertised the source-recorded capabilities.
3. `authenticate(agent)` returned success.
4. Unfiltered `session/list` returned an empty first page.
5. `session/new` returned a durable ID, default/plan modes, and off/auto thinking
   options with no configured model.
6. The new empty session immediately appeared in cwd-scoped `session/list` with
   cwd, updated time, message count 0, and file size metadata.
7. OMP pushed `available_commands_update` and `session_info_update` after create.
8. A no-model prompt failed with the demonstrated typed JSON-RPC error and local
   path-bearing details; no prompt content appeared in stderr.

The probe did not use real credentials or send a provider request.

## 12. Verification Still Required During Implementation

- Refresh source/assets against the exact stable pin selected in Step 9.
- Run authenticated text/image/reasoning/tool turns and compare live versus
  `session/load` replay through Sesori's ACP mapper.
- Verify model/provider/thinking sweeps with API-key, OAuth, and custom-provider
  configurations without logging account or credential data.
- Verify `always-ask`/`write` permissions and select/confirm/input/editor/plan
  forms end to end, including routing forms from two queued sessions to the
  originating conversation; verify default `yolo` emits no permission cards.
- Verify loaded-session `/session delete` removes OMP-managed artifacts and is
  idempotent after restart cleanup.
- Verify glibc and musl selection on available Linux hosts, Windows x64 install,
  and explicit unsupported status on Windows arm64.
- Verify profiles, XDG roots, custom session directories, moved/deleted cwd,
  process respawn, and terminal-to-Sesori handoff.
- Recheck unsupported parent lineage, local-only Sesori rename, OMP notify, URL
  elicitation, and host fs/terminal behavior remain explicit rather than
  silently misrepresented.
