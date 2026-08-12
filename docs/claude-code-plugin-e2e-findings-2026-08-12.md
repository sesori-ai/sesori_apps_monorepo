# Claude Code Plugin: User-Focused E2E Findings

## Scope

- **Date:** 2026-08-12
- **Result:** five user-visible issues found; no product fixes applied
- **App:** installed Sesori app (`com.sesori.app`) on iPhone 17 Pro Max simulator,
  iOS 26.5
- **Bridge:** source-run from merged `main` at `2bc60ae3`, using
  `<SESORI_DEV_DIR>`
- **Claude Code:** authenticated CLI 2.1.227
- **Project:** `<CLAUDE_E2E_PROJECT>`
- **Permissions:** YOLO mode off
- **Bridge log:** retained locally outside the repository

Testing used the real mobile client, relay, source bridge, Claude plugin, and
authenticated Claude CLI. This report records observed product behavior only.
No source, test, configuration, or persisted-data fix was made.

The companion screenshot
[`claude-code-plugin-e2e-findings-2026-08-12.png`](claude-code-plugin-e2e-findings-2026-08-12.png)
captures the restored session after the run, including persisted Stop recovery
artifacts and the rejected stale ExitPlanMode request. Live-only duplicate
rendering is recorded in the reproduction evidence below.

## Findings

### CCE2E-01: Live assistant text is rendered twice

- **Severity:** High
- **Frequency:** Frequent, but not every response
- **User impact:** Users see duplicated answers and cannot tell whether Claude
  intentionally repeated itself or Sesori duplicated the message.

#### Reproduction

1. Create a Claude Code session from the mobile app.
2. Send `Think briefly about 17*19, then reply exactly REASON 323.`
3. Observe the completed assistant response.
4. Repeat with a model switch, a question response, plan approval, or image input.

#### Expected

One assistant text part containing the response once.

#### Actual

The live session rendered the same text twice inside one assistant message:

- `REASON 323` twice.
- `MODEL MINI OK` twice after switching to `cx/gpt-5.4-mini`.
- `QUESTION Alpha` twice after answering the native question card.
- `Plan created and approval requested.` twice after ExitPlanMode approval.
- `Vibrant magenta and yellow flowers.` twice after image input.
- `RESTART OK` and `DEFAULT RESTORED` twice on later turns.

Simple responses such as `FRESH E2E OK`, `TOOL OK`, `ONCE OK`, and
`POST PLAN OK` rendered once, so the defect is intermittent rather than a fixed
two-copy transcript shape.

#### Persistence evidence

After restarting the bridge and reopening the session, replay showed one copy of
previously duplicated responses such as `Vibrant magenta and yellow flowers.`,
`Interrupted.`, and the post-interruption response. The duplicate therefore
appears to be in live event rendering/state rather than the persisted Claude
transcript.

### CCE2E-02: Approved ExitPlanMode leaves the session in Plan mode

- **Severity:** Critical
- **Frequency:** Reproduced consistently in this run
- **User impact:** After approving implementation, ordinary follow-up requests
  continue in Plan mode and can unexpectedly request plan approval instead of
  executing or replying normally. The wrong mode survives a bridge restart.

#### Reproduction

1. Select the `Plan` agent.
2. Send: `Create a minimal one-step plan to add a file named plan-probe.txt,
   then request approval with ExitPlanMode. Do not use subagents.`
3. Select `Approve`, then submit the answer.
4. Confirm Claude creates `plan-probe.txt`.
5. Observe the composer agent selector.
6. Restart the bridge and reopen the session.
7. Send `Reply exactly RESTART OK.`

#### Expected

Approving ExitPlanMode returns the session and composer to `Default`. The next
turn behaves as an ordinary execution/chat turn, including after restart.

#### Actual

- The implementation ran and `plan-probe.txt` was created.
- The agent selector remained `Plan`.
- A subsequent Write turn executed but the selector still remained `Plan`.
- After bridge restart, the selector still showed `Plan`.
- The simple `RESTART OK` request raised another Plan approval card containing
  the previous `Add plan-probe.txt` plan instead of replying normally.
- Manually selecting `Default` restored normal behavior.

This is not only a stale label: the persisted selection changed subsequent turn
behavior.

### CCE2E-03: Slash command completion temporarily replaces the model with `<synthetic>`

- **Severity:** Medium
- **Frequency:** Reproduced with `/autocompact auto`
- **User impact:** The session header reports an invalid-looking model value,
  making users doubt which model will handle the next turn.

#### Reproduction

1. Open the Slash commands picker in a Claude session.
2. Select `/autocompact`, enter `auto`, and send.
3. Observe the session subtitle after the successful command result.

#### Expected

