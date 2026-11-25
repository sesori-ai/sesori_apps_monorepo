# Runtime refresh, 2026-11-25

Status: completed 2026-11-25. Every step is merged; the remaining verification is listed under follow-ups.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-24 refresh (`.plan/completed/runtime-refresh-2026-11-24/PLAN.md`); no earlier
`runtime-refresh-*` plan was still active. Three harnesses released since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-25.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.4.1 | 2.4.1 | PATH 1.14.0; v2 2.0.11 | None, already newest | — |
| Antigravity | 1.5.2 | 1.5.2 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.172.0 | 0.172.0 (`rust-v0.172.0`, npm `latest`) | 0.139.0 | None, already newest | — |
| GitHub Copilot | 1.0.115 | 1.0.115 (`v1.0.115`, npm `latest`) | 1.0.78 | None, already newest | — |
| Cursor | 2026.11.22-e9042b2 | 2026.11.22-e9042b2 | date 2026.09.23 | None, already newest | — |
| Claude Code | 2.1.331 | 2.1.332 (`v2.1.332` `eb8e6d25`, npm `latest`); no managed assets; probe archive matches `SHASUMS256.txt` and the GitHub digest | 2.1.221 | Step 2 (#2934) | Network-denied `--version` and stream-json `initialize` on macOS arm64; `--help` and login help byte-identical to 2.1.331; every plugin string literal still present; error, result, stop and terminal value sets unchanged; control subtypes 179 → 181 |
| Hermes Agent | 0.23.4 | 0.23.4 (`v0.23.4`) | 0.20.0 | None, already newest | — |
| Pi | 1.6.0 | 1.6.1 (`v1.6.1` `ef4a1cfc`, npm `latest`); six archives match `SHA256SUMS`, GitHub digests and independent downloads | 0.99.0 | Step 3 (#2935) | Production managed install on macOS arm64, `--version` 1.6.1; sandboxed, network-denied RPC `get_state`, `get_commands`, thinking levels, model list and logged-out prompt failure identical to 1.6.0 |
| Oh My Pi | 19.1.1 | 19.2.0 (`v19.2.0` `5c5ecb16`); eight binaries match GitHub digests, `SHA256SUMS.txt` and independent downloads | 17.2.13 | Step 4 (#2936) | Production managed install on macOS arm64, `omp/19.2.0`; loopback-only ACP probe (initialize, modes, empty `session/new`, delete, removed-model restore error, `models --json`, Sesori MCP reach, `--plugin-dir` skill listing) identical to 19.1.1, no leftover processes |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.92 | 1.0.92 (`x.ai/cli/stable`) | 1.0.5 | None, already newest | — |

## Steps

1. Plan, docs-only (#2933).
2. Claude Code 2.1.331 → 2.1.332 (#2934).
3. Pi 1.6.0 → 1.6.1 (#2935).
4. Oh My Pi 19.1.1 → 19.2.0 (#2936).
5. Retire this plan and add the dated run to the regression doc's intro (this PR).

No parity work came out of this run.

## Findings

### Claude Code 2.1.332

- Owner question (review page sent 2026-11-25): the CLI now treats mid-turn SDK and `-p`
  messages as typed by the user in more setups (including Opus 4.8 and later), and upstream asks
  hosts to mark text the user didn't type with `isSynthetic: true`. Sesori sends its own prompts
  (PR Monitor reports, wake-ups, task runs) as plain user text, so mid-turn they may count as user
  intent in auto mode's checks. Marking them needs a prompt-origin field from the bridge to the
  Claude plugin; Sesori's replay already reads `isSynthetic` as harness-generated, so marked
  Sesori messages must keep their Sesori Automation look.
- Probe first: `set_permission_mode` now answers with the mode actually in effect. Sesori ignores
  the reply; reading it could show when the CLI picks a different mode.
- Track only (internal, host-optional): `set_peer_delivery` and `decide_held_peer_message` control
  requests for held messages from other sessions.
- Not applicable: the CLI no longer reads replies starting "You've hit your…" as usage-limit errors
  (Sesori's quota mapper already needs the `rate_limit` tag); fork Agent calls now finish when they
  finish; `reason:` value changes Sesori doesn't match; SDK `tool_result_meta[].rewritten_by_plugin`;
  MCP skills, the `PreSkillShellCommand` hook, IDE and cloud model alias items.

### Pi 1.6.1

- Every file Sesori depends on (`rpc-types.ts`, `json-event.ts`, `agent/src/types.ts`,
  `auth-guidance.ts`, `agent-session-services.ts`, `extensions/index.ts`) is byte-identical;
  `StopReason`, session version 3 and every matched error text are unchanged.
- Track only: more temporary provider failures retry automatically (events Sesori already
  handles); a `request_too_large` code inside a longer code no longer compacts and retries; Bash
  results gain an optional `fullOutputError`; a failing stored `!command` key reports the provider
  as not configured; `showCacheMissNotices` becomes four `notices.*` settings; `after_provider_response`
  also fires on HTTP errors and retries.
- Not applicable: TUI-only changes (dialog `blockedKind`), codemode, provider and model-list
  fixes, the bundled MCP extension refactor, `pi update` under WSL.

### Oh My Pi 19.2.0

- The ACP code barely changed: a `skill:` command now passes the prompt's images, and `plan` mode
  is hidden in `--no-tools` sessions (Sesori never starts those). Stop reasons, `session/*`,
  cancel and every matched string are unchanged.
- Track only: with `providers.maxInFlightRequests` set, model requests go through the shared
  daemon, which the bridge already leaves running; the fallback language-server spawn gets its own
  process group but stays a child of `omp` (source only, not live); `session/new` uses each
  project's `enabledModels`; shared workers unload after 15 idle minutes; a missing required tool
  call carries `AgentLoopError` metadata; custom OpenAI/Anthropic-compatible hosts get an
  `x-session-id` header; MCP handshake is stdio-first with an HTTP fallback (Sesori's `-32601`
  answer to `server/discover` still works).
- Not applicable: the TUI rebuild and Vim mode, queued-input interrupts, cross-instance messaging,
  rewind and `--continue`, `${CLAUDE_PLUGIN_ROOT}` substitution, new logins, provider and catalog
  fixes.

### Skill and reference

- Pi probe pitfall: the fake `ProcessException` needs `errorCode` 2 (ENOENT), which
  `IoHostExecutableLocator.isProcessMissingError` checks (fixed in #2935).
- Claude and Codex side-question probes: the reference said every refresh runs them live, but
  they need a signed-in account or a local test provider, and offline runs carried them as
  follow-ups. The reference now says so (this PR).
- OMP: the detached-spawn grep now also finds the language-server spawn in `lsp/client.ts`
  (expected); `git grep` over a full source clone can hit the 10-minute tool limit, so search the
  saved diff instead (this PR).

## Follow-ups

Carried over; each needs credentials, a live client or another host:

- Claude Code: the `isSynthetic` answer on the review page; signed-in stream-json, permissions,
  replay and interrupt; the live `side_question` probe mid-turn and after a cold `--resume`; the
  rewind-before-compaction refusal recheck (last live check 2.1.325); other platforms.
- Pi: authenticated settlement, retry, compaction, queue and fresh-process reuse; other platforms.
- Oh My Pi: the authenticated lifecycle, the live tool-title check, the live daemon and
  language-server tree-stop, the busy-window probes, a live `ask` form, other platforms
  (including Windows ARM64).
- Earlier runs' outstanding verification remains in
  `.plan/completed/runtime-refresh-2026-11-24/PLAN.md`,
  `.plan/completed/runtime-refresh-2026-11-23/PLAN.md`,
  `.plan/completed/runtime-refresh-2026-11-21/PLAN.md` and
  `.plan/completed/runtime-refresh-2026-11-20/PLAN.md`.
