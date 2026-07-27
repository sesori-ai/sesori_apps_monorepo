# Setup-Aware Harness Settings: Tracker

## Current State

- **Implementation base:** `origin/main` at `3adaf4e4` after Step 7/8 merged
- **Series state:** Step 8/8 management controls implemented and verified; PR pending
- **Next action:** open and settle the Step 8/8 PR

## Delivery

| Done | Slice | Branch | PR state |
|---|---|---|---|
| [x] | Step 1/7 — per-bridge harness preference | `setup-aware-harness-settings-preferences` | PR #579 merged; 729 changed lines (estimate 650-750) |
| [x] | Step 2/7 — management transport | `setup-aware-harness-settings-transport` | PR #583 merged as `ecd75b6c`; ~660 changed lines (estimate 300-400, test-driven overage) |
| [x] | Step 3/7 — synchronization service | `setup-aware-harness-settings-service` | PR #589 merged as `6fe69d5a`; 1,095 changed lines (estimate 550-700, race-matrix test overage) |
| [x] | Step 4/7 — harness logos | `setup-aware-harness-settings-branding` | PR #590 merged as `99670e08`; simplified to use existing plugin IDs |
| [x] | Step 5/7 — Harnesses overview and state contract | `setup-aware-harness-settings-overview` | PR #592 merged as `1b0f9874`; combined simulator E2E passed |
| [x] | Step 6/8 — management actions | `setup-aware-harness-settings-state` | PR #593 merged as `075951cb`; estimate 650-800 changed lines |
| [x] | Step 7/8 — management capabilities | `setup-aware-harness-settings-capabilities` | PR #594 merged as `3adaf4e4` |
| [ ] | Step 8/8 — management controls | `setup-aware-harness-settings-controls` | implemented and verified; PR pending; estimate 800-1,000 changed lines |

## Source Material

- Frozen PR #511: https://github.com/sesori-ai/sesori_apps_monorepo/pull/511
- Substantive old commit: `167a3ee7`
- Action-preservation follow-up: `bc3918cb`
- Frozen head: `4f07172f`
- Never merge, rebase, or cherry-pick the frozen branch. Reconstruct each
  behavior against current `main` and preserve newer connection, model-default,
  settings, and forced-disable behavior.

## E2E Environment

- Use the available iOS simulator for mobile Harnesses E2E.
- Run the source bridge with `--data-dir ~/.local/share/sesori-dev` so it
  reuses the existing login and development bridge data.
- Use the existing `random stuff` project for session interactions and
  management verification.
- Do not leave a temporary E2E bridge running after verification.

## Verification Log

- Step 1/7 (2026-07-26): shared contract tests + fatal analysis; bridge app
  full suite (2147) + fatal analysis; module_core full suite (638) + fatal
  analysis; mobile new-session/routing widget tests + fatal analysis;
  Aristotle implementation review approved. First-pass simulator E2E against
  the dev bridge: `bridgeId` on the wire, per-bridge Codex preference
  persisted across app reopen, fallback to the OpenCode default after Codex
  was disabled; sessions/worktrees cleaned, preference rewritten to the
  default, E2E bridge stopped. Review fixes: discovery-bridge invalidation on
  failure, single routability extension, composer-state clearing on
  bridge-identity change (cubit regression tests). Confirming E2E pass on the
  final head `b529a8a8` re-verified restored-preference selection, Codex
  persistence across reopen, and disable fallback with full cleanup; A-to-B
  bridge switch stays unit-tested only (single-bridge dev account).
