# Step 26 — Settings states

## What changed

- `PregoGlassScaffold` gains `largeTitleInBar`. It puts the collapsing large
  title in the bar row, next to the actions. Phone Settings uses it, so the
  Close X now shares the title's row. The scroll-edge gradient fades in only
  once the title collapses. Pages that do not set the parameter are
  unchanged.
- Phone Profile is now named Account. Its own bar has only the back button,
  because back was already the way out and the X was a second one.
- The account row states the provider once. It shows "Signed in with
  {provider}" with the provider's icon, and the tag is gone. Email now has a
  mail icon.
- When the bridge is offline, Bridge settings show one line above the group:
  "Connect to a bridge to change these settings." The rows are dimmed and
  keep their normal descriptions. The per-row "Offline" trailings and the
  repeated per-row text are gone.
- Log out now asks first, through `showPregoModal` (a sheet on touch, a
  dialog on pointer). Cancel keeps the user signed in; the destructive
  "Log out" button signs them out. Phone and desktop share this code.
- The mobile bridge-offline view names the computer only in the bridge line
  under the title. Its body reads "Bridge offline" and, when the time is
  known, "Last seen X ago". The start label lost its info popover, since
  "Why is this needed?" already explains it. "Install commands" and "Need
  help?" are now quiet tertiary links; "Need help?" is quiet only on this
  surface, and onboarding keeps its prominent button.
- The l10n keys that these changes left unused are removed.

## Deviations

- **The scaffold parameter has a default.** `largeTitleInBar` defaults to
  `false`, following the scaffold's existing convention for optional layout
  flags. The alternative was to edit every caller.
- **Desktop offline line.** On desktop the offline line replaces the bridge
  section description while the bridge is offline. Showing both would say
  "bridge" twice above the same group.
- **Fallback account row.** With no cached user, the row reads "Account",
  the same as its section header, instead of the removed "Profile" string.
- **Desktop offline home unchanged.** The review found that it already
  names the state once.
- **No analytics.** D18 rules out new events for this plan.
- **Illustration.** The bridge-offline illustration is unchanged. It does
  not appear in the widget-test renders, because the image asset does not
  load in tests.
- **Size.** The diff has about 675 authored changed lines and 111 generated
  l10n lines, against a budget of 600 or fewer. Without this plan evidence
  file, the authored count is about 607. The step covers six review items
  across phone and desktop, and roughly a third of the authored lines are
  deletions and rewritten offline-view tests. There is no clean split that
  would not leave a half-changed settings surface.
- **No architecture review.** There are no new classes, DI changes, or
  public, wire, or persisted contracts. The only design-system change is one
  layout flag on an existing widget.

## Verification

- `client/app`: `test/features/settings/` and `test/features/project_list/`
  (184 tests). They cover: the offline line shown once over dimmed rows;
  Log out signing out only after confirmation, with Cancel keeping the
  session; the Account title; the rewritten `bridge_offline_view_test`; and
  "Bridge offline" in the banner-suppression and onboarding tests.
- `client/desktop`: `desktop_settings_screens_test` (25 tests). They cover
  confirm before logout, `verifyNever` before the confirmation, and
  "Signed in with" shown once.
- `client/module_app_ui` settings tests (33) and the `module_prego`
  large-title scaffold tests. A new case checks that the title is centred on
  the Close button at the 16 px inset.
- `dart analyze --fatal-infos` is clean in module_prego, module_app_ui, app
  and desktop.
- Before and after renders (phone and desktop, fixture data only) are in the
  PR body.
