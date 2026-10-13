# MCP information, approvals, and connections

## Status and scope

- Date: 2026-10-13. Planning base: `55c7d4cbba` on `sesori/mcp-approvals-issue` in the provided `copper-heron` worktree.
- Status: architecture-reviewed plan only; production implementation and live authentication qualification have not
  started.
- Priority: deliver Claude Code and Codex before expanding the other harnesses.
- User-confirmed first version: manage existing MCP servers and harness-offered connectors.
- Future direction: adding new MCP servers will follow. Preserve an appropriate configuration boundary now, without
  implementing creation, removal, configuration editors, or placeholder APIs.
- Work stays in the user-provided worktree. This request authorizes planning, not execution of the implementation
  series.

## Outcome

From a session or selected harness/project, a person can see which MCP servers and offered connectors are available,
inspect their tools and status, respond to tool approvals and supported input requests, and complete supported
connection/authentication actions. The screen identifies the bridge, harness, and effective scope. It explains an
unavailable action instead of implying that every harness has the same controls.

Connection, authorization, configuration enablement, project trust, and permission to execute a tool are different
facts. Completing sign-in must not grant blanket tool approval. Opening an authorization page must not display
authentication success.

## Evidence and remaining native checks

### Current repository

| Area | Evidence and implication |
|---|---|
| Plugin contract | `bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart` exposes sessions, commands, questions, and permissions, but no MCP management contract. Add a separate supported capability; do not require dummy implementations in every plugin. |
| Claude transport | `api/claude_stream_client.dart` and `repositories/claude_session_process_repository.dart` already send control requests to the named resident process. `ClaudeApprovalRegistry` handles `can_use_tool`; MCP elicitation needs its own native classification. |
| Codex | `api/codex_app_server_api.dart` is the typed request boundary. `approval_registry.dart` recognizes tagged MCP tool approvals, but maps other MCP requests to a generic question and replies with a flattened `answers` object. `codex_event_mapper.dart` drops MCP startup status. |
| Existing interactions | `PendingPermissionRegistry`, bridge `PendingInteractionService`, and `SessionOperationDispatcher` already own native pending requests and ordered replies. Reuse their cancellation, session attribution, and settlement mechanisms. |
| Client | `module_core` owns API/repository/service/cubit behavior; `module_app_ui` owns shared settings and session presentation. `permission_modal.dart` already renders once/always/reject. No dedicated MCP inventory exists. |
| Browser authentication | `PluginAuthenticationBrowserService`, `PluginAuthenticationLoopbackServer`, and the platform `PluginAuthenticationBrowser` already support local and remote browser returns. Reuse these capabilities; provider-account login in `PluginLifecycleService` is a different operation from signing into an MCP server. |
| Other harnesses | Pi's `/mcp` command has status/reconnect/login/logout behavior; login currently opens on the bridge host. ACP has bounded form mapping. OpenCode's local API reference contains MCP management routes, while its SSE mapper currently drops MCP housekeeping/auth-browser failures. These are integration leads, not proof of current version parity. |

### Upstream and local evidence

- Claude's official SDK implementation exposes `mcp_status`, `mcp_reconnect`, and `mcp_toggle` control requests. Source:
  [official Python SDK query implementation][sdk-query]. Capture the corresponding payloads from the versions
  Sesori supports before choosing DTO fields.
- Claude documents separate CLI MCP login/logout and `--no-browser` URL handoff, while a headless agent run does not
  itself perform interactive OAuth. Sources: [CLI MCP authentication][claude-cli-auth],
  [SDK MCP authentication][claude-sdk-auth]. Piped stdin versus terminal requirements and live-session credential
  refresh need verification.
- Codex documents MCP status, OAuth login/completion, configuration reload, form/URL elicitation, and app discovery. Its
  plugin installation APIs are explicitly under development; this plan must not depend on them. Source:
  [official app-server documentation][codex-app-server].
- Read-only local checks found Claude Code `2.1.296` with `mcp login --no-browser`, and Codex `0.162.1`. Generated Codex
  schemas confirm a distinct OAuth attempt ID, thread-aware status, connection/auth states, tool inventory, and form/URL
  request variants. These versions are newer than this branch's targets and do not qualify the pinned runtimes.
