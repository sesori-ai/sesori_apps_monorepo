# Harness Capability Matrix

Sesori strives for feature parity across harnesses. This matrix records the
capabilities of the Sesori integration that not every harness has, so a gap is
a deliberate, visible state rather than an accident. Update it whenever a
capability lands for some harnesses but not others, or a harness limitation is
verified or lifted.

Columns are the plugins registered in `bridge/app/lib/src/runtime/plugin_registry.dart`.

## Legend

| Mark | Meaning |
|---|---|
| ✅ | Implemented: Sesori exposes the capability for this harness. |
| ⬜ | Not implemented: Sesori does not expose it yet. The harness may or may not support it; verify before marking 🚫. |
| 🚫 | Not supported: the harness itself cannot provide it. Note the verified version in the row's footnote. |

## Sub-agents

| Capability | Claude | OpenCode | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|
| Sub-agents rendered as inline subtask tiles with child sessions | ✅ | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Scoped stop: confirmation while sub-agents run, `stop` cancels them all | ✅ | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Stop the sub-agents only while the main agent is idle (`keep`) | ✅ | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |
| Stop the main agent only while it runs, keeping its sub-agents | 🚫¹ | 🚫² | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

¹ Claude Code's only stop primitive (`interrupt`, verified on 2.1.257) stops
background sub-agents together with the running main turn.
² OpenCode's task tool cancels a foreground child when its root is aborted
(verified on 1.18.25); background children survive, and the tracker cannot tell
the two apart, so the option is not offered.

Plugins that report a scoped-stop rejection declare whether "main agent only"
is honored through `mainAgentOnlySupported`; the app offers the action only
when it is true.
