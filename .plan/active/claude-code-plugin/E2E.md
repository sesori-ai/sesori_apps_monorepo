# Claude Code Harness Plugin: Simulator E2E

## Status

- **Date:** 2026-08-11
- **Result:** passed for the Beta gate, with one upstream-only plan-mode check
  not observable during repeated service overloads
- **Product baseline:** Steps 1-15 plus focused live-gate fixes PR #821, #823,
  #825, and #826, ending at `ea1bc354`
- **Scope:** Step 16/17 of `claude-code-plugin`

The run verified Claude Code through the same client, relay, bridge, plugin, and
real CLI path used by the product. It also found four product defects. Each was
fixed in a focused PR and the affected live scenario was repeated before this
record was finalized.

## Environment

- iPhone 17 Pro Max simulator running iOS 26.5.
- Installed Sesori app (`com.sesori.app`), signed into the same account as the
  bridge.
- Source bridge on `127.0.0.1:9977`, using
  `/Users/daniil/.local/share/sesori-dev` as its isolated data directory.
- Real logged-in Claude Code CLI 2.1.226 on PATH.
- Isolated project `/Users/daniil/Developer/sesori-claude-e2e`.
- Hybrid assertions through the simulator and the bridge debug HTTP router.
- YOLO mode disabled for permission and question checks.

## Initial Snapshot

`GET /plugin` reported Claude Code setup `ready`, display name `Claude Code`,
and `supportsPromptAttachments: true`. `POST /session/options` returned real
Claude agents, models, effort variants, and slash commands. The app's new-task
picker showed Claude Code with its bundled brand mark.

## Test Record

| ID | Check | Exact action | Observed result |
|---|---|---|---|
| E2E-01 | Ready discovery | Read `GET /plugin` from the source bridge. | Claude was `ready`, named `Claude Code`, and advertised prompt attachments. |
| E2E-02 | Missing runtime | Restarted with `--claude-bin /definitely/missing/claude`. | Harnesses showed `Runtime missing` and the action hint "Install Claude Code or fix the configured binary path, then retry setup detection." Other harnesses stayed ready. |
| E2E-03 | Picker branding | Opened a new task and selected the coding tool. | Claude Code appeared with its coral brand mark and correct display name. |
| E2E-04 | First streamed turn | Sent `Reply exactly E2E OK.` in a new Claude session. | The session row appeared, the reply streamed, and completed as `E2E OK`. |
| E2E-05 | Reasoning | Selected high effort and sent a reasoning/tool prompt. | A Thought part rendered before the answer. |
| E2E-06 | Tool lifecycle | Asked Claude to list the project directory. | A Bash card progressed through Running to Done with bounded output, followed by `LIST OK`. |
| E2E-07 | Once and reject | Created one file with **Once**, then rejected another Write request. | Once created the file. Reject left its file absent, rendered Write/Failed with the denial, and the model continued with `FIXED REJECT OK` without a false terminal error after PR #825. |
| E2E-08 | Always safety | Tapped **Always Allow** on Write, then requested another Write; separately captured Bash suggestions. | The first write succeeded. The next prompted again because Claude offered only `setMode(session)` for Write and `addRules(localSettings)` plus broader updates for Bash. The registry correctly rejected those unsafe/non-session-rule suggestions and degraded to Once, matching the locked security contract. |
| E2E-09 | Question | Asked Claude to use AskUserQuestion with Alpha/Beta choices and selected Alpha. | A native question card rendered; the answer reached Claude and produced `QUESTION OK Alpha`. |
| E2E-10 | Plan approval | Repeated three minimal Plan-agent prompts requesting ExitPlanMode, including a direct no-delegation form. | Claude's service returned `Our servers are currently overloaded` each time before ExitPlanMode. The card/reply path remains covered by the live 2.1.226 protocol capture and focused plugin tests; no product defect was observed. |
| E2E-11 | Models | Switched mid-session from default to `cx/gpt-5.4-mini` and sent a turn. | The catalog showed real models, the turn returned `MODEL OK`, and the navbar changed to `claude - gpt-5.4-mini`. A later default-model turn restored `gpt-5.6-terra`. |
| E2E-12 | Stop | Stopped a long-running delegated Agent turn, then stopped an active `/review` command after PR #826. | Both returned idle within five seconds. The merged fix prevented a new generic terminal error after the explicit stop. |
| E2E-13 | Abort pending permission | Raised a Write permission and called `/session/abort` while its card was open. | The card and pending snapshot cleared, the file stayed absent, the tool showed cancellation, and the merged interrupt fix suppresses the false terminal result error. |
| E2E-14 | Restart and resume | Restarted the source bridge against the same data directory, reopened the session, and sent `RESUME OK`. | The session list and full history survived, and the follow-up resumed successfully. |
| E2E-15 | External session | Started a real Claude session in an external terminal, ran an explicit Claude catalog import, then pulled to refresh the project. | The external untitled session appeared at the top of the project with the other imported Claude transcripts. |
| E2E-16 | Image input | Attached the simulator's magenta-flower photo and asked for five words. | Claude replied `Brilliant magenta flowers amid yellow blooms.`, correctly describing the image. |
| E2E-17 | Slash commands | Opened the command picker, inspected the real catalog, and ran `/autocompact auto`. | The picker listed built-in and project commands; the selected command completed with `Auto-compact window set to auto`. |
| E2E-18 | Idle reap and resume | Waited more than five minutes after an idle turn, checked process state, then sent `IDLE OK`. | The resident Claude process was reaped, a new `--resume` process spawned, and the follow-up completed transparently. |
| E2E-18a | Model after reap | Compared the navbar before and after the resumed reply. | The navbar stayed on `gpt-5.6-terra`, matching the default model reapplied by the plugin. |
| E2E-18b | Always after reap | Evaluated the grant available from the live CLI before testing restoration. | No eligible session-scoped `addRules` grant was offered, so there was no safe grant to restore. The plugin preserved the same intentional Once degradation across respawn; synthetic tests cover restoration when an eligible grant exists. |
| E2E-19 | Harness policy | Disabled and re-enabled Claude Code from Settings > Harnesses. | Disable removed runtime/work controls. Re-enable restored setup Ready, runtime Active, and work Idle. The client briefly showed a recovered connection-confirmation warning after the committed enabled state was already visible. |
| E2E-20 | Logs and cleanup | Inspected debug logs, stopped each source bridge, and checked for `claude ... stream-json` processes. | Logs contained no unhandled bridge/plugin exceptions. Every shutdown left no Claude process; idle reap also removed the resident process before the next turn. |

