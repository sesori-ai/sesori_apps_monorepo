# Antigravity ACP Harness Support

## Status

- **Plan slug:** `antigravity-harness`
- **Status:** active; Step 1 architecture review findings applied, validation in progress
- **Plan date:** 2026-09-03
- **Implementation base:** `origin/main` at `a87f30ab98b07dd7262afba462a36d4fbcc2dd9a`
- **Delivery:** twelve ordered PRs with fixed titles below
- **Delivery order:** user-supplied official runtime pair first; pinned managed installation follows after local
  support is live

## Goal

Add Google's Antigravity ACP agent as a first-class Sesori harness. A user who supplies the official runtime pair should
be able to authenticate a private Antigravity profile, create and continue sessions, select an account-advertised model,
stream text/reasoning/tools, answer questions and permissions from Sesori, load history, abort work, and recover after
plugin or bridge restart. A later PR in the same series adds an explicit, checksummed managed install of the official
Google archives.

This plan integrates the **official proprietary Antigravity ACP agent** published through the Agent Client Protocol
registry. It does not wrap the interactive `agy` CLI and does not use a community compatibility server.

## Authoritative Upstream Facts

Research baseline:

- ACP registry manifest: `agentclientprotocol/registry`, `antigravity-acp/agent.json` at commit
  `536e378b70a7a6d5f078a9160180e3569a23253c` on 2026-09-03.
- Registry package version: `1.0.0`; runtime identity/version reported by the reviewed release:
  `antigravity-acp` / `agy_acp_server_20260818_01_RC01`.
- Official product and policy documentation:
  - <https://antigravity.google/docs/ide/extensions>
  - <https://antigravity.google/docs/cli/headless/>
  - <https://antigravity.google/docs/cli/permissions/>
  - <https://antigravity.google/docs/cli/sandbox/>
  - <https://antigravity.google/terms>
- Independent implementation evidence: `pingdotgg/t3code` Antigravity PR #9348 at commit
  `fff33f9e851912363c5b1f3ac65598be35eb5f0d`. T3 is corroborating evidence, not a dependency or artifact source.

Facts established from the registry and reviewed released-agent integration:

- Google publishes a proprietary two-file runtime, not an `agy --acp` command:
  - macOS/Linux: `agy_acp_server.par` plus sibling `localharness_external`;
  - Windows: `agy_acp_server.exe` plus sibling `localharness_external.exe`.
- The registry publishes five targets: macOS arm64, Linux x64, Linux arm64, Windows x64, and Windows arm64. It does not
  publish macOS x64. Linux alone requires the literal launch argument `--uid=`.
- The ACP server requires `ANTIGRAVITY_HARNESS_PATH` to point at the matching sibling harness. Selecting or updating one
  executable without the other is not a valid runtime.
- The official release negotiates ACP v1, identifies as `antigravity-acp`, advertises `session/load`, `session/list`,
  `session/resume`, and auth logout, but does not advertise `session/close`. It advertises four auth method IDs. Initial
  Sesori support deliberately selects only `oauth-personal`; it never falls through to another method.
- The personal OAuth method prints one non-JSON stdout line beginning exactly with
  `Open the following link to authenticate the ACP server: `. The URL is an HTTPS Google authorization URL whose
  redirect target is an agent-owned `http://127.0.0.1:<port>/` listener. That line must be removed before NDJSON
  decoding.
- A browser on the bridge host can reach the loopback callback directly. A phone or remote desktop cannot; after Google
  redirects to its own unreachable loopback, the final redirect URL must be sent back over Sesori so the bridge host
  can deliver it to the exact listener that issued the challenge.
- Setting `GEMINI_HOME` and `AGY_ACP_FORCE_FILE_STORAGE=1` gives the agent an isolated file-backed profile. The reviewed
  release stores its token and ACP conversations below `<GEMINI_HOME>/antigravity-acp/`; conversation `.meta` files
  contain the session `cwd`.
- Model selection is a standard ACP session config option with id `model`; option values are opaque account-scoped IDs.
  The agent's permission modes are `default`, `auto_edit`, and `yolo`. Sesori will explicitly apply only `default`.
- Some `session/request_permission` calls whose `toolCallId` begins with `interaction_` are actually single-choice user
  questions. Their exact `optionId` must be returned. Ordinary permissions offer `allow_once`, `allow_always`, and
  `reject_once`; `allow_always` may carry `agy.security.warning` prompt-injection metadata.
- Tool output can use Antigravity-specific `formatted_output`, `exit_code`, `command_line`, and `working_dir` keys, and
  generated-image results can include a local image path plus an inline image. These require bounded normalization
  before the existing ACP live and replay mappers consume them.
- The ordinary `agy -p` headless CLI cannot ask for interactive permission and its
  `--dangerously-skip-permissions` flag bypasses every approval. Neither path is used here.

The local Step 2 preflight downloaded the pinned macOS arm64 archive directly on 2026-09-03. Its 314,500,221 bytes and
SHA-256 `f122ca7e7030a27f9649da4cf1a7d80e12c48c5f6118ff35affc34d56cbf83dd` match independent evidence; it contains
only the 792,105,680-byte server and 101,551,680-byte harness. An isolated initialize-only run confirmed the identity,
version, capability presence/absence, and four auth IDs above without authentication or account data. Step 2 commits
that privacy-safe result as a contract fixture. The released binary wins over T3 or documentation when they differ.

## Current Repository Behavior And Evidence

- `bridge/sesori_plugin_acp/` already owns ACP v1 stdio, process recovery, session create/list/load/resume/close,
  prompt streaming, cancellation, config-option writes, replay suppression, content bounds, standard permissions,
  elicitation, slash commands, and bridge-derived projects.
- `AcpPlugin` has concrete harness hooks for initialize validation/capture, approval registries, session options,
  pre-turn selection, process-reset state, and prompt behavior. It lacks only narrow seams needed here: initialize
  without automatic authentication, backend update normalization shared by live/replay, and externally discovered
  session-directory registration.
- `AcpApprovalRegistry.addPendingQuestion` is sufficient for Antigravity's `interaction_` request once a subclass
  classifies it. Normal permissions can be passed to the base registry after removing the unsafe `allow_always` choice.
- `bridge/sesori_plugin_interface/lib/src/lifecycle/plugin_authentication.dart` and the bridge/client management flow
  support only device-code challenges. They have start/cancel but no browser authorization challenge or redirect
  continuation.
- `bridge/sesori_plugin_runtime/` already downloads, SHA-256 verifies, extracts, places, activates, and cleans
  single-binary or package-directory runtimes. Antigravity can use the package-directory layout, but version probing
  must initialize ACP because this runtime has no supported standalone CLI version command.
- `bridge/app/lib/src/runtime/plugin_registry.dart` has no Antigravity descriptor. The shared `Harness` enum does not
  need an Antigravity case because transport and registry composition already carry opaque plugin ID strings.
- `client/module_prego/.../prego_brand_logo.dart` maps only legacy known IDs to names/artwork. Current and older clients
  can therefore continue to show Antigravity through the existing generic harness row.
- There is no Antigravity package, runtime state, credential copy, database schema, route, or compatibility obligation
  from a public Sesori release.

## Locked Product Decisions

- Plugin-owned ID is `AntigravityIdentity.pluginId == "antigravity"`; display name is `Antigravity`. Bridge composition
  registers that opaque string. Upstream ACP identity remains `antigravity-acp`; no shared `Harness` case is added.
- Use only the official Google pair from the ACP registry. Explicit `--antigravity-bin <path>` points at
  `agy_acp_server.par`/`.exe`; the matching `localharness_external` sibling is mandatory. Without an explicit path,
  resolve that official pair on PATH first, then an already-installed managed pair.
