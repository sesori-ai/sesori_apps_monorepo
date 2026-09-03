# Grok Build ACP v1 fixture source

Validated on 2026-08-27 against the official macOS arm64 artifact:

- Version: `grok 1.0.5 (5115b46bc909)`
- URL: <https://x.ai/cli/grok-1.0.5-macos-aarch64>
- SHA-256: `3dfa7f04fbb5427a8fbead286591543aaecb478b3a0ab222c4329eca1a3b2f86`
- Launch: `grok --no-auto-update agent --no-leader stdio`

An isolated initialize negotiated ACP v1, advertised load/list/resume/close, disabled image/audio prompts, enabled
embedded context, returned Grok identity/version metadata, and exposed model entries with structured reasoning-effort
metadata. With no credentials, it advertised only interactive `grok.com` authentication.

The JSON fixtures preserve only that schema. Model IDs, names, descriptions, effort labels, and session IDs are
synthetic; no account data, credentials, prompts, transcripts, source paths, or raw released response are retained.

The `subagent_*.json` fixtures were captured on 2026-09-02 from the same artifact during an authenticated live
probe of the sub-agent lifecycle (`.plan/completed/claude-inline-subtasks/followups/grok-probe.md`): the standard
`spawn_subagent` `tool_call` with its `_meta`, and the `_x.ai/session_notification` frames `subagent_spawned`,
`subagent_progress`, and `subagent_finished` (completed and cancelled). Field names, nesting, and enum values are
verbatim; ids, descriptions, prompts, outputs, and counters are synthetic.
