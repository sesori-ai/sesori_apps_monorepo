# Session Edit And Fork Tracker

| Step | Status | PR |
| --- | --- | --- |
| 1 Raise the plan | Merged | #2585 |
| 2 Message menu with Copy and Select text | In review | #2595 |
| 3 Edit contract and bridge route | Not started | |
| 4 First-message edits replace the harness session | Not started | |
| 5 Codex reads reverted and forked rollouts | In review | #2592 |
| 6 Codex native edit | Not started | |
| 7 Claude reads the active branch of a transcript | In review | #2596 |
| 8 Claude native edit | Not started | |
| 9 Restore a message's text and attachments into a composer | In review | #2594 |
| 10 Client edit flow | Not started | |
| 11 Fork contract, origin link and bridge route | Not started | |
| 12 Codex native fork | Not started | |
| 13 Claude native fork | Not started | |
| 14 Client fork flow | Not started | |
| 15 Reconcile docs, verify and retire | Not started | |

Steps 2, 5, 7 and 9 depend on nothing in this plan and can run in parallel. Step 4 needs 3. Step 6 needs 3 and 5;
step 8 needs 3 and 7. Step 10 needs 2, 4 and 9 (and 6 or 8 for a harness to offer it). Step 11 needs 3; step 12 needs
11 and 5; step 13 needs 11 and 7. Step 14 needs 10 and 11 (and 12 or 13 for a harness to offer it).

## Open questions

Round 2 (2026-11-15) answered the first seven. Two new ones are in `PLAN.md` "Open questions"; their provisional
defaults apply until they are answered.

## Verification results

| Cell | Result | Date (UTC) |
| --- | --- | --- |
| Automated (bridge, plugin and client suites in CI) | | |
| Live plugin, Claude Code 2.1.322 and 2.1.221 | | |
| Live plugin, Codex 0.167.2 (and refusal on 0.139.0) | | |
| Headless iOS simulator, Claude Code and Codex | | |
| Desktop macOS right-click menu, Claude Code and Codex | | |
| Relay, second client | | |