- Local/manual runtime support activates in Step 8. Managed installation is intentionally later, in Step 9, matching
  the user's requested delivery order.
- Pin registry package `1.0.0` and runtime `agy_acp_server_20260818_01_RC01`. Because no compatibility range is
  published, both local and managed pairs must pass the exact ACP identity/version/capability probe. A future release
  is a deliberate pin update, not an assumed compatible version.
- Initial authentication supports personal Google OAuth (`oauth-personal`) only. Enterprise OAuth, Gemini API key, and
  Agent Platform are honest capability gaps until Sesori has a secure configuration surface and an external-service
  matrix for them. Never silently select one of those methods.
- Every Antigravity process uses one Sesori-owned, plugin-isolated `GEMINI_HOME` below `PluginHost.stateDirectory`.
  Never read or copy tokens from the user's default Gemini/Antigravity profile, keychain, or environment.
- Browser authentication is user initiated. The bridge validates and strips the exact authorization stdout line; the
  client opens the Google URL. Same-host browsers complete directly. For remote clients, pure-Dart client logic parses
  the pasted redirect and checks its generic loopback shape before submission. The Antigravity plugin independently
  validates the exact outstanding Google state, callback endpoint, and code before forwarding it to loopback.
- Use the agent's current model as the default and expose every valid advertised model with its exact opaque ID/name.
  Do not maintain a Sesori model manifest, infer families, or send a stale/unknown model.
- Set Antigravity mode to `default` before every prompt. Never use `auto_edit`, `yolo`, the `agy` CLI's
  `--dangerously-skip-permissions`, or automatic permission acceptance.
- Surface normal approval once/reject/cancel. Deliberately omit `allow_always`: Sesori's current permission contract
  cannot carry the agent's prompt-injection warning, so exposing persistent approval would discard material safety
  context. Record this limitation in `docs/HARNESS_CAPABILITIES.md`.
- Convert valid `interaction_` permission requests into one single-choice Sesori question. Preserve opaque option IDs
  through an internal label-to-ID map, disambiguate duplicate labels, reject malformed/ambiguous answers, and never
  leave an invisible pending request.
- Keep ACP client filesystem and terminal capabilities disabled. The official local harness owns its tools and emits
  permission/tool updates; no new bridge filesystem server is introduced.
- Use the agent's isolated `.meta` records read-only for session enumeration and cold-start `sessionId -> cwd`
  recovery because the reviewed runtime does not provide the global import contract Sesori needs. Do not parse its
  SQLite conversation contents or mutate private history files.
- Local deletion remains a Sesori tombstone plus standard close when advertised. It does not delete Google's
  conversation/profile files; Git/database behavior and UI must describe this honestly.
- Managed installation is explicit user action, never startup download or background update. Download directly from
  `dl.google.com`, verify independently computed immutable SHA-256 digests, preserve the pair together, then run the
  exact ACP identity probe before activation.
- Show that the runtime is proprietary and link Google's current terms/docs in setup/product documentation. Sesori
  does not interpret entitlement or copy credentials; the user chooses whether to install and authenticate.
- No Antigravity-specific analytics. Existing generic authoritative session/auth/install outcomes are sufficient, and
  analytics policy forbids coding-provider/model names.

## Scope

### Included

- New pure-Dart `bridge/sesori_plugin_antigravity/` package over `sesori_plugin_acp`.
- Official runtime-pair resolution, platform launch arguments, exact identity/capability probing, explicit/PATH/managed
  precedence, and clear unsupported-host setup states.
- A backend-neutral browser OAuth challenge and one-shot redirect-continuation seam through plugin interface, bridge
  route/service, shared transport, pure client layers, and shared Flutter settings UI.
- Isolated Antigravity profile preparation, personal OAuth, strict authorization/redirect URL validation, stdout
  filtering, cancellation, and privacy-safe failures.
- Typed Antigravity profile/session metadata and protocol boundary models. Generated files come only from source
  annotations and generators.
- Model discovery/selection, fixed supervised mode, standard commands, question classification, permission filtering,
  and bounded tool-update normalization with live/replay parity.
- Session creation, prompt/command delivery, two-session behavior, cancellation, history replay, cold resume,
  bridge-derived projects, isolated-profile import, crash recovery, and shutdown through shared ACP ownership.
- App registration through the plugin-owned opaque ID, descriptor-provided display name, generic client presentation,
  README/architecture/capability documentation, and exact registry tests.
- Pinned managed installation for the five official registry targets and explicit unsupported handling for macOS x64.
- Regression-document reconciliation and L1-L5 retirement evidence defined below.

### Excluded

- `shubzkothekar/antigravity-acp`, `agy-acp`, any other community adapter, or wrapping `agy -p`.
- `--dangerously-skip-permissions`, `auto_edit`, `yolo`, silent auto-approval, or persistent `allow_always`.
- Gemini Enterprise OAuth, Gemini API keys, Agent Platform/Vertex credentials, account switching, multiple profiles per
  bridge, or copying an existing Google token.
- macOS x64 managed support while Google publishes no registry asset.
- ACP client terminal/filesystem handlers, global Antigravity hooks, global MCP config import, desktop IDE automation,
  cloud sandbox management, browser automation, or the interactive `agy` CLI.
- Parsing Antigravity SQLite conversation databases, deleting Google-owned history/profile files, session fork/rewind,
  upstream rename/delete, or import from another profile/harness.
- Model-family inference, preferred-model filtering, quota/billing display, custom model aliases, or a remote model
  manifest.
- New database tables/columns/migrations, persisted OAuth challenges, compatibility shims for unpublished code,
  provider-specific analytics, a shared `Harness.antigravity` case, or an Antigravity presentation branch.

## Architecture

```text
module_app_ui (render/collect only)
  -> PluginManagementCubit (consumer)
  -> PluginManagementService (Layer 3: transient auth state and generic loopback-input validation)
  -> PluginRepository (Layer 2: every wire-challenge variant maps to an internal model)
  -> PluginApi (Layer 1 HTTP) <-> encrypted relay <-> bridge auth route/lifecycle

PluginLifecycleService (one active operation per plugin)
  -> AntigravityAuthenticationOperation (stateful consumer)
       -> AntigravityProfileService -> AntigravityProfileRepository -> AntigravityProfileStorage
       -> AntigravityAuthenticationService -> AntigravityAuthorizationParser
            -> AntigravityAuthenticationRepository
                 -> AntigravityAcpApi -> official ACP process
                 -> AntigravityLoopbackClient -> exact bridge-host callback

bridge app -> AntigravityPluginDescriptor (composition root)
  -> AntigravityPlugin -> sesori_plugin_acp -> agy_acp_server + localharness_external
  -> AntigravityRuntimeService -> AntigravityRuntimeRepository -> Layer-1 storage/ACP APIs
  -> isolated GEMINI_HOME
```

### Layering And Composition Rules

- Every external Antigravity boundary follows `Foundation -> API/Storage/Client -> Repository -> Service -> Consumer`.
  Filesystem, process, and HTTP access never begins in a repository, service, operation, plugin, or descriptor helper.
- `AntigravityPluginDescriptor` is the plugin-package composition root. Its lifecycle entries construct peer
  collaborators together from `PluginHost` dependencies and pass each dependency through a required named constructor.
  No service constructs a repository, and no repository constructs an API, client, or storage collaborator.
- `AntigravityPlugin` receives all process-lifetime peers plus a descriptor-owned options-service composer. After a
  live ACP client exists, hooks may invoke that composer with the shared connection-scoped config repository and create
  the approval registry. The plugin never invokes a collaborator constructor itself.
- `AntigravityAuthenticationOperation` receives already-composed profile and authentication services. It owns the
  one-shot state machine and closes its composed process/HTTP leases, but it does not instantiate peers.
