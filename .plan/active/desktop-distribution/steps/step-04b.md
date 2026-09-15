# Step 4.b — Nonblocking Desktop Attention Startup

Status: **in progress — scoped architecture-plan review approved**.
Implementation base: `cd4c1412359ef8962cb019d97dc7fed73835e1c8` (step 4.a squash).
PR ordinal **6/14**, after [step 4.a](step-04.md), before macOS updates.

## Observed failure and scope

Fresh signed x64 and arm64 CI installs have live native windows but black content.
Run `35019880379`, payload `d5a03026dbfe7a95af0a262225c9f3ff640c74d1`, reaches
`Desktop startup: starting desktop attention` and never reaches the subsequent
analytics/rendering stages during the observation. Independent signed storage,
registration and file probes pass. No local app/bridge may be disturbed.

`client/desktop/lib/main.dart` awaits `DesktopAttentionService.start()` before
`runApp`. The service correctly installs its event/auth/window/open listeners, but
then waits for `LocalNotificationClient.initialize()` and initial native launch
metadata. On macOS that initialization includes a native authorization request;
there is no bounded-completion guarantee. The exact host/native cause of the
observed wait remains unproven. Regardless, native notification readiness must not
be a prerequisite for rendering the app.

## Proposed change and ownership

- Keep `DesktopAttentionService` as the sole Layer-3 owner. `start()` still awaits
  local preference/session snapshots and installs all existing subscriptions before
  returning, preserving observation before AuthGate restoration or helper startup.
- Start the existing native-initialization/initial-open sequence asynchronously from
  that owner. Reuse `_notificationInitialization`, `_notificationsAvailable`, the
  existing pending-request state and account guards; notification delivery already
  awaits the shared readiness future. Do not add another initialization owner.
- Preserve useful original error/stack logging. Consume native launch metadata even
  if initialization failed, as today. If completion arrives after service disposal,
  do not open a window or route; the existing `_disposed` field suffices. Do not
  make disposal wait indefinitely for a native permission decision.
- Do not change permission policy, native entitlements, account storage, relay/wire
  contracts, plugin behavior, the bridge supervisor or user-facing notification copy.
  No new classes, mutable fields, queues, registries, timers, DI or generated code.
- Cleanup is the removal of notification readiness from the shell's rendering
  prerequisite, not a refactor of the pre-existing attention service/state machines.
  Existing account/open fences remain authoritative; do not add speculative epochs.

Scoped architecture-plan review **approved**, pre-review gate **PASS**, run
`af8e6b65-ad28-4dd4-8caf-e40d116c00c9` (`medium-intelligence-fast`). Applied B-Client
(desktop shell and desktop core); B-Bridge/B-Shared were outside scope. No findings.
Output: `reviews/desktop-distribution-step-04b-plan.md` in that run's artifacts.

## Verification and budget

Target **under 250 authored changed lines**, zero generated. Moderate implementation
complexity; lifecycle/startup risk warrants focused review and native execution.

1. Add a red/green test proving `start()` returns with a deliberately held native
   initializer after listeners are installed. Release it and verify normal delivery
   and initial-open handling still work; do not create broad timing machinery.
2. Cover delayed native completion after disposal and preserve existing native-
   failure/auth-scoped initial-open tests. Run the owning attention suite/analyzer.
3. Repeat native signed packaged GUI checks on both CPUs; inspect actual screenshots
   for rendered login, not merely a live window. Reuse credential-free replay for
   capture-only retries. If a different earlier await remains blocked, keep its
   evidence explicit and fix only a demonstrated cause.
4. Obtain scoped architecture implementation review, update the attention/packaging
   regression documents and record the exact native source/artifact result.

No new analytics event is justified: startup diagnostic progress is not a product
metric. Human OAuth/MFA, real account restoration, interactive TCC, minimum-OS and
public ship gates remain part of the final verification handoff, not fabricated passes.
