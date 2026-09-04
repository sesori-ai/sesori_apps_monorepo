# Codebase Cleanup 2: Tracker

## How This Tracker Works

This file holds only what GitHub cannot: the owner's decisions, the rules the
series binds itself to, and the fixed PR titles. It deliberately does **not**
mirror live PR state.

- **Live status lives on GitHub.** `gh pr list --state all --search
  "[codebase-cleanup-2]"` shows every step's PR and whether it is open or
  merged. Nothing here needs editing when a PR is raised or merged.
- **Per-step evidence lives in `steps/step-NN.md`**, written only by that
  step's own PR: the re-verification delta against current `main`, what was
  done, what was deliberately not done, and the verification run. No PR ever
  edits another step's file, so parallel steps cannot conflict here.
- **This file changes only when a decision, principle, or guardrail changes**,
  never as bookkeeping.

Steps that touch disjoint trees run in parallel (up to about five open PRs).
Hard orderings: 4 after 3 (listeners consume the tracker); 6 after 2 and 5
(same bridge files); 12 after 2–5 and 13 after 8–10 (fakes move with their
production code); 14 after 8 (`module_app_ui` pubspec); 16 after 2–15; 17 last.

- **Plan slug:** `codebase-cleanup-2`
- **Implementation base:** `origin/main` at `480d82f090`
- **Overlapping work to avoid:** #1291 and the antigravity-harness series
  (`sesori_plugin_antigravity`, client browser auth handoff); #1271, #1268,
  #1237 (Pi command availability, provider login guidance); #1221 (chat tool
  payloads); #939, #930, #926, #1153 (client UI PRs); the `session-refresh-
  reconnects` plan owns `SessionDetailCubit` coordination; the `desktop-app`
  plan gates Step 11.

## Decisions

- [ ] **D1** minimum supported public peer — *default* `≥ v1.6.0`
  (2026-07-24); alternative `≥ v1.7.0`. Gates Step 7. Accepted consequence:
  peers below the floor fail to decode the now-required fields.
- [ ] **D2** identical Flutter platform adapters live once in
  `module_app_ui/lib/src/platform/` — *default* yes; `client/AGENTS.md`
  ownership sentence updated in Step 8.
- [ ] **D3** paired bridge listeners merge into one owner per concern —
  *default* yes; `bridge/app/AGENTS.md` and `bridge/AGENTS.md` "one trigger
  per listener" becomes "one concern per listener" in Step 4. If declined,
  Step 4 closes without a code change.
- [ ] **D4** historical documents outside `.plan/` are deleted — *default*
  yes (list in `PLAN.md`); `docs/parallel-plugins/ARCHITECTURE.md` kept only
  if `docs/ARCHITECTURE.md` lacks its durable content.
- [ ] **D5** reverse the first series' "install composition stays local" —
  *default* yes; the shared composition owns the `http.Client` it creates.
- [ ] **D6** Step 11 starts only after `desktop-app` retires; if it has not
  retired when every other step is merged, Step 11 is recorded as deferred and
  the series retires without it.
- [ ] **D7** variant availability on the session screen — *default* the
  shared derivation applies `isAvailable` on both screens (an unavailable model
  offers no variants anywhere); alternative: keep offering variants on the
  session screen through an explicit flag. Behavior decision for Step 10.

## Locked Principles

- [x] Behavior-preserving by default; Steps 4, 7, 10, and 11 name their
  intentional changes in their PR bodies and regression documents.
- [x] Nothing is extracted unless it replaces at least two copies and owns
  state, a lifecycle, or an invariant.
- [x] Every step re-verifies its evidence against current `main` before
  editing and records the delta in its own `steps/step-NN.md`.
- [x] No compatibility removal outside Step 7 and D1. No wire, database, or
  schema change outside Step 7.
- [x] `Orchestrator`, `PluginRuntime`, `SessionOptionsService`,
  `ConnectionService`/`RelayClient`, dispatcher, tool-tracker, and
  `SessionDetailCubit` coordination internals are out of scope.
- [x] Architecture-implementation review only for Steps 2, 3, 4, 7, 8, 9,
  10, 11; at most two passes per step before asking the owner.
- [x] 1,500 changed-line soft cap; deletion-heavy overages are recorded with
  the reason in the step file.
- [x] Test consolidation uses `implements`/subclass fakes only; assertions
  are never rewritten to fit a shared fake or helper.

## Complexity Guardrails

- [x] One managed-runtime install composition owner, one provision
  composition owner, one `BudgetedColdStart` (all in `sesori_plugin_runtime`);
  one `ConnectionViewTracker`; one `OptimisticRenameTracker`; one
  model-variant derivation; one `SessionActivityAnalyticsOwner` — no second
  variant of any of them.
- [x] No listener base class, dispose mixin, generic session-options
  service, SSE event hierarchy, refresh scheduler, or compatibility shim for
  peers below the D1 floor.
- [x] Step 11 ends with at most eight mutable fields and no per-session
  generation counters or in-flight sets.
- [x] Step 6 removes no log line and adds no new log category; it only moves
  the caught error and stack into logger arguments.

## Delivery Steps

Fixed titles and order. Status is GitHub's; evidence is in `steps/step-NN.md`.

| Step | Exact PR title |
|---|---|
| 1/17 | `🌱 [codebase-cleanup-2] docs: plan the second reliability cleanup series [step 1/17]` |
| 2/17 | `⚙️ [codebase-cleanup-2] bridge(runtime, plugins): share managed-runtime composition and the budgeted cold start [step 2/17]` |
| 3/17 | `⚙️ [codebase-cleanup-2] bridge(app): one connection view tracker for sessions and projects [step 3/17]` |
| 4/17 | `⚙️ [codebase-cleanup-2] bridge(app): merge the paired listeners into one owner per concern [step 4/17]` |
| 5/17 | `🌿 [codebase-cleanup-2] bridge: fold the duplicated worktree, Codex turn, and scanner loops [step 5/17]` |
| 6/17 | `🌿 [codebase-cleanup-2] bridge: pass caught errors to the logger instead of interpolating them [step 6/17]` |
| 7/17 | `🚧 [codebase-cleanup-2] compat: retire compatibility paths below the v1.6.0 baseline [step 7/17]` |
| 8/17 | `⚙️ [codebase-cleanup-2] client: share the identical Flutter platform adapters between the shells [step 8/17]` |
| 9/17 | `⚙️ [codebase-cleanup-2] client: share session-detail and list screen composition between the shells [step 9/17]` |
| 10/17 | `⚙️ [codebase-cleanup-2] client(module_core, module_auth): share the rename tracker and variant derivation, fold auth duplicates [step 10/17]` |
| 11/17 | `🚧 [codebase-cleanup-2] client(module_desktop_core): reconcile desktop attention notifications from one desired state [step 11/17]` |
| 12/17 | `⚙️ [codebase-cleanup-2] tests(bridge): consolidate identical fakes and repeated arrange blocks [step 12/17]` |
| 13/17 | `⚙️ [codebase-cleanup-2] tests(client): consolidate shared mocks and repeated arrange blocks [step 13/17]` |
| 14/17 | `🌿 [codebase-cleanup-2] tooling: prune unused dependencies, localization keys, and dead symbols [step 14/17]` |
| 15/17 | `🌱 [codebase-cleanup-2] docs: remove historical documents preserved by git history [step 15/17]` |
| 16/17 | `🌱 [codebase-cleanup-2] docs: reconcile regression coverage after the second cleanup [step 16/17]` |
| 17/17 | `🌿 [codebase-cleanup-2] verify: run the recorded matrix and retire the plan [step 17/17]` |

If D1 changes from its default, the Step 7 title is updated here before that
PR opens.

## Cleanup Ledger

| Artifact | Decision | Owning step |
|---|---|---|
| Seven `installRuntime`/`ensureRuntime` compositions; two budgeted cold-start blocks | One composition owner each and one `BudgetedColdStart` in `sesori_plugin_runtime` | 2 |
| `SessionViewTracker` + `ProjectViewTracker` | One `ConnectionViewTracker` keeping both `starts` and aggregate `changes` | 3 |
| Warm-up, glossary, and session-options listener pairs | Three single owners (D3) | 4 |
| Worktree attempt loop ×2; Codex resolve-start block ×4; Codex JS scan loop ×2 | Fold in place | 5 |
| 53 interpolated-error log sites | Logger arguments | 6 |
| Markers `≤ v1.6.0` with a released Sesori peer (list in `PLAN.md` Step 7) | Retire with per-marker peer verification (D1) | 7 |
| Backend/on-disk-format markers; every marker `> v1.6.0`; `/settings/pull-request-refresh` | Keep | — |
| Eight app/desktop adapter pairs + `NoOpAnalyticsClient` + twin tests | One copy in `module_app_ui` (D2) | 8 |
| Twin `SessionDetailCubit` construction, twin `_SessionActivityAnalyticsOwner`, list/new-session wrapper duplicates | Locator factories + one shared owner widget | 9 |
| `_ProjectRenameState`/`_SessionRenameState` + rename flows; new-session vs session-detail variant derivation (detail lacks `isAvailable`); auth HTTP mapping ×2; login persist ×2 | One tracker; one derivation (detail adopts `isAvailable`); one helper each | 10 |
| Desktop attention per-session generations, write chains, in-flight set | One desired-state reconciler (D6) | 11 |
| 13 identical bridge fakes; repeated arrange blocks in 9 bridge test files | Testing libraries + file-local builders | 12 |
| 71 identical client fakes; repeated arrange blocks in 10 client test files | `sesori_dart_core/testing.dart` + file-local builders | 13 |
| Unused dependencies (list in `PLAN.md`), 4 ARB keys, 6 dead symbols | Delete | 14 |
| Historical docs (list in D4) | Delete (D4) | 15 |
| Exhaustive SSE ignore-lists, dispose fences, ACP options services, core lifecycle owners, runtime manifests, small chrome overlaps | Keep (see `PLAN.md` Declined Candidates) | — |

## Plan Review

- To be recorded by the Step 1 PR: `architecture-plan-review` sub-agent
  result and applied findings.
