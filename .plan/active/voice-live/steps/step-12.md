# Step 12 — Run coverage

The agent's half of the matrix. The plan isn't retired: that waits for the user's half below.

One bug came out of it, fixed in its own commit.

## How it ran

- **Real server:** `wss://api.sesori.com/voice/realtime` and `/voice/transcribe` on dev account 1.
- **Real code:** `VoiceInputCubit`, service, `LiveDictationRun`, repository and `RealtimeVoiceClient`.
- **Fixture:** only the capture. Spoken clips from `say`, as 16 kHz mono PCM in 100 ms frames, at real
  pace. None are committed.
- **Two scratch setups, both removed:** a Dart harness in `module_core`, and the real app on a headless
  iPhone 17 simulator with a real bridge. The app's capture and Firebase source were swapped, and
  gestures were real pointer events.
- **Spend:** about two minutes of the 3,600 s daily quota, and a few short Haiku turns.

## Results

| Row | Result | Where |
| --- | --- | --- |
| Client to real `/voice/realtime` | Pass, after the bug below | Real server |
| Marker to the agent, title from plain words | Pass | Real server, real bridge, Claude Code |
| Fallback: unreachable before audio | Pass | Local closed port, then real `/voice/transcribe` |
| Fallback: dropped after audio | Pass | Real server, local socket killed |
| Fallback: limit with the finger down | Pass | Local loopback server |
| Touch gestures and send on finish | Pass, one feel question below | Real server, real bridge, simulator |
| Desktop controls | Widget tests pass. macOS build is the user's | Tests only |
| Live feel with a real microphone | Not run | The user's |
| Desktop streaming | Not run | The user's |

### Client to real `/voice/realtime`

- Four clips, 3 to 9 s, each went `ready`, `transcript`, `complete{finished}`, then
  `Completed outcome=finished mode=live`. Words were right, including the first ones, held about 1 s
  before `ready`.
- The last `transcript` has an empty `provisional`, and `Completed` equals the confirmed text. This settles
  step 8's unverified "confirmed-only at complete".
- About 6 events a second. The parser accepted every real frame.
- Cancel closed in 12 ms.
- Release at 200 ms, before `ready`: held frames flushed, finished, completed.
- Real errors seen:
  - `audio_timeout` (retryable), 5 s after `ready` with no frames: falls back to recording.
  - `invalid_audio` (not retryable), from the pace rule.
  - HTTP 401 with a made-up token: falls back to recording.
- Connect-to-`ready` **from this Mac, not a phone**: 1000 to 1139 ms over ten harness runs, and 975 to
  1182 ms in the simulator app.

### Bug: the held audio bound was above what the server accepts

The server allows 5 s of audio ahead of real time, counted from `ready`. Step 8 held up to 15 s. On a slow
start, the whole buffer went out at `ready`, and the server replied `invalid_audio` 400 ms later: failure,
all speech lost, no fallback.

Fixed in this step: the bound is now 4 s. Run against the real server with a delayed open:

| Open delay | Held | Before | After |
| --- | --- | --- | --- |
| 2.5 s | about 3.5 s | Not run | Complete |
| 3.5 s | about 4.6 s | Complete | Not run. Over the new bound, so by the code it falls back |
| 7 s | about 8 s | **`invalid_audio`, speech lost** | Falls back to recording at about 4.1 s |

4 s leaves a margin under the 5 s the server allows, at the cost of a start like the 3.5 s row, which used to
complete and now loses its first words to the fallback. Step 8's table and its list still say 15 s, as history. The worst connect-to-`ready` is now compared
with **4 s**.

A later change replaced this 4 s fallback: audio now waits up to about 30 s, and at `ready` up to 4 s go at once and the rest follows at real time.

### Marker and title

A new session held to talk, with Claude Code on Haiku 5.5, in the fixture project `voice12proj`.

- The harness's own transcript has `🎙️ "What does the purple lighthouse count before breakfast? ..."`.
  The bubble shows the same text.
- The generated title has no marker: "Purple Lighthouse Question".
- No per-plugin code exists, so one harness proves the seam as the plan says.

### Fallback

- **Unreachable before audio, local.** Closed port through the real `dart:io` connector. Connection refused,
  recording continues, real `/voice/transcribe` returns 200, `Completed outcome=interrupted
  mode=afterRecording` with the right words. D33 puts them in the box.
