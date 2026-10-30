# Live Voice, Send On Finish, And The Mic Marker

## Status

Agreed through review pages `voice-live-r1` and `voice-live-r2` (2026-10-30).
Implementation has not started.

## Goal

1. Tell the agent a prompt was dictated, by sending it as `🎙️ "…"`, so it can
   allow for misheard words.
2. Show the words live while the user speaks, through the server's existing
   `/voice/realtime` endpoint, while keeping today's record-then-transcribe mode.
   Remote config chooses between them, with no user-visible setting.
3. Send the message as soon as dictation finishes, instead of leaving the text in
   the box.

## Current Behavior (origin/main, 2026-10-30)

- `VoiceCapture` records to a file. `VoiceApi.transcribe` uploads it, and
  `VoiceTranscriptionService` and `VoiceInputCubit` own the session.
- `PromptInput` (`client/module_app_ui/.../widgets/prompt_input.dart`, 2,254 lines)
  owns the gestures through sealed `_VoiceGesturePresentation` states and appends
  the finished transcript to the draft with `appendVoiceTranscript`.
- Touch: hold to record, release to transcribe, drag onto a left X
  (`PregoVoiceCancelButton`) to cancel.
- Pointer: click the mic to start, click it again to transcribe, Esc cancels, the
  left X discards. **Clicking the mic slides it 44 px right** (measured
  660–704 → 704–748 at 760 px wide), so a second click in the same spot misses.
- `ComposerDraft.voiceSpans` produces `ComposerInputMode.voiceAssisted`, which is
  used for analytics only and never reaches the bridge.
- `FirebaseRemoteConfigClient` exists in `client/app` behind
  `@firebaseEnabledEnvironment`. **`client/desktop` has no Firebase dependency**,
  and uses no-op config sources.
- `VoiceInputCubit` is also used by the feedback sheet (`feedback_private_step.dart`).
- Production `GET https://api.sesori.com/voice/capabilities` reports realtime
  enabled, protocol 1.
- PR #918 (phone-only live voice, closed unmerged on 2026-08-28) is reference
  material at `refs/pull/918/head`.

## Decisions

All are the user's, from the review pages, except where marked as a planning
decision.

| # | Decision |
| --- | --- |
| D1 | Live words appear in **full focus** over the chat. A **floating panel** is built too, and remote config picks between them. |
| D2 | Tentative words are dim and brighten in place. |
| D3 | The waveform stays in the pill while words show. |
| D4 | The words glide to where they land, whether a bubble or the box. |
| D5 | No user-visible switch. Remote config chooses live or after-recording. |
| D6 | After-recording is the default. |
| D7 | Touch: **release sends. The left target becomes a pencil: slide onto it and release to put the words in the box. Slide up out of the pill to cancel.** |
| D8 | Sliding out reddens the pill and fades the words, following the finger. Sliding back restores them. A haptic tick and “Release to cancel” mark the point of no return. No new element. |
| D9 | The pencil is at the far left in both input modes, including “Type first”. |
| D10 | Desktop while listening: **pencil and X on the left, wide Send on the right.** The mic and the disabled send merge into the wide Send, so click, speak, click needs no mouse movement. Enter sends, Esc cancels. |
| D11 | Switches live in **Firebase Remote Config for the phone and are fixed in the build for desktop**. |
| D12 | Starting values: live with focus while only internal builds contain the code, then off for the first public release. Turning it on for everyone is the user's call. |
| D13 | After-recording sends on finish too, with the same gestures. |
| D14 | Send at once, with no countdown. |
| D15 | Whatever is in the box goes with the dictation as one message. |
| D16 | The same rule applies on the new session screen. |
| D17 | Any message with dictated text is marked whole. |
| D18 | The user's bubble shows the same text the agent got. |
| D19 | The marker is the emoji and quotes only. |
| D20 | A failed or cut-off dictation is never sent. Its words go in the box with a notice. Live keeps no recording, so it has no Retry; after-recording keeps Retry. |
| D21 | Live falls back to after-recording if it can't start. |
| D22 | The box always holds plain words. Titles use plain words. Slash commands are never marked. |
| D23 | While “Transcribing…” shows, an X stops it. |
| D24 | Cancelling keeps what was already in the box. |
| D25 | No words, or a hold under today's 200 ms minimum, sends nothing. |
| D26 | A hold never waits on the switch. With no value yet, it uses after-recording. |
| D27 | Desktop's focus view covers the chat pane only, with the words in a reading-width column. |
| D28 | Planning decision: desktop values come from `DesktopReleaseChannel`: `internal` gets live with focus, `stable` gets after-recording. This is D12 applied to D11. |
| D29 | Planning decision: audio captured before the server's `ready` is held in memory and flushed on `ready`, so the first words aren't lost. See Proportionality. |
| D30 | Planning decision: the client doesn't call `/voice/capabilities`. Remote config decides, and a disabled server fails the upgrade with 404, which is D21's fallback. |
| D31 | Planning decision: live and send on finish apply to the composer only. The feedback sheet keeps after-recording and keeps its words in its field. |

