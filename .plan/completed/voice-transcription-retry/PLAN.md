# Retained Async Voice Transcription Retry

## Status

- **Plan slug:** `voice-transcription-retry`
- **Status:** Completed — Steps 1–4 merged and the accepted Step 5 async simulator/provider matrix passed
- **Plan date:** 2026-08-27
- **Primary repository:** `sesori-ai/sesori_apps_monorepo`
- **Server repository:** `sesori-ai/sesori_auth_server`
- **Implementation base:** apps async retry Step 4 merged as `1a6007228f`; auth Step 2 merged as `459d2663c8`
- **Current branch:** `plan/voice-transcription-retry/s05-verify-and-retire`
- **Delivery:** one plan PR, one additive auth-contract PR, one client ownership/layering PR, one async-retry-plus-regression-doc PR, and one verification/retirement PR

This plan and `TRACKER.md` are the implementation authority. Current code and released behavior remain authoritative if either document becomes stale.

## Goal

A transient upload or async transcription-service failure must not destroy a completed file-based voice recording. The composer keeps the existing local audio artifact and offers an explicit **Retry** action until one of these terminal decisions occurs:

1. transcription succeeds and the text is inserted for review;
2. the server authoritatively says retrying the same audio cannot help;
3. the user explicitly discards or replaces the recording; or
4. the owning composer is disposed.

A provider/model rejection, unusable audio, authentication failure, quota rejection, or other non-retryable response must not show Retry. It explains that transcription failed and lets the user record again or type instead. Retrying is always manual; this work adds no automatic resend loop.

## Product Scope: Async Only

This plan covers the file-based async transcription flow shipped on apps `main`. A completed compressed recording may
remain composer-owned for manual Retry after a transient local or server-authoritative failure. Streaming capture,
parallel recording, replay spools, automatic resend, server-side audio storage, and larger upload routes are outside
this plan.

## Current Behavior And Evidence

### Apps baseline before Steps 3–4

- `client/app/lib/capabilities/voice/voice_transcription_service.dart` records to a temporary file, calls `VoiceApi.transcribe`, and unconditionally deletes the file in `stopAndTranscribe`'s `finally` block.
- That class is a DI lazy singleton even though `PromptInput` is the user-visible owner of a recording interaction. `PromptInput.dispose` can request cancellation but does not dispose the application-owned service.
- The app-layer service calls the Layer-1 `VoiceApi` directly and owns transport-error policy. There is no Layer-2 voice repository.
- `client/app/lib/features/session_detail/widgets/prompt_input.dart` returns to `_VoiceIdle` after every failure. Network errors show a popup, but no state or action can reuse the recording.
- `client/module_core/lib/src/capabilities/voice/voice_api.dart` returns generic `ApiResponse<String>`. A non-2xx response retains status and raw JSON only inside `NonSuccessCodeError`; voice code does not parse the server's existing `retryable` field.
- The popup design system supports actions, but a popup can time out or be dismissed. It is not a durable owner for audio. The retry choice belongs in the composer interaction itself.

### Auth baseline before Step 2

- `POST /voice/transcribe` already maps provider-neutral `TranscriptionFailureReason` values.
- Soniox transient errors carry additive `retryable: true`; provider configuration rejection carries `retryable: false`; explicit invalid audio currently returns `400 bad_request` without the flag.
- The OpenAI compatibility path intentionally returns `500 internal_server_error` for every provider failure so released apps keep their historical status/error contract. `OpenAIClient` currently collapses all non-cancellation failures to `Internal`, which loses the information needed for an authoritative retryability boolean.
- Existing apps ignore unknown JSON members. Adding `retryable` while preserving endpoint, authentication, status, and existing `error` values is backward compatible.

### Regression documentation

`docs/regression/voice-input.md` already lists transcription failure/retry at L4, but its baseline required behavior said every exit path deletes the file and no owner retains residual audio. Step 4 updated the async contract in the same PR that changed production behavior, so no merged state left this source of truth stale.

## Locked Architecture

### 1. Auth owns retryability for async HTTP responses

The app may classify failures it observes locally, such as timeout, socket, TLS, and HTTP-client failures. It must not infer provider/model retryability from status-code ranges or error strings.

