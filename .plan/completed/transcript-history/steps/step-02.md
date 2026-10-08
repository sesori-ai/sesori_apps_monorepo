# Step 2 — Drop The Duplicated Shell Title

Branch `transcript-history/shell-title`. Bridge only; no wire, store or
database change.

## Scope Delivered

- `bridge/app/lib/src/repositories/mappers/duplicated_shell_title_mapper.dart`:
  `MessageWithParts.withoutDuplicatedShellTitles()` sets `title` to null on a
  tool part whose `shellCommand` is non-null and equal to its title. Every
  other part passes through unchanged.
- `ChatHistoryRepository` applies it in its two page-assembly sites, after
  `_rehydrateParts`: `_assemblePage` (database, fresh and `storedOnly` pages)
  and the archived page build in `getArchivedSessionMessages`. The routing
  handler, `toShared`, the store, existing rows, the audit-file export,
  `_rehydratePart`, semantic import matching, subtask `taskState` and
  non-shell titles are unchanged.
- The `toShared` comment now says only live events keep the title alias.
- Docs: `docs/HARNESS_CAPABILITIES.md` "Explicit shell-command presentation"
  and `docs/regression/tools-and-file-changes.md` describe the split: live
  events keep the alias, and pages omit a title equal to `shellCommand`.
- O1 answered by the user on 2026-10-07: accept. PLAN.md and TRACKER.md record
  it.
- No `COMPATIBILITY` marker. The AGENTS.md rule covers an honest `@Default`
  for legacy transport omission; this step adds no field or default. The
  wire already allows a null title (`ToolState.title` is `String?`).

## Wire Compatibility Evidence

- **v1.9.0 decodes the page.** In `git show v1.9.0:shared/sesori_shared/lib/src/models/sesori/message_part.g.dart`,
  `_$ToolStateFromJson` reads `title: json['title'] as String?`, so a missing
  key decodes to null. The shared `build.yaml` sets `include_if_null: false`,
  so the page omits the key rather than sending `null`.
- **v1.9.0 renders the row correctly.** In
  `git show v1.9.0:client/module_app_ui/lib/src/features/session_detail/widgets/tool_part_widget.dart`,
  `ToolPartWidget.build` renders `_ShellToolPreview(command: command, ...)`
  whenever `state.shellCommand != null`. The title (`detail`) is used only in
  the `else` branch for non-shell tools, which this step never touches. A
  `git grep` over `v1.9.0` for `state.title` in `client/` and
  `shared/sesori_shared/lib` finds only that line.
- **`main` renders the row correctly.** `_ToolHeader` in
  `tool_part_widget.dart` shows `"\$ $command"` when `shellCommand` is
  non-null; it reads the title only for non-shell tools, and no other app code
  reads the tool title.
- **v1.8.3 and older** read the command only from the title, so their reloaded
  shell rows show the tool name without the command. Accepted by the user
  (O1).

## Evidence

- `bridge/app/test/bridge/repositories/mappers/duplicated_shell_title_mapper_test.dart`:
  a shell tool loses a title equal to its command and keeps its command and
  output; a shell tool with a different title keeps it; a non-shell tool and a
  text part are unchanged.
- `bridge/app/test/bridge/services/chat_history_archive_test.dart`: a database
  page read and an archived page read each return the duplicated shell title
  as null and keep a differing shell title and a non-shell title.
- `bridge/app/test/bridge/routing/get_session_messages_handler_test.dart`:
  through `POST /session/messages` with a real history service and
  repository, a plugin shell tool (whose live mapping aliases the title to the
  command) is served with no `title` key in its wire JSON. This headless route
  read stands in for the plan's manual debug-server page read.
- Measured on code commit `28fae0bba438ba6ffc7926431d24428cc8cee1b2` (tree
  `1aeed53280b9475bbe624f74c754de9e4d44fffe`) with Dart 3.13.4 from Flutter
  3.47.5-stable; the evidence commits change no code. Every check passed in
  `bridge/app/`: `dart test test/bridge/routing test/bridge/repositories/mappers
  test/bridge/services test/bridge/plugin_to_shared_mapping_test.dart
  test/bridge/persistence` (1,078 tests) and `dart analyze --fatal-infos`.
- No architecture review: the change is a pure projection at the two sites
  the plan's architecture review already placed it; no ownership moved.
