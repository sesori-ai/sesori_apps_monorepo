# Attachments And Images

## Capability

Images move in both directions of a session: staged in the composer and sent with
a prompt, and produced by a backend as generated images, tool output, or message
content the transcript renders live and after reload.

## Required Behavior

- The composer offers image staging only for a backend declaring prompt
  attachment support. Staged images are memory-only, are cleared when the target
  stops supporting attachments, the session changes, or the submission completes,
  never persist in a draft, and travel inline within the staged-attachment size
  bound so the request fits the relay's message limit. The owning plugin normalizes
  backend-produced images into a client-safe attachment; host paths never cross
  that boundary.
- Only bounded raster types are displayable, under per-collection count and
  decoded-byte budgets. Over-budget, unsupported, or malformed candidates degrade
  to bounded metadata instead of failing the message; later ones are dropped
  rather than partially rendered.
- A remote attachment image auto-loads only over HTTPS with declared type, size,
  timeout, and content-signature checks; anything else needs an explicit user
  action.
- Live streaming and history replay converge: same image, same message and part
  identity, same position relative to text and tool output. The viewer offers
  copy, share, and save on the original, and an unknown shape degrades safely.
- History requests default to the released bounded inline shape. A client that
  explicitly requests stored references receives bridge-scoped image metadata
  in the same part and tool-attachment order, including after archive; a missing
  stored file degrades to metadata instead of failing the transcript.
- Live message-part events follow the same rule per SSE subscription. A
  subscription that asked for inline delivery keeps the released shape, and one
  that asked for stored references receives metadata for bridge-owned images in
  the same event, with no second event and no reconnect replay handing a queued
  event to a subscription of the other kind. A part carrying bridge-owned image
  bytes is persisted before its live event is delivered, so a delivered
  reference is always fetchable; if that write fails, every subscriber receives
  the inline shape rather than a dangling identifier.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated, no plugin: the attachment contract's decode, size-bound, and unknown-variant behavior holds in its owning suites; history projection and live event shaping preserve inline defaults and return stored references only when requested. |
| L2 Routine | Live plugin, one representative plugin: a backend-produced image survives the plugin boundary as a bounded client-safe attachment, live and after a cold history read. |
| L3 Release | Client end to end on the release-target client platform, every supporting production plugin: staged composer images sent and echoed per attachment-capable plugin, generated and tool-output images displayed, text/image/text order preserved live and after reload, viewer copy/share/save. |
| L4 Extended | Live plugin for budget-exceeding or mixed collections, malformed types, attachment remote-URL rejection, abort, and plugin restart; relay integration for a second client loading the same transcript. Every supporting production plugin. |
| L5 Full | Client end to end on alternate client platforms for picker, clipboard, animated formats, archive, and deletion; automated for an older bridge omitting attachment support; packaged or external for the released inline compatibility shape. Every supporting production plugin where supported. |

## Exploration Guidance

Vary the image source (picker, clipboard, backend-generated, tool output, remote
reference), raster format, collection size from one image to over the candidate
limit, and bytes from small to over budget. Vary whether the transcript is seen
live, after paging back, or after a reopen, and vary the plugin.

## Failure Signals

- An image renders live but is missing, duplicated, reordered, or re-identified
  after reload.
- A host path, unsafe or unnormalized source URI, or raw attachment payload
  crosses the plugin/client boundary; a raw parser error reaches a client payload
  or user-facing error, or local diagnostics discard useful parser error and
  stack context.
- An over-budget or unsupported image breaks the message instead of degrading.
- A remote attachment image is fetched without the scheme, type, size, and
  signature checks.
- The composer offers or sends attachments to an unsupporting backend, retains
  staged images after switching to one, or the viewer acts on the wrong image.

## Known Limitations

- Prompt attachment support is read from declared capabilities, so an
  unsupporting backend hides staging rather than failing at send time.
- Switching between two attachment-capable backends in the same project keeps
  staged images because they are backend-neutral inline payloads.
- Markdown inline image URLs use the platform network image loader for HTTP and
  HTTPS and do not pass through the guarded attachment loader; they are not
  covered by the remote-attachment guarantee.
- Cursor path-only generated images are read locally inside its plugin and
  delivered as bounded attachments; the host path still never crosses the wire.
- Lazy stored-image delivery remains unfinished in product clients. The bridge
  supports explicit stored-reference history reads, live events, and on-demand
  renditions, while normal clients still request inline delivery on both
  surfaces.

## Sources

Shared attachment variants, budgets, safe-URI rules, and prompt part shapes;
per-plugin image mappers, including Cursor generated-image reading, and
descriptor capability declarations; client attachment tests and surfaces.
