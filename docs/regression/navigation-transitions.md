# Navigation Transitions

## Capability

The Sesori phone and desktop apps give route changes platform-appropriate
motion while keeping the intentional login, settings-modal, split-view, and
desktop main-pane transitions distinct.

## Required Behavior

- Standard pushes and pops use the Material platform transition: a horizontal
  Cupertino slide on iOS and macOS, and the configured Material transition on
  Android.
- On the phone, signed-in navigation starts at the home (`/sessions`). Session
  detail (`/sessions/<projectId>/<sessionId>`), new session
  (`/sessions/new?project=<id>`) and diffs open over it with the same platform
  transition. From 700 pt the home stays as the list beside them, and pane
  changes fade instead of sliding.
  The one exception is the session screen replacing the new-session screen that
  created it: it appears with no entry transition, because the new-session
  screen already shows its first message where the session screen does. Back
  from it still animates, and every other entry to the same session, including a
  deep link, transitions as usual.
- The base compact session-detail toolbar returns to the home. A child or
  background-task detail opened with a push still pops to its parent detail.
  Typed routes keep path-like project identifiers percent-encoded, so a
  session's URL stays matchable.
- A notification opens its session over the home, so Back lands on the home;
  a notification for another computer switches to it first. A computer switch
  replaces the stack with the home, and deleting the open session returns to it.
- The desktop serves the same home route with its own home pane. Its project
  page stays at `/projects/<projectId>/sessions`, and its new-session fallback,
  open-project, mark-unread and delete exits return there. A desktop session
  opened from a notification goes back to the home.
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
- Modals that rise as bottom sheets on phone open as centred dialogs on
  desktop and fade in and out: forms, confirmations, agent questions,
  permission requests, reasoning, and the folder browser. A dialog opened from
  a dialog stacks on it, and Escape closes only the top one. Reduced motion
  opens and closes them at once.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated route-table coverage proves every route supplies a standalone page and preserves each custom page type; the notification-open and computer-switch dispatcher tests prove a notification opens its session over the home (switching computers first) and a switch replaces the stack with the home; session deletion navigation coverage proves deleting the open session returns home; desktop router coverage proves the project page's exits; desktop router coverage proves the 150 ms main-pane fade and the instant reduced-motion switch; Prego modal coverage proves the phone sheet, the desktop dialog, stacked dialogs closing top first on Escape, and the instant reduced-motion open. |
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
- A desktop modal rises as a bottom sheet, a phone modal opens as a dialog,
  Escape closes more than the top dialog, or a dialog fades under reduced
  motion.
- Returning from a base compact session detail lands anywhere but the home, a
  session URL whose project identifier contains filesystem-path separators does
  not match, or a pushed child detail returns to the home instead of its parent.
- A notification's Back skips the home, or a computer switch leaves a page from
  the previous computer on the stack.

## Sources

- `client/app/lib/core/routing/app_router.dart`
- `client/app/test/core/routing/app_route_test.dart`
- `client/app/test/core/routing/imperative_pane_route_test.dart`
- `client/app/test/core/routing/adaptive_session_route_matrix_test.dart`
- `client/app/test/features/session_detail/adaptive_session_detail_routing_test.dart`
- `client/module_core/test/routing/notification_open_dispatcher_test.dart`
- `client/module_core/test/routing/computer_switch_dispatcher_test.dart`
- `client/desktop/lib/core/routing/desktop_router.dart`
- `client/desktop/test/core/routing/desktop_router_test.dart`
- `client/module_prego/lib/components/surfaces/prego_modal.dart`
- `client/module_prego/test/components/prego_modal_test.dart`