The auth response remains the existing error JSON with one authoritative additive member:

```json
{
  "error": "existing_error_value",
  "retryable": true
}
```

or:

```json
{
  "error": "existing_error_value",
  "retryable": false
}
```

#### Provider-neutral classification

`AsyncTranscriptionClient` remains provider-neutral. `OpenAIClient` and `SonioxTranscriptionClient` classify external outcomes into detailed `TranscriptionFailureReason` values; neither adapter chooses HTTP status, public `error`, or client retry policy.

Add `UnusableAudio` to the closed internal reason set for a structurally valid provider result with no usable speech/text. Add `QuotaExhausted` for provider billing/credit exhaustion that cannot recover by resubmitting identical audio. Keep `Capacity` for transient rate/concurrency pressure and `MalformedOutput` for invalid/untrusted provider structure.

`TranscriptionFailure` continues carrying the reason, original local `cause`, and optional provider cooldown only. It gains no HTTP fields or provider name.

#### Composition-owned public compatibility policy

Add an immutable `AsyncTranscriptionPublicErrorPolicy` selected in `src/index.ts` beside `ASYNC_TRANSCRIPTION_PROVIDER` and injected into `VoiceService`:

- `legacyOpenAiV1` preserves OpenAI's released all-provider-failures `500 internal_server_error` contract;
- `detailedV1` preserves the existing Soniox detailed status/error contract.

`VoiceService` derives `retryable` from the detailed reason, then applies the injected policy to status and existing `error`. It contains no `isOpenAi` branch. Provider adapters contain no HTTP semantics.

The public mapping is fixed:

| `TranscriptionFailureReason` | Retryable | `detailedV1` status/error | `legacyOpenAiV1` status/error |
|---|---:|---|---|
| `InvalidInput` | false | `400 bad_request` | `500 internal_server_error` |
| `UnusableAudio` | false | preserve `502 transcription_provider_error` | `500 internal_server_error` |
| `QuotaExhausted` | false | preserve `503 transcription_unavailable` | `500 internal_server_error` |
| `Capacity` | true | `503 transcription_unavailable` | `500 internal_server_error` |
| `Unavailable` | true | `503 transcription_unavailable` | `500 internal_server_error` |
| `Timeout` | true | `504 transcription_timeout` | `500 internal_server_error` |
| `ProviderRejected` | false | `500 transcription_configuration_error` | `500 internal_server_error` |
| `MalformedOutput` | true | `502 transcription_provider_error` | `500 internal_server_error` |
| `Internal` | false | `500 internal_server_error` | `500 internal_server_error` |
| `Cancelled`, caller still connected | false | `400 bad_request` | `400 bad_request` |
| Unexpected non-`TranscriptionFailure` | false | `500 internal_server_error` | `500 internal_server_error` |

The existing `ApiError` subclasses in `src/lib/errors.ts` remain the sole public HTTP errors. Extend or add typed transcription errors so every provider-derived response carries the fixed boolean while preserving the table's status and `error`. The existing Sesori daily-quota precheck remains `429 quota_exceeded` with its `service` member and gains `retryable: false` on this voice endpoint. `Retry-After` remains only on retryable detailed errors; quota exhaustion emits no cooldown, and the OpenAI legacy policy adds only the boolean while preserving its existing status/error/header behavior.

OpenAI classification recognizes caller cancellation first, then known SDK timeout/connection, provider error code/type for insufficient quota or a billing hard limit, generic 429 capacity, 5xx availability, 400/413/415/422 invalid input, 401/403/404 configuration, empty successful text, malformed output, and unknown internal failures. Soniox likewise recognizes documented quota-exhaustion metadata/402 before generic rate-limit 429. Raw provider values never cross either adapter.

### 2. Client separates the platform capability from the HTTP dependency chain

The two inputs meet only in the service layer:

```text
FlutterVoiceCapture → VoiceCapture platform capability ─────────┐
VoiceApi → VoiceRepository ──────────────────────────────────────┴→ VoiceTranscriptionService
VoiceTranscriptionService → VoiceTranscriptionSession → VoiceInputCubit → PromptInput
```

