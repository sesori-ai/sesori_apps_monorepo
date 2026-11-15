# Session Send Tracker

| Step | Status | PR |
| --- | --- | --- |
| 1 Raise the plan | Not started | |
| 2 Transcript Markdown and file store | Not started | |
| 3 Bridge send flow | Not started | |
| 4 Handoff marker in the bridge | Not started | |
| 5 Claude read rules (transcripts and uploads) | Not started | |
| 6 Busy-prompt declaration | Not started | |
| 7 Client send flow | Not started | |
| 8 Handoff marker and card in the chats | Not started | |
| 9 Archive the source after sending | Not started | |
| 10 Analytics | Not started | |
| 11 Reconcile docs and harness rows | Not started | |
| 12 Verify and retire | Not started | |

Dependencies: 2←1; 3←2; 4←3; 5←2 (ships after 3); 6←1; 7←3,6; 8←4; 9←7; 10←7; 11←5,8,9,10; 12←11.

## Product questions

All answered (rounds 1–3, 2026-11-14 and 2026-11-15).

## Verification results

| Cell | Result | Date (UTC) |
| --- | --- | --- |

## Decisions log

- 2026-11-15: round 2 and 3 answers applied: stay in the source (S1), running ACP targets allowed with a label (S2),
  bridge-stamped handoff marker with a source marker and a target card (S3, Q2), Claude read rule for transcripts and
  uploads (S4), archive switch on by default and remembered (Q3). Series grows from 8 to 12 PRs.

## Review record

- 2026-11-14 architecture plan review: rejected with eight specific findings, all applied directly without
  re-review, as the plan-maker rules allow:
  - readiness from statuses and pending requests rather than the quota-only readiness;
  - check and send inside one source reservation;
  - reuse of `abortStartedSessions`;
  - the transcripts root passed into `ClaudeLaunchSpec`;
  - a named `SessionSendService` collaborator list;
  - the capability flag dropped in favour of the missing-route 404 (no list surface holds discovery);
  - picker exclusion, `isRunning` and cubit wiring in `module_core`;
  - `stopSession` and the analytics dependency.
- The round 2 and 3 revision adds D11–D13 and a new `Message.user` field. A fresh architecture plan review is due
  before step 3. The D4 SSE fallback needs its own review if it is triggered.