- Branch baselines: Claude minimum `2.1.221`, target `2.1.291`; Codex PATH minimum `0.139.0`, managed target `0.160.1`.
  Do not silently raise either minimum or copy current documentation into older-version assumptions.

Step 2 produces credential-free native captures at these baselines and records exact method support, scope, side
effects, and response semantics. Cover local stdio and HTTP MCP fixtures, a fixture OAuth server, project trust
rejection, tool approval, scalar/choice forms, URL elicitation, and connector metadata. No real account/configuration is
modified for these probes. Use explicit test configuration and fixture directories, never the developer's normal MCP
inventory.

The result fixes adapter mappings before production contracts land. A missing native capability becomes a versioned
limitation with an actionable handoff. It must not become inferred support or a second implementation of the harness's
credential store. If the primary requested journey cannot be supported, record the evidence and obtain a product
decision before reducing acceptance criteria.

## Product behavior and feel

- Add an **MCP** entry to the shared session menu. It opens a separate panel/sheet over the transcript, preserving the
  reading position and composer. Desktop uses the same content in a panel or dialog; phone uses the existing adaptive
  sheet/navigation pattern.
- Add an entry from harness settings with a selected project or live-session context. A harness-wide list must be
  labelled as such; never present one session's inventory as the global inventory. If an inactive Claude session cannot
  be inspected safely, show “Start or resume this session to inspect its MCP servers.” A read must not secretly create
  an agent session.
- The list shows name, connection state, authorization requirement, configuration origin/scope when known, and supported
  actions. Details show a description, safe endpoint origin when available, tool names/descriptions/count, and useful
  failure information. Do not send environment variables, authorization headers, full launch commands, or raw
  configuration to clients.
- Keep rows keyed by an opaque target identity and in stable order while statuses change. Preserve expanded details and
  scroll position. Replace inline progress in place; no whole-screen loading reset for a reconnect or sign-in.
- Offer **Reconnect**, **Enable/Disable**, **Sign in/Reauthorize**, **Sign out**, or **Open provider setup** only with
  the native meaning the adapter declares. Explain whether a change affects this session, this project, or broader
  harness configuration. Disablement and logout are not labelled as equivalent “disconnect” actions.
- Tool approval shows server/tool context when the backend supplies it, the operation description, and the
  native-supported grant choices. Forms preserve field order, labels, option values, required fields, and typed reply
  semantics.
- An external action shows the destination domain and purpose before opening the system browser. Opening, waiting,
  completed, cancelled, failed, and “continue on bridge computer” states are explicit. Returning from the browser
  refreshes authoritative native state; it does not manufacture success.
- Pending actions also remain discoverable in the session's existing waiting-for-input surface. Resolving a request on
  another client closes its overlay smoothly, without moving the transcript. Dismissing a sheet alone is not approval or
  denial. Add no audio.

## Ownership and contracts

### Server identity and future configuration

Introduce plugin-neutral MCP models under `sesori_plugin_interface/lib/src/models/` and wire DTOs under
`shared/sesori_shared/lib/src/models/sesori/`. Use `Mcp` naming for the product concept, not a particular harness's RPC
names.

- `McpScope` is a sealed value: harness, project with project ID, or session with session ID. A route also names the
  harness; the relay connection selects the bridge. The bridge resolves project/session ownership from its catalog and
  rejects a mismatched harness.
- `McpServerTarget` combines scope with an opaque adapter-issued server key. Keep keys separate from display names and
  URLs. Consumers pass keys back without parsing them. They need only survive the native configuration's lifetime, not a
  future rename.
- `McpConfigurationSource` describes native ownership and scope, including read-only/managed configuration when known.
  Unknown origin is honest absence. Do not introduce a Sesori configuration database or derive ownership from a name
  prefix.
- Model connection state and authorization state independently; carry error data only in the state that needs it. A
  declared set of actions describes current support and effect scope. Use enums for scalar states and sealed variants
  for payload-bearing states/actions.
- `McpServerSnapshot` contains presentation-safe metadata and tool summaries. Distinguish discovery failure/unavailable
  from an empty tool list. Resource browsing, resource content retrieval, manual tool execution, and MCP Apps HTML
  rendering are outside this feature.