The async HTTP path follows API → Repository → Service without skipping a layer. Recording is a platform capability, not an endpoint or data repository; the client platform-abstraction rule explicitly allows module_core consumers to depend on that interface. Do not add misleading `VoiceCaptureApi`/`VoiceCaptureRepository` pass-through classes solely to rename the platform seam.

#### Platform capability

Add a pure-Dart `VoiceCapture` contract under `client/module_core/lib/src/platform/`. It returns typed artifacts, events, and one uniquely owned `VoiceCaptureSession` without exposing `record`, Flutter, wake-lock plugins, or raw maps.

The concrete app implementation lives under `client/app/lib/core/platform/` and owns only platform mechanics:

- `AudioRecorder` permission/start/stop/cancel/dispose;
- recording path creation and best-effort deletion;
- recording format/MIME facts;
- amplitude and native prewarm; and
- wake-lock acquisition/release.

It does not call auth APIs, parse server failures, choose retryability, or own composer policy.

The platform capability itself is stateless. Each opened `VoiceCaptureSession` owns a distinct `AudioRecorder` and native lifecycle, so composers never share disposable recording state. The concrete adapter may create that per-session native object directly; no DI factory or second production abstraction is added.

#### Layer 1 API

`VoiceApi` remains a dumb authenticated HTTP boundary. It parses successful transcript JSON and bounded non-success metadata into typed API DTOs. The failure metadata model has nullable `retryable` solely for older-server omission and is generated from source; no raw response map reaches higher layers.

#### Layer 2 repository

Add `VoiceRepository` under `client/module_core/lib/src/repositories/`. It depends on `VoiceApi` and maps API/transport DTOs into provider-neutral domain outcomes:

- transcript success;
- local transport failure;
- authoritative retryable server failure;
- terminal server rejection; and
- unauthenticated failure.

For a non-success HTTP body with omitted, malformed, or unknown retryability, the repository returns terminal rejection. This is the explicit old-server compatibility branch and carries the required dated app-version comment using the implementation date and then-current `client/app/pubspec.yaml` version (currently `1.8.2`).

#### Layer 3 service and per-composer session

Move recording/transcription orchestration to `client/module_core/lib/src/services/voice_transcription_service.dart`. `VoiceTranscriptionService` depends only on `VoiceRepository` and `VoiceCapture`. It never imports Flutter or app-shell code and never calls `VoiceApi` directly.

Register the service with the module_core-required `@lazySingleton` lifetime. It holds no composer-specific mutable state, but it owns all voice business operations and transition policy: prewarm, start, stop-and-transcribe, retry, cancel, discard, invalidate, and cleanup. Each operation receives an unregistered, uniquely owned `VoiceTranscriptionSession` created for one composer. The session is only the mutable state carrier: generation fence, private sealed lifecycle, one `VoiceCaptureSession`, and at most one opaque recording artifact. It holds no injected dependencies and performs no orchestration. The service can therefore operate on concurrent composer sessions without a registry or shared mutable lifecycle.

#### Layer 4 Cubit and composer ownership

Add `VoiceInputCubit` and a sealed `VoiceInputState` under `client/module_core/lib/src/cubits/voice_input/`. The Cubit is not registered in DI. The app's session-detail owner constructs it in `BlocProvider(create:)` with the lazy-singleton service, and the Cubit creates/owns exactly one `VoiceTranscriptionSession` for that provider lifetime.

The Cubit receives start, stop, retry, cancel, and discard intents; invokes the substantive service operations with its session; maps returned lifecycle/outcomes to renderable state; and keeps artifact/business policy out of Flutter. Its `close()` first asks the service to invalidate the session synchronously before any asynchronous gap, then awaits best-effort service cleanup for that session. Cleanup cancels native/upload work, releases wake lock, discards any retained artifact, closes streams, and logs contained failures.

`PromptInput` owns only Flutter presentation/controller concerns. It renders `context.watch<VoiceInputCubit>().state`, dispatches intents through `context.read<VoiceInputCubit>()`, and uses a listener for one-shot transcript/error effects. It neither resolves a service nor owns the voice business lifecycle. A late upload or platform callback checks the session generation and Cubit closure before any transition, so it cannot recreate retry-pending state after the provider is gone.

### 3. Async retained-file lifecycle

Public operations remain narrow:

- prewarm;
- start recording;
- stop and perform the first transcription attempt;
- retry the retained async artifact without invoking the recorder again;
- cancel active work;
- explicitly discard a retained artifact; and
- invalidate/close the composer-owned Cubit and service session.

The exact disposition matrix is:

| Async outcome | Artifact | Session/Cubit state | UI |
|---|---|---|---|
| Transcript success | Delete best-effort | Idle | Insert text once for review |
| Local transport failure | Retain | Retry pending | Saved-recording Retry + discard |
| Server `retryable: true` | Retain | Retry pending | Saved-recording Retry + discard |
| Server `retryable: false` | Delete best-effort | Idle | Explain re-record/type; no Retry |
| Server omits/malforms retryability | Delete best-effort | Idle | Terminal compatibility copy; no Retry |
| Authentication/quota rejection | Delete best-effort | Idle | Existing/specific terminal copy; no Retry |
| User cancels recording or the initial attempt | Delete best-effort | Idle | No transcript |
| User cancels an in-flight manual retry | Retain | Retry pending | Saved-recording Retry + discard |
| User discards pending recording | Delete best-effort | Idle | Normal composer |
| Retry finds artifact missing/unreadable | Clear ownership | Idle | Recording unavailable; re-record/type |
| Composer Cubit/session close | Delete best-effort | Disposed | No retained cross-route recording |

Each upload attempt releases busy/native wake-lock ownership when it settles. Retry reuses the exact artifact and MIME type, re-enters transcribing, and remains cancellable through the generation fence. Cancelling that retry aborts/fences only the current request and restores retry-pending with the same artifact; only the separate discard action abandons it. Repeated retryable failures keep the artifact; success or any terminal outcome clears it.

Deletion failure remains observable and best-effort: log the path/error locally, clear the in-memory owner, and retain the documented possibility of temporary-file residue. Do not add a deletion retry queue or directory sweep.

### 4. Retry is a persistent composer state

Replace `PromptInput`'s private `_VoiceInteraction` business state with the module_core sealed `VoiceInputState`, including a retry-pending variant. It blocks a second recording from silently replacing the retained artifact and survives ordinary widget rebuilds through the owning `BlocProvider`.

The voice-aware composer slot shows:

- localized saved-recording/error context;
- a clearly labelled **Retry** action; and
- the existing leading X affordance relabelled for discarding the saved recording.

Retry transitions back to the existing transcribing presentation. Success follows the existing path: append one voice-origin span, report one `voice_transcription_completed` outcome, preserve text-first/voice-first focus behavior, and never auto-send.

A terminal server rejection returns to the normal composer and shows localized copy equivalent to: “We couldn't transcribe this recording. Record it again or type your message.” It has no Retry action.

Typing remains available while an async recording is retry-pending. An explicit send that abandons the saved recording discards it before submission; starting another recording requires the visible discard action first. Route/composer disposal also discards it. Cross-route and process-restart recovery are intentionally out of scope.

### 5. No automatic or exactly-once retry claim

The user decides when to retry. A response can be lost after the server/provider completed transcription and recorded quota usage. Retrying can repeat provider work and quota debit.

This plan accepts that bounded ambiguity rather than adding an idempotency key, transcript cache, persisted audio, server retry registry, or reconciliation protocol. The UI promises that async audio is locally available for manual retry, not that provider processing is exactly once.

## Compatibility And Rollout

### New server with released apps

- Same endpoint, authentication, multipart shape, statuses, and existing `error` values.
- `retryable` is additive and ignored by released apps.
- No database, migration, backfill, or server-side audio persistence is introduced.

### New app with older server

- Local timeout/socket/TLS/client failures retain async audio and offer Retry.
- Any HTTP error lacking a valid boolean is terminal. The app neither crashes nor guesses.
- Success JSON is unchanged.

### Deployment order

Deploy the server contract first, then the client ownership and retry PRs. Mixed-version pairs remain safe throughout rollout and rollback.

### Client/bridge protocol

No bridge route, relay message, plugin interface, shared crypto contract, or database schema participates. The bridge and coding backend plugins are outside the matrix.

## Privacy And Analytics

