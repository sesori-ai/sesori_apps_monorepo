# Cursor / ACP Backend — Open Follow-ups

Deferred items from the review of PR #332 (`feat(bridge): add Cursor backend via
ACP`). Themes A, B, C, F, G, H, I and J are resolved and were removed from this
document; git history retains their full reasoning. Two items remain open.

Re-verify any claim against current code before acting on it — the file
references below were accurate at review time and may have drifted.

## D1 — Plan-mode rejection routing (blocked on evidence)

For `cursor/create_plan`, the modal's standard Reject button calls
`rejectQuestion`, which sends a JSON-RPC error; Cursor may expect a normal
`{accepted: false}` response instead, so plan-mode turns could abort
unexpectedly. This needs a real `agent acp` trace of Cursor's plan-response
contract before changing anything — altering it blind risks breaking the accept
path.

Source: [#332 r3536293286](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536293286)

## E — Typed ACP/Cursor boundary DTOs (deliberately deferred)

Core ACP parsing is raw `Map`/`List`. Replacing it with typed boundary DTOs would
restore compile-time safety in a central bridge flow, but only once the
undocumented ACP/Cursor wire shapes are pinned down by real traces; modeling
drifting payloads now would be brittle. The individual unsafe casts were hardened
fail-soft in the meantime (`acpToolName` / `_str` guards).

Affected surfaces: `acp_content.dart`, `acp_event_mapper.dart`,
`acp_session_loader.dart`, and the plugin models.

Source: [#332 r3481369047](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3481369047)
