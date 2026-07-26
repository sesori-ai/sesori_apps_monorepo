# Setup-Aware Harness Settings: Tracker

## Current State

- **Implementation base:** current `origin/main` after Stage 12 merge `6cedf5bd`
- **Series state:** Step 2/7 in review
- **Next action:** wait for PR #583 review to settle, then run the confirming
  E2E checks before merge

## Delivery

| Done | Slice | Branch | PR state |
|---|---|---|---|
| [x] | Step 1/7 — per-bridge harness preference | `setup-aware-harness-settings-preferences` | PR #579 merged; 729 changed lines (estimate 650-750) |
| [ ] | Step 2/7 — management transport | `setup-aware-harness-settings-transport` | PR #583 in review; ~590 changed lines (estimate 300-400, test-driven overage) |
| [ ] | Step 3/7 — synchronization service | `setup-aware-harness-settings-service` | planned; estimate 550-700 changed lines |
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
  `bridgeId`; bridge routing suites (388) and full bridge directory (1140);
  module_core full suite (654) with new API route and repository mapping
  tests; mobile/desktop fatal analysis; Aristotle implementation review
  approved. Confirming E2E checks follow after review settles.
