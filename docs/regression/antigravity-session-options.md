# Antigravity Model Catalogs and Session Options

## Status and scope

Antigravity discovers account models before the first user chat through one retained, hidden, no-prompt native
session. Model families expose High/Medium/Low through the existing variant picker. No database or wire-schema change
is required. Authenticated native discovery remains unverified; automated evidence uses composed fake ACP processes.

## Required behavior

- Cold options reads use standard ACP `session/list` to recover a discovery session whose cwd is the private
  `<GEMINI_HOME>/antigravity-acp/conversations` directory. Create one with `session/new` only when none exists.
  Send no prompt. The owner accepts native session artifacts because the pinned runtime has no delete capability.
- Cached reuse performs no ACP work. Explicit refresh resumes the same reserved session to obtain a fresh catalog.
  Concurrent discovery requests coalesce. A list/resume failure never creates a replacement. No credential copying,
  private API access, secondary probe process, or private history deletion is involved.
- The options service owns discovery state and calls a connection-scoped catalog repository over `AcpAgentApi`.
  The repository maps discovery DTOs into domain catalogs; the service validates selection invariants. Only complete
  valid responses replace the last-good catalog. Failures are logged and returned as failed discovery; `/providers`
  surfaces a typed operation failure rather than an apparently successful empty catalog. Failures do not erase the
  previous snapshot. Reset clears catalog/configuration state and fences late discovery results.
- Reserved-cwd sessions are excluded from global/project session enumeration and recovered directory attribution,
  including after a plugin restart. Their native artifacts remain untouched and are reused, not imported as chats.
- The Layer-2 protocol mapper decodes flat and one-level grouped model entries through generated DTOs. Preserve exact
  opaque native IDs and advertised order. Ignore unrelated config selectors without assuming their schemas.
- Group a model only when its native `-high`, `-medium`, or `-low` suffix agrees with its advertised
  ` (High)`, ` (Medium)`, or ` (Low)` label suffix. Expose the stripped model name/ID and strongest-first variant IDs
  while retaining the backend's default and exact native ID for dispatch. A single advertised level still uses the
  variant picker instead of returning its suffix to the model name. Unmatched, future, whitespace-bearing or ambiguous
  entries stay standalone. Duplicate labels alone do not merge opaque identities. No static model manifest is used.
- Empty catalogs, blank IDs/labels, duplicate native IDs, unsupported selector types, duplicate model selectors,
  missing current models and malformed entries fail without replacing last-good data. An ordinary session response
  without a model selector does not replace the snapshot; discovery without a selector fails.
- Newly created discovery and real sessions establish the advertised new-session default. Resuming a retained
  discovery session does not establish or replace that default or the process fallback. After restart, the default is
  omitted until a fresh native session establishes it. Real load/resume/configuration responses update the session
  selection, not the new-session default. Defaults and message metadata use normalized
  model IDs plus variants; configuration writes always use exact account-advertised native IDs.
- Before prompt dispatch, validate the requested model/variant tuple, await exact standard `session/set_config_option`,
  verify a returned catalog's current native ID equals the request, then await `session/set_mode` with `default`.
  Null model and variant preserve the session default without a model write. A model-only selection uses its advertised
  default variant. Mode is still applied each time.
- Unknown/stale model IDs, unknown variants, variants on standalone models, and unsupported provider/agent choices
  raise `PluginStaleOptionsException` before configuration writes. Invalid-ID diagnostics remain bounded and useful.
  A model-write, mismatched/invalid returned-catalog, or mode-write failure prevents later prompt dispatch. Ordered
  execution does not imply rollback of an already accepted model write.
- Live and replay assistant/tool/error metadata retain the normalized model and chosen variant through the existing
  ACP configuration tracker. No client widget or cubit recognizes Antigravity model-label conventions.

## Failure signals and coverage

- Missing models before first chat, refresh returning only a stale cache, repeated discovery-session creation, a probe
  appearing as a user chat, or a prompt sent during discovery is a regression.
- A fabricated model, lost variant, normalized ID sent to native configuration, invalid catalog replacing last-good
  data, altered opaque IDs, mode dispatched before model settlement, or a prompt after configuration failure is a
  regression.
- `antigravity_session_options_service_test.dart` retains baseline flat/grouped parsing, defaults, reset, last-good
  retention, malformed catalogs, ordered configuration and failure-propagation coverage.
- `antigravity_catalog_discovery_and_variants_test.dart` covers cold/coalesced discovery, reuse, refresh, reserved-session
  recovery, reset fencing, failed refresh, conservative grouping, normalized defaults and exact variant dispatch.
- `antigravity_plugin_test.dart` covers composed fake ACP discovery without prompts, reserved-session filtering,
  reconnect/residency and live/replay metadata. Shared `acp_event_mapper_test.dart` covers tracker-owned live variants;
  `acp_session_config_repository_test.dart` covers typed standard mode requests and rejection propagation.
- Owning Antigravity and ACP analyzers and tests define the automated evidence boundary. Actual account catalogs,
  native authenticated discovery and cross-target runtime behavior are not claimed by these fake-process tests.