- A later `createServer` flow belongs behind the same concrete plugin's native configuration boundary and returns a
  `McpServerTarget`. It can reuse the details, authentication, refresh, and action flows. This plan adds no
  create/update/delete request, generic config writer, empty tab, or speculative transport abstraction.

### Plugin and bridge

Add `McpManagementPluginApi` as an optional interface implemented by supporting `BridgePluginApi` implementations. It
owns typed inventory reads and supported actions for a scope. Add authentication capability only to implementations with
an actual flow. Per-server availability comes from the snapshot, not client checks for a harness name.

Concrete plugin data flow is
`native client/process API -> plugin repository/mapper -> plugin service where lifecycle is owned -> plugin API`. Extend
`CodexAppServerApi` rather than creating another wrapper for the same process. Claude control operations use its
existing resident-process repository; standalone login/logout commands extend the owning Claude process boundary with
typed request/results. Separate MCP repositories/services are justified by inventory normalization and authentication
lifetime, not file size.

Bridge `McpRepository` resolves the selected plugin through existing lifecycle access and maps plugin results to shared
DTOs. It owns no secondary inventory cache. `McpService` coordinates mutation plus authoritative refresh. A distinct
`McpAuthenticationService` owns one active MCP authentication attempt per bridge, including a plugin runtime lease,
cancellation, and completion. It does not get added to provider-account login state.

Proposed shared-router surface, with typed request/response models:

| Route | Contract |
|---|---|
| `POST /mcp/servers` | Read inventory for `{pluginId, scope}`. Returns an explicit supported snapshot, temporarily unavailable result, or unsupported capability. POST permits a typed sealed scope without ambiguous optional query fields; it is a read operation. |
| `POST /mcp/server/action` | Named target plus a closed native-supported action. Returns refreshed state or a typed failure; never accepts arbitrary native method names or raw config. |
| `POST /mcp/authentication` | Begin explicit authentication for the named target. Returns the attempt ID and one concrete challenge variant. |
| `GET /mcp/authentication` | Current attempt/status for reconnect recovery. No stored authentication history. |
| `POST /mcp/authentication/continue` | Attempt-bound callback/code only for the continuation variant the plugin declared. |
| `POST /mcp/authentication/cancel` | Cancel the named active attempt. If the native runtime cannot cancel, show its true state until it terminates; closing a UI is not native cancellation. |

Register handlers in the existing `Orchestrator` composition and shared request router so headless and relay clients use
the same API. Add backend-neutral `mcp.servers.changed` invalidation and `mcp.authentication.changed` events through the
existing plugin stream and Orchestrator event mapping. A read, explicit refresh, completed mutation, auth completion, or
actual native notification refreshes the open client view. Do not add background polling or wake every plugin to
populate settings.

### Tool approvals, forms, and external actions

Preserve the current permission/question routes and `PendingInteractionService` ordering. Keep native request IDs,
schema keys, connector IDs, persistence metadata, and answer encoding in the owning plugin.

- Ordinary tool approvals continue through `PluginPendingPermission` and `PermissionReply`; enrich the display context
  without changing existing once/always/reject meanings. Never treat a server trust prompt, installation offer, form, or
  URL request as an auto-approvable tool call.
- Represent supported string, finite number/integer, boolean, enum, and bounded string-choice-array forms using the
  existing question surface where it can express the request faithfully. Each plugin retains a typed schema next to its
  pending request and encodes answers under native property keys. Validate before replying; invalid input keeps the
  request pending and returns a useful field error. Do not forward a guessed `answers` object. Unsupported structures
  are explicitly declined with a visible explanation. Secret/credential entry is not added to ordinary question fields.
- Add a neutral pending external-action variant for URL authorization and offered-connector setup. Extend the existing
  plugin pending-request owner and teardown paths, rather than introducing a second request-ID registry. Its wire
  payload contains request/session/display-session IDs, explanatory text, a validated URL, purpose, and the declared
  native reply choices. Add matching session-scoped snapshot/reply routes and a normalized SSE event; bridge replies
  pass through the same `SessionOperationDispatcher` as existing interactions.
