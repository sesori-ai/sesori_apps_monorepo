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
| 8 | ⚙️ Pi turn acceptance via `disposition` | 7 | dropped (#1867 closed; see PLAN) |
| 9 | 🌱 Cursor ACP sub-agent wire probe | 2 | pending |
| 10.a | 🚧 Cursor native child sessions (re-reviewed; D10 floor decision first) | 9 | pending |
| 10.b | 🌿 Delete the inert Cursor live Task path and orphaned ACP residency hooks | 10.a | pending |
| 11 | 🌿 DeepSeek consumer pin | external adapter release | blocked (see below) |
| 12 | 🌱 Regression docs reconcile | 2–10.b | pending |
| 13 | 🌱 Final coverage and retirement | 11, 12 | pending |

Step 11 needs a session with `sesori-deepseek-acp` checked out (handoff in
`PLAN.md`). It does not hold Steps 2–12; its own PR updates the docs it touches.
Step 13 waits for Step 11, or for the owner's recorded exclusion of DeepSeek.

## Final follow-ups (collected as work proceeds)

- Copilot: re-probe ACP sub-agent identity (D7); lift 🚫⁴ only if usable.
- Cursor (needs an authenticated account): the child-id `session/load`
  transcript, children in `session/list`, and `agentId` in pre-capability
  transcripts. These decide replayed child links and whether the kept replay
  files can be deleted.
- Tracked only: Grok context-window selection (D8); Hermes replay compaction marker
  (D9); Pi codemode nested tool events; Codex `thread/items/list`; Antigravity and
  OpenCode usage/error payloads.
