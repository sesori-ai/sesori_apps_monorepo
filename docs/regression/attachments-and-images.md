# Attachments And Images

## Capability

Images move in both directions of a session: staged in the composer and sent with
a prompt, and produced by a backend as generated images, tool output, or message
content the transcript renders live and after reload.

## Required Behavior

- The shared composer actions pill opens from its chevron to show the supported
  image-attachment action as a plus and the slash-command picker. Open actions
  replace the chevron, without a manual collapse control, and choosing either
  action automatically collapses the pill. Both themes use the flat bordered
  44pt surface; command-only harnesses retain a single centred action. Recording
  and transcription still disable the revealed actions. With a pointer the
  actions show without the chevron. On both surfaces they fold back behind the
  chevron once the composer holds text, and the chevron still reopens them.
  Under reduced motion the pill opens and folds at once.
- The shared composer offers staging only while the backend declares prompt
  attachment support (images) or the bridge saves uploads (files), and only
  when its product shell supplies a real picker.
  Desktop opens a native file dialog for any files, routed like a drop
  (below). On mobile the plus opens a Photos / Files menu where the bridge
  saves uploads, and the gallery straight away anywhere else, including while
  that answer is still unknown. Files picks are routed like a drop: on iOS
  through the system document picker's copies, and on Android through the
  app's own document picker, which copies only files of at most 50 MB into the
  app's cache (cleared at each pick) and counts the rest in the over-budget
  notice without reading them. A gallery photo keeps its own name; one that
  image_picker hands over under its own copy name (always on iOS, and on
  Android when the photo has no display name) is named `photo.<ext>`.
  Shared core validates picked or clipboard bytes by raster signature and the
  outbound size bound rather than trusting an extension or platform MIME.
  Before the size bound applies, shared core shrinks any staged image above
  1 MiB except a GIF, which shared core leaves untouched so it keeps its
  animation: off the UI isolate, it bakes the EXIF orientation, resizes the
  long side to at most 2048 px without upscaling, composites transparency onto
  white and re-encodes a JPEG at quality 85, renaming the file's extension to
  match. A typical oversized screenshot or photo therefore stays well inside
  the inline image budgets backends accept. It keeps the original when the
  result is not smaller, when decoding fails, or when the image exceeds 24
  million pixels decoded; such an original is still held to the size bound and
  can still exceed a backend's own limit. On iOS the gallery picker applies the
  same size and quality natively before shared core sees the bytes: it scales
  a GIF frame by frame so it keeps its animation, and turns HEIC into JPEG. On
  Android the picker takes the original file. An animated GIF is handed over
  untouched, so it keeps its animation at its original size. Any other photo,
  HEIF included, is decoded by the platform straight to at most 2048 px on its
  long side, so a photo of any resolution is never decoded in full, and is
  re-encoded as a JPEG at quality 85 off the UI isolate. A photo already
  within that size in a format shared core reads is handed over as it is, and
  so is a photo the platform can't decode: shared core then shrinks it as above
  when it reads the format, and otherwise gives the unsupported-format notice.
  Staged images and files are memory-only. Staged images are cleared when the
  backend stops supporting attachments and staged files when the bridge stops
  saving uploads, and both when the session changes, or submission succeeds or
  settles after route exit; current-route failure instead transfers the one-shot
  snapshot into restoration. They never persist in a draft and travel inline
  within the staged-attachment size bound so the request fits the relay's message
  limit. Existing-session picker and paste entry are absent while that chat's
  harness is blocked; a completion racing the block cannot dispatch, and
  the availability gate does not retain staged bytes. The owning plugin normalizes
  backend-produced images into a client-safe attachment; host paths never cross
  that boundary.
- Selected images use the shared Prego preview: 52px square center crops, 10px
  corners, a subtle border, and a 14px close badge whose 24px target stays in
  the tile's corner in both themes. Tapping the rest of the tile opens the
  staged image in the full-screen viewer, view-only, on the new session page
  too. New-session and existing-session composers keep one 52px-high
  horizontal row with 8px gaps. Overflow scrolls, with edge fades indicating
  hidden images in either direction. The leading fade appears after scrolling
  and clears on returning to the start; the trailing fade clears at the end.
  Each endpoint image and remove action is then fully visible, and both fades
  disappear when the remaining images fit.
  Removing one image preserves the remaining image identities and send bytes;
  removing all images removes the strip.
