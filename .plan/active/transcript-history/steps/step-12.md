# Step 12 — Slim Tool Parts On The Bridge

Branch `transcript-history/slim-tools-bridge`. `sesori_shared`, the bridge,
two compile-only client call sites, and docs. No store or database schema
change; tool parts stored from now on carry a `"form":"full"` key. No
user-visible change: no app asks for summaries until step 13.

## Scope Delivered

- **Wire (`sesori_shared`):** `ToolState` is a Freezed union keyed by `form`.
  The unnamed constructor is `ToolStateFull` (`"full"`), so every existing
  `ToolState(` call site still compiles; `ToolState.summary(status, title,
  shellCommand, attachments)` is `ToolStateSummary`. `fallbackUnion: "default"`
  decodes keyless JSON (stored rows, v1.9.0 bridges) as full. Output and error
  live only on the full variant.
- **Opt-in:** `ToolOutputDelivery { inline, onExpand }`.
  `SessionMessagesRequest.toolOutputDelivery` defaults to `inline` with a
  `COMPATIBILITY 2026-10-07 (v1.9.1)` marker for v1.9.0 apps.
  `SessionMessagesThroughRequest.toolOutputDelivery` is required: v1.9.0 does
  not contain step 8 (checked with `git show v1.9.0:` of `session.dart`).
- **Route:** `POST /session/tool-output` takes
  `SessionToolOutputRequest(sessionId, messageId, partId)` and returns
  `SessionToolOutputResponse(output, error)`, or 404 when the part is missing
  or is not a tool. `GetSessionToolOutputHandler` →
  `ChatHistoryService.getToolOutput` (through `_readStoredHistory`, P10) →
  `ChatHistoryRepository.getToolOutput` / `getArchivedToolOutput` →
  `ChatHistoryDao.getPart` by primary key, or the audit file. A sealed
  `ToolOutputLookup` (`Found` / `Missing`) keeps "no audit file" distinct from
  "no such part".
- **Projection:** `withSummarizedToolOutput()` in `repositories/mappers/`
  summarizes completed, error and cancelled tools that have output or error.
  One private `_pageMessage` applies W2 and then W3 at both page-assembly sites
  (store and audit file), only for `onExpand`. Live SSE parts stay full.
- **Readers:** `PluginToolState.toShared` now returns `ToolStateFull`. The
  finalization sweep matches `ToolStateFull`. `ToolPartWidget` switches on the
  variant and shows the disclosure for every summary part; the app keeps
  asking for `inline` on load-throughs until step 13.

## Size

About 1,330 changed lines: about 460 generated Freezed and JSON output and
about 870 authored, of which about 430 are tests. The overage on the 900-line
target is the generated output of two new wire models and the `ToolState`
union; the authored part fits the target.

## Verification

Measured on code commit `3af61a81f87932045705e4e422c818b98a3ce00d` with Dart
3.13.4 from Flutter 3.47.5-stable. Later commits on this PR change only docs.

- `dart analyze --fatal-infos` clean in `bridge/` (including `tool/`),
  `sesori_shared`, `client/module_core`, `client/module_app_ui`, `client/app`
  and `client/desktop`.
- `bridge/app`: `test/bridge` (1,919 tests) plus `test/repositories`,
  `test/routing`, `test/services`, `test/persistence`, `test/drift`,
  `test/integration` and `test/api` pass. A first full run failed only to load
  suites when the disk filled.
- `sesori_shared` suite passes, including `tool_state_test.dart`.
- `tool_part_widget_test.dart` passes.
