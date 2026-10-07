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
  panel fetches again when it next opens.
- **Panel:** `ToolPartWidget` gives a full part its own output and a summary
  part the cubit's fetch, so a full part always wins. The panel fetches after
  its first frame when the output is not loaded, which also retries a failed
  fetch on reopening. Until the output arrives a row of at least 44 px stands
  below the title and command: a spinner that fades in after 150 ms (a retry
  starts a fresh delay), or the error text with Retry, which grows only when
  large text needs more room. Copy keeps its room but stays hidden and inert
  until the output loads, so the title does not move.
- **Motion:** `TranscriptDisclosure.panelComplete` turns true when the output
  arrives. The disclosure then lays the panel out at the old height for one
  frame, eases to its own height (taller or shorter) over 200 ms, and scrolls
  the reversed list by the growth on every tick, as it already did while
  opening, so the header and the content above stay still. The panel keeps
  its state, so a command scrolled sideways keeps its offset. Reduced motion
  snaps and compensates once.

## Compatibility

A v1.9.0 bridge decodes `SessionMessagesRequest` with the generated
`_$SessionMessagesRequestFromJson`, which reads only its known keys and has no
`disallowUnrecognizedKeys`, so the new `toolOutputDelivery` key is ignored
and the request succeeds. That bridge sends keyless tool states, which decode
as `ToolStateFull` and render as before; the app never calls the new route for
them. The through request did not exist in v1.9.0. No degraded path is needed.

## Size

About 990 changed lines against `origin/main`: about 55 generated
(localizations and Freezed) and about 935 authored, of which about 360 are
tests and about 70 are docs. About 110 lines of the `tool_part_widget.dart`
churn re-indent the unchanged viewport under `if (blocks.isNotEmpty)`, which
keeps a summary without a command from showing an empty viewport. The first
review wave added about 170 lines, mostly tests for its four fixes.

## Verification

Measured on code commit `22b214afead22aa29c2eb4e592112a7bda4f020e` (tree
`ec3c6f782192bc654f19a54bad3d0c1143d22dce`) with Dart 3.13.4 from Flutter
3.47.5-stable; later commits on this PR change only this file. Commands ran
from the named package directory.

- `dart analyze --fatal-infos` clean in `client/module_core`,
  `client/module_app_ui`, `client/app` and `client/desktop`.
- `client/module_core`: `flutter test test/cubits/session_detail test/api
  test/repositories test/services` passes (1,325 tests), including the
  "summary tool output" group and the `getToolOutput` API test.
- `client/module_app_ui`: `flutter test test/features/session_detail` passes
  (422 tests), including the "a summary part" group: the fetch on opening,
  the 150 ms spinner delay on the first fetch and on a retry, the eased
  resize to a taller and to a shorter output with the header and title
  still, the command's sideways scroll kept, the failure growing for large
  text, the in-panel Retry and an output fetched earlier opening at once.
  The retry-delay, shorter-output and large-text tests fail with their fixes
  reverted.
- `architecture-implementation-review` through a sub-agent: approved with no
  findings.
- Fixture-data renders (loading, failed, loaded and a 30 fps expand
  recording) from a throwaway widget test in `client/module_app_ui`, run with
  `flutter test <file> --update-goldens`, not committed.