- Dependencies have no production defaults. Tests fake concrete classes with `implements`; no one-implementation
  interfaces are introduced only for testing.
- Layer-1 ACP code parses protocol replies but makes no Antigravity identity, version, capability, or auth-policy
  decision. Repositories map those external results into plugin-domain outcomes.

### Ownership Boundaries

- `sesori_plugin_interface` owns backend-neutral authentication operation and challenge variants. A browser operation
  accepts one redirect continuation; device-code implementations such as Codex remain unchanged in behavior.
- `sesori_shared` owns backend-neutral wire DTOs for `deviceCode`, `browser`, `unknown`, and redirect submission. The
  browser DTO carries an authorization URL and expected loopback callback URL, not Google-specific state semantics.
- Bridge runtime/lifecycle owns single-flight authentication, generation fencing, cancellation, and routing a
  continuation only to the current active operation. It does not inspect Google URL semantics or issue HTTP itself.
- `sesori_plugin_antigravity` owns Google/runtime identity, profile policy, interactions, update normalization, and
  metadata mapping. Layer-3 services own runtime selection/probe/setup, callback/state/code, and model/mode workflows.
- The pure-Dart client flow owns generic browser challenge mapping and pasted-input validation. `PluginRepository` maps
  every wire variant to an internal sealed challenge. `PluginManagementService` parses the raw typed paste intent and
  verifies generic absolute-loopback shape plus the expected endpoint before asking the repository to submit it.
- `module_app_ui` only renders typed state, collects raw text, creates a typed submission intent, and invokes the cubit.
  It does not parse, validate, normalize, persist, or log either URL. Mobile and desktop shells only compose the view.
- `sesori_plugin_acp` remains the only owner of standard ACP requests, transport lifecycle, session lanes, event
  mapping, replay, cancellation, and pending inputs. New hooks are identity defaults for existing plugins.
- `sesori_plugin_runtime` continues to own generic download/checksum/extract/place/activate/cleanup. Antigravity
  contributes a package-directory manifest and service-backed validator; it does not duplicate an installer.
- Bridge app imports Antigravity only at `plugin_registry.dart`. Client logic uses opaque plugin IDs, existing metadata
  display names where available, and generic ID/artwork fallback elsewhere; no shared widget branches on Antigravity.

### Antigravity Collaborator Graph

All source paths in this table are below `bridge/sesori_plugin_antigravity/lib/src/`. Method inputs such as a selected
pair, `PluginHost`, timeout, cwd, or prepared profile are domain inputs, not hidden constructor dependencies.

| Collaborator | Source | Layer |
| --- | --- | --- |
| `AntigravityIdentity` | `foundation/antigravity_identity.dart` | L0 |
| `AntigravityRelease` | `foundation/antigravity_release.dart` | L0 |
| `AntigravityRuntimeManifest` | `runtime/antigravity_runtime_manifest.dart` | L0 manifest |
| `AntigravityLaunchSpecBuilder` | `builders/antigravity_launch_spec_builder.dart` | L0 |
| `AntigravityAuthorizationParser` | `parsers/antigravity_authorization_parser.dart` | L0 |
| `AntigravityProtocolMapper` | `mappers/antigravity_protocol_mapper.dart` | L0 |
| `AntigravityProfileStorage` | `storage/antigravity_profile_storage.dart` | L1 |
| `AntigravityRuntimeStorage` | `storage/antigravity_runtime_storage.dart` | L1 |
| `AntigravitySessionMetadataStorage` | `storage/antigravity_session_metadata_storage.dart` | L1 |
| `AntigravityLoopbackClient` | `clients/antigravity_loopback_client.dart` | L1 |
| `AntigravityAcpApi` | `api/antigravity_acp_api.dart` | L1 |
| `AntigravityProfileRepository` | `repositories/antigravity_profile_repository.dart` | L2 |
| `AntigravityRuntimeRepository` | `repositories/antigravity_runtime_repository.dart` | L2 |
| `AntigravityAuthenticationRepository` | `repositories/antigravity_authentication_repository.dart` | L2 |
| `AntigravitySessionMetadataRepository` | `repositories/antigravity_session_metadata_repository.dart` | L2 |
| `AntigravityProfileService` | `services/antigravity_profile_service.dart` | L3 |
| `AntigravityRuntimeService` | `services/antigravity_runtime_service.dart` | L3 |
| `AntigravityAuthenticationService` | `services/antigravity_authentication_service.dart` | L3 |
| `AntigravitySessionOptionsService` | `services/antigravity_session_options_service.dart` | L3 |
| `AntigravityRuntimeVersionValidator` | `runtime/antigravity_runtime_version_validator.dart` | L3 adapter |
| `AntigravityCatalogTracker` | `trackers/antigravity_catalog_tracker.dart` | tracker |
| `AntigravityAuthenticationOperation` | `authentication/antigravity_authentication_operation.dart` | consumer |
| `AntigravityApprovalRegistry` | `antigravity_approval_registry.dart` | consumer |
| `AntigravityPlugin` | `antigravity_plugin.dart` | consumer |
| `AntigravityPluginDescriptor` | `runtime/antigravity_plugin_descriptor.dart` | composition |

| Collaborator | Required constructor dependencies | Composed by | Owned state/lifecycle |
| --- | --- | --- | --- |
| `AntigravityIdentity` / `AntigravityRelease` | none | descriptor | immutable values |
| `AntigravityRuntimeManifest` | release facts | descriptor | immutable target map |
| `AntigravityLaunchSpecBuilder` | none | descriptor | none |
| `AntigravityAuthorizationParser` | none | descriptor | none |
| `AntigravityProtocolMapper` | ACP content limits | descriptor | none |
| `AntigravityProfileStorage` | command executor, platform target | descriptor | filesystem/permission boundary |
| `AntigravityRuntimeStorage` | PATH resolver | descriptor | filesystem boundary only |
| `AntigravitySessionMetadataStorage` | none | descriptor | filesystem boundary only |
| `AntigravityLoopbackClient` | HTTP client | descriptor | one HTTP client lease |
| `AntigravityAcpApi` | process factory | descriptor | one scratch ACP lease |
| `AntigravityProfileRepository` | profile storage | descriptor | none |
| `AntigravityRuntimeRepository` | runtime storage, ACP API, launch builder | descriptor | none |
| `AntigravityAuthenticationRepository` | ACP API, loopback client | descriptor | none |
| `AntigravitySessionMetadataRepository` | metadata storage | descriptor | none |
| `AntigravityProfileService` | profile repository | descriptor | none |
| `AntigravityRuntimeService` | runtime repository | descriptor | none |
| `AntigravityAuthenticationService` | auth repository, auth parser | descriptor | none |
| `AntigravitySessionOptionsService` | catalog tracker, ACP config repository | descriptor callback at ACP hook | none |
| `AntigravityRuntimeVersionValidator` | runtime service | descriptor | none |
| `AntigravityCatalogTracker` | none | descriptor | last-good immutable catalog |
| `AntigravityAuthenticationOperation` | profile service, auth service | descriptor | one auth attempt |
| `AntigravityApprovalRegistry` | live ACP client, pending registries | plugin hook | connection requests |
| `AntigravityPlugin` | launch/ACP/metadata peers, options composer | descriptor | live ACP processes |
| `AntigravityPluginDescriptor` | none | bridge registry | lifecycle composition root |

`AntigravityProfileStorage` creates the profile and, before any agent launch, uses its injected `CommandExecutor` to
apply owner-only `700` mode on POSIX; Windows relies on the user-profile ACL and runs no chmod command. Permission
failure blocks setup. `AntigravityProfileRepository` maps typed storage DTOs and `AntigravityProfileService` applies
environment policy. `AntigravitySessionMetadataStorage` alone lists and decodes bounded `.meta` files into typed DTOs;
its repository maps UUID/cwd records into plugin-domain sessions and decides which malformed records to skip. Neither
reads SQLite.

