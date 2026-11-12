# Harness Release and Probe Reference

Read with `../SKILL.md`; its planning, approval and safety rules apply throughout.
Repository paths here are relative to the repository root. Each package's
manifest/descriptor and tests are authoritative over these starting points.
Re-check release channels and protocol observations on every audit; do not copy
an old pin or claim another harness's ACP behavior as evidence.

These are verification checklists, not a requirement to hold old targets until
every fixture is available. Follow the skill's update-first policy: update all
included harnesses, run safely available checks, and group unavailable/failed
checks in final follow-up. Keep coverage claims honest. Only an exceptional,
concrete problem can justify a documented temporary hold with a resolution path.

## OpenCode

- **Source:** stable `@opencode/cli` npm version and matching `anomalyco/opencode`
  source tag, resolved to an immutable commit. As verified 2026-11-12, v2 tags
  get GitHub releases too, but GitHub latest and `opencode-ai` still select v1;
  recheck both channels rather than assuming they identify the same protocol.
- **Pin:** `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_runtime_manifest.dart`.
  Preserve `minPathVersion`; `targetVersion` drives `bundledVersion`. PATH v1
  remains supported. Every managed upgrade (v1 to v2, and between v2 releases
  that add migrations) migrates the native database one-way.
- **Assets:** six npm packages `@opencode/cli-{darwin,linux,windows}-{arm64,x64}`.
  Fetch exact-version registry metadata, verify each downloaded `.tgz` against
  published integrity, and independently compute its manifest SHA-256. URLs are
  `https://registry.npmjs.org/@opencode/cli-<target>/-/cli-<target>-<version>.tgz`.
  All use `ArchiveFormat.tarGz` with `package/bin/opencode[.exe]`, normalized by
  `RuntimeArchiveLayout.singleBinary`. As of 2.2.7 the darwin and windows
  tarballs also carry `package/` and `package/bin/` directory entries, which the
  extractor accepts. Verify members; do not assume helpers are unnecessary if a
  future release changes the layout.
- **Audit:** REST/SSE schemas and serialization, sessions/messages, permission and
  question replies, models, subagents, cancellation, and database/history shape.
  For v1 changes, inspect `bridge/sesori_plugin_opencode/tool/opencode_v1_surface.json`
  and the plugin's DB-first import before promising that a new API can replace
  it; v2 audits use `tool/opencode_v2_surface.json` instead. Keep
  minimum-surface metadata aligned only if a floor increase is approved.
- **Regenerate models on every target update:** from
  `bridge/sesori_plugin_opencode/`, run the matching commands below with the
  selected release tag (replace the `X.Y` placeholders; use `--commit <sha>`
  instead of `--tag` when pinning its resolved immutable revision):

  ```bash
  # OpenCode 1.x: packages/sdk/openapi.json -> lib/src/models/openapi/
  dart run tool/generate_opencode_client.dart --tag v1.X.Y
  dart run tool/generate_sse_events.dart

  # OpenCode 2.x: packages/protocol/openapi.json -> lib/src/v2/models/openapi/
  dart run tool/generate_opencode_client.dart --tag v2.X.Y \
    --surface tool/opencode_v2_surface.json --out-dir lib/src/v2
  dart run tool/generate_sse_events.dart --manifest tool/opencode_events_v2.json \
    --out lib/src/v2/models/v2_event.g.dart
  ```

  Audit `tool/opencode_events_v1.json` or `tool/opencode_events_v2.json` against
  the selected release's emitted event shapes **before** regenerating SSE:
  these manifests are hand-curated, so rerunning the generator alone cannot
  discover upstream event changes. Update the matching surface allowlist when
  the driven API changes, review the model diff, and commit manifests/generator
  changes with their generated output in the same update PR. Record the
  release/revision and an explicit no-diff result when output is unchanged.
  A v2 target update must not overwrite v1 models with v2 schemas; regenerate
  each supported adapter only against its own protocol-compatible source.
  Run affected model/union round-trip, API and SSE tests plus the package
  analyzer. Never hand-edit generated output or treat generation alone as
  live-protocol verification.
- **Probe:** production current-host managed install, exact version, isolated
  loopback `opencode serve`, and the REST/SSE startup paths the plugin actually
  drives. Read the current runtime policy/client and use disposable database and
  profile roots. Never boot against or migrate the user's OpenCode database.
  v2 `serve` always requires auth (it generates a password when none is set),
  and reads `OPENCODE_PASSWORD` before `OPENCODE_SERVER_PASSWORD`, so strip both
  from the probe environment and pass only the one you set.
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
  Extracted-member hashes are not additional platform mappings.
