# Step 4 Verification — Harness-Unavailable Existing Chats

## Scope

- **Date:** 2026-09-08
- **Live-verified client commit:** `b101d455ec`
- **Current-head automated verification:** `08537e5abb`, including the later management-acknowledgment changes and merged
  step-3 PR
- **Current `main` incorporated:** `4dd60a2aa5`
- **Harness Settings redesign incorporated:** `69e276cc44` is an ancestor of the implementation base
- **Bridge:** isolated local slot 4 on macOS; no occupied bridge slot or normal Claude credential directory was changed
- **Mobile clients:** isolated iPhone 17 simulator on iOS 26.5 and an isolated API 36 Android emulator
- **Toolchain:** Flutter 3.47.2 and Dart 3.13.2
- **Scope boundary:** input gating only; no queue recovery, outbox, failed-send retention, attachment persistence,
  composer handoff redesign, retry redesign, or bridge protocol change

No screenshot, transcript, prompt, token, path supplied by a session, or raw entity identifier is committed. Visual
checks were performed on the isolated clients and are summarized below without retaining user-content media.

## Automated evidence

| Status | Area | Evidence |
|---|---|---|
| Pass | Shared interaction policy and load orchestration | 341 focused `module_core` cases passed across 12 suites: 283 session-detail/load/calculator/queue cases plus 58 plugin-management ownership, refresh, acknowledgment, publication-fencing, and bridge-identity cases. The cold/live gate cases exercise selection, command-staging, pagination, question-rejection, send, stop, and analytics refusal. |
| Pass | Mobile presentation and routing | 124 focused app cases passed across the session body, composer, dictation button, and adaptive router suites. |
| Pass | Shared notice and composer UI | 61 focused `module_app_ui` cases passed. These include blocked notice semantics, reason-specific guidance, retained-history behavior, attachment/picker disposal, voice-state disposal, and Settings/Retry vertical-center alignment. |
| Pass | Desktop routing | 3 focused desktop settings-routing cases passed. |
| Pass | Static analysis | `dart analyze` passed for `client/module_core`; `flutter analyze --no-pub` passed for `client/module_app_ui`, `client/app`, and `client/desktop`. The final test-only core change was followed by another clean `module_core` analysis. |
| Pass | Builds | `flutter build ios --simulator --debug --no-pub` and `flutter build apk --debug --no-pub` completed successfully. Same-lock ignored generated plugin artifacts were reused without dependency resolution and were not committed. |
| Pass | Document structure | Each owning regression document contains exactly one ordered L1–L5 table: attachments/images, plugin setup/lifecycle, questions/permissions, history/recovery, turns, and voice. |
| Pass | Source hygiene | Focused LSP diagnostics reported no issue and `git diff --check` passed. |

The focused matrix contains **529 passing test cases**: 341 core, 124 mobile, 61 shared UI, and 3 desktop.
Compact progress labels and setup/teardown events were not counted as test cases.

## Isolated live matrix

Registered plugin ids were `antigravity`, `claude-code`, `codex`, `copilot`, `cursor`, `deepseek`, `omp`, `opencode`,
`pi`, `qwen-code`, and `qwen-code-v2`. Claude supplied the authentication-required journey; DeepSeek supplied the
managed-runtime-missing and supporting ACP disable/enable journeys.

