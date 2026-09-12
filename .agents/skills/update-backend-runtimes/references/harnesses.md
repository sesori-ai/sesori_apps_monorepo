# Harness Release and Probe Reference

Read with `../SKILL.md`; its planning, approval and safety rules apply throughout.
Repository paths here are relative to the repository root. Each package's
manifest/descriptor and tests are authoritative over these starting points.
Re-check release channels and protocol observations on every audit; do not copy
an old pin or claim another harness's ACP behavior as evidence.

## OpenCode

- **Source:** stable `anomalyco/opencode` GitHub release (`vX.Y.Z`); compare
  `npm view opencode-ai version` when available.
- **Pin:** `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_runtime_manifest.dart`.
  Preserve `minPathVersion`; `targetVersion` drives `bundledVersion`.
- **Assets:** six, with GitHub SHA-256 digests:
  `opencode-darwin-{arm64,x64}.zip`, `opencode-linux-{arm64,x64}.tar.gz`,
  `opencode-windows-{arm64,x64}.zip`. Preserve the manifest's entrypoint/layout.
- **Audit:** REST/SSE schemas and serialization, sessions/messages, permission and
  question replies, models, subagents, cancellation, and database/history shape.
  Inspect `bridge/sesori_plugin_opencode/tool/opencode_v1_surface.json` and the
  plugin's DB-first import before promising that a new API can replace it. Keep
  minimum-surface metadata aligned only if a floor increase is approved.
- **Probe:** production current-host managed install, exact version, isolated
  loopback `opencode serve`, and the REST/SSE startup paths the plugin actually
  drives. Read the current runtime policy/client and use disposable database and
  profile roots. Never boot against or migrate the user's OpenCode database.
- **Verify:** owning manifest/runtime-policy and affected API/import tests plus
  package analyzer. Preserve attach/no-auto-start behavior and PATH precedence.

## Antigravity

- **Source:** `agentclientprotocol/registry`, `antigravity-acp/agent.json`, resolved
  to an immutable registry commit; official Google archives from `dl.google.com`.
  Read `docs/ANTIGRAVITY.md` and Google's linked terms. This is the proprietary
  official ACP server plus local harness, not `agy -p` or a community adapter.
- **Pins:** `bridge/sesori_plugin_antigravity/lib/src/foundation/antigravity_release.dart`
  and `lib/src/runtime/antigravity_runtime_manifest.dart` in that package. Record
  registry commit/package version, exact `agentVersion`, protocol version,
  artifact URLs/hashes/sizes, and server/harness member facts separately.
- **Compatibility exception:** the manifest aliases `minPathVersion` and
  `bundledVersion` to the registry package version; the validator accepts an
  exact ACP identity/pair, not a free-standing semantic floor. Identify effects
  on previously accepted explicit/PATH pairs in the plan. Do not manufacture
  an independent minimum or silently change this exact-pin policy.
- **Assets:** five ZIPs: macOS arm64, Linux arm64/x64, Windows arm64/x64.
  No macOS x64. Independently hash official downloads; do not portray locally
  computed checksums as Google's signed provenance. Preserve sibling
  `agy_acp_server.par` + `localharness_external` (Windows `.exe` counterparts),
  launch environment, Linux `--uid=`, permissions and archive limits.
- **Probe:** no supported standalone CLI version command. Use the owning
  `AntigravityRuntimeVersionValidator` / runtime service's initialize-only ACP
  contract with candidate release facts and isolated state. Confirm exact
  identity, protocol, capabilities, auth-method set and process teardown before
  placement; create no session and initiate no OAuth. Linux extraction requires
  Info-ZIP `unzip` with ZipInfo support. Never substitute normal Google profiles.
- **Opportunities:** inspect account/model discovery, auth, history, deletion and
  subagent gaps against the current matrix. The 2026-09-12 matrix assessment found
  only generic parent-local subagent tool calls, not child identity/lifecycle or
  scoped-stop authority. Reassess on new evidence; do not infer support from
  native delegation or generic ACP features. Closed source limits remain explicit.

## Codex

- **Source:** stable `openai/codex` release `rust-vX.Y.Z`; compare
  `npm view @openai/codex version` when available. Store only `X.Y.Z` as target.
