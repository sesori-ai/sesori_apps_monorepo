# Step 4 — Render Folded Turns From The Session Fold State

Branch `turn-navigation/fold-turns`. Architecture 3.

## Plan Claims Checked

- `_buildLoadedState` seeds every loaded state's `isUpdatingAutoContinuation`
  from a private field. It sits at `session_detail_cubit.dart:2923` on
  origin/main, not 2939.
- `reload()` emits `SessionDetailState.loading()` first, so only the cubit's
  field carries the fold across it. Two load failures re-emit the state from
  before the load and seed it again; the plan did not name them.
- `SessionDetailLoadedView` passes `loadOlderMessages` from the cubit to
  `SessionDetailMessageList`; the fold follows the same path.
- The list eases in every row id missing from `_knownRowIds`, so without a
  reset the stub rows a switch brings in would ease in.

## Scope Delivered

- `SessionDetailLoaded.transcriptFolded`, with Freezed regenerated, and in
  `SessionDetailCubit` the `_transcriptFolded` field and the one intent,
  `setTranscriptFolded({required bool folded})`.
- `SessionDetailLoadedView` passes both to `SessionDetailMessageList`.
- Folded, the list runs `TranscriptTurnBuilder` after `TranscriptBuilder`. Each
  prompt turn shows its prompt row and a stub row
  `session-detail-turn-<openerMessageId>`. The leading segment shows one stub
  row `session-detail-turn-head`. The retry-error, working and queued rows
  stay. A switch resets `_knownRowIds`.
- `TranscriptTurnStub` shows the approved line in the step group summary's
  style, and screen readers read the same text. The copy is in `app_en.arb`.
- No control, analytics event or regression document: users see no change.

## Deviation

- Plan review finding: `transcriptFolded` is `required`, not
  `@Default(false)`, and every construction site passes it. PLAN.md's
  Architecture 3 is corrected.
- The two load-failure fallbacks seed the fold again. Otherwise a fold request
  during a load that then fails leaves the field folded and the state unfolded,
  and every later request is dropped as a no-change. Architecture 3 records it.
- The list takes `onTranscriptFoldedChanged` as planned, but nothing calls it
  until step 5's stub tap.
- Partial and preamble stubs always lead with a chevron: their copy has no
  running or error form.

Size: 686 changed lines against the 700-line target. Production code is
225 authored lines, 67 of them ARB copy, and 115 generated (localizations 98,
Freezed 17). Tests are 260 lines, and docs the rest.

## Automated Evidence

Toolchain: Dart 3.13.4 from Flutter 3.47.5. `dart analyze --fatal-infos` is
clean in `module_core`, `module_app_ui`, `app` and `desktop`.
`dart format -l 120` changes no touched file.

| Command | Result |
|---|---|
| `dart test test/cubits/session_detail/ test/cubits/state_defaults_test.dart test/consumers/analytics/session_activity_analytics_listener_test.dart` in `client/module_core` | 306 passed (2 new) |
| `flutter test test/features/session_detail/` in `client/module_app_ui` | 306 passed (14 new) |
| `flutter test test/features/session_detail/widgets/session_detail_body_test.dart` in `client/app` | 137 passed |
| `flutter test test/features/sessions/desktop_session_detail_screen_test.dart` in `client/desktop` | 10 passed |
| The `_knownRowIds` reset removed | "a fold switch eases no row in" fails |
| `_buildLoadedState` seeds `false` | the reload test fails |
| Plain "Running" guarded by `steps == -1` | the "Running" copy case fails |

## Review

`architecture-implementation-review` over `origin/main...HEAD` rejected on one
low finding: nothing calls the list's required `onTranscriptFoldedChanged`
before step 5. The plan's step 4 and this step's brief put that wiring here,
which the reviewer noted overrides the finding, so it stays and the review was
not rerun. Everything else conformed: the fold seeded wherever a loaded state
is built or re-emitted, the turn model in the list's build, the unexported
stub, and the dependency direction.

## Manual

None: no control exposes folding.