## Interaction Specification

These values come from the agreed mockups and are starting points to tune on a
real device.

**Touch hints:** `Release to send · slide up to cancel`, `Release to edit`,
`Release to cancel`.

**Desktop hint:** `Enter to send`. Tooltips on the pencil and X name their actions.
Shift+Enter is the keyboard path to the box.

**Finishing labels:** `Finishing…` in live, `Transcribing…` after recording.

| Motion | Value |
| --- | --- |
| Slide-up cancel arms | 64 px above the pill's top edge |
| Words opacity while sliding out | `1 - 0.6 × progress` |
| Pencil arms | At 90% of the way from the hold point to the pencil's centre; a cancel in progress wins |
| New word fade-in | 170 ms |
| Tentative word opacity | 0.46, easing to 1 over 280 ms, with no movement |
| Focus dim | 0.98 of the background, over 260 ms |
| Focus text | 23 pt on phone, 25 pt on desktop, medium weight |
| Panel | Grows upward to about five lines, then older lines fade at the top |
| Glide to bubble or box | 340 ms, `cubic-bezier(.2, .8, .2, 1)` |
| Cancel exit | 240 ms fade with a 12 px drop |

## Architecture

### Marker (step 2)

`sesori_shared` owns one pure pair, `wrapDictatedText` and `unwrapDictatedText`, so
the client and the bridge can't disagree on the format.

The client marks text where it builds the outgoing prompt, only when `command` is
null and `inputMode` is `voiceAssisted`:

- `SessionDetailCubit.sendMessage`
- the `QueuedSessionSubmission.text` path in `NewSessionCubit`

Drafts and `NewSessionSubmissionSnapshot` stay plain, because a refused new-session
submission restores from its snapshot into the box. `SessionCreationService` unwraps
`firstText` before generating metadata.

There is no wire-contract change. An older bridge would generate a title from the
marked text, which is cosmetic and accepted.

### Finish intent (steps 3–4)

`PromptInput` captures one closed `_VoiceFinish { send, edit }` value when the
gesture ends, carried inside the `_VoiceTranscribing` variant rather than in a
separate field.

On `VoiceInputCompleted`, the transcript is appended exactly as today. Then `send`
calls the existing `_submitComposer`, so attachments, command, `canSend` and
busy-queue rules all stay in one place. If `canSend` refuses, the words stay in the
box. A limit-reached or interrupted completion is treated as `edit`.

### Remote config (step 5)

Follows the existing `FeedbackPromptConfigSource` shape:

- `VoiceModeConfigSource` in `module_core/foundation/platform`
- `VoiceModeConfig`, sealed: `VoiceModeAfterRecording` and
  `VoiceModeLive({presentation})`, with `VoiceLivePresentation { focus, panel }`
- `FirebaseVoiceModeConfigSource` and a no-op source in `client/app`
- a channel-based source in `client/desktop` (D28)
- an API and a repository holding the last resolved value, reporting
  after-recording until one exists (D26)

