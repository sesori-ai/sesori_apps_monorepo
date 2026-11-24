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
  minimum-surface metadata aligned only if a floor increase is approved. When the
  old and new tags have diverged (neither is an ancestor of the other), diff the
  codeload source tarballs of the two commits. Also grep the release for text
  envelopes Sesori parses out of message text (the sub-agent report,
  `packages/core/src/session/background-result.ts` and `subagent-completion.ts`):
  2.4.0 renamed `<subagent …>` to `<background-result kind="subagent" …>` with
  no schema change. A host npm `min-release-age` setting makes `npm pack` refuse
  releases only days old; pass `--before=<future date>` for the independent
  download.
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
  Always run the package tests and analyzer after regenerating: the analyzer
  excludes `**.g.dart`, so only the tests catch a compile error in regenerated
  models.
  Never hand-edit generated output or treat generation alone as
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
  (1.4.5 adds JetBrains Air; 1.5.0 adds Android Performance Analyzer and T3 Code and
  matches Zed only as the exact name `zed`; 1.5.2 is unchanged). Antigravity CLI 1.5.1+ also ships its own `agy acp`, which
  offers every account model to every ACP client; the registry package does not.
  Account entitlement alone does not prove what ACP advertises. Any explicitly
  approved compatibility identity stays inside the Antigravity plugin and must
  reach live, replay, login and validation initialization consistently; preserve
  the standard Sesori identity for other ACP harnesses. Verify this gate again
  on future releases rather than inferring it from product model documentation.
- **Quick diffs:** `strings` on the macOS server binary exposes readable embedded
  Python source (`client_info.py`, `model_selection.py`, `settings.py`,
  `telemetry.py`), so diffing it between versions is a cheap audit of the identity
  gate, settings and telemetry. Each embedded module's source starts at a line containing
  `acp_server/<module>.py"""`; splitting both `strings` dumps on that marker gives a
  per-module diff (most churn is in `server.py`). Marshalled-bytecode noise differs only
  in trailing bytes. The registry's `.protocol-matrix/latest.json` is
  independent third-party initialize evidence (Linux x64).
- **Telemetry:** 1.5.0 and 1.5.2 (`telemetry.py` and `settings.py` unchanged) send telemetry only for business (Gemini Enterprise)
  OAuth with a project; Sesori allows only `oauth-personal`, and the parsed
  `telemetry.*` settings block is unused. Recheck both on each bump.

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
  Check provider admission (`ModelProviderError`): on 0.166.0 to 0.167.x a turn
  on a thread whose `modelProvider` differs from the configured one fails with
  `modelProviderMismatch`, so Sesori sends only `model` on `thread/start`. From
  0.168.0 a thread keeps its saved provider while that provider is still
  defined; only `modelProviderNotConfigured` and `modelProviderPolicyConflict`
  remain on resume.
  Side questions use the experimental `thread/sample` with `allowInProgressTurn`,
  so every refresh runs a live side-question probe over WebSocket with a local
  test provider (mid-turn, idle, a follow-up with history in the prompt, and the
  rollout byte-identical afterwards). Recheck the error texts the plugin maps:
  `` unknown variant `thread/sample` `` (before 0.164.0), `sample source must be
  idle` (0.164.0 to 0.168.x ignore `allowInProgressTurn`; mid-turn needs
  0.169.0), and `is not materialized yet` from `thread/turns/list`.
