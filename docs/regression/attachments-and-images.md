# Attachments And Images

## Capability

Images move in both directions of a session: staged in the composer and sent with
a prompt, and produced by a backend as generated images, tool output, or message
content the transcript renders live and after reload.

## Required Behavior

- The composer offers image staging only for a backend declaring prompt
  attachment support. Staged images are memory-only. They are cleared when the
  target stops supporting attachments, the session changes, or submission
  succeeds or settles after route exit; current-route failure instead transfers
  the one-shot snapshot into restoration. They never persist in a draft and travel
  inline within the staged-attachment size bound so the request fits the relay's
  message limit. The owning plugin normalizes backend-produced images into a
  client-safe attachment; host paths never cross that boundary.
- During new-session submission, one memory-only snapshot retains the exact
  attachment identities only until success, in-route restoration, or background
  settlement. A failed current-route launch restores those attachments together
  with text/voice/command intent before the composer remounts; failure after route
  exit never restores them. Reconnect and options refresh cannot erase a pending
  one-shot restoration.
- Maximum-size staged input is encoded with bounded event-loop yields through
  attachment base64, request JSON, and relay-envelope JSON/UTF-8. Encoding
  preserves exact bytes without copying attachment buffers through an isolate.
- Only bounded raster types are displayable, under per-collection count and
  decoded-byte budgets. Backend transcript output retains up to 20 MiB per image,
  50 MiB aggregate, and four candidates per logical collection. Over-budget,
  unsupported, or malformed candidates degrade to bounded metadata instead of
  failing the message; later ones are dropped rather than partially rendered.
- A remote attachment image auto-loads only over HTTPS with declared type, size,
  timeout, and content-signature checks; anything else needs an explicit user
  action.
- Stored thumbnails and originals use the typed attachment route with a longer
  request timeout, validate declared MIME, decoded size, and raster signature,
  and coalesce only concurrent requests with the same account, bridge, session,
  attachment, and rendition scope. Malformed sensitive response content never
  appears in parsing errors or diagnostics.
- Validated stored thumbnails persist in the app-private OS cache under hashed
  account and attachment identities; raw account, bridge, session, and
  attachment identifiers never appear in cache paths. Only thumbnails persist,
  each account scope is pruned to 64 MiB after writes by oldest modification
  time and then key, and reads do not refresh that order. Missing or corrupt
  entries refetch, while logout and account switch fence late writes before
  deleting the retired account scope.
- Live streaming and history replay converge: same image, same message and part
  identity, same position relative to text and tool output. The viewer offers
  copy, share, and save on the original, and an unknown shape degrades safely.
- Capable clients request stored references for normal history pages and live
  subscriptions. Opening a stored image keeps its thumbnail visible while the
  original loads and decodes, replaces it in place without resetting viewer
  state, and enables copy, share, and save only after that decode succeeds.
  Failure retains the thumbnail with an explicit accessible original retry;
  closing the viewer releases Cubit bytes and evicts the full-resolution image
  provider from Flutter's image cache, and scrolling never starts an original
  request.
- User, tool, and each maximal contiguous run of assistant file attachments use
  the same left-aligned square collection, capped at 320 px and constrained by
  the available parent width. One attachment spans the collection, two split a
  row, three use one lead tile above a pair, and larger collections continue in
  paired rows. Images center-crop within their square; metadata appears in a
  bounded bottom gradient; loading, failure, retry, and metadata-only fallbacks
  retain the same square geometry. Reduced-motion loading is static, retry is an
  explicit accessible action, and non-file assistant parts retain chronology
  between separate file runs.
- History requests default to the released bounded inline shape. A client that
  explicitly requests stored references receives bridge-scoped image metadata
  in the same part and tool-attachment order, including after archive; a missing
  stored file degrades to metadata instead of failing the transcript.
- The retained transcript limits do not raise the released inline-wire budget:
  old delivery still has one 5 MiB aggregate budget and degrades larger retained
  images to metadata, while stored-reference delivery preserves their original
  size for on-demand fetch.
- Live message-part events follow the same rule per SSE subscription. A
  subscription that asked for inline delivery keeps the released shape, and one
  that asked for stored references receives metadata for bridge-owned images in
  the same event, with no second event and no reconnect replay handing a queued
  event to a subscription of the other kind. A part carrying bridge-owned image
  bytes is persisted before its live event is delivered, so a delivered
  reference is always fetchable; if that write fails, every subscriber receives
  bounded metadata rather than a dangling identifier or oversized inline frame.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated, no plugin: the attachment contract's decode, size-bound, unknown-variant, typed stored-rendition request, scoped coalescing, timeout, sensitive-response redaction, persistent thumbnail cache, corruption recovery, bounded pruning, and auth cleanup behavior holds in its owning suites; maximum-size creation serialization yields across every encoding layer while preserving exact wire bytes; capable-client history and SSE requests opt into stored references while shared defaults preserve old clients; attachment collections retain square layouts and chronology; stored viewers remain thumbnail-first through original decode, preserve viewer state, gate original actions, retry decode/load failures, and evict/release originals on close. |
| L2 Routine | Live plugin, one representative plugin: a backend-produced image survives the plugin boundary as a bounded client-safe attachment, live and after a cold history read. |
| L3 Release | Client end to end on the release-target client platform, every supporting production plugin: staged composer images sent and echoed per attachment-capable plugin; a failed current-route creation restores exact attachment identities with the rest of the draft while background failure does not; generated and tool-output images display, text/image/text order is preserved live and after reload, and viewer copy/share/save works. |
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
- A stored rendition crosses account, bridge, or session scope; concurrent
  duplicate requests are not coalesced; or decrypted image/base64 content
  appears in an error or diagnostic.
- A thumbnail cache path exposes a raw identity, persists an original, remains
  above its per-account budget after a successful prune, or survives retirement
  of its authenticated account scope.
- An attachment collection exceeds its parent or 320 px cap, loses square tile
  geometry between states, reorders assistant content, or offers a failed image
  without an accessible retry action.
- A stored viewer fetches an original before opening, blanks the cached
  thumbnail while loading or after load/decode failure, resets zoom or drag when
  the original appears, enables actions before original decode succeeds, or
  retains original bytes/provider cache entries after closing.
- The composer offers or sends attachments to an unsupporting backend, retains
  staged images after switching to one, or the viewer acts on the wrong image.
- Failed creation loses, duplicates, or persists submitted attachment bytes;
  restores them after route exit; reconnect erases pending restoration; or
  maximum-size serialization blocks launch rendering or changes wire bytes.

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
- Older apps continue to request inline delivery by default, and newer apps
  continue to render inline images returned by older bridges. The current
  viewer remains single-image; galleries and persistent original caching are
  intentionally excluded.

## Sources

Shared attachment variants, budgets, safe-URI rules, and prompt part shapes;
per-plugin image mappers, including Cursor generated-image reading, and
descriptor capability declarations; client attachment cache, loader, and
surface tests.