- **Pin:** `bridge/sesori_plugin_codex/lib/src/runtime/codex_runtime_manifest.dart`;
  preserve the backing `minPathVersion` declaration.
- **Assets:** require six **canonical package** archives, not bare CLI archives:
  - `codex-package-aarch64-apple-darwin.tar.gz`
  - `codex-package-x86_64-apple-darwin.tar.gz`
  - `codex-package-aarch64-unknown-linux-musl.tar.gz`
  - `codex-package-x86_64-unknown-linux-musl.tar.gz`
  - `codex-package-aarch64-pc-windows-msvc.tar.gz`
  - `codex-package-x86_64-pc-windows-msvc.tar.gz`
  Verify GitHub digests and `codex-package_SHA256SUMS` when present, including
  the checksum file's published digest. Windows also uses tar.gz. Keep
  `bin/codex` / `bin/codex.exe`, `codex-code-mode-host`, and resources together.
- **Audit:** upstream `codex-rs/app-server-protocol/`, `codex-rs/app-server/`,
  schemas, processors and tests. Trace `thread/*`, `turn/*`, `item/*`, paging/
  rollout history, input/approval/auth requests, code mode, subagents, model
  discovery and experimental gates. Core/TUI/`exec --json` events are not
  automatically app-server notifications; `turn/completed` is not Pi's settled
  event. Prove ownership before replacing queue, retry, interrupt or history code.
- **Install:** use `ManagedRuntimeComposition.createInstaller()` with candidate
  manifest and asset resolver, then the production install/extract chain. The
  descriptor's installer hard-codes the current pin. Confirm the final
  `<stateDirectory>/codex/<version>/bin/codex[.exe]`, complete helpers/resources,
  and `.sesori-runtime-sha256` containing the bare candidate digest.
- **Probe both current-host transports:** isolated HOME/`CODEX_HOME`, exact
  version, 10-second response deadlines and bounded process-tree cleanup. Follow
  the owning stdio client and `codex_runtime_policy.dart` / WebSocket client;
  their envelopes and handshake policies differ.

  Stdio (`app-server --listen stdio://`), separate newline-delimited records:

  ```json
  {"id":"probe-init","method":"initialize","params":{"clientInfo":{"name":"sesori_runtime_probe","title":"Sesori Bridge","version":"0.0.0"}}}
  {"method":"initialized"}
  {"id":"probe-list","method":"thread/list","params":{"limit":1}}
  ```

  Wait for a successful correlated initialize result with the required typed
  `CodexInitializeResult` fields **before** sending `initialized` and list.
  Keep this production stdio check free of experimental capabilities.

  WebSocket (`app-server --listen ws://127.0.0.1:<fresh-port>`), separate text
  frames, not NDJSON:

  ```json
  {"jsonrpc":"2.0","id":"probe-init","method":"initialize","params":{"clientInfo":{"name":"sesori_runtime_probe","title":null,"version":"0.0.0"},"capabilities":{"experimentalApi":true,"requestAttestation":false,"optOutNotificationMethods":null}}}
  {"jsonrpc":"2.0","id":"probe-list","method":"thread/list","params":{"limit":1}}
  ```

  Again await initialize before list. The current production WebSocket client
  sends no `initialized`; verify candidate acceptance rather than adding it to
  hide a regression. Require matching IDs, no error and typed list/pagination
  shape. A server-originated `method` + `id` request is not a response. Report
  either transport's failure; one passing transport cannot validate the other.

## GitHub Copilot

- **Source:** stable `github/copilot-cli` `vX.Y.Z`; require agreement with
  `npm view @github/copilot version` when available.
- **Pin:** `bridge/sesori_plugin_copilot/lib/src/runtime/copilot_runtime_manifest.dart`;
  preserve `minPathVersion`.
- **Assets:** six: `copilot-darwin-{arm64,x64}.tar.gz`,
  `copilot-linux-{arm64,x64}.tar.gz`, `copilot-win32-{arm64,x64}.zip`, with
  GitHub digests. Current layout extracts `copilot` / `copilot.exe` as a single
  binary; verify packaging rather than imposing Pi/Codex package assumptions.
