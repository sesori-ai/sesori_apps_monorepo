# Step 5 — Handoff Card And Inline Errors

Branch `desktop-sign-in/handoff-card`. Architecture section 4, Approved Copy.

## Scope Delivered

- While `LoginPolling` waits, `_DesktopHandoffCard` replaces the provider buttons under the unchanged heading.
  - With the browser opened, it shows a spinner, "Continue in your browser", the waiting copy with the provider and the device name set off, "The link expires in m:ss", "Open again" and "Copy link".
  - When the browser failed to open, it shows an error icon, the approved title and copy, "Copy link" and "Try again".
  - Both end with "Cancel and choose another way".
- The countdown is a one-second `Timer.periodic` in the card's state. It compares `clock.now()` with `OAuthHandoff.expiresAt`, stops at 0:00, and is cancelled with the card.
- Open again and Try again call `LoginCubit.reopenBrowser()`. Cancel calls `cancel()`. Copy link writes the auth URL through `copyTextToClipboard` and shows the informational "Link copied to clipboard" popup.
- `LoginTimeout` and `LoginFailed` show a `_Notice` above the re-enabled buttons:
  - the approved expired copy;
  - the approved declined copy;
  - "Authentication failed" over the shared `LoginFailedReason` message for any other reason.

  The notice covers the heading, which keeps its footprint, so the buttons do not move as a notice appears or clears.
- While a provider sign-in starts, the tapped button shows its spinner and every option is disabled.
- Step 4's interim `_LoginStatus` and `_StatusRow` are gone. The 14 new strings are in `app_en.arb`.

## Deviations

- **Notice in the heading's place.** Mock 2a keeps "Sign in" above the notice. That would either grow the column and move the buttons, or reserve an empty slot of about 100 pt above them in every idle frame. Instead the notice takes the heading's place, 16 pt above the buttons.
- **`clock` dependency.** `client/desktop` now depends on `package:clock`, so widget tests can drive the countdown with the fake test clock. It is already a direct dependency of `module_prego` and `bridge/app`, and the lockfile is unchanged.
- **Copy confirmation.** Copy link shows "Link copied to clipboard", like onboarding's "Command copied to clipboard". The approved copy did not list it.
- **Starting feedback.** Step 4's "Signing in..." status line is replaced by a spinner on the tapped button.

## Automated Evidence

Toolchain: Flutter 3.47.5. `dart analyze --fatal-infos` is clean in `desktop` and `module_app_ui`.

| Command | Result |
|---|---|
| `flutter test test/features/login` in `client/desktop` | 23 passed |
| `flutter test test/features/auth_gate test/app_smoke_test.dart` in `client/desktop` | 4 passed |

The new desktop tests cover:

- **Waiting card.** It shows the title, the waiting copy with provider and device, "The link expires in 4:32", Open again, Copy link and Cancel. No provider button or email link remains.
- **Countdown.** It reads 4:31 after one second, 0:00 at expiry, and still 0:00 five seconds later.
- **Browser failed.** It shows the title, the copy, the countdown, Copy link, Try again and Cancel, and no Open again.
- **Reopening.** Open again and Try again each call `reopenBrowser()` once.
- **Copy link.** The auth URL reaches the platform clipboard, and the popup shows.
- **Cancel.** It calls `cancel()`. Once the cubit is idle, the card is gone and every option is enabled.
- **Notices.** Each of expired, declined and an unknown failure:
  - shows its title and message above the GitHub button;
  - leaves every option enabled;
  - keeps the GitHub button's rect equal to its idle rect while the notice shows and after it clears.
- **Starting.** The tapped provider spins while the others are disabled.

## Review

`architecture-implementation-review` was not run. The card and notice are private widgets inside the existing `login_screen.dart`. There are no new files, no moved classes, and no state-ownership or DI change. `LoginCubit` still owns the handoff, and the only new dependency is the `clock` utility above.

## Manual

Before and after renders at 1,200×800 are in the PR. They cover waiting, browser failed and expired in both themes, with fixture data only (device "MacBook Pro"). No desktop app or bridge was launched or stopped in this step.

**Pending the user:** the real GitHub run on macOS that the plan asks for. In a macOS desktop build of this branch, signed out:

1. Click "Continue with GitHub". The browser opens GitHub sign-in. The app shows "Continue in your browser" with GitHub and this Mac's device name, and the countdown drops by one every second.
2. Close that browser tab and click "Open again". The same sign-in page opens, and the countdown carries on without resetting.
3. Click "Copy link". "Link copied to clipboard" appears. Paste the link into another browser or a private window, then finish signing in there. The app reaches the cockpit.
4. Sign out. Click "Continue with GitHub", then "Cancel and choose another way" before confirming. The provider buttons return at once.
5. Finish that sign-in in the page that is still open. The app stays signed out.
6. Right away, sign in with GitHub or Google again. It completes normally.
