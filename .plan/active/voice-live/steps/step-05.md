# Step 5 — Voice mode switch

## Built

- `VoiceModeConfigSource` returns raw `({bool liveEnabled, String? presentation})`.
- Phone: `FirebaseVoiceModeConfigSource` (`voice_live_enabled`,
  `voice_live_presentation`, `""` becomes null) and a no-op for builds without
  Firebase.
- Desktop: `ChannelVoiceModeConfigSource`: `internal` gives `(true, null)`, `stable`
  gives `(false, null)` (D28).
- `VoiceModeConfigApi`, and `VoiceModeRepository` with a synchronous `mode` and a
  `load()` that step 8 starts. `mode` is after-recording until a load finishes (D26).
- `VoiceMode` is sealed: `VoiceModeAfterRecording`, `VoiceModeLive({presentation})`,
  with `VoiceLivePresentation { focus, panel }`.

## Values

| `liveEnabled` | `presentation` | `mode` |
| --- | --- | --- |
| false | anything | after-recording |
| true | `panel` | live, panel |
| true | null, `focus`, unknown, or another case such as `Panel` | live, focus |

## D26

Nothing in `lib` reads `VoiceModeRepository` yet, so no recording path can reach the
fetch. `mode` is a synchronous getter, so the type system stops step 8's `start` from
waiting on it; only `load()` awaits `FirebaseRemoteConfigClient.activated()`.

For step 8: start `load()` unawaited, and handle its failure there. It rethrows and
keeps the last value. No current source throws, since the client catches fetch
failures, so the repository has no catch of its own.

## Verification

Toolchain: Flutter 3.47.8. All commands from `client/<package>`.

| Command | Result |
| --- | --- |
| `dart test` (`module_core`, full suite) | +2510 pass, 13 of them in `voice_mode_repository_test.dart` |
| `flutter test --no-pub` Firebase source, DI registration (`app`) | +11 pass |
| `flutter test --no-pub` channel source, DI bootstrap (`desktop`) | +4 pass |
| `dart analyze --fatal-infos` in `module_core`, `app`, `desktop` | clean |
| `dart run build_runner build` in `module_core`, `app`, `desktop` | only `injection.config.dart` changed, additions only |

Not checked: a real Firebase Remote Config read (the source test mocks the SDK), and
a desktop build with the channel define set (the test uses a mock bundle source).
The full `app` and `desktop` suites were left to CI. `docs/regression/` is unchanged
because nothing visible changed; step 11 reconciles it.