The subtitle preserves the selected/applied Claude model, such as
`claude · gpt-5.6-terra`.

#### Actual

The command succeeded and rendered `Auto-compact window set to auto`, but the
subtitle changed to `claude · <synthetic>`. A later model-stamped turn restored a
real model name.

### CCE2E-04: Stop contaminates the next turn with recovery messages

- **Severity:** High
- **Frequency:** Reproduced once in the focused Stop sequence
- **User impact:** After stopping work, users see internal recovery content as
  conversation messages and the next request does not begin from a clean state.

#### Reproduction

1. Send `Use Bash to run sleep 30, then reply STOP SHOULD NOT APPEAR.`
2. While the command is active, tap `Stop`.
3. Confirm the session returns idle and shows `[Request interrupted by user]`.
4. Send a new request:
   `Use Write to create fresh-abort.txt containing abort. Wait for my permission.`

#### Expected

The stopped turn ends with one user-facing interruption marker. The next request
starts normally and contains no internal recovery instructions.

#### Actual

Before completing the next request, the transcript rendered:

- Thought: `Suppressing output after interruption`.
- A user-styled synthetic message:
  `[Your previous response had no visible output. Please continue and produce a user-visible response.]`
- `Interrupted.` duplicated in live rendering.
- `I’ll wait for your permission before creating fresh-abort.txt.` duplicated in
  live rendering.

No false generic terminal error appeared, and Stop itself returned idle, but the
subsequent conversation was polluted by recovery artifacts.

### CCE2E-05: Model changes expose raw Claude control output as a user message

- **Severity:** Medium
- **Frequency:** Reproduced on model changes
- **User impact:** Users see protocol-oriented XML-like text in the chat rather
  than a normal product status, adding noise and exposing backend implementation
  details.

#### Reproduction

1. Open the model picker in an active Claude session.
2. Select `cx/gpt-5.4-mini` and send a turn.
3. Later select the default model/Plan combination and send another turn.

#### Expected

The model selector and session subtitle update without adding backend control
payloads to the conversation, or a concise product-native status is shown.

#### Actual

The transcript rendered raw control output as blue user-style messages, including:

```text
<local-command-stdout>Set model to haiku (cx/gpt-5.4-mini)</local-command-stdout>
```

and:

```text
<local-command-stdout>Set model to cx/gpt-5.6-terra[1m]</local-command-stdout>
```

The selected model itself was applied correctly.

## Passing Scenarios

The following user-facing Claude Code scenarios passed in this run:

- Plugin discovery reported Claude Code Ready with attachment support.
- New-task picker selected Claude Code and created a session.
- First response streamed and the session title updated.
- Reasoning/Thought content rendered.
- Model catalog loaded and a mid-session model switch applied.
- Bash tool lifecycle rendered Thought, Running/Done, and bounded output.
- Write permission `Once` created the requested file.
- Reject left the file absent, rendered Write/Failed, and let Claude continue.
- `Always Allow` safely degraded to Once when no eligible session-scoped grant
  was available; the next Write prompted again.
- AskUserQuestion rendered Alpha/Beta choices and returned Alpha to Claude.
- ExitPlanMode rendered a real plan card on CLI 2.1.227; approval executed the
  plan and created the file.
- Image attachment reached Claude and was described correctly.
- Slash-command catalog loaded and `/autocompact auto` executed successfully.
- Stop returned idle and did not append a generic terminal error.
- Bridge restart preserved the session list and replayed history.
- External Claude CLI transcript import added `External import reply`, with the
  correct prompt, response, and model visible in the app.
- Disabling Claude removed runtime/work controls; re-enabling restored
  Ready/Active/Idle without the previously observed confirmation warning.
- Missing runtime showed `Runtime missing` and the actionable install/path hint,
  while other harnesses remained ready.
- Restoring the normal binary returned Claude to Ready.

## Not Fully Re-verified

- A fresh ten-minute idle-reap wait was not repeated. Restart/resume and model
  restoration were exercised, and the earlier Beta gate covered idle reap, but
  this run does not add new idle-timer evidence.
- Pending-permission abort was attempted after Stop, but CCE2E-04 altered the
  next turn before a permission card was raised. The earlier Beta gate covered
  aborting a pending permission; this run does not claim fresh evidence for it.

## Restored State

- Claude Code is enabled, setup-ready, Active, and idle.
- YOLO mode remains off.
- The normal `claude` binary configuration is restored.
- The source bridge remains running against `<SESORI_DEV_DIR>` so
  the findings can be reviewed in the simulator.
- No Claude `stream-json` process remains while the restored harness is idle.
- Test files and transcripts remain in `<CLAUDE_E2E_PROJECT>` for
  reproduction.
