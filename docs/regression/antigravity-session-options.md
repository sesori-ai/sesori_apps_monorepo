# Antigravity Model Catalogs and Session Options

## Status and scope

Registered local-runtime behavior over the Step 7.a foundations and Step 8 lifecycle composition. Activation adds no
database change. No persistent discovery session is created: a fresh process exposes no selectable model until a real
new/load/resume response advertises the account catalog.

## Required behavior

- Before a real new/load/resume response advertises a model catalog, expose partial options, one primary Antigravity
  agent, and no selectable models. A null model selection preserves the account/session default; never fabricate
  model IDs, maintain a model manifest, or create a scratch persistent session for discovery.
- The Layer-2 protocol mapper decodes flat and one-level grouped model entries through generated DTOs. Preserve exact
  opaque IDs, labels, order, and current value. Ignore unrelated config selectors without assuming their schemas.
- The options service validates the mapped candidate before replacing the process-scoped last-good tracker. Empty
  catalogs, empty/blank IDs or labels, duplicate IDs, unsupported selector types, duplicate model selectors, missing
  current models and malformed entries fail without replacing the previous snapshot. A response without a model
  selector is not a new snapshot. Clearing the tracker on connection reset removes both catalog and known default,
  returning to partial options. Step 8 wires that clear operation into the owning plugin's reset hook.
- Expose every valid advertised model, without guessed families/variants. Duplicate labels are allowed because model
  selection uses exact opaque IDs rather than display labels. Only a `newSession` capture establishes the new-session
  default; load/resume/configuration captures use `existingSession` and cannot redefine it. If no new-session default
  is known or it is no longer in the catalog, advertise no default rather than a session's current choice.
- Before prompt dispatch, validate any explicit model against the current catalog, await exact standard
  `session/set_config_option` selection, verify a returned catalog's current model equals the requested ID before
  accepting it, then await `session/set_mode` with
  `default`. No explicit model means no model write. Mode is still applied every time, including before first capture.
- Unknown/stale/blank IDs raise `PluginStaleOptionsException` before any configuration writes, using the bridge's
  refresh-and-retry path. A model-write, mismatched/invalid returned-catalog, or mode-write failure
  propagates and prevents later prompt dispatch. This is ordered execution, not rollback of an accepted model write.
  Invalid-ID diagnostics are bounded while retaining a useful ID prefix.
- Shared ACP mode writes use typed serialized `sessionId`/`modeId` parameters through API and repository. Existing
  harness behavior is unchanged; Antigravity's options service never exposes or writes `auto_edit` or `yolo`.

## Failure signals and coverage

- A fabricated/default-alias model, a scratch discovery session, stale model acceptance, invalid catalog replacing
  last-good data, reordered/trimmed opaque IDs, mode dispatched before model settlement, or a prompt after failed
  configuration is a regression.
- `antigravity_session_options_service_test.dart`: real mapper/DTO/tracker with fake config repository covers partial
  discovery, flat/grouped models, labels/IDs/defaults, restart, last-good retention, invalid/stale selections, ordered
  writes, and model/mode/returned-catalog failures. These tests do not claim real plugin-hook integration.
- `acp_session_config_repository_test.dart`: repository through actual ACP API/stdio framing with a fake process checks
  exact standard mode parameters, correlated completion, and backend rejection propagation.
- Owning Antigravity and ACP analyzers and focused tests are the automated proof boundary. Real account catalogs,
  native OAuth and cross-target runtime evidence remain pending plan/regression gates.