- **Install:** use `ManagedRuntimeComposition.createInstaller()` with candidate
  manifest and asset resolver, then the production install/extract chain. The
  descriptor's installer hard-codes the current pin. Confirm the final
  `<stateDirectory>/codex/<version>/bin/codex[.exe]`, complete helpers/resources,
  and `.sesori-runtime-sha256` containing the bare candidate digest. The
  installer checks the `PATH` of the process running it, not the environment
  passed to the child, so a host `codex` on `PATH` blocks the managed install.
  Start the probe with a system-only `PATH` and an absolute Dart path (the asdf
  shim fails under it).
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
  Releases also publish `copilot-linuxmusl-*` archives, which Sesori does not
  manage. The platform binary's embedded JS is compressed, so string diffs
  between versions do not work. For the audit, diff the digest-checked
  `github-copilot-X.Y.Z-<os>-<arch>.tgz` release assets instead: they hold
  readable `cli-main.js`, `changelog.json` and `copilot-sdk/generated/*.d.ts`
  (verified on 1.0.112 to 1.0.115). The ACP server itself lives in the native
  `prebuilds/<os>-<arch>/runtime.node`, not in `cli-main.js`. From 1.0.115 its
  ACP method names are no longer literal strings, so check the method surface
  with the network-denied, unauthenticated probe instead: bogus-session calls
  answer "not found" for implemented methods and `-32601` for absent ones.
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
- **Assets:** four archives at
  `https://downloads.cursor.com/lab/<build>/<os>/<arch>/agent-cli-package.tar.gz`,
  for `darwin`/`linux` and `arm64`/`x64`. Cursor also publishes
  `windows/<arch>/agent-cli-package.zip`, which Sesori does not manage yet. Download/hash all
  four and compare each with the same-host `<archive URL>.sha256` file
  (`<hex>  agent-cli-package.tar.gz`; present since at least `2026.11.11-b912975`,
  verified 2026-11-19, and checked by the CLI's own updater from `2026.11.19-f005e9d`).
  It is same-CDN integrity, not a signed manifest. Preserve
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
  inaccessible upstream source rather than guessing from CLI UX. String-diffing
  the downloaded `dist-package/*.js` bundles of the two builds is a cheap check
  for added or removed ACP methods.

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
  Anthropic-format probes against the local test proxy use the proxy root as
  the base URL (the CLI appends `/v1/messages`). Rewinding behind a compaction
  (`--resume-session-at` a pre-compaction uuid) still fails on 2.1.325 with
  "No message found with message.uuid", so Sesori's refusal stays; recheck on
  each bump.
- **Audit:** stream-json/control envelopes, tool and subagent lifecycle, replay,
  permissions, questions, models and settings. This plugin drives the CLI seam,
  not an arbitrary new SDK feature. Use approved live probes for adopted changes.
  A quick offline seam diff: run `strings` on the old and new native binaries,
  confirm every string literal in the plugin's `lib/` found in the old one is
  still in the new one, and diff the `subtype:<fn>("<name>")` literal sets for
  new or removed control requests and system messages.
  The `side_question` control request is undocumented, so every refresh runs a
  live side-question probe (mid-turn, and after a cold `--resume`). It checks
  that the session `.jsonl` gains no question or answer record (a cold resume
  may append a `cost-state` accounting record) and the
  `{response, synthetic, refusal_fallback}` reply shape.

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
  Re-check the no-model copy Sesori matches (`auth-guidance.ts`, the
  `--list-models` output and the non-interactive no-model exit in `main.ts`).
  A logged-out RPC process does not exit: it starts on a placeholder
  `unknown/unknown` model (verified 1.5.2 and 1.6.0), and from 1.6.0 also writes
  the startup diagnostics, including `Warning: No models available…`, to stderr.
  From 1.6.0 RPC subscribes before `bindExtensions`, so events emitted by
  `session_start` handlers (such as `entry_appended`) reach the client at
  startup; the stdin reader still attaches only after that.
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
  The plugin's Dart package name is `pi_plugin`, not its directory name. A
  probe-owned `HostProcessService` that wraps children (for example in
  `sandbox-exec`) must resolve bare names against its allowlisted `PATH` and
  throw `ProcessException` when absent; otherwise the installer's PATH
  authority sees a runtime and refuses with "The global Pi runtime now takes
  precedence".

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
  roots, including `OMP_DAEMON_DIR`: from `19.0.0` one per-user daemon lives
  under `~/.omp/run/daemon` whatever the profile, so a probe that isolates only
  the agent directory can reach the user's live daemon. Use an allowlist, not
  inherited credentials, and preserve production approval policy. Run the
  probe's own `dart` with the restricted `PATH` too: `Process.start` resolves a
  bare `omp` through the parent's `PATH`, so a user install otherwise wins and
  the installer stops at "The global Oh My Pi runtime now takes precedence".
  Missing fixtures become final checks while the target moves
  forward. Current-host execution is the ordinary existing-platform scope.
  Run the deletion probe without credentials: `session/new`, a prompt of
  `/session delete`, then `session/list` from a fresh process. From `18.18.9`
  until `18.20.1` (the fix landed there, not in `18.20.0` as the changelog says)
  the raw list holds a new empty, untitled replacement session (upstream
  #19068). `session/new` alone still writes an empty untitled session file
  (`19.1.0`), so the plugin's listing filter stays. Launch these probes as the
  live plugin does, without `--session-dir`: ACP `session/list` and
  `session/load` read only the default session directory under
  `PI_CODING_AGENT_DIR`, so with the flag nothing is ever listed. Launched that
  way, `session/list` returns the new file with `_meta.messageCount` 0 and no
  title without credentials (`19.0.1` and `19.1.0`, same or fresh process).
  Confirm both shapes on each bump.
  Also run the model-restore probe on a session whose saved model was removed.
  It needs no credentials: after `session/new`, append a `model_change` entry
  naming a removed model (`google-gemini-cli/gemini-2.5-pro`; that provider was
  removed in `19.1.0`) and a user `message` entry to the session's JSONL file,
  then call `session/load` and `session/resume` from a fresh process.
  From `18.6.3` (still in the `19.1.0` source), `session/load` and `session/resume` fail
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
- **Busy window:** from 18.20.1 `session/prompt` stays open while a background
  bash job or live sub-agent can resume it (job end plus a short follow-up
  turn, no updates in between). On each bump, start a background job and probe
  `_session/steering`, `session/cancel` and the history read inside that
  window; record the results in `docs/HARNESS_CAPABILITIES.md`.
- **Forms:** The shared ACP mapper supports finite array `items.anyOf` string
  choices and number/integer fields. Keep one question/encoder per property:
  checkbox selections and separate custom text retain their keys, order, required
  flags and answer slots, even for identical text. Since 18.18.3 the built-in
  `ask` tool sends HTML-field keys, and may include `number`, `boolean`,
  `required` and `default`; the "other" field is `<name>__other` from 18.20.0
  (`12c017d1`) and `<name>_other` only in 18.18.3–18.19.0. `qN`/`qN__other`
  names come from an extension's `ui.askDialog`; from 19.0.0 the `ask` tool
  also rebuilds a model's legacy `questions` list as a form named by each
  question's `id` or `qN` (no "other" field). 19.1.0's "RPC hosts must handle
  the `ask` tool as one complete HTML-form request" note is about RPC mode only;
  ACP already rendered the whole form through `formDialog`, and the ACP bridge
  and `html-form` parser did not change. Do not interpret OMP's naming in the generic
  mapper or add a second wire answer shape. Live
  `OmpPlugin.supportsFormElicitation` remains enabled; `OmpAcpApi.open()` keeps
  scratch/catalog/cleanup form elicitation disabled. See
  `docs/regression/questions-and-permissions.md` for the focused live-client gate.
- **Compaction:** `OmpEventMapper` maps the `_omp/compaction/start` and
  `_omp/compaction/end` extension notifications (sent by OMP's
  `#handleLifetimeEvent` in `packages/coding-agent/src/modes/acp/acp-agent.ts`,
  automatic compaction only) to the shared compaction row. Each release, re-check
  the end payload fields (`aborted`, `skipped`, `errorMessage`, `willRetry`,
  `tokensBefore`): `willRetry` means OMP re-sends the overflowed turn after a
  successful compaction, so it is ignored, and a failed method's fallback is a new
  start/end pair. If OMP starts signalling manual `/compact` or carries a summary,
  freed count or attempt id, extend the mapping and the capability row. From
  19.0.0 `/handoff` is `/compact handoff` (still inline over ACP, which sets no
  `runCommandInBackground`), and the cache warmer's default `auto` strategy can
  commit a bridge compaction mid-turn during a long tool call, through the same
  automatic start/end pair.
- **Tool titles:** ACP tool titles prefer the model's intent field. From 19.0.0
  intent tracing is off by default outside the interactive TUI, so titles fall
  back to `<tool>: <subject>`. `OmpBinary.launchSpec` sets `PI_INTENT_TRACING=1`,
  which outranks every settings file (17.2.13 and 18.x read the same variable).
  Live on 19.0.0: a read is titled `read: notes.txt` without it and by its intent
  with it. From 19.1.0 the title is only the label before the intent's first
  `: ` (`toolIntentLabel`). Re-check the variable name and precedence on each bump.
- **Shared helper:** OMP spawns its daemon (`__omp_worker_daemon`, 19.0.0) or,
  in 18.x, its per-project broker (`__omp_worker_daemon_broker`) and the
  machine-wide tiny ONNX and mnemopi workers (`__omp_worker_tiny_inference`,
  `__omp_worker_mnemopi_embed_server`; 19.0.0 runs them under the daemon)
  detached. The bridge's stop skips them by those arguments on POSIX and
  Windows (`OmpBinary.sharedHelperArguments`). On each bump, grep the source for
  detached spawns (`spawnDetached`, `detached: true`) that ACP mode reaches,
  and confirm each helper's argument and idle exit (19.0.0 daemon: 3 s after
  nothing is connected and no persistent unit runs). Live probe: let Sesori's
  `omp acp` start a named service, join from a second `omp acp` that starts
  another, stop Sesori's process mid tool call, and check with `ps` that the
  helper and both services remain; `omp ps stop <name>` then lets the helper
  exit. A model that always sends `timeout` needs `ready` (for example
  `ready.log`) on a named call, or OMP rejects it.
  From 19.1.0 the daemon can also host MCP servers (`mcp.shared`); ACP sessions
  run with `enableMCP: false` and keep client-declared servers in the `omp acp`
  process. Re-check that on each bump: point `session/new` `mcpServers` at a
  loopback HTTP fixture and see which process connects (`lsof`). OMP first sends
  `server/discover`; Sesori's `-32601` answer selects the handshake era.

## DeepSeek

- **Sources:** stable adapter releases from `sesori-ai/sesori-deepseek-acp` plus
  upstream DeepSeek Harness (`deepseek-ai/deepseek-harness`, npm `@deepseek-ai/dsh-*`).
  Upstream publishes only prereleases (`dsh-vX.Y.Z-rc.N` tags); its npm `latest`
  tag is stale. **The harness target is the npm `next` dist-tag** (an RC, never an
  alpha), checked with `npm view @deepseek-ai/dsh-agent dist-tags`. Take the
  `@deepseek-ai/cordis*` versions from that RC's own dependencies. Upstream can
  publish the `next` RC to npm hours before pushing its `dsh-v` tag, and the npm
  manifests carry no `gitHead` (rc.4, 2026-11-17). Then audit by diffing the old
  and new published tarballs, and recheck the tag before the consumer pin.
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
  conformance tests. Use the previous migration (PR #26, adapter v0.2.4 over dsh 0.2.2-rc.4) as the template:
  dsh pins, lockfile, `deepSeekHarnessVersion`, package version, runtime/session
  source, smoke script, README and fixtures. After bumping the exact dsh pins,
  `npm install` fails with ERESOLVE because the old dsh packages pin each other
  exactly: delete only the `@deepseek-ai/dsh-*` entries from `package-lock.json`,
  remove `node_modules`, then run `npm install` and confirm the third-party tree
  is unchanged. The npm `min-release-age=2` gate needs an override only while
  the RC is under two days old; record whether one was used. Audit the upstream
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
  Release packaging unpacks the official Node zip with `tar -xf`;
  `Expand-Archive` broke on the `windows-11-arm` runner image when Windows
  PowerShell loaded PowerShell 7's Archive module, so do not reintroduce it.
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
  published checksums or signatures; the installer's tokens are `macos`/`linux`/
  `windows` and `aarch64`/`x86_64` (so `grok-<ver>-macos-aarch64.gz`, not
  `darwin-arm64`); release notes are at
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
