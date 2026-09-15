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
- Preserve native macOS/iOS indicator implementations for CPU/battery efficiency;
  do not substitute Flutter drawing to avoid native QA. This step changes only
  the desktop sidebar.

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
- Exercise native macOS indicators through scrolling, clipping, repeated
  insertion/removal, collapse/expand, and composited content; check steady-state
  Flutter frame scheduling separately from finite layout transitions.
- Do not restart, stop, take over, or launch another bridge. Do not relaunch the
  current GUI during this QA pass or request another secure-storage password.

## Implementation And Evidence

- Simplified Projects header with a separate collapse control; full-width,
  labeled New project action; compact Prego rows and a distinct pinned footer.
- Shared running/unread sparkles, including avatar badges when compact and
  status-aware tooltips/accessibility labels. Keep Prego's native AppKitView
  path on macOS; iOS callers are unchanged. No new data requests.
- Compact Projects remains available even when the list is empty, loading,
  failed, or disconnected, including when automatic collapse disables expansion.
- 220 ms eased expansion/collapse; immediate drag feedback; both MediaQuery
  disabled animations and platform Reduce Motion disable the transition.
- Desktop cockpit widget suite: 18 passed, including compact overview activation
  across recovery states and native AppKitView selection throughout macOS
  running/unread transitions. Linux retains its Flutter path. Prego avatar
  tests: 2 passed.
- Desktop and Prego analyzers: passed. Localization generation: passed.
- Five font-loaded render probes: light/dark expanded, light/dark compact, and
  minimum 200 px width. These render the production sidebar with fixture state;
  they are visual previews, not native macOS or live-bridge E2E evidence.
- The existing GUI and standalone bridge were not relaunched or altered.
- An isolated, auth-free debug probe built, passed deep/strict signature
  verification, and started with Impeller MetalSDF. It uses the production
  cockpit/sidebar, synthetic cubits, in-memory layout persistence, a distinct
  bundle ID, and a separate derived-data output. Only that probe was stopped.
- Native visual/lifecycle checks are blocked: Peekaboo reported the macOS GUI
  session is locked. No unlock was attempted; no native rendering, steady-frame,
  CPU, or battery result is claimed.
- Profile-mode compilation separately failed in the pinned SDK:
  `Unexpected object (Class with illegal cid, full-aot)` for Flutter's
  `_window_macos.dart` `_Rect`; the snapshot generator exited with `-6`.
  This is not evidence of an indicator rendering failure.

## Status

Implementation and focused verification are complete. Native rendering remains
enabled. Per the user's direction, PR #1491 follows normal non-draft review,
auto-merge, and successor execution; unavailable local QA does not suspend that
workflow. Complete the outstanding native hierarchy/steady-frame checks before
shipping or retiring the plan; previews do not establish native coverage or user
approval. The isolated probe/logs remain outside the diff, and the standard app
build target is restored. Recent sessions remain the next logical step.
