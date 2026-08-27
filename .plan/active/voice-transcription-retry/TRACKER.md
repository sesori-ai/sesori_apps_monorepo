# Retained Async Voice Transcription Retry: Tracker

## Current State

- **Plan slug:** `voice-transcription-retry`
- **Apps base:** `origin/main` at `10e9c8c4bb`
- **Auth base:** `origin/master` at `93b4323dca`
- **Current branch:** `voice-retry-behavior`
- **Series state:** Step 1/6 PR [#1144](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1144) open
- **Current step:** plan publication
- **Next action:** drive Step 1 PR to ready for human review
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
- [x] Model retained audio inside one sealed, composer-scoped core service lifecycle and one existing sealed composer interaction.
- [x] Put Retry/discard in the composer, not only in a dismissible popup.
- [x] Delete on success, terminal rejection, cancel, discard, missing-artifact detection, and service disposal; retain across repeated retryable failures.
- [x] Keep the retry artifact memory-owned and composer-local; no cross-route or process-restart recovery.
- [x] Accept possible duplicate provider work/quota after response loss; add no idempotency or automatic retry machinery.
- [x] Add no analytics event; preserve one authoritative completion event after eventual success.
- [x] Keep bridge, relay, plugins, desktop, databases, and shared crypto out of scope.
- [x] Require L4 Extended async coverage before retirement.

## Locked Architecture

- [x] `VoiceApi` remains Layer 1 and returns typed API DTOs.
- [x] Add Layer-2 `VoiceRepository` for transport/server failure mapping.
- [x] Move policy and sealed lifecycle to factory-scoped Layer-3 `VoiceTranscriptionService` in module_core.
- [x] Add a module_core Foundation platform contract and app `core/platform` implementation for recorder/file/wake-lock mechanics.
- [x] `PromptInput` owns one service instance, synchronously fences it on disposal, and starts contained async cleanup.
- [x] Auth adapters classify detailed provider-neutral reasons only.
- [x] Auth composition injects `legacyOpenAiV1` or `detailedV1` public-error policy into `VoiceService`.
- [x] `VoiceService`, not adapters or the client, applies status/error compatibility and retryability.
- [x] PR #918 cannot merge before Steps 3–4; it must rebase and adopt the same ownership rather than retaining a second app service.

## Complexity Guardrails

- [x] At most one retained async artifact per composer service.
- [x] No persistence, database schema, queue, retry timer, connectivity listener, request registry, or dedupe cache.
- [x] No raw provider error, audio, transcript, prompt, or path in server responses or analytics.
- [x] No provider-specific client branch.
- [x] No realtime recording retry in this series.
- [x] Client architecture migration and retry behavior stay in separate PRs.
- [x] Never merge retention without a reachable retry/discard owner.

## Delivery Steps

| Done | Step | Repository | Exact PR title | Target | State |
|---|---|---|---|---:|---|
| [ ] | 1/6 | apps | `🌱 [voice-transcription-retry] Plan async voice transcription retries [step 1/6]` | 500-700 | [PR #1144](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1144) open |
| [ ] | 2/6 | auth | `⚙️ [voice-transcription-retry] Mark async transcription failures retryable [step 2/6]` | 450-900 | Blocked on Step 1 merge |
| [ ] | 3/6 | apps | `🚧 [voice-transcription-retry] Move voice lifecycle into client core [step 3/6]` | 1,050-1,500 | Blocked on Step 2 contract |
| [ ] | 4/6 | apps | `⚙️ [voice-transcription-retry] Retain and retry async voice recordings [step 4/6]` | 650-1,150 | Blocked on Step 3 |
| [ ] | 5/6 | apps | `🌱 [voice-transcription-retry] Document async voice retry behavior [step 5/6]` | 50-140 | Blocked on Step 4 and #918 rebase checkpoint |
| [ ] | 6/6 | apps | `🌿 [voice-transcription-retry] Verify async voice retries and retire plan [step 6/6]` | 60-180 | Blocked on Step 5 |

## Step 1 Checklist

- [x] Inspect current voice API, service, composer state, localization, tests, and regression contract.
- [x] Inspect current auth route, provider adapters, failure mapping, tests, and compatibility markers.
- [x] Inspect relevant Git history and active realtime PLAN/TRACKER.
- [x] Verify PR #918 is open at `b3083b7ad3`, overlaps voice ownership, and currently conflicts with `main`.
- [x] Record exact retry/artifact/error matrix and old-server fallback.
- [x] Record detailed auth reason plus composition-owned compatibility policies.
- [x] Record Foundation → API → Repository → Service → Composer ownership and composer-scoped disposal.
- [x] Record the user's async-only retry decision and realtime behavior distinction.
- [x] Record server-first rollout, #918 merge barrier, privacy, analytics, cleanup, and duplicate-work risk.
- [x] Define fixed six-step titles, repositories, changed-line targets, and L4 matrix.
- [x] Run `architecture-plan-review` through a sub-agent.
- [x] Apply all four blocking findings directly; do not re-review routine corrections.
- [x] Run final plan consistency validation and `git diff --check`.
- [x] Commit, push, open Step 1 PR, record URL/change count, and start PR monitor.

## Step 2 Checklist

- [ ] Add `UnusableAudio` and detailed OpenAI provider-neutral classification.
- [ ] Inject `legacyOpenAiV1`/`detailedV1` policy from composition into `VoiceService`.
- [ ] Preserve every released async status/error value while adding fixed booleans.
- [ ] Test every reason, unexpected error, and connected cancellation under both policies.
- [ ] Keep raw provider details private and existing Retry-After semantics intact.
- [ ] Update auth README plus realtime PLAN/TRACKER with async-only decision and #918 barrier.
- [ ] Pass focused auth verification and architecture implementation review.

## Step 3 Checklist

- [ ] Add pure-Dart recording platform contract and concrete app factory adapter.
- [ ] Keep `VoiceApi` Layer 1; add `VoiceRepository` Layer 2.
- [ ] Move orchestration to factory-scoped module_core `VoiceTranscriptionService` Layer 3.
- [ ] Make `PromptInput` own, synchronously invalidate, and asynchronously dispose one service.
- [ ] Remove app-shell singleton/direct API ownership without adding retry behavior yet.
- [ ] Prove permission/record/transcribe/cancel/cleanup behavior is unchanged.
- [ ] Run codegen, focused/downstream tests, strict analysis, and architecture implementation review.

## Step 4 Checklist

- [ ] Add typed generated auth failure metadata and repository true/false/omitted/malformed mapping.
- [ ] Add retry-pending to the sealed core lifecycle and exact artifact disposition.
- [ ] Add localized Retry/discard/saved/terminal/missing-artifact composer presentation.
- [ ] Preserve cancellation generations, wake lock, amplitude, max duration, draft spans, focus, and one completion event.
- [ ] Prove voice-first/text-first behavior and old-server omission fallback.
- [ ] Add no realtime dual-capture/retry behavior.
- [ ] Run codegen/localization, focused/downstream tests, strict analysis, and architecture implementation review.

## PR #918 Rebase Checkpoint

- [ ] Rebase #918 onto exact merged Step 4 SHA and record new base/head in auth realtime tracker.
- [ ] Resolve VoiceApi/DI/platform/repository/service/PromptInput/test/doc overlaps.
- [ ] Preserve async retained retry and old-server fallback tests.
- [ ] Preserve post-audio realtime confirmed-partial/no-full-retry behavior.
- [ ] Prove realtime failure never falsely shows the async Retry control.
- [ ] Return #918 to mergeable, CI-green, reviewed state before it may merge.

## Step 5 Checklist

- [ ] Reconcile `docs/regression/voice-input.md` required behavior, levels, failure signals, and limitations.
- [ ] State async retry versus realtime post-audio partial-text behavior honestly.
- [ ] Complete cleanup audit against actual code and rebased #918 branch.
- [ ] Validate documentation-only diff with `git diff --check`.

## Step 6 Checklist

- [ ] Pass automated API/repository/service/platform/widget coverage.
- [ ] Pass one release-target physical mobile platform in voice-first and text-first async modes.
- [ ] Exercise local network loss then successful retry without re-recording.
- [ ] Exercise explicit async server retryable and unusable-audio non-retryable outcomes.
- [ ] Exercise older-server omission and released-app/new-server fixture compatibility.
- [ ] Verify cancellation/discard/disposal cleanup and privacy-safe logs/analytics.
- [ ] If realtime is in the build, prove post-audio failure has no false retained-file Retry claim.
- [ ] Record mode/provider/platform/auth-build matrix and privacy-safe evidence.
- [ ] Move plan to completed only when all required L4 rows pass or the user records an explicit reduction.

## Plan Review

- **Reviewer:** `architecture-plan-review` sub-agent
- **Reviewed scope:** initial complete `.plan/active/voice-transcription-retry/`
- **Verdict:** rejected after pre-review gate passed
- **Blocking findings:** singleton/composer ownership mismatch; missing OpenAI retryability-versus-HTTP compatibility owner; stale/unreconciled realtime PR #918 baseline; app-shell Service directly calling Layer-1 API without Repository
- **Corrections applied:** composer-scoped factory service with synchronous disposal fence; Foundation/API/Repository/Service layering; composition-injected auth public-error policies and complete reason table; verified #918 head/overlap plus hard rebase-before-merge checkpoint; async-only realtime scope decision
- **Re-review:** not run; repository policy says apply valid findings directly without routine approval re-review

## Verification Log

- **Step 1 architecture review:** initial draft rejected; all four findings applied as recorded above
- **Step 1 documentation validation:** plan/tracker titles, six-step denominator, repositories, targets, async-only decision, #918 barrier, and review record agree; new-file whitespace check passed
- **Step 1 changed lines:** 636 documentation-only additions (`PLAN.md` 473, `TRACKER.md` 163), within the 500-700 target
- **Step 1 commits:** `620cb5c6c` (plan publication) plus the tracker-only delivery record
- **Step 1 PR:** [#1144](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1144), open and monitored
- **Step 2 server verification:** pending
- **Step 3 ownership migration:** pending
- **Step 4 client retry verification:** pending
- **Step 5 regression reconciliation:** pending
- **Step 6 L4 evidence:** pending
- **Final disposition:** active