- Async audio remains in the app's temporary directory only for the owning composer's retry window and is uploaded only to the existing authenticated auth endpoint.
- No audio, transcript, prompt, path, provider detail, or raw error is added to analytics or remote logs.
- Existing local diagnostic logging keeps original errors/stack traces where useful and never logs audio/transcript bytes.
- Add no analytics event. A retry tap is a UI proxy without a defined product decision, while `voice_transcription_completed` already reports the authoritative successful outcome. It fires once after eventual success and not on failed attempts.

## Complexity Budget

### New or changed mutable parts

1. **Composer-scoped session:** one service-created session replaces singleton booleans/path coordination and owns one artifact.
2. **Voice Cubit state:** one factory-constructed Cubit exposes the sealed lifecycle, including retry pending, to the composer; no registry or timer.
3. **Retained async artifact:** the already-created compressed file lives longer only after an explicitly retryable failure.

### Deliberately not added

- no streaming capture, parallel recorder, compressed spool, or replay;
- no persistent audio metadata or restart recovery;
- no queue, automatic retry/backoff, timer, network listener, or connectivity subscription;
- no request ID, idempotency database, transcript cache, or server-side audio retention;
- no app-wide pending-recording owner or cross-route restoration;
- no provider-specific client branch; and
- no bridge/plugin/database change.

The architecture move is causally required by the new lifecycle: retry policy and state cannot remain in a disposable Flutter shell service that calls an API directly. Step 3 isolates that migration from behavior change so Step 4 can stay focused and reviewable.

## Cleanup Assessment

- Replace the app-shell `VoiceTranscriptionService` and private `_VoiceInteraction` with the lazy-singleton core service, per-composer session/Cubit, and concrete platform adapter; do not keep an internal compatibility wrapper after all consumers move.
- Add the missing HTTP repository and remove direct service-to-API mapping. Do not add pass-through API/repository types around the platform capability.
- Replace unconditional async cleanup and generic network-error behavior that make retry impossible.
- Remove obsolete voice error variants/mappers only when the repository outcomes make them unused; internal Dart contracts update in lockstep.
- Update stale localization that tells users only to check the connection without saying the recording is saved.
- Keep recorder prewarm, amplitude, wake lock, max duration, generation fencing, draft voice spans, completion analytics, and best-effort deletion logging.

No database field, route, transport field, cache, setting, or job becomes obsolete.

## Fixed PR Series

| Step | Repository | Exact PR title | Changed-line target | Outcome |
|---|---|---|---:|---|
| 1/5 | apps | `🌱 [voice-transcription-retry] Plan async voice transcription retries [step 1/5]` | 500-700 | Publish this reviewed/corrected plan and tracker only |
| 2/5 | auth | `⚙️ [voice-transcription-retry] Mark async transcription failures retryable [step 2/5]` | 500-950 | Add authoritative booleans, quota classification, and explicit public compatibility policy |
| 3/5 | apps | `🚧 [voice-transcription-retry] Move voice lifecycle into client core [step 3/5]` | 2,800-4,200 | Add platform/session boundary, HTTP API/repository layering, lazy service, VoiceInputCubit, DI/codegen, and behavior-preserving tests |
| 4/5 | apps | `⚙️ [voice-transcription-retry] Retain and retry async voice recordings [step 4/5]` | 1,400-2,200 | Merged through PR #1172 as exact checkpoint `1a6007228f` |
| 5/5 | apps | `🌿 [voice-transcription-retry] Verify async voice retries and retire plan [step 5/5]` | 100-260 | Async simulator/provider matrix passed, `VERIFICATION.md` is published, and the plan is retired |

Other implementation PRs retain the 1,500-line soft cap. On 2026-08-27, the code-informed Step 3 candidate measured roughly 3,300 touched lines including about 977 deletions of the legacy service and its tests. The user explicitly approved keeping that ownership migration in one cohesive PR; splitting it would require a temporary duplicate lifecycle or compatibility wrapper that the architecture intentionally removes. The final Step 3 budget is 2,800–4,200 lines, including the architecture review's session-safe wake-lock lease plus PR-review fixes for typed native causes, stop/cancel/disposal serialization, in-flight stop cancellation, post-start rollback, composer-scoped ownership on both conditional composer surfaces, coordinated native prewarm, and collision-resistant concurrent recording paths.

