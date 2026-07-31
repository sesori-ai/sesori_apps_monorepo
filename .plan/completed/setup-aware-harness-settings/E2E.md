# Setup-Aware Harness Settings: Simulator E2E

## Status

- **Date:** 2026-07-31
- **Result:** passed on the final current-main single-screen Harnesses design
- **Product baseline:** PR #595 merged the original Step 8/8 controls as
  `a30b671b`; PR #647 later consolidated the overview and controls into one
  screen and merged to `main` as `0da8ec7c`
- **Scope:** close the remaining real-simulator gate for
  `setup-aware-harness-settings` and its parent lifecycle plan

This record tests the current product destination. The original Stage 13 plan
described an overview plus a nested management page, but PR #647 intentionally
removed that nested route and folded its controls into the surviving Harnesses
screen. The checks below therefore apply the original lifecycle, timeout,
capability, persistence, and cleanup requirements to that final single screen.

## Environment

- iPhone 17 simulator running iOS 26.5.
- Installed Sesori app (`com.sesori.app`), already signed into the same account
  as the bridge.
- Source bridge and app behavior from the PR #647/current-main code.
- Bridge debug server on `127.0.0.1:9977`.
- Durable bridge data at `~/.local/share/sesori-dev`.
- Existing `random stuff` project used for session behavior.
- The first startup had imported existing project/session catalog data, but the
  bridge database had no test mutations from this E2E run.
- A pre-existing externally managed OpenCode server was already listening on
  `127.0.0.1:4096`. It was treated as unrelated user state and was not stopped
  or replaced.

## Initial Snapshot

`GET /plugin/management` showed:

- Codex, Cursor, and OpenCode setup `ready`;
- all three eligible and enabled;
- default idle timeout `10` minutes;
- no per-harness timeout overrides; and
- normal managed-mode capabilities `lifecycle`, `setupRefresh`, and
  `idleTimeout` for all three harnesses.

The initially connected app had activated the three harnesses while loading
catalog data. Later clean bridge starts correctly returned them to `dormant`
until demand.

## Test Record

| ID | Check | Exact action | Observed result |
|---|---|---|---|
| E2E-01 | Settings navigation | Opened Settings from Projects. | Harnesses was immediately below Notifications in the same grouped settings card. |
| E2E-02 | Final single-screen presentation | Opened Harnesses. | One screen showed the bridge default and all registered harnesses. Codex, Cursor, and OpenCode rendered distinct bundled logos; OpenCode carried the Default badge. Setup/runtime/work facts matched the live management snapshot. |
| E2E-03 | Setup refresh | Tapped **Refresh setup** for Codex. | Codex remained setup `ready`, active, and idle with no action or refresh error. |
| E2E-04 | Safe restart | Tapped **Restart** for idle Codex. | The command completed and Codex returned active/idle without an error. |
| E2E-05 | Per-harness no-timeout override | Opened Codex **Idle timeout**, selected **No timeout**, and saved. | The Prego sheet closed, the card showed “This harness stays running / No timeout,” and the bridge reported `idleTimeoutMins: 0` with `hasIdleTimeoutOverride: true`. |
| E2E-06 | Clear timeout override | Tapped **Use bridge default** for Codex. | The override cleared, the card returned to 10 minutes, and the bridge reported `hasIdleTimeoutOverride: false`. |
| E2E-07 | Apply one timeout to all | Opened **Default idle timeout**, selected Custom, entered `12`, and saved. | The bridge default and every capable harness changed to 12 minutes; all per-harness override flags remained false. |
| E2E-08 | Persistence across bridge process restart | Sent `POST /global/restart`, observed the app enter **Loading harnesses**, then relaunched the source bridge against the same absolute data directory when the detached source handoff did not return. | After reconnect, the app and bridge still showed the 12-minute default for all three harnesses with no overrides. This verifies durable settings persistence across shutdown/start and client reconnection. See the source-handoff follow-up below. |
| E2E-09 | Restore timeout baseline | Set the global custom timeout back to `10`. | Default and effective timeouts returned to 10 minutes with no overrides. |
| E2E-10 | Safe disable and enable | Disabled dormant Codex, inspected the card, then enabled it again. | Disable produced runtime `disabled`; the card kept setup context and the enable/setup actions while hiding runtime/work/restart/timeout facts. Enable re-inspected setup and returned Codex active/idle. |
| E2E-11 | Create from resulting harness state | Opened `random stuff`, created a Codex session with Dedicated worktree off, and submitted: ``E2E lifecycle test: run `sleep 90`, then reply exactly E2E COMPLETE. Do not modify any files.`` | The session was created successfully, appeared as Running, and Codex management work state became `busy`. No worktree or file change was created. |
| E2E-12 | Busy safe-conflict copy | While the session was busy, toggled Codex off. | Safe disable produced a non-dismissible Prego confirmation sheet titled **Force disable harness?** with the warning that active work may be interrupted and the action is sent once. |
| E2E-13 | Force cancellation | Tapped **Cancel** on the first confirmation. | No force mutation was sent; Codex remained active/busy and the session remained Running. |
| E2E-14 | Explicit one-shot force | Repeated safe disable and tapped **Force action** once. | Codex became disabled with unknown work state. The test session stopped showing Running but remained visible in the session list. |
| E2E-15 | Forced-disable session reconciliation | Re-enabled Codex and reopened the test session. | Messages loaded again and retained the interrupted turn, including aborted sleep-tool output. The session was not lost or left falsely running. |
| E2E-16 | Attach-only capability declaration | Stopped only the E2E bridge and started it with `--opencode-no-auto-start --opencode-port=4096`, attaching to the pre-existing server. | The bridge published only `setupRefresh` for OpenCode, effective timeout `0`, setup `ready`, and runtime `dormant`. The unrelated OpenCode process remained running. |
| E2E-17 | Attach-only UI enforcement | Inspected the OpenCode card and tapped its remaining setup refresh action. | The card showed **Managed outside Sesori** and explained that Sesori would not start, stop, restart, or suspend it. Enable/disable, restart, and timeout controls were absent; **Refresh setup** remained and completed with setup still ready. |
| E2E-18 | Return to managed mode | Stopped only the attach-mode bridge and restarted the ordinary source bridge without attach flags. | The app reconnected and OpenCode again exposed normal lifecycle/setup/timeout controls. The pre-existing server on port 4096 remained untouched. |

