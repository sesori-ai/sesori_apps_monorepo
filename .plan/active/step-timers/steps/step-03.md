# Step 3 — remove the tool kind

## Shipped

- Wire: `MessagePart.tool.kind` and `ToolKind` removed from `sesori_shared`;
  `PluginMessagePart.tool.kind` and `PluginToolKind` removed from
  `sesori_plugin_interface`; bridge mapping drops `PluginToolKindMapping`.
  Freezed and JSON output regenerated.
- Plugins: the Claude, Codex and Pi kind mappers and their tests are deleted;
  ACP `AcpContentMapper.toolKind`, OpenCode `_toolKind` and the OpenCode v2
  public `toolKind` are gone. OpenCode v2 keeps a private `_isShellTool` for
  its shell-command projection. Pi keeps its private edit check
  (`_TrackedTool.isEdit`) for session-diff refreshes; Claude keeps its private
  `_ClaudeToolKind`.
- Docs: `HARNESS_CAPABILITIES.md` "Tool kinds" section deleted;
  `tools-and-file-changes.md` kind bullet, decode failure signal and sources
  removed.

## Release evidence

- The field landed in 76caab4a75 (2026-09-25, visual-hierarchy step 32).
- `git merge-base --is-ancestor 76caab4a75 v1.9.0` fails: the latest public
  release, v1.9.0 (2026-09-24), does not contain it, and its
  `message_part.dart` has no `ToolKind`.
- Only prerelease tags `v1.9.1-internal.979`–`.992` contain it. No
  compatibility path is owed.
- An internal app that still decodes `kind` reads its `@Default` (`unknown`)
  from a newer bridge; a newer app ignores the key from an older bridge.

## Verification

- `dart analyze --fatal-infos`: `sesori_shared`, `sesori_plugin_interface`,
  `bridge/app`, the ACP, Claude, Codex, Cursor, OpenCode, Pi, Antigravity,
  Copilot, Grok, DeepSeek, Hermes and OMP plugins, `module_core`,
  `module_app_ui`, `client/app`, `client/desktop` — no issues.
- `dart test`: `sesori_shared` (426), `sesori_plugin_interface` (181),
  `bridge/app` (3,068), ACP (363), Claude (380), Codex (472), OpenCode (587),
  Pi (340), Cursor (175) — all pass.
