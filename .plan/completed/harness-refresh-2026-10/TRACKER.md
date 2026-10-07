# Tracker — harness-refresh-2026-10

Evidence lives in the PRs and per-step notes. This file only orders the work.
Total: 13 (highest step identifier; dropped Steps 3 and 8 get no PR; titles use `[step <x>/13]`).

| Step | Title | Depends on | Status |
|---|---|---|---|
| 1 | 🌱 Publish the plan | — | merged (#1854) |
| 2 | 🌿 Mechanical pins: Claude, Copilot, Cursor, Grok, Codex | 1 | merged (#1855) |
| 3 | 🌱 Codex floor 0.148.0 | 2 | dropped (D4 keeps 0.139.0; see PLAN) |
| 4 | 🌿 Antigravity 1.3.0 | 1 | merged (#1856; pin landed on main in f197395731) |
| 5 | 🌿 OMP model-restore probe | 1 | done: no pin change (D12; #1863 closed) |
| 6 | ⚙️ OpenCode 2.0.24 + regeneration | 1 | merged (#1857) |
| 7 | ⚙️ Pi 1.0.4 + floor 0.99.0 + catalog fix | 1 | merged (#1862) |
| 8 | ⚙️ Pi turn acceptance via `disposition` | 7 | dropped (#1867 closed; see PLAN) |
| 9 | 🌱 Cursor ACP sub-agent wire probe | 2 | merged (#1864) |
| 10.a | 🚧 Cursor native child sessions (D10 floor 2026.09.23, D11) | 9 | merged (#1870, #1871) |
| 10.b | 🌿 Delete the inert Cursor live Task path and orphaned ACP residency hooks | 10.a | merged (#1874) |
| 11 | 🌿 DeepSeek consumer pin | adapter v0.2.0 (sesori-deepseek-acp #22) | merged (#1883) |
| 12 | 🌱 Regression docs reconcile | 2–10.b | merged (#1875) |
| 13 | 🌱 Final coverage and retirement | 11, 12 | done: plan retired, gaps accepted 2026-10-07 (see PLAN) |

Step 11's adapter work merged as `sesori-deepseek-acp` #22 and shipped as
release v0.2.0 (DeepSeek Harness 0.2.0-rc.2); the consumer pin merged as #1883.

## Final follow-ups (collected as work proceeds)

- OMP: re-probe the next release with the Step 5 model-restore probe (D12);
  move off 18.3.0 only if `session/load` and `session/resume` succeed for a
  session whose model was removed.
- Copilot: re-probe ACP sub-agent identity (D7); lift 🚫⁴ only if usable.
- Cursor (needs an authenticated account): the child-id `session/load`
  transcript, children in `session/list`, and `agentId` in pre-capability
  transcripts. These decide replayed child links and whether the kept replay
  files can be deleted.
- Tracked only: Grok context-window selection (D8); Hermes replay compaction marker
  (D9); Pi codemode nested tool events; Codex `thread/items/list`; Antigravity and
  OpenCode usage/error payloads.
