# Step 40 — voice interaction sealed state

## Re-verification

- `PromptInput` still coordinated startup, recording, transcription, and
  cancellation through eleven independently mutable fields plus a derived
  display state.
- Pointer ownership and cancel engagement remain valid during recorder startup,
  because the gesture begins before the platform start future settles.
- The minimum-duration timer and max-duration subscription are lifecycle
  resources rather than interaction state. The drag progress notifier remains
  separate because pointer-rate updates must not rebuild the composer.
- Transcription may unpin its layout when the user enters typing mode; active
  starting and recording interactions retain a non-null pinned layout.
- Per the owner's 2026-08-24 sequencing decision, this state refactor lands
  before the replacement for #918. Realtime preview work will adapt to these
  variants rather than this step targeting the unpublished #918 implementation.

## Changes

- Replaced `_VoiceState` and its coordination booleans with exhaustive
  `_VoiceIdle`, `_VoiceStarting`, `_VoiceRecording`, `_VoiceTranscribing`, and
  `_VoiceCancelling` variants.
- Moved interaction id, pinned layout, release intent, pointer ownership,
  minimum-duration completion, and cancel engagement onto only the variants
  where each value is valid.
- Kept timer/subscription ownership and high-frequency drag progress outside the
  sealed state while deriving the existing three-state visual presentation.
- Added widget coverage proving the max-duration signal stops and transcribes
  the active hold.
- Updated the voice regression contract and durable plan ordering.

## Behavior impact

Refactor-only. Startup acknowledgement, release-during-start cancellation,
minimum and maximum durations, drag-to-cancel hysteresis, pinned layouts,
transcription cancellation, stale-result isolation, and haptic feedback remain
unchanged. No analytics, database, persistence, wire, localization, DI, or
generated-source impact.

## Change budget

Totals exclude this evidence file and use `origin/main`:

| Scope | Files | Additions | Deletions |
| --- | ---: | ---: | ---: |
| Production/lib | 1 | 341 | 179 |
| Tests | 1 | 31 | 3 |
| Regression docs | 1 | 2 | 0 |
| Plan source | 1 | 4 | 2 |

The production increase makes the valid transition data explicit and removes
invalid field combinations; it adds no public abstraction or runtime owner.

## Verification

- `flutter pub get` (`client/app`, via test commands) — pass; lockfile unchanged.
- `dart analyze --fatal-infos` (`client/app`) — pass.
- `flutter test test/features/session_detail/widgets/session_detail_body_test.dart`
  (`client/app`) — pass, 85 tests.
- `flutter test test/features/session_detail` (`client/app`) — pass, 241 tests.
- `git diff --check` — pass.
- Architecture implementation review — approved with no findings.
- Independent state-machine correctness review — no findings.

`dart format` formatted the test file, then hit the pinned formatter's known
Dart 3.13 enhanced-enum null-check crash on `prompt_input.dart`. The package
analyzer and whitespace validation pass.

Physical hold-to-talk, cancel-drag, maximum-duration, and minimum-duration
checks were not claimed: only an iOS simulator is attached, which cannot prove
real microphone or haptic behavior. The corresponding widget flows pass with
the fake voice service.
