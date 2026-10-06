# Tracker — harness-refresh-2026-10

Evidence lives in the PRs and per-step notes. This file only orders the work.

| Step | Title | Depends on | Status |
|---|---|---|---|
| 1 | 🌱 Publish the plan | — | in progress |
| 2 | 🌿 Mechanical pins: Claude, Copilot, Cursor, Grok, Codex | 1 | pending |
| 3 | 🌱 Codex floor 0.148.0 (round 3) | 2 | decision pending |
| 4 | 🌿 Antigravity 1.3.0 | 1 | pending |
| 5 | 🌿 OMP 18.6.3 + model-restore probe | 1 | pending |
| 5.b | 🌿 OMP cleanup fix (only if the Step 5 probe needs it; re-reviewed) | 5 | conditional |
| 6 | ⚙️ OpenCode 2.0.24 + regeneration | 1 | pending |
| 7 | ⚙️ Pi 1.0.4 + floor 0.99.0 + catalog fix | 1 | pending |
| 8 | ⚙️ Pi turn acceptance via `disposition` | 7 | pending |
| 9.a | 🌱 Cursor ACP sub-agent wire probe | 2 | pending |
| 9.b | 🚧 Cursor native child sessions (re-reviewed) | 9.a | pending |
| 10 | 🌿 DeepSeek consumer pin | external adapter release | blocked: needs a `sesori-deepseek-acp` session (handoff in PLAN.md) |
| 11 | 🌱 Regression docs reconcile | 2–10 | pending |
| 12 | 🌱 Final coverage and retirement | 11 | pending |

## Final follow-ups (collected as work proceeds)

- Copilot: re-probe ACP sub-agent identity (D7); lift 🚫⁴ only if usable.
- Tracked only: Grok context-window selection (D8); Hermes replay compaction marker
  (D9); Pi codemode nested tool events; Codex `thread/items/list`; Antigravity and
  OpenCode usage/error payloads.