`AntigravityAcpApi` owns scratch `AcpStdioClient`/`AcpAgentApi` process access, initialize-only, and authenticate calls.
`AntigravityRuntimeRepository` maps runtime-storage candidates and ACP initialize results into domain outcomes.
`AntigravityRuntimeService` validates exact identity/version/capabilities, owns explicit/PATH/managed precedence and
setup classification, and sequences repository calls. `AntigravityAuthenticationRepository` maps ACP auth and callback
HTTP outcomes only.
`AntigravityAuthenticationService` parses and validates Google authorization/callback semantics, sequences repository
calls, and permits one no-redirect GET only after exact endpoint/state/code validation. The operation coordinates the
profile/authentication services and owns state transitions.

Shared ACP changes preserve the same layering: `AcpAgentApi` exposes separate initialize-only/authenticate and
`session/set_mode` Layer-1 calls; `AcpSessionConfigRepository` maps model/mode writes for consumers. The shared stdout
hook owns a bounded partial-line buffer per process and delegates complete authorization lines to the plugin parser.
A launch-spec/host-process `includeParentEnvironment` flag is a required named parameter. Every existing caller is
updated in lockstep to choose `true`; Antigravity chooses `false` and supplies the profile service's filtered
`PluginHost.environment`. No Antigravity service or plugin calls `AcpStdioClient.request` directly.

Step 4 changes existing client collaborators without adding a parallel model layer:

| Existing client collaborator | Layer/owner | Step 4 responsibility |
| --- | --- | --- |
| `PluginApi` | L1 HTTP, injected by client DI | encode/decode backend-neutral shared DTOs only |
| `PluginRepository` | L2, injected by client DI | map `deviceCode`, `browser`, and `unknown` to internal variants |
| `PluginManagementService` | L3, injected by client DI | own transient challenges and validate typed paste intents |
| `PluginManagementCubit` | consumer, shell composition | forward intent and publish operation/presentation state |
| `HarnessesSettingsView` | presentation, `module_app_ui` | render, collect raw text, and dispatch typed intent only |

The internal pure-Dart challenge is sealed as device-code, browser, or unsupported. The browser variant contains parsed
HTTPS authorization and expected loopback callback URIs. The shared `unknown` DTO maps to unsupported in
`PluginRepository`; `PluginManagementService` never imports or switches on a wire challenge response. A typed
`PluginAuthenticationContinuationIntent.pasted(rawInput: ...)` crosses UI -> cubit -> service without UI parsing.

Data-only types are not additional collaborators: generated shared challenge/request DTO variants live in
`sesori_shared`; the internal challenge lives in `client/module_core/lib/src/repositories/models/`, while the
continuation intent lives in `client/module_core/lib/src/services/models/`; Antigravity runtime-pair, prepared-profile,
profile-settings DTO, metadata DTO, and probe-result values live under the
owning plugin layer. They are immutable, have no injected dependencies or lifecycle, and are constructed by the mapper
or owner named above.

A collaborator remains private or is folded into its owner if implementation shows no independent state, lifecycle,
multi-caller invariant, or stable layer boundary. The table fixes ownership; it is not permission to add pass-through
classes solely to shorten files.

### Browser Authentication Flow

```text
POST /plugin/antigravity/authentication
  -> initialize official ACP without session/new
  -> authenticate(methodId: oauth-personal)
  -> intercept exact non-JSON Google authorization line
  -> validate accounts.google.com URL + one state + loopback redirect
  -> return browser challenge to requesting client
  -> client opens URL

same-host browser:
  Google -> bridge-host loopback listener -> authenticate completes

remote browser:
  Google -> unreachable browser-local 127.0.0.1 URL
  user copies final URL -> module_app_ui emits typed raw-paste intent
  -> PluginManagementService parses URI and checks generic loopback/expected-endpoint shape
  -> PluginRepository -> POST /plugin/antigravity/authentication/redirect
  -> AntigravityAuthenticationService validates exact endpoint/state/code
  -> AuthenticationRepository -> LoopbackClient GETs only the issued listener, with redirects disabled
  -> authenticate completes

completion -> setup reinspection -> terminal progress -> profile becomes ready
```

The callback relay is intentionally not a generic fetch primitive. It accepts one bounded URL only while a browser
challenge is active and the Antigravity operation proves exact equality with its issued loopback endpoint/state. It
never follows an arbitrary host, redirect, second submission, or URL from a stale generation.

### Runtime And Profile Flow

```text
explicit --antigravity-bin -> exact file + mandatory sibling -> ACP probe
else PATH agy_acp_server.* -> resolved exact file + sibling -> ACP probe
else installed managed pair -> ACP probe
else setup runtimeMissing/unavailable

start/auth/replay scratch process
  -> launch exact selected pair
  -> GEMINI_HOME=<plugin state>/profile
  -> AGY_ACP_FORCE_FILE_STORAGE=1
  -> ANTIGRAVITY_HARNESS_PATH=<validated sibling>
  -> Linux only: --uid=
```

An explicit path is authoritative and never falls through. `AntigravityRuntimeStorage` exposes pair candidates, and
`AntigravityRuntimeRepository` maps candidate/probe boundary results without choosing among them.
`AntigravityRuntimeService` owns explicit/PATH/managed precedence, exact probe validation, and setup classification.
Setup may use token-file presence from `AntigravityProfileRepository` as a non-secret hint, but live ACP authentication
remains authoritative; stale/invalid tokens become a typed authentication-required state.

### Sessions, Options, And Updates

```text
session/new or load/resume
  -> capture configOptions.model catalog/current value
  -> register sessionId -> canonical cwd

create/send
  -> validate exact requested model against last-good catalog
  -> session/set_config_option(model, exact id) when needed
  -> session/set_mode(default)
  -> standard ACP session/prompt

session/update
  -> bounded Antigravity normalization
  -> existing ACP live mapper

history session/load replay
  -> same bounded normalization
  -> existing ACP replay collector

catalog import/cold resume
  -> metadata Storage lists/decodes isolated profile *.meta into typed DTOs
  -> metadata Repository maps valid session UUID + cwd only
  -> register directory in shared ACP map
  -> standard session/load or resume
```

The model tracker replaces its catalog only after a complete valid capture; a malformed refresh retains the prior
catalog. No model IDs, account values, prompts, or tool bodies are logged.

## Compatibility And Security

- Plugin IDs stay strings on the existing session/plugin wire. Older clients show a generic `antigravity` row and can
  use already-authenticated sessions; newer clients connected to an older bridge see no Antigravity entry.
- Browser challenge and redirect submission are new public client/bridge wire variants. Shared DTOs remain
  backend-neutral; `PluginRepository` maps their `deviceCode`, `browser`, and `unknown` variants into internal models.
  A public older client cannot complete remote browser auth, so setup requires a current client or bridge-host login.
  No fake device code or empty sentinel impersonates a browser challenge.
- Authorization URLs and returned OAuth codes are transient sensitive values: encrypted in transit, bounded, validated,
  never logged, never placed in SSE replay, and never persisted. The bridge forwards only to the exact issued
  `127.0.0.1` listener, preventing the continuation route from becoming SSRF.
- The isolated profile prevents ambient Gemini/Google credentials, default keychain entries, other ACP clients, and
  multiple bridges from silently sharing identity. New settings JSON is typed and contains only `auth.type`, never a
  token or API key.
- Exact runtime identity/version plus mandatory sibling validation prevents an `agy` CLI, community adapter, mismatched
  local harness, or silently republished archive from being accepted as Google Antigravity ACP.
