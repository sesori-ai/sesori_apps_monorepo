# GitHub Copilot Harness

## Status

- **Plan slug:** `github-copilot-harness`
- **Status:** active; Steps 1-5/7 merged (#1154, #1155, #1158, #1159, #1161), Step 6/7 implemented and verified locally
- **Plan date:** 2026-08-27
- **Implementation base:** current `origin/main`
- **Delivery:** seven PRs with the fixed titles below

## Goal

Add GitHub Copilot CLI as a first-class Sesori harness through its native ACP v1
stdio server. A configured Copilot installation should appear alongside the
other harnesses, import and resume persisted Copilot ACP sessions, create and
continue sessions, stream turns and tools, handle standard permissions, expose
standard session options and commands, accept supported images, and remain
isolated when its runtime or authentication fails.

The first release keeps authentication out of band: users authenticate on the
bridge machine with `copilot login`, a supported GitHub token environment
variable, or Copilot BYOK configuration. Sesori does not read or persist Copilot
credentials and does not initiate an interactive login flow from the phone.

## Authoritative Upstream Facts

Reviewed against stable GitHub Copilot CLI `1.0.80` and the official ACP server
documentation on 2026-08-27:

- `copilot --acp` starts an ACP v1 server; stdio is the default transport.
- A local no-prompt protocol probe completed `initialize`, `authenticate`,
  `session/list`, `session/new`, and `session/close` successfully. Initialize
  advertised `loadSession`, session list/close, images, and embedded context.
  Session creation emitted standard `config_option_update` and
  `available_commands_update` notifications.
- Authentication is inherited from a prior `copilot login`,
  `COPILOT_GITHUB_TOKEN`, `GH_TOKEN`, `GITHUB_TOKEN`, or configured BYOK
  provider. ACP advertises `copilot-login` with terminal-auth metadata; Sesori's
  headless runtime may call standard `authenticate` but must never execute the
  advertised terminal login command automatically.
- Copilot `1.0.78` added ACP `session/close`; it is the minimum PATH version for
  this integration. Managed installation pins the validated stable `1.0.80`.
- Copilot supports standard ACP permission requests, model/session config
  updates, modes, plans, commands, custom agents, session loading, and images.
  Exact entitled-account model and reasoning catalogs remain a live-verification
  item because the isolated no-prompt probe exposed mode and permission options
  but no model catalog.
- Copilot does not yet forward its `ask_user` interaction to ACP clients
  (github/copilot-cli#2109). Sesori therefore does not advertise or claim form
  elicitation for this harness.
- `session/close` releases a live ACP session; it is not treated as upstream
  persisted-session deletion. Sesori deletion owns its local purge and
  plugin-scoped tombstone and does not mutate Copilot's private storage.
- `--no-auto-update` is available. Sesori launches both PATH and managed
  runtimes with it so a bridge-owned ACP process cannot mutate its executable
  or drift from the version that setup selected.
- Stable `1.0.80` publishes six official single-binary archives with GitHub
  release SHA-256 digests:

| Host | Asset | SHA-256 |
|---|---|---|
| macOS arm64 | `copilot-darwin-arm64.tar.gz` | `2346bb691981c2997d65c1c5bc3cef1aeddc9edd37dcb2f970b911aa597e59f6` |
| macOS x64 | `copilot-darwin-x64.tar.gz` | `a1a9c1f25740f9a27b34eb14b70b5d3175794dc8bb410875531aa198b3abc18f` |
| Linux arm64 | `copilot-linux-arm64.tar.gz` | `3ed85e711955e13be523bf492bc6c93b40b69925bcb7f817c9d08abf4839cf89` |
| Linux x64 | `copilot-linux-x64.tar.gz` | `039933c9247686131c4406abb1d439bdbf68103edc1ff585bd70d5b0dc940f72` |
| Windows arm64 | `copilot-win32-arm64.zip` | `c551da2377b99f08ff95cca6c1603c0006295c2ca7786ba1c8be7c05dc7943a7` |
| Windows x64 | `copilot-win32-x64.zip` | `e9ea2063913faa8a9f1cf374529c5fea075da0545a894d7469026166f854c541` |

Sources:

- <https://docs.github.com/en/copilot/reference/copilot-cli-reference/acp-server>
- <https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli>
- <https://github.com/github/copilot-cli/releases/tag/v1.0.80>
- <https://github.com/github/copilot-cli/blob/main/LICENSE.md>
- <https://github.com/github/copilot-cli/issues/2109>

## Architecture And Scope

```text
client <-> relay <-> bridge <-> sesori_plugin_copilot <-> copilot --no-auto-update --acp
```

- `sesori_plugin_copilot` owns Copilot identity, executable arguments, version
  policy, setup classification, managed-runtime metadata, and any demonstrated
  Copilot-specific ACP policy.
- `sesori_plugin_acp` remains the owner of standard ACP transport, session
  enumeration/load/replay, prompts, events, config options, commands,
  permissions, and process lifecycle. The Copilot descriptor constructs its
  plugin with `hostProcessAcpFactory` and delegates startup/shutdown to
  `AcpBridgePlugin.start`; it does not introduce a Copilot-local transport or
  lifecycle wrapper. The new harness should require no generic ACP production
  change unless a pinned-binary conformance test demonstrates a real protocol
  mismatch.
- The bridge app knows the concrete plugin only at
  `bridge/app/lib/src/runtime/plugin_registry.dart` and its package dependency.
- The client continues consuming backend-neutral plugin contracts. Shared wire
  plugin ids remain strings; `Harness.copilot` is only the built-in identity
  used for exact registry tests and client-owned presentation.
- Copilot uses `PluginProjectOwnership.bridgeDerived` and
  `PluginSessionOptionsScope.plugin`. The bridge derives projects from session
  directories and persists its own catalog/transcript state.
- Runtime precedence is an explicit `--copilot-bin`, then a compatible PATH
  runtime (`>=1.0.78`), then the exact already-installed managed `1.0.80`.
  `ensureRuntime` only resolves existing files. `installRuntime`, invoked by an
  explicit management command, downloads the official release archive directly
  from GitHub, verifies its immutable digest, extracts the single binary, and
  sweeps superseded managed versions.
- Managed Copilot bits are not bundled in Sesori artifacts. Installation is an
  explicit upstream download of the unmodified binary. The implementation and
  product documentation retain the upstream license link and do not claim any
  GitHub service entitlement.
- Runtime authentication remains the authority. Side-effect-free setup can
  prove a compatible executable but cannot honestly infer every credential
  source without starting ACP or reading private credential stores; it reports
  the runtime ready, while an authentication failure during eager ACP handshake
  becomes a plugin-local authentication-required/degraded state with local
  `copilot login` guidance.
- The stock ACP approval registry handles standard permission requests.
  Copilot's missing ACP `ask_user` forwarding remains a documented limitation;
  no custom question protocol or polling workaround is added.

### Compatibility

- No client/bridge wire shape or database schema changes.
- Older clients connected to a Copilot-capable bridge retain the raw plugin id,
  bridge-provided display name, and generic icon fallback.
- Newer clients connected to an older bridge receive no Copilot entry.
- Copilot CLI releases below `1.0.78` are setup-blocked rather than receiving a
  compatibility shim for missing close and older ACP behavior.
- Public production wire compatibility remains unchanged because plugin ids are
  already opaque strings.

### Complexity Budget And Cleanup

- **New persistent mutable state:** none beyond the existing managed-runtime
  directory and existing bridge catalog/tombstone rows used by every plugin.
- **New in-memory mutable state:** none beyond one existing `AcpPlugin` instance
  and its existing trackers.
- **New coordination:** none; no locks, registries, timers, queues, credential
  stores, storage readers, or Copilot-specific session maps.
- **Deliberately omitted:** Copilot SDK shim, phone-initiated login, private
  credential/session-file parsing, custom tool injection, `ask_user` emulation,
  auto-update support, and speculative ACP extensions.
- **Analytics:** existing backend-neutral harness-install outcome analytics
  already cover the new managed install. No new event or plugin identifier is
  sent.
- **Cleanup assessment:** no existing production field, route, cache, watcher,
  or compatibility path becomes obsolete. The implementation adds no causal
  cleanup outside its own package and registry/branding entries.

## Delivery Steps

| Step | Fixed PR title | Scope and expected result |
|---|---|---|
| 1/7 | `🌱 [github-copilot-harness] docs: plan GitHub Copilot harness support [step 1/7]` | Add this reviewed plan and tracker. No user-visible or database change. |
| 2/7 | `⚙️ [github-copilot-harness] feat(copilot): add the ACP harness package [step 2/7]` | Add the workspace package, stable identity, `--no-auto-update --acp` launch spec, stock-ACP plugin composition, and focused protocol/factory tests. The package is not registered yet; no user-visible or database change. |
| 3/7 | `⚙️ [github-copilot-harness] feat(copilot): add runtime setup and lifecycle [step 3/7]` | In `bridge/sesori_plugin_copilot`, add the descriptor, semantic version parsing (`GitHub Copilot CLI X.Y.Z.` included), explicit/PATH runtime selection, setup statuses, authentication guidance, and descriptor tests. Complete the merged-package review follow-ups by adding the package to the bridge verification module list and mapping Copilot's standard model, mode, and thought-level options through an isolated discovery process plus `session/set_config_option`; Copilot's permission config remains backend-private. The descriptor composes `hostProcessAcpFactory` and `AcpBridgePlugin.start`; `sesori_plugin_acp` remains the sole owner of ACP stdio startup/shutdown. The plugin remains unregistered; no user-visible or database change. |
| 4/7 | `⚙️ [github-copilot-harness] feat(copilot): install the managed Copilot CLI [step 4/7]` | Add the exact `1.0.80` six-platform manifest, direct official downloads, digest verification, install capability gating, cleanup, and manifest/install tests. No database change; still no user-visible harness until registration. |
| 5/7 | `⚙️ [github-copilot-harness] feat(app): activate and brand GitHub Copilot [step 5/7]` | `bridge/app` adds the package dependency, registry entry, and exact registry fixtures; `shared/sesori_shared` adds only `Harness.copilot`; `client/module_prego` adds only Copilot display-name/artwork presentation and fallback-preserving tests. Root product documentation adds the support listing. No other client/shared package changes. Users can select, install, start, and use Copilot; no database migration. |
| 6/7 | `🌱 [github-copilot-harness] docs: document Copilot regression coverage [step 6/7]` | Reconcile the affected feature documents under `docs/regression/`, including upstream limitations and exact boundaries/matrix. Documentation only. |
| 7/7 | `🌱 [github-copilot-harness] docs: verify and retire the Copilot plan [step 7/7]` | Run and record the matrix below, keep any incomplete row honestly Partial/Blocked, and move the plan to `.plan/completed/github-copilot-harness/` only when all required coverage passes or the owner explicitly accepts a reduction. Documentation only. |

No implementation PR is expected to exceed the 1,500 changed-line soft cap.
If focused tests make a step materially exceed it, split within the same fixed
step only after updating the tracker and preserving one independently valid PR
per published step number; do not merge unrelated cleanup into the series.

## Regression And Retirement Matrix

Highest required level is **L3 Release** for the new selectable production
harness, plus the named L4 authentication/restart/recovery checks. Unchanged
plugins retain existing evidence, while every registered-plugin registry and
branding check includes Copilot.

| Feature document | Required Copilot evidence | Boundary and matrix |
|---|---|---|
| `plugin-runtime-installation.md` | Explicit/PATH/managed precedence; too-old and malformed versions; exact six-asset metadata; digest failure; install cancellation; superseded cleanup | Automated all six targets + packaged/live install on release-target bridge host |
| `plugin-setup-and-lifecycle.md` | Missing/old/current/explicit runtime; install capability gating; configured start; local-login-required failure; enable/disable/restart; plugin-local crash/reconnect; clean shutdown | Automated + headless bridge + live plugin; release-target host and one alternate host when available |
| `projects-and-sessions.md` | Explicit Copilot import; database-only normal reads; healthy pagination exhaustion; cancellation/first-page failure preserve the catalog; later-page failure commits gathered pages non-destructively | Headless bridge + live plugin |
| `session-creation-and-options.md` | Create with standard mode/model/reasoning/agent options actually advertised to the entitled account; stable Copilot identity; unsupported options are not invented | Client E2E + live plugin |
| `session-turns.md` | Text, reasoning when emitted, tools, statuses, exact commands, queued follow-up cancellation, abort, and two independent sessions; ACP plan updates are not client-visible | Client E2E + live plugin |
| `session-history-and-recovery.md` | Standard load replay, bridge transcript backfill, plugin restart, bridge restart, and process replacement converge without duplicate live replay | Headless bridge + live plugin |
| `questions-and-permissions.md` | Once/Reject UI, Always when advertised, exact selected-or-cancelled ACP outcome, abort cleanup, and no claimed `ask_user` support | Client E2E + live plugin |
| `attachments-and-images.md` | Advertised image reaches a vision-capable selected model; model/account rejection remains visible | Client E2E + live plugin |
| `tools-and-file-changes.md` | Live permission linkage plus tool lifecycle, diffs, and bounded output converging after replay; permission decisions themselves do not replay | Client E2E + live plugin |
| `session-archiving-and-deletion.md` | Local purge plus tombstone prevents re-import while retained upstream Copilot persistence is documented | Headless bridge + live plugin |
| Compatibility and branding | Unknown-id fallback remains intact; older client contract tolerates `copilot`; older bridge supplies no entry; exact built-in artwork/name render in both themes | Automated + client E2E for presentation claim |

Step 7 records Copilot version, bridge/app build, bridge host, client platform,
account type without identifiers, chosen model/mode, privacy-safe evidence,
cleanup, and Pass/Partial/Fail/Blocked for each row. Prompts, transcripts, paths,
tokens, session ids, account ids, and raw logs stay out of the repository.

## Risks And Test Focus

- **ACP preview drift:** pin and probe a validated release; protocol v1 alone is
  insufficient if behavior changes. Fail setup for unsupported versions.
- **Authentication:** terminal-auth metadata is guidance, not permission to run
  login. Verify prior CLI login, environment token/BYOK where available, and a
  genuinely unauthenticated home separately.
- **Supply chain:** install only official immutable release assets, verify the
  exact per-platform digest before extraction, disable runtime self-update, and
  keep explicit paths authoritative.
- **Catalog truth:** verify model/reasoning/custom-agent options with an entitled
  account. Do not synthesize choices that the ACP server did not advertise.
- **Permissions:** standard ACP permission requests must correlate with tool
  calls. Do not treat process-wide launch flags as per-session authorization.
- **Questions:** Copilot's current missing ACP `ask_user` forwarding is a product
  limitation, not a reason to add a custom protocol.
- **Deletion:** close is not private-storage deletion. Verify Sesori's tombstone
  prevents a later explicit import from resurrecting a locally deleted row.
- **Privacy:** never commit credentials, account details, paths, prompts,
  transcripts, tool payloads, or raw Copilot output.

## Expected Result

A supported GitHub Copilot CLI appears as `GitHub Copilot` in Sesori, can be
installed from the harness management surface or resolved from a compatible
local installation, and runs through the existing encrypted client/relay/bridge
path. Standard Copilot ACP sessions can be imported, created, resumed, streamed,
approved, and closed without backend concepts escaping the plugin. Missing or
old runtimes and authentication failures affect only Copilot and present local,
privacy-safe recovery guidance. No database migration or wire-contract change
is introduced.
