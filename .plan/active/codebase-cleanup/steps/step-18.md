# Step 18/45 - Consolidate auth, abortable requests, and encryptor ownership

## Re-verification against Step 17

Auth-server behavior remained split across OAuth, registration, profile, token
validation, and refresh classes. Registration, token refresh, and
`SesoriServerApi` also maintained separate deadline/abort implementations.
`BridgeRuntimeAuthService` loaded the token file a second time when validation
failed, and room-key encryption was reconstructed independently by the
orchestrator and SSE delivery.

The implementation now:

- exposes OAuth, bridge registration, profile lookup, and startup token
  validation through one injected `AuthApi`;
- renames `TokenManager` to `TokenService` and routes its refresh request,
  registration requests, and `SesoriServerApi` requests through one
  `AbortableRequestClient` contract;
- keeps request deadlines active through response-body consumption, rejects
  already-aborted requests before dispatch, and detaches timers/listeners after
  completion;
- loads stored startup tokens once before deciding whether to reuse the saved
  provider or prompt for a fresh login;
- normalizes auth-backend trailing slashes through one foundation helper;
- shares one room-key `SessionEncryptor` across routed responses and SSE frames
  while retaining independent ephemeral encryptors for key exchanges;
- centralizes restricted temporary-write, permission, and rename behavior for
  bridge-id and onboarding-marker files; and
- relocates data-directory hardening to the foundation layer used by all file
  boundaries.

There is no wire-contract, database-schema, or intended user-visible behavior
change. Deadline expiry now consistently aborts the underlying HTTP operation,
and persisted private-file permissions remain owner-only on Unix.

## Regression evidence

- `dart analyze --fatal-infos`: no issues.
- Focused auth, storage, request, crypto, SSE, repository, runtime-auth,
  registration, and token re-auth matrix: 182 tests passed.
- `git diff --check`: clean.
- `dart format` checked 42 supported touched Dart files without changes. The
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
environment on both invocation attempts. A best-effort architecture-only review
against the repository rules approved the boundaries and identified two minor
findings; direct foundation imports replaced an internal re-export, and token
validation now uses sealed valid/invalid variants.

The independent correctness and security review found one startup regression:
a successful refresh response with empty tokens could be persisted. Empty
tokens are rejected again, with direct regression coverage. No findings remain.
