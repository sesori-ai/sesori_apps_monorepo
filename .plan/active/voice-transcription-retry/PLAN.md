# Retained Async Voice Transcription Retry

## Status

- **Plan slug:** `voice-transcription-retry`
- **Status:** Active — Step 1/6 plan correction and publication
- **Plan date:** 2026-08-27
- **Primary repository:** `sesori-ai/sesori_apps_monorepo`
- **Server repository:** `sesori-ai/sesori_auth_server`
- **Implementation base:** apps `origin/main` at `10e9c8c4bb`; auth `origin/master` at `93b4323dca`
- **Current branch:** `voice-retry-behavior`
- **Delivery:** one plan PR, one additive auth-contract PR, one client ownership/layering PR, one async-retry PR, one regression-doc PR, and one verification/retirement PR
- **External merge barrier:** apps realtime voice PR [#918](https://github.com/sesori-ai/sesori_apps_monorepo/pull/918), head `b3083b7ad3`, must rebase onto the merged async-retry implementation before it may merge

This plan and `TRACKER.md` are the implementation authority. Current code and released behavior remain authoritative if either document becomes stale.

## Goal

A transient upload or async transcription-service failure must not destroy a completed file-based voice recording. The composer keeps the existing local audio artifact and offers an explicit **Retry** action until one of these terminal decisions occurs:

1. transcription succeeds and the text is inserted for review;
2. the server authoritatively says retrying the same audio cannot help;
3. the user explicitly discards or replaces the recording; or
4. the owning composer is disposed.

A provider/model rejection, unusable audio, authentication failure, quota rejection, or other non-retryable response must not show Retry. It explains that transcription failed and lets the user record again or type instead. Retrying is always manual; this work adds no automatic resend loop.

## Product Scope Decision: Async Only

On 2026-08-27 the user explicitly accepted that full-recording retry does not need to extend to realtime mode if doing so increases complexity drastically. It does.

The pending realtime implementation streams raw PCM after `ready` and does not retain a compressed file. Supporting full replay after audio starts would require teeing every PCM frame to disk, producing an async-compatible compressed artifact on iOS and Android, handling disk/socket backpressure and cancellation, and proving the 15-minute limit. Raw WAV is insufficient: mono PCM16 is about 28.8 MB at 16 kHz and about 79.4 MB at 44.1 kHz for 15 minutes, while `POST /voice/transcribe` caps audio at 25 MB.

Therefore:

- this plan guarantees retry only for file-based async transcription, including the async fallback path retained by realtime PR #918;
- realtime failures before audio starts may continue falling back to async as #918 already plans;
- once realtime audio has been sent, its accepted behavior remains confirmed-partial-text recovery plus a typed error, without a full-recording Retry action; and
- no dual capture, native AAC/FLAC encoder, PCM spool/replay, second recorder, larger upload route, or new server storage is added.

The regression contract must state this mode distinction honestly.

## Current Behavior And Evidence

### Current apps `main`

- `client/app/lib/capabilities/voice/voice_transcription_service.dart` records to a temporary file, calls `VoiceApi.transcribe`, and unconditionally deletes the file in `stopAndTranscribe`'s `finally` block.
- That class is a DI lazy singleton even though `PromptInput` is the user-visible owner of a recording interaction. `PromptInput.dispose` can request cancellation but does not dispose the application-owned service.
- The app-layer service calls the Layer-1 `VoiceApi` directly and owns transport-error policy. There is no Layer-2 voice repository.
- `client/app/lib/features/session_detail/widgets/prompt_input.dart` returns to `_VoiceIdle` after every failure. Network errors show a popup, but no state or action can reuse the recording.
- `client/module_core/lib/src/capabilities/voice/voice_api.dart` returns generic `ApiResponse<String>`. A non-2xx response retains status and raw JSON only inside `NonSuccessCodeError`; voice code does not parse the server's existing `retryable` field.
- The popup design system supports actions, but a popup can time out or be dismissed. It is not a durable owner for audio. The retry choice belongs in the composer interaction itself.

### Auth server

- `POST /voice/transcribe` already maps provider-neutral `TranscriptionFailureReason` values.
- Soniox transient errors carry additive `retryable: true`; provider configuration rejection carries `retryable: false`; explicit invalid audio currently returns `400 bad_request` without the flag.
- The OpenAI compatibility path intentionally returns `500 internal_server_error` for every provider failure so released apps keep their historical status/error contract. `OpenAIClient` currently collapses all non-cancellation failures to `Internal`, which loses the information needed for an authoritative retryability boolean.
- Existing apps ignore unknown JSON members. Adding `retryable` while preserving endpoint, authentication, status, and existing `error` values is backward compatible.

### Active realtime overlap

Auth realtime `TRACKER.md` names S03 as active. Apps PR #918 is open at `b3083b7ad3` on branch `plan/real-time-transcription/s03-w01-p01-stream-mobile-voice`; its recorded CI is green, but GitHub currently reports it conflicting with `main`.

It changes the same `VoiceApi`, capture lifecycle, DI, `PromptInput`, tests, localization, and `docs/regression/voice-input.md`. It cannot remain a second authoritative implementation.

The merge order is locked:

1. this plan's client ownership and async-retry Steps 3–4 merge first;
2. PR #918 rebases onto that merged SHA and adapts its realtime/async orchestration to the new Foundation → API → Repository → Service ownership;
3. #918 preserves async retained-file retry and its tests while keeping post-audio realtime partial-text/no-full-retry semantics; and
4. only then may #918 merge.

Step 2 updates both the auth realtime `PLAN.md` and `TRACKER.md` with this decision and barrier. Updating prose without reconciling the open apps branch is insufficient; the branch rebase is a required checkpoint before this plan's documentation step.

### Regression documentation

`docs/regression/voice-input.md` already lists transcription failure/retry at L4, but its required behavior says every exit path deletes the file and no owner retains residual audio. The document must be reconciled after implementation rather than treated as evidence that retry exists today.

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

Add `UnusableAudio` to the closed internal reason set for a structurally valid provider result with no usable speech/text. Keep `MalformedOutput` for invalid/untrusted provider structure.

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
| `Capacity` | true | `503 transcription_unavailable` | `500 internal_server_error` |
| `Unavailable` | true | `503 transcription_unavailable` | `500 internal_server_error` |
| `Timeout` | true | `504 transcription_timeout` | `500 internal_server_error` |
| `ProviderRejected` | false | `500 transcription_configuration_error` | `500 internal_server_error` |
| `MalformedOutput` | true | `502 transcription_provider_error` | `500 internal_server_error` |
| `Internal` | false | `500 internal_server_error` | `500 internal_server_error` |
| `Cancelled`, caller still connected | false | `400 bad_request` | `400 bad_request` |
| Unexpected non-`TranscriptionFailure` | false | `500 internal_server_error` | `500 internal_server_error` |

The existing `ApiError` subclasses in `src/lib/errors.ts` remain the sole public HTTP errors. Extend or add typed transcription errors so every provider-derived response carries the fixed boolean while preserving the table's status and `error`. `Retry-After` remains only on retryable detailed errors; the OpenAI legacy policy adds only the boolean and preserves its existing status/error/header behavior.

OpenAI classification recognizes caller cancellation first, then known SDK timeout/connection, 429 capacity, 5xx availability, 400/413/415/422 invalid input, 401/403/404 configuration, empty successful text, malformed output, and unknown internal failures. Raw provider values never cross the adapter.

### 2. Client dependency flow is Foundation → API → Repository → Service → Composer

#### Foundation/platform

Add pure-Dart contracts under `client/module_core/lib/src/foundation/platform/` for the platform recording boundary. The boundary returns typed artifacts and events without exposing `record`, Flutter, wake-lock plugins, or raw maps.

The concrete app implementation lives under `client/app/lib/core/platform/` and owns only platform mechanics:

- `AudioRecorder` permission/start/stop/cancel/dispose;
- recording path creation and best-effort deletion;
- recording format/MIME facts;
- amplitude and native prewarm;
- wake-lock acquisition/release; and
- when PR #918 rebases, PCM stream/config callbacks and native realtime teardown.

It does not call auth APIs, parse server failures, choose retryability, or own composer policy.

The platform adapter and its `AudioRecorder` are factory-scoped so one composer service does not share disposable native state with another.

#### Layer 1 API

`VoiceApi` remains a dumb authenticated HTTP boundary. It parses successful transcript JSON and bounded non-success metadata into typed API DTOs. The failure metadata model has nullable `retryable` solely for older-server omission and is generated from source; no raw response map reaches higher layers.

#### Layer 2 repository

Add `VoiceRepository` under `client/module_core/lib/src/repositories/`. It depends on `VoiceApi` (and, after #918 rebases, `RealtimeVoiceApi`) and maps API/transport DTOs into provider-neutral domain outcomes:

- transcript success;
- local transport failure;
- authoritative retryable server failure;
- terminal server rejection; and
- unauthenticated failure.

For a non-success HTTP body with omitted, malformed, or unknown retryability, the repository returns terminal rejection. This is the explicit old-server compatibility branch and carries the required dated app-version comment using the implementation date and then-current `client/app/pubspec.yaml` version (currently `1.8.2`).

#### Layer 3 service

Move recording/transcription orchestration to `client/module_core/lib/src/services/voice_transcription_service.dart`. It depends only on `VoiceRepository` and the Foundation platform contract. It never imports Flutter or app-shell code and never calls `VoiceApi` directly.

One private sealed lifecycle represents idle, starting, recording, transcribing, retry-pending, cancelling, and disposed. Prewarm remains an independent best-effort operation. The lifecycle owns at most one opaque recording artifact.

The service is registered as a DI factory, not a singleton. `PromptInput` resolves exactly one instance for its State lifetime and never resolves the service through a getter on each call.

#### Composer ownership and disposal

`PromptInput` owns its service instance and UI interaction generation.

On widget disposal it:

1. synchronously calls a non-async service invalidation/fence so no later completion can publish transcript or retry-pending state;
2. starts best-effort asynchronous service disposal without awaiting from Flutter's synchronous `dispose`; and
3. relies on service disposal to cancel native/upload work, release wake lock, discard any retained artifact, close streams, and contain/log cleanup failures.

A late upload or platform callback checks the service generation/disposed state before any transition. It can never recreate retry-pending state after the composer is gone.

### 3. Async retained-file lifecycle

Public operations remain narrow:

- prewarm;
- start recording;
- stop and perform the first transcription attempt;
- retry the retained async artifact without invoking the recorder again;
- cancel active work;
- explicitly discard a retained artifact; and
- invalidate/dispose the composer-owned service.

The exact disposition matrix is:

| Async outcome | Artifact | Service state | UI |
|---|---|---|---|
| Transcript success | Delete best-effort | Idle | Insert text once for review |
| Local transport failure | Retain | Retry pending | Saved-recording Retry + discard |
| Server `retryable: true` | Retain | Retry pending | Saved-recording Retry + discard |
| Server `retryable: false` | Delete best-effort | Idle | Explain re-record/type; no Retry |
| Server omits/malforms retryability | Delete best-effort | Idle | Terminal compatibility copy; no Retry |
| Authentication/quota rejection | Delete best-effort | Idle | Existing/specific terminal copy; no Retry |
| User cancels an in-flight attempt | Delete best-effort | Idle | No transcript |
| User discards pending recording | Delete best-effort | Idle | Normal composer |
| Retry finds artifact missing/unreadable | Clear ownership | Idle | Recording unavailable; re-record/type |
| Composer service disposal | Delete best-effort | Disposed | No retained cross-route recording |

Each upload attempt releases busy/native wake-lock ownership when it settles. Retry reuses the exact artifact and MIME type, re-enters transcribing, and remains cancellable through the generation fence. Repeated retryable failures keep the artifact; success or any terminal outcome clears it.

Deletion failure remains observable and best-effort: log the path/error locally, clear the in-memory owner, and retain the documented possibility of temporary-file residue. Do not add a deletion retry queue or directory sweep.

### 4. Retry is a persistent composer state

Extend `PromptInput`'s existing sealed `_VoiceInteraction` with a retry-pending variant. It blocks a second recording from silently replacing the retained artifact and survives ordinary widget rebuilds.

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

### Realtime PR #918

PR #918 is an unpublished candidate, so it creates no compatibility obligation. It must rebase after Step 4 and update every in-repository consumer in lockstep rather than adding a shim.

Its accepted post-rebase behavior is:

- async mode/fallback uses the repository/service retained-file contract;
- pre-audio realtime failure may select async;
- post-audio realtime failure preserves confirmed partial text and shows its existing typed failure, without a full-recording Retry;
- realtime success/cancel/cleanup remains unchanged; and
- no provider-specific client logic is introduced.

### Client/bridge protocol

No bridge route, relay message, plugin interface, shared crypto contract, or database schema participates. The bridge and coding backend plugins are outside the matrix.

## Privacy And Analytics

- Async audio remains in the app's temporary directory only for the owning composer's retry window and is uploaded only to the existing authenticated auth endpoint.
- No audio, transcript, prompt, path, provider detail, or raw error is added to analytics or remote logs.
- Existing local diagnostic logging keeps original errors/stack traces where useful and never logs audio/transcript bytes.
- Add no analytics event. A retry tap is a UI proxy without a defined product decision, while `voice_transcription_completed` already reports the authoritative successful outcome. It fires once after eventual success and not on failed attempts.

## Complexity Budget

### New or changed mutable parts

1. **Composer-scoped service lifecycle:** one sealed lifecycle replaces singleton booleans/path coordination and owns one artifact.
2. **Retry-pending UI variant:** one variant in the existing sealed composer interaction; no Cubit, registry, or timer.
3. **Retained async artifact:** the already-created compressed file lives longer only after an explicitly retryable failure.

### Deliberately not added

- no realtime dual capture, compressed stream spool, replay, or fallback after audio starts;
- no persistent audio metadata or restart recovery;
- no queue, automatic retry/backoff, timer, network listener, or connectivity subscription;
- no request ID, idempotency database, transcript cache, or server-side audio retention;
- no app-wide pending-recording owner or cross-route restoration;
- no provider-specific client branch; and
- no bridge/plugin/database change.

The architecture move is causally required by the new lifecycle: retry policy and state cannot remain in a disposable Flutter shell service that calls an API directly. Step 3 isolates that migration from behavior change so Step 4 can stay focused and reviewable.

## Cleanup Assessment

- Replace the app-shell `VoiceTranscriptionService` with the core service plus concrete platform adapter; do not keep an internal compatibility wrapper after all consumers move.
- Add the missing repository and remove direct service-to-API mapping.
- Replace unconditional async cleanup and generic network-error behavior that make retry impossible.
- Remove obsolete voice error variants/mappers only when the repository outcomes make them unused; internal Dart contracts update in lockstep.
- Update stale localization that tells users only to check the connection without saying the recording is saved.
- Keep recorder prewarm, amplitude, wake lock, max duration, generation fencing, draft voice spans, completion analytics, and best-effort deletion logging.
- When #918 rebases, delete superseded app-service realtime orchestration rather than keeping two owners.

No database field, route, transport field, cache, setting, or job becomes obsolete.

## Fixed PR Series

| Step | Repository | Exact PR title | Changed-line target | Outcome |
|---|---|---|---:|---|
| 1/6 | apps | `🌱 [voice-transcription-retry] Plan async voice transcription retries [step 1/6]` | 500-700 | Publish this reviewed/corrected plan and tracker only |
| 2/6 | auth | `⚙️ [voice-transcription-retry] Mark async transcription failures retryable [step 2/6]` | 450-900 | Add authoritative booleans with explicit public compatibility policy; update realtime plan/tracker |
| 3/6 | apps | `🚧 [voice-transcription-retry] Move voice lifecycle into client core [step 3/6]` | 1,050-1,500 | Add platform contract, API/repository layering, composer-scoped core service, DI/codegen, and behavior-preserving tests |
| 4/6 | apps | `⚙️ [voice-transcription-retry] Retain and retry async voice recordings [step 4/6]` | 650-1,150 | Add retained-artifact lifecycle, Retry/discard UI, localization/codegen, and focused tests |
| 5/6 | apps | `🌱 [voice-transcription-retry] Document async voice retry behavior [step 5/6]` | 50-140 | Reconcile `docs/regression/voice-input.md` after #918 branch rebase checkpoint |
| 6/6 | apps | `🌿 [voice-transcription-retry] Verify async voice retries and retire plan [step 6/6]` | 60-180 | Run/record required L4 async matrix and retire only after it passes |

Every implementation PR targets at most the 1,500-line soft cap. If the post-implementation estimate for Step 3 exceeds that after code-informed decomposition, stop and ask before changing the fixed series; do not hide a second lifecycle behind a nominally smaller PR.

The existing PR #918 is an external merge-barrier action owned by the realtime plan, not a seventh PR in this series. Between Steps 4 and 5 it must rebase onto the merged Step 4 SHA, adopt the new repository/service/platform ownership, preserve async retry tests, update its own auth-hosted PLAN/TRACKER checkpoint, and return to mergeable CI-green state.

## Step 1/6 — Publish The Plan

### Scope

- Add `PLAN.md` and `TRACKER.md` under `.plan/active/voice-transcription-retry/`.
- Record current app/server behavior, exact failure matrix, async-only scope, architecture ownership, #918 barrier, compatibility fallback, complexity budget, cleanup assessment, and L4 retirement boundary.
- Record the architecture plan-review rejection and corrections honestly; do not claim the corrected draft was approved because repository rules prohibit routine re-review of applied findings.

### Verification

- `git diff --check`
- plan/tracker slug, six-step denominator, exact titles, repositories, and line targets agree
- only plan files appear in the diff

## Step 2/6 — Add The Authoritative Server Signal

### Scope

- Update `AsyncTranscriptionClient`, `OpenAIClient`, `TranscriptionFailure`, `VoiceService`, composition, and typed public errors according to the fixed two-policy table.
- Preserve OpenAI's released HTTP-500/`internal_server_error` behavior while recovering detailed provider-neutral classification.
- Preserve Soniox statuses/error values while adding false to invalid/unusable audio and retaining true on transient outcomes.
- Keep cancellation, quota, request validation, provider cleanup, privacy, and existing Retry-After semantics intact.
- Update auth README/tests plus realtime `PLAN.md` and `TRACKER.md` with the async-only product decision, #918 head/overlap, and merge barrier.

### Verification

- Focused OpenAI/Soniox adapter tests cover every reason.
- `VoiceService` and `POST /voice/transcribe` tests assert exact `{status, error, retryable}` under both policies, unexpected failures, and connected cancellation.
- Compatibility fixtures prove existing status/error values are unchanged and the new field is additive.
- Auth TypeScript check, lint/format check, focused Node tests, architecture implementation review, and `git diff --check`.

## Step 3/6 — Correct Client Ownership Without Changing Behavior

### Scope

- Add the pure-Dart platform capture contract and concrete app factory adapter.
- Keep `VoiceApi` Layer 1; add `VoiceRepository` Layer 2; add factory-scoped `VoiceTranscriptionService` Layer 3 in module_core.
- Move current permission/capture/transcription/cancel/max-duration/amplitude/wake-lock orchestration through those seams without adding retry-pending behavior yet.
- Make `PromptInput` own one service instance, synchronously invalidate it on dispose, and start contained async disposal.
- Remove the app-shell singleton service and update all consumers/tests/DI in lockstep.

### Verification

- Repository mapping tests, pure-Dart service lifecycle tests with fake platform/API boundaries, concrete app platform-adapter tests, and existing composer voice tests.
- Prove one composer gets one service/native recorder, disposal fences late completion, and behavior remains permission → record → transcribe → cleanup.
- Run code generation only through build runner.
- Strict analysis in module_core/app, focused/downstream mobile tests, architecture implementation review, and `git diff --check`.

## Step 4/6 — Retain And Retry Async Recordings

### Scope

- Add generated typed failure metadata and repository handling for true/false/omitted/malformed retryability.
- Add retry-pending to the sealed core service lifecycle and implement exact artifact disposition.
- Add retry-pending composer presentation plus localized Retry, discard, saved-recording, terminal-rejection, and missing-artifact copy.
- Preserve editable draft, voice-span attribution, focus behavior, cancellation, max duration, and one completion analytics outcome.
- Do not add realtime capture/retry behavior.

### Verification

- `VoiceApi`/`VoiceRepository`: true, false, omitted, malformed, auth, local transport, success, and privacy-safe mapping.
- Core service: retain on network/true, reuse exact artifact on retry, repeated failure, success/false/cancel/discard/dispose cleanup, missing artifact, deletion failure logging, stale completion fencing, wake lock, and one-artifact invariant.
- App widgets: voice-first/text-first Retry/discard rendering, no Retry for terminal rejection, retry success inserts once, second recording blocked until discard, typed draft preserved, cancel/dispose, and stale isolation.
- Codegen/localization generation, strict analysis, focused/downstream tests, architecture implementation review, and `git diff --check`.

## Realtime PR #918 Rebase Checkpoint

Before Step 5:

- Rebase #918 onto the exact merged Step 4 SHA and record that base/head in auth realtime `TRACKER.md`.
- Resolve its overlaps in `VoiceApi`, DI, platform capture, core service/repository, `PromptInput`, localization, tests, and voice regression docs.
- Preserve async retained retry and old-server fallback tests.
- Keep post-audio realtime confirmed-partial/no-full-retry behavior and prove it does not expose the async Retry control.
- Return #918 to mergeable, CI-green, reviewed state before it may merge.

If #918 is closed, superseded, or materially redesigned instead, update this plan and the realtime plan before Step 5; do not silently ignore the barrier.

## Step 5/6 — Reconcile Regression Documentation

### Scope

Update `docs/regression/voice-input.md` to state:

- authoritative retryable versus terminal async outcomes;
- retained temporary-artifact ownership and deletion points;
- manual Retry/discard behavior;
- old-server omission fallback;
- no automatic, cross-route, or restart retry;
- duplicate provider/quota possibility after response loss;
- realtime pre-audio fallback versus post-audio partial-text/no-full-retry behavior; and
- updated L2/L4 coverage and failure signals.

Complete the cleanup audit against Steps 2–4 and the rebased #918 branch. Remove stale claims instead of leaving tombstones.

### Verification

- `git diff --check`
- regression wording matches implemented async state/error names and accepted realtime distinction
- documentation-only diff; no Dart/Flutter suites

## Step 6/6 — Verify And Retire

### Highest required level

**L4 Extended.** The delivered claim is recovery from adverse network/server state through a real mobile composer and hosted async auth boundary. Automated artifact/API tests alone do not prove that a user can retain and retry a real recording.

### Required matrix

- **Client:** one release-target physical mobile platform, voice-first and text-first layouts.
- **Auth:** current server contract plus an older-server fixture with omitted `retryable`.
- **Providers:** automated classification for every configured async provider adapter; one live configured production provider through staging/external verification.
- **Failures:** offline/connection loss, explicit retryable async server failure, explicit unusable-audio/non-retryable response, authentication/quota rejection, cancel during retry, and deletion/disposal cleanup.
- **Mode:** force/confirm async capability for the retained-file journey. If realtime code has merged, separately confirm post-audio failure does not falsely display the async Retry action.
- **Plugins/bridge:** none.

### Acceptance

1. Record once in async mode, fail transiently, restore connectivity, tap Retry, and receive editable transcript text without re-recording.
2. A server-declared non-retryable audio failure shows no Retry and directs re-recording or typing.
3. A current app against omitted metadata never guesses retryability; a current server remains compatible with released-app fixtures.
4. Success, terminal failure, discard, cancellation, and disposal attempt deletion; retryable failure does not.
5. Realtime post-audio failure, when present in the tested build, preserves its documented partial-text behavior and never claims a retained full recording.
6. No audio/transcript content reaches logs or analytics, and completion analytics fires once after eventual async success.

Record Pass/Partial/Fail/Blocked with mode, platform, auth build, provider scope, and privacy-safe evidence. Any required row that is partial, blocked, failed, or unexecuted keeps the plan active unless the user explicitly accepts a reduced matrix in this plan. Move `.plan/active/voice-transcription-retry/` to `.plan/completed/voice-transcription-retry/` only after acceptance.

## Risks And Accepted Limits

- A lost async response followed by manual retry can repeat provider work and quota usage; no exactly-once claim is made.
- The retained artifact is memory-owned and composer-local. Process death, route exit, OS temporary-file eviction, or explicit discard loses retry capability.
- Best-effort deletion can leave local residue if the filesystem refuses removal; no background sweeper is added.
- An older server cannot distinguish provider failures. New clients treat its HTTP failures as terminal rather than risking a false Retry.
- Realtime audio sent after `ready` has no full-recording retry. Confirmed partial text is the accepted recovery, per the explicit user decision.
- PR #918 is already large and conflicting. Its rebase may expose changed file estimates; that work remains owned by the realtime plan and cannot bypass this plan's async contract.

## Expected Result

After an async connection or server-declared transient failure, the composer visibly keeps the completed compressed recording and lets the user resend that exact artifact. A server/model rejection that cannot benefit from resubmission deletes it, offers no Retry, and directs the user to re-record or type. Realtime remains intentionally simpler: pre-audio fallback is allowed, while post-audio failure keeps confirmed partial text without retaining the full recording. Existing apps and servers continue to interoperate, ownership follows Foundation → API → Repository → Service → Composer, and no bridge/plugin/database contract changes.
