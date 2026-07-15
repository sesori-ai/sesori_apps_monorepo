# Stage S03: Client Presence and History

## 0. Stage Metadata

- **Stage ID:** S03
- **Status:** Pending
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main`
- **PR count:** 2
- **Manual checkpoints:** 1 advisory

## 1. Outcome

Mobile session-list/detail surfaces declare their effective viewed project with
correct lifecycle and reconnect behavior, render the current PR prominently and
prior PRs in a collapsed section, and remove the dead request-era
`PrSyncService` implementation. Shared/module-core changes remain compatible
with desktop consumers, and the complete feature receives automated and
advisory end-to-end verification.

## 2. Entry Criteria and Baseline

- S02-W04 is merged to `main`; the bridge already decodes project-view messages
  and owns adaptive scheduling.
- Each wave assesses and pins the current `main` tip before branching.
- Mobile and desktop client workspaces resolve the S01 shared contract.
- The current list load remains cache-first (`waitForPrData: false`) and explicit
  pull-to-refresh remains awaited (`true`); this is a baseline invariant, not
  work to reinvent.

## 3. Invariants and Non-Goals

- `module_core` remains pure Dart and surface-agnostic.
- API -> Repository -> Service -> Cubit direction is mandatory.
- Outbound view APIs construct feature messages and use generic Layer-0
  `RelayControlClient`; higher layers never call `ConnectionService` transport
  methods.
- Session-view/mark-seen and project-view/poll-presence state machines remain
  separate.
- List/detail cubits never depend on each other.
- Product shells contain presentation and platform wiring only.
- Desktop compiles/tests shared changes but gains no desktop-only PR UI.
- Old bridges may ignore `RelayProjectView`; request-driven refresh remains.
- History is collapsed by default, never duplicates the headline, and uses
  localized text plus Prego tokens.
- No PR details screen, links/actions expansion, review comments, or local cache
  is added.

## 4. Execution Waves

| Wave | ID | Step | Repository | Base | Can run in parallel | Merge barrier |
|---|---|---|---|---|---|---|
| W01 | S03-W01-P01 | Client project-view declarations | `sesori-ai/sesori_apps_monorepo` | `main` | No | Merge before W02 |
| W02 | S03-W02-P01 | Collapsed history UI and dead-sync cleanup | `sesori-ai/sesori_apps_monorepo` | `main` | No | Final PR merge barrier |
| W03 | S03-W03-M01 | Real-repository end-to-end check | N/A | N/A | Advisory | Does not block closure |

## 5. Integration and Manual Verification

- W01 tests list/detail claim precedence, navigation races, hidden/resumed
  lifecycle, foreground reconnect, send serialization, and old-bridge safety.
- W02 tests current/history mapping through the widget tree, stable expansion,
  archived snapshots, adaptive widths/text scales, and the retained legacy
  request paths after `PrSyncService` deletion.
- W02 runs the complete bridge/shared/client/mobile/desktop command matrix.
- W03 uses a disposable real GitHub repository and authenticated `gh` account to
  check branch switching, presence-driven cadence, history, archive, and
  terminal unarchive behavior. User and Worker evidence are independent.

## 6. Exit Criteria

- S03-W01-P01 and S03-W02-P01 are merged to `main`.
- New clients declare presence without marking conversations seen.
- Current PR remains immediately visible; history is collapsed and ordered.
- No unsupported old client/bridge pairing loses session-list functionality.
- Dead `PrSyncService` code is gone while both request dispatcher paths remain.
- Full automated verification passes.
- The advisory manual row is either evidenced or explicitly left unchecked; it
  does not block plan completion.
- Parallel-plugin plan is handed to explicit stale-plan re-review before that
  workstream resumes.

## 7. Stage-Specific Detail

Stable expansion state is presentation state, not cubit/domain state. The UI
uses session identity (`ValueKey` / `PageStorageKey`) so a `sessionsUpdated`
re-fetch that preserves the session identity does not unexpectedly collapse an
open history section.
