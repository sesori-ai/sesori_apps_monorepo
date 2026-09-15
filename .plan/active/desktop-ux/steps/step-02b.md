# Step 2.b — Sidebar Polish, Motion, and Activity

Local successor branch: `desktop-ux/sidebar-polish`.
Planned PR ordinal 3/13:
`🌿 [desktop-ux] Polish sidebar styling, motion, and activity signals [step 3/13]`.
Target: ≤ 900 changed lines against step 2.a. Do not add this work to PR #1488.

## Approved Scope

The user requested a separate follow-up within step 2 on 2026-09-15:

- Simplify the confusing branding/navigation/collapse header.
- Make New project an obvious, labeled action rather than a detached plus.
- Improve row spacing, typography, selected/hover/focus states, and surfaces.
- Give pinned Bridge/Settings controls a clear visual separator.
- Show existing running/unread project indicators in expanded and compact modes.
- Animate expand/collapse smoothly, keep dragging immediate, and respect
  reduced-motion settings.
- Show the revised screen before calling the visual work complete.

## Boundaries

Consume `ProjectListLoaded.activityById` and `unseenByProjectId` directly;
reuse Prego's activity/unread visual language. Do not introduce new backend
requests, services, persisted fields, analytics events, or bridge ownership.
Main-pane routes stay unchanged. Recent-session rows remain logical step 3;
Bridge popovers and modal Settings remain later steps.

Only existing presentation files and focused tests need production changes.
This is not a new architecture boundary; architecture review is unnecessary
unless implementation materially changes that scope.

## Verification Plan

- Focused desktop widget tests: intermediate transition frames, reduced motion,
  immediate drag feedback, and running/unread updates in both widths.
- Analyze the desktop package.
- Review expanded/compact and light/dark renderings, including narrow widths.
- Keep screenshot/render-preview evidence distinct from native interaction QA.
- Do not restart, stop, take over, or launch another bridge. Do not relaunch the
  current GUI during this QA pass or request another secure-storage password.

## Implementation And Evidence

- Simplified Projects header with a separate collapse control; full-width,
  labeled New project action; compact Prego rows and a distinct pinned footer.
- Shared running/unread sparkles, including avatar badges when compact and
  status-aware tooltips/accessibility labels. Explicit state colors select
  Prego's Flutter painter, avoiding platform views in this moving/clipped
  hierarchy. No new data requests.
- Compact Projects remains available even when the list is empty, loading,
  failed, or disconnected, including when automatic collapse disables expansion.
- 220 ms eased expansion/collapse; immediate drag feedback; both MediaQuery
  disabled animations and platform Reduce Motion disable the transition.
- Desktop cockpit widget suite: 18 passed, including compact overview activation
  across recovery states and no AppKitView during running/unread transitions
  under macOS and Linux target settings. Prego avatar tests: 2 passed.
- Desktop and Prego analyzers: passed. Localization generation: passed.
- Five font-loaded render probes: light/dark expanded, light/dark compact, and
  minimum 200 px width. These render the production sidebar with fixture state;
  they are visual previews, not native macOS or live-bridge E2E evidence.
- The existing GUI and standalone bridge were not relaunched or altered.

## Status

Implementation and focused verification complete. Production-widget previews
were shown to the user before publication; this does not claim native macOS
interaction coverage or user approval. The follow-up remains separate from
#1488 and does not advance recent sessions.
