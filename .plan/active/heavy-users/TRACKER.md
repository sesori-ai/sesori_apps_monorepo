# Heavy users tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Current step: 1/19, publishing the plan.
- User decisions: D1–D7 in `PLAN.md`, agreed 2026-10-28 on the review page `heavy-users-r1` and the follow-up in
  chat (D7).

## Delivery

| Step | Repository | Outcome | State | PR/evidence |
|---|---|---|---|---|
| 1/19 | monorepo | Publish the plan | In progress | This change |
| 2/19 | monorepo | 10,000-session Claude fixture and baseline | Not started | |
| 3/19 | monorepo | Session list rebuilds only when it changes | Not started | |
| 4/19 | monorepo | Prego lists animate only on-screen rows | Not started | |
| 5/19 | monorepo | Import writes only changed rows | Not started | |
| 6/19 | monorepo | One reload per import; off-UI decode | Not started | |
| 7/19 | monorepo | Claude metadata cache | Not started | |
| 8/19 | monorepo | Pi metadata cache | Not started | |
| 9/19 | monorepo | Codex enumeration off the main isolate | Not started | |
| 10/19 | monorepo | OpenCode import without a call per session | Not started | |
| 11/19 | monorepo | Row action cubits keep to their session | Not started | |
| 12/19 | monorepo | Shared running and search rules | Not started | |
| 13/19 | monorepo | Bridge session pages | Not started | |
| 14/19 | monorepo | Client window service | Not started | |
| 15/19 | monorepo | Palette search through the bridge | Not started | |
| 16/19 | monorepo | Session list on pages | Not started | |
| 17/19 | monorepo | Launch rows on the window; inventory removed | Not started | |
| 18/19 | monorepo | Reconcile regression documents | Not started | |
| 19/19 | monorepo | Run the L3 matrix; retire | Not started | |

## Baseline (step 2)

Not measured yet. Step 2 records here the bridge and app numbers named in `PLAN.md`, and later steps add their
after-numbers next to them.

## Evidence and decisions

- 2026-10-28: two read-only investigations, one of the bridge and plugins and one of the client, ranked every path
  that grows with the session count. `PLAN.md` → "Current behavior" records the findings with file references.
- 2026-10-28: the review page `heavy-users-r1` settled D1–D6. The user then asked for one plan covering both phases
  in detail (D7).
- No reduction of the retirement matrix has been requested or accepted.

## Review record

- 2026-10-28: `architecture-plan-review` rejected the first revision with 12 findings. All were applied in the same
  revision:
  1. There is one window per mode (an injectable factory). The scope owns the active window and the archived route
     owns its own. Refresh, launch rows and the palette read the active window.
  2. Palette search moved into a new `SessionSearchCubit`.
  3. The window now has named layers: `SessionApi.getSessionPage`, and `SessionRepository.getSessionPage`
     returning a sealed result with an Unsupported variant. The legacy path is the window's complete mode, which
     makes `RecentSessionInventoryService` removable (step 17).
  4. The window owns the one matching rule. The cubit's debounce goes in step 16, and the hidden-row count
     adjustment was dropped and accepted as a risk.
  5. The bridge chain is named: handler → `SessionRepository.getSessionPage` → DAO, then
     `SessionViewService.enrichMany`. Running ids come from `getProjectActivitySummaries()`, and the per-request
     cost is accepted.
  6. The SQL forms of the unseen rule and the displayed time stay in the DAO, with parity tests.
  7. A shared `ActiveSessionRunningCalculator` is applied once in `SseEventTracker`, and `SessionActivityCalculator`
     is deleted (new step 12).
  8. OpenCode keeps the runtime's dormant-only snapshot. A live `NativeProjectsPluginApi.readCatalogSnapshot`
     replaces the per-parent walk.
  9. The cache owners are named: the Claude, Pi and Codex catalog repositories. Pi's process repository receives
     resolved sessions.
  10. One page limit, 0..1000, applies on both sides; anything outside is a 400.
  11. The compatibility baseline is v1.10.1, the latest public release.
  12. The search words and own-name rule move to `sesori_shared` (step 12).

  The series grew from 17 to 19 steps. Per `AGENTS.md` the applied fixes are not re-reviewed.
