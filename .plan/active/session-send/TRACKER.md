# Session Send Tracker

| Step | Status | PR |
| --- | --- | --- |
| 1 Raise the plan | Done | #2587 |
| 2 Transcript Markdown and file store | Done | #2588 |
| 3 Bridge send flow | Done | #2600 |
| 4 Handoff marker in the bridge | Done | #2608 |
| 5 Claude read rules (transcripts and uploads) | Done | #2613 |
| 6 Busy-prompt declaration | Done | #2589 |
| 7 Client send and stop pipeline | Done | #2622 |
| 7.a Send from the session menu | In PR | #2623 |
| 8 Handoff marker and card in the chats | In PR | #2629 |
| 8.a Queued handoff prompts stay hidden; a failed send updates live | Not started | |
| 9 Archive the source after sending | Not started | |
| 10 Analytics | Not started | |
| 11 Reconcile docs and harness rows | Not started | |
| 12 Verify and retire | Not started | |

Dependencies: 2←1; 3←2; 4←3; 5←2 (ships after 3); 6←1; 7←3,6; 7.a←7; 8←4; 8.a←8;
9←7.a; 10←7; 11←5,8,9,10; 12←11.

## Product questions

All answered (rounds 1–3, 2026-11-14 and 2026-11-15).

## Verification results

| Cell | Result | Date (UTC) |
| --- | --- | --- |

## Decisions log

- 2026-11-15: round 2 and 3 answers applied: stay in the source (S1), running ACP targets allowed with a label (S2),
  bridge-stamped handoff marker with a source marker and a target card (S3, Q2), Claude read rule for transcripts and
  uploads (S4), archive switch on by default and remembered (Q3). Series grows from 8 to 12 PRs.
- 2026-11-15: step 7 measured about 1,680 lines, so it split into step 7 (the `module_core` pipeline) and step 7.a (the
  sheet, picker, menu entry and alerts), as the plan allows. Series total 13.
- 2026-11-15: 7.a ships the archive switch inert, on by default. Step 9 makes it act; if step 9 misses the release that
  carries 7.a, hide the switch in that release.

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
- 2026-11-15 architecture plan review of the round 2 and 3 revision (D11–D13, busy-prompt declaration): rejected with
  five findings. All were applied directly without re-review:
  - the handoff stamp reuses the command-invocation record (`PromptStampTracker` with a sealed `PromptStamp`). It is
    recorded inside `SessionRepository.sendPrompt(handoff:)` instead of a second tracker that the service writes into;
  - `ChatHistoryRepository` and `forgetHandoff` added to `SessionSendService`'s collaborators. The stamp is cleared on
    any failure after the send was accepted;
  - separate `PluginBusyPromptHandling` (interface) and `BusyPromptHandling` (shared) enums, with a named mapper;
  - `SessionSearchCubit`'s running sources named (`SseEventTracker`, `PluginRepository`), plus
    `createSessionSearchCubit` in `cubit_composition.dart`;
  - the archive-switch storage named (`ArchiveAfterSendPreferenceStorage` through `SessionActionsCubit`), and
    `SessionListActionDispatcher` named as the owner of archive-after-send.
- The D4 SSE fallback needs its own review if it is triggered.
