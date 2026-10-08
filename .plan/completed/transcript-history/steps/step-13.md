# Step 13 — Fetch Tool Output When A Row Expands

Branch `transcript-history/slim-tools-app`. `client/module_core`,
`client/module_app_ui` and docs. No wire, store or database change. Users see
a finished tool's panel open at once and load its output.

## Scope Delivered

- **Opt-in:** `SessionApi.getMessages` and `getMessagesThrough` ask for
  `ToolOutputDelivery.onExpand`.
- **Fetch:** `SessionApi.getToolOutput` posts `/session/tool-output`;
  `SessionRepository.getToolOutput` returns a sealed `ToolOutputResult`
  (`ToolOutputAvailable(output, error)` or `ToolOutputFailure(ApiError)`);
  `SessionDetailLoadService.loadToolOutput` logs a failure;
  `SessionDetailCubit.fetchToolOutput(messageId, partId)` fills
  `SessionDetailLoaded.toolOutputs`, a map from the record key
  `ToolOutputKey` to a sealed `ToolOutputFetch` (`ToolOutputLoading`,
  `ToolOutputLoaded(output, error)`, `ToolOutputFailed`) (P14). It skips a key
  that is loading or loaded, so repeated asks make one request. The map
  survives a silent refresh (`copyWith`); a full reload starts empty and the
  panel fetches again when it next opens. A tool part that arrives live as a
  finished full part seeds the map with its output, so a later page that
  summarizes the same part resolves without a fetch.
- **Panel:** `ToolPartWidget` gives a full part its own output and a summary
  part the cubit's fetch, so a full part always wins. The panel fetches after
  its first frame when the output is not loaded, which also retries a failed
  fetch on reopening. Until the output arrives a row of at least 44 px stands
  below the title and command: a spinner that fades in after 150 ms (a retry
  starts a fresh delay), or the error text with Retry, which grows only when
  large text needs more room. Copy keeps its room but stays hidden and inert
  until the output loads, so the title does not move.
- **Motion:** `TranscriptDisclosure.panelContentKey` changes between
  loading, failed and output. The disclosure then lays the panel out at the
  old height for one frame, eases to its own height (taller or shorter) over
  200 ms, and scrolls the reversed list by the growth on every tick, as it
  already did while opening, so the header and the content above stay still.
  It skips that scroll while the reader drags or flings, because a jump would
  stop the gesture. The panel keeps its state, so a command scrolled sideways
  keeps its offset. Reduced motion snaps and compensates once.

## Compatibility

A v1.9.0 bridge decodes `SessionMessagesRequest` with the generated
`_$SessionMessagesRequestFromJson`, which reads only its known keys and has no
`disallowUnrecognizedKeys`, so the new `toolOutputDelivery` key is ignored
and the request succeeds. That bridge sends keyless tool states, which decode
as `ToolStateFull` and render as before; the app never calls the new route for
them. The through request did not exist in v1.9.0. No degraded path is needed.

## Size

About 1,140 changed lines against `origin/main`: about 55 generated
(localizations and Freezed) and about 1,085 authored, of which about 470 are
tests and about 80 are docs. About 110 lines of the `tool_part_widget.dart`
churn re-indent the unchanged viewport under `if (blocks.isNotEmpty)`, which
keeps a summary without a command from showing an empty viewport. The two
review waves added about 320 lines, mostly tests for their seven fixes.

## Verification

Measured on code commit `1c31be0a4770e25b349769de74243449e5ce4e08` (tree
`4c595d1b25bfd902058a4439f71819a6f2a5eae4`) with Dart 3.13.4 from Flutter
3.47.5-stable; later commits on this PR change only this file. Commands ran
from the named package directory.

- `dart analyze --fatal-infos` clean in `client/module_core`,
  `client/module_app_ui`, `client/app` and `client/desktop`.
- `client/module_core`: `flutter test test/cubits/session_detail` passes
  (365 tests), including the "summary tool output" group and the live seed.
  `flutter test test/api test/repositories test/services` passed on the
  first review wave's commit, before this wave's cubit-only change.
- `client/module_app_ui`: `flutter test test/features/session_detail` passes
  (424 tests), including the "a summary part" group: the fetch on opening,
  the 150 ms spinner delay on the first fetch and on a retry, the eased
  resize to a taller and to a shorter output with the header and title
  still, the command's sideways scroll kept, the failure growing and easing
  for large text, a fling running on while the output lands, the in-panel
  Retry and an output fetched earlier opening at once. The retry-delay,
  shorter-output, large-text, failure-ease and fling tests fail with their
  fixes reverted.
- `architecture-implementation-review` through a sub-agent: approved with no
  findings.
- Fixture-data renders (loading, failed, loaded and a 30 fps expand
  recording) from a throwaway widget test in `client/module_app_ui`, run with
  `flutter test <file> --update-goldens`, not committed.
