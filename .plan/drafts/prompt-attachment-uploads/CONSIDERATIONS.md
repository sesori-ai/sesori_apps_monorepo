# Prompt Attachment Upload Considerations

## Status

- **State:** Discussion record only; not an active implementation plan
- **Date:** 2026-08-10
- **Depends on:** the attachment fetch/reference contract being implemented and
  proven by `.plan/completed/attachment-references/`
- **No fixed PR count, titles, branches, estimates, or architecture are approved
  by this document.** Create a fresh active plan from then-current code before
  implementation.

## Purpose

Preserve the product decisions and code findings from the attachment-sharing
discussion without coupling prompt upload work to transcript viewing. The
future plan should reuse proven concepts where useful, but it must re-inspect
the code, backend runtimes, and production evidence rather than treating this
document as an implementation specification.

## Current User Problem

Selected prompt images are currently held as in-memory `ComposerAttachment`
objects and base64-encoded inside the final create/send request:

- gallery selection requests a 2048-pixel edge and JPEG quality 85;
- clipboard paste is supported;
- attachment count is not bounded;
- the composer allows 50 MB aggregate because that base64 request barely fits
  the relay's 64 MiB frame;
- Codex independently rejects more than 5 MiB aggregate because its outbound
  path reuses the transcript inline-image constant;
- attachments clear when Send is tapped, before bridge acceptance;
- new-session failure can therefore lose selected images and text; and
- there is no upload progress, upload retry, or cancellation boundary.

OpenCode, Codex, and Cursor currently advertise prompt-image support. Generic
ACP support remains agent-capability dependent, and Claude image input still
requires its active plugin plan's live verification before capability is
advertised.

## Agreed Lean User Experience

### Selection

- Image-only first.
- Start with native multi-select gallery plus clipboard paste.
- Defer direct camera capture and generic Files/image-file selection until usage
  evidence justifies their platform permissions, cancellation paths, and tests.
- Allow at most 10 images.
- Use one product policy initially: at most 20 MB per image and 50 MB aggregate
  per prompt.
- Preserve selected bytes and metadata exactly when they fit.
- Only resize/recompress an image when required to meet the limit. An optimized
  copy must preserve visual orientation but does not promise complete EXIF/GPS
  round-tripping.

### Preparation and sending

- A selected image may upload to bridge staging immediately in the background
  so it is usually ready before Send.
- Show an indeterminate preparing/uploading state, then ready or failed. Do not
  promise a byte percentage without a chunked transfer primitive.
- Disable Send until every selected attachment is ready.
- Upload failure keeps the text and selected images editable in the composer
  with Retry and Remove actions.
- Only after all attachment references are ready does the existing prompt queue
  own the submission. Do not put partial upload state inside
  `QueuedSessionSubmission`.
- Do not clear text or attachments until the bridge has accepted the create or
  prompt request. A failed new-session request must remain retryable.

### Lifetime

- Attachment drafts are local to the selecting device.
- The first upload version does not promise attachment restoration after app
  restart. Text draft behavior remains independent.
- A selection can remain staged in the current process while disconnected and
  begin/retry after reconnection.
- Do not build seven-day persistent upload drafts, cross-phone synchronization,
  or account/bridge draft migration in the first version.
- Bridge staging still needs a simple bounded expiry/startup sweep so a killed
  app cannot leave files forever. The future plan must choose that TTL from the
  actual upload/send lifecycle rather than inheriting the discarded seven-day
  draft requirement.

## One-Image-Per-Request Tradeoff

The approved lean direction sends one bounded image per encrypted relay request
instead of introducing binary/chunk/range messages.

Benefits:

- reuses the current request/response routing and E2E trust posture;
- no partial-file offset protocol;
- no resumable-upload registry;
- no chunk idempotency or completion transaction;
- no fake progress aggregation; and
- much smaller implementation and recovery state space.

Accepted UX costs:

- progress is indeterminate rather than a true percentage;
- a disconnect or timeout retries the complete image, not the remaining bytes;
- removing an image updates the UI immediately, but a whole frame already
  handed to the socket may finish consuming network before bridge cleanup; and
- the maximum individual image must remain comfortably below the relay frame
  ceiling after base64 and JSON overhead.

At 20 MB decoded, one image expands to roughly 27 MB before framing and remains
below the current 64 MiB ceiling. The future plan should add an
attachment-specific timeout and verify transfer/memory behavior on a slow real
mobile connection before locking the limit. Chunking should be reconsidered
only for demonstrated unreliable-network failures, larger generic files, or
video/range playback.

## Backend Mapping Direction To Reassess

Once an upload is complete, the bridge can avoid re-inlining it into the plugin
request where the backend supports a local reference:

- Codex can consume a local-image path;
- OpenCode can consume a local file URL/path through its file part;
- ACP can consume a resource link when its declared prompt image capability is
  verified; and
- Claude may still require base64 at its plugin boundary, subject to the active
  Claude plan's live verification and upstream limits.

Backend-specific mapping remains in each plugin. The shared client/bridge
contract carries only the upload reference and safe metadata.

Remove Codex's current outbound 5 MiB aggregate restriction when this reference
path exists. Keep the agreed 20 MB per-image and 50 MB per-prompt Sesori policy
unless implementation-time evidence supports a safer/simple alternative. Do
not add a rich backend limit matrix in the first version.

## Privacy And Cleanup

- Preserve original metadata for unmodified selections, as explicitly chosen by
  the user.
- If optimization is required, preserve orientation but do not add a fragile
  cross-format EXIF reconstruction subsystem.
- Staged files and thumbnails are source-adjacent user data. Keep them in
  hardened app/bridge-private storage and remove them after acceptance/expiry,
  explicit removal, logout scope removal, or failed/cancelled staging as
  appropriate to the future design.
- Never report names, paths, bytes, MIME values, sizes, attachment ids, prompts,
  or backend errors to analytics.

## Analytics Consideration

The user approved adding only a bounded `has_attachments` value to the existing
authoritative `session_message_sent` and `session_created_with_message`
outcomes. Emit it only after bridge acceptance, through
`ProductAnalyticsService`, with no new viewer-open event.

A future implementation must update the closed analytics model, exact wire
tests, curated BigQuery transforms/fixtures, and reporting coverage according
to the analytics skill. Analytics failure must remain isolated from prompt
success.

## Explicitly Deferred

- Determinate byte percentages.
- Chunking, resumable offsets, range transfer, or parallel chunk lanes.
- Send-before-ready and an upload-aware queued message bubble.
- Restart-safe attachment drafts and seven-day local/bridge draft retention.
- Cross-device draft synchronization or handoff.
- Camera and generic file picker sources.
- Video, PDF, document, audio, and generic file uploads.
- Backend-specific dynamic count/format/size capability matrices.
- Preserving all EXIF fields after resize/re-encoding.
- Reusing uploads across prompts or sessions.

## Questions For A Future Active Plan

1. Does a 20 MB one-frame upload complete reliably within an
   attachment-specific timeout on the slowest supported real mobile connection?
2. What simple bridge staging TTL covers ordinary composition/backend
   consumption without creating restart-safe draft semantics?
3. When may OpenCode/Codex safely release a staged local file after their
   asynchronous prompt endpoint reports acceptance?
4. Should file-picker images join the first release if real usage shows gallery
   and clipboard cannot reach common developer screenshots?
5. Which client owner should retain selected attachment state without coupling
   upload lifecycle to the existing prompt queue?
6. Can the future upload request use the transcript attachment reference models
   honestly, or do its independent unsent/expiring states require a separate
   sealed contract?
