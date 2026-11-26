# Runtime refresh, 2026-11-26

Status: completed 2026-11-26. Every step is merged; the remaining verification is listed under follow-ups.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-25 refresh (`.plan/completed/runtime-refresh-2026-11-25/PLAN.md`); no earlier
`runtime-refresh-*` plan was still active. Three harnesses released since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-26.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.4.1 | 2.4.2 (`@opencode/cli` npm `latest`, `v2.4.2` `fc31a485`); six tarballs match npm integrity and an independent `npm pack`; the GitHub release zip matches its digest and holds a byte-identical binary | PATH 1.14.0; v2 2.0.11 | Step 2 (#2941) | Production managed install on macOS arm64, `opencode v2.4.2`; sandboxed loopback `serve`: auth, `/api/event`, the agent/model/provider/command/skill/permission/form and session lists decode through regenerated models; v2 models gain only an optional `Agent.Info.instructions`, SSE output unchanged |
| Antigravity | 1.5.2 | 1.5.2 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.172.0 | 0.172.0 (`rust-v0.172.0`, npm `latest`) | 0.139.0 | None, already newest | — |
| GitHub Copilot | 1.0.115 | 1.0.116 (`v1.0.116` `641556c6`, npm `latest`); six assets match GitHub digests, `SHA256SUMS.txt` and independent downloads | 1.0.78 | Step 3 (#2942) | Production managed install on macOS arm64, `GitHub Copilot CLI 1.0.116.`; network-denied, unauthenticated ACP initialize and session/model/mode/config/logout calls identical to 1.0.115 |
| Cursor | 2026.11.22-e9042b2 | 2026.11.22-e9042b2 | date 2026.09.23 | None, already newest | — |
| Claude Code | 2.1.332 | 2.1.332 (`v2.1.332`, npm `latest`) | 2.1.221 | None, already newest | — |
| Hermes Agent | 0.23.4 | 0.23.4 (`v0.23.4`) | 0.20.0 | None, already newest | — |
| Pi | 1.6.1 | 1.6.1 (`v1.6.1`, npm `latest`) | 0.99.0 | None, already newest | — |
| Oh My Pi | 19.2.0 | 19.2.1 (`v19.2.1` `b55cd1bb`); eight binaries match GitHub digests, `SHA256SUMS.txt` and independent downloads | 17.2.13 | Step 4 (#2940) | Production managed install on macOS arm64, `omp/19.2.1`; loopback-only ACP probe (initialize, modes, empty `session/new`, delete, removed-model restore error, `models --json`, Sesori MCP reach, skill fixture) identical to 19.2.0, no leftover processes |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.92 | 1.0.92 (`x.ai/cli/stable`) | 1.0.5 | None, already newest | — |

## Steps

1. Plan, docs-only (#2939).
2. OpenCode 2.4.1 → 2.4.2 (#2941).
3. GitHub Copilot 1.0.115 → 1.0.116 (#2942).
4. Oh My Pi 19.2.0 → 19.2.1 (#2940).
5. Retire this plan and add the dated run to the regression doc's intro (this PR).

Fix outside the series: #2943 hides Oh My Pi's harness notices from replayed history (below).
No parity work came out of this run.

## Findings

### OpenCode 2.4.2

- Owner question (review page sent 2026-11-26): OpenCode's own clients now take back a message
  stopped before the model writes anything and put it back in the composer. Sesori has no such
  undo on any harness.
- Track only (experimental upstream): push device endpoints and `experimental.push.updated`, the
  experimental session working directory and `cd` tool, the `compaction_jobs` and `mcp_skills`
  flags.
- Not applicable: the sub-agent report envelope, `aborted` and matched copy are unchanged;
  OpenAPI changes are descriptions plus a `502 SkillLoadError`; sending to an archived session
  unarchives it (Sesori archives in the bridge); "Always allow" for web fetch saves one site;
  `generate_image`/`generate_video` moved into Code Mode; moving a session moves its subagents.

### GitHub Copilot 1.0.116

- Owner question (same page): a new "Context Size" session option for supported models. Sesori
  offers no context-size choice on any harness.
- Probe first: the option's ACP `category`. Sesori's shared ACP option parser takes the first
  option of `model`, `mode` and `thought_level`; if Context Size reused one of those and came
  first, it would be read as the model or effort picker. Needs a signed-in `session/new`.
- Track only: `allow_all` gains an `auto` value (an LLM approves requests it judges safe, "Not a
  security boundary"); Sesori doesn't set it. New "Task completion blocked. Human review is
  required before continuing." tool text, which Sesori doesn't match. Experimental SDK types and
  `occurredAt` on sub-agent events.
- Not applicable: shell approval prompts now show the command (Sesori shows the agent's title);
  TUI, `/` command, sandbox, MCP sign-in and search changes.

### Oh My Pi 19.2.1

- Fixed in #2943: `bash.reapBackground` (on in ACP mode) adds a `<system-reminder>` developer
  message and one more turn when a bash call leaves a process running. OMP replays developer
  messages as plain `user_message_chunk`s with no marker (offline probe confirmed), so they showed
  as user bubbles after a reload, older notices included. The OMP plugin now drops replayed user
  turns that are one whole OMP harness-tag block (`irc`, `tangent-notice`, `system-*`). Untagged
  notices (`auto-continue`, `interrupted-thinking`, plan-execution prompts) still replay as user
  turns.
- Track only: a process adopted with `o2ctl services add` stays in `omp`'s tree, so the bridge's
  stop ends it although OMP now promises it survives (it died on stop before too); cancelled or
  timed-out shell commands now also end descendants in other groups; queued follow-ups drain the
  same way at any conversation end; the Copilot 1M catalog fix.
- Not applicable: no ACP code change, no matched string in any changed line, no new detached
  spawn; Perl builtin, TUI, `history://`, `/fast`, `agent://` and OAuth catalog changes.

### Skill and reference (this PR)

- OpenCode: npm publishes no SHA-256; the GitHub release zip gives an upstream digest
  cross-check.
- Copilot: verified range now 1.0.112 to 1.0.116; session option labels in `runtime.node` reveal
  new options offline, and a new option's category needs the authenticated check above.
- OMP: the `bash.reapBackground` reminder, the replay filter's tag set and the adopted-service
  stop behaviour are now per-bump checks.

## Follow-ups

Carried over; each needs credentials, a live client or another host:

- OpenCode: provider turns, a live sub-agent report, the event-stream lifecycle, history/write
  parity, native reconnect, upgrade from v1, other platforms; the take-back answer.
- GitHub Copilot: the authenticated lifecycle, the Context Size option's category and values,
  other platforms; the context-size answer.
- Oh My Pi: the authenticated lifecycle, a live leftover-process reminder and adopted service, the
  live tool-title check, the live daemon and language-server tree-stop, the busy-window probes, a
  live `ask` form, other platforms (including Windows ARM64).
- Earlier runs' outstanding verification remains in
  `.plan/completed/runtime-refresh-2026-11-25/PLAN.md`,
  `.plan/completed/runtime-refresh-2026-11-24/PLAN.md`,
  `.plan/completed/runtime-refresh-2026-11-23/PLAN.md`,
  `.plan/completed/runtime-refresh-2026-11-21/PLAN.md` and
  `.plan/completed/runtime-refresh-2026-11-20/PLAN.md`.
