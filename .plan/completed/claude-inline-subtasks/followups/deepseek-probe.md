# DeepSeek sub-agent probe (dsh 0.1.1-rc.2)

Date: 2026-09-03. Live, in-process probe through the adapter's `bootRuntime`
(`sesori-deepseek-acp` `main` at `e408ed8`, dsh `0.1.1-rc.2`, model
`deepseek-official/deepseek-v4-flash` from the dsh home defaults). Root-context
listeners on `session/event`, `subagent/start`, `subagent/end`, `agent/status`,
`agent/error`, and a `tools/execute` wrapper. Four parent turns: foreground
`subagent` (`run_in_background: false`), background `subagent` (default,
continuable), two foreground `subagent` calls in one step, and `subagent_fork`.
Facts only; no prompt or transcript text recorded.

## Verdicts

1. **Root listener suffices.** `dsh-scope` `scopeTarget` admits untagged
   (root-context) listeners for every scope, so `subagent/start`,
   `subagent/end`, and every child `session/event` reached the adapter-style
   root listener without per-agent registration. Child `session/event`s arrive
   under the child session object (`session.id` = child id); the adapter's
   current ownership check is what drops them. `context.agents.get(childId)`
   is live at `subagent/start` (`local: true`) and the child header already
   carries `parentSession`, `origin: "subagent"`, `delegationDepth: 1`, and
   the parent's `cwd`.
2. **Ordering.**
   - Foreground (`subagent` with `run_in_background: false`, and
     `subagent_fork`): `tool/call` -> child `turn/start` -> `subagent/start`
     -> child `subagent/descriptor` (about 30 ms after start) -> ... ->
     child `turn/end` -> `subagent/end` -> parent `tool/result`.
   - Continuable (`subagent` default): `tool/call` -> `subagent/start` ->
     parent `tool/result` (3 ms later) -> ... -> child `turn/end` -> parent
     `turn/start` (settlement notice turn) -> `subagent/end` -> parent
     `user/message` with `source.kind: "subagent-settled"`, `form: "notice"`,
     `senderSessionId` = child.
   - One step opened two children before any result: `tool/call` A, B ->
     `subagent/start` A, B (same ms, call order) -> `subagent/end` A ->
     `tool/result` A -> `subagent/end` B -> `tool/result` B.
   - `subagent/start` and `subagent/end` carry only `runId`, `provider`, `id`,
     `local`, and (end) `stopReason` / `lastAssistantMessage`. The parent
     `tool/result` carries no `meta` (`metaKeys: null`); its content is text
     only.
   - **Correlation:** wrapping the root `tools/execute` waterfall in an
     `AsyncLocalStorage` scope keyed by `exec.callId` made every
     `subagent/start` observe the exact executing call id, including the two
     parallel calls in one step (`call_00` -> child A, `call_01` -> child B)
     and the fork. Correlation never fell back; labels are not needed.
3. **Parent idles while a continuable child runs.** The parent reported
   `idle` (turn 2 `completed`) 1.3 s before the child's `turn/end`; the
   settlement then opened parent turn 3 through `followup` with no in-flight
   prompt (`agent/status running`, `turn/start`, then the notice
   `user/message`). Foreground children keep the parent `running` until the
   tool returns.

## Additional findings

- **Blocking defect for the adapter as shipped:** the adapter installs the
  model selection as an agent-scoped `agent/request` waterfall and never sets
  `AgentOptions.provider/model`. dsh children inherit
  `parent.options.provider/model` (`resolveChildAgentOptions`), so under the
  adapter's composition every child fails immediately with
  `agent "<id>" has no provider/model` (`subagent/end` `stopReason: "error"`,
  parent `tool/result` `isError: true`). Reproduced by mirroring the adapter's
  hook (`PROBE_SELECTION=hook`). Passing `agentOptions` at creation, or
  applying the owning root's selection to descendants from a root-level
  `agent/request` listener, makes children run.
- Persisted child headers: `parentSession` = parent, `origin: "subagent"`,
  `delegationDepth: 1`, `cwd` equal to the parent's. Parent header
  `delegationDepth: 0`.
- Child logs: the `subagent/descriptor` event (`version: 2`, `mode:
  "one-shot" | "continuable"`, `provider`, `label`) is appended after
  `subagent/start`; a fork child's log begins with the parent's seed (its
  descriptor sat at seq 403).
- The parent log identifies a continuable child only through the tool result
  text (`started subagent <id>`) and the later `subagent-settled` notice
  (`senderSessionId`, `source.summary`). A foreground child's id never appears
  in the parent log; only the child header's `parentSession` and `createdAt`
  window relate them.
- Approval policy `ask`: no approval request was raised for `subagent` or
  `subagent_fork`.
- Session event counts: parent 450, children 16-29 each (one turn).
