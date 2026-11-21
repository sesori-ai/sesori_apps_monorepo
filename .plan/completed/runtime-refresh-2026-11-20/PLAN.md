# Runtime refresh, 2026-11-20

Status: completed 2026-11-20. Every step is merged; the remaining verification is listed under final follow-ups.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-19 refresh (`.plan/completed/runtime-refresh-2026-11-19/PLAN.md`, retired in the same PR);
six harnesses released again since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-20.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.3.2 | 2.3.2 | PATH 1.14.0; v2 2.0.11 | None, already newest | — |
| Antigravity | 1.5.0 | 1.5.0 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.170.0 | 0.171.0 (`rust-v0.171.0` → `ccf9be8c`); 6 packages match `codex-package_SHA256SUMS` and GitHub digests | 0.139.0 | Step 2 (#2865) | Managed install, stdio and WebSocket `initialize`/`thread/list`, idle and mid-turn `thread/sample` against a loopback model fixture on macOS arm64 pass; real-account turns pending |
| GitHub Copilot | 1.0.114 | 1.0.114 | 1.0.78 | None, already newest | — |
| Cursor | 2026.11.19-f005e9d | 2026.11.19-f005e9d | date 2026.09.23 | None, already newest | — |
| Claude Code | 2.1.328 | 2.1.330 (`e791a1c4`; range includes 2.1.329); npm `latest`; probed archive matches `SHASUMS256.txt` and GitHub digest | 2.1.221 | Step 3 (#2863) | `--version`, `--help` flags and unauthenticated stream-json initialize pass; live probes pending |
| Hermes Agent | 0.23.2 | 0.23.3 (`caafe538`) | 0.20.0 | Step 4 (#2862) | Tag install, `hermes acp --version`, network-denied ACP initialize and empty `session/list` on macOS arm64 pass; configured lifecycle pending |
| Pi | 1.5.2 | 1.6.0 (minor, `faac5858`); 6 archives match `SHA256SUMS` and GitHub digests | 0.99.0 | Step 5 (#2864) | Managed install, RPC `get_state`, and logged-out commands/models/prompt identical to 1.5.2 on macOS arm64; authenticated turns pending |
| Oh My Pi | 19.0.0 | 19.0.1 (`f40f3358`); 8 binaries match `SHA256SUMS.txt` and GitHub digests | 17.2.13 | Step 3 (#2863) | Managed install, offline ACP initialize, `session/new`, delete/list probe identical to 19.0.0; authenticated lifecycle pending |
| DeepSeek | adapter 0.2.5 (dsh 0.2.2-rc.5) | adapter 0.2.5 (dsh `next` 0.2.2-rc.5) | 0.1.5 | None, already newest | — |
| Grok Build | 1.0.89 | 1.0.92 (`x.ai/cli/stable`, build `b06756fd6256`; no published checksums) | 1.0.5 | Step 4 (#2862) | Exact-launch ACP initialize and empty `session/list` network-denied on macOS arm64, surface identical to 1.0.89; authenticated lifecycle pending |

## Steps

1. Publish this plan (#2860).
2. Codex 0.171.0 (#2865).
3. Claude Code 2.1.330 and OMP 19.0.1 (#2863).
4. Hermes Agent 0.23.3 and Grok Build 1.0.92 (#2862).
5. Pi 1.6.0 (#2864).
6. Parity fix from the Pi audit: a logged-out Pi turn ("No API key found for the selected model.") now asks
   the user to log in, like the other harnesses, instead of Sesori's generic "Pi could not run this turn." (#2866).
   Then retire this plan and the 2026-11-19 plan (this PR).

Steps 2 to 5 ran in parallel. Their adjacent regression-doc rows conflicted three times (#2863 once, #2864
twice), resolved by merging `main`.

## Findings

No finding needed code in a bump PR. One pre-existing Pi gap found in the audit got its own parity fix (step 6).

- **Codex 0.170.0 → 0.171.0** (#2865): nothing Sesori reads changed; matched error strings appear the same
  number of times. Not applicable: `modelProvider/default/set`, experimental `thread/search/partial`, removal of
  `currentTime/read`, `bioPolicy` error code, `Project.position`. Track only: `thread/list` `includedThreadIds`;
  approval/interrupt race fixes; Codex can compress old session files to `.zst` behind an off-by-default flag,
  which Sesori's reader cannot read. If it becomes default, old sessions stop being readable.
- **Claude Code 2.1.328 → 2.1.330** (#2863): matched strings, error values, result subtypes, permission modes and
  system types unchanged; one new initialize capability (`get_usage_detached_v1`). Track only:
  `update_queued_message` (move a queued message forward or send it now) is behind an upstream feature flag that
  is off by default, so a "send now" action for queued messages is not yet buildable; revisit when it ships by
  default. Experimental Code Mode (`CLAUDE_CODE_EXPERIMENTAL_CODE_MODE`) now also starts with telemetry or feature
  flags off; only a user who sets it would see a script's tool calls as one opaque tool. A Keychain refusal to
  save a refreshed login is now `invalid_request`, so Sesori shows Claude's own message rather than "log in again",
  which fits. `rewind_conversation` refused right after a model change (Sesori doesn't send it).
- **OMP 19.0.0 → 19.0.1** (#2863): `modes/acp` byte-identical; the #2842 markers and `PI_INTENT_TRACING` still
  hold. Track only: `^model` mentions in steering, `--resume` fix (unused), Linux session-owner lock files,
  `/loop` and `/goal` waiting for background sub-agents.
- **Hermes Agent 0.23.2 → 0.23.3** (#2862; 1,675 commits): ACP methods, stop reasons, capabilities and matched
  failure copy unchanged. Track only: session reads moved to a new storage interface; Codex models that need
  account discovery are hidden from the ACP picker (Sesori tolerates a current model missing from the list).
- **Grok Build 1.0.89 → 1.0.92** (#2862): no method added or removed. Track only: since 1.0.90 a session
  switches model when its model leaves the available list, which may arrive as an unrequested model change.
  Not applicable: fork-offer notices (Sesori launches `--no-leader`), headless-only `-p` changes.
- **Pi 1.5.2 → 1.6.0** (#2864; 368 commits): RPC commands and events, stop reasons, session format (v3) and the
  matched "No models available…" text unchanged. Track only: RPC subscribes before extensions start, so an
  extension message at session start now shows live; a logged-out process warns on stderr (Sesori matches the
  exact unprefixed line, unchanged); aborted tool calls not yet started now get an "Operation aborted" end
  instead of Sesori's "did not complete"; more auto-retried connection errors.

## Verification still needed (final follow-ups)

Carried from 2026-11-18 and still open: authenticated lifecycles for Copilot, Cursor, OMP, Antigravity, Grok,
Hermes, Pi and DeepSeek; non-macOS-arm64 hosts; a live OpenCode turn with provider credentials; the Claude Code
compaction-rewind and side-question probes; the Grok `_x.ai/yolo_mode_changed`, `session/history_tree`,
`session/import`, `x.ai/models/refresh` and `x.ai/session/unsent_message` probes; a real DeepSeek
content-refused turn; DeepSeek `web_search` direct and through a gateway `baseURL`; an OpenCode timed-out shell
command's later wake-up row.

New:

- OMP: a signed-in lifecycle with the live intent-title, daemon tree-stop and model-restore probes on 19.0.1; a
  real Windows host stop with a busy OMP (covered so far by the CI host test).
- Grok 1.0.92: confirm how the automatic model switch arrives over ACP.
- Codex: watch for `.zst` session compression becoming default.

## Skill corrections

- Codex probes: the installer checks the `PATH` of the process running it, not the environment passed to the
  child, so start the probe with a system-only `PATH` (references, this PR).
- Grok binary URL platform names, the Claude Code offline seam diff, and Pi logged-out and startup notes were
  added in #2862, #2863 and #2864.
