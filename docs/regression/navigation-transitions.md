# Navigation Transitions

## Capability

The Sesori phone and desktop apps give route changes platform-appropriate
motion while keeping the intentional login, settings-modal, split-view, and
desktop main-pane transitions distinct.

## Required Behavior

- Standard pushes and pops use the Material platform transition: a horizontal
  Cupertino slide on iOS and macOS, and the configured Material transition on
  Android.
- Compact session-list, session-detail, new-session, and diff navigation uses
  the same platform transition. Split-view pane changes fade instead of sliding.
- The base compact session-detail toolbar returns to the typed sessions route.
  This keeps path-like project identifiers percent-encoded and matchable instead
  of reconstructing the parent URL from decoded route parameters. A child or
  background-task detail opened with a push still pops to its parent detail.
- Settings and modal harness settings rise from the bottom on every platform;
  settings child pages use the standard platform push.
- Login uses its intentional fade and logo hero motion.
- Custom login and session transitions honor reduced-motion mode without
  changing page identity or dropping in-flight screen state.
- Desktop main-pane pages cross-fade in place over 150 ms: the sidebar never
  moves, nothing slides, and the page underneath shows until the fade ends.
  Reduced motion switches at once. Dialogs, popups, and the desktop settings
  window keep their own motion. The new-session page changes in place without
  a fade, both when it switches project and when its first prompt turns it
  into the session.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated route-table coverage proves every route supplies a standalone page and preserves each custom page type; desktop router coverage proves the 150 ms main-pane fade and the instant reduced-motion switch. |
| L3 Release | Client end to end on iOS and Android: exercise a standard push/pop, compact session navigation, a settings child, and the settings modal. |
| L4 Extended | Client end to end on macOS and with reduced motion enabled: repeat the transition matrix and exercise split-view pane fading where the viewport supports it. |
| L5 Full | No additional coverage. |

## Failure Signals

- A route appears or disappears instantly when reduced motion is disabled.
- iOS or macOS uses no transition, or Android loses its configured transition.
- A settings child rises as a modal, or the settings modal slides horizontally.
- Compact and split session layouts use each other's transition.
- A desktop main-pane page slides, moves the sidebar, or fades under reduced
  motion.
- Returning from a base compact session detail produces an unmatchable sessions
  URL, especially when a project identifier contains filesystem-path separators,
  or a pushed child detail returns to the sessions list instead of its parent.

## Sources

- `client/app/lib/core/routing/app_router.dart`
- `client/app/test/core/routing/app_route_test.dart`
- `client/app/test/core/routing/imperative_pane_route_test.dart`
- `client/app/test/core/routing/adaptive_session_route_matrix_test.dart`
- `client/app/test/features/session_detail/adaptive_session_detail_routing_test.dart`
- `client/desktop/lib/core/routing/desktop_router.dart`
- `client/desktop/test/core/routing/desktop_router_test.dart`