## Cleanup And Restored State

- Deleted the E2E Codex session from `random stuff`; a final `/sessions` query
  found no session titled `E2E lifecycle test`.
- Dedicated worktree was disabled for the test session, and the turn performed
  only sleep commands; no project file changes were produced.
- Restored the bridge default timeout to 10 minutes.
- Confirmed Codex, Cursor, and OpenCode are setup-ready, enabled, and have no
  per-harness timeout overrides.
- Confirmed ordinary managed-mode capabilities are restored for all three.
- Left the source bridge running normally on debug port 9977 against the same
  durable data directory.
- Left the simulator on the Projects surface.
- Did not stop, replace, or reconfigure the pre-existing OpenCode server on
  port 4096.

## Follow-Up Candidates

These are explicit follow-up options, not blockers for the Stage 13 lifecycle
and persistence gate completed above:

1. **Restart handoff on the post-test tilde fix:** the debug restart request
   acknowledged and shut down the source `dart run` process, but its detached
   successor did not return on port 9977. Manual source relaunch against the same
   absolute data directory proved persistence and reconnection. PR #651
   (`7ad9ceed`) subsequently fixed `~` expansion for `--data-dir`; repeat the
   source or installed-binary handoff on #651 or later if restart handoff itself
   needs release evidence.
2. **Busy force-restart variant:** this run exercised safe conflict, cancel, and
   one-shot force through disable. Widget and service suites cover restart; a
   later manual pass can repeat the busy flow with Restart if desired.
3. **Real older bridge unsupported state:** no older bridge fixture was
   available. Unsupported and failed-refresh presentation remain covered by
   focused contract/widget tests.
4. **Unknown harness/generic logo:** the normal bundled bridge advertises only
   the three known harnesses, so the forward-compatible generic card remains a
   widget/contract test case.
5. **Invalid custom timeout:** this pass verified no-timeout `0`, positive custom
   apply-all, override, and clear. Invalid/non-positive custom input remains
   covered by focused widget/service tests and can be repeated manually if a
   UI-validation-specific follow-up is requested.
