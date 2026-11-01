# Step 3 — Touch gesture and send on finish

## Built

- Touch hold: release sends, the left target is a Tabler pencil (far left in both
  input modes), sliding up out of the pill cancels and keeps the box.
- Red wash over the full pill follows the finger through `_cancelDragProgress`;
  the pencil fill follows `_editDragProgress`. Neither rebuilds the composer.
- `_VoiceFinish { send, edit }` in `_VoiceTranscribing`.
  `VoiceInputCompleted.outcome` is the closed `VoiceDictationOutcome { finished,
  limitReached }`. A send needs `send` and `finished`, through `_submitComposer`.
- `PregoVoiceCancelButton` became `PregoVoiceTarget` (icon and tone).
- `voice_transcription_completed` gains closed `finish`: `sent`, `edited`, `cut_off`.
- Pointer presentation always finishes `edit`. The feedback sheet is unchanged in
  behaviour and ignores `outcome`.

## Values

| Value | Result | Note |
| --- | --- | --- |
| Cancel arm | 64 px above the pill | Plan value |
| Pencil arm | 0.9 of the way to its centre | Plan value; fill reaches solid exactly at arm |
| Disarm tolerance | 12 px on both | Added: keeps the existing tremor guard |
| Wash fade after lift | 240 ms | Added: the wash does not snap off |

The mock's pencil is binary with a 150 ms CSS transition. Here the fill scrubs
with the finger, so the gesture responds continuously.

## Beyond the brief

- A hold the system cancels, and the keyboard button during transcribing, land in
  the box and never send.
- Hold surfaces take a semantic dismiss so assistive technology keeps a cancel path;
  a tap on the pencil ends in the box.
- A dictated send does not raise the keyboard unless the field already had it, in
  either input mode.

## Verification

Toolchain: Flutter 3.47.8. All commands from `client/<package>`.

| Command | Result |
| --- | --- |
| `flutter test --no-pub` touch, pointer, keyboard policy, capabilities, feedback sheet (`module_app_ui`) | +81 pass |
| `flutter test --no-pub` session detail body, new session screen (`app`) | +285 pass |
| `dart test` voice input, analytics event, new session, session detail cubits (`module_core`) | +249 pass |
| `flutter test --no-pub` (`module_prego`) | +397 pass |
| `dart analyze --fatal-infos` in `module_prego`, `module_core`, `module_app_ui`, `app`, `desktop`, `design_catalog` | clean |

Not checked on a device: the feel of the drag (the wash detent at the 12 px
tolerance, the small snap when a cancel zeroes the pencil) needs a real finger.
