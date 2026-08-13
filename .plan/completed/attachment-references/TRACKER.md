# Lazy Transcript Attachments: Tracker

## Current State

- **Plan slug:** `attachment-references`
- **Series state:** Steps 1-10 merged; Step 11 retirement in review
- **Current step:** 11/11
- **Implementation base:** synchronized `origin/main` at `14a4e405`
- **Plan PR:** [#807](https://github.com/sesori-ai/sesori_apps_monorepo/pull/807)
- **Current PR:** [#893](https://github.com/sesori-ai/sesori_apps_monorepo/pull/893)
- **Next action:** Monitor and merge the plan-retirement PR

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
| [x] | 5/11 | `🚧 [attachment-references] feat(bridge): reference images in live events [step 5/11]` | 1,100-1,500 | [PR #851](https://github.com/sesori-ai/sesori_apps_monorepo/pull/851) merged |
| [x] | 6/11 | `⚙️ [attachment-references] feat(bridge): retain larger transcript images [step 6/11]` | 900-1,450 | [PR #854](https://github.com/sesori-ai/sesori_apps_monorepo/pull/854) merged |
| [x] | 7/11 | `🚧 [attachment-references] feat(client): load stored image renditions [step 7/11]` | 1,500-2,000 | [PR #864](https://github.com/sesori-ai/sesori_apps_monorepo/pull/864) merged |
| [x] | 8/11 | `🚧 [attachment-references] feat(client): cache encrypted image previews [step 8/11]` | 1,250-1,600 | [PR #876](https://github.com/sesori-ai/sesori_apps_monorepo/pull/876) merged |
| [x] | 9/11 | `⚙️ [attachment-references] feat(client): render square attachment grids [step 9/11]` | 900-1,450 | [PR #889](https://github.com/sesori-ai/sesori_apps_monorepo/pull/889) merged |
| [x] | 10/11 | `⚙️ [attachment-references] feat(client): load originals in the image viewer [step 10/11]` | 900-1,450 | [PR #891](https://github.com/sesori-ai/sesori_apps_monorepo/pull/891) merged |
| [ ] | 11/11 | `🌱 [attachment-references] docs: retire lazy transcript attachments [step 11/11]` | 50-200 | [PR #893](https://github.com/sesori-ai/sesori_apps_monorepo/pull/893) in review |

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
  67 focused tests and all 2,587 bridge-app tests pass, including new coverage for the predicate,
  one-write dual shaping, cross-part legacy budgeting, capture failure fallback,
  listener ownership, mixed old/new subscribers, orphan mode matching, and
  orchestrator store-before-deliver, ordering, invisible parts, and generation
  fencing. Architecture implementation review approved after moving finalized
  part wire visibility and event construction fully behind `BridgeEventMapper`.
  After synchronization with `origin/main` at `82ab02c1`, the final diff has
  1,259 additions and 93 deletions across 17 files (1,352 changed lines), within
  the 1,100-1,500 target; `git diff --check origin/main...HEAD` passes.
  Implementation was committed as `c9d012fb` and synchronized in `23cc34ef`.
- Step 5 (merged): Review fixes ordered all finalized part updates and removals
  through the Orchestrator, fenced queued work by plugin generation, filtered
  unknown parts, and prevented stale removals from advancing freshness. Bridge
  CI passed and [PR #851](https://github.com/sesori-ai/sesori_apps_monorepo/pull/851)
  squash-merged as `ec479cef`.
- Step 6 (local): Added backend-neutral transcript retention limits of 20 MiB
  per image, 50 MiB aggregate, and four candidates while retaining the separate
  5 MiB inline-wire limit. OpenCode, Codex, ACP, Cursor, Claude, and OMP's ACP
  composition now retain larger backend-produced images without changing
  prompt-input limits. Successful live/history storage still projects the
  released inline budget, and failed writes degrade image bytes to metadata so
  no oversized frame bypasses projection. Fatal analysis and full tests pass in
  shared (391 tests), OpenCode (419), Codex (361), ACP (240), Cursor (126),
  Claude (213), and OMP (30); 45 focused bridge app projection, rendition,
  Orchestrator, and SSE tests pass. Architecture implementation review approved
  the shared constant boundary, plugin ownership, independent wire/prompt
  limits, and capture-fallback layering with no blockers. Review fixes preserve
  Claude block indexes, enforce Codex's per-image cap after batch merging, and
  enforce the aggregate retention budget across every stored sibling when a
  live part is appended or updated. Fatal bridge-app analysis and 37 focused
  history tests pass after the latest fix. Against merge base `ec479cef`, the
  current diff has 557 additions and 147 deletions across 28 files (704 changed
  lines), below the 900-1,450 estimate; `git diff --check` passes. The initial
  implementation was committed as `29235b47`, pushed, and opened as
  [PR #854](https://github.com/sesori-ai/sesori_apps_monorepo/pull/854).
  CI passed 16/16 and the PR squash-merged as `abac4e99`.
- Step 7 (local): Added typed thumbnail/original attachment requests with a
  two-minute relay timeout, source-free sensitive response failures, scoped
  in-flight coalescing, MIME/base64/size/signature validation, and independent
  preview/original Cubit state. Stored requests use account, bridge,
  message-owned session, attachment, and rendition identity; both history and
  SSE delivery remain inline. Module-core fatal analysis and all 1,089 tests
  pass; mobile fatal analysis and 64 focused transport/session-detail tests
  pass; desktop fatal analysis passes. Architecture implementation review
  approved after fixes for message-owned session authority, transcoded
  thumbnail MIME, non-success body redaction, and the generic timeout seam.
  Targeted DI generation produced the correct registration but the generator
  command exits non-zero on unrelated pre-existing product-analytics enum
  parsing errors. Against `origin/main` at `3ae9dd43`, the current diff has
  1,544 additions and 362 deletions across 30 files (1,906 changed lines),
  within the revised 1,500-2,000 target; `git diff --check` passes. Actual
  cross-layer identity, transport, state, and security work raised Step 7 from
  moderate to complex.
  Committed as `f8c5a3b5`, pushed, and opened as
  [PR #864](https://github.com/sesori-ai/sesori_apps_monorepo/pull/864).
  Review fixes tightened original bounds, preserved failure context, scoped
  Cubit/request reuse, coalesced raw transport before per-caller mapping, and
  moved strict base64 validation into the decode isolate. CI passed 12/12 and
  the PR squash-merged as `88059e20`.
- Step 8 (local): Added a pure-Dart thumbnail storage capability and a mobile
  app-private temporary-directory adapter with atomic writes, safe path
  segments, and metadata listing. `MessageImageRepository` now persists only
  validated thumbnail bytes under SHA-256 account/attachment identities,
  recovers from missing or corrupt entries, coalesces matching work, prunes each
  account scope to 64 MiB by oldest modification time, and fences auth cleanup
  against late fetches and writes. Mobile eagerly activates the disposable auth
  cleanup service after core DI; desktop remains bootable with no storage
  binding or cache-service resolution. History and SSE requests remain inline.
  Fatal analysis passes in module_core, mobile, and desktop; all 1,105
  module-core, 972 mobile, and 16 desktop tests pass, including 28 focused
  cache-policy tests, 31 focused mobile storage/DI/widget tests, and two desktop
  DI tests. After merging the Dart 3.13 generator fix from `origin/main`, DI
  generation succeeds and reproduces both intended registrations. Architecture
  implementation review approved the foundation, repository/service, platform,
  DI, privacy, and
  lifecycle seams with no blockers. Review fixes reclaim abandoned atomic-write
  files without touching active writes, tolerate files disappearing during
  metadata scans, and retry failed account retirement before same-account cache
  access while bypassing stale cache when deletion keeps failing. The focused
  review matrix passes 29 repository tests, 33 mobile storage/DI/widget tests,
  and two desktop DI tests, plus fatal analysis in all three owning products.
  A later review fix excludes active atomic-write files from metadata while
  preserving abandoned-file reclamation; eight platform tests and fatal mobile
  analysis pass. Against the synchronized base `57e1d0ea`, the PR diff has
  1,486 additions and 77 deletions across 17 files (1,563 changed
  lines), within the
  review-revised 1,250-1,600 target;
  `git diff --check origin/main...HEAD` passes. Published as
  [PR #876](https://github.com/sesori-ai/sesori_apps_monorepo/pull/876), which
  merged as `57c2af97`.
- Step 9 (local): Added one capped, parent-responsive square attachment
  collection for user and tool attachments and maximal contiguous assistant
  file runs. One item spans the row, two split evenly, three use a lead tile
  plus a pair, and larger collections use paired rows. Loaded images center-crop
  with bounded metadata overlays; loading, metadata, rejection, and retry states
  retain square geometry, with static reduced-motion loading and an accessible
  explicit retry. Existing remote URL safety, per-tile `MessageImageCubit`
  ownership, and image-viewer behavior remain intact; normal history and live
  requests still use inline delivery. All 29 focused file/assistant widget tests
  pass, including new grid, width-cap, chronology, long-metadata,
  reduced-motion, retry, and semantics coverage. After synchronizing with
  `origin/main` at `6ee94bfe`, all mobile tests, mobile fatal analysis,
  `dart pub get`, focused formatting, and `git diff --check` pass.
  Architecture implementation review approved the presentation flow, cubit
  ownership, backend neutrality, compatibility boundary, and chronology with no
  findings. The local diff has 568 additions and 117 deletions across nine files
  (685 changed lines), below the 900-1,450 estimate because the existing
  `FilePartWidget`, `MessageImageCubit`, and viewer seams were reused without new
  state infrastructure. No analytics event was added: passive tile rendering or
  taps have no defined product decision or authoritative outcome to measure.
  Published as [PR #889](https://github.com/sesori-ai/sesori_apps_monorepo/pull/889).
  Review fixes preserved hidden assistant run boundaries, filtered unsupported
  attachments before layout, stabilized tile identity, corrected semantics and
  theme contrast, retained metadata under extreme scaling, kept overlays from
  intercepting retry, and made immutable inline rejection terminal while
  preserving retry for remote failures. Fatal analysis, 34 focused widget
  tests, the full mobile suite, and CI passed; the PR squash-merged as
  `4b3d67f3`.
- Step 10 (local): The existing tile-owned `MessageImageCubit` now releases
  original state on viewer close. Stored-image viewers open on the thumbnail,
  start the original request only after opening, replace the in-memory provider
  in place after validation, gate copy/share/save until then, and retain the
  thumbnail with retry when the original is unavailable. History and SSE
  requests now opt into `storedReference`; shared compatibility defaults remain
  unchanged. Module-core fatal analysis and all 1,122 tests pass; mobile fatal
  analysis and the full suite pass, including 36 focused file/assistant widget
  tests; desktop fatal analysis and five focused bridge history/archive parity
  tests pass. Module-core code generation succeeds with its expected external
  registration warnings, and localization generation reproduces the intended
  API. Architecture implementation review approved the transport activation,
  cubit lifecycle, and app-shell presentation seams with no findings. An
  isolated slot-1 source bridge authenticated, registered, exposed debug port
  9971, connected to the relay, and shut down cleanly. That fresh slot imported
  no backend projects or sessions, so cold/warm transcript and reconnect media
  behavior could not be exercised meaningfully without creating external test
  session data; the automated cache, history, SSE, and viewer coverage remains
  the evidence for those paths. Against `origin/main` at `4b3d67f3`, the local
  implementation diff excluding this tracker bookkeeping has 876 additions and
  152 deletions across the other 14 files (1,028 changed lines), within the
  900-1,450 estimate because Step 7 already supplied the bounded transport,
  repository, and independent preview/original state machines; `git diff
  --check` passes.
- Step 10 (merged): Review fixes stage Flutter decoding before swapping the
  original or enabling actions, retain the thumbnail on decode failure, preserve
  viewer zoom/drag/Hero state, evict the full-resolution provider on close, and
  keep action Cubit ownership under `BlocProvider(create:)`. Fatal analysis, 37
  focused widget tests, the full mobile suite, CI 13/13, and Cubic approval
  passed; [PR #891](https://github.com/sesori-ai/sesori_apps_monorepo/pull/891)
  squash-merged as `14a4e405` with no unresolved threads.
- Step 11 retirement gate: On the slot-owned `sesori-dev-1` simulator and
  authenticated slot-1 source bridge, a fresh Codex session generated a real
  PNG attachment. The app received a stored reference, rendered its 320 px
  square thumbnail, opened thumbnail-first, enabled copy/share/save after the
  original decoded, reopened from the warm thumbnail cache, survived a bridge
  stop/start and relay reconnect, and rendered again after leaving and reopening
  the session from cold history. The slot bridge and simulator were shut down
  after the check. Together with the Step 10 automated matrix, this completes
  the required regression evidence for retirement.
- Step 11 (in review): Against merge base `14a4e405`, `git diff --numstat`
  reports 33 additions and 11 deletions across four documentation files (44
  changed lines), below the 50-200 estimate because Git records the active-to-
  completed plan move as renames rather than deleting and re-adding both files;
  `git diff --check` passes. Published as
  [PR #893](https://github.com/sesori-ai/sesori_apps_monorepo/pull/893).

## Findings And Plan Deltas

- **2026-08-13 - Thumbnail cache budget:** The user approved a 64 MiB
  per-account cache scope with oldest-on-write pruning. Reads do not update file
  timestamps, avoiding an LRU index or background worker.
- **2026-08-13 - Step 8 complexity:** Persistence, auth-generation cleanup,
  mobile eager lifecycle activation, and desktop lazy-startup boundaries raised
  Step 8 from moderate/850-1,350 to complex/1,250-1,500 changed lines. Review
  hardening for abandoned writes, metadata races, and failed-retirement retry
  raised the ceiling to 1,600 without changing complexity.

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
