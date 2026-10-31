# Step 7 — Streaming capture

## Built

- `VoiceCaptureSession` gains `supportsPcmStream`, `startPcmStream` and `stopPcmStream`,
  plus `voiceCapturePcmSampleRate` for step 8 to announce. Capture is PCM16 little-endian
  mono at 16 kHz, in memory only.
- `FlutterVoiceCapture` implements them on `record`'s `startStream`. Effects, audio session
  config, wake lock, the activity lease and the amplitude stream match file recording.
- `PcmFrameBuilder` in `client/module_app_ui/.../platform/voice/`.
- `RealtimeVoiceSession` logs `[voice] realtime ready N ms after open` at info level, once
  per socket, so release builds show it too. The clock starts when `open` is called, so it
  includes the token refresh.
- The frame limits moved to `foundation/models/voice/voice_realtime.dart`, so the capture and
  the transport share one definition.

No consumer and no user-visible change. The file recording path behaves as before: it only
shares the extracted permission check, config builder and lease wrapper.

## Choices the plan left open

| Choice | Decision | Why |
| --- | --- | --- |
| Where realignment lives | In the capture, not `LiveDictationRun` | Every frame is valid when it leaves the capture, so D29's buffer holds ready frames and step 8 has no byte handling. A split sample is a platform detail |
| A last half sample | Dropped | It can't be sent. Earlier bytes are never dropped, because that would shift every later sample |
| What "supported" means | The host can attempt it: `record`'s encoder answer and, on Linux, `parecord --version` exits 0 | `isEncoderSupported(pcm16bits)` is hard-coded true on all five platforms. It says nothing about a device, so the doc comment says a yes is not proof |
| Windows and Linux, unproven | Report yes when the prerequisites exist | The plan's matrix wants step 12 to confirm streaming or the fallback, and a hard no would make streaming impossible to confirm. Internal builds only (D12, D28). Reporting no is a one-line change if step 12 finds them bad |
| A format the recorder changes | Fails the stream with `VoiceCaptureFailed` | Android picks stereo for an input that reports only stereo. Stereo sent as mono is noise, and send on finish would send the result unseen. File recording handles that input, so this is D21's fallback |
| A recorder that ends by itself | Fails the stream | `parecord` with no audio server starts, exits 1 and writes nothing, so a clean close would read as silence |
| Measurement | One log line, no harness | It runs wherever step 8 runs a live session, which is the real device the plan asks for |

## What each platform has actually done

| Platform | Evidence | Status |
| --- | --- | --- |
| iOS simulator, iOS 27.0 | Real `record_ios` native code with this step's config and the host microphone, three runs in a scratch app, not `FlutterVoiceCapture` | Ran. Chunks of 3,200 bytes every 100 ms, none odd or empty, about 32,000 B/s, non-silent peaks, amplitude values, no config change, first chunk 227–289 ms after the call. AAC to a file then worked on the same recorder (about 88 KB in 2 s) |
| Linux, `parecord` | Real `pacat 16.1` in Debian arm64 against a PulseAudio null sink, no microphone, with the plugin's exact arguments | Ran, not through the plugin. 3,200-byte chunks, none odd, 32,000 B/s. SIGTERM closes stdout. `--version` exits 0. With no server: exits 1, no bytes |
| Linux, plugin Dart | Real `AudioRecorder` and `RecordLinux` through `FlutterVoiceCapture` on macOS, with a stand-in `parecord` writing odd sizes | Ran. 12,814 bytes in order in even frames, amplitude values, clean stop. Stand-in exits at once: `VoiceCaptureFailed`. No `parecord` on the PATH: `startPcmStream` throws `VoiceCaptureFailed` holding the `ProcessException` |
| iPhone | Nothing | **Not run** |
| Android | Nothing. Read `sesori-ai/record` at 98dc1e1: `PCMReader` reads shorts, so chunks are even | **Not run** |
| macOS | Nothing. It would raise a microphone prompt on this Mac that nobody can answer | **Not run** |
| Windows | Nothing. Read `record_windows`: `PcmEncoder` passes samples through, and mono is never changed | **Not run** |

Odd chunks never came from real `parecord` in this run. A pipe doesn't promise whole samples,
so the frame builder still covers them, and the stand-in proves that path.

## Native config

No change needed, checked rather than assumed:

| Platform | Found |
| --- | --- |
| iOS | `NSMicrophoneUsageDescription` present. `UIBackgroundModes` has no `audio`, the same as file recording today |
| macOS, `app` and `desktop` | `device.audio-input` and `network.client` in Debug and Release entitlements, and `NSMicrophoneUsageDescription` |
| Android | `RECORD_AUDIO` and `INTERNET` |
| Windows | Nothing in the repo governs it. Whether the OS privacy setting behaves the same for streaming is unverified |
| Linux | No config, only tools on the PATH. Streaming needs `parecord`. The fallback also needs `ffmpeg`, so with `parecord` alone live can start while its fallback fails with the recording-failed notice |

