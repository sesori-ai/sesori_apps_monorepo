# Periodic cleanup tracker

Authority: [PLAN.md](PLAN.md). Fixed proposed series: fourteen steps.
Implementation scope acceptance is pending.

| Step | Exact PR title | Status | PR |
| --- | --- | --- | --- |
| 1/14 | 🌱 [periodic-cleanup] docs: plan deep repository cleanup [step 1/14] | In review | [#1295](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1295) |
| 2/14 | 🌿 [periodic-cleanup] client: preserve streamed text across refresh [step 2/14] | Proposed | — |
| 3/14 | ⚙️ [periodic-cleanup] client: preserve live transcript during refresh [step 3/14] | Proposed | — |
| 4/14 | ⚙️ [periodic-cleanup] bridge: remove unused session paths and tracker state [step 4/14] | Proposed | — |
| 5/14 | 🚧 [periodic-cleanup] bridge: remove unused options cache metadata [step 5/14] | Proposed | — |
| 6/14 | ⚙️ [periodic-cleanup] plugins: keep session status events typed [step 6/14] | Proposed | — |
| 7/14 | 🚧 [periodic-cleanup] plugins: keep message events typed [step 7/14] | Proposed | — |
| 8/14 | ⚙️ [periodic-cleanup] bridge: narrow session and activity projections [step 8/14] | Proposed | — |
| 9/14 | ⚙️ [periodic-cleanup] opencode: stop forwarding unused backend events [step 9/14] | Proposed | — |
| 10/14 | ⚙️ [periodic-cleanup] client: share native thumbnail storage [step 10/14] | Proposed | — |
| 11/14 | ⚙️ [periodic-cleanup] client: share optimistic rename bookkeeping [step 11/14] | Proposed | — |
| 12/14 | ⚙️ [periodic-cleanup] runtime: share managed installer composition [step 12/14] | Proposed | — |
| 13/14 | 🌱 [periodic-cleanup] docs: reconcile cleanup regression coverage [step 13/14] | Proposed | — |
| 14/14 | 🌿 [periodic-cleanup] verify: run coverage and retire the plan [step 14/14] | Proposed | — |

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
- Plan validation: 53 relative links resolve; all 14 exact titles agree; both
  diagnostic patches apply; whitespace checked. Production/test sources restored.
- Implementation tests, live-plugin/platform retirement matrix: not run.
- Scope decision: pending, including unversioned reconciliation limits in step 3.
- Existing refresh diagnostic plan: linked handoff, not falsely retired.
- Retirement: not eligible; requires all recorded matrix rows to pass.
