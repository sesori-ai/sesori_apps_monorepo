# Step 3 — Recent sessions per project

## Scope

- One surface-neutral `RecentSessionsCubit` per signed-in cockpit, with five
  shared-stream subscriptions and immutable per-project entries. Existing
  `SessionListService` owns inventory, ordering, filtering and mutation helpers;
  `RecentSessionsResolvers` derives three recent rows plus the open session.
- Live create/update/delete, activity and unread projection; retry, reconnect
  and catalog invalidation. Superseded/closed reads cannot seed unseen state.
  Retry requests data through the service, not transport reconnection.
- Project collapse persists with the existing sidebar layout. Header hover or
  keyboard focus reveals New session. Existing project/session menu builders
  and main-pane routes are reused; “All sessions · N” counts visible active rows.
- Lazy `SessionListMode.actions` scopes reuse existing mutations without an
  initial fetch, project-view claim or route-navigation refresh. Normal desktop
  and mobile lists use `SessionListMode.view`; their behavior remains unchanged.
- No new analytics event: existing creation/action outcomes remain authoritative.
  No wire contract or database change; only desktop layout JSON gains a field.
- Approximately 1,300 changed lines, including 87 generated lines: a modest
  overage against the 1,200-line step estimate, below the repository soft cap.
  The shared action/viewing seam and its focused coverage stay with their real
  sidebar consumer rather than landing an unused intermediate API.

## Automated Evidence

- Recent cache: six cases cover lazy/deduplicated reads, active ordering and
  pinning, live state/mutations, invalidation, retry, stale reads and disposal.
- Existing session-list cubit/service cases pass, including a new seeded-action
  case proving no initial fetch/view claim and preserving normal rename refresh.
- Nineteen cockpit cases pass, including native-macOS versus Flutter renderer
  selection, tree selection/navigation, project collapse persistence, hover New
  session, shared project menus and package-font/single-line count labels.
- Five router and nineteen sidebar/storage cases pass. Localization and sidebar
  model generation pass. All five touched client package analyzers pass.
- Architecture pass 1 identified direct transport retry and logic inside the
  state model. Both were fixed locally; fresh-context pass 2 approved the
  resulting boundaries with no remaining architectural findings.

## Visual Evidence And Limits

Four font-loaded production-widget fixtures cover light/dark 260-pixel layouts,
200-pixel minimum width and the compact rail. Initial previews exposed missing
package-font styles/wrapping in count/retry controls; those were corrected.
Synthetic data includes running/unread/awaiting sessions, an open fourth row,
a failed project, and a collapsed project. Artifacts are private/local under
`/tmp/rose-elephant-qa.mri9JX/recent-*`; the probe source is ignored.

The inspected comparison was shown to the user. These are Flutter/Linux-renderer
fixtures, not native macOS compositing,
energy-efficiency or live-bridge verification. Production Apple indicators
remain native. The current GUI and standalone bridge were not relaunched,
taken over or stopped; no auth/storage prompts were triggered. Prior locked-GUI
and pinned-SDK profile blockers remain recorded in `step-02b.md`.

Native tree scrolling/clipping, menu/lifecycle behavior, steady Flutter frames,
live session actions, persisted-layout relaunch and the final platform matrix
remain required before shipping/plan retirement. Per the user's direction,
these outstanding checks do not draft or block this implementation PR or its
successor. Main-pane redesign, Bridge popover and modal Settings remain later
steps.
