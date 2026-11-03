# Cursor / ACP Backend — Open Follow-ups

Deferred items from the review of PR #332 (`feat(bridge): add Cursor backend via
ACP`). Themes A, B, C, F, G, H, I and J are resolved and were removed from this
document; git history retains their full reasoning. Two items remain open.

Re-verify any claim against current code before acting on it — the file
references below were accurate at review time and may have drifted.

## D1 — Plan-mode rejection routing (blocked on evidence)

For `cursor/create_plan`, the modal's standard Reject button calls
`rejectQuestion`, which sends a JSON-RPC error because the request registers
`resolutionBuilder: null` (`cursor_approval_registry.dart`, falling back in
`_rejectAcpQuestion` in `acp_approval_registry.dart`); Cursor may expect a normal
`{accepted: false}` response instead, so plan-mode turns could abort
unexpectedly. This needs a real `agent acp` trace of Cursor's plan-response
contract before changing anything — altering it blind risks breaking the accept
path.

Source: [#332 r3536293286](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536293286)

## E — Typed ACP/Cursor boundary DTOs (deliberately deferred)

Content blocks and tool content already parse into typed DTOs
(`api/models/acp_content_block_dto.dart`, `api/models/acp_tool_content_dto.dart`,
mapped by `repositories/mappers/acp_content_mapper.dart`). Session updates and
history replay still read raw `Map`/`List`. Typing them would restore
compile-time safety in a central bridge flow, but only once the undocumented
ACP/Cursor wire shapes are pinned down by real traces; modeling drifting
payloads now would be brittle. Approval fields use fail-soft `_str` guards, but
session-update and tool-call fields still use direct `as String?` casts.

Affected surfaces in `bridge/sesori_plugin_acp/lib/src/`: `acp_event_mapper.dart`,
`acp_session_loader.dart` and `acp_approval_registry.dart`, plus Cursor's
`cursor_approval_registry.dart`.

Source: [#332 r3481369047](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3481369047)
