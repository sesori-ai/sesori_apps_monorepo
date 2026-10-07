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
  fetch on reopening. Until the output arrives a fixed 44 px row stands below
  the title and command: a spinner that fades in after 150 ms, or the error
  text with Retry. Copy keeps its room but stays hidden and inert until the
  output loads, so the title does not move.
- **Motion:** the panel's key changes only when the output arrives.
  `TranscriptDisclosure` then lays the new panel out at the old height for one
  frame, eases to its own height over 200 ms, and scrolls the reversed list by
  the growth on every tick, as it already did while opening, so the header and
  the content above stay still. Reduced motion snaps and compensates once.

## Compatibility

A v1.9.0 bridge decodes `SessionMessagesRequest` with the generated
`_$SessionMessagesRequestFromJson`, which reads only its known keys and has no
`disallowUnrecognizedKeys`, so the new `toolOutputDelivery` key is ignored
and the request succeeds. That bridge sends keyless tool states, which decode
as `ToolStateFull` and render as before; the app never calls the new route for
them. The through request did not exist in v1.9.0. No degraded path is needed.

## Size

About 820 changed lines: about 55 generated (localizations and Freezed) and
about 765 authored, of which about 260 are tests and about 50 are docs. About
110 lines of the `tool_part_widget.dart` churn re-indent the unchanged
viewport under `if (blocks.isNotEmpty)`, which keeps a summary without a
command from showing an empty viewport. The authored change is about 50 lines
over the 700-line target.

## Verification

Measured on code commit `3bbe2dd470e8a21ff4c8cac373a5a6e367d1e79d` with Dart
3.13.4 from Flutter 3.47.5-stable.

- `dart analyze --fatal-infos` clean in `client/module_core`,
  `client/module_app_ui`, `client/app` and `client/desktop`.
- `client/module_core`: `test/cubits/session_detail`, `test/api`,
  `test/repositories` and `test/services` pass (1,324 tests), including the
  new "summary tool output" group and the `getToolOutput` API test.
- `client/module_app_ui`: `test/features/session_detail/widgets` passes (415
  tests), including the "a summary part" group: the fetch on opening, the
  150 ms spinner delay, the eased resize with the header and title still, the
  in-panel Retry and an output fetched earlier opening at once.
- `architecture-implementation-review` through a sub-agent: approved with no
  findings.
- Fixture-data renders (closed, loading, failed, loaded and a 30 fps
  expand recording) from a throwaway widget test, not committed.
