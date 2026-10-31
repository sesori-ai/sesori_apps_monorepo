# Step 8 — Live session

Two commits, 8.i and 8.ii, because the step came to about 2,300 authored lines against the
1,500 soft cap. This doc covers both.

## Built

**8.i, the service can run live, and nothing asks it to yet.** Every `createSession` caller
passes `allowLive: false`, so nothing changes for a user.

- `services/live_dictation_run.dart`: one dictation's socket, frames, and the audio that waits
  for `ready`. It ends in a closed `LiveDictationEnding`.
- `VoiceTranscriptionService`: injects `VoiceModeRepository`, takes `allowLive`, snapshots the
  mode in `start`, gains `liveEventStream` and `livePresentation`, and returns
  `VoiceDictationResult` from `stopAndTranscribe`. `_cancel`, `invalidate` and `close` tear the
  run down.
- `foundation/models/voice/voice_live.dart`, `VoiceDictationOutcome.interrupted`,
  `VoiceDictationMode`, `VoiceDictationResult`.

**8.ii, the composer uses it.** The four composer scopes pass `allowLive: true`; the feedback
sheet stays false (D31).

- `VoiceInputLiveRecording`, `VoiceInputLiveFinishing`, `mode` on `VoiceInputCompleted`.
- `PromptInput`: the cut-off and limit notices, a "Finishing..." label, `interrupted` lands in
  the box.
- `mode` on `voice_transcription_completed`.

With live on, a dictation runs over the socket with only the waveform on screen until step 9.

## Choices the plan left open

| Choice | Decision | Why |
| --- | --- | --- |
| How the cubit learns the mode | `start` stays `Future<void>`, and the cubit reads `livePresentation` after it | A `startPcmStream` that fails has already fallen back when `start` returns, and this reports that with no event |
| Event delivery | Synchronous broadcast | A release can then never overtake an ending that already happened |
| Loading the mode and support | In sequence, and support only when the mode is live | The support check spawns `parecord --version` on Linux. Stable users never pay for it |
| When the socket opens | After `startPcmStream` succeeds | A denied permission opens no socket |
| Buffer bound | 15 s, 480,000 bytes, then a failure | Falling back loses less speech than waiting on a socket this slow. Step 12 compares it with the measured connect-to-`ready` |
| `startPcmStream` failing | Fallback with `interrupted`, the same as any other | A denied permission goes up as itself |
| Failure after a release, no audio forwarded | Error notice, nothing in the box, held audio dropped | The table's fallback row can't apply: the microphone is off |
| `complete` transcript | Confirmed words only | The server finalizes before `complete`, and #918 read the same field. A failure keeps confirmed and provisional, per the table |
| Blank `complete{finished}` | `emptyTranscript` error notice | Same as after-recording and #918 |
| Blank limit | Limit notice only | There is nothing to report as an error |
| Releasing the microphone | Always `capture.cancel()`, not `releaseOperation` | It covers both a stopped and a running recorder and always releases |
| A release during the fallback's restart | `stopAndTranscribe` waits for the restart | The recording it caught is still worth having |
| Limit notice copy | New "Dictation limit reached", shown at completion | "Recording limit reached (15 minutes)" is wrong for a quota limit |
| The "Finishing..." label | Added here | Live has no transcription to name, and step 9 can still replace it |

## Where the plan needed more

- **A fourth event.** The plan lists three. A failure with the finger down and no words needs
  to show at once, so `VoiceLiveFailed` joined them.
- **The first row of the terminal table assumes the finger is down.** See the table above.
- **The fallback's own failure** isn't in the table. If the recorder can't restart, the dictation
  ends with `VoiceLiveFailed(recordingFailed)`.

## Step 7's stop failure

The step 7 review changed `stopPcmStream`'s failure: the capture stays streaming and the stream
stays open. `LiveDictationRun._stopMic` now calls `cancel` on that failure, which closes the
stream, so the audio already sent still finishes. The test uses a mock capture for this:
`stopPcmStream` throws and only `cancel` closes the frames. Nothing here has run against the real
capture.

