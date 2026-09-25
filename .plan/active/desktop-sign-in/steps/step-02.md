# Step 2 — Cancellable, Described Browser Sign-In

Branch `desktop-sign-in/cancellable-browser-login`. Architecture sections 1
and 2 plus the phone waiting line.

## Scope Delivered

- `module_auth`:
  - `startOAuthFlow` returns `OAuthHandoff`, which carries the URL, the expiry and the device name.
  - The new `cancelOAuthFlow()` releases ownership synchronously. It clears the stored session only while no newer flow owns the manager and the stored token is still the cancelled one.
  - Denied and expired statuses throw the typed errors `OAuthFlowDenied` and `OAuthFlowExpired`.
- `module_core`:
  - `LoginPolling` carries a `LoginHandoff` (the provider, the `OAuthHandoff` and the browser launch result).
  - `LoginCubit` gains `cancel()` and `reopenBrowser()`.
  - A failed launch keeps the attempt waiting.
  - A new `declined` reason replaces `browserOpenFailed`.
  - The terminal-cause rule: an attempt whose browser never opened on any launch reports `launch` when it is cancelled or times out.
- Phone: `LoginWaitingLine` shows the Cancel link in every waiting state. The "Could not open browser" message appears only after a failed launch. Declined has its own copy.
- Desktop: a minimal interim Cancel and a browser-failed message, so that a failed launch cannot trap the window until steps 4–5.

## Deviation

The provider record is moved to step 6: the in-memory field, the `oauth_provider` write, the `pollForResult` read and the "survives an interrupted-poll resume" test. Nothing reads the provider before "Last used" in step 6. The implementation review rejected a write with no reader, and PLAN.md now assigns the record and its check to step 6.

## Automated Evidence

Toolchain: Flutter 3.47.5. `dart analyze --fatal-infos` is clean in `module_auth`, `module_core`, `module_app_ui`, `app` and `desktop`.

| Command | Result |
|---|---|
| `dart test` in `client/module_auth` | 118 passed |
| `flutter test` in `client/module_core` | 1978 passed |
| `flutter test test/features/login` in `client/app` | 17 passed |
| `flutter test test/features/login` in `client/desktop` | 8 passed |
| `dart test` in `client/module_desktop_core` | 333 passed |

## Review

`architecture-implementation-review`, scope `origin/main...HEAD`:

- First review: **rejected**. Its one finding was the provider write with no reader, fixed as described under Deviation.
- Second review: **approved**.

## Manual

Not run in this step. The on-device checks belong to the step 8 matrix.