- On desktop, files dragged anywhere over the session-detail pane, the
  new-session pane or the home pane show a full-pane "Drop files to add
  them to your prompt" hint and go to that pane's composer, and to exactly one
  composer when a cross-fade briefly mounts two. The hint shows only while a
  composer there can take files, and follows a composer that appears or starts
  recording mid-drag. A drop on a pane with no composer gets a "Files can't be
  added here" notice; while the composer records or transcribes there is no
  hint, and a drop gets "Finish recording before adding files". A pane under a
  pushed page or a dialog takes no drops. Picked and dropped paths share one
  rule in shared core: a supported raster image (by its header bytes) is staged
  while the backend accepts attachments and, once downscaled, it fits the rest
  of the prompt's 50 MB budget. A file above 50 MB is never read in full.
  Anything else, including folders and images that are unsupported or over
  budget, is typed into the prompt at the caret as its absolute path when the
  active bridge runs on this computer; paths with whitespace are quoted and
  separated by spaces. On a bridge on another computer that saves uploads, any
  other file that fits the rest of the budget stages as a file tile with its
  original bytes and name (a file glyph over its extension, the name as its
  tooltip and label); a folder is not added. On an older bridge on another
  computer nothing but a stageable image is added. Either way one notice has a
  line per reason (file, folder, a path that couldn't be read, images the
  agent doesn't take, the 50 MB budget), each counting the files turned away for it. This works regardless of
  backend attachment support. The plus action is offered while the backend
  takes images or the bridge saves uploads. A pasted or picked image for a
  backend without images (Grok) stages as a file, named after the picked file
  or `pasted-image.<ext>`, when the bridge saves uploads. A staged file is sent
  as `application/octet-stream`, so the bridge saves it. When the backend stops
  taking images, staged images are cleared, and when the bridge stops saving
  uploads, staged files are; an unknown answer clears nothing. Images and files
  from several picks, pastes and drops stage in the order they were added, even when an earlier one takes longer to downscale. A late
  result never lands in a composer that moved to another draft.
- On desktop, a paste takes files copied in Finder or Explorer first, then an
  image, then text. Copied files go through the drop rule above, whatever the
  backend's attachment support, so a Finder copy of files that still exist
  never pastes as the file's icon or name. A late result keeps the selection
  from when paste was pressed, unless the text changed meanwhile. Copied files
  are read when paste is pressed, even while an earlier image is still
  preparing. The paste falls back to the image or text when any copied path
  no longer exists, and when the clipboard's text is a link to anything other
  than a file: macOS reports a copied `https://example.com/` as the path `/`,
  and that paste stays text. Mobile paste takes only image bytes and text.
- Send pressed while a pick, paste or drop is still preparing an image waits
  for it: the Send button shows a spinner and further presses do nothing, then
  the prompt goes out once, with every image that staged. An image that fails
  to stage gets its usual notice and the prompt goes without it. Moving to
  another session or draft while Send waits abandons that send.
- Antigravity's descriptor advertises prompt attachments and the shared ACP mapper sends bounded inline image parts.
  Provider-generated image content uses the same shared collection limits after Antigravity removes redundant raw image
  copies; a provider-local image path remains bounded metadata and is never opened or sent to a client.
- GitHub Copilot's production descriptor advertises prompt attachments
  unconditionally, and the shared ACP mapper sends bounded inline image parts
  without renegotiating that declaration against initialization metadata. A
  vision-capable selected model must receive the exact image; a model or account
  rejection remains a visible backend failure rather than silently dropping it.
- During new-session submission, one memory-only snapshot retains the exact
  attachment identities only until success, in-route restoration, or background
  settlement. A failed current-route launch restores those attachments together
  with text/voice/command intent before the composer remounts; failure after route
  exit never restores them. Reconnect and options refresh cannot erase a pending
  one-shot restoration. The submitting surface keeps its staged-image previews
  through local sending, acceptance, bridge queuing, and dispatch,
  including fast handoffs that skip intermediate UI frames and scrolling away
  and back. The prompt queue owns these memory-only references with a 50 MB
  aggregate budget per session, evicting the oldest previews for newer ones.
  Evicted previews use the attachment count; sending is unaffected. Retained
  previews are released when the prompt leaves the bridge queue or the session
  closes; delivered messages use their transcript attachments. Other surfaces
  and reopened sessions show the bounded attachment count, without
  rebroadcasting or persisting staged bytes.
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
  time and then key, and reads do not refresh that order. One shared
  file-backed storage serves phone and desktop over each shell's temporary
  directory lookup; writes land atomically through a uniquely named temporary
  file, and a write interrupted by process death may leave that temporary file
  behind, which metadata listing ignores. Missing or corrupt
  entries refetch, while logout and account switch fence late writes before
  deleting the retired account scope.
- Live streaming and history replay converge: same image, same message and part
  identity, same position relative to text and tool output. The viewer offers
  copy and save on the original, plus share where the product shell has a
  registered platform implementation; unsupported actions are omitted, and an
  unknown shape degrades safely. The shared transcript receives these
  capabilities from its product shell: both shells register the same pasteboard
  copy and system share-sheet adapters, mobile keeps its own save adapter, and
  desktop saves through the native file selector and shares on macOS and
  Windows. Linux omits Share because the
  current share plugin has no Linux implementation. The root image-viewer route
  retains the same injected capability scope even when it is above the session
  route's navigator.
- Capable clients request stored references for normal history pages and live
  subscriptions. Opening a stored image keeps its thumbnail visible while the
  original loads and decodes. Stored thumbnails preserve the source aspect ratio;
  only the square collection presentation center-crops them, and the Hero flight
  reveals the full thumbnail while resizing toward its contained bounds. The
  decoded original then fades in without resetting viewer state. Available
  copy, share, and save actions enable only after that decode succeeds. Failure
  retains the thumbnail
  with an explicit accessible original retry; closing the viewer releases Cubit
  bytes and evicts the full-resolution image provider from Flutter's image cache,
  and scrolling never starts an original request. Reduced motion skips the
  viewer route and image-swap animations.
- The viewer closes through its close button, a free-form drag, a hardware
  Escape key, and system back. Back closes only the viewer and keeps the session
  open, including when the Android back gesture delivers a second pop while the
  viewer is still fading out.
- User, tool, and each maximal contiguous run of assistant file attachments use
  the same compact collection: 100 px square previews with 4 px corners and
  6 px gaps, wrapping within the parent width (and shrinking if the pane is
  narrower than one preview). Attachment-only outgoing bubbles shrink to their
  thumbnail run instead of filling the maximum bubble width. Loaded images center-crop without an obscuring
  metadata overlay; filenames remain accessible and in the full-screen viewer.
  Assistant Markdown images use the same compact crop and reveal the contained
  image during the viewer transition. Loading, failure, retry, and metadata-only
  fallbacks retain square geometry and bounded metadata. Reduced-motion loading
  is static, retry is an accessible 44 px icon button, and non-file assistant
  parts retain chronology between separate file runs.
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
- The bridge advertises `supportsFileUploads`; an older bridge omits it and
  reads as unsupported. It passes a `file_data` part to the plugin unchanged
  only when its mime starts with `image/` and the plugin takes attachments.
  Every other one (any file, or an image for Grok) is saved as
  `~/.sesori/uploads/<sessionId>/<YYYY-MM-DD>-<random>/<sanitized name>`,
  owner-only, and replaced in the same position by a visible
  ``Attached file "<name>": `<path>` `` note, which a new session's live user
  message shows too. A repeated accepted prompt saves nothing again, and a
  command or a create with a command saves nothing. Deleting a session from
  Sesori removes its uploads folder, and each save starts a best-effort sweep
  of file folders dated more than 30 days before it.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated, no plugin: the attachment contract decodes, enforces its size bound, and rejects unknown variants; composer picks and clipboard bytes share signature/size validation; an oversized PNG is staged as a JPEG at most 2048 px on its long side with transparency on white and orientation applied, while a small image and a GIF stay untouched; Send pressed while an image is still being prepared waits with a spinner, sends once with it, goes without an image that fails to stage, and is abandoned when the draft changes; an Android pick hands a GIF over untouched, re-encodes any other photo above 2048 px on its long side, or in a format shared core can't read, through the platform decoder to a JPEG at most 2048 px on its long side, and hands one the platform can't decode to shared core, which turns it away only when it can't read the format either; a stored thumbnail renders with its aspect ratio preserved; staged previews retain Figma geometry and theme tokens, scroll without wrapping, expose accessible removal, and submit the untouched remaining bytes; local transcript thumbnails survive queue acceptance and dispatch with and without prompt text, coalesced UI frames, and row recycling; queue reconciliation and removal release references, aggregate retained bytes remain bounded, and evicted previews use count-only fallback; transcript previews stay compact and unobscured in both themes, wrap without reordering, and retain accessible retry and full-screen viewing at enlarged text sizes. |
| L2 Routine | Live plugin, one representative plugin: a backend-produced image survives the plugin boundary as a bounded client-safe attachment, live and after a cold history read. Automated, no plugin: typed stored-rendition requests coalesce per scope and time out; capable-client history and SSE requests opt into stored references while shared defaults preserve old clients; maximum-size creation serialization yields across every encoding layer while preserving exact wire bytes; attachment collections keep center-cropped square layouts and chronology; stored viewers morph that crop toward the contained thumbnail's fitted bounds, fade in the decoded original, preserve viewer state, and gate original actions. Shared routing of picked and dropped paths covers images, files, folders, quoted paths, budget and local versus remote bridges; dropped paths reach the composer as staged images and caret text; copied files route only when every path exists and paste ahead of the clipboard's image and text, whatever the backend's attachment support, and the desktop clipboard adapter reads a copied web link as no files; the desktop pane hint and delivery appear only while a composer listens, to the last one only; desktop adapter coverage verifies file-pick and file-save success and cancellation, and the shared `module_app_ui` adapter coverage verifies pasteboard reads and writes and the forwarded share payload (bytes, MIME type, file name, and popover origin). Automated bridge, no plugin: the bridge advertises file uploads; an image goes inline to a plugin that takes images, and every other `file_data` part is saved owner-only (700 folders, 600 files) under the session's folder and replaced in place by its note; a repeated accepted prompt and a command save nothing; a create saves under the id it commits, and joins the notes into its live user message; saved names are sanitized and never escape their folder; deleting a session family removes every member's uploads whatever `deleteSessionFolder` says; the sweep removes only folders dated more than 30 days back and skips unparseable ones. |
| L4 Extended | Client end to end on mobile and desktop: change availability from another surface while an existing-session picker is open or an attachment is staged; no blocked send lands, transcript images remain usable, and recovery presents a fresh composer. Live plugin for budget-exceeding or mixed collections, malformed types, attachment remote-URL rejection, abort, and plugin restart; relay integration for a second client loading the same transcript. Every supporting production plugin. Automated, no plugin: sensitive-response redaction, persistent thumbnail cache corruption recovery, bounded pruning, auth cleanup, viewer decode and load retry, and original eviction and release on close. |
| L5 Full | Client end to end on alternate client platforms for picker, clipboard, animated formats, archive, and deletion; automated for an older bridge omitting attachment support; packaged or external for the released inline compatibility shape. Every supporting production plugin where supported. |

## Exploration Guidance

Vary the image source (picker, clipboard, backend-generated, tool output, remote
reference), raster format, collection size from one image to over the candidate
limit, and bytes from small to over budget. Vary whether the transcript is seen
live, after paging back, or after a reopen, and vary the plugin. For
Antigravity, vary inline prompt images, standard provider image content,
redundant raw image aliases, path-only metadata, mixed text/image output and
live versus replay. For Copilot,
vary a vision-capable selected model, a model that rejects images, and an
account-level rejection without changing the descriptor's capability claim.

## Failure Signals

- A blocked existing chat offers picker or paste submission; a late picker result
  reaches the bridge; staged bytes survive solely because availability
  recovered; or read-only mode prevents viewing existing transcript images.
- A locally submitted image within the retained-preview budget becomes only an
  attachment count during bridge queuing or dispatch, disappears after
  scrolling back to the pending row, or remains retained after the row leaves
  the bridge queue; retained preview bytes exceed the session's aggregate budget.
- An image renders live but is missing, duplicated, reordered, or re-identified
  after reload.
- A non-image `file_data` part reaches a plugin; a saved name escapes its
  folder or a saved file isn't owner-only; a new session's files land under an
  id other than its own; a deleted session's uploads folder stays.
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
- A transcript preview exceeds its parent or 100 px cap, loses square tile
  geometry between states, reorders assistant content, or offers a failed image
  without an accessible retry action.
- A stored viewer fetches an original before opening, blanks the cached
  thumbnail while loading or after load/decode failure, opens a permanently
  cropped thumbnail instead of revealing its original aspect ratio, expands the
  crop beyond the full image's fitted bounds during the Hero flight, jumps when
  the original appears, resets zoom or drag, enables actions before original
  decode succeeds, or retains original bytes/provider cache entries after closing.
- Staged previews wrap, grow the composer with the image count, hide the final
  remove action behind the fade, remove a different image after scrolling, or
  change the staged bytes sent to the backend.
- A dropped or picked file is lost without a notice, inserted twice, read in
  full when it is not a stageable image, typed as a path for a bridge on
  another computer, or staged into a composer other than the pane's; a drop
  over a pane without a ready composer shows the hint or passes without a
  notice; a notice for mixed reasons names only one of them; images stage out
  of the order they were added; or a pane under another page or a dialog takes
  the drop.
- A copied web link pastes as a path, or a Finder copy pastes as the file's
  icon or name instead of the file.
- The mobile plus offers Files where the bridge doesn't save uploads, or opens
  the menu when only Photos applies; an Android Files pick of a file over
  50 MB is copied, read, or crashes the app instead of getting the notice; a
  staged photo is labelled with image_picker's `image_picker_<id>` name.
- An image above the downscale threshold is staged unshrunk although it could
  shrink, a GIF loses its animation, a rotated photo is staged sideways, a
  transparent image gets a black background, a downscale blocks the UI, or a
  paste that settles after its composer changed stages into the new one.
- Send pressed while an image is still being prepared goes out without it,
  goes out twice, shows no spinner while it waits, or sends into a session the
  user has since left.
- The composer offers or sends images to a backend without attachment support,
  or files to a bridge that doesn't save uploads, retains staged images or
  files after switching to such a target, clears them while a capability is
  still unknown, or the viewer acts on the wrong image.
- Antigravity reads or sends a provider-local image path, retains duplicate raw image bytes, drops a supported standard
  image, diverges between live and replay, or bypasses existing count/byte/type limits.
- Copilot advertises images but drops the ACP image part, accepts it with the
  wrong selected model, or hides a model/account rejection.
- Failed creation loses, duplicates, or persists submitted attachment bytes;
  restores them after route exit; reconnect erases pending restoration; or
  maximum-size serialization blocks launch rendering or changes wire bytes.

## Known Limitations

- Prompt attachment support and upload saving are read from declared
  capabilities, so a target that takes neither hides staging rather than
  failing at send time.
- Several images that each stay just under the downscale threshold can still
  exceed a backend's own aggregate inline-image limit; that send fails visibly
  at the bridge.
- Switching between two attachment-capable backends in the same project keeps
  staged images because they are backend-neutral inline payloads.
- Markdown inline image URLs use the platform network image loader for HTTP and
  HTTPS and do not pass through the guarded attachment loader; they are not
  covered by the remote-attachment guarantee.
- Antigravity native prompt-image acceptance and Google-generated image behavior remain unverified; account or
  model rejection must stay visible and does not justify reading path-only provider output.
- Only images reach an older bridge on another computer: a non-image file
  dropped or picked there is turned away with a notice. Folders never reach a
  bridge on another computer.
- Saved prompt files are removed with their session when it is deleted from
  Sesori; that removal is best-effort. Age cleanup is a best-effort sweep that
  runs only after a later save on the same bridge, so a file can stay well past
  30 days when nothing else is uploaded. Files of a create that bound to an
  existing session, of a failed create, of a failed send that was retried, or
  of a session removed outside Sesori go only by age. Some harnesses ask before
  reading outside the session's working directory (see
  `docs/HARNESS_CAPABILITIES.md`).
