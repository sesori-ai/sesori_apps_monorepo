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
| ⬜ | Not implemented: the harness and the seam Sesori drives can provide it, Sesori does not yet. |
| 🚫 | Not supported: the harness or the protocol seam Sesori drives cannot provide it. The footnote names the verified version. |

## Sub-agents

| Capability | Claude | OpenCode | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|
| Sub-agents rendered as inline subtask tiles | ✅ | ✅ | ⬜³ | 🚫⁴ | ⬜⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ⬜¹⁰ |
| Sub-agent transcripts exposed as child sessions | ✅ | ✅ | ✅³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ⬜¹⁰ |
| Scoped stop: confirmation while sub-agents run, `stop` cancels them all | ✅ | ✅ | ⬜³ | 🚫⁴ | ⬜⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ⬜⁹ | ⬜¹⁰ |
| Stop the sub-agents only while the main agent is idle (`stop`) | ✅ | ✅ | ⬜³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ⬜⁹ | ⬜¹⁰ |
| Stop the main agent only while it runs, keeping its sub-agents | 🚫¹ | 🚫² | ⬜³ | 🚫⁴ | 🚫⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ⬜⁹ | 🚫¹⁰ |

Plugins that report a scoped-stop rejection declare whether "main agent only"
is honored through `mainAgentOnlySupported`; the app offers the action only
when it is true.

¹ Claude Code's only stop primitive (`interrupt`, verified on 2.1.257) stops
background sub-agents together with the running main turn.

² OpenCode's task tool cancels a foreground child when its root is aborted
(verified on 1.18.25); background children survive, and the tracker cannot tell
the two apart, so the option is not offered.

³ Codex (codex-cli 0.148.0, `multi_agent` stable, probed 2026-09-02): a child
announces itself through the parent's `subAgentActivity started`
(`agentThreadId`) and `thread/status/changed`, never `thread/started`;
`receiverThreadIds` stays empty. Sesori exposes the verified child thread and
persisted rollout under its direct parent and rolls running descendants into
the root's busy state. `turn/interrupt` works per child thread with its
`turnId`, and interrupting the parent leaves children running, so
main-agent-only is supportable.

⁴ Copilot CLI (plugin targets 1.0.80) runs custom agents as subagents, but its
Agent Client Protocol server exposes no subagent lifecycle, no child session,
and only the turn-wide `session/cancel`.

⁵ Cursor (cursor-agent 2026.07.23) over ACP emits a subagent as a plain
`Task: …` tool call plus a `cursor/task` notification without child transcript,
so a tile is possible but a child session is not; the running count enables a
confirmation, while ACP's turn-wide `session/cancel` rules out partial stops.

⁶ Hermes (hermes-agent 0.19.0) has `delegate_task`, but its ACP adapter
flattens delegation into an ordinary tool call and maps `session/cancel` to a
hard interrupt of the whole agent; no child ids or per-delegate stop cross the
seam.

⁷ Pi (0.84.4) has no native sub-agents. Delegation exists only through
third-party extensions (`pi-subagents`) that spawn separate `pi` processes with
their own control channel, invisible to the RPC stream Sesori drives.

⁸ Oh My Pi (18.0.3) has subagents, but its ACP mode maps the task tool to a
generic `tool_call` with no ids or lifecycle notifications; those exist only in
`--mode rpc`, which Sesori does not drive. `session/cancel` aborts the whole
turn.

⁹ DeepSeek (`sesori-deepseek-acp` 0.1.3 source over dsh 0.1.1-rc.2,
probed 2026-09-03) now has protocol-v2 lifecycle, descendant transcript, replay,
and per-child interrupt contracts. Sesori maps its live and replayed child work
to tiles and child sessions, including foreground/background mode; a protocol-v1
adapter retains its generic delegation cards. Adapter v0.1.3 remains unpublished:
managed target 0.1.2 and PATH floor 0.1.0 remain in force until release preparation
records the merged consumer commit. Scoped stop
is intentionally pending the subsequent runtime-pin/interrupt consumer PR.

¹⁰ Grok Build (1.0.5, probed 2026-09-03) sends `subagent_spawned`/`subagent_progress`/
`subagent_finished` with parent and child session ids as
`_x.ai/session_notification` extension notifications, streams child updates
under the child id, and exposes `_x.ai/subagent/cancel` per child. A root
`session/cancel` cancels background children too, so main-agent-only is not
supported.