| Status | Journey | Privacy-safe evidence |
|---|---|---|
| Pass | Real management-state normalization | The isolated bridge listed all 11 registered plugins. Real snapshots included ready/dormant, runtime-missing, authentication-required, and unknown setup states; the exact session plugin determined interaction availability. |
| Pass | Authentication-required block on a loaded chat | Claude Code was launched against an isolated empty credential directory. Existing history stayed visible and copyable; the composer disappeared; the notice named authentication as the reason; Settings and Retry remained available. Clipboard payload presence was confirmed without printing it. |
| Pass | Exact Settings recovery target | **Open Harness Settings** opened the selected Claude row and showed **Authentication required**, not a generic settings destination. |
| Pass | Retry and Settings parity | The notice uses the original Retry text action with centered wrap alignment. Widget geometry differed by at most 0.5 logical pixels, and both iOS and Android visual checks showed the actions sharing one center line. |
| Pass | Recovery without reopening and post-recovery send | Restoring the isolated Claude prerequisite and refreshing on the open route returned normal controls. A harmless deterministic prompt completed with the expected short marker. |
| Pass | Cold unavailable shell | Opening existing Claude and DeepSeek sessions while their exact harness prerequisite was unavailable showed the read-only unavailable shell without attempting plugin-backed history. |
| Pass | Loaded transcript preservation | Disabling DeepSeek while a loaded session was open retained the transcript and copy affordance while removing the composer and bridge-owned controls. |
| Pass | Local-only cancellation | Focused Cubit coverage retained cancellation of a local queued item while refusing bridge-owned cancellation and queue drain during the block. |
| Pass | Other harness remains usable | An OpenCode session stayed interactive while Claude was authentication-blocked. |
| Pass | Managed runtime missing and restored | DeepSeek was pointed at an explicit nonexistent executable in the isolated environment; management reported runtime missing and the existing chat showed the matching guidance. Returning to the normal managed executable restored availability. |
| Pass | Runtime disable/enable without route reopen | A safe DeepSeek disable changed the open chat to **DeepSeek is disabled**. Re-enabling it restored controls on the same route without navigation. |
| Pass | Open response-dialog invalidation | A real multiple-choice question was open when DeepSeek was disabled. The dialog closed, no stale answer was submitted, history remained, and controls returned after re-enable. |
| Pass | Voice recording invalidation | On iOS, availability changed during active recording. The recording UI was replaced by the unavailable notice; releasing input did not submit content; recovery returned a fresh composer. |
| Blocked | Voice pending-transcription invalidation | The simulator produced no usable recording payload, so a distinct observable pending-transcription phase could not be held while the availability transition occurred. Active recording was covered, but it is not substituted for this row. |
| Pass | Attachment picker and staged attachment invalidation | A picker opened before a block could not repopulate the blocked composer after completion. A separately staged attachment was discarded on block and did not return after recovery. No file was sent. |
| Pass | Android unavailable-to-usable variation | On the API 36 emulator, a loaded DeepSeek chat retained history, replaced its composer with the disabled notice, and restored controls after enable without leaving the route. |
| Pass | Two-client convergence | The isolated iOS and Android clients viewed the same session. One external disable made both surfaces read-only with matching guidance; one enable restored both. |
| Pass | Current-main bridge reconnect | After incorporating the upstream concurrent-NDJSON fix, the isolated bridge reached connected/ready state with DeepSeek active and no unhandled exception or relay-client replacement in the final reconnect log. |
| Pass | Management failure and bridge-identity fencing | The 47-case plugin-management service suite proves same-bridge refresh retention/retry, unsupported management replacement, reconnect invalidation, and stale/different-bridge publication fencing. |
| Not applicable | Packaged public-old-bridge smoke | No qualifying public old-bridge artifact was established for this run. Unsupported-management behavior remains covered automatically; no unpublished/internal build is treated as a compatibility baseline. |
| Blocked | macOS desktop live client journey | Another Sesori desktop process was already running and was not disturbed. Approved GUI tooling was unavailable: Peekaboo was not installed/on `PATH`, and the approved `agent-device` command was unavailable. Automated desktop Settings routing passed, but it does not substitute for the required live desktop transition. |

## Setup boundary and cleanup

The first Android `--no-pub` build installed but remained at the splash surface because the ignored generated Android
plugin registrant was absent from this worktree. The client lockfile exactly matched the main checkout, so the same-lock
generated registrant was reused and the rebuilt app reached login normally. This was verification-infrastructure repair,
not a source change; the generated file remains ignored and is not part of the diff.

At cleanup, DeepSeek was enabled, both isolated app installations were removed, the Android emulator was stopped, the
owned iOS simulator was shut down, and the slot-4 bridge stopped cleanly. Ports and processes owned by other bridge
slots were not touched. The isolated development auth token was left in its configured slot as required by the
local-testing procedure.

## Acceptance result

The implemented behavior and all available automated evidence pass. The Android variation and two-client convergence
also pass. The macOS desktop live journey and distinct iOS pending-transcription transition remain honestly **Blocked**;
they are not counted as passes. After reviewing this evidence, the user explicitly accepted both named reductions on
2026-09-08. Every other applicable row passes, so the user-approved reduced matrix is complete and the plan is retired.
