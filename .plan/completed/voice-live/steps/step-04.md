# Step 4 — Desktop controls

## Built

- Pointer composer: click the mic to listen. Pencil and X on the left; mic and send
  merge into a wide `Send ↑` under the cursor, so the second click lands.
- Enter or wide Send finish `send`. Pencil or Shift+Enter finish `edit`. Esc or X
  cancel and keep the box. Enter and Shift+Enter bind beside Esc, only while
  listening, so they never reach the field as a newline or send the box separately.
- Hint `Enter to send`. Tooltips on pencil, X and Send. `voiceClickToTranscribe` and
  `voiceStopAndTranscribe` are gone.
- `PregoVoiceSendButton` added beside `PregoVoiceTarget`. No catalog entry, as other
  voice components have none. `ComposerListeningPulse` deleted: the pointer mic was
  its only user and the agreed mock has no pulse.
- D31: the feedback sheet has its own flow and uses none of the removed strings. No
  change. Its X shares `voiceCancelRecording`, so that key's description now says so.

## Values

| Value | Result | Note |
| --- | --- | --- |
| Wide Send width | 94 px | Real mic and send: 44 + 6 (`PregoSpacing.sm`) + 44. The mock's gap was 8, so 96 would move an edge |
| Wide Send radius | 22 px | `PregoRadius.full` at 44 high |
| Merge | `_morphDuration`, `_morphCurve` | Same as the composer's other morphs; reduced motion snaps the width and keeps the fade |
| Transcribing | Send 0.4 opacity and inert | Holds its place; the pencil fades with its width held; the X stays put |

Back to rest, the Send shrinks toward the send button's slot and cross-fades.

## Beyond the brief

- Esc also stops a transcription on pointer, matching the X.
- Enter during transcribing is swallowed on pointer, so a double Enter cannot send
  the box ahead of the words.
- A retried recording does not merge. The send stays free and sending abandons the
  retry, as the regression doc already says.
- The leading slot's `AnimatedSwitcher` is pinned to the leading edge. Without it the
  options jump 25 px as the wider targets leave. This also applies to touch, where
  the touch tests still pass.

## Verification

Toolchain: Flutter 3.47.8. All commands from `client/<package>`.

| Command | Result |
| --- | --- |
| `module_app_ui`: `flutter test --no-pub` pointer, touch, keyboard policy, capabilities, feedback sheet | +98 passed; pointer alone +21 |
| `app`: `flutter test --no-pub` session_detail_body, new_session_screen | +285 passed |
| `desktop`: `flutter test --no-pub` session detail, home composer layout, home pane, new session | +69 passed |
| `dart analyze --fatal-infos` in `module_prego`, `module_app_ui`, `desktop`, `app`, `design_catalog` | No issues |

Mutation: centring the leading slot fails the feel test (options at 31, expected 6).

## Found while building

Step 3 could send two messages: on touch the send button stayed live during transcribing,
so a tap sent the box and the words followed separately, breaking D15. The composer now
holds the box until the words arrive, in every shell, and the button shows as unavailable.
Covered by `tapping send during transcribing still sends one message`, which failed first.

## Not checked

- No run on real macOS and no recording: the merge's feel, and the tooltips over the
  moving Send, are judged from frame tests and still PNGs only.
- No real platform text input: "no newline" rests on the key being handled before the
  field, asserted through the field's text in a widget test.
- Numpad Enter is not bound, the same as the composer's other Enter handling.
