# Step 18/45 - Consolidate auth, abortable requests, and encryptor ownership

## Re-verification against Step 17

Auth-server behavior remained split across OAuth, registration, profile, token
validation, and refresh classes. Registration, token refresh, and
`SesoriServerApi` also maintained separate deadline/abort implementations.
`BridgeRuntimeAuthService` loaded the token file a second time when validation
failed, and room-key encryption was reconstructed independently by the
orchestrator and SSE delivery.

The implementation now:

- exposes OAuth, bridge registration, profile lookup, and token-refresh
  endpoints through one injected `AuthApi`, with `AuthRepository` mapping the
  profile and refresh results for services;
- keeps startup token validation and refresh policy in
  `BridgeRuntimeAuthService` and renames `TokenManager` to `TokenService`;
- injects an `AuthRequestSender` at runtime composition for bounded auth and
  registration requests, backed by the shared foundation abort implementation
  also used by `SesoriServerApi`;
- keeps request deadlines active through response-body consumption, rejects
  already-aborted requests before dispatch, and detaches timers/listeners after
  completion;
- loads stored startup tokens once before deciding whether to reuse the saved
  provider or prompt for a fresh login;
- normalizes auth-backend trailing slashes at CLI composition through one
  foundation helper before the URL enters the auth subsystem;
- shares one room-key `SessionEncryptor` across routed responses and SSE frames
  while retaining independent ephemeral encryptors for key exchanges;
- centralizes restricted temporary-write, permission, and rename behavior for
  the token, bridge-id, and onboarding-marker files in `writeRestrictedFile`,
  injected into auth persistence as a `RestrictedFileWriter`; and
- relocates data-directory hardening to the foundation layer used by all file
  boundaries.

There is no wire-contract, database-schema, or intended user-visible behavior
change. Deadline expiry now consistently aborts the underlying HTTP operation,
and persisted private-file permissions remain owner-only on Unix.

## Regression evidence

- `dart analyze --fatal-infos`: no issues.
- Focused auth, storage, request, crypto, SSE, repository, runtime-auth,
  CLI-composition, registration, and token re-auth matrix: 204 tests passed.
- `git diff --check`: clean.
- `dart format` formatted or confirmed the supported touched Dart files. The
  pinned formatter still crashes on existing enhanced enum bodies in
  `orchestrator.dart`, `bridge_runtime_runner.dart`, `login_oauth_service.dart`,
  and `login_test.dart`; analyzer parsing is clean and edited sections retain
  existing formatting.
- `docs/regression/account-and-onboarding.md` now records single-load auth and
  abortable deadline behavior.
- `docs/regression/bridge-connectivity.md` now records session encryptor and
  per-frame nonce ownership.

## Review

The required architecture implementation review skill was unavailable in the
environment on both initial invocation attempts. A best-effort architecture-only
review identified two minor findings; direct foundation imports replaced an
internal re-export, and token validation now uses sealed valid/invalid variants.

The independent correctness and security review found one startup regression:
a successful refresh response with empty tokens could be persisted. Empty
tokens are rejected again, with direct regression coverage. No findings remain.
Follow-up pull-request review moved endpoint-result mapping into
`AuthRepository`, kept startup validation policy in the runtime service, bounded
the underlying validation requests, and flushed private temporary files before
rename. A later pass replaced the injected `final` `AbortableRequestClient`
(not substitutable outside its library, so the constructor parameter was dead
flexibility) with a plain function, folded `saveTokens` into
`writeRestrictedFile` as planned, and restored the 401-then-refresh-rejected
startup coverage with a `MockClient` instead of an unused local HTTP server.
A later pull-request review correctly identified that the resulting auth imports
of core foundation violated the subsystem boundary. Runtime composition now
injects bounded-request and restricted-write capabilities, and URL normalization
happens before construction; production `auth/` has no core-layer imports.
The architecture implementation reviewer approved this final boundary fix with
no findings.
