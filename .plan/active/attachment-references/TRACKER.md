# Lazy Transcript Attachments: Tracker

## Current State

- **Plan slug:** `attachment-references`
- **Series state:** Step 5 ready for PR
- **Current step:** 5/11
- **Implementation base:** `origin/main` at `82ab02c1`
- **Plan PR:** [#807](https://github.com/sesori-ai/sesori_apps_monorepo/pull/807)
- **Current PR:** Pending
- **Next action:** Publish Step 5, then begin Step 6 locally

## Plan Review

- **Verdict:** First draft rejected with actionable findings; all findings
  applied directly; corrected draft not re-reviewed merely for approval
- **Reviewer:** `architecture-plan-review`
- **Reviewed scope:** `.plan/active/attachment-references/PLAN.md` against the
  current bridge/shared/client architecture, with tracker and upload
  considerations checked for scope consistency
- **Applied findings:** live writes now route through `ChatHistoryRepository`;
  `AttachmentThumbnailBuilder`, `ChatHistoryService`, and
  `GetSessionAttachmentHandler` have explicit placement/dependencies; cache
  policy and auth cleanup stay in module_core while the Flutter adapter is dumb
  IO; stored-image loading stays in `MessageImageCubit` and the shell renders
  emitted bytes without repository access. A focused second review accepted the
  revised seams and assigned its one unnamed capture predicate finding to
  `ChatHistoryService.requiresAwaitedAttachmentCapture(part:)`.

## Delivery Steps

| Done | Step | Exact PR title | Changed-line target | State |
|---|---|---|---:|---|
| [x] | 1/11 | `🌱 [attachment-references] docs: plan lazy transcript attachments [step 1/11]` | 650-1,100 | [PR #807](https://github.com/sesori-ai/sesori_apps_monorepo/pull/807) merged |
| [x] | 2/11 | `🚧 [attachment-references] feat(protocol): describe stored transcript images [step 2/11]` | 750-1,100 | [PR #812](https://github.com/sesori-ai/sesori_apps_monorepo/pull/812) merged |
| [x] | 3/11 | `🚧 [attachment-references] feat(bridge): serve stored image renditions [step 3/11]` | 1,800-2,300 | [PR #818](https://github.com/sesori-ai/sesori_apps_monorepo/pull/818) merged |
| [x] | 4/11 | `⚙️ [attachment-references] feat(bridge): reference images in history pages [step 4/11]` | 700-1,150 | [PR #843](https://github.com/sesori-ai/sesori_apps_monorepo/pull/843) merged |
| [ ] | 5/11 | `🚧 [attachment-references] feat(bridge): reference images in live events [step 5/11]` | 1,100-1,500 | Ready for PR |
| [ ] | 6/11 | `⚙️ [attachment-references] feat(bridge): retain larger transcript images [step 6/11]` | 900-1,450 | Pending |
| [ ] | 7/11 | `⚙️ [attachment-references] feat(client): load stored image renditions [step 7/11]` | 850-1,350 | Pending |
| [ ] | 8/11 | `⚙️ [attachment-references] feat(client): cache encrypted image previews [step 8/11]` | 850-1,350 | Pending |
| [ ] | 9/11 | `⚙️ [attachment-references] feat(client): render square attachment grids [step 9/11]` | 900-1,450 | Pending |
| [ ] | 10/11 | `⚙️ [attachment-references] feat(client): load originals in the image viewer [step 10/11]` | 900-1,450 | Pending |
| [ ] | 11/11 | `🌱 [attachment-references] docs: retire lazy transcript attachments [step 11/11]` | 50-200 | Pending |

## Locked Decisions

- Transcript viewing and prompt upload are separate efforts.
- References live inside existing message-part payloads; no attachment SSE
  event is added.
- Bridge-owned content remains E2E and has no public/network-image URL.
- One bounded JSON/base64 image is transferred per request; no chunks, ranges,
  resume, or determinate progress.
- Bridge thumbnails are fixed square first-frame renditions and are persisted
  with originals in the OS user's shared attachment root.
- Shared attachment directories are keyed by plugin/backend session identity,
  independent of account and `--data-dir`; archive/history/session deletion
  retains them for other bridge databases, and cleanup is manual.
- The app persists thumbnails only; full originals remain temporary.
- Chat uses center-cropped square grids with metadata overlays and stable retry
  states.
- The existing single-image viewer remains; no gallery swiping.
- Remote HTTPS behavior remains phone-fetched and unchanged.
- Reference delivery supports 20 MB per image and 50 MB per collection; legacy
  inline delivery remains bounded at 5 MiB.
- Documents, video, prompt uploads, camera/file picker expansion, and full-image
  offline storage are excluded.

## Verification Log

- Step 1: Architecture review completed with four findings applied; corrected
  draft intentionally not re-reviewed. Against merge base `944e07e7`,
  `git diff --numstat` reports 1,097 additions and 0 deletions across the three
  plan documents, within the 650-1,100 target; `git diff --check` passes. No
  Dart/Flutter suites were run for this documentation-only step. Committed as
  `6998f477`, pushed, and opened as
  [PR #807](https://github.com/sesori-ai/sesori_apps_monorepo/pull/807).
- Step 2: Added stored-image identity, inline-default delivery capability on
  history and SSE requests, and typed rendition DTOs; regenerated shared code
  and kept bridge/client behavior explicitly inline with metadata placeholders.
  Shared full tests, focused bridge/client tests, and source analysis across
  shared, bridge, mobile, module_core, and desktop pass. Architecture
  implementation review approved the contract and compatibility boundaries.
  Committed as `9753d350`, pushed, opened as
  [PR #812](https://github.com/sesori-ai/sesori_apps_monorepo/pull/812), and
  merged as `f91fee47`.
- Step 3: Added bounded off-isolate thumbnail generation, one global decode
  lane, and the typed `POST /session/attachment` handler, then revised storage
  to one platform-native owner-only root keyed by durable plugin/backend session
  identity. Independent bridge databases reuse content-addressed bytes; archive,
  history purge, and session deletion retain shared files for manual cleanup.
  The obsolete live/archive spill split and its DI/copy/purge paths are removed.
  `dart analyze --fatal-infos` passes in the bridge app and foundation package;
  all 2,553 bridge-app tests and all 71 foundation tests pass. Focused coverage
  includes platform roots, separate-store reuse, scope isolation/traversal,
  archive access, retained bytes after purge, manual-deletion degradation,
  thumbnail bounds, and the typed route. Architecture implementation review
  approved the revised dependency, privacy, concurrency, and lifecycle seams
  with no blockers. The considerable shared-persistence revision raised Step 3
  from moderate/900-1,400 to complex/1,800-2,300 changed lines. Against the
  current `origin/main`, the final PR diff has 1,907 additions and 343 deletions
  across 34 files (2,250 changed lines), within that revised target;
  `git diff --check origin/main...HEAD` passes.
  Implementation began in `865e0334`, synchronized with `origin/main` in
  `aa94152d`, and merged as `6a9d016f` through
  [PR #818](https://github.com/sesori-ai/sesori_apps_monorepo/pull/818).
- Step 4: Threaded attachment delivery through active and archived history,
  projecting capable requests to stored references while preserving inline
  defaults, the released aggregate budget, metadata degradation, part/tool
  order, and pagination. `dart analyze --fatal-infos` passes in the bridge app;
  77 focused history/routing tests and all 2,571 bridge-app tests pass.
  Architecture implementation review approved the delivery, DI, scope, and
  compatibility seams with no blockers. After synchronization with
  `origin/main` at `ec290e14`, the final diff has 727 additions and 61 deletions
  across 11 files (788 changed lines), within the 700-1,150 target;
  `git diff --check origin/main...HEAD` passes.
  Implementation was committed as `a693d3c5` and synchronized in `5f37e20e`.
- Step 5 (local): Moved finalized part capture from
  `ChatHistoryListener` to the Orchestrator, added
  `ChatHistoryService.requiresAwaitedAttachmentCapture` plus one queued
  `capturePartForDelivery` that persists once and returns typed inline/reference
  parts projected from the complete stored collection, and gave each SSE
  subscriber and orphan queue its own attachment delivery mode with
  matching-mode adoption. `dart analyze --fatal-infos` passes in the bridge app;
  66 focused tests and all 2,584 bridge-app tests pass, including new coverage for the predicate,
  one-write dual shaping, cross-part legacy budgeting, capture failure fallback,
  listener ownership, mixed old/new subscribers, orphan mode matching, and
  orchestrator store-before-deliver, ordering, invisible parts, and generation
  fencing. Architecture implementation review approved after moving finalized
  part wire visibility and event construction fully behind `BridgeEventMapper`.
  The complete diff has 1,247 additions and 87 deletions across 16 files (1,334
  changed lines), within the 1,100-1,500 target; `git diff --check` passes.

## Findings And Plan Deltas

- **2026-08-10 - Scope split:** The user approved one active transcript-viewing
  plan and a separate considerations-only record for prompt uploads rather than
  one coupled implementation series.
- **2026-08-10 - Lean transfer:** The user approved one image per encrypted
  request, indeterminate loading, complete-image retry, and deferring chunks,
  resumability, and byte percentages.
- **2026-08-10 - Lean composer follow-up:** The user approved deferring
  restart-safe attachment drafts, send-before-upload completion, upload-state
  queued bubbles, all picker sources, and EXIF preservation after transforms.
- **2026-08-10 - Lean viewer:** The user approved square grids and retained the
  current single-image viewer without gallery swiping.
- **2026-08-10 - Architecture review:** Applied the repository-layer live-write
  seam, named bridge owners, module_core cache-policy ownership, and Cubit-owned
  image loading requested by reviewers. No scope expansion.
- **2026-08-10 - PR review:** Moved thumbnail transformation beside Layer-2
  attachment mapping, made malformed attachment responses content-redacted,
  threaded the longer timeout through both relay client layers, and kept all
  preview/original intents in `MessageImageCubit`.
- **2026-08-10 - PR review root seam:** Moved only inline-image part capture to
  one awaited `ChatHistoryService.capturePartForDelivery` call, eliminating the
  archive race and duplicate decode while preserving legacy ACP aggregate
  budgeting from complete stored collection state. Also required message-owned
  session scope, viewer-close original release, injected directory lookup, and
  generation-fenced logout cleanup.
- **2026-08-10 - Step 1 review budget:** Raised the documentation target from
  1,050 to 1,100 changed lines to record the valid second-round review findings;
  the step remains well below the repository's 1,500-line soft cap.
- **2026-08-10 - PR review lifecycle closure:** Routed rendition reads and
  source-root thumbnail writes through the history session queue, made bridge
  identity/account scope explicit, made cache cleanup mobile-activated and
  disposable, and required source-free diagnostics. Declined suggestions that
  added machinery only to already-safe or self-healing failure paths.
- **2026-08-11 - Shared bridge attachment storage:** Import identity tracing
  confirmed that each new database allocates a fresh random local session id for
  the same `(pluginId, backendSessionId)`, so moving the old local-id layout alone
  would duplicate bytes. The user selected a platform-native root shared across
  accounts/data directories, durable backend-session disk scope, and manual-only
  file lifetime. Step 3 owns this revision; Step 4 was restored and adapted to
  the shared scope before publication.
- **2026-08-11 - No internal-layout migration:** The user explicitly rejected
  backward-compatibility work for the barely exercised development/internal
  spill layout. The shared root replaces it without migration, fallback reads,
  dual writes, or sync-state repair; old files are ignored.
- **2026-08-11 - Shared-root architecture review:** The considerable plan
  revision's only blocking finding requested old-layout migration. The user's
  explicit no-internal-compatibility decision superseded that finding, so it was
  not re-reviewed or implemented. The subsequent architecture implementation
  review approved the clean replacement with no blockers.
- **2026-08-11 - Relative XDG review fix:** Relative `XDG_DATA_HOME` values now
  fall back to the absolute home-based root, preventing attachment originals
  from being written beneath the bridge's process working directory.
- **2026-08-12 - Live part ordering:** The user approved routing every finalized
  part capture through the Orchestrator. Splitting ordinary parts through the
  listener and awaited image parts through the Orchestrator could let a later
  ACP text part enter the history queue first and reverse persisted part order.
