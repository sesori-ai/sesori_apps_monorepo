# Step 3 — Shared Email Form

Branch `desktop-sign-in/email-form`. Architecture section 3.

## Scope Delivered

- `module_app_ui` gains `EmailLoginForm` (`lib/src/features/login/email_login_form.dart`). It reads `LoginCubit` from context and owns the controllers, validation, the inline failure and the autofill commit. The host decides what a success does through a required `onSignedIn` callback.
- The phone's `showEmailLoginSheet` keeps the modal wrapper, the stale-error clearing and the pop after success, and hosts the shared form. The phone-only `EmailLoginSheet` widget is gone.
- The `LoginFailedReason` → message extension moves from `client/app` into `module_app_ui` (`lib/src/extensions/login_failed_reason_x.dart`). The phone banner and form use it, and the desktop's interim failure line now uses it instead of two hard-coded strings.
- Form tests move to `module_app_ui/test/features/login/email_login_form_test.dart`. The phone sheet test keeps the presenter cases: close on success and clear a stale failure on open.

## Deviations

- **LG2 was already fixed.** Visual-hierarchy step 8 (`34433454aa`) removed `PregoInputField`'s brand asterisk and moved the placeholder from `textPlaceholder` to `textTertiary`. The review page's phone screenshot predates it. This step makes no styling change. Renders of the phone sheet on origin/main and on this branch are pixel-identical in both themes.
- **`onBack` moves to step 4.** The desktop's "Other ways to sign in" link is its only consumer, and nothing hosts the form on desktop before step 4. That step adds the callback together with its reader.

## Automated Evidence

Toolchain: Flutter 3.47.5. `dart analyze --fatal-infos` is clean in `module_app_ui`, `app` and `desktop`.

| Command | Result |
|---|---|
| `flutter test test/features/login` in `client/module_app_ui` | 8 passed |
| `flutter test test/features/login` in `client/app` | 11 passed |
| `flutter test test/features/login` in `client/desktop` | 8 passed |

## Review

`architecture-implementation-review`, scope `origin/main...HEAD`: **approved** on the first review, with no findings.

## Manual

The by-hand phone email sign-in was not run: no fixture email account is available to this session. The iOS and Android email rows of the step 8 matrix cover it.