- Managed archives are fetched only after explicit install, verified before extraction, kept as an immutable package
  directory, and initialized before activation. The five independently recomputed hashes are pinned in source.
- ACP terminal and client filesystem capabilities remain false. `default` mode and filtered persistent approval keep
  every sensitive tool action under the agent's and Sesori's visible permission path.
- Invalid/duplicate question options are rejected rather than guessed. Exact opaque option IDs are never derived from
  labels when the label is ambiguous.
- Private `.meta` parsing is read-only, limited to UUID filename plus string `cwd`, and fail-soft. A format change can
  reduce import/cold attribution but cannot corrupt Google's history or Sesori's database.
- Existing session tombstones prevent a locally deleted row from reappearing during explicit import. Google-owned
  profile/history residue is accepted and documented rather than adding private database deletion logic.
- Google controls provider traffic, retention, telemetry, quotas, account eligibility, and terms. Sesori presents the
  official terms/docs and does not claim that registry publication changes the user's agreement.

## Complexity Budget And Cleanup

New persistent mutable state:

- Google-owned isolated profile under the plugin state root: typed `settings.json` written by Sesori, then token,
  conversation databases, metadata, and brain files written by the official agent. This is required for explicit
  authentication and recovery without touching a user's unrelated Google profile.
- Managed runtime package directory and existing shared runtime activation metadata after Step 9. No automatic install
  or update.
- Existing bridge session/project/tombstone tables only. No schema, migration, duplicated session sidecar, or persisted
  auth continuation.

New in-memory mutable state:

- One current browser-auth operation already fenced by `PluginLifecycleService`; its Antigravity implementation holds
  one expected authorization/redirect tuple and one pending continuation completer until completion/cancel. The
  operation coordinates injected service outcomes and never owns raw filesystem, ACP, or HTTP access.
- One bounded stdout line buffer per Antigravity process because the observed auth line can split across chunks.
- One last-good immutable model catalog in `AntigravityCatalogTracker`.
- Existing ACP maps/lanes/registries remain authoritative for sessions, prompts, permissions, and questions. The only
  shared addition is a protected way for the metadata repository to register a recovered directory.

Deliberately omitted coordination and state:

- No auth database table, callback registry by state, token cache/copy, browser polling loop, background refresh,
  profile watcher, process pool, model manifest, runtime update daemon, alternate-session index, permission memory,
  or private SQLite parser.
- No lock beyond existing one-authentication-per-plugin lifecycle serialization. A second callback is rejected by the
  one-shot operation rather than coordinated through a new registry.
- No direct profile cleanup on local session deletion; low-damage disk residue is preferable to mutating proprietary
  history files.

Safeguard evidence:

- URL interception, remote callback relay, and profile isolation address the ordinary personal-login flow observed in
  the official agent integration; without them ACP framing breaks or remote clients cannot finish auth.
- Pure-Dart client loopback-shape validation gives immediate safe feedback. Independent exact endpoint/state/code
  validation in the plugin and no-redirect transport in the Layer-1 client prevent credential theft and SSRF.
- Fixed `default` mode and removal of warning-bearing persistent approval protect ordinary tool execution.
- Pair/checksum/identity validation protects every explicit managed install of a very large proprietary executable.
- Malformed `.meta` skipping and duplicate-label rejection are bounded fail-soft parsing, not speculative lifecycle
  machinery.

Cleanup assessment:

- No existing route, field, database column, cache, job, or compatibility path becomes obsolete.
- Directly caused cleanup is limited to keeping exact built-in, registry, workspace, and documentation inventories
  current. Existing generic harness artwork remains the intended backend-neutral fallback.
- Existing device-code auth remains fully used by Codex and is not generalized away.

## Analytics Assessment

No event is added. Existing generic authoritative authentication, installation, session creation, and first-turn
outcomes already answer activation without exposing a coding provider. An Antigravity/model parameter is expressly
outside the closed analytics privacy contract, and a setup-button tap would not be an authoritative outcome.

## Delivery Steps

1. `🌱 [antigravity-harness] docs: plan Antigravity ACP support [step 1/12]`
   - Add and architecture-review this plan/tracker; no production behavior.
2. `⚙️ [antigravity-harness] feat(antigravity): pin the official ACP runtime contract [step 2/12]`
   - Add the package/workspace skeleton, official pair/release identity, initialize-only probe seam, layered local-pair
     resolution, privacy-safe released-agent fixture, and focused contract tests. Do not create/register the plugin.
3. `🚧 [antigravity-harness] feat(auth): accept browser authentication continuations [step 3/12]`
   - Extend the plugin authentication operation and bridge runtime/lifecycle ownership with a one-shot browser redirect
     continuation while preserving Codex device-code behavior. Keep it internal and unreachable from HTTP for now.
4. `🚧 [antigravity-harness] feat(client): add remote browser authentication handoff [step 4/12]`
   - Add the browser challenge/redirect wire DTO and route; repository-owned DTO mapping; pure-Dart service validation;
     cubit flow; presentation-only shared settings UI; unknown fallback; cancellation; and mobile/desktop tests. No
     plugin emits it yet.
5. `🚧 [antigravity-harness] feat(antigravity): add isolated profile authentication [step 5/12]`
   - Add layered profile Storage/Repository/Service ownership, auth stdout filtering, ACP/HTTP lower boundaries,
     Google/loopback validation, personal OAuth operation, callback forwarding, cancellation, and deterministic tests.
6. `🚧 [antigravity-harness] feat(antigravity): map ACP options and interactions [step 6/12]`
   - Add exact model catalog/selection, fixed default mode, question conversion, persistent-approval filtering, bounded
     tool normalization, and live/replay mapper hooks with direct collaborator tests.
7. `🚧 [antigravity-harness] feat(antigravity): compose persistent ACP sessions [step 7/12]`
   - Create the unregistered `AntigravityPlugin` and descriptor, compose typed metadata Storage/Repository mapping,
     directory recovery, load/resume/history, turn lanes, options wiring, commands, crash/reconnect,
     tombstone-compatible deletion, and conformance tests.
8. `⚙️ [antigravity-harness] feat(bridge): activate local Antigravity runtimes [step 8/12]`
   - Register the local-only descriptor through app composition with its plugin-owned opaque ID; update exact-set
     fixtures, architecture inventories, and backend-neutral listing/routing. Local manual support is complete here.
9. `🚧 [antigravity-harness] feat(antigravity): install the managed ACP runtime [step 9/12]`
   - Independently pin all five official archives, add package-directory managed install/selection/validation, explicit
     unsupported macOS x64 behavior, install tests, and user-initiated lifecycle integration.
10. `🌱 [antigravity-harness] docs: complete Antigravity product guidance [step 10/12]`
    - Complete README/architecture/operator guidance after activation while retaining descriptor-provided naming and
      generic harness artwork.
11. `🌱 [antigravity-harness] docs: reconcile Antigravity regression coverage [step 11/12]`
    - Penultimate step: update affected `docs/regression/` contracts, sources, matrices, and honest capability limits.
12. `🚧 [antigravity-harness] test: verify Antigravity and retire the plan [step 12/12]`
    - Run architecture implementation review and the recorded L1-L5 matrix, fix only in-scope defects, record evidence,
      and move the passing plan to `.plan/completed/antigravity-harness/`.

Each PR targets at most 1,500 changed lines including tests and generated output. Step 4 may approach the cap because
the new wire variant must compile through shared DTO generation and exhaustive client presentation consumers. If the
measured change exceeds it, split transport/service from UI before opening that PR and update the fixed plan total
first. No other step has an expected overage.

## Step Details

### Step 1/12: Plan Antigravity support

- Record upstream evidence, fixed product decisions, ownership, security/compatibility posture, complexity budget,
  exact PR series, and retirement matrix.