- The client acknowledges consent according to that native request's contract. A URL-elicitation `accept` is not an
  OAuth-completed signal. Only a native completion or refreshed status proves connection. Connector offers without a
  verified install/setup URL receive an explicit native-harness handoff, not an invented installer.
- Resolve/archive/stop/process-exit paths settle these requests alongside existing pending input. Retain the original
  session as reply owner when a child request is displayed under its parent.

### Client

Add `McpApi`, `McpRepository`, `McpService`, and `McpCubit` in the usual `module_core` layers; the service owns reactive
refresh/auth orchestration and the cubit owns presentation state. Use existing connection-incarnation fencing so a late
response from bridge A cannot populate or authorize a target on bridge B.

Shared views live under `module_app_ui/lib/src/features/mcp/`, composed from session detail and
`harness_settings_detail_view.dart`. Both shells provide navigation/platform adapters and DI only. Reuse the current
permission/question widgets and system-browser/loopback capabilities. Do not copy the large provider-management state
machine or add a client-side credential repository.

Use the existing browser service where its contract is adequate. If a small rename/extraction is necessary to share the
exact browser transport between provider and MCP authentication, keep it confined to that proven second use and update
callers in lockstep. A broader authentication refactor requires a separate scope decision.

## Harness delivery

| Harness | Planned behavior and evidence gate |
|---|---|
| Claude Code, priority 1 | Session inventory and tools from native status; reconnect/toggle through the control seam; MCP login/logout through supported native commands; existing tool approvals plus native form/URL elicitation. First prove the initialize capability, cancellation, and reply frames. Project-server trust approval is supported only through a verified native seam; otherwise show pending trust and a precise local approval instruction. No automatic approval of `.mcp.json`. |
| Codex, priority 1 | Thread-scoped inventory/status/tools, OAuth login/completion, native-supported reload/control operations, correct typed form/URL replies, and offered connector metadata/setup URLs. `app/list` is a native connector catalog, not a local MCP configuration list. Keep those variants distinct under the shared UI. Prefer supported config/RPC operations; no direct TOML rewrite or development-only plugin installation API. |
| OpenCode, next | Implement the same supported inventory, connect/disconnect, and OAuth behaviors against both supported v1/v2 seams after verifying their actual schemas. Normalize its MCP change/auth events instead of dropping them. Keep v1/v2 differences entirely inside this plugin. |
| Pi and ACP family | Preserve existing Pi `/mcp` and startup dialogs and ACP forms. Audit the registered adapters after the priority work. Map verified structured capabilities into the same contract; mark missing integration as **not implemented**, and a verified native limitation as **not supported** with version/evidence. A text command is not silently promoted into a structured inventory API. |

The first Claude/Codex milestone may ship before secondary adapters. The complete series must record every registered
harness's state in `docs/HARNESS_CAPABILITIES.md`; secondary structured implementations that exceed their bounded step
are split into coherent steps in this same series, without delaying the priority milestone or inventing parsing of
terminal UI output.

## Authentication and compatibility boundaries

- The native harness owns access/refresh tokens, OAuth validation, configuration, and credential persistence. Sesori
  transports only the challenge and the supported continuation over its existing encrypted connection. No new token
  database, client secret editor, or refresh scheduler.
- Browser continuation is bound to `{bridge connection, plugin, target, attempt}`. The adapter must establish the exact
  expected callback origin/path/state from its native flow. Never forward a client-supplied URL to an arbitrary HTTP
  destination; only complete the currently owned native operation at its validated callback. Preserve PKCE/state and
  native requested scopes.
- For a remote phone, reuse existing client loopback capture and route the captured redirect to the originating bridge
  operation where the native seam supports it. Test fixed and dynamic callback ports. Do not assume opening a
  host-loopback URL on a phone reaches the bridge. Where the native seam cannot support completion, use an explicit
  bridge-computer handoff.
- Native completion is authoritative, including denial, expired login, failed tool discovery, or missing account access
  after a connector page is visited. Refresh may honestly report that more setup is still required.
- Authentication retry starts only after the prior native attempt ends or is definitively cancelled. One active MCP
  attempt per bridge is enough; reject conflicting starts with a typed busy response. Preserve a pending native attempt
  across temporary relay loss, but not bridge/process restart.
