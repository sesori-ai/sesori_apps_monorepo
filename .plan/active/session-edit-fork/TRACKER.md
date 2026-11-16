# Session Edit And Fork Tracker

| Step | Status | PR |
| --- | --- | --- |
| 1 Raise the plan | Merged | #2585, #2604, #2611 |
| 2 Message menu with Copy and Select text | Merged | #2595 |
| 3.a Branching contract and rewind wire models | Merged | #2606 |
| 3.b Rewind route and bridge edit flow | Merged | #2602 |
| 4 First-message edits replace the harness session | Merged | #2621 |
| 5 Codex reads reverted and forked rollouts | Merged | #2592 |
| 6 Codex native edit | Merged | #2620 |
| 7 Claude reads the active branch of a transcript | Merged | #2596 |
| 8 Claude native edit | Merged | #2619 |
| 9 Restore a message's text and attachments into a composer | Merged | #2594 |
| 9.b Retire the plugin-side file-path prompt part | Merged | #2609 |
| 10 Client edit flow | Merged | #2647, #2639, #2657 |
| 11 Fork contract, origin link and bridge route | Merged | #2631 |
| 11.b Recreate an archived origin's worktree for a fork | Merged | #2636 |
| 12 Codex native fork | Merged | #2649 |
| 13 Claude native fork | Merged | #2638, #2688 |
| 14.a Fork from a message or the session menu | Merged | #2698 |
| 14.b Forked-from link, mid-turn popup Fork, No-project wording | Merged | #2711, #2709 |
| 15.a Keep Codex 0.139 history from duplicating replies on first import (`[step 18/23]`) | Merged | #2724 |
| 15.b Keep the transcript in place during a Claude first-message edit (`[step 19/23]`) | Merged | #2725 |
| 15.c Resend shows no stale Working timer (`[step 20/23]`) | Merged | #2726 |
| 15.d Codex later-prompt edit fold settles without rows bouncing (`[step 21/23]`) | In progress | |
| 15.e Relay observer keeps its anchor through an edit (`[step 22/23]`) | In progress | |
| 15 Reconcile docs, verify and retire (`[step 23/23]`) | In progress: waits on 15.a-15.e | |

Steps 2, 5, 7 and 9 depend on nothing in this plan and can run in parallel. Step 4 needs 3. Step 6 needs 3 and 5;
step 8 needs 3 and 7. Step 9.b needs 9. Step 10 needs 2, 4 and 9 (and 6 or 8 for a
harness to offer it). Step 11 needs 3; step 11.b needs 11; step 12 needs 11, 11.b and 5; step 13 needs 11, 11.b and 7. Step 14 needs 10 and 11 (and 12 or 13 for a harness to offer it).

#2688 lifted Claude's refusal to fork from before a compaction: the fork keeps the prefix and leaves the
compaction and everything after it behind. Claude's fork uses no launch flag; it resumes the written transcript with
a plain `--resume`.

Step 14 split into 14.a (`[step 17a/18]`) and 14.b (`[step 17b/18]`). Deviations from PLAN: a fork slower than
300 ms answers with the existing loading alert ("Forking…"), not an inline indicator on the pressed message; the
session-list menus read `sessionBranching` from a small plugin-listing cache in `SessionActionService`, because the
plugin management snapshots don't carry it; and the missing-worktree prompt names no base branch, because `Session`
carries none.

Decided in 14.b: the "Forked from" tap reads the origin first, as the handoff link does, so an archived origin
opens read-only from the start. When the origin isn't the page below, desktop selects it and replaces the page
stack, as its parent-session link does, while the phone pushes it. A follow-up (#2709) keeps the " (fork)" suffix
visible when a title truncates.

## Open questions

Round 2 (2026-11-15) answered the first seven. Round 4 answered the archived-worktree question (recreate it, step
11.b) and settled the mid-turn follow-up fork (decision 15). None are open.

## Verification results

| Cell | Result | Date (UTC) |
| --- | --- | --- |
| Automated (bridge, plugin and client suites in CI) | Pass: Desktop and Mobile CI green on main 7d8a422401 (#2711's merge), Bridge CI green on 5091836459 (no bridge change after it) | 2026-11-16 |
| Live plugin, Claude Code 2.1.325 | Pass: later-prompt edit (store matches the active branch), first-message swap (old transcript deleted, one row), every fork point, archived origin forks; project files unchanged | 2026-11-16 |
| Live plugin, Codex 0.169.0 | Pass: later-prompt edit (store and model memory match), first-message swap (new thread, old rollouts deleted, one row), every fork point, archived origin forks; project files unchanged | 2026-11-16 |
| Live plugin, Codex 0.139.0 refusal | **Pass (live, after #2724)** on main 4ef315450b, headless iOS sim, 9router: a live-captured session imports with each reply once and its live time (4 rows before and after); the edit is refused as `legacySession` with the store byte-identical and the banner and composer kept; a fork at the latest turn is refused with "Update Codex to fork sessions." and the store unchanged. Prompts were sent through the bridge debug API. The first run failed (duplicated replies, misleading fork reason) | 2026-11-16 |
| Headless iOS simulator (sesori-dev-5), Claude Code and Codex | Pass: edit with fold-away, mid-turn popup Fork (whole turn kept, text in the composer), fork from a reply, own prompt and ⋯ with `… (fork)` kept on long titles, "Forked from" back and open, archived origin read-only from the first frame, delete or archive one of a pair | 2026-11-16 |
| Desktop right-click menu | Covered by widget tests, not run live (a macOS debug build raises a keychain prompt): `transcript_message_menu_test.dart` (right-click with and without a selection), `session_detail_message_list_test.dart` (right-click Copy selected text, drag across messages), `session_tile_menu_test.dart` (right-click a row opens the anchored menu), `prego_context_menu_test.dart` (secondary click). No test asserts Fork or Edit in a right-click menu | 2026-11-16 |
| Relay, second client (sesori-dev-7, Codex 0.169.0) | Pass: removed rows fold away, a swapped session stays one row, a fork row appears (edit, swap and fork driven through the bridge debug API) | 2026-11-16 |
