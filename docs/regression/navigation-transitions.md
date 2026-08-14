# Navigation Transitions

## Capability

The Sesori app gives route changes platform-appropriate motion while keeping
the intentional login, settings-modal, and split-view transitions distinct.

## Required Behavior

- Standard pushes and pops use the Material platform transition: a horizontal
  Cupertino slide on iOS and macOS, and the configured Material transition on
  Android.
- Compact session-list, session-detail, new-session, and diff navigation uses
  the same platform transition. Split-view pane changes fade instead of sliding.
- Settings and modal harness settings rise from the bottom on every platform;
  settings child pages use the standard platform push.
- Login uses its intentional fade and logo hero motion.
- Custom login and session transitions honor reduced-motion mode without
  changing page identity or dropping in-flight screen state.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated route-table coverage proves every route supplies a standalone page instead of relying on legacy `MaterialApp` detection, and preserves each custom page type. |
| L3 Release | Client end to end on iOS and Android: exercise a standard push/pop, compact session navigation, a settings child, and the settings modal. |
| L4 Extended | Client end to end on macOS and with reduced motion enabled: repeat the transition matrix and exercise split-view pane fading where the viewport supports it. |
| L5 Full | No additional coverage. |

## Failure Signals

- A route appears or disappears instantly when reduced motion is disabled.
- iOS or macOS uses no transition, or Android loses its configured transition.
- A settings child rises as a modal, or the settings modal slides horizontally.
- Compact and split session layouts use each other's transition.

## Sources

- `client/app/lib/core/routing/app_router.dart`
- `client/app/test/core/routing/app_route_test.dart`