- Errors retain typed causes, stacks, target/operation context in local diagnostics. Selectively exclude callback
  codes/state, tokens, authorization headers, form contents, full authorization/elicitation URLs, and raw secret-bearing
  process output. For those URLs, log only safe metadata such as scheme, host, and purpose; paths, queries, and
  fragments can contain credentials or OAuth state. Sanitized presentation is separate from useful local diagnostics.
- Existing public production wire contracts remain valid. New clients detect MCP support from an additive capability
  flag with an honest omitted default; an older bridge gets an explicit upgrade/unavailable state. New routes do not
  replace existing question/permission routes. Check the released clients' unknown-event behavior before adding
  broadcasts; do not assume they ignore a new event.
- New external-action requests must not strand old clients. Supply a safe existing-question handoff with explicit
  decline/cancel behavior if it faithfully represents the request; otherwise return an observable native unsupported
  response. Never degrade a connection/install request into a generic Allow permission. No silent acceptance.
- Internal APIs update all consumers together. Add no database migrations, backfills, or shims for unpublished
  implementations. Use the then-current product version and dated compatibility comments only for actual released-peer
  needs.

## Complexity budget and accepted limits

| Mutable addition | Owner and reason |
|---|---|
| One active MCP auth operation plus its native handle, completion subscription, and bounded expiry | Bridge `McpAuthenticationService`; a browser journey outlives its initial HTTP request. No per-server operation map, queue, or durable job. |
| Typed form/external-action payloads | Existing plugin pending-input owners; the native process is waiting for a response. Reuse their request map and cancellation lifecycle. |
| Current visible inventory, refresh-in-flight marker, and auth presentation | Client service/cubit, scoped to the selected bridge/harness/context. Reuse connection fencing; no persistent inventory. |
| Native subscriptions | Existing plugin connection/process owner, held in its existing composite subscription where applicable. No new watcher framework. |

Persistent additions: **none in Sesori**. Explicit native enablement, sign-in, and sign-out can change the harness's own
configuration or credentials; each action must explain that effect. A later server-creation feature will use that same
native ownership boundary.

Ordinary reachable flows justify the checks: two clients answer one pending request; someone changes bridges during
sign-in; a native process exits while a form is open; a user retries after browser denial; a server's tools fail
discovery. They can target the wrong operation, grant the wrong permission, or leave a session blocked. Test and enforce
these at their existing owners.

Accept brief stale inventory until refresh/reopen when a harness emits no change signal. Do not add locks around read
snapshots, automatic retries of consent, cross-session configuration reconciliation, perfect inventory provenance,
history repair, or scheduled background refresh. Creation/edit/removal of arbitrary MCP configurations, a marketplace,
and universal OAuth broker functionality remain out of scope.

Analytics assessment follows `.opencode/skills/add-analytics/SKILL.md`: retain normal screen reporting when adding a
route. No additional event or reporting pipeline is needed for the first implementation; there is no concrete product
decision requiring per-server/tool tracking. Revisit a bounded authoritative adoption metric separately. Never report
server, connector, tool, account, path, form, or URL identifiers.

## Cleanup caused by this feature

- Replace Codex's generic MCP question classification and flattened MCP reply only where the typed form/external-action
  paths supersede them; retain ordinary user-input behavior.
- Remove the corresponding obsolete approval tests and replace them with native-shaped fixtures. Remove comments
  claiming MCP changes have no consumer when the new consumer lands.
- Stop dropping MCP status/auth events in adapters that now expose them. Do not change unrelated ignored events.
- Keep Pi's usable slash command and all existing generic approval/question handling. Do not rewrite provider
  authentication, existing plugin lifecycle, or transcript rendering.
- No relevant obsolete database fields, persistent jobs, or migrations were found.

## Delivery series

All implementation PRs are independently valid and update this tracker. Estimates include tests/docs/generated output;
separate authored/generated churn at each push. Target below 1,500 changed lines, and lower for authentication/lifecycle
work. If codegen or coupling breaks the estimate, split coherently before the first push and synchronize the one series
total. No artificial compatibility scaffolding between steps.

