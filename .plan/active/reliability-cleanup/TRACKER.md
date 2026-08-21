# Reliability Cleanup Series — Tracker

Plan: [PLAN.md](PLAN.md) · Slug: `reliability-cleanup` · Series total: 14 steps

## Execution State

| Step | Title (emoji + description) | Status | PR | Notes |
|---|---|---|---|---|
| 1/14 | 🌱 docs: plan the series | Approved, not raised | — | Plan reviewed (2 rounds) + owner waiver recorded; raise on owner go. |
| 2/14 | ⚙️ refactor: drop pre-v1.4 compatibility paths | ☐ Not started | — | Per-marker peer-verification notes go in the ledger below. |
| 3/14 | 🌿 fix(bridge): make swallowed failures observable | ☐ Not started | — | Includes settings-repository fold + AbortableRequestClient. |
| 4/14 | ⚙️ refactor(bridge): unify plugin command transitions | ☐ Not started | — | |
| 5/14 | 🚧 refactor(bridge): extract relay connection coordinator | ☐ Not started | — | Contract in PLAN.md Step 5; assembly stays in Orchestrator.create. |
| 6/14 | 🚧 refactor(bridge): extract plugin-event delivery pipeline | ☐ Not started | — | Label generation fences; no check deletion without proof. |
| 7/14 | 🚧 refactor(plugins): share ndjson subprocess transport | ☐ Not started | — | acp/claude gain runtime dep; record teardown-order delta here when merged. |
| 8/14 | 🌿 refactor(plugins): consolidate shared plugin primitives | ☐ Not started | — | Pi MIME variant: adopt only if byte-equivalent, else note. |
| 9/14 | 🌿 refactor(client): remove dead code and fix observability | ☐ Not started | — | Verify barrel-export orphans against DI/tests before deleting implementations. |
| 10/14 | ⚙️ refactor(ui): consolidate sheet/status/picker primitives | ☐ Not started | — | Migrate all consumers in the same PR. |
| 11/14 | ⚙️ refactor(app): split state-heavy widgets | ☐ Not started | — | Facades unchanged; app-local collaborators only. |
| 12/14 | 🌿 chore(tooling): CI, codegen freshness, installer parity | ☐ Not started | — | |
| 13/14 | 🌱 docs: reconcile regression coverage | ☐ Not started | — | Penultimate: docs listed in PLAN.md; no coverage reductions. |
| 14/14 | 🌿 test: verify series and retire | ☐ Not started | — | Final: run L2 matrix from PLAN.md, record evidence, move to `.plan/completed/`. |

## Review Log

- **2026-08-21, review 1:** REJECTED as too vague (11 gaps). All addressed in
  Revision 2: per-step class/file/layer contracts, DefaultEditorRepository
  folded into BridgeSettingsRepository (layering preserved), AbortableRequestClient
  defined with exact home/signature, coordinator + pipeline contracts written,
  transport home decided (`sesori_plugin_runtime`) with dependency-direction and
  AGENTS.md updates, registry promotion dropped (interface stays contract-only;
  deferred), cleanup-rejection mapping flow pinned to repository layer,
  single Prego designs chosen, widget collaborators named with ownership and
  layer justification, workspace/package map added.
- **2026-08-21, review 2:** REJECTED as too vague on remaining type-level
  detail (8 narrow gaps: exact constructor signatures/seam types for Steps 5-6,
  adapter names for Step 7, voice callback contract, tooling paths). All
  factual spot-checks passed.
- **2026-08-21, owner waiver:** owner explicitly accepted the current design
  level ("waive, proceed as-is"). Exact signatures/types get pinned inside each
  implementation PR and reviewed via `architecture-implementation-review`.
  Recorded in PLAN.md Owner Decisions. No further plan review.

## Step 2 Peer-Verification Ledger

Fill during implementation; a marker that fails verification stays with its
reason recorded here.

| Marker | Location | Peer surface | Baseline holds? | Action |
|---|---|---|---|---|
| BridgeIdMigrationService + readLegacyBridgeId (v1.3.0) | `bridge/app/lib/src/auth/` | Released Sesori installs ≤ v1.3.x | TBD | |
| LegacyPostUpdateRelaunch constant (v1.1.2) | `bridge/app/lib/src/bridge/foundation/legacy_post_update_relaunch.dart` | Pre-v1.1.2 updater binaries | TBD | |
| Rejection sessionId omission fallback (v1.1.0) | `bridge/app/lib/src/bridge/services/pending_interaction_service.dart` | Released clients ≤ v1.0.x | TBD | |
| Codex config fallback reads (v1.1.2) | `bridge/sesori_plugin_codex/lib/src/codex_config_reader.dart` | VERIFY: released client vs on-disk rollouts of still-supported runtimes | TBD | Keep if data-format peer is live. |
| CLI flag aliases ×3 (v1.1.1) | `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_plugin_descriptor.dart` | User scripts predating namespaced flags | TBD | |
| RuntimeStartIntent side-file model (v1.0.9) | `bridge/sesori_plugin_runtime/lib/src/runtime_start_intent.dart` | Bridges ≤ v1.0.8 sharing a data directory | TBD | |

## Verification Evidence

(Append per step as steps merge: analyze/test commands run, suites touched,
deviations.)

## Retirement Checklist (Step 14)

- [ ] All 14 steps merged or explicitly cancelled with reason
- [ ] L2 matrix from PLAN.md executed; evidence recorded below
- [ ] Any Partial/Blocked rows explained; plan stays active if required rows unrun
- [ ] Regression docs reconciled (Step 13)
- [ ] Move to `.plan/completed/reliability-cleanup/`
