# Live Voice, Send On Finish, And The Mic Marker

## Status

Agreed through review pages `voice-live-r1` and `voice-live-r2` (2026-10-30). Implemented and retired on 2026-10-31.
See the [tracker's final disposition](TRACKER.md#final-disposition).

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
  owns the gestures through a private sealed `_voiceInteraction` and appends the
  finished transcript to the draft with `appendVoiceTranscript`.
- Touch: hold to record, release to transcribe, drag onto a left X
  (`PregoVoiceCancelButton`) to cancel.
- Pointer: click the mic to start, click it again to transcribe, Esc cancels, the
  left X discards. **Clicking the mic slides it 44 px right** (measured
  660–704 → 704–748 at 760 px wide), so a second click in the same spot misses.
- `ComposerDraft.voiceSpans` produces `ComposerInputMode.voiceAssisted`, which is
  used for analytics only and never reaches the bridge.
- The first new-session message reaches the bridge from the submission snapshot
  (`session_launch_service.dart:133`), and follow-ups from `QueuedTextSubmission`
  (`:192`, `session_detail_cubit.dart:2518`). `displayText` currently serves as
  bubble text, restore text (`withFollowUps`) and pending title
  (`session_launch_repository.dart:88`).
- `VoiceInputCubit` is created in five places: `home_composer_pane`,
  `new_session_screen` and `session_detail_composer_controls` in `client/app`,
  `desktop_composer_presentation_scope` in `client/desktop`, and
  `feedback_voice_input_scope` for the feedback sheet.
- `FirebaseRemoteConfigClient` exists in `client/app` behind
  `@firebaseEnabledEnvironment`, and fetches once per launch. **`client/desktop` has
  no Firebase dependency**, and uses no-op config sources.
- Production `GET https://api.sesori.com/voice/capabilities` reports realtime
  enabled, protocol 1.
- PR #918 (phone-only live voice, closed unmerged on 2026-08-28) is reference
  material at `refs/pull/918/head`.

## Decisions

All are the user's, from the review pages, except where marked as a planning
decision.

Superseded 2026-10-31: the panel is the only live view on phone and desktop. Where this plan specifies focus, its dim and
text, or `voice_live_presentation` (D1, D12, D27, D28 and the sections below), that part no longer applies.

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
| D22 | The box always holds plain words. Titles use plain words. Slash commands are never marked, including a dictated argument to a selected command, which stays typed as `session_detail_composer_controls.dart:44` already reports it. |
| D23 | While “Transcribing…” shows, an X stops it. |
| D24 | Cancelling keeps what was already in the box. |
| D25 | No words, or a hold under today's 200 ms minimum, sends nothing. |
| D26 | A hold never waits on the switch. With no value yet, it uses after-recording. |
| D27 | Desktop's focus view covers the chat pane only, with the words in a reading-width column. |
| D28 | Planning decision: desktop values come from `DesktopReleaseChannel`: `internal` gets live with focus, `stable` gets after-recording. This is D12 applied to D11. Source builds default to `stable`, so testing live locally needs the define set. |
| D29 | Planning decision: audio captured before the server's `ready` is held in memory, up to about 30 s, so the first words aren't lost. At `ready` at most 4 s go at once, under the server's 5 s, and the rest follows at real time. Review page r4 Q6 chose keeping it all at the allowed pace, with a limit around 30 s; the 4 s burst is an implementation choice. See Proportionality. |
| D30 | Planning decision: the client doesn't call `/voice/capabilities`. Remote config decides, and a disabled server fails the upgrade with 404, which is D21's fallback. |
| D31 | Planning decision: live and send on finish apply to the composer only. The feedback sheet keeps after-recording and keeps its words in its field. |
| D32 | Planning decision: a retried after-recording dictation lands in the box rather than sending, following D20. The attempt failed and the user has moved on, so a late send would surprise them. |
| D33 | Planning decision: a dictation that fell back from live lands in the box with a notice rather than sending, following D20. Its first words may be missing, and sending a clipped prompt unseen is the damage this rule exists to prevent. |

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
| Focus dim | Solid background, over 260 ms (`voice-live-r3`, changed from 0.98) |
| Focus text | 23 pt on phone, 25 pt on desktop, medium weight |
| Panel | Grows upward to about five lines, then older lines fade at the top |
| Glide to bubble or box | 340 ms, `cubic-bezier(.2, .8, .2, 1)` |
| Cancel exit | 240 ms fade with a 12 px drop |

## Architecture

### Marker (step 2)

`sesori_shared` owns one pure pair, `wrapDictatedText` and `unwrapDictatedText`, so
the client and the bridge can't disagree on the format.

Stored text stays plain. `QueuedTextSubmission` and
`NewSessionTextSubmissionSnapshot` each gain one derived `outgoingText`, which wraps
when `inputMode` is `voiceAssisted`:

- `session_detail_cubit.dart:2518` and `session_launch_service.dart:133` and `:192`
  send `outgoingText`.
- `displayText` shows the marked form (D18).
- `withFollowUps` and the pending launch title read plain text through a new
  `plainText` getter (D22), because a refused submission restores into the box.

`SessionCreationService._generateAndApplyMetadata` unwraps `firstText` before
generating metadata.

There is no wire-contract change. An older bridge would generate a title from the
marked text, which is cosmetic and accepted.

### Finish intent (steps 3–4)

`PromptInput` captures one closed `_VoiceFinish { send, edit }` value when the
gesture ends, carried inside the `_VoiceTranscribing` variant rather than in a
separate field. `_retrySavedRecording` builds it with `edit` (D32).

`VoiceInputCompleted` gains `outcome`, a closed `VoiceDictationOutcome` in
`foundation/models/voice/`: `finished` and `limitReached` from step 3, and
`interrupted` from step 8. The cubit already knows `limitReached`. Step 8 also adds
`mode`, the closed `live` or `after_recording` the dictation actually ran as, so a
fallback reports `after_recording`. The feedback sheet ignores both.

On completion the transcript is appended exactly as today. It sends **only when
the finish is `send` and the outcome is `finished`**, by calling the existing
`_submitComposer`, so attachments, command, `canSend` and busy-queue rules stay in
one place. If `canSend` refuses, the words stay in the box. Any other outcome
shows its notice, once.

`_handleCompletedTranscription` must also accept a completion while the presentation
is `_VoiceRecording`, because live can end while the finger is still down. Today it
returns early and the words would be lost. The presentation goes idle, and the
later pointer-up is a no-op because it only acts on `_VoiceRecording`.

### Remote config (step 5)

Follows the existing `FeedbackPromptConfigSource` shape:

- `VoiceModeConfigSource` in `foundation/platform` returns raw values:
  `({bool liveEnabled, String? presentation})`. Keys live only in the Firebase
  source, which maps `""` to null.
- `FirebaseVoiceModeConfigSource` and a no-op source in `client/app`.
- `ChannelVoiceModeConfigSource` in `client/desktop`, returning `(true, null)` for
  `internal` and `(false, null)` for `stable`.
- `VoiceModeConfigApi` and `VoiceModeRepository` in `module_core`. The repository
  parses to `VoiceMode`, sealed in `foundation/models/voice/`
  (`VoiceModeAfterRecording`, `VoiceModeLive({presentation})`, with
  `VoiceLivePresentation { focus, panel }`), and caches the last value. It reports
  after-recording until one exists (D26).

Parameter keys: `voice_live_enabled` (unset reads as false) and
`voice_live_presentation` (`panel` gives panel; anything else gives focus).

The value is fetched once per launch, so **switching live off applies at each
phone's next cold launch**. This is why the release action in the tracker has to
happen before the release goes out.

### Transport (step 6)

No platform interface and no shell code: `web_socket_channel` and `dart:io` are
already used directly in `module_core` (`capabilities/relay/relay_client.dart`).

- `capabilities/voice/realtime_voice_client.dart`: one `RealtimeVoiceClient`, with
  the injected connector test seam `RelayClient` already has. Re-check and port from
  #918's `realtime_voice_api.dart`, dropping its `RealtimeWebSocketConnector` and
  both shell connectors.
- `capabilities/voice/realtime_voice_protocol.dart`: wire models, checked against
  the server's `tests/fixtures/voice-realtime-protocol-v1.json`, with the fixture
  copied to tests.
- `VoiceRepository.openRealtime`: the only way in. It maps protocol errors and
  closes to the existing `VoiceTranscriptionError` types, keeping the cause.
- Value models in `foundation/models/voice/`. #918's `models/voice_realtime.dart`
  path no longer exists.

Do not port #918's interaction code.

### Streaming capture (step 7)

`VoiceCaptureSession` gains a PCM16 mono 16 kHz stream start using `record`'s
`startStream`, and reports whether the platform supports it. A platform that can't
stream uses after-recording. Wake lock, audio session and the amplitude stream
carry over. This step logs connect-to-`ready` time, because D29's buffer depends on
it. A real value needs an authenticated session, so step 12 reads it on a real device.

### Live session (step 8)

`VoiceTranscriptionService` injects `VoiceModeRepository`. `createSession` takes
`allowLive`, which the feedback scope sets to false (D31), and starts the mode load
beside `_refreshProjectGlossaryKey`. `start` reads the value synchronously and
snapshots it for that dictation.

`services/live_dictation_run.dart` holds one per-dictation `LiveDictationRun`, which
owns the socket, the PCM subscription and the pre-`ready` buffer. A new
`_VoiceSessionState` variant holds it as a non-null field. `_cancel`, `invalidate`
and `close` all tear it down, sending `cancel` first when the socket is open.

Contract between service and cubit:

- `start` still returns as soon as capture begins.
- A new `liveEventStream` delivers a sealed `VoiceLiveEvent`:
  `VoiceLiveWordsChanged({words})`, `VoiceLiveFellBack()`,
  `VoiceLiveEnded({transcript, outcome})`.
- `stopAndTranscribe` returns `VoiceDictationResult({transcript, outcome, mode})` in
  both modes.

`VoiceInputCubit` gains immutable states carrying a non-null `presentation`:

- `VoiceInputLiveRecording({words, presentation})`
- `VoiceInputLiveFinishing({words, presentation})`

`words` is `LiveWords({confirmed, provisional})`. The cubit's stop guard and
max-duration listener, which accept only `VoiceInputRecording` today, also accept
`VoiceInputLiveRecording`. `feedback_private_step.dart`'s exhaustive switches must
list both states, although D31 makes them unreachable there.

| Event | Result |
| --- | --- |
| Failure before any audio is forwarded | `VoiceLiveFellBack`, continues as after-recording (D21). Its outcome is `interrupted`, so it lands in the box (D33) |
| Failure after audio was forwarded, with any words on screen, confirmed or provisional | `Completed(interrupted)`, all of those words go in the box with a notice, never sent (D20) |
| Failure after audio was forwarded, no words at all | Error notice, nothing in the box |
| `complete{finished}` | `Completed(finished)`, follows the finish intent |
| `complete{session_limit, quota_limit}` | `Completed(limitReached)`, goes to the box, even with the finger still down |

The project glossary key is snapshotted exactly as today and sent as `projectKey`.

### Live words layer (step 9)

`PromptInput` shows a new `ComposerLiveWords` widget through
`OverlayPortal.overlayChildLayoutBuilder`, as `background_tasks_bar.dart:55` does,
so it never relayouts the chat or the composer.

Its rect runs **from the top of the nearest `Scaffold` to the composer's top**,
measured from `_composerBodyKey`. An unbounded overlay would paint above the pill
and hide the waveform and the wide Send. That rect is the chat pane on wide
layouts. `IgnorePointer` keeps gestures on the pill, and words rebuild through
`BlocSelector`.

Without the glide, a sent dictation's words fade out as its bubble appears, and an
edited dictation's words fade out as they appear in the box.

### Glide (step 10)

A clean split from step 9, since this is the only part that crosses from the
composer into the message lists.

The box's rect comes from `PromptInput` itself. For the bubble, a small screen-owned
`SentBubbleLanding` sits above both the composer and the message list, in session
detail and new session:

1. `PromptInput` calls `expect()` just before `_submitComposer`. It can't know the
   prompt id, which the cubit generates.
2. The list reports the rect of the first new user row it builds while expecting.
3. The layer retargets its glide to that rect, then hands over to the real bubble.

If no rect arrives within two frames, the words glide to the estimated slot,
right-aligned just above the composer, and fade. If the owner unmounts mid-glide,
which new session's launch view can do, the layer just goes: the launch view
is already showing the same words.

## Analytics

Answers whether live and send on finish change voice adoption, per the
`add-analytics` checklist.

- `voice_transcription_completed` gains closed `mode` (`live`, `after_recording`)
  and `finish` (`sent`, `edited`, `cut_off`) parameters. Added with the behavior:
  `finish` in step 3, `mode` in step 8.
- `_submitComposer` returns whether it sent, because today it refuses silently.
  `PromptInput` reports after that decision, through a callback that replaces
  `onVoiceTranscriptionCompleted` and carries both closed values. `mode` comes from
  `VoiceInputCompleted`. Both cubits' report methods change with it.
- No transcript, audio or identifiers.

## Security And Privacy

- The bearer token goes only in the upgrade header, only to the configured Sesori
  API host, and never into a URL or a log.
- No audio or transcript in logs or analytics. Diagnostic socket errors keep their
  codes and close reasons, and wrapped errors keep their cause.
- PCM stays in memory: nothing is written to disk in live mode.
- The marker adds no data beyond what the user dictated.

## Complexity Budget

New mutable parts:

1. `PromptInput`: an edit-drag progress notifier, alongside the existing cancel one.
2. `VoiceModeRepository`: one cached value.
3. `LiveDictationRun`: one socket, one PCM subscription, and one bounded pre-`ready`
   buffer that is empty after `ready`.
4. Cubit: `LiveWords`, immutable, replaced on each server event.
5. `SentBubbleLanding`: one expected-landing value per screen.

Deliberately not added: a capabilities call, a platform connector interface, dual
file and stream capture, a local recording in live mode, reconnection during a
dictation, a countdown or undo, any user setting, a transcript cache, a percentage
rollout for desktop, any new wire field to the bridge.

## Cleanup Assessment

Included in the feature PRs:

- `voiceReleaseToTranscribe` and `voiceClickToTranscribe` copy, once nothing shows it
- `PregoVoiceCancelButton`, generalized into a target taking an icon rather than
  keeping two near-identical widgets. `feedback_private_step.dart` uses it too.
- `docs/regression/voice-input.md`: “Text is inserted for review, never auto-sent”
  and the matching failure signal

Outside this repository, the auth server's `.plan/active/real-time-transcription`
still points to PR #918; the final step updates that pointer.

No other relevant cleanup was found. `voiceSpans` and `ChatInputMode` stay in use.

## Proportionality And Accepted Risk

| Item | Evidence | Outcome |
| --- | --- | --- |
| Pre-`ready` buffer (D29) | Ordinary flow: people start speaking as soon as they press | One bounded buffer, sent as ordinary frames after `ready` at the pace the server allows. The words lag by what is held beyond the 4 s burst, at worst about 26 s, and a release waits that long under Finishing. Accepted because it only follows a very slow start, the alternative loses the first words, and the X still stops it. The auth plan's “no queue” design would clip first words. |
| Wrong words sent | Ordinary flow | Accepted by the user (D14): Stop remains available. |
| Thumb drifting up cancels | Plausible | Tune the distance on a device (D8). No extra confirmation. |
| Live start fails after the user started speaking | Rare | Accepted: the words said during the failed attempt are lost, and capture continues as after-recording. D33 puts the result in the box with a notice, so a clipped prompt is never sent unseen. |
| Older bridge titles include the marker | Cosmetic | Accepted, no compatibility code. |
| Glide on new session may end early | Launch view replaces the composer | Accepted: the launch view already shows the words. Judge on a device. |
| Forgetting to turn live off before a public release | Real, with wide reach | A release check in the final step's result and in the user's release notes. |

## Regression Coverage

Affected documents: `voice-input.md`, `session-turns.md`,
`session-creation-and-options.md`, `desktop-cockpit-shell.md`. Step 11 confirms
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
| Fallback | Server unreachable before audio, connection dropped after audio, server limit with the finger still down |

Any reduction to this matrix needs the user's acceptance recorded here before
retirement.

## Delivery Rules

- Each PR's body has the sections `AGENTS.md` requires, with before and after visuals
  on `pr-media` for anything visible. Fixture data only.
- Steps 3, 4, 9 and 10 must be judged by feel, ideally with a device recording.
- Lifecycle PRs stay well under the 1,500-line soft cap. Split cleanly if one grows.

## Steps

Fixed titles are in [TRACKER](TRACKER.md).

1. **Raise this plan.**
2. **Mic marker.** The shared pair, `outgoingText` and `plainText`, the bridge title
   path, tests. Takes effect for every dictated message immediately.
3. **Touch gesture and send on finish.** Pencil target, slide-out cancel with the
   D8 look, new hints, `_VoiceFinish`, `VoiceDictationOutcome`, the X during
   “Transcribing…”, the `finish` analytics parameter. Covers both input modes and
   the new session screen, in after-recording, which is the only mode so far.
4. **Desktop controls.** Pencil and X, the merged wide Send that fixes the 44 px
   shift, Enter, Shift+Enter, Esc, send on finish.
5. **Voice mode switch.** Sources, API, repository, tests. Nothing reads it yet.
6. **Realtime transport.** Client, protocol, repository method, fixture, tests
   against the real server shape. No UI.
7. **Streaming capture.** PCM start on each platform, the support check, the
   connect-time log.
8. **Live session.** `LiveDictationRun`, the service contract, cubit states, the
   buffer, fallback, terminal rules, the `mode` parameter. Live works when enabled,
   with only the waveform on screen until step 9.
9. **Live words layer.** Focus and panel, dim and brighten, both shells, fading out
   at the end.
10. **Glide.** `SentBubbleLanding`, the box and bubble destinations, the fallback.
11. **Reconcile regression docs.**
12. **Run coverage and retire.** Run the matrix above, record the release check,
    update the auth plan's pointer, and move this plan to `.plan/completed/`.

## Plan Review Record

`architecture-plan-review` ran once, by an Opus sub-agent, and **rejected** the first
draft with 12 findings, five of them contradicting the code. It did not re-open
D1–D27. All 12 were accepted and applied:

1. Marker seams missed the first new-session message and leaked into the box.
2. The realtime path had no repository.
3. The platform connector had no platform reason to exist.
4. Nothing named who reads the mode, and the presentation never reached the UI.
5. Config parsing and model placement were ambiguous.
6. The live run had no owner and no service contract.
7. An ending while the finger is down lost the words.
8. Retry had no finish intent, now D32.
9. An unbounded overlay would have hidden the pill.
10. The glide to a bubble had no seam, now its own step.
11. The `finish` analytics value had no authoritative source.
12. The feedback sheet's switches and a stale model path were missed.

Per the review rules, the fixes were not re-reviewed. `SentBubbleLanding` is this
plan's own answer to finding 10 and has not had a plan review, so step 10's
implementation review should look at it. The review didn't check the server fixture,
the production capabilities endpoint or the 44 px measurement.