- Step 2/7 (2026-07-27): shared contract tests for known/null/omitted
  `bridgeId`; full bridge suite (2148); module_core full suite (657) with new
  API route and repository mapping
  tests; mobile/desktop fatal analysis; Aristotle implementation review
  approved. Review fixes: lifecycle service caches identity-free state and
  requires the provider's current ID before reads or mutation side effects,
  including when a timeout write begins after waiting in the settings queue;
  post-commit identity loss maps through HTTP 503 to typed `uncertain`;
  single-report malformed conflicts, named parameters, encoded command path,
  post-dispatch response loss mapped to `uncertain`.
  Confirming E2E on `cbd10948`: all three management routes carried the dev
  bridge identity on GET and both mutation shapes; Step 1 gate rerun passed;
  full cleanup with the E2E bridge stopped. Final service-owned identity rerun
  on `f0c4932d` again verified the same ID on GET, command, and idle-timeout
  responses after late registration; override cleared, Codex re-enabled, and
  bridge stopped (one external relay 429 was retried successfully). Final
  mutation-guard rerun on `b0067458` verified registered GET, safe disable,
  enable, timeout override, and timeout clear responses all carried
  `br_qdF5_X5_LUM6zi7D`; the override was cleared, Codex re-enabled, the
  temporary bridge stopped, and the unrelated bridge on port 7829 remained
  untouched.
- Step 3/7 (2026-07-27): added the replay-backed management synchronization
  service, a single publication coordinator, connection/publication/staleness
  fences, identity-scoped retained snapshots (including legacy null identity),
  coalesced refresh, mutation uncertainty refresh, and Layer-3 timeout/force
  planning. Focused service suite (21) and full module_core suite (678) pass;
  module_core, mobile, and desktop fatal analysis are clean. Aristotle's first
  pass found that identity supersession did not invalidate other concurrently
  captured old-bridge requests; the fix advances the request epoch before
  forgetting identity and routes every publication through one coordinator.
  The second pass approved. PR review additionally fenced typed mutation
  rejections when the connection epoch moves and corrected the remaining
  positional private parameter. Disposal continues to await its owned,
  transport-bounded refresh tail as required by the reviewed plan. Real
  integration E2E remains scheduled after Step 5/7, when the app resolves and
  renders this service.
- Step 4/7 (2026-07-27): added the exported, decorative `PregoBrandLogo`
  resolver with a generic fallback and integrated it into the new-session
  chooser. The initial implementation introduced a separate nullable logo key
  across plugin and wire contracts; product feedback removed that redundant
  contract and made the Prego presentation boundary map the existing stable
  plugin ID directly. A shared `Harness` enum now owns the three built-in IDs;
  bridge producers and app presentation use `Harness.<value>.name`, while wire
  contracts remain open strings and unknown IDs retain the generic fallback.
  Full shared (337), focused Prego (5), mobile new-session (23), OpenCode (67),
  Codex (17), and Cursor (41) tests pass; fatal analysis is clean in every
  affected package. Aristotle approved the shared-enum dependency and open
  string transport boundary. The real simulator logo E2E remains pending until
  after PR review.
- Step 5/7 (2026-07-27): added the typed `/settings/harnesses` route, settings
  landing row, replay-backed read-only `PluginManagementCubit`, final management
  state contract, and localized Harnesses overview. The screen covers loading,
  unsupported, initial failure/retry, retained-snapshot refresh failure,
  pull-to-refresh, known/generic logos, default attribution, setup/runtime/work
  unknowns, guidance, effective timeout, and close behavior without exposing
  mutations. Full module_core (683) and 51 focused mobile route/settings tests
  pass; module_core, mobile, desktop, and module_desktop_core fatal analysis is
  clean. Architecture review confirmed the layer flow, stream ownership,
  routing, desktop boundary, and backend neutrality; its sole rejection asked
  to remove the plan-mandated final Step 6 action fields as future-only. Those
  fields remain because this slice explicitly delivers the final state contract
  that Step 6 extends without replacement. Combined simulator logo and
  management-service integration E2E on the reviewed PR head used the current
  iOS simulator build and source bridge with the development data directory.
  Settings retained all sections with Harnesses after Notifications; the page
  rendered Codex, Cursor, and OpenCode with their distinct bundled logos,
  OpenCode as Default, and live setup/runtime/work/timeout facts. Pull-to-refresh
  retained the same snapshot without an error. The temporary E2E bridge was
  stopped afterward. Owner review then replaced nullable ready-state
  coordination fields with independent sealed refresh, action-target, and
  action states; force confirmation carries the exact typed request that Step 6
  will execute. A later review found that the service could replay bridge A's
  retained snapshot to a newly created cubit while bridge B's first load was
  pending. Connection-epoch and authoritative identity invalidation now publish
  loading immediately, with service and cubit regressions proving the prior
  bridge cannot escape through replay. Full module_core (686) and focused tests
  pass; module_core, mobile, and desktop analysis is clean; architecture review
  approved the lifecycle ownership and publication fencing.
