# S03-W03-M01: Verify a Real Repository End to End

## 0. Metadata

- **ID:** S03-W03-M01
- **Type:** Advisory manual checkpoint
- **Stage:** S03 — Client Presence and History
- **Wave:** W03
- **Blocks later waves:** No
- **Automation owner:** None; record separate User and Worker evidence in
  `TRACKER.md`
- **Worker capability:** Partial. A worker can perform disposable GitHub/Git/CLI
  setup and simulator checks when authenticated `gh`, build artifacts, and a
  mobile device are available. The user is best placed to validate a physical
  phone's background/resume behavior, real navigation feel, and responsive UI.

## 1. Why Automation Is Insufficient

Deterministic tests cover clocks, filesystem events, dispatcher races, relay
messages, and widgets, but they cannot prove the complete host environment:

- real `.git/HEAD` atomic replacement/worktree notifications on the user's OS;
- installed `gh` authentication and GitHub's eventual PR state propagation;
- relay reconnect plus physical mobile lifecycle behavior;
- real narrow/wide text rendering and disclosure interaction; or
- perceived archive responsiveness while a network command is in flight.

This checkpoint supplements rather than gates the automated suite. A missing
credential/device leaves its checkbox unchecked; it does not fail or block plan
closure.

## 2. Setup

Use disposable data only. Do not paste OAuth tokens, relay room keys, or full
bridge configuration into tracker evidence.

Prerequisites:

1. S03-W02-P01 is merged and its full automated matrix passes.
2. A disposable GitHub repository owned by the account currently active in
   `gh`, with merge/close permission.
3. A clean local clone registered as a Sesori project.
4. A bridge built from the merged plan result, run with diagnostic logging that
   is safe to retain after redaction.
5. A mobile development build on a physical device or simulator connected to
   that bridge.
6. One root session whose reported directory is the disposable clone. Avoid a
   worktree with unrelated changes so branch switching/archive cleanup is safe.

Confirm identity and repository without exposing secrets:

```text
gh auth status --hostname github.com
gh api user --hostname github.com --jq .login
git status --short
git remote -v
```

Create two clean authored PR branches. Adapt owner/repository/base names rather
than copying placeholders literally:

```text
git switch <base-branch>
git switch -c sesori-pr-history-one
# create and commit one harmless fixture file
git push -u origin sesori-pr-history-one
gh pr create --base <base-branch> --head sesori-pr-history-one --title "Sesori PR history one" --body "Disposable manual verification"

# After the first branch has been observed by the root session:
git switch <base-branch>
git switch -c sesori-pr-history-two
# create and commit a second harmless fixture file
git push -u origin sesori-pr-history-two
gh pr create --base <base-branch> --head sesori-pr-history-two --title "Sesori PR history two" --body "Disposable manual verification"
```

Record the repository URL, PR numbers/URLs, device type, bridge SHA, client SHA,
OS, and approximate start time. Never record credentials.

## 3. Checklist

### A. Initial presence and headline

- [ ] Open the disposable project's mobile session list and keep it visible.
- [ ] Confirm the first all-state refresh completes without blocking session
      loading and the first branch's PR appears as the root session headline.
- [ ] Confirm the PR number/state/review/check affordances remain compact and
      the conversation unseen indicator does not change merely because PR data
      appeared.
- [ ] Open the same session directly in detail, then return to the list. Confirm
      there is no visible refresh gap attributable to a false null project-view
      declaration.

### B. Live branch history and disclosure

- [ ] With the list/detail surface still viewing the project, switch the clean
      root checkout from `sesori-pr-history-one` to
      `sesori-pr-history-two` and create/open the second authored PR.
- [ ] Confirm the local branch change invalidates the session promptly even if
      the GitHub query has not yet completed.
- [ ] Confirm PR two becomes the prominent headline after refresh and PR one is
      present exactly once behind a collapsed history disclosure.
- [ ] Expand/collapse history. Confirm order, labels, touch target, state icons,
      no overflow, and expansion retention through at least one subsequent
      `sessionsUpdated` re-fetch.
- [ ] Repeat at the largest supported text size and, where available, a narrow
      phone plus wide/split mobile layout. Confirm a no-history session elsewhere
      in the list retains its prior compact shape.

### C. Viewed cadence and lifecycle cancellation

- [ ] While an authored PR is open and the project remains visible, change its
      GitHub state (for example close then reopen) and confirm the displayed
      state converges on the fast viewed tier (allow command duration and relay
      delivery beyond the nominal 15-second interval; record observed time).
