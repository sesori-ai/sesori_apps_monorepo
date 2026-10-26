# Navigation Transitions

## Capability

The Sesori phone and desktop apps give route changes platform-appropriate
motion while keeping the intentional login, settings-modal, sidebar-pane, and
desktop main-pane transitions distinct.

## Required Behavior

- Standard pushes and pops use the Material platform transition: a horizontal
  Cupertino slide on iOS and macOS, and the configured Material transition on
  Android.
- On the phone, signed-in navigation starts at the home (`/sessions`). Session
  detail (`/sessions/<projectId>/<sessionId>`), new session
  (`/sessions/new?project=<id>`) and diffs open over it with the same platform
  transition. From 700 pt the home is a floating sidebar panel beside them,
  as on desktop, and its own pane is a new session, and pane changes fade
  instead of sliding. Collapsing the sidebar slides the panel out at its full
  width with its margins while the pane widens and grows a restore button
  before the pane's leading; restoring reverses the motion. Rotating across
  700 pt keeps the open page and its state, and keeps the collapse.
  The one exception is the session screen replacing the new-session screen that
  created it: it appears with no entry transition, because the new-session
  screen already shows its first message where the session screen does. Back
  from it still animates, and every other entry to the same session, including a
  deep link, transitions as usual.
- Below 700 pt the home's floating + opens New session as a circle that grows
  out of the + to the farthest corner (400 ms, ease-in-out cubic) while the home
  holds still under it. The circle lifts off the home: the home dims as it
  grows, lightly on a light page and more deeply on a dark one, and its rim
  casts a soft shadow that grows in at the start and fades out before the end;
  on a dark page the circle also lightens faintly, easing back over the second
  half. Fully open, the page paints alone, with no dim or shadow left. The +
  puts its centre in the URL (`reveal=<x>,<y>`, fractions of the screen), and
  the page keeps it when it changes project. Back, the page's own and Android's,
  shrinks the circle back into the +. On iOS a swipe from the left edge shrinks
  the circle, and its dim, shadow and dark-page lift, with the finger; released
  past halfway or flicked it closes, otherwise it springs back open, carrying
  the swipe's speed. With no default project the project picker rises once the
  circle has settled. Every other way into New session, deep links included,
  keeps the platform transition, and the wide layout's sidebar button still
  returns the pane to the composer; under reduced motion the + page moves as the
  platform transition does, with no circle.
- The base compact session-detail toolbar returns to the home. A child or
  background-task detail opened with a push still pops to its parent detail.
  Typed routes keep path-like project identifiers percent-encoded, so a
  session's URL stays matchable.
- A notification opens its session over the home, so Back lands on the home;
  a notification for another computer switches to it first. A computer switch
  replaces the stack with the home, and deleting the open session returns to it.
- The desktop serves the same home route with its own home pane. Its
  new-session fallback, mark-unread, archive and delete exits return there, and
  a desktop session opened from a notification goes back to the home.
- Settings and modal harness settings rise from the bottom on every platform; settings child pages, the phone's
  Archived among them, and archived session detail use the standard platform push. An archived session's edge swipe
  or system Back returns to the Archived list, and the list's own Back returns to Settings.
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
| L2 Routine | Automated route-table coverage proves every route supplies a standalone page and preserves each custom page type; sidebar shell coverage proves the 700 pt breakpoint, the floating panel's inset past the safe area, the pane's page kept clear of the side insets through the collapse, the collapse motion and restore, and that rotating keeps the open session and the list; reveal page coverage proves the circle follows the route animation out of its origin over a still page and back into it, paints the dim and the rim's shadow under the circle (and the lift over it on a dark page) mid-reveal and on pop and leaves the open page painting alone, without checking their colours, tracks an iOS edge swipe linearly, closes past halfway or on a flick and otherwise springs back open, ignores the edge off iOS and gives way to the fallback under reduced motion, and route and home navigation coverage prove only the + selects it and choosing a project keeps it; the notification-open and computer-switch dispatcher tests prove a notification opens its session over the home (switching computers first) and a switch replaces the stack with the home; session deletion navigation coverage proves deleting the open session returns home; desktop router coverage proves the desktop exits to the home; desktop router coverage proves the 150 ms main-pane fade and the instant reduced-motion switch; archive navigation coverage proves an archived session's edge swipe and system Back return to the Archived list and the list's leave the flow; Prego modal coverage proves the phone sheet, the desktop dialog, stacked dialogs closing top first on Escape, and the instant reduced-motion open. |
| L3 Release | Client end to end on iOS and Android: exercise a standard push/pop, compact session navigation, a settings child, the settings modal, the + revealing New session and Back shrinking it (on iOS also a partial and a completed edge swipe, slow and flicked, with the list scrolled), and the phone's Archived page pushing over Settings with an archived session's detail pushing over it, leaving each by an edge swipe released mid-gesture (the page springs back) and completed, and by Back. |
| L4 Extended | Client end to end on macOS and with reduced motion enabled: repeat the transition matrix and exercise sidebar pane fading and the collapse and restore motion where the viewport supports it. |
| L5 Full | No additional coverage. |

## Failure Signals

- A route appears or disappears instantly when reduced motion is disabled.
- iOS or macOS uses no transition, or Android loses its configured transition.
- A settings child rises as a modal, or the settings modal slides horizontally.
- An archived session's edge swipe or system Back leaves Archived instead of returning to its list.
- Compact and sidebar session layouts use each other's transition.
- Collapsing or restoring the sidebar snaps, squeezes the panel's rows, moves
  the pane's title in a jump, or rotating drops the open session or its draft.
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
- The + opens New session without the circle, or the circle grows from or
  shrinks into anywhere but the +; the home moves under it; the dim, the shadow
  or the dark-page lift is missing mid-reveal or lingers once the page is open,
  or one of them stays put while a swipe shrinks the circle; Back or an iOS edge
  swipe does not shrink it back, a released swipe snaps instead of settling, or
  touches stay blocked after one; or the circle shows from another entry or
  under reduced motion.

## Sources

- `client/app/lib/core/routing/app_router.dart`
- `client/app/test/core/routing/app_route_test.dart`
- `client/app/lib/core/routing/circular_reveal_page.dart`
- `client/app/test/core/routing/circular_reveal_page_test.dart`
- `client/app/test/features/session_list/adaptive_session_list_navigation_test.dart`
- `client/app/test/core/routing/imperative_pane_route_test.dart`
- `client/app/test/core/routing/adaptive_session_route_matrix_test.dart`
- `client/app/test/core/widgets/session_sidebar/session_sidebar_shell_test.dart`
- `client/module_app_ui/lib/src/widgets/session_sidebar/session_sidebar_shell.dart`
- `client/module_app_ui/lib/src/widgets/session_sidebar/floating_sidebar_panel.dart`
- `client/app/test/features/session_detail/adaptive_session_detail_routing_test.dart`
- `client/app/test/features/session_list/archived_sessions_navigation_test.dart`
- `client/module_core/test/routing/notification_open_dispatcher_test.dart`
- `client/module_core/test/routing/computer_switch_dispatcher_test.dart`
- `client/desktop/lib/core/routing/desktop_router.dart`
- `client/desktop/test/core/routing/desktop_router_test.dart`
- `client/module_prego/lib/components/surfaces/prego_modal.dart`
- `client/module_prego/test/components/prego_modal_test.dart`