- **Probe:** production current-host install, isolated `COPILOT_HOME`, branded
  `GitHub Copilot CLI X.Y.Z.` version, then `--no-auto-update --acp`. Require ACP
  v1 initialize and the `copilot-login` method, without prompting or reading the
  user's profile. Audit auth-state, models, session/history and subagent events
  through Copilot's own wire, not just shared ACP DTOs.
- **Verify:** manifest/descriptor and affected adapter tests plus analyzer.

## Cursor

- **Source:** read `https://cursor.com/install` as text. Extract one unambiguous
  published build used in its version directory and download URLs; do not run
  the installer. Ambiguous discovery blocks pinning rather than inviting guesses.
- **Pin:** `bridge/sesori_plugin_cursor/lib/src/runtime/cursor_runtime_manifest.dart`.
  Target is the exact `YYYY.MM.DD-<build>` string. PATH comparison uses the leading
  calendar date; preserve that separate minimum and the raw bundled build value.
- **Assets:** four self-hashed archives at
  `https://downloads.cursor.com/lab/<build>/<os>/<arch>/agent-cli-package.tar.gz`,
  for `darwin`/`linux` and `arm64`/`x64`. No Windows package. Download/hash all
  four; no upstream checksum manifest is currently published. Preserve
  `dist-package/` and the `cursor-agent` entrypoint's siblings. Re-published bytes
  must fail the old pin rather than bypass checksum verification.
- **Probe:** production current-host package placement, exact build identity and
  the descriptor's ACP launch. Verify initialization, advertised model/mode and
  configured load/replay behavior used by the adapter; an unavailable required
  fixture blocks the Cursor pin. Confirm download URLs resolve before consumer
  publication.
- **Audit:** model switching, history/load, native Task/subagent coverage and
  settings. Report inaccessible upstream source rather than guessing from CLI UX.

## Claude Code

- **Source:** stable `anthropics/claude-code` `vX.Y.Z`; compare
  `npm view @anthropic-ai/claude-code version`. Inspect the associated
  `@anthropic-ai/claude-agent-sdk` release too; do not assume permanent version
  correspondence between CLI and SDK.
- **Pin:** `bridge/sesori_plugin_claude/lib/src/runtime/claude_plugin_descriptor.dart`,
  `targetVersion` versus `minVersion`. PATH/explicit CLI only; no managed assets.
- **Probe:** isolated official current-host CLI, exact `--version`, every public
  flag in `bridge/sesori_plugin_claude/lib/src/api/claude_launch_spec.dart`, and
  matching SDK launch code for headless stream-json/stdio permission behavior.
  Stop on required-flag or semantic regressions. Version/help/source checks do
  not re-verify live stream observations; label them accurately and keep existing
  historical `Verified against` claims unless that trace is repeated.
- **Audit:** stream-json/control envelopes, tool and subagent lifecycle, replay,
  permissions, questions, models and settings. This plugin drives the CLI seam,
  not an arbitrary new SDK feature. Use approved live probes for adopted changes.

## Hermes Agent

- **Source:** stable `NousResearch/hermes-agent` GitHub release. Calendar tag and
  semantic CLI version differ: reconcile release name and tagged `pyproject.toml`.
  PyPI may lag and is not the release authority.
- **Pin:** `bridge/sesori_plugin_hermes/lib/src/runtime/hermes_plugin_descriptor.dart`,
  independent `targetVersion` / `minVersion`; direct CLI, no managed artifacts.
- **Probe:** acquire exact tagged source under the permitted disposable boundary,
  install its `acp` extra there, and verify `hermes acp --version`, ACP v1
  initialize, advertised list/load capabilities and `session/list`. Do not run
  remote installers for discovery or create a forbidden checkout. Isolate HOME;
  a fresh profile can lack model/provider setup. Use an authorized configured
  fixture for new/load coverage; an unavailable required fixture blocks the
  Hermes pin. Report unavailable evidence explicitly.
- **Audit:** the actual Hermes ACP implementation, not only its CLI release
  notes: settings, model/provider discovery, history, tools and subagents.

## Pi

- **Source:** stable `earendil-works/pi` `vX.Y.Z`, not OMP or a local Pi fork. Compare
  the published `@earendil-works/pi-coding-agent` package when available; the
  repository name and npm package name differ.
