# Step 6 — Last Used And Window Forward

Branch `desktop-sign-in/last-used`. Architecture sections 1 and 4.

## Storage Backend

`LastSignInStorage` sits on the typed `SecureStorageRepository` from `sesori_persistence`, under the new `AuthSecretKey.lastSignInProvider` (`last_sign_in_provider`). PR #1751, the `desktop-master-key-storage` client cutover, merged on 2026-09-26 at 05:31 UTC, before this step started. The branch was fast-forwarded to that `main`, and step 5 (#1759) was later merged in; nothing was rebased.

## Scope Delivered

- `AuthManager` records the provider of each interactive sign-in right after the authenticated emit, so a login that logout superseded records nothing. The OAuth poll passes the provider `startOAuthFlow` recorded; `_completeInteractiveLogin` passes email or Apple.
- The Layer-1 `LastSignInStorage` stores only the provider key. A failed write or read is logged and never fails the sign-in. Logout leaves the key alone. `AuthSession.lastSignedInProvider()` reads it.
- `LastSignInProviderCubit` in `module_desktop_core` loads it once; `LoginScreen` builds it next to `LoginCubit`. The matching provider button carries a "Last used" chip tinted like its label; after an email sign-in, a `PregoTag` sits on "Sign in with email".
- `AuthGateCubit` takes `WindowHost` and calls `show()` only on signed-out → signed-in, logging a failure. A startup restore leaves checking, so a `--hidden` launch stays hidden.
- `docs/regression/account-and-onboarding.md` gains the behaviour and its failure signal. No analytics.

## Deviation

The in-flight OAuth provider lives in memory only, keyed by session token, and releasing ownership keeps it. The plan also had it written to the `oauth_provider` storage slot. Memory covers the one resume path, an interrupted poll resumed in the same process; a fresh process never resumes. PLAN.md section 1 and the Complexity Budget record this.

## Automated Evidence

Toolchain: Flutter 3.47.5. `dart analyze --fatal-infos` is clean in `module_auth`, `module_core`, `module_desktop_core`, `module_app_ui` and `desktop`.

| Command | Result |
|---|---|
| `dart test` in `client/module_auth` | 121 passed |
| `dart test` in `client/module_desktop_core` | 335 passed |
| `flutter test`, every committed test, in `client/desktop` after merging step 5 | 331 passed |

- `AuthManager` records the poll's provider, Apple and email, keeps the key through logout, and records nothing for a login that logout superseded. A storage error is logged, not thrown.
- A poll that fails in the background still records its provider when it resumes. Clearing the record on release fails this test.
- The gate shows the window on signed-out → signed-in only: never on a cold-start restore or a background recovery. A failed `show()` still signs in.
- Widget tests cover no marker, the chip, the email marker, and `LoginScreen` with `getIt` fakes showing the stored provider's chip.

## Review

`architecture-implementation-review`, scope `origin/main...HEAD`: **approved** on the first review. Of its three non-blocking notes, the `module_auth` DI list now names `LastSignInStorage`, and this file answers the plan's storage-backend sentence. The third note was left alone: it is about old code this step did not create. `OAuthStorageService`'s provider and PKCE writer and readers have had no production callers since before this step.

## Manual

Before and after renders of the idle column in both themes, with the chip and with the email marker, use fixture data only and are in the PR. The renders are byte-identical before and after merging step 5. No live desktop run was made in this step.