- Run `architecture-plan-review` through a sub-agent and apply valid findings directly.
- Validate Markdown paths/links, exact titles, and Git whitespace only.

### Step 2/12: Pin the official runtime contract

- Create `bridge/sesori_plugin_antigravity/` with package metadata, exports, analysis/build-runner configuration,
  identity/release facts, `AntigravityLaunchSpecBuilder`, Layer-1 runtime Storage/ACP API, Layer-2 runtime repository,
  Layer-3 runtime service, and tests. Add it to bridge workspace, Makefile, and CI inventories; create no plugin or
  production descriptor yet.
- Refactor `AcpAgentApi` so initialize-only and authenticate are separately callable while its existing combined method
  and every current harness retain behavior. `AntigravityAcpApi` owns scratch process/client access; the repository maps
  storage/probe results, while `AntigravityRuntimeService` owns exact validation, candidate precedence, and sequencing.
- Download the official macOS arm64 archive from the pinned registry URL in an isolated temporary directory; compute
  hash/size, inspect exactly the pair, launch with the registry arguments/environment, and capture only privacy-safe
  initialize identity/capability structure. Do not commit the archive, credentials, URLs, account/model IDs, or logs.
- Freeze exact agent version, required load/resume/auth capability facts, process exit, and whether session list/close
  are actually advertised. Update later step wording if the release contradicts reviewed evidence.
- Cover explicit path authority, PATH pair resolution, missing/mismatched sibling, platform names/args, malformed
  initialize, wrong identity/version, timeout, cancellation, and cleanup.

### Step 3/12: Browser continuation ownership

- Replace the stream-only descriptor result with a backend-neutral authentication operation that exposes events and can
  reject or accept a browser redirect according to its sealed operation kind. Update Codex and all in-repository fakes
  in lockstep; no compatibility shim for the internal Dart API.
- Route continuation only to the current plugin's single active, generation-fenced authentication. Define typed
  no-active/wrong-kind/already-submitted conflicts and preserve cancel/shutdown settlement.
- Keep browser semantics out of bridge core: it owns operation identity/order, not provider URL validation or HTTP.
- Cover same-request joining, submit-before/after challenge, stale generation, duplicate submit, cancel race, shutdown,
  Codex rejection, and terminal cleanup without synthetic unreachable guards.

### Step 4/12: Remote browser handoff

- Add backend-neutral shared transport variants for `deviceCode`, `browser`, and `unknown`. The browser DTO carries an
  HTTPS authorization URL and expected loopback callback URL; it contains no Google provider, state, or code policy.
- Add `POST /plugin/:id/authentication/redirect` with a typed bounded `redirectUrl` request and conflict/error mapping.
  Register it through the existing routing/composition point and update API fixtures/docs generated from source where
  applicable.
- Keep `PluginApi` at Layer 1: it serializes shared response/request DTOs without domain decisions. In
  `PluginRepository`, exhaustively map device-code and browser DTOs to parsed internal sealed challenge variants and
  map `unknown` to an internal unsupported variant. Invalid known URLs become a typed request failure there.
- Make `PluginAuthenticationStartResult` carry only that internal challenge model. `PluginManagementService` must not
  import or inspect `PluginAuthenticationChallengeResponse`; it owns transient challenge state and consumes repository
  outcomes.
- Define `PluginAuthenticationContinuationIntent.pasted(rawInput: ...)` in pure Dart. `module_app_ui` creates that typed
  intent from the unchanged text-field value; the cubit forwards it to `PluginManagementService` without parsing.
- In `PluginManagementService`, parse the pasted URI, require a bounded absolute loopback URL matching the browser
  challenge's expected scheme/host/port/path, and reject userinfo/fragment or the wrong challenge kind before calling
  `PluginRepository` with a typed URI. This is generic client validation, not the plugin security boundary.
- Keep provider-specific authorization origin, exact callback endpoint, state, and code validation in the Antigravity
  plugin in Step 5. The bridge must independently reject a malicious or outdated client even when client checks passed.
- Keep `HarnessesSettingsView` presentation-only: render typed state, open the URL through the cubit action, explain
  local versus remote completion, collect raw text, dispatch the typed intent, and show typed errors/cancel/retry. It
  performs no URI parsing, validation, or normalization. Mobile and desktop shells share this view and business flow.
- Authentication URLs/codes stay only in transient state and clear on terminal progress, cancel, disconnect, or
  supersession. Cover repository mapping of all three wire variants, service input validation, cubit forwarding, URL
  launch, stale responses, terminal SSE, cancellation, and both app shells.

### Step 5/12: Isolated personal authentication

- Add typed `{auth: {type: oauth-personal}}` settings. `AntigravityProfileStorage` creates the profile, uses an injected
  `CommandExecutor` backed by `PluginHost.processes` to apply POSIX `700` before launch, writes/reads the typed settings
  DTO, and reports opaque token-file presence below the plugin state root. Windows performs no chmod and relies on its
  user-profile ACL. Permission failure blocks setup. The repository maps storage results; `AntigravityProfileService`
  produces the sanitized environment. All dependencies are required and tests cover mode, ordering, and failure.
- Add a narrow backend-neutral `includeParentEnvironment` launch/host-process flag as a required named parameter.
  Update every in-repository caller in lockstep to choose `true`; Antigravity chooses `false` and supplies a filtered
  copy of injected `PluginHost.environment`, removing ambient Google/Gemini credentials/profile overrides before adding
  `GEMINI_HOME`, `AGY_ACP_FORCE_FILE_STORAGE=1`, and the validated harness path for live/auth/probe/replay processes.
- Extend the shared ACP stdout seam with a bounded per-process partial-line buffer. The pure Antigravity parser
  recognizes the exact auth prefix, while `AntigravityAcpApi` owns scratch process I/O. Preserve every non-auth byte,
  reject malformed Google URLs with sanitized errors, and turn a live-login line into an auth-required exception.
- Put all outbound callback transport in `AntigravityLoopbackClient`, which accepts one already-validated URI, uses a
  required injected HTTP client, disables redirects, and exposes no generic fetch surface. It makes no Google decision.
- `AntigravityAuthenticationRepository` consumes `AntigravityAcpApi` and the loopback client. It maps typed ACP/HTTP
  results and performs only the already-authorized no-redirect GET; it does not decide Google origin, state, or code
  policy.
- `AntigravityAuthenticationService` consumes that repository and `AntigravityAuthorizationParser`. It validates
  authorization origin/path/query and the issued callback; continuation requires the same endpoint/state, one bounded
  code, and no userinfo/fragment before the service permits the repository GET.
- `AntigravityAuthenticationOperation` receives the already-composed profile and authentication services. It owns only
  one challenge/completer, state transitions, cancellation, and terminal cleanup; it performs no filesystem, ACP, or
  HTTP operation directly and never constructs its lower-layer peers.
- Implement initialize/authenticate, browser challenge, direct same-host completion, remote callback,
  abort/timeout/process-exit cleanup, and terminal setup reinspection. Never log either URL.
- Treat repository-reported token-file presence only as setup evidence; live authenticate is authoritative. Do not parse
  token content or auto-start login.

### Step 6/12: Options, questions, permissions, and updates

- Parse `configOptions` model selects including grouped options; keep exact IDs/names, current value, and a last-good
  immutable catalog. Expose one primary Antigravity agent and provider through existing session-option contracts.
- Extend Layer-1 `AcpAgentApi` and Layer-2 `AcpSessionConfigRepository` with standard `session/set_mode`. Add
  `AntigravitySessionOptionsService(required catalogTracker, required configRepository)`; it validates the model,
  performs exact selection, then sends `default` as one operation. Test it directly with fakes in this step; defer all
  plugin/descriptor composer wiring to Step 7. Any write failure prevents later dispatch.