- **Dropped after audio, real server.** The raw TLS socket destroyed mid-stream:
  - Finger down, words shown: close 1006, `Completed interrupted` with the words so far, 10 ms later.
  - Just after release: `Completed interrupted`, 11 ms after release.
  - No words yet: `TranscriptionFailed`, network error.
  - A silent blackhole with no reset was **not** simulated.
- **Limit with the finger down, local.** The real server can't produce one cheaply: 900 s session, 3,600 s a
  day. A loopback server over the real connector sent `complete{quota_limit}` and `{session_limit}`. Both gave
  `Completed outcome=limitReached mode=live` while held, and the later pointer-up did nothing. Widget tests
  cover the notice.

### Touch gestures and send on finish

`prompt_input_touch_voice_test`, `prompt_input_pointer_voice_test`, `prompt_input_live_words_test` and
`composer_live_words_glide_test`: +125, all passing at this head. Existing evidence before this step was
widget tests (steps 3 and 4) and fake-cubit feel runs (steps 9 and 10). #2231 was step 10.ii itself, and #2232
only centred the hint.

New, in the real app with real words, judged from recordings. The focus rows predate the panel becoming the only view:

| Case | Decision | Seen |
| --- | --- | --- |
| Send, focus, new session | D7 | Words land in the launch bubble, marked |
| Send, focus, text in the box | D15, D17 | One message, marked whole, reaches the agent |
| Send, panel, text in the box | D15, D17 | Same, panel turns into the bubble |
| Send, panel, empty box | D7 | Marked, reaches the agent |
| Pencil, focus | D22 | Words stay in place, pencil fills, "Release to edit", box holds plain words, nothing sent |
| Pencil, panel | D22 | Same, in the card |
| Sending what the pencil put in the box | D17 | Marked, by the Send button |
| Slide up to cancel, text in the box | D24 | Pill and hint go red, words dim, box unchanged, nothing sent |
| Slide up to cancel, box open and empty | D24 | Same. Pencil is far left (D9) |
| Hold under 200 ms | D25 | No `ready` in the log, nothing sent |
| After recording, send on finish | D13 | Waveform, "Transcribing...", real `/voice/transcribe`, sent marked |

Slide up and back wasn't run in the app. Widget tests have it.

### Desktop controls

Widget tests only (`prompt_input_pointer_voice_test`, in the +125). The macOS build row is in the list below.

## Findings

Nothing here has been seen by the user yet, and none is decided.

1. **A hold just over 200 ms can send a guess.** Two frames of "Mar..." came back as "Wow." With send on
   finish, that goes out unseen. A release mid-sentence does the same at any length: a clip saying "wooden spoons",
   released early, came back as "wooden sticks". D25's minimum only filters by time. A design choice for the user.
2. **Words stay dim for a long time on the real server.** On an 8.8 s clip, the first confirmed words came
   about 5.4 s after the first words. Short dictations stay entirely dim until release. This bears on D2, and
   is on the list below.
3. **The list bounces after a send with text in the box.** Recordings, sampled at 10 frames a second, on a
   debug build, so sizes are rough. Panel send: up about 90 pt as the row enters, down about 50 pt within
   100 ms as the box collapses, up about 80 pt within 100 ms as "Working..." appears, then down about 30 pt. A
   plain tap on Send shows the same down and up, about 40 pt each, so this isn't voice's. It still breaks the
   "content must not jump" rule. Not fixed: it's in the session list and composer, not small, and needs a look
   on a device.
4. **Step 8's iOS silent frames note is incomplete.** It says this ends in the empty-transcript error. The
   real server sends `audio_timeout` after 5 s with no frames, so a dictation that has stopped producing frames
   ends as a cut-off or failure. From the server's code and the `audio_timeout` run, not from a real converter
   failure.
5. **OpenCode turn failed with 401 in the first try at row 2.** OpenCode with GPT-5.6 Sol Fast on this Mac:
   "OpenCode turn failed, Request failed: 401". The marker bubble and title were fine. It looks like that
   harness's own credentials here, not voice. Not investigated. Nor was a bridge log line from the same run,
   `[V2MessageMapper] OpenCode v2 transcript contains an unsupported message variant; omitting that message`.
6. **The phone app can't export logs.** `IoAppLogSink` writes to `<temp dir>/logs/app.log` and nothing in
   the UI shares it, which makes the connect-to-`ready` check below harder than it needs to be.
7. **The hint's cross-fade overlaps for a moment.** "Release to send..." and "Release to edit" overlap for
   about a frame. On the list below at real speed.

## Not checked

