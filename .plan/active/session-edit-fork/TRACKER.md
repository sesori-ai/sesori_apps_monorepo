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
| 14.a Fork from a message or the session menu | In review | #2698 |
| 14.b Forked-from link, mid-turn popup Fork, No-project wording | In progress | |
| 15 Reconcile docs, verify and retire | In progress (local, lands after 14) | |

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

## Open questions

Round 2 (2026-11-15) answered the first seven. Round 4 answered the archived-worktree question (recreate it, step
11.b) and settled the mid-turn follow-up fork (decision 15). None are open.

## Verification results

| Cell | Result | Date (UTC) |
| --- | --- | --- |
| Automated (bridge, plugin and client suites in CI) | | |
| Live plugin, Claude Code 2.1.322 and 2.1.221 | | |
| Live plugin, Codex 0.167.2 (and refusal on 0.139.0) | | |
| Headless iOS simulator, Claude Code and Codex | | |
| Desktop macOS right-click menu, Claude Code and Codex | | |
| Relay, second client | | |