## Connect-to-`ready`

A real `ready` needs an authenticated session, so **no real value exists yet**. No real token
was used.

The only real number here is a lower bound: `open` through the real connector with the made-up
token `not-a-real-token` was rejected with 401 in 518, 528, 538, 569, 632 and 960 ms, from this
Mac. That is the token step, TCP, TLS and HTTP only, and says nothing about a phone network or
the server's own time to `ready`.

PCM costs 32,000 bytes per second of buffer, so each second of wait holds 32 KB.

## For step 12

Checks only the user can run, all with a dev account and live on:

1. **Connect-to-`ready`, iPhone and Android.** About ten dictations each on Wi-Fi and on
   cellular, including the first after a cold launch. Read `[voice] realtime ready N ms after
   open` from the logs. That span includes the token read, because the buffer has to hold that wait too. Compare the worst value with step 8's buffer bound.
2. **Real microphone, iPhone, Android and macOS.** Words come out right, which proves the format
   end to end. The last word isn't clipped. Haptics still fire on iPhone. A second dictation works
   after a prewarm.
3. **Android with a stereo-only input,** such as a USB microphone, if one is at hand: it must
   fall back rather than produce noise.
4. **Linux.** A real microphone with `parecord`. No audio server. An AppImage build, which
   runs `parecord` from its own environment. The last word isn't clipped. Record whether streaming
   or the fallback is what works.
5. **Windows.** Confirm streaming with a real microphone. If it misbehaves without failing,
   make `supportsPcmStream` report no there and record it.

## For step 8

- `supportsPcmStream` is async and spawns a process on Linux. D26 says a hold never waits, so
  don't wait for it in the hold's path: load it beside the mode, and treat no answer yet as
  after-recording.
- Listen to `startPcmStream`'s stream at once. It is single-subscription and buffers without a
  bound until someone listens.
- Frames need no handling: buffer them and pass each to `sendAudio` unchanged. They can be views
  of larger buffers, which the loopback test covers.
- Pass `voiceCapturePcmSampleRate` to `openRealtime`.
- To finish, call `stopPcmStream`, then call `finish` when the stream is done, so the last frames
  go first. `finish` before `ready` still throws.
- A failure is one `VoiceCaptureFailed` on the stream, then done. The microphone may still be on,
  so call `cancel`. `cancel` then `start` on the same session is the fallback.
- A format change arrives just after `startPcmStream` returns, because Android posts it after the
  result. It is a stream error well before `ready`, so it counts as "before any audio is forwarded".
- `stopPcmStream` keeps the operation held. Call `releaseOperation` after the terminal event, as
  after-recording does after the upload.
- A cancel during `startPcmStream` is not handled here. Use the same generation check after the
  await that `start` has.
- Frames can stop with no error and no close. On iOS a converter failure stops the recorder
  without closing the event channel. No watchdog was added: the user sees a flat waveform and
  finishing still works.
- `record` cancels its stream when `stop` returns, so anything still unread is lost. Real
  `parecord` wrote nothing after SIGTERM, but with a null sink, so the checks are items 2 and 4 above.

## Found while building

- `record`'s stream is broadcast and drops chunks while nothing listens, which is why the capture
  listens straight after `startStream` returns.
- On the null sink, real `parecord`'s first chunk came after 2 s. The iOS simulator took under
  300 ms. This may be the idle null sink rather than `parecord`, so item 4 should watch for it.

## Verification

Toolchain: Flutter 3.47.8.

| Command | Result |
| --- | --- |
| `module_core`: `dart test` | +2556 passed |
| `module_app_ui`: `flutter test --no-pub` | +1077 passed |
| `dart analyze --fatal-infos` in `module_core`, `module_app_ui` | No issues |

`dart format -l 120` rewrote the unchanged `RecorderPrewarm` typedef, which was reverted.

Mutations, each failing a test: dropping the held byte; not splitting at the limit; stop not
expected; format not checked; `cancel` leaving PCM running; a recorder's own end not failing;
tool not checked; `parecord` exit code ignored; `start` allowed while streaming; wrong rate;
timing logged on every `ready`.

## Not checked

- `FlutterVoiceCapture` has not run on any device. Native code ran on the simulator through a
  scratch app, and the class ran only against mocks and the Linux Dart code on macOS.
- The simulator's audio is not a phone's: no real session routing, Bluetooth or interruption.
- No audio was transcribed, so nothing here proves the format beyond byte rate and peaks.
- No client or desktop build containing this change was made. No code outside the tests calls it.