Parameter keys: `voice_live_enabled` (unset reads as false) and
`voice_live_presentation` (`panel` gives panel; anything else gives focus).

### Transport (step 6)

Re-check and port from `refs/pull/918/head`, against the server's current fixture
`tests/fixtures/voice-realtime-protocol-v1.json`:

- `api/models/realtime_voice_protocol.dart`
- `api/realtime_voice_api.dart`
- `models/voice_realtime.dart`
- `foundation/platform/realtime_websocket_connector.dart`
- a connector implementation for `client/app`, and one reachable from
  `client/desktop`

Do not port #918's interaction code.

### Streaming capture (step 7)

`VoiceCaptureSession` gains a PCM16 mono 16 kHz stream start using `record`'s
`startStream`, and reports whether the platform supports it. A platform that can't
stream uses after-recording. Wake lock, audio session and the amplitude stream
carry over. This step measures connect-to-`ready` time on a real device, because
D29's buffer depends on it.

### Live session (step 8)

`VoiceTranscriptionService` adds live states to its private sealed session state.
`VoiceInputCubit` gains immutable states:

- `VoiceInputLiveRecording({words})`
- `VoiceInputLiveFinishing({words})`

Each carries `LiveWords({confirmed, provisional})`. `VoiceInputCompleted` gains a
closed outcome so `PromptInput` can tell a finished dictation from a cut-off one.

`VoiceInputCubit` takes whether live is allowed at construction: the composer's
scope allows it, the feedback sheet doesn't (D31).

| Event | Result |
| --- | --- |
| Failure before any audio is forwarded | Falls back to after-recording (D21) |
| Failure after audio was forwarded | Confirmed words go in the box with a notice, never sent (D20) |
| `complete{finished}` | Completed, follows the finish intent |
| `complete{session_limit, quota_limit}` | Completed as cut-off, goes to the box |
| No confirmed words at a failure | Error notice, nothing in the box |

The project glossary key is snapshotted exactly as today and sent as `projectKey`.

### Live words layer (step 9)

`PromptInput` shows a new `ComposerLiveWords` widget through an `OverlayPortal`, so
it never relayouts the chat or the composer. `IgnorePointer` keeps gestures on the
pill. It covers the nearest ancestor `Scaffold`'s rect, which is the chat pane on
wide layouts and the screen on phones; step 9 verifies that on both shells. Words
rebuild through `BlocSelector`. The glide takes its destination from the box field
or from the new bubble's rect.

## Analytics

Answers whether live and send on finish change voice adoption, per the
`add-analytics` checklist.

- `voice_transcription_completed` gains closed `mode` (`live`, `after_recording`)
  and `finish` (`sent`, `edited`, `cut_off`) parameters. Added with the behavior:
  `finish` in step 3, `mode` in step 8.
- No transcript, audio or identifiers.

## Security And Privacy

- The bearer token goes only in the upgrade header, only to the configured Sesori
  API host, and never into a URL or a log.
- No audio or transcript in logs or analytics. Diagnostic socket errors keep their
  codes and close reasons.
- PCM stays in memory: nothing is written to disk in live mode.
- The marker adds no data beyond what the user dictated.

## Complexity Budget

New mutable parts:

1. `PromptInput`: an edit-drag progress notifier, alongside the existing cancel one.
2. `VoiceModeRepository`: one cached value.
3. Live run: one socket, one PCM subscription, and one bounded pre-`ready` buffer
   that is empty after `ready`.
4. Cubit: `LiveWords`, immutable, replaced on each server event.

Deliberately not added: a capabilities call, dual file and stream capture, a local
recording in live mode, reconnection during a dictation, a countdown or undo, any
user setting, a transcript cache, a percentage rollout for desktop, any new wire
field to the bridge.

## Cleanup Assessment

Included in the feature PRs:

- `voiceReleaseToTranscribe` and `voiceClickToTranscribe` copy, once nothing shows it
- `PregoVoiceCancelButton`, generalized into a target taking an icon rather than
  keeping two near-identical widgets
- `docs/regression/voice-input.md`: “Text is inserted for review, never auto-sent”
  and the matching failure signal

