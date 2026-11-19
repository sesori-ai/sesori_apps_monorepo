# Runtime refresh, 2026-11-18

Status: completed 2026-11-18. Every step is merged; the remaining verification is listed under final follow-ups.

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise. This follows the
2026-11-17 refresh (`.plan/completed/runtime-refresh-2026-11-17/PLAN.md`); eight harnesses
released again since then.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.
Release channels were checked on 2026-11-18.

| Harness | Target before | Candidate | Floor (unchanged) | Update | Verification |
|---|---|---|---|---|---|
| OpenCode | 2.3.0 | 2.3.2 (`v2.3.2` → `c0ad18b4`; from `a6b15d33`, range includes 2.3.1); 6 npm tarballs match npm integrity | PATH 1.14.0; v2 2.0.11 | Step 2 (#2809) | Managed install and offline `serve` (auth, SSE, generated-model round trips) on macOS arm64 pass; live provider turn pending |
| Antigravity | 1.5.0 | 1.5.0 | Exact package/server/ACP 1 pair | None, already newest | — |
| Codex | 0.169.0 | 0.170.0 (`rust-v0.170.0` → `29eb79e9`); 6 packages match `codex-package_SHA256SUMS` and GitHub digests | 0.139.0 | Step 3 (#2807) | Managed install, stdio and WebSocket `initialize`/`thread/list`, `thread/sample` against a loopback model fixture on macOS arm64 pass; real-account turns pending |
| GitHub Copilot | 1.0.113 | 1.0.114 (`a9b36a75`); 6 archives match `SHA256SUMS.txt` and GitHub digests | 1.0.78 | Step 4 (#2810) | Managed install and offline ACP initialize on macOS arm64 pass; authenticated lifecycle pending |
| Cursor | 2026.11.13-eacade1 | 2026.11.17-f532c45 (`cursor.com/install`); 4 self-computed package hashes (Cursor publishes none) | date 2026.09.23 | Step 5 (#2808) | Managed install and network-denied ACP initialize on macOS arm64 pass; authenticated lifecycle pending |
| Claude Code | 2.1.326 | 2.1.327 (`9fa26078`); npm `latest`; probed archive matches `SHASUMS256.txt` and GitHub digest | 2.1.221 | Step 4 (#2810) | `--help` flags and unauthenticated stream-json initialize pass; live side-question and compaction-rewind probes pending |
| Hermes Agent | 0.23.2 | 0.23.2 | 0.20.0 | None, already newest | — |
| Pi | 1.5.2 | 1.5.2 | 0.99.0 | None, already newest | — |
| Oh My Pi | 18.22.0 | 18.22.2 (`e1ae2cc9`; range includes 18.22.1); 8 binaries match `SHA256SUMS.txt` and GitHub digests | 17.2.13 | Step 4 (#2810) | Managed install, offline ACP initialize and delete/list probe on macOS arm64 pass; authenticated lifecycle pending |
| DeepSeek | adapter 0.2.4 (dsh 0.2.2-rc.4) | adapter **0.2.5** (`v0.2.5` → `4b66ba98`; dsh `next` 0.2.2-rc.5, tag `dsh-v0.2.2-rc.5` → `9c2670d3`); 6 archives match `checksums.txt` and GitHub digests | 0.1.5 | Steps 6 (sesori-deepseek-acp#27)–7 (#2811) | Managed install, offline `check`, ACP initialize, `session/new` and `session/list` on macOS arm64 pass; authenticated lifecycle and live `web_search` pending |
| Grok Build | 1.0.88 | 1.0.89 (`x.ai/cli/stable`, build `28be5bb1bf65`; no published checksums) | 1.0.5 | Step 5 (#2808) | Exact-launch ACP initialize and empty `session/list` network-denied on macOS arm64 pass, surface identical to 1.0.88; authenticated lifecycle pending |

## Steps

1. Publish this plan.
2. OpenCode 2.3.2: release-range audit, pin and asset digests, regenerated v2 models and SSE events,
   offline checks.
3. Codex 0.170.0: release-range audit, pin and asset digests, offline checks.
4. Copilot 1.0.114, Claude Code 2.1.327 and OMP 18.22.2: release-range audit, pins and managed asset
   digests, offline initialize checks.
5. Cursor 2026.11.17-f532c45 and Grok Build 1.0.89: release-range audit, pins and digests, offline checks.
6. DeepSeek adapter: move `sesori-ai/sesori-deepseek-acp` to dsh 0.2.2-rc.5 and release `v0.2.5`.
7. Pin the DeepSeek consumer to adapter 0.2.5 from the published assets.
8. Findings that need code get their own PRs. Reconcile the plan table, capability and regression docs
   (including the regression intro's dated run list), apply skill corrections, then retire this plan.

Steps 2–5 and 6 ran in parallel. Implementation PRs left this plan and the regression intro's dated run
list to step 8; their adjacent regression-doc rows still conflicted once (#2810), resolved by merging `main`.
Step 6 also moved the adapter's runtime-composition tests to one 30 s describe-level timeout after a second
slow-runner flake on darwin-x64.

## Findings

No finding needed Sesori code; nothing new for the owner to decide. No parity cell changed.

- **OpenCode 2.3.0 → 2.3.2** (#2809; range includes 2.3.1): v2 REST models regenerated (headers only), SSE
  event manifest unchanged, v1 models unchanged. Not applicable: automation endpoints replacing the experimental
  schedule endpoints, `automation`-table migrations, per-step permission rejection (Sesori already clears from
  reply events), JSON `UnknownError` bodies on HTTP 500. Track only: timed-out shell commands keep running and
  wake the session later, background compaction on by default, Code Mode jobs behind `full_codemode`,
  `experimental.subagent_depth` (default 1), `video` model type.
- **Codex 0.169.0 → 0.170.0** (#2807): app-server methods, notifications and server requests unchanged (109/10/86).
  Not applicable: `agentMessage.moderation.display` union, `userVerification/verify` `biometricType`, resume
  `sandbox` comparison. Track only: a recovery turn now survives a client resuming a loaded thread. Rollout
  `response_item.id` stays a string; the new `id_allocation` sibling is ignored.
- **Copilot 1.0.113 → 1.0.114** (#2810): empty release notes and internal changelog; CLI script changed only in
  version strings. Not applicable.
- **Claude Code 2.1.326 → 2.1.327** (#2810): initialize keys, models and commands unchanged; `side_question`, the
  rewind error text and `--resume-session-at` still present. Not applicable: `system/shell_cwd` (hook-only).
  Track only: `reload_connectors` and `update_cloud_session` control requests; fixes for headless resume losing
  stored messages, `--agents` lost on plugin reload, and compaction after an output cut losing a tool call.
- **OMP 18.22.0 → 18.22.2** (#2810; range includes 18.22.1): `modes/acp` unchanged, so compaction notifications
  and model restore are unchanged. Track only: one session's shutdown no longer marks other sessions' OAuth
  accounts depleted for 5 minutes; new Kiro provider.
- **Cursor 2026.11.13-eacade1 → 2026.11.17-f532c45** (#2808): same 31 ACP/extension methods, 11 update kinds and
  sub-agent strings; still no permission-request withdrawal. Not applicable.
- **Grok 1.0.88 → 1.0.89** (#2808, build `28be5bb1bf65`): initialize surface identical. Track only: new
  `x.ai/models/refresh`, `x.ai/session/unsent_message`, `x.ai/shellNotHeld`, `x.ai/catchUpRow` strings; the
  1.0.88 unprobed names are still present.
- **DeepSeek 0.2.2-rc.4 → rc.5** (sesori-deepseek-acp#27; tag `dsh-v0.2.2-rc.5` → `9c2670d3`, 5 commits). Probe
  first: `web_search` now defaults to DeepSeek's Messages search for DeepSeek models (billed as tokens). Its
  endpoint ignores the chat `baseURL` (it uses `web-search-deepseek.baseURL`, then `$DEEPSEEK_SEARCH_BASE_URL`,
  then `api.deepseek.com/anthropic/v1`), so a gateway setup's searches fail until that is set. The adapter follows
  upstream's default; its README says so. Nothing changed on the ACP seam: the new
  `web/deepseek-search-llm-request` session-log event is already a known type and stays hidden. Track only: 36
  `npm audit` findings from newly published `undici`/`picomatch` advisories in the unchanged dsh tree.

## Verification still needed (final follow-ups)

Carried from 2026-11-17 and still open: authenticated lifecycles for Copilot, Cursor, OMP, Antigravity, Grok
and DeepSeek; non-macOS-arm64 hosts; a live OpenCode turn with provider credentials; the Claude Code
compaction-rewind and side-question probes; the Grok `_x.ai/yolo_mode_changed`, `session/history_tree` and
`session/import` probes; a real DeepSeek content-refused turn.

New from this run:

- DeepSeek 0.2.5: a credentialed `web_search` turn, once against DeepSeek directly and once through a gateway
  `baseURL`. Expected: direct search succeeds; the gateway search fails until `web-search-deepseek.baseURL` is set.
  If gateway users are affected in practice, decide whether the adapter should pin
  `searchProvider: deepseek-search-api`.
- Grok 1.0.89: the new `x.ai/models/refresh` and `x.ai/session/unsent_message` names, with the 1.0.88 probes.
- OpenCode 2.3.2: confirm a timed-out shell command's later wake-up report renders as a system row.

## Skill corrections

- Probes that restrict `PATH`: resolve the repository's Dart with `asdf which dart` inside the worktree; the
  global shim can resolve an older Flutter whose Dart is too old (SKILL.md, this PR).
- Copilot/OMP recheck notes and the Copilot audit tip were refreshed in #2810.
