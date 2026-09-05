# Periodic cleanup tracker

Authority: [PLAN.md](PLAN.md). Fixed proposed series: **25 steps**.
The user authorized consolidating #1296, closing it, and broad documentation
simplification. Refactor execution was accepted on 2026-09-05 when the user
asked to start working the plan; steps execute in order from step 2.
[Source-step dispositions](CONSOLIDATION.md).

| Step | Exact PR title | Status | PR |
| --- | --- | --- | --- |
| 1/25 | 🌱 [periodic-cleanup] docs: consolidate the repository cleanup plan [step 1/25] | Merged | [#1295](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1295) |
| 2/25 | ⚙️ [periodic-cleanup] client: preserve streamed text across refresh [step 2/25] | In review | [#1299](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1299) |
| 3/25 | ⚙️ [periodic-cleanup] client: preserve live transcript during refresh [step 3/25] | Proposed | — |
| 4/25 | ⚙️ [periodic-cleanup] bridge: remove unused session paths and tracker state [step 4/25] | Proposed | — |
| 5/25 | 🚧 [periodic-cleanup] bridge: remove unused options cache metadata [step 5/25] | Proposed | — |
| 6/25 | ⚙️ [periodic-cleanup] plugins: keep session status events typed [step 6/25] | Proposed | — |
| 7/25 | 🚧 [periodic-cleanup] plugins: keep message events typed [step 7/25] | Proposed | — |
| 8/25 | ⚙️ [periodic-cleanup] bridge: narrow session and activity projections [step 8/25] | Proposed | — |
| 9/25 | ⚙️ [periodic-cleanup] plugins: stop forwarding unused backend events [step 9/25] | Proposed | — |
| 10/25 | ⚙️ [periodic-cleanup] client: share native thumbnail storage [step 10/25] | Proposed | — |
| 11/25 | ⚙️ [periodic-cleanup] client: share optimistic rename bookkeeping [step 11/25] | Proposed | — |
| 12/25 | ⚙️ [periodic-cleanup] runtime: share managed installer composition [step 12/25] | Proposed | — |
| 13/25 | ⚙️ [periodic-cleanup] runtime: share provisioning and bounded cold-start waiting [step 13/25] | Proposed | — |
| 14/25 | 🌿 [periodic-cleanup] bridge: fold repeated worktree and Codex algorithms [step 14/25] | Proposed | — |
| 15/25 | 🌿 [periodic-cleanup] bridge: preserve caught errors and stacks in logs [step 15/25] | Proposed | — |
| 16/25 | ⚙️ [periodic-cleanup] client: share shell cubit composition [step 16/25] | Proposed | — |
| 17/25 | ⚙️ [periodic-cleanup] auth: share response and interactive login completion [step 17/25] | Proposed | — |
| 18/25 | 🌿 [periodic-cleanup] tests: consolidate substantial bridge fixtures [step 18/25] | Proposed | — |
| 19/25 | 🌿 [periodic-cleanup] tests: consolidate substantial client fixtures [step 19/25] | Proposed | — |
| 20/25 | 🌿 [periodic-cleanup] tooling: remove verified unused dependencies and symbols [step 20/25] | Proposed | — |
| 21/25 | 🌱 [periodic-cleanup] docs: simplify repository documentation [step 21/25] | Proposed | — |
| 22/25 | 🌱 [periodic-cleanup] docs: simplify client regression guides [step 22/25] | Proposed | — |
| 23/25 | 🌱 [periodic-cleanup] docs: simplify bridge regression guides [step 23/25] | Proposed | — |
| 24/25 | 🌱 [periodic-cleanup] docs: reconcile cleanup regression coverage [step 24/25] | Proposed | — |
| 25/25 | 🌿 [periodic-cleanup] verify: run coverage and retire the plan [step 25/25] | Proposed | — |

## Evidence and execution

- Initial audit commit: `1508f3bce`; first pass was structural/source inspection.
- Deeper pass: three failing diagnostics against unchanged production code,
  plus one passing nearby refresh test. See [evidence](evidence/README.md).
  Test sources restored; no production change delivered in this PR.
- Architecture plan review (2026-09-04): initial proposal **Rejected**, pre-review
  gate passed. Three findings corrected directly, without claiming re-approval:
  (1) reconcile before/live/fetched messages before consuming staleness;
  (2) produce app-owned normalized message/status values before Layer-4 SSE,
  with repository conversion and no new SSE-to-repository mapper imports;
  (3) inject an explicit core temporary-directory platform interface with shell
  adapters, not a loader callback. No additional mutable-state machinery added.
  The corrected version has not been re-reviewed, following repository rules.
- Original consolidated validation: 55 relative links resolve; all 25 exact titles and
  scope rows agree; all 17 source-step dispositions are recorded; whitespace passes.
  Diagnostic source files were restored; evidence patches were unchanged at
  consolidation. The later PR-feedback diagnostic revision is recorded below.
- Implementation tests, live-plugin/platform retirement matrix: not run.
- Scope decision: accepted 2026-09-05 (see authority line), including the
  unversioned reconciliation limits recorded in step 3.
- Existing refresh diagnostic plan: linked handoff, not falsely retired.
- Retirement: not eligible; requires all recorded matrix rows to pass.

## Consolidation update — 2026-09-04

- #1296 reviewed at `c7f35a5c7936ac3cc1b9ed7399b7b81436c8253a`; useful
  work is now owned by the steps above. #1296 was closed after the consolidated
  update was pushed to #1295.
- #1294 verified merged as `da2e9eeb47`; selection cleanup is externally
  completed. No variant or calculator rewrite remains in this series.
- Eleven additional steps adopted, three overlapping refactors consolidated,
  and policy-dependent/low-benefit ideas retained with explicit dispositions.
- Architecture plan review of the material consolidation (2026-09-04):
  **Approved**, pre-review gate passed; B-Client and B-Bridge applied, public
  shared wire contracts unchanged. No new findings or corrections required.
- Original retirement matrix retained and expanded for adopted work.
- Latest user steering: audit root/package/general docs and simplify every
  regression guide, removing pointless content. Steps 21–24 own this broader
  pass; historical deletion is only one part.

## PR feedback corrections — 2026-09-04

- Initial buffer correction used completed-message timestamps; the subsequent
  loader inspection below supersedes that unreliable predicate.
- Move transcript merge policy to a service-layer calculator and normalized
  event values to repository models. Core DI registers shared native storage;
  shell modules bind only the platform provider.
- Installer/provision services keep injected constructors. One explicit runtime
  composition owner builds both graphs, preserving all seven plugins' inputs.
- Preserve directory-client failure/retry tests, defer pruning without weakening
  its awaited budget contract, and update feature docs in behavior-changing PRs.
- Correct the merged refresh PR states and superseded trigger/options proposals;
  required live observation remains pending. Repair the verification table.
- Replace the streaming diagnostic's fixed delay with an observed delta-flush
  predicate. The final assertion still distinguishes `after` from `before-after`.
- These valid PR findings were applied directly, without claiming that the
  previously approved plan review covered this revised text.
- Validation: 61 relative links, all 25 exact titles, and the contiguous 13-row
  verification matrix pass. Revised delta diagnostic reproduces expected
  `before-after`, actual `after` without a fixed delay; test source restored.

## Follow-up PR feedback — 2026-09-04

- Confirmed Codex/Pi/Claude history omits completion timestamps and that Codex
  emits the shared MCP-tools event. Corrected the actual producer/loader scope.
- Step 2 uses exact content coverage for text/reasoning and seeds the next
  accumulator from installed content. No inferred finality or extra state;
  explicit divergent-history limitation retained. Its buffer-contract change
  raises the planned title to moderate complexity and its estimate to 200–400.
- Step 3 derives assistant metadata and selection inputs after reconciliation,
  using effective options catalogs. Step 9 includes Codex suppression/tests and
  now has a plugins-scoped title; the denominator remains 25.
- Named the source and destination of the temporary-directory test move and
  preserved the grouped-snapshot option's transcript handoff/other-group deferral.
- Valid review corrections applied directly; no claim of another architecture
  approval or newly executed product tests. Prior diagnostic evidence is unchanged.
- Validation: all 63 relative links, 25 exact titles, the contiguous 13-row
  verification matrix and Git whitespace checks pass.

## Step 2 execution — 2026-09-05

- Refresh retires a streaming accumulator only when the fetched same-ID
  text/reasoning part starts or ends with the whole buffered value; otherwise
  the buffer survives. The suffix case covers a tail-only accumulator after a
  reconnect outside the replay window (PR review finding). `appendDelta` takes a lazy base-text lookup so a new accumulator
  seeds once from the installed part. `StreamingTextBuffer.clear` had no
  remaining production caller and was removed.
- Both audit diagnostics are promoted as cubit tests, parameterized over text and
  reasoning with `completed: null` assistant messages: covering, extending,
  shorter/absent, divergent, and final-part-during-reload cases.
- Not added: per-harness Codex/Pi/Claude history fixtures in the client suite.
  The cubit reads no harness-specific field; the null-completion assistant
  fixture is the whole boundary it observes. Recorded here for step 25's matrix.