- Add a narrow shared ACP session-update normalizer hook used identically by live events and `AcpReplayCollector`; every
  existing plugin gets identity behavior.
- Normalize Antigravity command/output/image keys into bounded standard fields, strip duplicate inline image bytes after
  retaining supported content/path metadata, and preserve nonzero exit separately from protocol/tool failure.
- Classify only structurally valid `interaction_` permission requests as single-choice questions. Map unique display
  labels back to exact IDs and reject malformed/ambiguous replies.
- Remove `allow_always` before ordinary base permission handling. Preserve allow-once/reject/cancel and never substitute
  a different option when an offered kind is absent.
- Cover grouped/empty/stale models, failed selection/mode, duplicate question labels/IDs, reject-kind question choices,
  prompt-injection warning filtering, malformed requests, bounded payloads, and live/replay equality.

### Step 7/12: Persistent ACP plugin composition

- Create the unregistered `AntigravityPlugin` and `AntigravityPluginDescriptor`; registration waits for Step 8.
- Add the smallest shared protected directory-registration seam. `AntigravitySessionMetadataStorage` alone lists
  bounded `.meta` files in the isolated conversations directory and decodes each through a typed generated DTO. It
  never reads SQLite or brain content.
- `AntigravitySessionMetadataRepository` consumes the storage DTOs, maps valid UUID filenames and canonical string cwd
  values into plugin-domain sessions, and records privacy-safe skips for malformed entries. The plugin consumes only
  repository results; ordinary bridge reads remain DB-only and scans run only for import or cold ACP resolution.
- In the descriptor composition root, build process-lifetime trackers, mapper, metadata repository, process factory,
  and other peers. Define the required composer that combines a live `AcpSessionConfigRepository` with the catalog
  tracker into the Step 6 service; pass it and every peer to `AntigravityPlugin`. The connection hook invokes that
  composer and separately creates the approval registry after the client exists; peers construct no peers.
- Prefer standard `session/resume` for live residency when advertised; reserve `session/load` for history replay.
  Preserve replay suppression, exact model stamping, turn acceptance semantics, stop-and-send, and cleanup.
- Cover new/load/resume, bridge restart directory recovery, long replay, two sessions, active cancel/delete, question
  cleanup, process crash/reconnect, stale auth, tombstone-compatible re-import, and idempotent dispose with ACP fakes.

### Step 8/12: Local descriptor and activation

- Register the Step 7 `AntigravityPluginDescriptor` with `--antigravity-bin`. Its composition asks
  `AntigravityRuntimeService` for explicit/PATH selection, initialize-only setup validation, ensureRuntime revalidation,
  isolated-profile auth classification, abort checks, and local install/login guidance.
- Launch every process through `PluginHost.processes`; never call `io.Process.start` directly.
- Advertise browser authentication only while personal auth is required. Keep install capability absent until Step 9.
- Add the package dependency and descriptor to the bridge app registry through `AntigravityIdentity.pluginId`; do not
  add a shared `Harness` case. Update exact built-in, CLI-option, app composition, and architecture inventories.
  Preserve OpenCode as preferred default and on-demand start.
- In this activation PR, update `docs/HARNESS_CAPABILITIES.md` for personal OAuth and persistent-approval gaps and put
  proprietary-runtime, Google terms, manual-pair, and retained-history disclosure in setup/auth guidance before either
  action is usable. Descriptor display name is `Antigravity`; shared presentation keeps generic harness artwork.
- Verify a missing runtime remains inert, an explicit pair is authoritative, local auth blocks only Antigravity, and a
  current client can route/list the generic built-in with the required disclosure.

### Step 9/12: Managed runtime installation

- Independently download all five registry archives; recompute SHA-256, archive size, member names/sizes, and compare
  against the registry/T3 evidence. Record only immutable public artifact facts; do not trust copied third-party hashes.
- Add `AntigravityRuntimeManifest` using package-directory layout so the server and harness remain siblings. Map the
  registry's macOS arm64, Linux x64/arm64, and Windows x64/arm64 assets; return unsupported for macOS x64.
- Reuse shared download/checksum/extract/place/activation/cleanup. Compose
  `AntigravityRuntimeVersionValidator(required runtimeService)` as the shared installer adapter; it delegates exact
  validation to the service and reports sanitized outcomes without duplicating process access.
- Extend descriptor precedence to explicit -> valid PATH -> already-installed managed. Advertise install only without
  an explicit override and on one of the five supported targets; install is always explicit.
- Add required `extractionTimeout` to `ArchiveRuntimeAsset`, forward it as a required named `ArchiveExtractor` input,
  and update every existing asset/caller explicitly. Give each Antigravity target a measured budget that unpacks the
  verified payload on its packaged host; retain traversal/symlink checks and test success, not only timeout messaging.
- Add managed-download disclosure and five-target/macOS-x64 capability facts in this PR before Install is exposed.
- Cover all target mappings/digests, package sibling preservation, corrupt archive/hash, partial pair, failed probe,
  shutdown-triggered abort at phase boundaries, superseded cleanup, rollback to the prior active runtime, unsupported
  host, successful large extraction, timeout, and disk-failure messaging without building a second installer.

### Step 10/12: Complete product guidance

- Complete README and architecture/operator docs with the final official pair/release, manual and managed setup,
  five-target support, macOS x64 gap, personal OAuth/remote callback, isolated profile, supervised mode, model/session/
  history/attachment behavior, retained Google history, and terms links already surfaced at activation.
- Audit both shells: management/chooser surfaces already carrying plugin metadata show descriptor-provided
  `Antigravity`; ID-only surfaces retain the generic `antigravity` name/plug fallback. Do not add an Antigravity branch
  or asset to `PregoBrandLogo`, add a presentation-only contract, or add provider-specific analytics.
- Reconcile any remaining non-regression inventory/support prose without postponing behavior-critical disclosure from
  Steps 8 or 9.

### Step 11/12: Reconcile regression documents

Update at least:

- `plugin-setup-and-lifecycle.md`
- `plugin-runtime-installation.md`
- `projects-and-sessions.md`
- `session-creation-and-options.md`
- `session-turns.md`
- `session-history-and-recovery.md`
- `questions-and-permissions.md`
- `tools-and-file-changes.md`
- `attachments-and-images.md`
- `session-archiving-and-deletion.md`

Reconcile feature statements, support matrices, authoritative boundaries, sources, and known limits. Do not rewrite
unrelated historical gaps or claim Enterprise/API-key/Agent Platform/macOS-x64 support.

### Step 12/12: Verify and retire

- Run `architecture-implementation-review` through a sub-agent over the Git-defined Step 2-10 production commit/PR
  range. Resolve valid in-scope findings with at most the two passes allowed by repository policy.
- Run focused package/app/shared/client tests and analyzers after the final code state and any review fixes.
- Execute the complete applicable L1-L5 catalog plus the Antigravity target/feature matrix below with pinned official
  artifacts and a dedicated eligible personal Google test account.
- Record Pass/Partial/Fail/Blocked, versions, privacy-safe evidence, and cleanup in `TRACKER.md`.
- Do not retire on incomplete required coverage unless the user explicitly accepts a named matrix reduction in this
  plan. On full pass, move both files to `.plan/completed/antigravity-harness/`.

## Regression And Retirement Matrix

Highest required level: **L5 Full**. The delivered managed runtime makes packaged claims across five host targets, and
browser authentication/session behavior crosses Google, bridge, encrypted transport, and client boundaries. Under
`docs/regression/README.md`, Step 12 runs the complete applicable documented catalog cumulatively from L1 through L5,
not only the Antigravity-focused feature rows below. Missing infrastructure is `Blocked`, not silently out of scope.

Release matrix:

