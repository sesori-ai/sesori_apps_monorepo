# Lazy Transcript Attachments: Tracker

## Current State

- **Plan slug:** `attachment-references`
- **Series state:** Step 1 PR open
- **Current step:** 1/11
- **Implementation base:** `origin/main` at `944e07e7`
- **Plan PR:** [#807](https://github.com/sesori-ai/sesori_apps_monorepo/pull/807)
- **Next action:** Monitor Step 1 review and CI; begin Step 2 only after merge

## Plan Review

- **Verdict:** First draft rejected with actionable findings; all findings
  applied directly; corrected draft not re-reviewed merely for approval
- **Reviewer:** `architecture-plan-review`
- **Reviewed scope:** `.plan/active/attachment-references/PLAN.md` against the
  current bridge/shared/client architecture, with tracker and upload
  considerations checked for scope consistency
- **Applied findings:** live writes now route through `ChatHistoryRepository`;
  `AttachmentThumbnailBuilder`, `MessageAttachmentService`, and
  `GetSessionAttachmentHandler` have explicit placement/dependencies; cache
  policy and auth cleanup stay in module_core while the Flutter adapter is dumb
  IO; `StoredAttachmentImageProvider` has explicit app ownership and
  constructor-injected repository access

## Delivery Steps

| Done | Step | Exact PR title | Changed-line target | State |
|---|---|---|---:|---|
| [ ] | 1/11 | `🌱 [attachment-references] docs: plan lazy transcript attachments [step 1/11]` | 650-1,050 | [PR #807](https://github.com/sesori-ai/sesori_apps_monorepo/pull/807) open |
| [ ] | 2/11 | `🚧 [attachment-references] feat(protocol): describe stored transcript images [step 2/11]` | 900-1,450 | Pending |
| [ ] | 3/11 | `⚙️ [attachment-references] feat(bridge): serve stored image renditions [step 3/11]` | 900-1,400 | Pending |
| [ ] | 4/11 | `⚙️ [attachment-references] feat(bridge): reference images in history pages [step 4/11]` | 700-1,150 | Pending |
| [ ] | 5/11 | `🚧 [attachment-references] feat(bridge): reference images in live events [step 5/11]` | 1,100-1,500 | Pending |
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
  under the existing session spill lifecycle.
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
  draft intentionally not re-reviewed. The initial documentation commit is 986
  changed lines, within its 650-1,050 target, and `git diff --check` passes. No
  Dart/Flutter suites were run for this documentation-only step. Committed as
  `6998f477`, pushed, and opened as
  [PR #807](https://github.com/sesori-ai/sesori_apps_monorepo/pull/807).

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
  seam, named bridge owners, module_core cache-policy ownership, and explicit
  app-provider injection requested by the reviewer. No scope expansion.
