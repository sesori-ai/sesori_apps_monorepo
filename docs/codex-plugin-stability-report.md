# Codex Plugin Stability Test Report

## Status

- **Started:** 2026-08-03
- **Completed:** 2026-08-04
- **Merged baseline:** `2408b574` on `origin/main`
- **Deep-test branches:** originally validated as the local
  `codex-stability-deep-test-*` stack, then delivered through the stability
  feedback PR series
- **Status:** Original deep-test matrix complete; F-12 follow-up open
- **Release decision:** Ready for code review for the original stability matrix.
  The separately reproduced F-12 generated-instructions defect remains open and
  is scheduled for Step 10 of the delivery plan.

The final production stack, in order, is:

1. `c3ab5fcb` `fix(codex): recognize directed image wrappers`
2. `58585e1f` `fix(codex): unify code-mode command identity`
3. `36ee48e9` `fix(codex): hide generated image wrappers`
4. `a32b6c29` `fix(codex): retain late command identity after abort`
5. `9da8f2e1` `fix(codex): unify file change identity`
6. `8f0f4ece` `fix(codex): settle interrupted tools after restart`
7. `cdd3a305` `fix(codex): preserve locally archived history`
8. `d4e30b87` `refactor(codex): type replay and item boundaries`

The first six deep-test steps subsequently merged through PRs
[#724](https://github.com/sesori-ai/sesori_apps_monorepo/pull/724),
[#731](https://github.com/sesori-ai/sesori_apps_monorepo/pull/731),
[#732](https://github.com/sesori-ai/sesori_apps_monorepo/pull/732),
[#733](https://github.com/sesori-ai/sesori_apps_monorepo/pull/733),
[#740](https://github.com/sesori-ai/sesori_apps_monorepo/pull/740), and
[#743](https://github.com/sesori-ai/sesori_apps_monorepo/pull/743).

## Purpose

Validate that Codex sessions present the same user-visible information while
live, after a client reconnect, after navigation away and back, and after a
cold bridge restart. The pass covers text, reasoning availability, tool calls,
tool output, image-bearing content, lifecycle controls, and failure recovery on
a real iOS simulator.

## Evidence Method

Each relevant scenario compared three views of the same session:

1. Normalized live events from `GET /global/event` on the debug server.
2. Bridge snapshots from session messages, status, and lifecycle routes.
3. The rendered Sesori session on the iPhone simulator.

Raw captures remain outside the repository because they can contain prompts,
transcripts, local paths, or tool output. This report records privacy-safe
summaries and only the identifiers needed to correlate a finding.

## Environment

- iPhone 17 simulator running iOS 26.5.
- Sesori app bundle `com.sesori.app`.
- Source bridge started from `bridge/app` with debug port 9977 and debug logs.
- Codex 0.146.0 through the managed Codex plugin runtime.
- GPT-5.6-Sol with Default mode and `xhigh` reasoning for the final matrix.
- Luna Fast with `xhigh` reasoning for the original baseline.
- Existing disposable project used for test sessions and generated files.

## Regression Matrix

| ID | Area | Scenario | Expected invariant | Initial | Final |
|---|---|---|---|---|---|
| ENV-01 | Environment | Bridge startup, authentication, Codex setup, debug API, and simulator connection | All surfaces refer to the same bridge | Passed | Passed |
| TXT-01 | Text | Stream a long structured response while continuously viewing | Text follows deltas without disappearing or duplicating | Failed: completion rehydration inserted internal context and displaced the transcript | Passed: 40 exact lines rendered progressively and remained byte-identical after cold load |
| TXT-02 | Text | Fetch history while a turn is active | A refresh cannot replace newer live content with an older snapshot | Not isolated initially | Passed during repeated active-turn snapshots, navigation, and reconnect checks |
| TXT-03 | Text | Cold-open the completed text session | Final text and ordering match the completed live view | Failed: cold history added a synthetic user message | Passed; live and cold response SHA-256 matched |
| RSN-01 | Reasoning | Compare reasoning live, after navigation, and cold | Available reasoning presence, identity, and content stay consistent | Pending | Not exercised: Codex persisted encrypted reasoning with an empty `summary` for every tested turn, so no user-visible reasoning existed to compare |
| REC-01 | Reconnect | Background and relaunch the app during a long turn | No tool state or final output is lost | Earlier reconnect exposed identity and hidden-context defects | Passed: one 24-second tool retained one identity, all 24 markers, idle status, and the exact final response after relaunch |
| REC-02 | Reconnect | Restart the bridge during an active Codex turn | Persisted progress recovers honestly and is not left falsely busy | Failed: an unresolved tool remained `Running` while session status was idle | Passed after `8f0f4ece`: interrupted cold history is `Failed`; genuinely active history stays `Running` |
| NAV-01 | Navigation | Leave an active session and reopen it before completion | Rehydrated state converges and continues updating | Tool representation changed on reopen | Passed for active image generation and a 30-second canonical shell tool |
| NAV-02 | Navigation | Switch repeatedly between two sessions while one is active | Content and status never bleed across session IDs | Pending | Passed; both sessions retained their own transcript, model metadata, and status |
| TOOL-01 | Tool | Successful shell command with multiline output | State, title, identity, and output match live and cold | Failed: one command produced two live cards and one cold card | Passed for direct and code-mode commands |
| TOOL-02 | Tool | Failing shell command | Error state and useful output match live and cold | Failed: live was error while cold history was completed | Passed: one canonical failed card retained marker and exit code 7 through restart |
| TOOL-03 | Tool | Create, edit, read, and clean up a file | Tool ordering, titles, patches, and completion survive rehydration | Failed: code-mode file changes had separate live and rollout identities | Passed after `9da8f2e1`; fresh create, update, and delete each kept one canonical ID live and cold |
| TOOL-04 | Tool | Exercise another available non-shell tool | Identity and result remain consistent | Image generation did not converge | Passed through stable `image_generation` tools and attachments |
| IMG-01 | Images | Send an image prompt and expand it | Attachment remains usable after navigation and cold load | Failed: Codex received the image but transcript history had no file part | Passed after `6930b3a9`; one file part remained expandable after navigation and bridge restart |
| IMG-02 | Images | Exercise image-bearing tool output and expand it | Attachment metadata and content match live and cold | Failed: live and cold count, identity, title, and filename differed | Passed after merged and deep-test wrapper fixes |
| IMG-03 | Images | Attach a phone-selected image to a new Codex session | Declared capability enables attachment, Codex receives the image, and the attachment remains usable after navigation | Not previously available through the app | Passed on the follow-up branch; Codex described the image and the reopened attachment retained its viewer controls |
| TURN-01 | Lifecycle | Abort while a tool is active | UI and status converge to idle without losing persisted output | Failed: late completion created a second tool identity | Passed after `a32b6c29`; one failed canonical card remained live and cold |
| TURN-02 | Lifecycle | Continue the same session for multiple turns | Ordering, model metadata, and prior content remain stable | Pending | Passed across text, shell, edit, image, abort, reconnect, and image-prompt turns |
| SES-01 | Session | Rename, archive, unarchive, and reopen | Catalog state and transcript remain intact | Failed: archive moved the rollout out of the readable catalog | Passed after `cdd3a305`; archive remained local and history stayed readable |
| SES-02 | Session | Delete disposable sessions | Deleted sessions disappear without affecting other sessions | Pending | Passed; detail, rollout, index rows, and project files were removed |

## Findings

### F-01: Codex Internal Context Was Rendered As A User Message

- **Severity:** High
- **Reproduced:** Existing history and a fresh multi-turn session.
- **Impact:** Completion rehydration inserted Codex-generated context as a large
  user message, displaced the viewport, and changed cold history.
- **Cause:** History rendered every rollout response item with role `user`,
  including generated context envelopes.
- **Fix:** Merged commit `0dc0c6ec` excludes complete generated envelopes while
  preserving user-authored text that happens to mention the same tags.
- **Result:** Original and fresh cold sessions contained only authored prompts.

### F-02: One Shell Invocation Had Two Live Identities

- **Severity:** High
- **Reproduced:** Direct commands and code-mode commands with delayed output.
- **Impact:** One command appeared as both an app-server `exec-*` card and a
  rollout `call_*` card before collapsing after completion.
- **Cause:** Codex uses distinct app-server and rollout IDs. Code-mode wrappers
  needed a narrower correlation path than direct function calls.
- **Fix:** Merged commit `e5cb9d86` fixed direct commands. Deep-test commit
  `58585e1f` correlates a wrapper containing exactly one command invocation by
  turn when no stable function-call candidate exists.
- **Result:** One canonical ID progresses from running to terminal and remains
  unchanged after reload.

### F-03: Interrupted Historical Tools Remained Running Forever

- **Severity:** Medium
- **Reproduced:** Interrupted and aborted rollouts with no ordinary command
  output record.
- **Impact:** Cold history displayed old commands as permanently running.
- **Cause:** History treated a missing output as active without considering
  durable turn completion, abort, wait, and chronology evidence.
- **Fix:** Merged commit `f70bdbcb` folds waits into the originating command and
  derives terminal status from durable turn evidence.
- **Result:** Interrupted historical tools now replay as a single terminal card.

### F-04: Prompt Images Disappeared From History

- **Severity:** Medium
- **Reproduced:** PNG supplied as a Codex local-image prompt part.
- **Impact:** Codex received and described the image, but navigation or cold
  history exposed only text and no expandable attachment.
- **Cause:** History discarded typed `input_image` content and retained Codex's
  generated local-path marker instead.
- **Fix:** Merged commit `6930b3a9` restores bounded inline image file parts and
  removes the generated path marker from visible prompt text.
- **Result:** The final snapshot contained one stable text part and one PNG file
  part. The image expanded with copy, share, and save controls after navigation
  and after a full bridge restart.

### F-05: Debug SSE Disconnected On Non-Latin-1 Text

- **Severity:** Medium for diagnostics; no production relay impact.
- **Reproduced:** A curly apostrophe caused the debug SSE response's default
  Latin-1 writer to reject the event and remove the client.
- **Fix:** Merged commit `025ba43b` writes explicit UTF-8 bytes and includes a
  regression proving the same connection receives a following event.
- **Result:** UTF-8 debug events remain readable without disconnecting.

### F-06: Failed Commands Became Completed In Cold History

- **Severity:** High
- **Reproduced:** A command printed a marker and exited with code 7.
- **Impact:** Reopening changed a visible failure into a successful command.
- **Cause:** The rollout output omitted the exit code while the app-server event
  carried the structured failure.
- **Fix:** Merged commit `20521cc2` persists structured app-server outcomes by
  canonical call ID.
- **Result:** Live, rendered, and cold views retain one error card, marker, and
  exit code 7.

### F-07: Code-Mode Output Images Did Not Converge

- **Severity:** High
- **Reproduced:** Image generation through direct, forwarded, directed, and
  preview-only wrapper forms.
- **Impact:** Live history showed wrapper shells plus image cards while cold
  history showed a different count, identity, title, or filename.
- **Cause:** Durable image records and generated code-mode wrappers were
  projected independently, and directed/content-forwarding variants were not
  classified consistently.
- **Fix:** Merged commit `2408b574` restores durable images. Deep-test commits
  `c3ab5fcb` and `36ee48e9` recognize only complete generated wrapper forms and
  suppress their shell projection without hiding mixed-purpose code.
- **Result:** Each generation has one completed `image_generation` identity and
  one expandable attachment live, after navigation, and cold.

### F-08: Late Completion Forked An Aborted Tool Identity

- **Severity:** High
- **Reproduced:** A code-mode process outlived its aborted model turn.
- **Impact:** The canonical card became failed, then a late native `exec-*` card
  appeared as a separate completed command.
- **Cause:** Turn termination discarded the app-server alias before the already
  started item emitted its own terminal event.
- **Fix:** Deep-test commit `a32b6c29` retains aliases only for started items that
  have not completed and retires each alias at item completion.
- **Result:** The late event updates the same canonical failed card; restart
  introduces no duplicate.

### F-09: Code-Mode File Changes Had Two Identities

- **Severity:** High
- **Reproduced:** Create, update, and delete operations performed through
  generated `apply_patch` wrappers.
- **Impact:** App-server `fileChange` items and rollout `call_*` wrappers could
  produce different live and cold cards.
- **Cause:** File changes lacked the same narrow turn correlation used for
  code-mode commands, and the wrapper patch was not projected as an edit.
- **Fix:** Deep-test commit `9da8f2e1` recognizes the exact single-patch wrapper,
  correlates app-server file changes to its canonical rollout ID, and preserves
  the patch as edit output. Follow-up `d4e30b87` parses file-change lifecycle
  data into a sealed typed event before coordination and repository tracking.
- **Result:** A fresh create/update/delete sequence produced exactly three edit
  cards with stable IDs, titles, patches, and completed status after restart.

### F-10: Bridge Restart Left An Active Tool Running Forever

- **Severity:** High
- **Reproduced:** The bridge was terminated while a 40-second command was active.
- **Impact:** After restart, session status was idle but the unresolved rollout
  call still displayed `Running` with no way to stop it.
- **Cause:** The last chronology segment had neither output nor later turn
  evidence. History reconstruction did not receive authoritative session status.
- **Fix:** Deep-test commit `8f0f4ece` introduced idle-gated replay
  terminalization. PR #743 refined the activity snapshot and interrupted-image
  handling before merge. Follow-up `d4e30b87` keeps the policy in
  `CodexSessionService`, which maps session status to an explicit
  preserve-or-terminalize replay disposition.
- **Result:** The interrupted call replays as `Failed`. A separate live
  30-second call remained `Running` during active snapshots and completed
  normally, proving active work is not closed prematurely.

### F-11: Archiving Removed Readable Codex History

- **Severity:** High
- **Reproduced:** Rename, archive, reopen, unarchive, and delete on a fresh
  two-message session.
- **Impact:** Codex `thread/archive` moved the rollout to `archived_sessions`.
  Sesori's archived detail then showed no messages and a false running state.
- **Cause:** Sesori's bridge database intentionally owns archive state and has no
  backend unarchive callback, but the Codex plugin also archived the backend
  thread destructively.
- **Fix:** Deep-test commit `cdd3a305` keeps Codex archive local-only so the
  readable rollout remains in the normal catalog.
- **Result:** Rename persisted, archive and unarchive preserved the transcript,
  and delete removed the disposable session without changing another session.

### F-12: Repository Instructions Appeared As A User Message

- **Severity:** High
- **Reproduced:** A fresh Codex session created from the iOS app during the
  follow-up mobile-image validation.
- **Impact:** On history load, a repository-instruction envelope was rendered as
  a large authored user message ahead of the actual image prompt.
- **Evidence:** The bridge-backed session and reopened iOS view both retained the
  synthetic message. The report omits its contents because they include local
  repository instructions and paths.
- **Disposition:** Not caused by attachment capability or image encoding. No fix
  is included in this branch; investigate and resolve it in a separate PR.

## Final Live Evidence

- A 40-line text response rendered progressively with no visible duplication or
  disappearance. Its live and post-restart SHA-256 was
  `3e103ca2fb45d13e2795857c74209c094a8550a0b38af92a93115d377b28b11b`.
- The final reconnect command used canonical ID
  `call_3j5QwV4y6xq6ISePhcCYOhNB`, retained markers 1 through 24 exactly once,
  completed, returned the session to idle, and rendered the exact final marker
  after app relaunch.
- The final prompt image used message ID
  `msg_019fc9bc-db87-7470-88a2-dcd3053546fc`. Its text and file part identities,
  PNG MIME type, and encoded length were unchanged after a bridge restart.
- A follow-up iOS submission selected a PNG through the app, received an
  image-specific Codex description, and retained an expandable attachment after
  leaving and reopening the session. The reopened viewer exposed close, copy,
  share, and save controls.
- The final file-edit rerun produced one canonical create, update, and delete
  card. No native file-change duplicate remained in live SSE or cold history.
- The archive lifecycle rerun retained the same two-message transcript through
  rename, archive, unarchive, and reopen, then deleted it cleanly.

## Automated Verification

- `dart test` in `bridge/sesori_plugin_codex`: 315 tests passed after the typed
  boundary changes were merged forward over the first seven delivery steps.
- `dart analyze --fatal-infos` in `bridge/sesori_plugin_codex`: no issues.
- Targeted tests cover generated image wrappers, canonical shell and file-change
  identity, late abort completion, active-versus-idle rollout replay, and
  local-only archive behavior.
- Architecture review approved the eight production commits after typed
  app-server event parsing and service-owned replay policy were verified.
- `git diff --check` is part of final report validation.

## Residual Observations

- F-12 was reproduced after the original matrix was finalized: generated
  repository instructions and a local path can appear as an authored user
  message. The active stability plan tracks the fix in Step 10; this report does
  not claim that follow-up is resolved.
- Codex persisted encrypted reasoning records for the tested Sol turns, but
  every record had an empty `summary`. The plugin correctly rendered no empty or
  invented reasoning. A future upstream turn with a non-empty summary is needed
  to exercise RSN-01 end to end.
- One idle bridge shutdown stalled during teardown after a debug SSE harness and
  required a second `SIGTERM`. Subsequent shutdowns completed normally, so this
  was not reproducible and no speculative lifecycle change was made.
- Codex logs a missing custom-tool-output diagnostic when reopening the rollout
  intentionally interrupted by bridge termination. The bridge now surfaces the
  corresponding user-visible tool honestly as failed.
- Immediately after the follow-up phone submission, the detail view briefly
  showed an incomplete text-only history. Its next history refresh restored the
  attachment and response, and both remained present after navigation. This was
  not isolated as a separate deterministic defect.

## Cleanup

- Deleted the main, baseline, and lifecycle test sessions through the bridge.
- Confirmed deleted session detail routes return 404 and session status is empty.
- Confirmed the main rollout and its four generated-image cache files are gone.
- Removed the prompt-image fixture and generated project copies.
- Confirmed temporary file-edit targets were already deleted by their test turns.
- Stopped the final debug bridge cleanly; session teardown completed in 4 ms.
- Kept privacy-sensitive raw captures only in the external temporary evidence
  directory, not in the repository.
- Deleted both follow-up mobile-image sessions through their owning bridges with
  worktree and branch deletion disabled, then confirmed both detail routes
  returned 404.
- Stopped the follow-up debug bridge cleanly after persistence verification.

## Final Assessment

The Codex plugin passed the user-visible stability matrix on the final local
stack. Text, tool identity and status, file changes, image inputs and outputs,
abort behavior, reconnect, navigation, cold reconstruction, archive lifecycle,
and deletion all converged across bridge snapshots and the iOS UI.

The empty upstream reasoning summaries and one non-reproduced shutdown stall are
documented residual coverage limits, not demonstrated release blockers. The
eight deep-test production commits are being reviewed and merged in their
original stack order.

The follow-up mobile-image branch additionally validates image selection and
submission from the iOS app through Codex. F-12 remains intentionally outside
that branch's implementation scope and requires a separate PR.