Step 4 is a cohesive 1,400–2,200-line exception to the normal implementation soft cap because its typed DTO/state and localization generators contribute committed output, while retained lifecycle, reachable Retry/Discard ownership, focused coverage, and the regression contract must land together. Splitting would temporarily retain audio without a complete user decision path or publish UI against an unauthoritative failure contract.

Step 5's documentation-only 100–260-line budget includes the verification artifact, plan move, and removal of superseded cross-plan material so the completed source stays aligned with async behavior merged on `main`.

## Step 1/5 — Publish The Plan

### Scope

- Add `PLAN.md` and `TRACKER.md` under `.plan/active/voice-transcription-retry/`.
- Record current app/server behavior, exact failure matrix, async-only scope, architecture ownership, compatibility fallback, complexity budget, cleanup assessment, and L4 retirement boundary.
- Record the architecture plan-review rejection and corrections honestly; do not claim the corrected draft was approved because repository rules prohibit routine re-review of applied findings.

### Verification

- `git diff --check`
- plan/tracker slug, five-step denominator, exact titles, repositories, and line targets agree
- only plan files appear in the diff

## Step 2/5 — Add The Authoritative Server Signal

### Scope

- Update `AsyncTranscriptionClient`, provider adapters, `TranscriptionFailure`, `VoiceService`, composition, and typed public errors according to the fixed two-policy table.
- Preserve OpenAI's released HTTP-500/`internal_server_error` behavior while recovering detailed provider-neutral classification.
- Preserve Soniox statuses/error values while distinguishing terminal provider quota/unusable audio from transient capacity and availability.
- Add `retryable: false` to the voice daily-quota response without changing its `429 quota_exceeded`/`service` contract.
- Keep cancellation, request validation, provider cleanup, privacy, and existing Retry-After semantics intact.
- Update auth README/tests with the authoritative async retryability contract and compatibility policy.

### Verification

- Focused OpenAI/Soniox adapter tests cover every reason, including quota-exhaustion metadata before generic 429 capacity.
- `VoiceService` and `POST /voice/transcribe` tests assert exact `{status, error, retryable}` under both policies, daily quota, unexpected failures, and connected cancellation.
- Compatibility fixtures prove existing status/error values are unchanged and the new field is additive.
- Auth TypeScript check, lint/format check, focused Node tests, architecture implementation review, and `git diff --check`.

## Step 3/5 — Correct Client Ownership Without Changing Behavior

### Scope

- Add the pure-Dart `VoiceCapture`/`VoiceCaptureSession` platform capability and concrete app adapter with one native recorder per session.
- Keep HTTP `VoiceApi` Layer 1; add `VoiceRepository` Layer 2; add lazy-singleton `VoiceTranscriptionService` Layer 3.
- Add an unregistered per-composer `VoiceTranscriptionSession` state carrier plus factory-constructed module_core `VoiceInputCubit`/sealed state.
- Keep all permission/capture/transcription/cancel/max-duration/amplitude/wake-lock orchestration and transition policy in the lazy service, parameterized by the owned session, without adding retry-pending behavior yet.
- Wire the Cubit in the app owner; make `PromptInput` render state/dispatch intents only; synchronously fence session completion at Cubit close before asynchronous cleanup.
- Remove the app-shell singleton service/private voice business state and update all consumers/tests/DI in lockstep.

### Verification

- HTTP repository mapping tests, pure-Dart service/session/Cubit lifecycle tests with fake platform/API boundaries, concrete app platform-adapter tests, and existing composer widget tests.
- Prove each Cubit gets one distinct state session/native recorder, two composers do not share state, close fences late completion, and behavior remains permission → record → transcribe → cleanup.
- Prove the stateless `@lazySingleton` service—not the session or Cubit—owns every business operation/transition, the Cubit is created only by `BlocProvider`, and no product shell calls service/API directly.
- Run code generation only through build runner.
- Strict analysis in module_core/app, focused/downstream mobile tests, architecture implementation review, and `git diff --check`.

## Step 4/5 — Retain And Retry Async Recordings

### Scope

