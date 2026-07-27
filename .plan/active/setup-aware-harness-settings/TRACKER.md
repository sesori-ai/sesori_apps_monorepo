# Setup-Aware Harness Settings: Tracker

## Current State

- **Implementation base:** `origin/main` at `99670e08` after Step 4/7 merged
- **Series state:** Step 5/7 PR #592 review settled; combined simulator E2E passed
- **Next action:** merge PR #592, then begin Step 6/7

## Delivery

| Done | Slice | Branch | PR state |
|---|---|---|---|
| [x] | Step 1/7 — per-bridge harness preference | `setup-aware-harness-settings-preferences` | PR #579 merged; 729 changed lines (estimate 650-750) |
| [x] | Step 2/7 — management transport | `setup-aware-harness-settings-transport` | PR #583 merged as `ecd75b6c`; ~660 changed lines (estimate 300-400, test-driven overage) |
| [x] | Step 3/7 — synchronization service | `setup-aware-harness-settings-service` | PR #589 merged as `6fe69d5a`; 1,095 changed lines (estimate 550-700, race-matrix test overage) |
| [x] | Step 4/7 — harness logos | `setup-aware-harness-settings-branding` | PR #590 merged as `99670e08`; simplified to use existing plugin IDs |
| [ ] | Step 5/7 — Harnesses overview and state contract | `setup-aware-harness-settings-overview` | PR #592 ready; 1,735 initial changed lines (estimate 1,100-1,300, generated state/localization overage) |
| [ ] | Step 6/7 — management actions | `setup-aware-harness-settings-state` | planned; estimate 650-800 changed lines |
| [ ] | Step 7/7 — management controls | `setup-aware-harness-settings-controls` | planned; estimate 800-1,000 changed lines |

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
  will execute.
