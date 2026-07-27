# Setup-Aware Harness Settings: Tracker

## Current State

- **Implementation base:** `origin/main` at `ecd75b6c` after Step 2/7 merged
- **Series state:** Step 3/7 implementation complete
- **Next action:** raise the Step 3/7 synchronization-service PR and settle
  review; the real integration E2E gate follows Step 5/7

## Delivery

| Done | Slice | Branch | PR state |
|---|---|---|---|
| [x] | Step 1/7 — per-bridge harness preference | `setup-aware-harness-settings-preferences` | PR #579 merged; 729 changed lines (estimate 650-750) |
| [x] | Step 2/7 — management transport | `setup-aware-harness-settings-transport` | PR #583 merged as `ecd75b6c`; ~660 changed lines (estimate 300-400, test-driven overage) |
| [ ] | Step 3/7 — synchronization service | `setup-aware-harness-settings-service` | implementation complete; ~1,080 changed lines (estimate 550-700, race-matrix test overage) |
| [ ] | Step 4/7 — harness logos | `setup-aware-harness-settings-branding` | planned; estimate 750-900 changed lines |
| [ ] | Step 5/7 — Harnesses overview and state contract | `setup-aware-harness-settings-overview` | planned; estimate 1,100-1,300 changed lines |
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
  planning. Focused service suite (20) and full module_core suite (677) pass;
  module_core, mobile, and desktop fatal analysis are clean. Aristotle's first
  pass found that identity supersession did not invalidate other concurrently
  captured old-bridge requests; the fix advances the request epoch before
  forgetting identity and routes every publication through one coordinator.
  The second pass approved. Real integration E2E remains scheduled after Step
  5/7, when the app resolves and renders this service.