- Add generated typed failure metadata and repository handling for true/false/omitted/malformed retryability.
- Add retry-pending to the sealed service-session/Cubit lifecycle and implement exact artifact disposition.
- Add retry-pending composer presentation plus localized Retry, discard, saved-recording, terminal-rejection, and missing-artifact copy.
- Preserve editable draft, voice-span attribution, focus behavior, cancellation, max duration, and one completion analytics outcome.
- Update `docs/regression/voice-input.md` in this same PR with authoritative async outcomes, artifact deletion points, Retry/discard, old-server fallback, duplicate-work risk, scope limits, L2/L4 coverage, and failure signals.
- Do not add streaming capture or recording-replay behavior.

### Verification

- `VoiceApi`/`VoiceRepository`: true, false, omitted, malformed, auth/quota, local transport, success, and privacy-safe mapping.
- Service session/Cubit: retain on network/true, reuse exact artifact on retry, cancel manual retry back to retry-pending, repeated failure, success/false/initial-cancel/discard/close cleanup, missing artifact, deletion failure logging, stale completion fencing, wake lock, and one-artifact invariant.
- App widgets: voice-first/text-first Retry/discard rendering, no Retry for terminal rejection, retry success inserts once, second recording blocked until discard, typed draft preserved, cancel/close, and stale isolation.
- Regression text matches the behavior in the same diff and removes the stale every-exit-deletes claim.
- Codegen/localization generation, strict analysis, focused/downstream tests, architecture implementation review, and `git diff --check`.

## Step 5/5 — Verify And Retire

### Highest required level

**L4 Extended.** The delivered claim is recovery from adverse network/server state through a real mobile composer and hosted async auth boundary. Automated artifact/API tests alone do not prove that a user can retain and retry a real recording.

### Required matrix

The user explicitly substituted the owned iOS simulator for the original physical-device row. Record that accepted
reduction without claiming physical microphone, audio-session, haptics, or hardware wake coverage.

- **Client:** owned iOS simulator, voice-first and text-first layouts.
- **Auth:** current server contract plus an older-server fixture with omitted `retryable`.
- **Providers:** automated classification for every configured async provider adapter; one live configured production provider through staging/external verification.
- **Failures:** offline/connection loss, explicit retryable async server failure, explicit unusable-audio/non-retryable response, authentication/quota rejection, cancel during retry back to retry-pending, and deletion/disposal cleanup.
- **Mode:** file-based async capture and upload only.
- **Plugins/bridge:** none.

### Acceptance

1. Record once in async mode, fail transiently, restore connectivity, tap Retry, and receive editable transcript text without re-recording.
2. A server-declared non-retryable audio failure shows no Retry and directs re-recording or typing.
3. A current app against omitted metadata never guesses retryability; a current server remains compatible with released-app fixtures.
4. Success, terminal failure, initial cancellation, explicit discard, and disposal attempt deletion; retryable failure and cancellation of a manual retry retain the artifact.
5. No audio/transcript content reaches logs or analytics, and completion analytics fires once after eventual async success.

Record Pass/Partial/Fail/Blocked with mode, platform, auth build, provider scope, and privacy-safe evidence. Any required row that is partial, blocked, failed, or unexecuted keeps the plan active unless the user explicitly accepts a reduced matrix in this plan. Move `.plan/active/voice-transcription-retry/` to `.plan/completed/voice-transcription-retry/` only after acceptance.

## Risks And Accepted Limits

- A lost async response followed by manual retry can repeat provider work and quota usage; no exactly-once claim is made.
- The retained artifact is memory-owned and composer-local. Process death, route exit, OS temporary-file eviction, or explicit discard loses retry capability.
- Best-effort deletion can leave local residue if the filesystem refuses removal; no background sweeper is added.
- An older server cannot distinguish provider failures. New clients treat its HTTP failures as terminal rather than risking a false Retry.

## Expected Result

After an async connection or server-declared transient failure, the composer visibly keeps the completed compressed recording and lets the user resend that exact artifact. A server/model rejection that cannot benefit from resubmission deletes it, offers no Retry, and directs the user to re-record or type. Existing apps and servers continue to interoperate, the HTTP path follows API → Repository → Service → Cubit → Composer while recording stays behind its platform capability, and no bridge/plugin/database contract changes.
