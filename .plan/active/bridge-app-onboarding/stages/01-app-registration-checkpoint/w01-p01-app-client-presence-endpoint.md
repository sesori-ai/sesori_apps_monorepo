# S01-W01-P01: Add App-Client Presence Endpoint

## 0. Metadata

- **ID:** S01-W01-P01
- **Repository:** `sesori-ai/sesori_auth_server`
- **Worktree:** one dedicated auth-server worker worktree for this PR
- **Base branch:** `master`
- **Branch:** `plan/bridge-app-onboarding/s01-w01-p01-app-client-presence-endpoint`
- **Wave baseline:** pin the assessed current `master` tip in `TRACKER.md` before branch creation
- **Audited reference:** `b17a6e760b0c70c3dc3d1cd456ff93d814c75453`
- **Audited reference date:** 2026-07-16T14:14:09Z
- **Contract-affecting:** Yes — additive authenticated HTTP endpoint

## 1. Goal and Cohesion

Expose whether the authenticated user has any current app token and support a
30-second wait that wakes after durable token registration. The PR is
independently cohesive: it adds and tests the complete server contract without
requiring a bridge release, while existing app registration/deletion clients
retain byte-compatible requests and responses.

## 2. Dependencies and Baseline

- No implementation PR dependency beyond the approved plan.
- Fetch `master`, assess changed planned paths and auth middleware/device-token
  contracts from the audited reference, and pin the exact tip before branching.
- Re-read root `AGENTS.md`, current package version, the activation-reminder
  instructions, and current OAuth long-poll tests after pinning.
- Preserve the documented single-instance deployment constraint. Do not add
  Redis, Mongo change streams, a lease, or cross-instance pub/sub.
- Same-wave sibling baseline reuse is not applicable; this wave has one PR.

## 3. Scope

### In Scope

- Add `DeviceTokenRepository.hasAnyForUser(userId)` using an existence query
  that benefits from the existing user-leading index and does not load token
  arrays or expose token values.
- Add `AppClientPresenceService` with injected `DeviceTokenRepository`.
- Move public notification-route token upsert behind that service so it owns
  post-commit wake. Keep unchanged token deletion as a direct
  `notificationRoutes -> DeviceTokenRepository.deleteByTokenForUser` call; do
  not add a pass-through service method.
- Add immediate current-registration reads.
- Add race-safe per-user waiters with a 30-second route cap, request abort,
  post-registration recheck, all-same-user wake, and complete cleanup.
- Extract the proven Fastify request/reply close-to-`AbortSignal` adapter from
  OAuth status into one Foundation utility reused by both routes.
- Add authenticated `GET /auth/app-clients/status` and validated optional
  `wait=true` query.
- Add strict `appClientStatusQuerySchema` and `appClientStatusReplySchema` in
  `src/models/api.ts`, with `AppClientStatusQuery` / `AppClientStatusReply`
  inferred from those Zod schemas.
- Wire one service instance through `src/index.ts`, `AppServices`, app-client
  route, and notification route.
- Add repository, service, route, disconnect, race, and regression tests.
- Document the new process-local waiter constraint beside existing scaling
  constraints if needed for repository truth.

### Non-Goals

- Returning token, platform, device, timestamp, count, or user details.
- A liveness/heartbeat/last-seen API.
- Waking on token deletion; waiters only wait for transition from zero current
  tokens to at least one durable token.
- Changing activation milestone semantics or failure isolation.
- Changing notification send/stale-token cleanup behavior.
- New collection/index/schema/config/package dependency.
- Reusing or coupling to `PendingAuthStore`; its token-keyed OAuth state machine
  remains independent.
- Distributed signaling or multi-instance guarantees.
- Bridge code or deployment in this repository.

## 4. Audited Current Code and Assumptions

- `src/repositories/device-token-repo.ts:15-45` owns upsert/list queries and uses
  Mongo `ObjectId`; it has no current-existence method.
- `tests/notifications/device-token-repo.test.ts:161-209` proves all-token reads
  and the existing `{ userId: 1, createdAt: 1 }` index across desktop/mobile.
- `src/routes/notifications.ts:55-72` currently awaits upsert before activation
  recording; this ordering is the durable signal seam.
- `src/routes/notifications.ts:75-83` owns authenticated single-token deletion.
- `tests/notifications/routes.test.ts:82-232` proves all five platforms,
  activation ordering/failure isolation, auth, validation, and deletion.
- `src/routes/auth/session-status.ts:53-101,159-194` is the proven long-poll route
  and request-close adapter.
- `src/services/pending-auth-store.ts:419-508,593-635` proves the required
  waiter/recheck/cleanup shape but is semantically OAuth-specific.
- `src/server.ts:108-173` constructs auth middleware and registers routes from
  injected `AppServices`.
- `src/index.ts:59-101,152-171` constructs one device-token repository plus
  notification/activation services.
- Tests run sequentially with MongoDB through `tests/helpers/setup.ts`; new
  service injection must preserve override/test cleanup behavior.
