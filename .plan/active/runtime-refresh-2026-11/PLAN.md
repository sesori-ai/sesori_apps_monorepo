# Runtime refresh, 2026-11-16

Raise every registered harness to its current stable upstream release, following
`.agents/skills/update-backend-runtimes/SKILL.md`. Floors (`minPathVersion` /
`minVersion`) stay unchanged unless the owner approves a raise.

## Harnesses

All 11 `knownPlugins` entries in `bridge/app/lib/src/runtime/plugin_registry.dart` are covered.

| Harness | Target before | Target after | Floor (unchanged) | Release evidence | Update | Verification |
|---|---|---|---|---|---|---|
| OpenCode | 2.2.7 | 2.3.0 (`a6b15d33`) | PATH 1.14.0; v2 2.0.11 | 6 npm tarballs, hashes match npm integrity; v2 models regenerated, v1 unchanged, SSE manifest re-audited | Step 2 | Managed install and offline sandbox serve/auth/catalog on macOS arm64 pass; live turn pending (step 7) |
| Antigravity | 1.4.5 | 1.5.0 (registry `655791de`) | Exact package/server/ACP 1 pair | 6 ZIPs match registry sha256; layout unchanged | Step 3, merged (#2737) | Managed install and initialize-only on macOS arm64 pass; signed-in model list pending |
| Codex | 0.169.0 | 0.169.0 | 0.139.0 | Already the newest stable (`rust-v0.169.0`) | None | From the side-questions step |
| GitHub Copilot | 1.0.109 | 1.0.112 (`a0d26c24`) | 1.0.78 | 6 archives match `SHA256SUMS.txt` and GitHub digests | Step 4 | Managed install and offline initialize pass; authenticated lifecycle pending |
| Cursor | 2026.11.11-b912975 | 2026.11.13-eacade1 | date 2026.09.23 | 4 self-computed hashes; `cursor.com/install` names one build | Step 4 | Managed install and offline initialize pass; load/replay/model/mode pending |
| Claude Code | 2.1.322 | 2.1.325 (`715ff104`) | 2.1.221 | npm `latest`; probed archive matches `SHASUMS256.txt` | Step 4 | `--help` flags and unauthenticated handshake pass; live probes in step 7 |
| Hermes Agent | 0.23.1 | 0.23.1 | 0.20.0 | Already the newest stable | None | — |
| Pi | 1.5.2 | 1.5.2 | 0.99.0 | Already the newest stable | None | — |
| Oh My Pi | 18.19.0 | 18.21.0 (`6f03614d`) | 17.2.13 | 8 binaries match `SHA256SUMS.txt` and GitHub digests | Step 4, merged (#2741) | Managed install and offline initialize pass; live busy-window probe passes (7.c) |
| DeepSeek | adapter 0.2.2 (dsh 0.2.2-rc.2) | adapter 0.2.3 (dsh 0.2.2-rc.3, `38a6a5c9`) | 0.1.5 | Producer release `v0.2.3` (tag commit `cca1c801`); 6 archives match `checksums.txt` and GitHub digests; `BUILD-METADATA.json` names adapter 0.2.3 over dsh 0.2.2-rc.3 | Steps 5–6 | `npm run check`, six-platform release CI; managed install and offline `check`/initialize/new/list on macOS arm64 pass; authenticated turn pending |
| Grok Build | 1.0.77 | 1.0.77 | 1.0.5 | Already the newest stable (`x.ai/cli/stable`) | None | — |

## Steps

1. Publish this plan.
2. OpenCode 2.3.0 with regenerated models (#2738, merged).
3. Antigravity 1.5.0 (#2737, merged).
4. Copilot 1.0.112, Cursor 2026.11.13-eacade1, OMP 18.21.0, Claude Code 2.1.325 (#2741, merged).
5. DeepSeek adapter: move to dsh 0.2.2-rc.3 and release `v0.2.3` (sesori-deepseek-acp#25, merged and tagged
   `v0.2.3`). Also fixes the Windows arm64 packaging step, whose `Expand-Archive` broke on the current
   `windows-11-arm` runner image.
6. Pin the DeepSeek consumer to adapter 0.2.3 from the published assets (#2748, in review).
7. Live follow-up probes against the local test endpoint, the fixes they show are needed, doc reconciliation,
   skill corrections, then retire this plan. Fixes that need code get their own PRs inside this step:
   - 7.a Claude "Always" shown with nothing to save.
   - 7.b OpenCode 2.3.0 background sub-agent report rows in the parent session.
   - 7.c OMP 18.21.0 busy-window docs and comments, plus the skill corrections below (this PR).

## Findings from step 7

- Claude 2.1.325 only sends a saveable rule suggestion when saving would allow the command again; Sesori may still
  show "Always" with nothing to save (`claude_approval_registry.dart`). Fix in 7.a.
- OMP 18.21.0 keeps a prompt open until background jobs or live sub-agents can no longer resume it. Probed live on
  2026-11-16: steering answers `promptRequired` (the follow-up queues), Stop ends the prompt but not the job, and
  history falls back to stored history. No code change; documented in 7.c.
- Claude `supersedes` now also names a reply discarded for an unparsable tool call; Sesori ignores the field.
- Claude rewinding behind a compaction still fails on 2.1.325, so Sesori's refusal stays.
- Antigravity 1.5.0 telemetry needs no change: it only sends for business OAuth with a project, and Sesori allows
  only personal OAuth.
- OpenCode 2.3.0 background sub-agent report rows in the parent session: handled in 7.b.

Owner decisions:

- OMP floor stays 17.2.13 (2026-11-16): 18.20.1 is too new to require, so both workarounds for the upstream
  bugs it fixes stay.
- Claude "Always" on a file edit switches the session to `acceptEdits`, matching Claude Code's own terminal
  (2026-11-16; step 7.d, stacked on #2743).
- Finished sub-agent rows stay compact: the answer stays one tap away in the child session, not shown inline in
  the parent chat (2026-11-16; no app change, #2745 ships as is).

Track only: OpenCode first-token timing, Copilot `--resume` marking sessions in use, Claude sandbox prompts and
`auto` permission-mode fallback, OMP late background results carried into the next prompt.

## Verification still needed (final follow-ups)

- Authenticated lifecycles for Copilot, Cursor, OMP, Antigravity (signed-in model list) and Grok.
- Native checks on hosts other than macOS arm64.

## Skill corrections

Applied in 7.c: OMP form field naming, fix versions and busy-window probe, Antigravity allowlist, embedded-source
audit tip and telemetry recheck, Copilot musl archives and compressed JS, Cursor bundle string diffing, DeepSeek
lockfile regeneration and packaging, Claude proxy base URL and compaction-rewind recheck, compare-API truncation
workarounds, probes needing a PATH without user installs, and running package tests after OpenCode regeneration.