- **Pin:** `bridge/sesori_plugin_pi/lib/src/runtime/pi_runtime_manifest.dart`;
  preserve `minPathVersion`.
- **Assets:** six: `pi-darwin-{arm64,x64}.tar.gz`,
  `pi-linux-{arm64,x64}.tar.gz`, `pi-windows-{arm64,x64}.zip`. Require GitHub
  digests; reconcile `SHA256SUMS` when present. Preserve the Unix `pi/` tree and
  Windows package tree; the executable cannot be separated from its package.
- **Audit:** RPC commands, response IDs, serialized `AgentSessionEvent`,
  `session.subscribe()` / `toJsonEvent()` and `rpc-mode.ts` forwarding. An event
  accepted by `pi.on(...)` can be extension-only. `ui_prompt_start`/`ui_prompt_end`
  must not be parsed as wire events without evidence; RPC can instead expose
  `extension_ui_request`. Inspect exact field casing, delta shape, retry/
  compaction, queue controls, models/auth, history and package changes.
- **Lifecycle:** preserve delta-only updates and `message_end` authority.
  `agent_end` is a low-level boundary that can precede retries or queued work;
  inspect `agent_settled` for user-visible completion, and distinguish per-turn/
  per-tool events. Pi has no version handshake: select any justified version
  branch only from a validated managed or PATH version, not incidental events.
- **Probe:** production current-host placement and exact `--version`; isolate
  HOME, `PI_CODING_AGENT_DIR`, `PI_CODING_AGENT_SESSION_DIR`, config/cache roots,
  and set `PI_SKIP_VERSION_CHECK=1`. Launch the absolute entrypoint with
  `--mode rpc --no-session --approve`, then send:

  ```json
  {"id":"probe-1","type":"get_state"}
  ```

  Within 10 seconds require `id == "probe-1"`, `type == "response"`,
  `command == "get_state"`, `success == true`, and object `data`. Drain unrelated
  events; reject malformed/mismatched responses. Close stdin, wait at most two
  seconds, then terminate the process tree before cleanup. No inherited secrets
  or normal profile; this probe policy must not replace production user settings.

## Oh My Pi (OMP)

- **Source:** stable `can1357/oh-my-pi` `vX.Y.Z`, as wired by the manifest. A local
  `omp-fork` Git remote is not authority to switch release distributions.
- **Pin:** `bridge/sesori_plugin_omp/lib/src/runtime/omp_runtime_manifest.dart`;
  preserve `minPathVersion`.
- **Assets:** **bare executables** plus `SHA256SUMS.txt`. Enumerate the selected
  official release and reconcile it with the manifest's complete asset mapping:
  `OmpRuntimeManifest._assets` and `_linuxAssets` (both libc variants). Do not
  assume a fixed asset count. Names use `omp-darwin-{arm64,x64}`,
  `omp-linux-{arm64,x64}` (glibc), `omp-linux-musl-{arm64,x64}`, and
  `omp-windows-<arch>.exe`. Record newly published architectures separately from
  currently supported mappings; adopting one is a platform feature, not a
  mechanical pin change. Verify GitHub digests, checksum-list agreement, and
  independently downloaded bytes for every selected asset. Preserve direct-binary
  layout and the plugin's libc selection, never model these assets as ZIPs.
- **Probe:** exact `omp/<version>` and the owning ACP launch/initialization.
  A disposable configured fixture must cover `authenticate(agent)`, list/new/load,
  and persisted cleanup before the pin; an unavailable required fixture blocks
  the OMP pin. Isolate `PI_CODING_AGENT_DIR` and all other profile roots; use an
  allowlisted environment, not inherited credentials. Report required
  fixture/protocol blockers. Preserve normal production approval policy.
  Current-host execution is sufficient for ordinary existing-platform target
  bumps. A new Windows ARM64 mapping separately requires native Windows ARM64
  install/version/ACP smoke before its platform claim or retirement; another
  host's evidence is insufficient and a missing Windows runner blocks that
  feature claim.
- **Audit:** OMP's ACP projection, not Pi RPC. Trace auth, configuration, history,
  models, tools, subagent and cancellation behavior at that seam.

## DeepSeek

