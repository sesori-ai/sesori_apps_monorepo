# Bridge App Onboarding

## Status

- **Plan slug:** `bridge-app-onboarding`
- **Implementation base:** monorepo `main`
- **Pinned W02 base:** `4a156a78b3bf8572c280ce859b3b1370300a8105`
- **Auth dependency:** `sesori-ai/sesori_auth_server` PR #44 must merge and deploy before bridge release.
- **Current state:** W01 implemented; W02 redesigned after the user rejected an over-broad first implementation.

## Goal

Help a standalone interactive bridge user install/sign in to a Sesori client
without turning onboarding into an auth, token, persistence, or terminal-system
rewrite.

The bridge checks the current account once. If no client is registered, it shows
a bounded terminal QR plus the exact URL
`https://sesori.com/app/?openStore=true`, waits for one server-held 30-second
registration round, and then continues startup regardless of outcome.

After registration is confirmed, the bridge attempts to persist a completion
flag keyed by an opaque SHA-256 digest of the normalized configured auth backend
and that account's existing JWT `userId` claim. Each backend/account pair keeps
its own flag, so once persistence succeeds the A -> B -> A sequence checks A and
B once each. Accepted CLI logout clears all completion flags so the next login
checks again.

## Locked Behavior

1. Run only for standalone interactive startup.
2. Run after authentication and the selected plugin's quick availability check,
   but before provisioning, startup mutex acquisition, or plugin startup.
3. Parse the account id with existing `parseJwtUserId` and normalize the
   configured auth base without changing profile, login, validation, refresh,
   `TokenManager`, or token persistence.
4. If the marker for that backend/account pair exists, perform no status request
   and emit no onboarding output.
5. Otherwise perform one immediate authenticated status request.
6. `registered: true` marks the account complete and continues silently.
7. `registered: false` prints same-account guidance, a QR when safe, and the
   exact plain URL, then performs exactly one `wait=true` request.
8. A true long-poll result marks the account complete, prints one success line,
   and continues.
9. A false long-poll result prints one concise timeout/continuation line and
   continues. Each of the immediate and long-poll requests has its own
   abortable 35-second deadline, so even a slow immediate false response followed
   by the long poll remains bounded to about 70 seconds total.
10. Any auth, network, timeout, malformed-response, or unsupported-server failure
    warns once and fails open. There is no refresh, retry loop, retry timer, skip
    prompt, or asynchronous stdin ownership; only the status API owns a
    request-local deadline timer/abort trigger.
11. A marker read failure warns and still performs the remote check. A marker
    write failure warns and continues; the next run may check again.
12. After logout is accepted, clear all onboarding markers before clearing
    tokens. If state deletion fails, return the existing failed logout result
    and leave tokens intact so no successful logout can leave stale completion
    state. Cancelled logout changes neither tokens nor markers.
13. QR output is rendered only with validated ANSI and Unicode support and known
    sufficient terminal width. Otherwise output the URL only.

## Scope

### In Scope

- Consume auth PR #44's `GET /auth/app-clients/status` endpoint in immediate and
  `?wait=true` modes.
- Add one bridge-local Freezed `{registered: bool}` response model.
- Add a narrow app-client-status API and repository without migrating existing
  auth APIs.
- Add a tiny raw marker-directory storage and repository with one opaque
  SHA-256-named flag per normalized-auth-backend/JWT-userId pair.
- Add one onboarding service and one QR formatter.
- Add pure-Dart `qr` and its normal lockfile update.
- Insert one bounded runner checkpoint and clear all markers in accepted CLI
  logout.
- Add focused API/repository/service/formatter/logout tests and build the host
  bridge.

### Explicit Non-Goals

- No `SesoriAuthApi` consolidation or migration of email, OAuth, profile,
  validation, refresh, or bridge-registration HTTP.
- No `TokenManager` rename, token contract change, cancellation primitive,
  forced refresh, token repository/storage layering, or call-site migration.
- No terminal API/repository move, asynchronous stdin owner, provider/password/
  replacement/logout prompt change, skip input, or indefinite wait.
- No shared DTO, relay, plugin, mobile, desktop, database, CLI/config, analytics,
  browser-launch, or app-store integration change.
- No generic polling/retry framework or speculative compatibility abstraction.

## Minimal Architecture

```text
AppClientStatusApi (new Layer 1 HTTP boundary)
  -> AppClientStatusRepository (new Layer 2 result mapping)

AppOnboardingStateStorage (new Layer 1 raw marker directory)
  -> AppOnboardingStateRepository (new Layer 2 pair lookup/write/clear-all)

AppClientStatusRepository + AppOnboardingStateRepository
  + AppOnboardingFormatter
  -> AppClientOnboardingService (new Layer 3 bounded policy)
  -> BridgeRuntimeRunner (existing startup composition)

AppOnboardingStateRepository
  -> BridgeLogoutRunner (after acceptance, clear marker directory before tokens;
     state-clear failure returns failed and leaves tokens intact)
```

