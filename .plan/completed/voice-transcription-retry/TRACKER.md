# Retained Async Voice Transcription Retry: Tracker

## Current State

- **Plan slug:** `voice-transcription-retry`
- **Apps async retry checkpoint:** Step 4 merged as `1a6007228f`; Step 5 branch synced through apps `main` `cf9b33d275`
- **Auth Step 2:** PR [#77](https://github.com/sesori-ai/sesori_auth_server/pull/77) merged as `459d2663c8`
- **Current branch:** `plan/voice-transcription-retry/s05-verify-and-retire`
- **Series state:** Complete — Steps 1–4 merged, the user-approved Step 5 simulator/provider matrix passed, and the plan is retired
- **Current step:** 5/5 completed
- **Next action:** publish and monitor the documentation-only Step 5 retirement PR

## Locked Product Decisions

- [x] Retain the completed temporary artifact only after a local transport failure or server-declared retryable **async** failure.
- [x] Retry is manual and reuses the exact artifact/MIME without restarting the recorder.
- [x] A server/model rejection that cannot benefit from identical audio shows no Retry.
- [x] File-based async capture and upload are the only transcription mode in this plan.
- [x] Add no streaming capture, parallel recorder, native encoder, spool/replay, enlarged upload route, or server audio storage.
- [x] The auth server owns retryability for HTTP responses; the app does not infer provider behavior from status or error strings.
- [x] Preserve released server endpoint, status, and `error` values; add only an authoritative boolean.
- [x] Treat omitted/malformed retryability from an older server as terminal; definite local connection failures remain retryable.
- [x] Model retained audio inside one sealed, per-composer service session and module_core `VoiceInputCubit` state.
- [x] Put Retry/discard in the composer, not only in a dismissible popup.
- [x] Delete on success, terminal rejection, initial cancel, discard, missing-artifact detection, and Cubit/session close; retain across repeated retryable failures and manual-retry cancellation.
- [x] Keep the retry artifact memory-owned and composer-local; no cross-route or process-restart recovery.
- [x] Accept possible duplicate provider work/quota after response loss; add no idempotency or automatic retry machinery.
- [x] Add no analytics event; preserve one authoritative completion event after eventual success.
- [x] Keep bridge, relay, plugins, desktop, databases, and shared crypto out of scope.
- [x] Require L4 Extended async coverage before retirement.

## Locked Architecture

- [x] HTTP `VoiceApi` remains Layer 1 and returns typed API DTOs.
- [x] Add Layer-2 `VoiceRepository` for transport/server failure mapping.
- [x] Add module_core `VoiceCapture`/`VoiceCaptureSession` platform contracts and an app `core/platform` implementation for recorder/file/wake-lock mechanics.
- [x] Do not add pass-through capture API/repository classes: scoped client rules explicitly allow module_core to consume platform interfaces directly.
- [x] Register Layer-3 `VoiceTranscriptionService` as a stateless `@lazySingleton` that owns every business operation/transition and operates on one unregistered state-only `VoiceTranscriptionSession` per composer.
- [x] Add factory-constructed module_core `VoiceInputCubit`; the app wires it with `BlocProvider`, the Cubit invokes service operations with its session, and `PromptInput` only renders state/dispatches intents.
- [x] Cubit close synchronously fences its session before asynchronous native/upload/artifact cleanup.
- [x] Auth adapters classify detailed provider-neutral reasons, including terminal provider quota versus transient capacity.
- [x] Auth composition injects `legacyOpenAiV1` or `detailedV1` public-error policy into `VoiceService`.
- [x] `VoiceService`, not adapters or the client, applies status/error compatibility and retryability.

## Complexity Guardrails

- [x] At most one retained async artifact per composer service session.
- [x] No persistence, database schema, queue, retry timer, connectivity listener, request registry, or dedupe cache.
- [x] No raw provider error, audio, transcript, prompt, or path in server responses or analytics.
- [x] No provider-specific client branch.
- [x] No streaming recording or replay path in this series.
- [x] Client architecture migration and retry behavior stay in separate PRs.
- [x] Never merge retention without a reachable retry/discard owner.
- [x] User approved one cohesive Step 3 after the candidate measured roughly 3,300 touched lines including about 977 causal legacy deletions; the final 2,800-4,200 budget includes architecture/PR-review lifecycle fixes without introducing a temporary duplicate lifecycle or compatibility wrapper.

## Delivery Steps

| Done | Step | Repository | Exact PR title | Target | State |
|---|---|---|---|---:|---|
| [x] | 1/5 | apps | `🌱 [voice-transcription-retry] Plan async voice transcription retries [step 1/5]` | 500-700 | [PR #1144](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1144) merged as `bd7ad4bc` |
| [x] | 2/5 | auth | `⚙️ [voice-transcription-retry] Mark async transcription failures retryable [step 2/5]` | 500-950 | [PR #77](https://github.com/sesori-ai/sesori_auth_server/pull/77) merged as `459d2663c8` |
| [x] | 3/5 | apps | `🚧 [voice-transcription-retry] Move voice lifecycle into client core [step 3/5]` | 2,800-4,200 | [PR #1162](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1162) merged as `41f9ac9d`; 4,176 changed lines, architecture approved, eleven review findings addressed |
| [x] | 4/5 | apps | `⚙️ [voice-transcription-retry] Retain and retry async voice recordings [step 4/5]` | 1,400-2,200 | [PR #1172](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1172) merged as exact checkpoint `1a6007228f`; 2,032 changed lines |
| [x] | 5/5 | apps | `🌿 [voice-transcription-retry] Verify async voice retries and retire plan [step 5/5]` | 100-260 | Async matrix passed and recorded in `VERIFICATION.md`; retirement PR pending publication |

## Step 1 Checklist

- [x] Inspect current voice API, service, composer state, localization, tests, and regression contract.
- [x] Inspect current auth route, provider adapters, failure mapping, tests, and compatibility markers.
- [x] Inspect relevant Git history for the async voice implementation and released endpoint contract.
- [x] Record exact retry/artifact/error matrix and old-server fallback.
- [x] Record detailed auth reason plus composition-owned compatibility policies.
- [x] Record separate platform capability plus HTTP API → Repository → Service → Cubit → Composer ownership and composer-scoped cleanup.
- [x] Record the async-only product scope, server-first rollout, privacy, analytics, cleanup, and duplicate-work risk.
- [x] Define fixed five-step titles, repositories, changed-line targets, and L4 matrix.
- [x] Run `architecture-plan-review` through a sub-agent.
- [x] Apply every blocking architecture-plan finding within the delivered async scope directly; do not re-review routine corrections.
- [x] Inspect all seven Codex PR-review threads across both review rounds and both review summaries.
- [x] Apply Cubit ownership, service lifetime, substantive service operations, retry-cancel retention, provider-quota, and same-PR regression findings; clarify why platform capture has no pass-through API/repository.
- [x] Collapse the fixed series from six steps to five after moving regression documentation into Step 4.
- [x] Run final plan consistency validation and `git diff --check`.
- [x] Commit, push, open Step 1 PR, record URL/change count, and start PR monitor.

## Step 2 Checklist

- [x] Add `UnusableAudio`/`QuotaExhausted` and detailed provider-neutral classification.
- [x] Detect provider quota code/type before generic 429 capacity in OpenAI and Soniox adapters.
- [x] Inject `legacyOpenAiV1`/`detailedV1` policy from composition into `VoiceService`.
- [x] Preserve every released async status/error value while adding fixed booleans, including false on the voice daily-quota response.
- [x] Test every reason, daily quota, unexpected error, connected cancellation, authenticated validation/upload failures, and route rate limiting.
- [x] Keep raw provider details private and existing Retry-After semantics intact.
- [x] Update auth README with the authoritative async retryability contract and compatibility policy.
- [x] Pass focused auth verification and architecture implementation review.

## Step 3 Checklist

- [x] Add pure-Dart `VoiceCapture`/`VoiceCaptureSession` platform contracts and concrete app adapter.
- [x] Keep HTTP `VoiceApi` Layer 1; add `VoiceRepository` Layer 2.
- [x] Add stateless lazy-singleton `VoiceTranscriptionService` owning all operations/transitions plus an unregistered state-only session per composer.
- [x] Add module_core `VoiceInputCubit`/sealed state, wired only through `BlocProvider` and invoking the service with its owned session.
- [x] Make `PromptInput` render Cubit state and dispatch intents; fence/clean up through Cubit close.
- [x] Remove app-shell singleton/private business state/direct API ownership without adding retry behavior yet.
- [x] Prove permission/record/transcribe/cancel/cleanup behavior and per-composer isolation in focused tests.
- [x] Complete codegen, focused/downstream tests, strict analysis, and two-pass architecture implementation review on the local candidate.
- [x] Merge `origin/main` at `746e222c42` after Step 2 merged, resolve drift, regenerate code, and rerun affected verification before publication.

## Step 4 Checklist

- [x] Add typed generated auth failure metadata and repository true/false/omitted/malformed mapping.
- [x] Add retry-pending to the sealed service-session/Cubit lifecycle and exact artifact disposition.
- [x] Add localized Retry/discard/saved/terminal/missing-artifact composer presentation.
- [x] Preserve cancellation generations, wake lock, amplitude, max duration, draft spans, focus, and one completion event.
- [x] Prove voice-first/text-first behavior, old-server omission fallback, and manual-retry cancellation returning to retry-pending with the artifact retained.
- [x] Update `docs/regression/voice-input.md` in the same production PR; remove stale every-exit-deletes behavior.
- [x] Add no streaming capture or recording-replay behavior.
- [x] Route valid send-time abandonment through Cubit → Service discard while refused submissions retain audio; document duplicate-work/quota risk.
- [x] Complete the second/final architecture implementation review; approved with no findings after first-pass corrections.

## Step 5 Checklist

- [x] Pass automated API/repository/service/platform/widget coverage.
- [x] Pass voice-first and text-first async modes on the user-approved owned iOS simulator substitution; do not claim physical coverage.
- [x] Exercise local network loss then successful retry without re-recording.
- [x] Exercise explicit async server retryable and unusable-audio non-retryable outcomes.
- [x] Exercise older-server omission and released-app/new-server fixture compatibility.
- [x] Verify cancel/discard/disposal/background cleanup, manual-retry cancel retention, permission revocation, and privacy-safe logs/analytics.
- [x] Record mode/provider/platform/auth-build matrix and privacy-safe evidence in `VERIFICATION.md`.
- [x] Move the plan to completed after every required async matrix row passes.

## Plan Review

- **Reviewer:** `architecture-plan-review` sub-agent
- **Reviewed scope:** initial complete `.plan/active/voice-transcription-retry/`
- **Verdict:** rejected after pre-review gate passed
- **Blocking findings retained for the delivered async scope:** singleton/composer ownership mismatch; missing OpenAI retryability-versus-HTTP compatibility owner; app-shell Service directly calling Layer-1 API without Repository
- **Scope reconciliation:** the completed tracker records only findings applicable to behavior merged on `main`; unrelated unpublished work is not a retirement dependency and is intentionally excluded
- **Initial corrections applied:** composer-scoped factory service with synchronous disposal fence; Foundation/API/Repository/Service layering; composition-injected auth public-error policies and complete reason table
- **PR review round 1:** accepted module_core Cubit ownership, lazy-singleton service plus per-composer session, provider-quota classification, and same-PR async regression documentation; declined a pass-through capture API/repository because scoped platform rules explicitly permit direct interface consumption, then clarified the two dependency paths
- **PR review round 2:** made the lazy service substantively own every operation/transition with the session reduced to state only; split initial cancellation from manual-retry cancellation so Retry cancellation preserves the artifact
- **Re-review:** architecture-plan review not rerun; repository policy says apply valid findings directly without routine approval re-review

## Verification Log

- **Step 1 architecture review:** initial draft rejected; all relevant findings applied as recorded above
- **Step 1 documentation validation:** plan/tracker titles, five-step denominator, repositories, targets, async-only scope, quota classification, substantive service/Cubit ownership, retry-cancel retention, same-PR regression update, and both review rounds agree; whitespace check passed
- **Step 1 changed lines:** 625 documentation-only additions (`PLAN.md` 460, `TRACKER.md` 165), within the 500-700 target
- **Step 1 commits:** `620cb5c6c` (plan), tracker records, `c55a0846b` (review round 1), and `830ba2e8d` (review round 2)
- **Step 1 PR:** [#1144](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1144), merged as `bd7ad4bc374d959309154d2a30697d698ec56970`
- **Step 2 server verification:** PR #77 merged as `459d2663c8`; format/lint/build/circular-dependency checks pass, focused provider/policy suites pass, full Node suite passed 941 with one skipped before the route-level review follow-up, route/service follow-up passes 51/51, and architecture implementation review approved with no findings
- **Step 3 ownership migration:** PR [#1162](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1162) merged as `41f9ac9dcb`, 4,176 changed lines; synchronized with apps `origin/main` at `746e222c42`; codegen and module_core/app strict analysis pass, along with 26 focused core tests, 17 platform/path tests, 86 composer tests, and 59 new-session/routing tests; architecture approved, then eleven PR review findings were addressed across typed causes, stop/cancel/disposal serialization, in-flight stop cancellation, post-start rollback, both conditional composer lifetimes, adapter-owned and time-bounded native prewarm/activity coordination, and concurrent path uniqueness
- **Step 4 client retry verification:** PR [#1172](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1172) merged as `1a6007228f` at 2,032 changed lines; module_core/app strict analysis, generated DTO/state/localization output, 39 focused API/repository/service/Cubit tests, 17 platform/path tests, 94 composer tests, and 58 affected new-session/routing tests pass; first architecture review rejected send-time abandonment/docs, both findings were fixed, the second/final review approved, and three PR findings were addressed across send serialization, active-retry abandonment, and capture-release lifecycle alignment
- **Step 4 regression reconciliation:** merged with the async implementation and remains authoritative on apps `main`
- **Step 5 L4 evidence:** `VERIFICATION.md`; all rows in the user-approved simulator matrix passed, including production HTTP 200/non-empty live-provider transcription
- **Step 5 environment cleanup:** auth URL restored, temporary stubs/Flutter/bridge stopped, microphone permission restored, owned simulator shut down
- **Final disposition:** completed from merged async behavior after every required matrix row passed; no row remains partial, blocked, failed, or unexecuted
