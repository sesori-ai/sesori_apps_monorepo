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

Consume `ProjectListLoaded.activityById` and `projectUnseenById` directly;
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

## Status

Implementation in progress. No visual or motion acceptance claimed yet.
