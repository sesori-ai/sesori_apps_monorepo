# Step 6 — Shared Prompt-Turn Rule

Branch `transcript-history/shared-turn-rule`. `sesori_shared`, `module_core`,
one `module_app_ui` import and one regression-doc source line. No wire, store
or database change, and no behavior change.

## Scope Delivered

- `shared/sesori_shared/lib/src/transcript/prompt_turns.dart`, exported from
  `sesori_shared.dart`, holds what moved verbatim from `module_core`:
  - the `SessionMessagePresentation` extension (`hasRenderableUserContent`,
    `promptText`) from `session_detail_resolvers.dart`;
  - rule A from `transcript_turns.dart`: `_opensTurn`, `_outputEndOf`,
    `_partEnd` and `_OutputEnd`.
- One public fold, `splitPromptTurns({required messages})`, returns a sealed
  `PromptTurnSegment` list: `LeadingPromptSegment(messages)` and
  `PromptSegment(opener, messages)`. The plan's example names were kept.
- `TranscriptTurnBuilder.build` keeps its signature and maps a leading
  segment to `TranscriptPartialTurn` or `TranscriptPreamble` by
  `hasOlderMessages`. The client copies are deleted, not wrapped.
  `firstNonBlankLine` stays in `session_detail_resolvers.dart`.
- `transcript_sticky_prompt_overlay.dart` drops its now-unused
  `sesori_dart_core` import; every other consumer already imported
  `sesori_shared`.
- `docs/regression/transcript-turn-navigation.md` lists the shared rule and
  its test under Sources. No other doc named the moved code.

## Evidence

- Measured on code commit `48d11f7aae3ff334ca3d3fd325a5db30912c7899` (tree
  `dc437d0de7eb969b682db0399ff8298c5f81d174`) with Dart 3.13.4 from Flutter
  3.47.5-stable, after `flutter pub get` in `client/`. The evidence commits
  change no code. Every check passed:
  - in `shared/sesori_shared/`: `dart test test/transcript` (7 tests) and
    `dart analyze --fatal-infos`;
  - in `client/module_core/`: `dart test
    test/cubits/session_detail/transcript_turns_test.dart
    test/cubits/session_detail/transcript_prompt_list_test.dart
    test/cubits/session_detail/transcript_activity_test.dart
    test/cubits/session_detail/session_detail_resolvers_test.dart`
    (38 tests) and `dart analyze --fatal-infos`;
  - in `client/module_app_ui/`: `flutter test
    test/features/session_prompts/session_prompts_view_test.dart` (22 tests)
    and `dart analyze --fatal-infos`.
- Parity: `transcript_turns_test.dart` and `transcript_prompt_list_test.dart`
  pass unchanged.
- `shared/sesori_shared/test/transcript/prompt_turns_test.dart` covers the
  fold without the client: no messages, a prompt after an answer, follow-ups
  while waiting and mid-step, a failed step, the leading segment, hidden user
  messages, and the prompt extension.
- `architecture-implementation-review`, pass 1: approved with no findings.