Outside this repository, the auth server's `.plan/active/real-time-transcription`
still points to PR #918; step 11 updates that pointer.

No other relevant cleanup was found. `voiceSpans` and `ChatInputMode` stay in use.

## Proportionality And Accepted Risk

| Item | Evidence | Outcome |
| --- | --- | --- |
| Pre-`ready` buffer (D29) | Ordinary flow: people start speaking as soon as they press | One bounded buffer, sent as ordinary frames after `ready`, which the protocol allows. The auth plan's “no queue” design would clip first words. |
| Wrong words sent | Ordinary flow | Accepted by the user (D14): Stop remains available. |
| Thumb drifting up cancels | Plausible | Tune the distance on a device (D8). No extra confirmation. |
| Live start fails after the user started speaking | Rare | Accepted: the words said during the failed attempt are lost, and capture continues as after-recording. |
| Older bridge titles include the marker | Cosmetic | Accepted, no compatibility code. |
| Forgetting to turn live off before a public release | Real, with wide reach | A release check in step 11's result and in the user's release notes. |

## Regression Coverage

Affected documents: `voice-input.md`, `session-turns.md`,
`session-creation-and-options.md`, `desktop-cockpit-shell.md`. Step 10 confirms
the list; `feedback-flow.md` needs a check that its voice behavior is unchanged.

Highest level: **L3** for voice input.

| Boundary | Proof |
| --- | --- |
| Marker to the agent, on every harness | No per-plugin logic exists, so one real session through a real bridge proves the seam, plus title generation from plain words |
| Client to real `/voice/realtime` | Dev account, real server, recorded PCM fed through the transport, asserting confirmed and provisional handling and `complete` |
| Touch gestures and send on finish | Headless iOS simulator with fixture voice state, plus widget tests for every ending in both input modes |
| Desktop controls | macOS build, plus widget tests for click, click, Enter, Shift+Enter, Esc |
| Live feel with a real microphone | Real iPhone and Android device, run by the user, recorded |
| Desktop streaming | macOS with a real microphone. Linux and Windows: confirm streaming, or confirm the after-recording fallback, and record which |
| Fallback | Server unreachable before audio, connection dropped after audio |

Any reduction to this matrix needs the user's acceptance recorded here before
retirement.

## Delivery Rules

- Each PR's body has the sections `AGENTS.md` requires, with before and after visuals
  on `pr-media` for anything visible. Fixture data only.
- Steps 3, 4 and 9 must be judged by feel, ideally with a device recording.
- Lifecycle PRs stay well under the 1,500-line soft cap. Split cleanly if one grows.

## Steps

Fixed titles are in [TRACKER](TRACKER.md).

1. **Raise this plan.**
2. **Mic marker.** The shared pair, both cubit seams, the bridge title path, tests.
   Takes effect for every dictated message immediately.
3. **Touch gesture and send on finish.** Pencil target, slide-out cancel with the
   D8 look, new hints, `_VoiceFinish`, the X during “Transcribing…”, the `finish`
   analytics parameter. Covers both input modes and the new session screen, in
   after-recording, which is the only mode so far.
4. **Desktop controls.** Pencil and X, the merged wide Send that fixes the 44 px
   shift, Enter, Shift+Enter, Esc, send on finish.
5. **Voice mode switch.** Sources, API, repository, tests. Nothing reads it yet.
6. **Realtime transport.** Protocol, API, connectors, fixture, tests against the
   real server shape. No UI.
7. **Streaming capture.** PCM start on each platform, the support check,
   connect-time measurement on a device.
8. **Live session.** Service and cubit states, the buffer, fallback, terminal rules,
   the `mode` parameter. Live now works when enabled, with only the waveform on
   screen until step 9, then the words go through the finish intent.
9. **Live words layer.** Focus and panel, dim and brighten, the glide, both shells.
10. **Reconcile regression docs.**
11. **Run coverage and retire.** Run the matrix above, record the release check, update
    the auth plan's pointer, and move this plan to `.plan/completed/`.

## Plan Review Record

Pending.
