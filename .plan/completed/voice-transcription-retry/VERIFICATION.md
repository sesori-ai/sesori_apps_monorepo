# Step 5 Verification — Async Voice Retry

## Scope and substitution

- **Date:** 2026-08-28
- **Client build:** apps main lineage through `b883bcad80`, containing async retry Step 4 merge `1a6007228f`
- **Mode:** file-based async capture and upload
- **Client platform:** `sesori-dev-1`, iPhone 17 simulator, iOS 26.5
- **Auth:** production `api.sesori.com` contract plus deterministic localhost fixtures
- **Provider:** all configured async adapters covered automatically; the configured production provider returned one live non-empty transcript
- **Bridge/plugin scope:** local bridge supplied a real composer/session only; no coding plugin behavior participates

The user explicitly replaced the plan's physical-device row with simulator coverage. This is an accepted reduction of the
matrix, not a claim that physical microphone, audio-session, haptics, or hardware wake behavior was exercised.

## L4 matrix

| Status | Journey | Privacy-safe evidence |
|---|---|---|
| Pass | Voice-first local connection failure retains one completed recording | Composer showed persistent **Recording saved**, Retry, and Discard; retained cache file was 76,616 bytes. |
| Pass | Voice-first manual Retry succeeds without recording again | The retained artifact was reused and editable transcript text appeared. Screenshots: `/tmp/voice-retry-pending-voice-first.png`, `/tmp/voice-retry-success-voice-first.png`. |
| Pass | Text-first retry preserves the existing draft | Existing draft `Okay. Bye.` remained while Retry/Discard was visible and after eventual success. Screenshots: `/tmp/voice-retry-pending-text-first.png`, `/tmp/voice-retry-success-text-first.png`. |
| Pass | Explicit authoritative retryable failure | Local HTTP fixture returned a typed 503 body with `retryable: true`; the composer retained the file and exposed Retry/Discard. |
| Pass | Explicit terminal unusable/non-retryable failure | Local fixture returned terminal metadata; the composer returned to normal input with no Retry and attempted deletion. |
| Pass | Older-server omission is terminal | Local fixture omitted retryability; the client did not infer from status/error and showed no Retry. |
| Pass | Quota/auth rejection is terminal | Local quota fixture produced no Retry; automated repository/route coverage retains authentication and quota mapping. |
| Pass | Cancelling a hanging manual Retry retains ownership | Cancel returned to Retry/Discard with the same artifact. Screenshot: `/tmp/voice-retry-cancel-retained.png`. |
| Pass | Discard and composer disposal delete the retained artifact | Discard reduced app audio files to zero. A second retained file was observed before route exit and zero files remained after composer disposal. |
| Pass | Background/system interruption does not strand capture state | Backgrounding during active capture returned at the project surface with zero app audio files; background/foreground of retry-pending retained its actions while the process stayed alive. |
| Pass | Permission revoked between interactions prevents upload | Simulator microphone permission was revoked; the next interaction created no audio file and did not increment the local upload fixture request count. Permission was restored afterwards. |
| Pass | Current production provider accepts a real encoded audio upload | A synthesized spoken sentence was encoded to a 20,161-byte M4A and posted through the production authenticated endpoint; response was HTTP 200 with a non-empty 43-character transcript. Transcript content and bearer tokens were not printed. |
| Pass | Provider classifications and released compatibility | Auth Step 2 adapter/policy/route suites cover every configured async adapter and preserve released status/error fixtures while adding the boolean. |
| Pass | Cleanup, privacy, and completion analytics | Focused service/platform/widget tests cover initial cancel, terminal cleanup, deletion failure observability, wake-lock leases, stale fencing, and exactly one content-free completion event. Simulator logs contained operation/error context but no audio bytes, prompt, or transcript payload. |

## Deterministic fault fixtures

Temporary localhost endpoints supplied retryable, terminal, omitted-metadata, quota, hanging-retry, and success responses.
`client/module_auth/lib/src/auth_config.dart` was restored to `https://api.sesori.com`; no fixture URL or credential change
remains in Git. Stub, Flutter, and bridge processes were stopped, and only the owned `sesori-dev-1` simulator was shut
down.

The live provider initially returned a malformed/non-JSON 504. The client treated unknown metadata as terminal, as
required. A later authenticated production request returned HTTP 200 and completed the provider row.

## Automated evidence

- Auth PR #77: provider classification, public-policy, route, quota, validation, rate-limit, and compatibility coverage.
- Apps PR #1172: strict module-core/app analysis; 39 focused API/repository/service/Cubit tests, 17 platform/path tests,
  94 composer tests, and 58 affected new-session/routing tests.
- Git ancestry confirms verification build `b883bcad80` and Step 4 merge `1a6007228f` are both contained in apps
  `main` `cf9b33d275`.
- Generated DTO/state/localization/DI output and `git diff --check` passed in the implementation PRs.

## Acceptance result

All rows in the user-approved simulator matrix passed. No automatic retry, persistence, restart recovery, cross-route
recovery, idempotency registry, streaming capture, recording spool, or replay path was introduced. The delivered async
behavior is merged on apps `main`, so the plan is retired.