`AppClientStatusApi` uses a request-local `http.AbortableRequest`, deadline
`Timer`, and abort completer so its 35-second deadline closes the underlying
request. It cleans the timer/trigger in `finally`; this does not add a shared
cancellation abstraction or touch any existing auth operation.

The existing auth provider boundary is already split across legacy use-case APIs
and top-level functions. Adding `AppClientStatusApi` is a deliberate narrow
exception to the normal one-API-per-provider preference: consolidating the
provider was attempted and explicitly rejected as disproportionate scope. This
PR must not use the new class as a reason to migrate existing auth behavior.

## Expected Files

New production files:

- `bridge/app/lib/src/auth/app_client_status_response.dart` plus generated files
- `bridge/app/lib/src/auth/app_client_status_api.dart`
- `bridge/app/lib/src/auth/app_client_status_repository.dart`
- `bridge/app/lib/src/api/app_onboarding_state_storage.dart`
- `bridge/app/lib/src/repositories/app_onboarding_state_repository.dart`
- `bridge/app/lib/src/foundation/app_onboarding_formatter.dart`
- `bridge/app/lib/src/services/app_client_onboarding_service.dart`

Existing production files changed:

- `bridge/app/lib/src/bridge/runtime/bridge_runtime_runner.dart`
- `bridge/app/lib/src/bridge/runtime/bridge_logout_runner.dart`
- `bridge/app/bin/bridge.dart`
- `bridge/app/pubspec.yaml`
- `bridge/pubspec.lock`

Tests mirror those owners. No other production path is expected to change.

## Data And Failure Rules

- Status URI is the configured auth base plus `/auth/app-clients/status`; only
  long-poll mode adds `wait=true`.
- Bearer token appears only in the authorization header.
- Only HTTP 200 with strict `{registered: bool}` is accepted.
- API requests use the runner-owned shared `http.Client`; the API never closes it.
- Both immediate and long-poll requests have a 35-second client deadline that
  actively aborts the request and cancels its local timer in every completion
  path.
- Repository maps 404/405 through this exact compatibility seam:

```dart
// COMPATIBILITY <implementation-date> (v1.5.1): Auth servers predating app-client status return 404/405, so onboarding must fail open for older/custom deployments. Remove this fallback and its endpoint-omission tests after every supported auth server exposes GET /auth/app-clients/status.
```

- All remote failures become one unavailable outcome. The service is the sole
  warning owner.
- The repository derives each marker name as SHA-256 over the UTF-8 JSON encoding
  of `[normalizedAuthBackend, userId]`. The storage sees only that opaque key;
  marker files are empty and contain no token, profile, backend URL, or user id.
- Marker storage enforces a 0700 marker directory and 0600 files on Unix,
  matching existing token and bridge-id storage; Windows retains existing
  platform behavior.
- A missing pair marker means not completed. Different backend/user pairs retain
  independent markers; confirming B never replaces A.
- A pair marker is written only after a true response, never after timeout,
  false, or failure. Accepted logout clears the entire marker directory.
- A missing/unreadable JWT `userId` cannot be cached; warn and fail open without
  making a status request because the same-account invariant cannot be enforced.

## QR Rules

- Encode exactly `https://sesori.com/app/?openStore=true` with fixed correction
  level M.
- Add four light modules on every side.
- Render compact half blocks with explicit black/white ANSI foreground and
  background, ending each row with reset.
- Require existing terminal ANSI and Unicode validators and safely read
  `Stdout.terminalColumns`.
- Unknown/throwing/insufficient width or unsupported capabilities returns the
  exact URL without QR output.

## Verification

Focused tests prove:

- exact immediate/long-poll URI, bearer header, strict model parsing, status and
  timeout failures;
- repository registered/absent/unavailable mapping and 404/405 marker;
- marker missing/match/different-backend/different-user/A-B-A/read-write-clear-
  all/error behavior and Unix permissions;
- matching account performs zero network requests;
- confirmed immediate/long-poll registration writes that pair marker;
- false long poll is bounded and does not write; failures warn and fail open;
- formatter quiet zone, width/capability fallback, explicit colors/reset, and
  exact URL;
- runner mode/order insertion remains before plugin startup and outside mutex;
- accepted logout clears all markers then tokens; state-clear failure returns
  failed and leaves tokens intact; cancelled logout clears neither.

Commands:

```text
# bridge
dart pub get
make codegen
make analyze
make test

# bridge/app
dart analyze --fatal-infos
make build-host
```

No client/shared package verification is required because W02 changes no shared
or client contract.

## Release Order

1. Merge and deploy auth PR #44.
2. Merge W02 after focused verification and implementation review.
3. Release through the existing bridge process.
4. Run S01-W02-M01 against a disposable same-account app registration.