- Pasting files copied in a file manager works on desktop only. On Windows and
  Linux it is covered only by adapter tests.
- Mobile has no drop. On iOS a gallery photo is always named `photo.<ext>`,
  since image_picker doesn't pass on the library's file name, and Files copies
  stay in the app's tmp folder until iOS clears it.
- An Android GIF above the 50 MB budget is turned away as too large, since
  it is never shrunk. HEIF photos need Android 9 (API 28) or later; on Android
  7 and 8 they get the unsupported-format notice.
- On an older bridge, the plus action follows backend attachment support, so a
  backend without it offers no picker even on a local bridge, where drop still
  inserts paths.
- Copilot does not negotiate its descriptor's attachment support against the
  initialized CLI capability. Image acceptance can vary by selected model and
  account entitlement; a visible upstream rejection is expected coverage, not a
  bridge failure.
- Cursor path-only generated images are read locally inside its plugin and
  delivered as bounded attachments; the host path still never crosses the wire.
- Older apps continue to request inline delivery by default, and newer apps
  continue to render inline images returned by older bridges. The current
  viewer remains single-image; galleries and persistent original caching are
  intentionally excluded.

## Sources

Shared attachment variants, budgets, safe-URI rules, and prompt part shapes;
per-plugin image mappers, including Cursor generated-image reading, Antigravity raw-alias normalization, the shared
ACP image mapping used by Antigravity and Copilot, and descriptor capability declarations;
shared client composer validation, attachment cache, loader, viewer, and
surface tests under `client/module_core` and `client/module_app_ui`; mobile
picker (including the Android `DocumentPickerService.kt` and its JVM tests), voice, and keyboard composition under `client/app`; desktop picker,
file, copied-file clipboard and session-detail adapters under `client/desktop`; and the shared
pasteboard and share adapters under `client/module_app_ui/lib/src/platform/`.