- `DevicePlatform` already includes iOS, Android, macOS, Windows, and Linux; no
  platform model change is needed.

## 5. Design and Ownership

### Expected files

- `src/lib/request-close-signal.ts` (new extraction)
- `src/repositories/device-token-repo.ts`
- `src/services/app-client-presence-service.ts` (new)
- `src/routes/app-clients.ts` (new)
- `src/routes/auth/session-status.ts`
- `src/routes/notifications.ts`
- `src/models/api.ts`
- `src/server.ts`
- `src/index.ts`
- `tests/notifications/device-token-repo.test.ts`
- `tests/notifications/routes.test.ts`
- `tests/services/app-client-presence-service.test.ts` (new)
- `tests/auth/app-clients.test.ts` (new; use repository naming convention if
  the pinned base centralizes auth route tests elsewhere)
- `tests/auth/session-status.test.ts`
- `tests/helpers/setup.ts`
- `AGENTS.md` only if the new in-process waiter scaling fact is not otherwise
  accurately documented; do not edit unrelated guidance.

### Layers and collaborators

- Foundation request-close adapter depends only on Fastify request/reply events.
- `DeviceTokenRepository` remains the sole database owner.
- `AppClientPresenceService` depends only on the repository and owns current
  registration/waiter invariants. It does not depend on `ActivationService`,
  `NotificationService`, `PendingAuthStore`, or another service.
- `notificationRoutes` remains a consumer: registration through presence
  service, deletion directly through the existing device-token repository,
  activation through existing service, and sends through existing notification
  service.
- `appClientRoutes` remains a thin authenticated consumer over the presence
  service.
- `index.ts` is the sole constructor; `server.ts` performs injection/registration.

No DAO/repository decision moves into a route, and no same-layer peer is made a
child.

Production construction is explicit:

```ts
new AppClientPresenceService({ deviceTokenRepo })
```

`index.ts` constructs that one instance. It owns only its in-memory waiter map
and timers/listeners; it does not close the injected repository or database.
`server.ts` injects the same instance into `appClientRoutes` and
`notificationRoutes`, and retains direct `DeviceTokenRepository` injection into
`notificationRoutes` for deletion only. The Foundation close-signal adapter is a stateless
function, the route is a Fastify plugin, and the Zod contracts are schemas rather
than hidden stateful collaborators.

### Service algorithm

`registerToken({userId, token, platform})`:

1. Await `DeviceTokenRepository.upsertToken`.
2. Snapshot current waiter set for `userId`.
3. Remove/resolve each waiter as `true`; delete the empty map entry.
4. Return. If step 1 throws, perform no notification.

`waitForRegistration({userId, timeoutMs, abortSignal})`:

1. Capture one absolute deadline before starting the initial
   `hasAnyForUser` query. Race all reads/waiting through one completion gate so
   the advertised timeout includes initial-query time and late query completion
   cannot send or mutate waiter state.
2. Return true when the initial query completes present before the deadline.
3. If already aborted, the deadline has elapsed, or timeout is non-positive,
   return false/cancel according to the route contract without storing state.
4. Create waiter using only the remaining deadline budget plus a one-shot abort
   listener; store by user id.
5. Requery `hasAnyForUser` after storage.
6. If present, remove and resolve true immediately. If the recheck throws,
   remove all state before rethrowing.
7. The absolute deadline removes state and resolves false. Abort removes state and resolves a
   cancellation result that the route does not serialize to a closed socket.

Use one internal completion method so registration, recheck, timeout, abort,
and error cannot resolve or clean one waiter twice.

### Route behavior

- Require existing user auth for both immediate and wait modes.
- Define the strict query schema as an object whose optional `wait` accepts only
  the wire string `"true"`; omitted means immediate and unknown keys/values are
  invalid. Run `appClientStatusQuerySchema.safeParse(request.query)` and map
  failure to the existing 400 error form without truthy-string guessing.
- Build `{ registered }`, run
  `appClientStatusReplySchema.safeParse(candidateReply)` before sending, and map
  an impossible internal mismatch to the existing internal-server error path.
  The route never asserts or casts an unvalidated reply.
- Use a 30,000 ms route constant as one absolute service deadline beginning
  before the initial repository read; do not add environment config solely for
  this endpoint.
- After await, verify request/reply remains open. If closed, hijack/return as the
  OAuth route does rather than sending a late payload.
- Return only `{ registered }` with status 200.

### Error, lifecycle, concurrency

- Mongo errors propagate to Fastify's existing error handler; they are not
  converted to false.
- Client disconnect is expected cancellation, not a server error log.
- A timeout is normal and returns false.
- Multiple waiters for one user all resolve after one committed registration.
- A token changing owner wakes only the new owner's waiters because the service
  receives the authenticated registration user after upsert.
- Service state is process-local and bounded by concurrent open requests/FDs;
  no completed user history remains.
- Existing app registration response does not wait for bridge clients beyond
  synchronous in-memory waiter resolution.