| Step | Outcome | Planned diff |
|---|---|---:|
| 1/12 | Reviewed plan | 350–650 |
| 2/12 | Native contract evidence | 500–1,000 |
| 3/12 | Claude inventory | 850–1,400 |
| 4/12 | Phone and desktop details | 800–1,300 |
| 5/12 | Claude actions and authentication | 800–1,350 |
| 6/12 | Shared authentication and external actions | 850–1,400 |
| 7/12 | Claude approvals and elicitation | 650–1,150 |
| 8/12 | Codex inventory and actions | 750–1,300 |
| 9/12 | Codex forms and connector offers | 650–1,200 |
| 10/12 | Secondary harness support | 800–1,400 |
| 11/12 | Regression and capability coverage | 250–500 |
| 12/12 | Qualification and retirement | 100–300 |

Exact PR titles and scope:

1. `🌿 [mcp-management] Plan MCP information and connection support [step 1/12]`

   Publish this reviewed plan and tracker. No user-visible or database change.

2. `⚙️ [mcp-management] Verify Claude and Codex native MCP contracts [step 2/12]`

   Add bounded fixture probes/captures and the exact capability/version table. No production behavior or database
   change.

3. `🚧 [mcp-management] Expose scoped MCP inventory for Claude Code [step 3/12]`

   Shared/plugin inventory models, supported-capability detection, bridge read route/events, and Claude typed inventory
   mapping. Headless consumers can inspect a live session; no database change.

4. `⚙️ [mcp-management] Show MCP server details on phone and desktop [step 4/12]`

   Shared client layers/views and settings/session entry points. Stable status/tool details with
   loading/error/unsupported states; no database change.

5. `🚧 [mcp-management] Add native Claude MCP actions and authentication [step 5/12]`

   Action/authentication DTOs, bridge owner/routes, Claude reconnect/toggle/login/logout adapter. Headless flow works;
   native config/credential changes only after explicit actions.

6. `🚧 [mcp-management] Present MCP authentication and external actions [step 6/12]`

   Shared client authentication UI/browser reuse, neutral pending external-action contract and session
   routing/presentation. Visible connection actions and fixture-proven URL requests; no Sesori database change.

7. `⚙️ [mcp-management] Complete Claude MCP approvals and elicitation [step 7/12]`

   Native form/URL handlers and server/tool context through the shared surfaces; preserve exact grant/cancel behavior.
   Completes the Claude milestone subject to native gates; no database change.

8. `🚧 [mcp-management] Add Codex MCP inventory and connection actions [step 8/12]`

   Codex DTO/API/repository mapping and native status/OAuth events using the shared UI. No duplicate auth owner; native
   settings/credentials change only for explicit actions.

9. `⚙️ [mcp-management] Complete Codex MCP forms and connector offers [step 9/12]`

   Typed forms, URL elicitation, native grant scopes, and verified offered-connector setup URLs. Remove superseded
   generic MCP mapping. No Sesori database change.

10. `⚙️ [mcp-management] Extend supported MCP controls across harnesses [step 10/12]`

    OpenCode v1/v2 structured support and bounded Pi/ACP capability integration/audit. Preserve existing dialogs. Split
    additional proven adapter work if needed; no Sesori database change.

11. `🌿 [mcp-management] Reconcile MCP regression and capability coverage [step 11/12]`

    Complete supported-behavior docs and exact remaining limitations; no production or database change.

12. `⚙️ [mcp-management] Qualify MCP journeys and retire the plan [step 12/12]`

    Execute the recorded matrix, record privacy-safe evidence, and move to completed only after passing. No intended
    production/database change.

Steps depend on the preceding step. The Claude milestone is steps 2–7; Codex follows immediately in 8–9. Step 2 verifies
both from the start so Claude-first implementation does not bake in incompatible Codex assumptions. Do not spend the
priority milestone implementing secondary harnesses.

For each production PR, tests/analyzer run in the owning packages, with downstream client tests when impacted; CI owns
the full matrix. Architecture implementation review applies to changed production boundaries. UI PRs include
fixture-only before/after visuals and a short flow recording on `pr-media`. No production screenshots, tokens, user
paths, or transcripts in public artifacts.

## Verification and retirement