- **Compatibility exception:** the manifest aliases `minPathVersion` and
  `bundledVersion` to the registry package version; the validator accepts an
  exact ACP identity/pair, not a free-standing semantic floor. Identify effects
  on previously accepted explicit/PATH pairs in the plan. Do not manufacture
  an independent minimum or silently change this exact-pin policy.
- **Assets:** Sesori selects all six ZIPs from the
  [official registry](https://github.com/agentclientprotocol/registry/blob/02b460362cfedf4d43b03df7aad6d79a353fe064/antigravity-acp/agent.json):
  macOS arm64/x64, Linux arm64/x64 and Windows arm64/x64. Independently hash official downloads and compare them
  with the registry's published per-archive `sha256` (present since 1.4.3); neither is Google's signed provenance. Preserve sibling
  `agy_acp_server.par` + `localharness_external` (Windows `.exe` counterparts),
  launch environment, Linux `--uid=`, permissions and archive limits.
- **Probe:** `--version` prints a `Build label:` among unrelated build diagnostics;
  setup consumes only the sanitized label. The 2026-09-24 native probe established
  plain semantic labels and ACP identity for package 1.2.1, replacing the earlier
  `agy_acp_server_` prefix. Do not derive an identity from the archive filename.
  Use the owning `AntigravityRuntimeVersionValidator` / runtime service's
  initialize-only ACP contract with candidate release facts and isolated state.
  Confirm exact identity, protocol, capabilities, auth-method set and process
  teardown before placement; create no session and initiate no OAuth. Linux
  extraction requires Info-ZIP `unzip` with ZipInfo support. Never substitute
  normal Google profiles.
- **Opportunities:** inspect account/model discovery, auth, history, deletion and
  subagent gaps against the current matrix. The 2026-09-12 matrix assessment found
  only generic parent-local subagent tool calls, not child identity/lifecycle or
  scoped-stop authority. Reassess on new evidence; do not infer support from
  native delegation or generic ACP features. Closed source limits remain explicit.
  Inspect model selection's client-identity gates too: the official 1.3.0–1.4.5 packages
  keep non-Gemini models only for recognized Zed/JetBrains/Android Studio/Xcode identities
  (1.4.5 adds JetBrains Air). Antigravity CLI 1.5.1+ also ships its own `agy acp`, which
  offers every account model to every ACP client; the registry package does not.
  Account entitlement alone does not prove what ACP advertises. Any explicitly
  approved compatibility identity stays inside the Antigravity plugin and must
  reach live, replay, login and validation initialization consistently; preserve
  the standard Sesori identity for other ACP harnesses. Verify this gate again
  on future releases rather than inferring it from product model documentation.

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
  `bin/codex` / `bin/codex.exe`, `codex-code-mode-host`,
  `bin/codex-exec-server[.exe]` (new in 0.167.x) and resources together.
- **Audit:** upstream `codex-rs/app-server-protocol/`, `codex-rs/app-server/`,
  schemas, processors and tests. Trace `thread/*`, `turn/*`, `item/*`, paging/
  rollout history, input/approval/auth requests, code mode, subagents, model
  discovery and experimental gates. Core/TUI/`exec --json` events are not
  automatically app-server notifications; `turn/completed` is not Pi's settled
  event. Prove ownership before replacing queue, retry, interrupt or history code.
  Check provider admission (`ModelProviderError`): since 0.166.0 a turn on a
  thread whose `modelProvider` differs from the configured one fails with
  `modelProviderMismatch`, so Sesori sends only `model` on `thread/start`.
- **Install:** use `ManagedRuntimeComposition.createInstaller()` with candidate
  manifest and asset resolver, then the production install/extract chain. The
  descriptor's installer hard-codes the current pin. Confirm the final
  `<stateDirectory>/codex/<version>/bin/codex[.exe]`, complete helpers/resources,
  and `.sesori-runtime-sha256` containing the bare candidate digest.
- **Probe both current-host transports:** isolated HOME/`CODEX_HOME` (create the
  directory first; Codex exits when `CODEX_HOME` does not exist), exact
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
- **Probe:** production current-host install, isolated `COPILOT_HOME` and
  `COPILOT_CACHE_HOME` (the loader can run a newer package cached there unless
  auto-update is off), branded `GitHub Copilot CLI X.Y.Z.` version, then
  `--no-auto-update --acp`. Require ACP
  v1 initialize and the `copilot-login` method, without prompting or reading the
  user's profile. Audit auth-state, models, session/history and subagent events
  through Copilot's own wire, not just shared ACP DTOs.
- **Verify:** manifest/descriptor and affected adapter tests plus analyzer.

## Cursor

- **Source:** read `https://cursor.com/install` as text. Extract one unambiguous
  published build used in its version directory and download URLs; do not run
  the installer. Resolve ambiguous discovery from official evidence rather than
  guessing identities or treating an old pin as the completed update.
- **Pin:** `bridge/sesori_plugin_cursor/lib/src/runtime/cursor_runtime_manifest.dart`.
  Target is the exact `YYYY.MM.DD-<build>` string. PATH comparison uses the leading
  calendar date; preserve that separate minimum and the raw bundled build value.
  The minimum is `2026.09.23`, the oldest build with evidence for the native
  sub-agent child sessions Sesori always enables (`_meta.subagents`).
- **Assets:** four self-hashed archives at
  `https://downloads.cursor.com/lab/<build>/<os>/<arch>/agent-cli-package.tar.gz`,
  for `darwin`/`linux` and `arm64`/`x64`. Cursor also publishes
  `windows/<arch>/agent-cli-package.zip`, which Sesori does not manage yet. Download/hash all
  four; no upstream checksum manifest is currently published. Preserve
  `dist-package/` and the `cursor-agent` entrypoint's siblings. The CDN answers 403
  to Python `urllib`'s default user agent; download with `curl`. Re-published bytes
  must fail the old pin rather than bypass checksum verification.
- **Probe:** production current-host package placement, exact build identity and
  the descriptor's ACP launch. Verify initialization, advertised model/mode and
  configured load/replay behavior used by the adapter. If that fixture is
  unavailable, update the target and retain load/replay/model/mode checks in
  final follow-up. Confirm download URLs resolve before consumer publication.
- **Audit:** model switching, history/load, the native `subagent_spawned` /
  `subagent_state_update` shapes and Task `rawInput`, and settings. Report
  inaccessible upstream source rather than guessing from CLI UX.

## Claude Code

- **Source:** the latest non-prerelease `anthropics/claude-code` `vX.Y.Z`, i.e.
  npm `latest`, not the npm `stable` dist-tag (2026-10 decision D1); compare
  `npm view @anthropic-ai/claude-code dist-tags`. npm can publish versions that
  have no GitHub tag (2.1.315), so require both. GitHub releases ship native
  archives with `SHASUMS256.txt` and a `.sig`, and the SDK `manifest.json` carries
  checksums; use them when hashing a probe input. Inspect the associated
  `@anthropic-ai/claude-agent-sdk` release too; do not assume permanent version
  correspondence between CLI and SDK.
- **Pin:** `bridge/sesori_plugin_claude/lib/src/runtime/claude_plugin_descriptor.dart`,
  `targetVersion` versus `minVersion`. PATH/explicit CLI only; no managed assets.
- **Probe:** isolated official current-host CLI, exact `--version`, every public
  flag in `bridge/sesori_plugin_claude/lib/src/api/claude_launch_spec.dart`, and
  matching SDK launch code for headless stream-json/stdio permission behavior.
  Fix demonstrated required-flag or semantic incompatibilities as update work;
  use the exceptional temporary-hold policy only for concrete severe harm.
  Version/help/source checks do not re-verify live streams; keep existing
  historical `Verified against` claims unless that trace is repeated.
- **Audit:** stream-json/control envelopes, tool and subagent lifecycle, replay,
  permissions, questions, models and settings. This plugin drives the CLI seam,
  not an arbitrary new SDK feature. Use approved live probes for adopted changes.

## Hermes Agent

- **Source:** stable `NousResearch/hermes-agent` GitHub release. Tags are semantic
  (`vX.Y.Z`) from v0.21.6; earlier releases used calendar tags. Tagged `pyproject.toml`
  is an inert `0.0.0`: `hermes acp --version` prints a derived version from the install
  stamp or git (`X.Y.Z`, `X.Y.Z+<n>.g<sha>` ahead of a tag, otherwise `git.<sha>` or
  `unknown`). PyPI may lag and is not the release authority.
- **Pin:** `bridge/sesori_plugin_hermes/lib/src/runtime/hermes_plugin_descriptor.dart`,
  independent `targetVersion` / `minVersion`; direct CLI, no managed artifacts.
- **Probe:** acquire exact tagged source under the permitted disposable boundary
  and install it there with Python 3.14 and `uv sync --frozen --extra acp` (core
  dependencies require Python 3.14, wheel/sdist builds are blocked outside Nix,
  and resolving without the lock fails). The install fetches about 67 PyPI
  packages, so it needs network unless a cache is seeded. Verify
  `hermes acp --version`, ACP v1 initialize, advertised list/load capabilities and
  `session/list`. A source tarball prints `unknown`; check the derived version
  from a tagged git checkout or install stamp, and do not treat
  `agentInfo.version` (an inert `0.0.0`) as a version. Do not run remote
  installers for discovery or create a forbidden checkout. Isolate HOME; a fresh
  profile can lack model/provider setup. Preserve the real CLI dispatch, not a
  direct call into `acp_adapter.entry`. Since 0.22 `hermes acp` is a viewer of a
  detached gateway daemon, so probes past initialize/list need loopback
  networking and must clean up that daemon. Use an authorized configured
  fixture for new/load coverage; missing access or inconclusive probe results go
  into final follow-up, not an old target. Separate fixture/provider-restore
  failures from demonstrated production regressions and preserve failed state.
- **Audit:** the actual Hermes ACP implementation (`acp_adapter/gateway_server.py`
  since 0.22, not only `server.py`), not only its CLI release notes: settings,
  model/provider discovery, history, tools and subagents.

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
  Check `get_commands` `sourceInfo.path` for bundled extensions: since 0.99.0
  they report `builtin:<name>` (`src/extensions/index.ts`), not `<inline:name>`,
  and the catalog's excluded-source set must match the current form.
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
  Use a disposable configured fixture for `authenticate(agent)`, list/new/load
  and persisted cleanup. Isolate `PI_CODING_AGENT_DIR` and all other profile
  roots; use an allowlist, not inherited credentials, and preserve production
  approval policy. Missing fixtures become final checks while the target moves
  forward. Current-host execution is the ordinary existing-platform scope.
  Run the deletion probe without credentials: `session/new`, a prompt of
  `/session delete`, then `session/list` from a fresh process. From `18.18.9`
  OMP leaves a new empty, untitled replacement session there (upstream
  #19068); the plugin hides entries with `_meta.messageCount` 0 and no title.
  Confirm the leftover still has that shape, and drop the filter once
  upstream stops persisting it.
  Also run the model-restore probe on a session whose saved model was removed.
  From `18.6.3` (still in the `18.19.0` source), `session/load` and `session/resume` fail
  closed with JSON-RPC `-32603` and `details: "Could not restore model
  <provider/id>"`: ACP `#openStoredSession` calls `switchSession(path)` without
  `allowSessionModelFallback` (upstream PR #13689). The owner accepted this
  limitation on 2026-10-07, so it no longer holds the pin.
  `OmpPlugin.unrestorableSessionMessage` turns it into a readable inline turn
  error; history open and resume-then-delete cleanup still fail for such
  sessions. Re-check each release: if the restore succeeds or the details
  wording changes, update that mapping and the regression row.
  A new Windows ARM64 mapping needs native install/version/ACP smoke to claim
  native verification; another host is not that proof. If a runner is missing,
  retain the approved implementation and record the native check for final
  user-assisted verification, without claiming it passed.
- **Audit:** OMP's ACP projection, not Pi RPC. Trace auth, configuration, history,
  models, tools, subagent and cancellation behavior at that seam.
- **Forms:** The shared ACP mapper supports finite array `items.anyOf` string
  choices and number/integer fields. Keep one question/encoder per property:
  checkbox selections and separate custom text retain their keys, order, required
  flags and answer slots, even for identical text. Since 18.18.3 the built-in
  `ask` tool sends HTML-field keys with `<name>_other`, and may include `number`,
  `boolean`, `required` and `default`; `qN`/`qN__other` names now come only from
  an extension's `ui.askDialog`. Do not interpret OMP's naming in the generic
  mapper or add a second wire answer shape. Live
  `OmpPlugin.supportsFormElicitation` remains enabled; `OmpAcpApi.open()` keeps
  scratch/catalog/cleanup form elicitation disabled. See
  `docs/regression/questions-and-permissions.md` for the focused live-client gate.

## DeepSeek

- **Sources:** stable adapter releases from `sesori-ai/sesori-deepseek-acp` plus
  upstream DeepSeek Harness (`deepseek-ai/deepseek-harness`, npm `@deepseek-ai/dsh-*`).
  Upstream publishes only prereleases (`dsh-vX.Y.Z-rc.N` tags); its npm `latest`
  tag is stale. **The harness target is the npm `next` dist-tag** (an RC, never an
  alpha), checked with `npm view @deepseek-ai/dsh-agent dist-tags`. Take the
  `@deepseek-ai/cordis*` versions from that RC's own dependencies.
- **Always update:** every refresh compares `next` with the producer's
  `release/config.json` `deepSeekHarnessVersion`. When `next` is newer, the refresh
  **must** migrate the adapter, release it and pin the consumer. A refresh that
  leaves DeepSeek behind upstream is incomplete. Updating only the existing adapter
  tag misses a newer upstream harness.
- **Consumer pin:** `bridge/sesori_plugin_deepseek/lib/src/runtime/deepseek_runtime_manifest.dart`.
  Keep `minimumVersion` / `minPathVersion` separate from `targetVersion`. Record
  adapter version, embedded `@deepseek-ai/*` harness pins and extension protocol
  independently. The adapter version is stable even when its embedded harness pin
  is an RC; give each harness migration a new adapter version.
- **Producer work:** work in a fresh worktree of the local
  `~/sesori-ai/sesori-deepseek-acp` clone, branched from `origin/main`. Inspect its
  `release/config.json`, package/lockfile, extension protocol, packaging workflow and
  conformance tests. Use the previous migration (PR #23, 0.2.1-rc.3) as the template:
  dsh pins, lockfile, `deepSeekHarnessVersion`, package version, runtime/session
  source, smoke script, README and fixtures. Audit the upstream
  `dsh-v<old>...dsh-v<new>` delta for APIs the adapter uses. Run `npm run check`
  and the current-host packaged smoke before opening its PR. `consumerCommit` must identify an exact pushed consumer
  conformance snapshot; preserve frozen protocol baselines unless their contract
  changes. Keep a dependent consumer PR draft or unopened until assets exist.
- **Publication:** use the producer's existing tagged release workflow, six native
  package/smoke jobs, consumer conformance, complete-set verification and publish
  gates. Verify the tag points at the merged producer commit. This private npm package is
  distributed via GitHub Releases, not `npm publish`. A runtime-refresh request
  authorizes this routine release without a human approval: merge the producer PR
  through `monitor-pr` readiness once its checks and automated reviews settle with
  every finding handled, then push tag `v<version>` on that merge commit so the
  workflow publishes. It does not
  authorize other producer changes, protocol changes or releases.
- **Assets:** six `sesori-deepseek-acp-v<version>-<platform>-<arch>` archives:
  `darwin`/`linux` arm64/x64 `.tar.gz`, `windows` arm64/x64 `.zip`, plus
  `checksums.txt`. Reconcile GitHub/list/download hashes. Preserve launchers,
  bundled Node, dependencies, protocol files and runtime assets as one package.
  Inspect `BUILD-METADATA.json` and embedded harness pins against producer facts.
- **Probe:** current-host production installation, `--version` identity including
  adapter, `deepseek-harness/<pin>` and `acp/1`, `check`, then the producer's
  packaged initialize/list/new/prompt/history/restart/load/close smoke. Distinguish
  fake-provider conformance from separately authorized authenticated feature E2E.
  Resolve unexpected protocol/harness identity drift in the producer/adapter,
  never by loosening the consumer validator. An unresolved severe incompatibility
  needs an explicit temporary-hold resolution, not permanent version divergence.
- **Plan dependencies honestly:** publish and verify all assets before pinning
  hashes; never use placeholders or temporary dual-version support solely for
  unreleased intermediate states. Ask separately if a real supported-runtime
  contract requires a floor increase. Report adapter maintenance/release effort
  even when the monorepo diff itself is only a version bump.

## Grok Build

- **Source:** xAI's official `https://x.ai/cli/stable` channel; reconcile its build
  identity with `xai-org/grok-build` source when source evidence is available
  (as of 2026-11-12 that repository stops at 1.0.45). Binaries are at
  `https://x.ai/cli/grok-<ver>-<os>-<arch>` (`.zst` and `.gz` variants) with no
  published checksums or signatures; release notes are at
  `https://x.ai/cli/changelogs/<ver>.external.md` (or `.json`). Release notes
  omit ACP-visible changes, so diff strings and field counts of the candidate
  binary against the previous target's.
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
  Authenticated new/prompt/replay/model-selection/close checks require explicitly
  authorized test credentials and endpoint scope. If unavailable, update the
  stable target and put those checks in final follow-up; do not repeatedly ask
  whether to hold Grok or obtain credentials before the update. Optional broad
  provider/model/child exploration remains separate. Source-to-binary association
  is useful evidence, not a routine signed/source-attestation requirement.
- **Audit:** Grok-owned model metadata and `session/set_model`, replay, tool/
  subagent extensions and scoped cancellation. Neither a generic ACP ACK nor
  an idle notification proves those behaviors. Preserve no-auto-update/no-leader
  launch policy. Fix demonstrated required-surface regressions as update work;
  distinguish a real severe compatibility problem from unavailable test access.