## 6. Backward Compatibility

### Existing app clients

`POST /notifications/register-token` keeps the same auth, body, all-platform
acceptance, status, and `{ ok: true }` response. `DELETE
/notifications/tokens/:token` remains unchanged. Activation recording stays
best-effort after durable registration, so an activation failure still cannot
fail token registration.

### Existing bridge/custom clients

The new route is additive. No current client sends it, and no existing response
gains a field. There is no compatibility-only server fallback or source marker.

### Rollback and deployment pairs

- Old bridge + new server: no behavior change.
- New bridge + new server: immediate/long-poll onboarding works.
- New bridge + rolled-back/old server: bridge S01-W02-P01 handles endpoint
  absence and fails open.

## 7. Schema, Migration, and Generation

- No Mongo document schema, collection, database config, or index changes.
- No data migration or backfill.
- No generated code.
- No package dependency or lockfile change.

## 8. Verification

### Automated tests

- `hasAnyForUser` returns false with no row and true for each supported platform;
  invalid user id follows the repository's explicit safe/throw convention chosen
  at the pinned baseline and never queries an inferred id.
- Immediate service call returns true/false correctly and stores no waiter.
- Timeout resolves false and clears timer/abort/map state; controlled slow
  initial-read and recheck tests prove their elapsed time consumes the same
  absolute 30-second budget and late completions emit no second result.
- Pre-aborted signal stores nothing.
- Abort during wait resolves cancellation and clears everything.
- Registration wakes all waiters for its user, not another user's waiters.
- Upsert failure wakes nobody.
- Registration in the initial-check/register-waiter gap is observed by the
  post-registration recheck.
- Recheck error cleans state before propagation.
- Route immediate true/false, wait timeout, and registration wake return exact
  response JSON after reply-schema `safeParse`.
- Route without auth returns 401; invalid/unknown query values and keys return
  400 through query-schema `safeParse`; reply-schema rejection takes the
  internal-server error path in its focused test seam.
- Closed request produces no late payload and leaves no waiter.
- Existing token registration tests still prove all five platforms, activation
  failure isolation, response compatibility, and deletion.
- Deletion regression proves the route calls `DeviceTokenRepository` directly
  and the presence service exposes no deletion forwarding method.
- OAuth status tests prove the extracted request-close helper preserves ACK,
  timeout, terminal response, disconnect, and listener cleanup behavior.

### Manual verification

Use local/deployed injection only if convenient: authenticate a disposable user,
start one `wait=true` request, register a token through the existing route, and
observe prompt completion after registration. Do not retain bearer/token values.
The cross-repository user journey is owned by S01-W02-M01.

### Exact commands

```text
# workdir: sesori_auth_server
npm run format:check
npm run lint
npm run build
npm test
npm run circular-dependencies
```

`npm test` requires the repository's configured MongoDB test service. If it is
unavailable, record the blocker rather than replacing route/repository tests
with mocks that cannot prove durable ordering.

### Regression guide

- OAuth session status still wakes, expires, aborts, and ACKs as before.
- App registration/deletion request/response and activation behavior are
  unchanged.
- Notification sending and stale-token deletion still use
  `DeviceTokenRepository` through existing `NotificationService`.
- Auth revocation/delete-all behavior remains repository-owned and does not need
  to publish an appearance event.
- Server shutdown/test cleanup leaves no open timer caused by presence waiters.

## 9. Risks

- Notifying before Mongo commit would create a false positive; service order and
  failed-upsert test make this impossible.
- Query-then-wait can lose a transition; post-storage recheck closes the gap.
- Starting the timeout after the initial read can exceed the bridge's 35-second
  client deadline; one absolute deadline and slow-read tests enforce the route
  contract.
- Duplicating OAuth's close adapter could drift; extract and regression-test one
  Foundation seam.
- A generic presence service could absorb deletion/notifications/activation;
  keep it limited to post-commit token registration signaling plus registration
  wait. Deletion remains exclusively route -> device-token repository.
- Multi-instance signaling is intentionally absent and must remain explicit in
  docs/tests rather than implied.

## 10. Acceptance Criteria

- Authenticated immediate and long-poll endpoint returns exact boolean contract.
- Any supported platform token counts.
- Durable upsert precedes wake; failed upsert never wakes.
- Waiter race, timeout, abort, error, and multi-user tests pass with no leaks.
- Existing registration/deletion/activation and OAuth long-poll behavior passes.
- No migration, new config, dependency, token exposure, or distributed machinery
  is introduced.
- All command groups pass.

## 11. Definition of Done

- Scope, tests, docs, and verification are complete on the pinned auth-server
  baseline.
- Architecture-bearing implementation receives the configured implementation
  review required by the worker before PR opening.
- Only intended auth-server files are committed; branch is pushed and PR targets
  `master`.
- `TRACKER.md` records S01/W01 baseline, branch, PR URL, and checked state on the
  implementation branch.
- W02 does not start until this PR merges; deployment is confirmed before bridge
  release.
