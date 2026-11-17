# Runtime refresh, 2026-11-17

Status: completed 2026-11-17. Every step is merged; the remaining verification is listed under final follow-ups.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-16 refresh (`.plan/completed/runtime-refresh-2026-11/PLAN.md`); six harnesses
released again since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-17.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.3.0 | 2.3.0 | PATH 1.14.0; v2 2.0.11 | None, already newest | — |
| Antigravity | 1.5.0 | 1.5.0 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.169.0 | 0.169.0 | 0.139.0 | None, already newest | — |
| GitHub Copilot | 1.0.112 | 1.0.113 (`16604af5`); 6 archives match `SHA256SUMS.txt` and GitHub digests | 1.0.78 | Step 2 (#2775) | Managed install and offline ACP initialize on macOS arm64 pass; authenticated lifecycle pending |
| Cursor | 2026.11.13-eacade1 | 2026.11.13-eacade1 | date 2026.09.23 | None, already newest | — |
| Claude Code | 2.1.325 | 2.1.326 (`bc1e8a88`); npm `latest`; probed archive matches `SHASUMS256.txt` and GitHub digest | 2.1.221 | Step 2 (#2775) | `--help` flags and unauthenticated stream-json initialize pass; live side-question and compaction-rewind probes pending |
| Hermes Agent | 0.23.1 | **0.23.2** (`v0.23.2` → `ae2a81cc`; from `3b421578`) | 0.20.0 | Step 3 (#2774, merged) | Tagged-source install prints `0.23.2`; offline ACP initialize (load/list/resume/fork) and empty `session/list` pass on macOS arm64; configured lifecycle pending |
| Pi | 1.5.2 | 1.5.2 | 0.99.0 | None, already newest | — |
| Oh My Pi | 18.21.0 | 18.22.0 (`3e8cff3b`); 8 binaries match `SHA256SUMS.txt` and GitHub digests | 17.2.13 | Step 2 (#2775) | Managed install, offline ACP initialize and credential-free delete/new list probes on macOS arm64 pass; busy window and authenticated lifecycle pending |
| DeepSeek | adapter 0.2.3 (dsh 0.2.2-rc.3) | adapter **0.2.4** (`v0.2.4` → `d294bb56`; dsh `next` 0.2.2-rc.4, tag `dsh-v0.2.2-rc.4` → `3f321d32`); 6 archives match `checksums.txt` and GitHub digests | 0.1.5 | Steps 4 (sesori-deepseek-acp#26, merged)–5 (#2776) | Managed install, offline `check`, ACP initialize, `session/new` and `session/list` on macOS arm64 pass (tree, commands and results in #2776's Verification); refusal notice covered by tests; authenticated lifecycle pending |
| Grok Build | 1.0.77 | **1.0.88** (`x.ai/cli/stable`, build `2fe3608f7398`; no published checksums) | 1.0.5 | Step 3 (#2774, merged) | `grok 1.0.88 (2fe3608f7398)`; offline exact-launch ACP initialize and empty `session/list` pass on macOS arm64, surface identical to 1.0.77; authenticated lifecycle pending |

## Steps

1. Publish this plan.
2. Copilot 1.0.113, Claude Code 2.1.326 and OMP 18.22.0: release-range audit, pins and managed asset digests,
   offline initialize checks.
3. Hermes 0.23.2 and Grok Build 1.0.88: release-range audit, pins, offline checks.
4. DeepSeek adapter: move `sesori-ai/sesori-deepseek-acp` to dsh 0.2.2-rc.4 and release `v0.2.4`.
5. Pin the DeepSeek consumer to adapter 0.2.4 from the published assets.
6. Findings that need code get their own PRs here. Reconcile capability and regression docs, apply skill
   corrections, then retire this plan. The one code finding (DeepSeek content refusals) shipped inside steps 4–5;
   the skill corrections and retirement are the final docs-only PR.

## Findings

- **Copilot 1.0.112 → 1.0.113** (#2775): ACP methods and update types are identical. Track only: Copilot's own SDK
  event types drop the deprecated `parentToolCallId` and terminal tool-result content (not on Sesori's ACP seam).
  Not applicable: the `features.browserUse` admin setting. No parity cell changes.
- **Claude Code 2.1.325 → 2.1.326** (#2775): one new initialize key (`hooks_when_unanswered_kept`); models and
  commands unchanged. Probe first: the SDK fixed `resumeSessionAt` failing on an empty reply, which is on
  Sesori's rewind path. Track only: `system/informational` warnings (already ignored), better secret masking in
  permission descriptions, sandboxed approval-rewritten commands, plan-mode auto-compaction on the answering
  model, resumed sessions no longer losing turns. No parity cell changes.
- **OMP 18.21.0 → 18.22.0** (#2775): nothing changed in the ACP layer, compaction notifications or model
  restore. Not applicable: the `ida`/`ghidra` tools folding into a `dsm` namespace (breaking upstream, unused
  here). Track only: lower sub-agent CPU/memory, LSP watch fixes. No parity cell changes.
- **Hermes 0.23.1 → 0.23.2** (7,918 commits, 5,211 files; diffed in a blobless clone because the compare
  API caps at 250 commits/300 files). `acp_adapter/gateway_server.py` and `hermes sessions delete` copy are
  unchanged. New `guardrail_blocked` failure copy, recognised in this PR. Track only: edit auto-approval now
  also refuses symlinked `.git`/`.ssh` targets; model switch/resume keep named custom provider routes and
  fail closed on an explicit provider that does not resolve; fast-mode detection now considers provider and
  base URL; terminal failure status lines are marked so chat surfaces drop the duplicate; durable subagents
  and a new primary-login lead on failed turns, which the source attaches only on messaging-gateway and API
  server turns, not the ACP path. No parity cell changes.
- **Grok 1.0.77 → 1.0.88:** release notes are TUI/CLI fixes; initialize surface identical. Track only:
  1.0.84 live model-list updates, 1.0.85 subagent turn-limit handoff and direct replies to unknown slash
  commands, 1.0.88 loaded sessions keep saved model/effort when the first model fetch fails. New binary
  strings `_x.ai/yolo_mode_changed`, `session/history_tree`, `session/import` are unprobed. No parity cell
  changes.
- **DeepSeek 0.2.2-rc.3 → rc.4** (audited from the npm tarballs before upstream tagged; `dsh-v0.2.2-rc.4` has since appeared at
  `3f321d32`). The one change on the adapter's seam: a turn DeepSeek's content safety review refuses now ends with
  `CONTENT_REFUSED` and an explanation instead of a malformed-response error. Done: the adapter (0.2.4) forwards the
  explanation and stops with `refusal`, and the DeepSeek plugin shows it once as the red failed-turn notice, live and on
  reload, in this PR; no shared or wire change. Not yet seen against the live service. No other parity cell changes.

## Verification still needed (final follow-ups)

Carried from 2026-11-16 and still open: authenticated lifecycles for Copilot, Cursor, OMP, Antigravity, Grok
and DeepSeek; non-macOS-arm64 hosts; a live OpenCode 2.3.0 turn with provider credentials.

New from this run:

- Claude Code 2.1.326: the live compaction-rewind and side-question probes against the local test endpoint
  (`resumeSessionAt` fix). Expected: a rewind to an earlier message after compaction resumes there.
- Grok 1.0.88: probe the new `_x.ai/yolo_mode_changed`, `session/history_tree` and `session/import` names with a
  signed-in session before relying on them.
- DeepSeek 0.2.4: a real content-refused turn, which needs DeepSeek provider credentials. Expected: one red
  failure notice with DeepSeek's explanation, live and after reload.

## Skill corrections

- Copilot: audit from the readable `cli-main.js`, `changelog.json` and SDK typings inside the release `.tgz`
  assets; OMP recheck notes for 18.22.0 (#2775).
- DeepSeek: the npm `next` RC can precede its upstream tag; audit the published tarballs and recheck the tag
  before the consumer pin. The reference's template migration now points at sesori-deepseek-acp#26.