- **Pinned agent:** registry package `1.0.0`, runtime `agy_acp_server_20260818_01_RC01`; record initialize identity.
- **Managed host targets:** macOS arm64, Linux x64, Linux arm64, Windows x64, Windows arm64.
- **Unsupported target:** macOS x64 must omit managed install and show accurate local/unsupported guidance.
- **Clients:** one release-target iOS device/simulator and one packaged desktop shell. Browser/callback presentation is
  shared, but both shell integrations must be exercised.
- **Account:** one dedicated eligible personal Google account. Evidence records only auth success/capability counts, not
  identity, authorization URLs, codes, or model IDs.
- **Remote topology:** one client whose browser is not on the bridge host, proving pasted loopback continuation; one
  same-host desktop flow proving direct callback completion.

Per-target packaged checks (all five supported hosts):

- setup before install, explicit install start/progress, archive hash verification, pair extraction/permissions, exact
  initialize validation, activation, restart selection, clean shutdown, shutdown-triggered install abort/recovery,
  failed update retaining the prior active runtime, and uninstall/cleanup behavior supported by shared runtime code;
- no automatic download, no cross-plugin impact, and privacy-safe logs/errors;
- at least a smoke `session/new -> prompt -> cancel/complete -> resume/load` on the target. Full account/UI scenarios
  may use the representative hosts below, but package/process claims must execute on every advertised target.

Feature matrix:

- **`plugin-setup-and-lifecycle.md`**
  - Evidence: missing/wrong/mismatched/current explicit and PATH pairs; exact identity/version; inert registration;
    auth-required isolation; enable/disable/restart/idle; crash/reconnect; current and older-client fallback.
  - Boundary: automated, headless bridge, live agent, and client E2E.
- **Browser personal authentication** (recorded in setup/lifecycle coverage)
  - Evidence: exact stdout fragmentation/filtering; repository mapping for every wire variant; service-owned generic
    loopback validation; presentation-only input collection; Google URL validation; same-host completion; remote paste;
    exact plugin callback/state/code validation; malformed/duplicate/stale rejection; cancel/process exit; no secrets
    in logs, SSE replay, or persisted state.
  - Boundary: automated, live Google service on representative macOS arm64 and Linux x64 hosts, iOS and desktop E2E.
- **`plugin-runtime-installation.md`**
  - Evidence: five independently pinned digests, target-sized extraction budgets, successful huge-package extraction,
    sibling preservation, validation-before-activation, shutdown abort/recovery, rollback, cleanup, and macOS x64 gap.
  - Boundary: automated plus packaged execution on every listed host target.
- **`projects-and-sessions.md`**
  - Evidence: isolated-profile metadata import, DB-only ordinary reads, canonical cwd attribution, malformed metadata
    skip, non-destructive re-import, and plugin ownership.
  - Boundary: headless bridge and live agent.
- **`session-creation-and-options.md`**
  - Evidence: current default, grouped account models, exact selection, stale rejection/refresh, `default` mode before
    prompt, session creation, and remembered plugin defaults.
  - Boundary: automated, live agent, and client E2E.
- **`session-turns.md`**
  - Evidence: text/reasoning/tool/status streaming, accepted-send timing, model application, abort, stop-and-send,
    two-session concurrency, visible failures, and idle completion with no permission bypass.
  - Boundary: live agent and both client shells.
- **`session-history-and-recovery.md`**
  - Evidence: first load replay, long history, tool normalization parity, cold reopen, plugin restart, bridge restart,
    resume without duplicate replay, and correct cwd.
  - Boundary: headless bridge, live agent, and client E2E.
- **`questions-and-permissions.md`**
  - Evidence: interaction question exact choice ID, duplicate-label behavior, permission allow-once/reject/cancel,
    `allow_always` absence, abort cleanup, and no auto-approval.
  - Boundary: live agent and client E2E.
- **`tools-and-file-changes.md`**
  - Evidence: command lifecycle, formatted output/nonzero exit, file diff content, generated-image degradation/path,
    bounded large payload, and live/replay status parity.
  - Boundary: live agent and client E2E.
- **`attachments-and-images.md`**
  - Evidence: every attachment type the initialize capability advertises and existing Sesori prompt model can carry;
    reject unsupported/oversized data without claiming T3-only file-resource behavior.
  - Boundary: automated, live agent, and client E2E.
- **`session-archiving-and-deletion.md`**
  - Evidence: archive/read-only behavior; active delete cancellation/settlement/close; tombstone prevents re-import;
    Google profile row remains and is documented.
  - Boundary: headless bridge, live agent, and client E2E.
- **Compatibility/presentation**
  - Evidence: current browser challenge, unknown future challenge, older generic plugin identity, metadata display name,
    generic ID/artwork fallback, pre-action terms/capability disclosure, and no database migration.
  - Boundary: automated and both client shells.

## Risks And Test Focus

- **Terms/proprietary distribution:** the registry intentionally publishes Google binaries for ACP clients, while
  Google separately controls account eligibility and terms. Fetch only from the official registry URLs after explicit
  action, link current terms, and avoid legal promises or community wrappers.
- **Large artifacts:** archives are hundreds of MiB and extracted pairs can exceed 1.6 GiB. Replace the extractor's
  fixed two-minute limit with required per-asset budgets, then verify successful target extraction, shutdown abort,
  disk/timeout failure, prior-runtime rollback, and cleanup without duplicating the shared installer.
- **Pair drift:** server and local harness must match. Resolve/place/lease them as one directory, then validate both
  before activation.
- **OAuth callback security:** a pasted URL is attacker-controlled input containing a short-lived code. Pure-Dart
  generic loopback checks improve feedback, but exact plugin-owned endpoint/state/code matching, one-shot use, a
  Layer-1 no-redirect HTTP client, and no logging are the release-blocking trust boundary.
- **Cross-version auth:** older public clients cannot represent browser continuation. Keep already-authenticated use
  compatible, provide an update/bridge-host action hint, and never encode a fake device code.
- **Profile isolation:** a wrong `GEMINI_HOME` could leak/corrupt unrelated Google credentials. Assert environment
  stripping and exact state-root containment on every process kind.
- **Permission safety:** a wrong mode or mapped `allow_always` could bypass meaningful review. Assert `default`, no
  dangerous CLI flags, exact offered-option selection, and a real permission/question before retirement.
- **Private metadata drift:** `.meta` is not a stable ACP API. Read only the minimum cwd shape, fail soft, retain bridge
  DB rows, and test that malformed metadata cannot block normal known sessions.
- **Process multiplexing:** T3 uses a process per provider session while shared `AcpPlugin` can multiplex. Prove two
  live
  sessions and reconnect on the official release; do not add serialization unless an observed failure requires it.
- **Tool payload size/shape:** normalize before live/replay retention, preserve useful bounded output/diffs, and strip
  duplicate inline image bytes without hiding failures.
- **External service variability:** account model lists and OAuth pages change. Assert protocol structure and exact
  round-trip IDs, not a hard-coded model inventory or browser text.
- **Unsupported host honesty:** do not synthesize macOS x64 support or silently use an unverified community build.

## Expected Result

Antigravity appears as an on-demand built-in harness backed only by Google's official ACP runtime pair. Users can first
point Sesori at a local pair, authenticate a separate personal profile from a local or remote client, create/resume
sessions, choose advertised models, supervise tools/questions, and recover history through the encrypted Sesori path.
They can later explicitly install the pinned managed runtime on each of Google's five published targets, with exact
checksum/pair/identity verification and an honest macOS x64 limitation.

No community adapter, dangerous permission bypass, ambient credential reuse, new database schema, provider-specific
analytics, or silent Google-history deletion is introduced. Existing harness behavior remains unchanged, and browser
OAuth continuation becomes a backend-neutral capability available to future plugins without embedding Antigravity
semantics in shared layers.