- **Sources:** stable adapter releases from `sesori-ai/sesori-deepseek-acp` plus
  the DeepSeek Harness dependencies actually pinned by that producer. Audit both;
  updating only the existing adapter tag can miss a newer upstream harness.
- **Consumer pin:** `bridge/sesori_plugin_deepseek/lib/src/runtime/deepseek_runtime_manifest.dart`.
  Keep `minimumVersion` / `minPathVersion` separate from `targetVersion`. Record
  adapter version, embedded `@deepseek-ai/*` harness pins and extension protocol
  independently. An upstream RC pin is not a stable adapter version or approval
  to start tracking arbitrary prereleases.
- **Producer work:** inspect its `release/config.json`, package/lockfile,
  extension protocol, packaging workflow and conformance tests. When an adapter
  change/release is needed, plan that repository's PR and approved release before
  the consumer bump. `consumerCommit` must identify an exact pushed consumer
  conformance snapshot; preserve frozen protocol baselines unless their contract
  changes. Keep a dependent consumer PR draft or unopened until assets exist.
- **Publication:** use the producer's existing tagged release workflow, six native
  package/smoke jobs, consumer conformance, complete-set verification and publish
  gates. Verify tag/approved source correspondence. This private npm package is
  distributed via GitHub Releases, not `npm publish`. Release/merge authority
  remains the user's; a plan is not permission to tag or merge another repo.
- **Assets:** six `sesori-deepseek-acp-v<version>-<platform>-<arch>` archives:
  `darwin`/`linux` arm64/x64 `.tar.gz`, `windows` arm64/x64 `.zip`, plus
  `checksums.txt`. Reconcile GitHub/list/download hashes. Preserve launchers,
  bundled Node, dependencies, protocol files and runtime assets as one package.
  Inspect `BUILD-METADATA.json` and embedded harness pins against producer facts.
- **Probe:** current-host production installation, `--version` identity including
  adapter, `deepseek-harness/<pin>` and `acp/1`, `check`, then the producer's
  packaged initialize/list/new/prompt/history/restart/load/close smoke. Distinguish
  fake-provider conformance from separately authorized authenticated feature E2E.
  Unexpected protocol/harness identity drift blocks pinning, not a reason to
  loosen the consumer validator.
- **Plan dependencies honestly:** publish and verify all assets before pinning
  hashes; never use placeholders or temporary dual-version support solely for
  unreleased intermediate states. Ask separately if a real supported-runtime
  contract requires a floor increase. Report adapter maintenance/release effort
  even when the monorepo diff itself is only a version bump.

## Grok Build

- **Source:** xAI's official `https://x.ai/cli/stable` channel; reconcile its build
  identity with `xai-org/grok-build` source when source evidence is available.
  Do not execute the remote installer just to discover a release. A source-to-
  binary association is useful evidence but is not a routine pin gate for this
  direct CLI.
- **Pin:** `bridge/sesori_plugin_grok/lib/src/runtime/grok_plugin_descriptor.dart`,
  `targetVersion` versus `minVersion`. Direct CLI only; no managed assets/digests.
- **Probe:** isolated official current-host candidate, branded
  `grok <version> (<build>)`, then the exact production launch:
  `grok --no-auto-update agent --no-leader stdio`. Never add `--always-approve` or
  `--yolo`. Verify ACP v1 identity and advertised list/load/resume/close support.
  ACP source/SDK names may spell the vendor namespace `x.ai/...`, while SDK
  normalization emits the `_x.ai/...` wire namespace; compare normalized wire
  methods before treating this as drift. Versioned normalization evidence is
  [ACP 0.10.4 source](https://docs.rs/agent-client-protocol/0.10.4/src/agent_client_protocol/lib.rs.html#221-234).
  Required authenticated new/prompt/replay/model-selection/close probes use
  explicitly authorized test credentials and are pin gates; an unavailable
  required fixture blocks the Grok pin. Optional broad provider/model/child
  exploration remains non-gating. Source-to-binary association is useful
  evidence but is not a routine signed or source-attestation gate.
- **Audit:** Grok-owned model metadata and `session/set_model`, replay, tool/
  subagent extensions and scoped cancellation. Neither a generic ACP ACK nor
  an idle notification proves those behaviors. Preserve no-auto-update/no-leader
  launch policy and stop on required-surface regressions.
