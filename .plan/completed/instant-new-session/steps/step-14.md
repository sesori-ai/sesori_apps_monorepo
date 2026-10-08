# Step 14/14: Run new-session coverage and retire the plan

Documentation only. No code, wire, database, string or user-visible change.

## L3 Matrix

| Cell | Result |
|---|---|
| Client: phone narrow and split, three desktop creating surfaces, sidebar, desktop home, phone home Activity | Unexecuted |
| Plugins: release rule on each echo family; command start on Claude and one ACP harness | Unexecuted |
| Modes: dedicated and in-place, warm and cold | Unexecuted |
| Follow-ups: in order, cancel, leave the route at once | Unexecuted |
| The launching row: tap alert, "Creating…" | Unexecuted |
| Failure: rejection, timeout, D1 append, Back mid-creation, D5 alert | Unexecuted |
| Structural acceptance on a real device | Unexecuted |
| Abandoned launches with the `sessionMessageSent` debug log | Unexecuted |

Device tools were unavailable, so no live cell ran. Each cell is listed in
full in `PLAN.md` under "Highest level and matrix".

## Automated Evidence

Not re-run for this step. Each step's PR ran the owning packages' tests and
`dart analyze --fatal-infos` in CI, recorded per step in `TRACKER.md`: the
`module_core` launch repository, service, resolver and cubit tests; the
`module_app_ui`, `app` and `desktop` new-session, session-detail, session-list,
Activity and sidebar widget tests, including the bubble and composer rect
assertions across the route swap. Every CI check on #1902's final head
`1deb8ca423` passed or was skipped.

## Cleanup Audit

Every item in `PLAN.md` "Cleanup Assessment" is gone on `main` at `5dd2d6be85`:

- No new-session sending branch uses `PregoLaunchStatus`; the ordinary
  session-detail load still does, and the `app` new-session tests assert it is
  absent while sending.
- `SessionDetailCubit` has no `_generatePromptId`; the shared
  `generatePromptId` in `foundation/identity/prompt_id.dart` owns
  `_promptIdRandom`.
- `NewSessionCubit` no longer awaits `createSessionWithMessage`; only
  `SessionLaunchService` calls it.
- The composer's sending checks no longer gate Send; `isSending` remains only
  for layout in `new_session_view.dart`.

No obsolete database column, wire field, cache, flag or compatibility path was
introduced or left behind.

## Regression Documents

Checked `session-creation-and-options.md`, `projects-and-sessions.md`,
`session-turns.md`, `navigation-transitions.md` and `desktop-cockpit-shell.md`
against the merged series. One stale failure signal was fixed: the sending
bubble's "permits duplicate Send" predated the live composer, where a second
Send queues a follow-up; it now reads "lets a second Send start a second
session". No tombstones were found. `docs/HARNESS_CAPABILITIES.md` needs no
entry, since every harness gets the whole feature.

## Acceptance

The user explicitly accepted every unexecuted cell above on 2026-10-08 (L1:
"Accept the unexecuted L3 cells and retire now"), recorded in `PLAN.md`, so the
plan retires to `.plan/completed/instant-new-session/`. The acceptance permits
retirement; it does not claim that those cells passed.
