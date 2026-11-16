# Side Questions Tracker

| Step | Title | Status | PR | Depends on |
| --- | --- | --- | --- | --- |
| 1 | Plan side questions | Merged | #2586 | |
| 2 | Bridge contract, storage and routes | Merged (schema v25) | #2591 | 1 |
| 3 | Claude Code native side questions | Merged | #2597 | 2 |
| 4 | Codex runtime target to at least 0.169 | Merged (0.169.0) | #2590 | 1 (parallel) |
| 5 | Codex native side questions | Merged | #2605 | 2, 4 |
| 6 | Client core | Merged | #2598 | 2 |
| 7 | Prego detent sheet | Merged | #2593 | 1 (parallel) |
| 8 | Phone side chat, with the archived entry | Merged | #2630 | 6, 7 |
| 9 | Desktop side panel | Merged | #2652 | 8 |
| 10 | `/btw` side-question mode | Merged | #2666 | 8, 9 |
| 11 | Reconcile regression docs | Merged | #2689 | 3, 5, 8, 9, 10 |
| 12 | Verify and retire | Merged | this PR | 11 |

## Product questions

Answered: entry points D (button and `/btw`, round 2), `/btw` composer mode B (round 3), no streaming on any harness (2026-11-15), archived entry A (a "Side chats (N)" link on the archived notice, round 4 q2), Codex attached threads A (hidden from the session list, its own PR outside these steps, round 4 q3).

Open: none.

## Verification results

Live cells ran against main at 0b0b569ef9, with Claude Code 2.1.325 and Codex 0.169.0 behind the local test proxy (non-Claude model).

| Cell | Result | Date (UTC) |
| --- | --- | --- |
| Bridge contract | Pass: bridge route, repository and migration tests, Claude Code and Codex plugin tests | 2026-11-16 |
| Claude Code live | Partial: idle ask, follow-up and cold-resume ask pass, and the `.jsonl` is unchanged. Some mid-turn asks answered the running turn's prompt. The direct CLI behaves the same on 2.1.322 to 2.1.325, so the proxied model is the likely cause (see HARNESS_CAPABILITIES.md); this has not been checked against a real Claude model | 2026-11-16 |
| Codex live | Pass: mid-turn (about 1.7 s), follow-up, cold resume, rollout unchanged, over-budget history trimmed | 2026-11-16 |
| iOS simulator, Claude and Codex | Pass on Codex. Claude Code partial, only for the mid-turn answer above. Every entry, both sheet heights, Earlier (n), close while thinking and reopen, no transcript or composer movement, and Pi's unsupported reason and an older bridge's update reason pass | 2026-11-16 |
| macOS desktop panel | Not run on macOS: a debug desktop build raises a keychain prompt on the user's screen, so it cannot run unattended. `desktop_session_detail_screen_test` passes: slide-in without the transcript moving, close, Escape, session switch, archived link. A `/btw` question replacing the open panel's chat has no test | 2026-11-16 |
| Analytics | Pass: one `side_question_asked` per ask with bounded parameters (`side_chat_cubit_test`, `product_analytics_event_test`) | 2026-11-16 |