- [ ] Close/merge all authored open PRs, keep the project visible, change one
      final state again, and confirm convergence on the idle tier (nominally 90
      seconds; record observed time).
- [ ] Navigate completely away from both session list and detail. Change a PR
      state, wait longer than the prior fast interval, and confirm available
      bridge diagnostics show no continued scheduled query for that project.
- [ ] While still away, switch the clean root checkout to a third named branch
      and create a third authored PR. Return to the project and confirm
      branch history was retained and one activation refresh reconciles GitHub.
- [ ] Background/hide the app while viewing, change a PR, and confirm no ghost
      viewed work remains. Resume and confirm the effective project is reasserted
      and converges without changing unseen state.
- [ ] Drop and restore the relay/bridge connection once in foreground and once
      while hidden. Confirm foreground reconnect reasserts, hidden reconnect
      waits for resume, and no duplicate/overlapping visible refresh occurs.

### D. Continuous-view all-state reconciliation

- [ ] Keep the project visible continuously. Arrange a short-lived authored PR
      transition that is not relied on as an open-poll result (or observe a
      closed/merged change), then verify an all-state reconciliation occurs no
      later than ten minutes after the prior complete all-state success.
- [ ] If a deliberate transient network/`gh` failure is safe to induce, confirm
      the failed attempt does not erase existing PRs and the deadline remains
      pending under bounded retry. Restore connectivity before continuing.

Do not log out or remove the user's primary `gh` account merely to force this
case; deterministic tests are authoritative when safe failure injection is not
available.

### E. Terminal archive snapshot

- [ ] With a known headline/history state visible, archive the root session
      without destructive checkout options. Confirm the archive response/UI is
      not held open by the final GitHub command.
- [ ] Record the archived headline/history snapshot, then change the associated
      PR state remotely after the one final asynchronous attempt has settled.
- [ ] Confirm the archived display remains immutable under later project
      refreshes.
- [ ] Unarchive the session, leave the project visible through at least one
      normal cadence, and confirm that session's PR display remains the terminal
      snapshot and branch/PR tracking does not restart.
- [ ] Restart the bridge once and confirm terminal behavior survives process
      restart.

## 4. Expected Evidence

### Worker evidence

Record a concise bundle in the tracker or an attached artifact:

- disposable repository and PR URLs;
- bridge/client full SHAs, device/simulator, and OS;
- sanitized timestamped observations for fast, idle, viewer departure,
  resume/reconnect, and ten-minute all-state behavior attempted;
- screenshots of current headline, collapsed history, expanded ordered history,
  archived snapshot, and post-unarchive snapshot;
- sanitized bridge log excerpts showing branch observation, viewer activation/
  cancellation, refresh mode/outcome, and absence of repeated archive-final work;
- any skipped sub-check and why required access/tooling was unavailable.

### User evidence

Record independently:

- physical device/OS and whether background/resume/reconnect behaved as expected;
- narrow/large-text/wide layout screenshots or a concise pass statement;
- perceived archive responsiveness and disclosure usability;
- confirmation that unseen styling did not change from PR-only updates; and
- any discrepancy with the worker's simulator/CLI observations.

Evidence must be factual. Do not mark one party's checkbox from the other
party's evidence.

## 5. Pass Criteria

The checkpoint passes for a participating party when all safely executable
checks show:

1. current named-branch PR is prominent and previous branches are ordered once
   in collapsed history;
2. real branch events persist while unviewed, but GitHub scheduling exists only
   while a project is effectively viewed;
3. visible status converges on fast/idle/all-state policies without overlapping
   or ghost work;
4. lifecycle/reconnect reassertion is correct and unseen state is unaffected;
5. archive is non-blocking and terminal snapshot remains immutable through
   unarchive/restart; and
6. UI remains accessible and overflow-free on the tested surfaces.

A functional mismatch is a product finding: record it under `Blockers and
Staleness`/`Findings and Plan Deltas` and open a scoped follow-up before calling
the manual check passed. Missing credentials, a physical device, or safe failure
injection is recorded as unexecuted evidence and leaves the relevant checkbox
unchecked; it is not a plan blocker.

## 6. Cleanup

After evidence is retained:

- close/delete disposable PRs and remote branches;
- remove the disposable local clone/project if no longer needed;
- remove screenshots/logs containing local paths or account details from public
  artifacts, or redact them; and
- restore normal bridge log level and app lifecycle/network settings.
