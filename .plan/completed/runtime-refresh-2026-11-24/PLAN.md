# Runtime refresh, 2026-11-24

Status: completed 2026-11-24. Every step is merged; the remaining verification is listed under follow-ups.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-23 refresh (`.plan/completed/runtime-refresh-2026-11-23/PLAN.md`); no earlier
`runtime-refresh-*` plan was still active. Four harnesses released since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-24.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.4.1 | 2.4.1 | PATH 1.14.0; v2 2.0.11 | None, already newest | — |
| Antigravity | 1.5.2 | 1.5.2 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.171.0 | 0.172.0 (`rust-v0.172.0` `3d86e43b`, npm `latest`); six digests from `codex-package_SHA256SUMS`, matching GitHub digests; macOS arm64 also independently downloaded | 0.139.0 | Step 2 (#2903) | Production managed install on macOS arm64, `codex-cli 0.172.0`; loopback-only probe over stdio and WebSocket: thread list, idle and mid-turn side questions (refusal without `allowInProgressTurn`), rollout unchanged and readable, clean exit |
| GitHub Copilot | 1.0.114 | 1.0.115 (`v1.0.115` `4d1886bb`, npm `latest`); six archives match `SHA256SUMS.txt`, GitHub digests and independent downloads | 1.0.78 | Step 3 (#2902) | Production managed install on macOS arm64; network-denied `--version` and ACP `initialize`, `session/list`, `new`, `load`, `close`, `set_*`, `prompt`, `resume`, `logout` answers identical to 1.0.114 |
| Cursor | 2026.11.22-e9042b2 | 2026.11.22-e9042b2 | date 2026.09.23 | None, already newest | — |
| Claude Code | 2.1.330 | 2.1.331 (`v2.1.331`, npm `latest`); no managed assets; probe archive matches `SHASUMS256.txt` and the GitHub digest | 2.1.221 | Step 4 (#2900) | Network-denied `--version` and stream-json `initialize` on macOS arm64; `--help` output, the 437 matched strings, the control subtype set and the stop/terminal/error value sets unchanged from 2.1.330 |
| Hermes Agent | 0.23.3 | 0.23.4 (`v0.23.4` `8fc03744`) | 0.20.0 | Step 5 (#2901) | Offline install of the tag into isolated roots, `hermes acp --version` 0.23.4; sandboxed, network-denied ACP `initialize` (protocol 1, load/list/resume/fork, `hermes-setup` auth) and empty `session/list`, no leftover processes |
| Pi | 1.6.0 | 1.6.0 | 0.99.0 | None, already newest | — |
| Oh My Pi | 19.1.1 | 19.1.1 | 17.2.13 | None, already newest | — |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.92 | 1.0.92 (`x.ai/cli/stable`) | 1.0.5 | None, already newest | — |

## Steps

1. Plan, docs-only (#2898).
2. Codex 0.171.0 → 0.172.0 (#2903).
3. GitHub Copilot 1.0.114 → 1.0.115 (#2902).
4. Claude Code 2.1.330 → 2.1.331 (#2900).
5. Hermes Agent 0.23.3 → 0.23.4 (#2901).
6. Retire this plan, add the dated run to the regression doc's intro, and note a Codex probe
   pitfall in `references/harnesses.md` (this PR).

Parity work the audit found landed outside the series: Copilot question cards (#2904) and
Codex side questions with their full history on 0.172.0 and later (#2905).

## Findings

### Codex 0.172.0

- Fixed outside the series: `thread/sample` no longer caps prompts at 4,000 bytes (#62378).
  #2903 corrected the comment and capability note; #2905 sends the full side-chat
  history where the runtime allows it, matching Claude Code.
- Track only (experimental API): `thread/sample` accepts an optional `model` (#62419), so side
  questions could use a cheaper model.
- Not applicable: three new spend-limit error kinds (Sesori shows the message as is), Bedrock
  login `providerId`, Daybreak experiment fields, the `approvals_reviewer` config field, a renamed
  experimental realtime item. The app-server method sets are identical (110 requests, 87
  notifications, 10 server requests) and no matched error string changed.
- Track only: thread cwd now goes through a cross-platform path type (still a string on the wire;
  a non-UTF-8 cwd now errors), interrupting a parent keeps queued child-agent replies, earlier
  stream errors and terminal bio/cyber policy errors, a duplicate-initial-context fix.

### GitHub Copilot 1.0.115

- Fixed outside the series (#2904): Copilot now sends standard ACP form questions
  (`elicitation/create`). Sesori advertises forms to Copilot and shows them as question cards,
  matching Oh My Pi; every choice also takes a free-text answer, as Copilot tells its model.
- Track only: ACP respects `permissions.disableBypassPermissionsMode`, "Always allow" appears only
  when session-wide approval is permitted, ACP honours the image-generation setting, smaller and
  faster local sessions, new events in Copilot's own SDK protocol (unused).
- The ACP server lives in the native `runtime.node`, and from 1.0.115 its method names are no
  longer literal strings; the reference now points audits at the probe (fixed in #2902).

### Claude Code 2.1.331

- Track only (`@internal` upstream): a field-less `prompt_draft_activity` control request a host
  sends while the user types, so the CLI can get the next request ready between turns. Older CLIs
  reject it as an unknown subtype.
- Track only: `CLAUDE_CODE_DISABLE_RESPONSE_COMPRESSION` for proxies that cut off compressed replies.
- Not applicable: the `mcp_call_soft_error_result_v1` capability (SDK-hosted MCP only), a
  `sandbox_enabled` key, SDK 0.3.331's `task_notification.output_file` for foreground subagents,
  `updatedInput` reporting on Edit/Write, the `listSessions()` fix, the `sideload_flags_disabled`
  startup reason, and the CLI fixes in the changelog.

### Hermes Agent 0.23.4

- `acp_adapter/` is unchanged and none of the files Sesori's matched copy comes from changed.
- Track only: a plugin can mark a profile as running elsewhere, and `hermes acp` then exits 1
  before starting (Sesori shows a startup failure); gateway-side client identity, a `paused`
  interrupt flag and sandbox approval kinds, none of which the ACP adapter uses.
- Not applicable: canary tags are now `canary.<stamp>-vX.Y.Z`; a canary still prints a version
  the parser accepts.

## Follow-ups

Carried over; each needs credentials, a live client or another host:

- Codex: turns with a real account, the capped side-question path live on a PATH Codex before
  0.172.0, other platforms.
- Copilot: the signed-in lifecycle, an on-device question-card round trip, PATH versions
  1.0.78 to 1.0.114 receiving the form capability, other platforms.
- Claude Code: signed-in stream-json, permissions, replay and interrupt; the live `side_question`
  probe mid-turn and after a cold `--resume`; the rewind-before-compaction refusal recheck (last
  live check 2.1.325); other platforms.
- Hermes: configured or authenticated new/prompt/load/replay and persisted deletion, other platforms.
- Earlier runs' outstanding verification remains in
  `.plan/completed/runtime-refresh-2026-11-23/PLAN.md`,
  `.plan/completed/runtime-refresh-2026-11-21/PLAN.md` and
  `.plan/completed/runtime-refresh-2026-11-20/PLAN.md`.