- Step 6/8 (2026-07-27): extended the existing cubit over the final nested
  sealed state contract with exact enable, safe-disable, safe-restart, setup
  refresh, apply-all timeout, per-harness override, clear-override, and explicit
  force-confirmation flows. Timeout parsing and forceability remain service
  policy; the cubit preserves action state across successful/failed refresh
  publications, fences late completions after deliberate state transitions,
  and maps uncertain outcomes explicitly. The Harnesses overview now renders
  effective timeout values at or below zero as `No timeout` with always-running
  guidance instead of zero minutes or a false bridge-default attribution. Root
  agent guidance now requires sealed variants with only their valid non-nullable
  fields. Full module_core (695), 53 focused mobile tests, and analysis in
  module_core, mobile, desktop, and module_desktop_core pass. Architecture
  review approved the service/cubit lifecycle ownership and boundaries. PR
  review added explicit force-confirmation dismissal so cancel returns the
  action lifecycle to idle and cannot leave all subsequent controls blocked.
- Step 7/8 requirement clarification (2026-07-27): OpenCode attached with
  `--opencode-no-auto-start` is externally managed and cannot be lifecycle- or
  idle-timeout-controlled by Sesori. Step 7 will add an explicit backend-neutral
  capability set from plugin descriptor through bridge enforcement and shared
  transport to UI gating; it will not infer this mode from plugin ID or the
  effective timeout value. Because that cross-layer contract and enforcement is
  not tiny, the user approved expanding the series to eight PRs; Step 8/8 now
  owns the controls UI. Historical merged PR title suffixes remain `/7`.
- Step 7/8 (2026-07-27): added independent backend-neutral capability enums to
  the plugin interface and shared wire contract, with `bridge/app` owning the
  mapping. The capability field is required with no default because it and the
  controls ship together before production; future values decode to `unknown`.
  OpenCode no-auto-start declares setup
  refresh only; managed OpenCode, Codex, and Cursor retain all default
  capabilities. The bridge rejects unsupported lifecycle and per-plugin timeout
  operations before runtime or settings effects, returns typed non-forceable
  conflicts, and apply-all updates the global default while clearing overrides
  only for timeout-capable plugins. Review follow-up made the immutable
  registration snapshot authoritative for both published controls and command
  authorization. Startup now rejects a persisted disabled state for a plugin
  without lifecycle control with an actionable config command, preserving
  `plugins.disabled` as the authoritative policy without silently making a
  rejected startup mutate it. Full shared (340), plugin
  interface (147), OpenCode (398), bridge app (2163), and module_core (696)
  suites pass; fatal analysis is clean in
  those packages, Codex, Cursor, module_core, mobile, desktop, and
  module_desktop_core. Architecture review approved the Layer-0 independence,
  bridge mapping/enforcement, and required capability contract. PR review also
  required idle suspension to check lifecycle plus timeout capabilities before
  scheduling and stopping, and corrected new private helpers to required named
  parameters.
- Step 8/8 (2026-07-27): added the nested typed Harness management route and a
  thin Flutter controls screen over the existing singleton management service
  and cubit. The screen renders lifecycle, setup-refresh, and timeout controls
  only from declared capabilities; externally managed harnesses retain status
  context and setup refresh without lifecycle inference from plugin identity,
  runtime state, or timeout values. Global/per-harness signed timeout dialogs,
  safe lifecycle actions, one-shot force confirmation, action/refresh errors,
  back/close navigation, and known/generic logos are covered. Full mobile (752)
  and module_core (697) suites pass; fatal analysis is clean in mobile,
  module_core, desktop, and module_desktop_core. Architecture review's sole
  finding was applied by using the shared fail-closed `PluginRuntimeState.isEnabled`
  semantic rather than classifying lifecycle state in the Flutter shell.
