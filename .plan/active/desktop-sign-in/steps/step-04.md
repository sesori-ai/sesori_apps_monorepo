# Step 4 — Desktop Layout With Apple And Email

Branch `desktop-sign-in/layout`. Decisions D1 and D2, Architecture section 4.

## Apple Gate

On 2026-09-25, one unauthenticated `POST https://api.sesori.com/auth/apple/init` was sent with the client's body shape: `clientType: app_macos`, a fixture device name and a random `X-Sesori-Session-Token`. The server answered **HTTP 200** with an authorize URL on `appleid.apple.com` and `expiresIn` 300. The deployed server accepts desktop client types for Apple, so the Apple button ships.

**Pending the user:** a full Apple sign-in from a macOS desktop build to the cockpit. It needs the user's Apple ID, so this session could not run it. The step 8 matrix's macOS Apple row covers it.

## Scope Delivered

- `LoginView` is one `Row` at every width: `LoginBrandPanel` and the sign-in column. At 820 pt and wider, the panel (aurora, logo, "Sesori" and the tagline) takes 44% of the window, up to 560 pt. Below 820 pt it fades while its width eases to nothing (200 ms, instant under reduced motion), and the logo appears above the column. Both layouts share one tree, so crossing the breakpoint keeps what was typed.
- The column scrolls. A tall window centres it and pins the legal sentence to the bottom; at 560×480 it scrolls through to the legal sentence. The top 54 pt stays clear for the window drag band.
- Buttons: "Continue with GitHub", "Continue with Apple" and "Continue with Google" as `PregoButtonsSolid` primaryAlt xl buttons with logos, then a tertiary "Sign in with email".
- Email: "Sign in with email" swaps the buttons for the shared `EmailLoginForm` in the same column. The form gains `required VoidCallback? onBack`. The desktop passes "Other ways to sign in"; the phone sheet passes `null` because the sheet has its own close control. Switching either way calls `onDismissedLoginFailureError()` before the swap.
- Legal: `loginAgreementText`, with its links opening in the browser through the injected `openDesktopExternalLink`.
- Every string is localized in `app_en.arb`. The hard-coded English and the "native-iOS-only" comment are gone.
- `SesoriLogo` and `SesoriBackgroundWidget` move, with their assets, from `client/app` to `module_app_ui` so both shells can draw them. `vector_graphics` moves with them.

## Deviations

- **Apple gate.** The plan asked for a completed Apple sign-in before the button ships. The orchestrating session replaced that gate with the init probe above, so the button ships now and the end-to-end run waits for the user.
- **Shared logo and aurora.** The plan did not name this move. The brand panel needs both, and copying the widgets and about 700 KB of artwork into the desktop would have duplicated them.
- **Folded background.** The folded column uses the theme background with the logo on top, not direction C's full-bleed aurora.
- **Interim status line.** Waiting, timeout and failure still use the minimal localized status line below the buttons, with the existing copy. Step 5 replaces it with the handoff card, the approved expired and declined copy and the fixed-height notice slot.

## Automated Evidence

Toolchain: Flutter 3.47.5. `dart analyze --fatal-infos` is clean in `module_app_ui`, `app` and `desktop`.

| Command | Result |
|---|---|
| `flutter test test/features/login` in `client/desktop` | 17 passed |
| `flutter test test/features/auth_gate test/app_smoke_test.dart test/core/widgets/desktop_window_drag_area_test.dart` in `client/desktop` | 9 passed |
| `flutter test test/features/login` in `client/module_app_ui` | 10 passed |
| `flutter test test/features/login test/features/settings test/core/widgets/session_split test/core/routing` in `client/app` | 180 passed |

The desktop tests cover:

- The layouts at 1,200×800, 819×800 and 560×480. The last scrolls to the legal sentence.
- Crossing the breakpoint keeps typed text.
- A mouse drag in the top band at 560×480 drags the window.
- Each provider button starts its provider.
- The legal link opens the Terms URL.
- The interim waiting, timeout, browser-failed and declined states.
- Two stale-error cases: a provider failure followed by switching to email shows no error in the form, and an email failure is gone after "Other ways to sign in". Removing the dismissal call fails both tests.

## Review

`architecture-implementation-review`, scope `origin/main...HEAD`: **approved** on the first review, with no findings.

## Manual

Before and after renders at 1,200×800 in both themes, plus 819×800, 560×480 and the email form, use fixture data only. They are in the PR. No live desktop run was made in this step.
