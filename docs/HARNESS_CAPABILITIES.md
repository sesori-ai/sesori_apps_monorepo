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

## Managed runtime

| Capability | Claude | OpenCode | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|
| Sesori-managed runtime installed on request | 🚫 | ✅ | ✅ | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | 🚫 |
| Superseded managed runtime upgraded automatically on bridge start | 🚫 | ✅ | ✅ | ✅ | ✅ | 🚫 | ✅ | ✅ | ✅ | 🚫 |

Claude, Hermes, and Grok have no Sesori-managed runtime at all: they resolve a
user-installed CLI from PATH or an explicit binary option, so there is nothing
for Sesori to install or upgrade. The upgrade follows the install capability
exactly — a harness configured with an explicit binary override, running on a
platform with no pinned asset, or attached to an externally managed server
(`--opencode-no-auto-start`) advertises neither.

The upgrade only replaces a runtime Sesori already manages. A machine with no
managed version directory keeps the explicit Install action; it never downloads
a runtime the user has not asked for.

## Option pickers

| Capability | Claude | OpenCode | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|
| Models and effort variants listed strongest first, default declared separately | ✅ | ⬜ | ✅ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ | ⬜ |

The picker shows each plugin's declared order. OpenCode ranks models newest
release first, which is the best signal its catalog offers. Other plugins
still declare variants default-first (the client falls back to the first
listed variant when no default is declared) and models in plugin-defined order.

## Command limitations

Pi 0.84.4 advertises its bundled `/llama` command over RPC, but the handler
supports only the interactive TUI. Sesori excludes this bundled command source,
including numbered invocation aliases, while preserving user commands with the
same name. This command is **not supported** through Pi RPC; ordinary extension,
prompt, and skill commands remain available.

## Sub-agents

| Capability | Claude | OpenCode | Codex | Copilot | Cursor | Hermes | Pi | OMP | DeepSeek | Grok |
|---|---|---|---|---|---|---|---|---|---|---|
| Sub-agents rendered as inline subtask tiles | ✅ | ✅ | ✅³ | 🚫⁴ | ⬜⁵ | 🚫⁶ | 🚫⁷ | 🚫⁸ | ✅⁹ | ⬜¹⁰ |
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
the root's busy state. Spawn calls appear as inline subtask tiles both live
and in saved history, linked to the child thread; the tile follows the child's
session status instead of treating spawn completion as task completion.
Raw task-path fallbacks are formatted for display (for example,
`/root/architecture_review_1271` becomes `Architecture review · 1271`), while
raw paths remain the identity used to match saved spawn calls to children.
`turn/interrupt` works per child thread with its
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

⁹ DeepSeek's published adapter 0.1.3 over dsh 0.1.1-rc.2 is the managed target
and minimum accepted runtime. The consumer requires extension protocol v2 and
implements live/replayed correlated tiles and child transcripts/catalogs.
Replay retains direct-parent tile identities and ordered ordinary-content runs
without changing live child state. Scoped stop remains an unimplemented consumer
follow-up, although the adapter supplies its contract. Foreground children die
with the parent; background children survive, making main-agent-only stop
supportable when all running children are background. Final feature E2E coverage
remains pending.

¹⁰ Grok Build (1.0.5, probed 2026-09-03) sends `subagent_spawned`/`subagent_progress`/
`subagent_finished` with parent and child session ids as
`_x.ai/session_notification` extension notifications, streams child updates
under the child id, and exposes `_x.ai/subagent/cancel` per child. A root
`session/cancel` cancels background children too, so main-agent-only is not
supported.
