# Session Edit And Fork Tracker

| Step | Status | PR |
| --- | --- | --- |
| 1 Raise the plan | In this PR | |
| 2 Message menu with Copy | Not started | |
| 3 Edit contract and bridge route | Not started | |
| 4 Codex reads reverted and forked rollouts | Not started | |
| 5 Codex native edit | Not started | |
| 6 Claude reads the active branch of a transcript | Not started | |
| 7 Claude native edit | Not started | |
| 8 Client edit flow | Not started | |
| 9 Fork contract, origin link and bridge route | Not started | |
| 10 Codex native fork | Not started | |
| 11 Claude native fork | Not started | |
| 12 Client fork flow | Not started | |
| 13 Reconcile docs, verify and retire | Not started | |

Steps 2, 4 and 6 depend on nothing in this plan and can run in parallel. Step 5 needs 3 and 4; step 7 needs 3 and 6;
step 8 needs 2 and 3. Step 9 needs 3; steps 10 and 11 need 9 (and 4 or 6); step 12 needs 8 and 9.

## Open questions

The seven questions in `PLAN.md` "Open questions" are unanswered; the provisional defaults apply until they are.

## Verification results

| Cell | Result | Date (UTC) |
| --- | --- | --- |
| Live plugin, Claude Code 2.1.322 and 2.1.221 | | |
| Live plugin, Codex 0.167.2 (and refusal on 0.139.0) | | |
| Headless iOS simulator, Claude Code and Codex | | |
| Desktop macOS, Claude Code and Codex | | |
| Relay, second client | | |