Highest required feature level: **L4**, cumulative L1–L3, with explicitly selected packaged/external checks below. This
is an authentication and multi-client feature; isolated unit tests cannot prove it. Unavailable accounts, native
versions, or devices are **Blocked/Partial**, not evidence to lower the level.

| Boundary | Required matrix and pass condition |
|---|---|
| Automated/native fixtures | Every adapter that declares a capability: supported/unknown methods, full pagination, missing optional metadata, scope isolation, accurate actions, form value typing, required/invalid fields, grant persistence, decline/cancel, process exit, and external settlement. Current native captures plus minimum supported behavior or honest unavailable result. |
| Headless bridge | Every supporting plugin; read/action/auth routes use the same authoritative owners as relay routes. Wrong plugin/session/target and stale attempt continuation cannot act on another entity. Session stop/archive and plugin shutdown settle native waits. No implicit login or tool execution from opening inventory. |
| Relay integration | Local E2E and managed trusted modes, two clients, temporary reconnect, and switching between two bridges with colliding server names. Only the active originating operation receives a callback/reply. Existing non-MCP permissions/questions still work. |
| Client end to end | Claude and Codex separately on macOS desktop, iOS, and Android; desktop with a local bridge and both phone platforms with a remote bridge. Inspect tools, reconnect/enablement where supported, approve/reject, fill supported forms, open URL/connector setup, complete/deny/cancel sign-in, and reopen pending state. Run the same shared journey for secondary supporting plugins on desktop plus one mobile platform. |
| Native hosts/versions | Full priority flows on macOS arm64. On Linux x64 and Windows x64, run native inventory/control/auth fixture checks for every supported host of each implemented adapter. Minimum PATH versions must degrade honestly; target versions must pass claimed capabilities. No requirement to make an upstream-unsupported host work. |
| Packaged/external | One packaged build per client platform for browser return/link registration, plus a real OAuth MCP provider for each priority harness and a real offered connector where exposed. Use dev accounts and verify the next harmless native tool use succeeds. Fixture success alone does not prove external provider policy or native credential persistence. |
| Feel | Record opening/closing the overlay mid-scroll, status changes in a long inventory, browser return, cancellation, and another client settling the request. No transcript jump, lost form draft on routine refresh, inaccessible action, or unexpected audio. |

Required failure variations are bounded to meaningful flows: provider denial, expired attempt, native process exit,
bridge switch, two-client reply, unsupported schema, blocked project trust, and unavailable connector entitlement.
Verify sign-in does not weaken tool approvals, tool auto-approval does not grant install/login consent, and native
credentials remain native across restart.

Affected documents: new `docs/regression/mcp-management.md`; update `questions-and-permissions.md`,
`permission-auto-approval.md`, `plugin-setup-and-lifecycle.md`, `bridge-connectivity.md`, `session-turns.md`, the
regression index, and `docs/HARNESS_CAPABILITIES.md`. Update browser-return packaging documents only where this
implementation changes their supported behavior. Keep provider-account authentication distinct from MCP authentication.

Step 11 reconciles the full supported contract. Step 12 records versions, builds, platforms, plugins, boundaries,
outcomes, limitations, cleanup, and privacy-safe evidence references in `TRACKER.md`. Retire only when this matrix
passes. Any reduction requires explicit user acceptance recorded here; verified native limitations must be explicit
product limitations rather than unfinished promised behavior.

## Planning validation

For step 1: validate Markdown links, series numbering/dependencies, ownership and scope consistency, `git diff --check`,
and architecture plan review. No Dart/Flutter suites are needed for planning documents. Publish the plan PR under the
normal repository workflow; implementation remains pending a later instruction.

Architecture plan review on 2026-10-13: **approved**, with the specificity gate passed and no architectural findings.
This establishes the design boundaries, not native feasibility or authentication qualification. Local
document/link/series checks and staged Git whitespace validation passed before publication.

[sdk-query]: https://github.com/anthropics/claude-agent-sdk-python/blob/main/src/claude_agent_sdk/_internal/query.py
[claude-cli-auth]: https://code.claude.com/docs/en/mcp#authenticate-from-the-command-line
[claude-sdk-auth]: https://code.claude.com/docs/en/agent-sdk/mcp#oauth2-authentication
[codex-app-server]: https://learn.chatgpt.com/docs/app-server
