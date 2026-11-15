# Session Send Tracker

| Step | Status | PR |
| --- | --- | --- |
| 1 Raise the plan | Not started | |
| 2 Transcript Markdown and file store | Not started | |
| 3 Bridge send flow | Not started | |
| 4 Claude read rule | Not started | |
| 5 Client send flow | Not started | |
| 6 Analytics | Not started | |
| 7 Reconcile docs and harness rows | Not started | |
| 8 Verify and retire | Not started | |

## Open product questions

Q1–Q3 in PLAN.md wait for the user. Defaults apply until answered.

## Verification results

| Cell | Result | Date (UTC) |
| --- | --- | --- |

## Decisions log

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
- This revised plan was not reviewed again. The D4 SSE fallback needs a new review if it is triggered.
