# Retained Async Voice Transcription Retry: Tracker

## Current State

- **Plan slug:** `voice-transcription-retry`
- **Apps base:** `origin/main` at `ac08fee06b`
- **Auth base:** `origin/master` at `0cfca944e1`
- **Current branch:** `plan/voice-transcription-retry/s03-core-voice-lifecycle`
- **Series state:** Step 1 merged; Step 2 auth PR [#77](https://github.com/sesori-ai/sesori_auth_server/pull/77) open and ready; Step 3 implemented locally pending final review
- **Current step:** 3/5 ownership migration, held local until Step 2 merges
- **Next action:** finish Step 3 verification and architecture review while monitoring auth PR #77
- **External merge barrier:** realtime apps PR [#918](https://github.com/sesori-ai/sesori_apps_monorepo/pull/918), current head `b3083b7ad3`, must rebase onto merged Step 4 before it may merge

## Locked Product Decisions

- [x] Retain the completed temporary artifact only after a local transport failure or server-declared retryable **async** failure.
- [x] Retry is manual and reuses the exact artifact/MIME without restarting the recorder.
- [x] A server/model rejection that cannot benefit from identical audio shows no Retry.
- [x] Full-recording retry is intentionally async-only because realtime dual capture/compression is disproportionately complex.
- [x] Realtime pre-audio failure may fall back to async; post-audio failure keeps confirmed partial text and has no full-recording Retry.
- [x] Add no dual capture, native encoder, PCM spool/replay, second recorder, enlarged upload route, or server audio storage.
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
- [x] PR #918 cannot merge before Steps 3–4; it must rebase and adopt the same ownership rather than retaining a second app service.

## Complexity Guardrails

- [x] At most one retained async artifact per composer service session.
- [x] No persistence, database schema, queue, retry timer, connectivity listener, request registry, or dedupe cache.
- [x] No raw provider error, audio, transcript, prompt, or path in server responses or analytics.
- [x] No provider-specific client branch.
- [x] No realtime recording retry in this series.
- [x] Client architecture migration and retry behavior stay in separate PRs.
- [x] Never merge retention without a reachable retry/discard owner.
- [x] User approved one cohesive Step 3 after the candidate measured roughly 3,300 touched lines including about 977 causal legacy deletions; the final 2,800-3,700 budget includes the required session-safe wake-lock review fix without introducing a temporary duplicate lifecycle or compatibility wrapper.

## Delivery Steps

| Done | Step | Repository | Exact PR title | Target | State |
|---|---|---|---|---:|---|
| [x] | 1/5 | apps | `🌱 [voice-transcription-retry] Plan async voice transcription retries [step 1/5]` | 500-700 | [PR #1144](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1144) merged as `bd7ad4bc` |
| [ ] | 2/5 | auth | `⚙️ [voice-transcription-retry] Mark async transcription failures retryable [step 2/5]` | 500-950 | [PR #77](https://github.com/sesori-ai/sesori_auth_server/pull/77) open, passing, mergeable, ready for human review |
| [ ] | 3/5 | apps | `🚧 [voice-transcription-retry] Move voice lifecycle into client core [step 3/5]` | 2,800-3,700 | Implemented locally; architecture approved, final merge-forward/verification pending Step 2 merge |
| [ ] | 4/5 | apps | `⚙️ [voice-transcription-retry] Retain and retry async voice recordings [step 4/5]` | 700-1,250 | Blocked on Step 3 |
| [ ] | 5/5 | apps | `🌿 [voice-transcription-retry] Verify async voice retries and retire plan [step 5/5]` | 60-180 | Blocked on Step 4 and #918 rebase checkpoint |

## Step 1 Checklist

- [x] Inspect current voice API, service, composer state, localization, tests, and regression contract.
- [x] Inspect current auth route, provider adapters, failure mapping, tests, and compatibility markers.
- [x] Inspect relevant Git history and active realtime PLAN/TRACKER.
- [x] Verify PR #918 is open at `b3083b7ad3`, overlaps voice ownership, and currently conflicts with `main`.
- [x] Record exact retry/artifact/error matrix and old-server fallback.
- [x] Record detailed auth reason plus composition-owned compatibility policies.
- [x] Record separate platform capability plus HTTP API → Repository → Service → Cubit → Composer ownership and composer-scoped cleanup.
- [x] Record the user's async-only retry decision and realtime behavior distinction.
- [x] Record server-first rollout, #918 merge barrier, privacy, analytics, cleanup, and duplicate-work risk.
- [x] Define fixed five-step titles, repositories, changed-line targets, and L4 matrix.
- [x] Run `architecture-plan-review` through a sub-agent.
- [x] Apply all four blocking architecture-plan findings directly; do not re-review routine corrections.
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
- [x] Update auth README plus realtime PLAN/TRACKER with async-only decision and #918 barrier.
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
- [ ] Merge current `origin/main` after Step 2 merges, resolve drift, and rerun affected verification before publication.

## Step 4 Checklist

- [ ] Add typed generated auth failure metadata and repository true/false/omitted/malformed mapping.
- [ ] Add retry-pending to the sealed service-session/Cubit lifecycle and exact artifact disposition.
- [ ] Add localized Retry/discard/saved/terminal/missing-artifact composer presentation.
- [ ] Preserve cancellation generations, wake lock, amplitude, max duration, draft spans, focus, and one completion event.
- [ ] Prove voice-first/text-first behavior, old-server omission fallback, and manual-retry cancellation returning to retry-pending with the artifact retained.
- [ ] Update `docs/regression/voice-input.md` in the same production PR; remove stale every-exit-deletes behavior.
- [ ] Add no realtime dual-capture/retry behavior or unshipped realtime claims.
- [ ] Run codegen/localization, focused/downstream tests, strict analysis, and architecture implementation review.

## PR #918 Rebase Checkpoint

- [ ] Rebase #918 onto exact merged Step 4 SHA and record new base/head in auth realtime tracker.
- [ ] Resolve VoiceApi/DI/platform-session/repository/service/Cubit/PromptInput/test/doc overlaps.
- [ ] Preserve async retained retry and old-server fallback tests.
- [ ] Preserve post-audio realtime confirmed-partial/no-full-retry behavior.
- [ ] Prove realtime failure never falsely shows the async Retry control.
- [ ] Return #918 to mergeable, CI-green, reviewed state before it may merge.

## Step 5 Checklist

- [ ] Pass automated API/repository/service/platform/widget coverage.
- [ ] Pass one release-target physical mobile platform in voice-first and text-first async modes.
- [ ] Exercise local network loss then successful retry without re-recording.
- [ ] Exercise explicit async server retryable and unusable-audio non-retryable outcomes.
- [ ] Exercise older-server omission and released-app/new-server fixture compatibility.
- [ ] Verify initial-cancel/discard/disposal cleanup, manual-retry cancel retention, and privacy-safe logs/analytics.
- [ ] If realtime is in the build, prove post-audio failure has no false retained-file Retry claim.
- [ ] Record mode/provider/platform/auth-build matrix and privacy-safe evidence.
- [ ] Move plan to completed only when all required L4 rows pass or the user records an explicit reduction.

## Plan Review

- **Reviewer:** `architecture-plan-review` sub-agent
- **Reviewed scope:** initial complete `.plan/active/voice-transcription-retry/`
- **Verdict:** rejected after pre-review gate passed
- **Blocking findings:** singleton/composer ownership mismatch; missing OpenAI retryability-versus-HTTP compatibility owner; stale/unreconciled realtime PR #918 baseline; app-shell Service directly calling Layer-1 API without Repository
- **Initial corrections applied:** composer-scoped factory service with synchronous disposal fence; Foundation/API/Repository/Service layering; composition-injected auth public-error policies and complete reason table; verified #918 head/overlap plus hard rebase-before-merge checkpoint; async-only realtime scope decision
- **PR review round 1:** accepted module_core Cubit ownership, lazy-singleton service plus per-composer session, provider-quota classification, and same-PR async regression documentation; declined a pass-through capture API/repository because scoped platform rules explicitly permit direct interface consumption, then clarified the two dependency paths
- **PR review round 2:** made the lazy service substantively own every operation/transition with the session reduced to state only; split initial cancellation from manual-retry cancellation so Retry cancellation preserves the artifact
- **Re-review:** architecture-plan review not rerun; repository policy says apply valid findings directly without routine approval re-review

## Verification Log

- **Step 1 architecture review:** initial draft rejected; all four findings applied as recorded above
- **Step 1 documentation validation:** plan/tracker titles, five-step denominator, repositories, targets, async-only decision, #918 barrier, quota classification, substantive service/Cubit ownership, retry-cancel retention, same-PR regression update, and both review rounds agree; whitespace check passed
- **Step 1 changed lines:** 625 documentation-only additions (`PLAN.md` 460, `TRACKER.md` 165), within the 500-700 target
- **Step 1 commits:** `620cb5c6c` (plan), tracker records, `c55a0846b` (review round 1), and `830ba2e8d` (review round 2)
- **Step 1 PR:** [#1144](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1144), merged as `bd7ad4bc374d959309154d2a30697d698ec56970`
- **Step 2 server verification:** PR #77; format/lint/build/circular-dependency checks pass, focused provider/policy suites pass, full Node suite passed 941 with one skipped before the route-level review follow-up, route/service follow-up passes 51/51, and architecture implementation review approved with no findings
- **Step 3 ownership migration:** local candidate passes module_core/app strict analysis, 23 focused core tests, 9 wake-lock/platform-adapter tests, 85 composer tests, and 57 new-session/routing tests; first review's wake-lock isolation finding was fixed and the second architecture review approved with no findings; final merge-forward/diff pending
- **Step 4 client retry verification:** pending
- **Step 4 regression reconciliation:** pending with implementation
- **Step 5 L4 evidence:** pending
- **Final disposition:** active
