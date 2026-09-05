# Popup Alerts

## Capability

The app-wide transient feedback surface. Popup alerts replace Material snackbars
and render above the current route, below the top navigation bar.

## Required Behavior

- Success, info, warning, error, and loading variants use the matching icon and
  accent treatment from the Prego design system.
- An alert without supporting text stays compact; supporting text and optional
  actions expand the card without clipping at accessibility text sizes.
- The card is centered with 16 px screen margins and a 343 px maximum width.
- A newly presented alert replaces the alert already visible on the same route,
  including while the previous alert is still dismissing.
- Session-attributed backend alerts appear only while the matching session detail
  or diffs route is on top; unattributed backend alerts remain app-wide.
- Alerts dismiss after three seconds by default, immediately when the close
  button is tapped, and on an upward swipe that follows the finger and completes
  on release.
- Alerts presented from asynchronous operations remain visible when the source
  row or modal is removed, and alerts raised from a modal or full-screen image
  viewer render above that route rather than behind it.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: the owning widget suite proves each visual variant, placement below navigation, auto-dismiss, close-on-tap, upward-swipe dismissal, replacement including replacement during dismissal, sizing for short and long text and for action-bearing alerts, and overlay inset behavior when a modal strips top padding. |
| L2 Routine | Client end to end on the release-target client platform: an alert raised by a real asynchronous operation survives removal of its source row or modal, and renders above a modal or full-screen image viewer. |
| L3 Release | Client end to end: a session-attributed backend alert appears on the matching session detail or diffs route and stays suppressed elsewhere, while an unattributed backend alert shows app-wide. |
| L4 Extended | Client end to end at accessibility text sizes: supporting text and actions expand the card without clipping. |
| L5 Full | No additional coverage. |

## Failure Signals

- An alert renders behind the top navigation bar, behind a modal, or behind the
  full-screen image viewer.
- A session-attributed alert appears on an unrelated route, or an unattributed
  alert is suppressed.
- A replacement leaves two alerts visible, or replacing an alert that is still
  dismissing crashes or strands the surface.
- An alert outlives its source operation's route in a way that hides it, or a
  swipe or close tap fails to dismiss it.
- Supporting text or actions clip at accessibility text sizes.

## Sources

- `client/module_prego/lib/components/alerts/prego_popup_alerts_notifications.dart`
- `client/module_prego/test/components/prego_popup_alerts_notifications_test.dart`
