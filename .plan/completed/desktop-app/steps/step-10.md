# Step 10 — `module_auth` logout/rejection hardening

Date: 2026-08-30.

## Delivered

- Added an auth-generation fence owned by `AuthManager`. Local logout,
  definitive refresh rejection, and each new interactive login advance the
  generation, so an older restore, refresh, OAuth completion, email login, or
  Apple login cannot re-save credentials or emit `AuthAuthenticated` after a
  newer auth decision.
- Added a private mutation lock around credential/user persistence, OAuth
  cleanup, and auth-state emission. Every awaited write is followed by a
  generation/ownership check; a superseded token result clears any tokens it
  managed to write before it returns. Refresh singleflight is scoped to the
  auth generation, so a new account is not blocked by a stale pending request.
- Fenced both `/auth/me` restore paths, including the no-refresh local restore
  path. A restored user is saved and emitted only while its generation remains
  current.
- Distinguished definitive `/auth/refresh` rejection (the auth server's 401
  invalid/revoked response) from transport and other server failures. A
  rejection clears persisted tokens and the cached user before emitting
  `unauthenticated`; offline, transport, and non-definitive server failures
  remain non-destructive.
- Terminal OAuth cleanup attempts PKCE, provider, and persisted-session removal
  independently, while retaining the generation/ownership fence so an older
  flow cannot clear a newer flow's state.
- Removed `AuthGateCubit`'s temporary timeout and unconditional post-fence
  re-clear workaround. It now delegates sign-out directly to
  `DesktopLogoutOrchestrator`; auth-generation ownership remains in
  `module_auth`.
- Updated account/onboarding regression guidance and retired the obsolete
  Step 7 note about the temporary gate fence.

No database, relay, or auth wire-contract change. The change hardens local
credential lifecycle and in-memory state ordering only.

## Architecture implementation review

The Step 10 architecture implementation review approved the changed
`module_auth` and `module_desktop_core` behavior with no findings. It confirmed
that `AuthManager` retains ownership of auth state, persistence, generation
fencing, and mutation serialization, while `AuthGateCubit` remains a consumer
that delegates coordinated logout.

## Verification

- `client/module_auth`: `dart analyze --fatal-infos` clean; full suite passed
  (108 tests), including refresh-rejection relaunch, transient-4xx handling,
  generation-scoped refresh, OAuth cleanup failure, and
  login/restore/refresh race coverage.
- `client/module_desktop_core`: `dart analyze --fatal-infos` clean; full suite
  passed (155 tests), including direct sign-out delegation while restore is
  pending.
- `client/module_core`: `dart analyze --fatal-infos` clean; full suite passed
  (1,459 tests).
- `client/app`: `flutter analyze --fatal-infos` clean; full suite passed (913
  tests).
- Dart LSP reported zero diagnostics across all changed Dart files.
- `git diff --check` clean.

## Completed handoff

Step 10 merged in PR #1212 on 2026-08-30. MT gate B remains the user-run
daily-driver checkpoint after Step 12.