## Known limits, accepted

- **Linux with `parecord` and no `ffmpeg`.** Live starts. Failure before any audio leaves: the
  fallback can't start, so `VoiceLiveFailed(recordingFailed)` shows "Transcription failed. Record
  again or type instead.", not the recording-failed notice step 7 predicted. Failure after audio
  left, and every normal dictation, behave as on any host. No machinery added.
- **No client deadline for `ready` after a release.** On a dead network "Finishing..." stays until
  the upgrade timeout or ping gives up, up to about 30 s. The X stops it.
- **A held dictation with no terminal event** waits the same way, up to the buffer bound.
- **A retried fallback recording** lands in the box with no cut-off notice, because `retry`
  returns a plain transcript.
- **A fallback that also hits the 15-minute limit** can show both notices.
- **iOS silent frames.** Step 7's converter failure stops frames with no close, and no watchdog was
  added. The waveform goes flat and finishing still works, ending in the empty-transcript error.

## Verification

Toolchain: Flutter 3.47.8. Measured at the tip of the series, rebased on `main` with step 7 merged.

| Command | Result |
| --- | --- |
| `module_core`: `dart test` | +2614 passed |
| `module_app_ui`: `flutter test --no-pub` | +1090 passed |
| `app`: `flutter test --no-pub` | +859 passed |
| `desktop`: `flutter test --no-pub` | +382 passed |
| `dart analyze --fatal-infos` in all four | No issues |

The mutations ran on the full tree, not on 8.i.

The live tests run the real `RealtimeVoiceSession` and repository over a fake channel, with a
mock capture.

`dart format -l 120` rewrote every enum closer in `product_analytics_event.dart` and one `Focus`
line in `prompt_input.dart`, all reverted.

Mutations, each failing a test:

- **Service:** mode read regardless of what has loaded; `allowLive` ignored; support asked when
  the mode isn't live; load failure uncaught; denied permission falling back; no generation check
  after `startPcmStream`; fallback outcome `finished`; `startPcmStream` fallback unflagged; release
  not waiting for the restart; cancel or close skipping the run; failed restart silent; no
  generation check after the finish; limit timer ignoring live; fallback ignored while held.
- **Run:** no flush at `ready`; no finish after a quick release; no finish when the frames end;
  cut-off as `finished`; failure keeping only confirmed words; `complete` keeping provisional
  words; fallback after audio left; blank finish completing; blank limit erroring; stop failure
  not cancelling; buffer never overflowing, or at exactly the bound; late socket left open; ending
  with the socket or microphone left open; wrong rate; no project key; provisional appended.
- **Cubit:** retry offered at a live finish; limit overriding `interrupted`; `mode` dropped; fallback
  ignored while finishing; words dropped while finishing; late `VoiceLiveEnded` or `VoiceLiveFailed`
  unguarded.
- **Composer:** sending whatever the outcome; no cut-off notice; no live limit notice; limit notice
  also after recording. **Scope:** feedback sheet allowing live.

Two survived at first. One was a missing test, the generation check after the finish, which
now has one. The other was dead code, `_micStop == null` when choosing a fallback, which was
removed: after a release the service treats a fallback and a failure the same.

## Not checked

- **No live session has run on any device or against the real server.** No real token was used.
- **Feel was not checked.** Only the waveform shows for now, and the live words arrive in step 9.
- `LiveDictationRun` has run only against a mocked capture, not `FlutterVoiceCapture`.
- No client or desktop build containing this change was made.
- The `allowLive: true` wiring at the four composer sites has no test. Only the feedback sheet's
  `false` does.
- Whether words are confirmed-only at a real `complete` rests on reading #918 and the fixture.

## For step 12

Add to the list in `step-07.md`:

1. Compare the worst connect-to-`ready` with the 15 s bound.
2. Linux with `parecord` and no `ffmpeg`: confirm the behaviour above.
3. Kill the network mid-dictation, held and released: words land in the box, nothing is sent, and
   the wait after a release is bearable.
4. Hit the quota limit with the finger down.
