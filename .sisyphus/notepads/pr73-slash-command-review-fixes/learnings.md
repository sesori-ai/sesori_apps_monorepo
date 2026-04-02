# Learnings — pr73-slash-command-review-fixes

## Architecture Decision: BridgePlugin Interface Unchanged
BridgePlugin interface stays AS-IS. Handlers route commands by calling plugin.sendCommand() after plugin.sendPrompt(). This avoids 10 implementations × 60 test files ripple.

## Key Existing Patterns
- `BodyRequestHandler<REQ, RES>` — extend, pass `fromJson` to super, receive typed `body` in `handle()`
- `ProjectIdRequest` — EXISTS at `shared/sesori_shared/lib/src/models/sesori/project.dart:38-45`
- Directory header: `_directoryOpenCodeHeader: ?directory` in headers map (NOT query param)
- Mobile POST requests: `_client.post(path, fromJson: T.fromJson, body: RequestModel(...))`

## Codegen Order (CRITICAL)
1. `cd shared/sesori_shared && dart run build_runner build --delete-conflicting-outputs`
2. `cd bridge && make codegen`
3. `cd mobile && dart run build_runner build --delete-conflicting-outputs` (from module_core)

## Model Field Convention
- Always `required` named arguments, never positional
- New nullable fields: `required String? fieldName` (Freezed pattern)
- `AgentModel` uses `modelID` + `providerID` naming — use `provider` (not `providerID`) in CommandInfo/Command to match reviewer's plain naming style

## Dead Code Confirmed
- `_QueuedMessagesSection` and `QueuedMessageBubble` ARE USED — do NOT delete
- `SessionLaunchCommandStore` IS dead after this refactor — DELETE
- `createEmptySession()` IS dead after this refactor — DELETE

## OpenCode API Review Fixes
- `listCommands()` should mirror `listSessions()` and pass `_directoryOpenCodeHeader` in headers, not query params.
- `createSession()` should always forward the prompt body; the empty-parts guard is unnecessary for the review fix.
## 2026-04-02
- `GetCommandsHandler` can follow the same `BodyRequestHandler<REQ, RES>` pattern as other POST handlers by deserializing `ProjectIdRequest` and reading `body.projectId`.
- Bridge analyze is sensitive to import ordering and unused exports; fixing lint noise in neighboring files may be required before verification passes.
