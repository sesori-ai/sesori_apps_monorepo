# Antigravity Sub-Agent ACP Probe

## Status and disposition

Completed 2026-09-12 against Google's official managed Antigravity ACP package
`1.0.0`, exact runtime identity `agy_acp_server_20260818_01_RC01`.

Native internal delegation was observed, but the official ACP projection does
not expose enough authoritative state for Sesori inline subtasks. Antigravity
therefore remains generic-tool-only for this feature: no inline subtask tile,
child transcript, descendant lifecycle/busy state, or scoped sub-agent stop.
This is a completed unsupported disposition, not unfinished implementation and
not a claim that native Antigravity lacks sub-agents.

## Authorization, isolation, and cleanup

The user authorized one bounded live probe using Sesori's existing authenticated
Antigravity profile, accepted provider quota use, and accepted Google-side
conversation residue that Sesori cannot delete. Token contents were never read,
printed, copied, or changed.

- Used only pinned server/harness siblings already installed beneath Sesori's
  Antigravity state.
- Preserved production runtime pin, account-selected model, approval policy,
  global configuration, and existing bridge processes.
- Used mode `default`, a sanitized no-inheritance environment, and an owned
  temporary workspace. Browser launch was suppressed.
- Accepted only one exact warning-free `allow_once` option per invocation. No
  persistent approval was selected; unsupported requests would have been
  cancelled.
- Captured only bounded structural facts. No prompt, transcript, token, raw ID,
  permission payload, provider response, screenshot, or private log was
  published.
- Removed every owned local conversation metadata/database file, temporary
  workspace, probe script, and process. One unrelated existing conversation and
  the installed runtime/profile remained untouched. No owned probe process
  remained. Google-side residue may remain under the accepted provider boundary.

## Executed cases

1. Initialized and authenticated the pinned ACP pair with the existing isolated
   profile, created one owned root session, forced mode `default`, and requested
   exactly one bounded reasoning-only sub-agent.
2. Resumed that same root on a fresh ACP process and requested exactly one
   built-in `self` sub-agent for a second deterministic reasoning task.
3. Replayed the first turn through standard `session/load` on a fresh process.
4. Listed sessions before and after root creation to detect independently
   exposed child sessions.

Both live root prompts returned `stopReason: end_turn`; assistant output included
the expected deterministic result after sub-agent-labelled tool activity. This
proves that native delegation was attempted and produced a usable root result.
It does not make assistant text lifecycle authority.

No child-cancellation case was run. The seam exposed no child target, child
listing, or child-cancel method to exercise. Standard root `session/cancel` is
already available through shared ACP, but whole-turn cancellation cannot prove
or implement any sub-agent-specific stop policy.

## Privacy-safe wire facts

- `initialize` advertised standard ACP load/list/resume capabilities and no
  child-session or sub-agent extension.
- Every observed notification was standard `session/update`; every update used
  only the root session ID. No extension notification appeared.
- Live `invoke_subagent` input contained one `Subagents` item with `Model`,
  `Prompt`, `Role`, and `TypeName`; it contained no child ID. Both invocations
  transitioned `pending` → `failed` after permission resolution even though the
  root returned the requested result.
- Nested activity appeared as additional generic parent-local `other` tool
  calls. One case also exposed a generic `manage_subagents` call and a nested
  read. No field correlated these calls to a child identity or authoritative
  lifecycle.
- `session/list` grew by exactly one: the owned root. No child session appeared.
- `session/load` replayed the recorded `invoke_subagent`, nested generic call,
  and read as `completed`. Replay string-encoded structured raw input and
  supplied blank raw output. It exposed no child identity, child transcript, or
  lifecycle extension.
- Live and replay therefore disagree on invocation status and raw shape. Neither
  form exposes background/foreground mode, independent completion, child
  ancestry, or cancellation authority.

## Capability decision

| Capability | Disposition | Reason |
|---|---|---|
| Inline subtask tile | Not supported | Generic parent-local calls lack authoritative child identity/lifecycle; live and replay status conflict. |
| Child transcript/session | Not supported | No child ID/session/list row or child-scoped replay target crosses ACP. |
| Descendant busy/root residency | Not supported | Root prompt lifetime is observable; independent descendant lifetime is not. |
| Confirm/count running sub-agents | Not supported | No authoritative running-child set exists. |
| Stop all sub-agents | Not supported as scoped policy | Only whole-root `session/cancel` is available; descendant settlement is unobservable. |
| Stop child only | Not supported | No child target or child-cancel method crosses ACP. |
| Stop root while retaining children | Not supported | No background/independent child lifecycle is exposed. |

Keep native calls generic. Do not infer support from binary symbols, public
Antigravity SDK/CLI documentation, tool names, prompt-bearing raw input, call
order, assistant claims, replay's `completed` status, or the shared ACP child
tracker existing in Sesori. Reassess only when a later official ACP runtime
exposes stable typed child identity plus lifecycle and replay semantics;
sub-agent stop additionally needs exact-child or native-subtree cancellation
authority.

## Records updated

- `docs/HARNESS_CAPABILITIES.md`
- `docs/ANTIGRAVITY.md`
- `docs/regression/antigravity-live-replay-updates.md`
- `docs/regression/tools-and-file-changes.md`
- `docs/regression/session-turns.md`
- `docs/regression/session-history-and-recovery.md`
- `.plan/completed/claude-inline-subtasks/{PLAN.md,HARNESS_FOLLOWUPS.md,TRACKER.md}`