## Focused Fixes Found By The Run

1. PR #821 preserved the host environment without duplicating it as launch
   overrides, unblocking real session options and process startup.
2. PR #823 attributed `can_use_tool` frames from their resident process because
   the real CLI omits `session_id` on control requests.
3. PR #825 correlated handled denial `tool_use_id` values so explicit rejection
   continued normally without being misreported as an unprompted denial.
4. PR #826 carried the point-in-time interrupted state on process events so Stop
   and abort did not append a false terminal result error.

## Non-Blocking Limitations

1. **ExitPlanMode service overload:** three live Plan-agent attempts reached the
   real CLI and then received Anthropic overload results before the interaction
   request. The exact CLI 2.1.226 ExitPlanMode shape and approval response were
   verified during protocol grounding, and focused tests cover the client-facing
   registry path. This is an upstream availability limitation, not a code path
   that failed the run.
2. **No safely expressible Always grant:** the current CLI offered only broader
   session mode changes or a rule persisted to local settings. The plugin must
   not widen or persist permissions to make the E2E row pass. It therefore
   degrades to Once exactly as `PROTOCOL.md` requires.
3. **Recovered enable confirmation warning:** re-enabling Claude committed and
   returned Ready/Active/Idle, while the client briefly reported that the
   connection changed before confirmation. The resulting harness state and all
   subsequent operations were correct; this is not Claude-specific.

## Cleanup And Restored State

- Restored the normal Claude binary configuration after the missing-runtime
  check.
- Left Claude enabled, setup-ready, and YOLO mode off in durable bridge state.
- Stopped the final source bridge and confirmed no Claude stream-json process
  remained.
- Left the isolated project and its test transcripts in place so the recorded
  restart, external-import, and history evidence remains reproducible.
- The run consumed the developer's own Claude quota using minimal prompts.