- No real microphone. `FlutterVoiceCapture` still hasn't run live on any device.
- No real device, no Android, no desktop build. A debug simulator can't judge smoothness.
- A real quota or session limit, and a silent network blackhole.
- A phone's connect-to-`ready`.
- Any harness other than Claude Code to completion. OpenCode's turn failed as above.

## For the user

Run in this order. All with a dev account. Platform-only items are marked.

### 1. Setup

- **Firebase Remote Config:** `voice_live_enabled=true`. It applies at each phone's next cold launch.
- **Desktop:** build with `--dart-define=SESORI_DESKTOP_RELEASE_CHANNEL=internal`. Source builds default to
  `stable`, which is after-recording.

### 2. Real microphone (iPhone and Android)

Dictate a few sentences, twice.

Fails if:

- Words are wrong or noise. This is the first proof of the audio format end to end.
- The last word is clipped.
- The second dictation, after the prewarm, doesn't work.
- *iPhone only:* haptics don't fire.

Also judge how long words stay dim, finding 2. It fails if a short dictation feels unconfirmed all the way through.

### 3. Connect-to-`ready` (iPhone and Android)

About ten dictations each on Wi-Fi and cellular, including the first after a cold launch.

- Read `[voice] realtime ready N ms after open`. It's info level, also in release builds, and includes the
  token read.
- Sources: `flutter run` or `flutter logs`, `adb logcat`, the Xcode device console, or `<temp dir>/logs/app.log`
  on the phone (no export in the app).
- Over 4 s, the speech is kept unless the socket or microphone fails during the backlog: the words lag by the
  difference, and a release waits that long under Finishing. With the finger still down, about 30 s without `ready`
  falls back to recording and drops what was held. After a release there is no client deadline for `ready`, only the X.
  This Mac saw about 1 s, which says nothing about a phone.
- Fails if the wait after a release is unbearable, or the lag in the words feels wrong, at the worst value seen.

### 4. Feel (iPhone and Android)

| Do | Fails if |
| --- | --- |
| Dictate a long message | The wrap jumps, or a real server's rate feels restless |
| Send and edit at real speed | A visible pop at the handover, or line ends that stay clipped after the rewrap |
| Slide to the pencil and to cancel, slowly | The wash jumps at its 12 px detent, the snap on cancel feels abrupt, or the hint's cross-fade reads as a glitch |
| Dictate for several minutes | It slows down |

### 5. Real session (iPhone and Android)

| Do | Fails if |
| --- | --- |
| Send from a long transcript, at its end | The list's rise jumps. Include text in the box, finding 3 |
| Send while scrolled away | The fallback glide looks wrong, or the position is lost |
| Send from a new session, and follow it through the launch view | The words vanish or pop before the session opens |

### 6. Network (either phone)

Kill the network mid-dictation, once held and once just after release.

Fails if the words don't land in the box, anything is sent, or the wait is unbearable. It can reach about 30 s,
and the X must stop it.

### 7. Quota limit (either phone, only with a real quota)

Reach the limit with the finger down. Fails if there's no "Dictation limit reached" notice, or the words are lost.

### 8. Android only

If a stereo-only USB microphone is at hand: it must fall back, not produce noise.

### 9. macOS build

- Real microphone: click, click, Enter, Shift+Enter, Esc all work, with words right and the last word kept.
- Fails if text input gets a newline from any of these.
- Merge feel, and tooltips over the moving Send.
- The panel against a real transcript, and in a window wider than the transcript.
- Send and edit in the pointer shell. Fails if it pops at the landing.

### 10. Linux only

- Real microphone with `parecord`, with no audio server, and as an AppImage.
- Fails if the last word is clipped or the first chunk is long delayed.
- `parecord` with no `ffmpeg` should show "Transcription failed. Record again or type instead."
- Record whether streaming or the fallback is what works.

### 11. Windows only

Confirm streaming with a real microphone. If it misbehaves without failing, make `supportsPcmStream` report no
there and record it.

### 12. Release check

Before the first public release containing this code, set `voice_live_enabled=false` in Firebase. It applies at
each phone's next cold launch. Desktop `stable` stays after-recording by build.

### 13. Decisions

- Finding 1: whether a very short hold or a mid-word release should still send on finish.
- Finding 3: whether the list's bounce after a send gets its own fix.
- Accept, or not, any part of the matrix you won't run. The plan requires that recorded before retirement.
- Then retirement: update the auth plan's pointer and move this plan to `.plan/completed/`. Not done here.
