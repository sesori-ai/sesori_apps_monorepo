# Popup Alerts

Popup alerts are the app-wide transient feedback surface. They replace Material
snackbars and render above the current route, below the top navigation bar.

## Regression Checklist

- Success, info, warning, error, and loading variants use the matching icon and
  accent treatment from the Prego design system.
- An alert without supporting text stays compact; supporting text and optional
  actions expand the card without clipping at accessibility text sizes.
- The card is centered with 16 px screen margins and a 343 px maximum width.
- A newly presented alert replaces the alert already visible on the same route.
- Alerts dismiss after three seconds by default and dismiss immediately when
  the close button is tapped.
- Alerts presented from asynchronous operations remain visible when the source
  row or modal is removed.
- Alerts raised from a modal or full-screen image viewer render above that
  route, not behind it.
