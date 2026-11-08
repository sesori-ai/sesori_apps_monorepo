# Issue #2400 phase 2: send any file to a bridge on another computer

Durable plan. This is a multi-PR series, so step 1 commits this as
`.plan/active/file-transfer/PLAN.md`. Code facts come from `origin/main` @ 82eeff0aa6.
The user settled decisions D1-D6 on 2026-11-08 (see Decisions, at the end). Run
`architecture-plan-review` through a sub-agent before step 1 is published, because
this plan changes a wire contract and adds a bridge class.

## Goal

1. When the bridge is on another computer, a non-image file, or an image the
   harness can't take, is sent to the bridge. The bridge core saves it to disk and
   gives the agent a text part naming the path, so every harness behaves like
   phase 1's local case.
2. The bridge advertises this. New clients send files only to bridges that
   advertise it, and older bridges keep the phase 1 notice.
3. Saved files are deleted with their session, and anything older than 30 days
   is swept.
4. Mobile can pick any file, as well as photos.
5. On desktop, files copied in Finder or Explorer can be pasted.
6. One analytics event shows whether people adopt remote file transfer.

## Current behavior (origin/main)

- **Client routing.** `ComposerAttachmentDispatcher.routeHostPaths`
  (`client/module_core/lib/src/services/composer_attachment_dispatcher.dart`) does
  one of three things with each path:
  - It stages a supported raster image when `attachmentsSupported == true` and the
    image fits.
  - On a local bridge, it inserts the path as text.
  - On a remote bridge, it rejects the path as `notTransferable` (arb
    `sessionDetailFilesNotTransferable`). Folders are rejected the same way.
- **Staged attachments.** A `ComposerAttachment{mime, bytes, filename}` is an
  image by contract. Both send paths emit `PromptPart.fileData`: `SessionApi._buildParts`,
  and `_BoundedCreateSessionBody`, which encodes the base64 with bounded yields.
  The budget is `maxComposerPromptAttachmentBytes`, 50 MB decimal, which is
  66.7 MB as base64. That fits under the relay's 64 MiB (67.1 MB) message limit.
- **Image-only gates.** These checks all assume every attachment is an image:
  - `PromptInput` (`module_app_ui/.../session_detail/widgets/prompt_input.dart`):
    - can-send (l.543) and submit (l.650);
    - `didUpdateWidget`, which clears *all* attachments when
      `attachmentsSupported == false` (l.721);
    - paste (l.2755), the context menu (l.2302) and the plus (l.2596).
  - `SessionDetailCubit` at l.2363 and l.2556.
  - `NewSessionCubit` at l.1084 and l.1171.
- **Capability flags.** Image support is per plugin:
  `PluginMetadata.supportsPromptAttachments`, taken from
  `BridgePluginDescriptor.supportsPromptAttachments`. Every production plugin sets
  it to true except Grok. There is a precedent for a per-bridge flag:
  `PluginListResponse.supportsSessionOptions`, which `GetPluginsHandler` sets.
- **Bridge seam.** `SessionRepository.sendPrompt` (about l.431) and `createSession`
  (about l.290) map parts with `PromptPartToPlugin.toPlugin()`
  (`bridge/app/lib/src/repositories/mappers/prompt_part_mapper.dart`) and pass them
  straight to the plugin. This is how plugins treat non-image `file_data` today:
  - Claude drops it (`claude_session_process_repository.dart:743`).
  - ACP drops it (`acp_event_mapper.dart:447`).
  - Codex (`codex_thread_repository.dart:214`) and Pi
    (`pi_session_process_repository.dart:553`) reject it.
  - OpenCode passes it as a `data:` URI (`opencode_v2_repository.dart:529`).

  The callers are:
  - `SessionPromptService._sendPrompt`. It runs inside the per-session lane, after
    the `isAccepted` dedupe check.
  - `SessionContinuationService`, which sends only the text "Continue.".
  - `SessionCreationService._createSession`. It builds `userVisibleText` from the
    request's text parts before calling the repository.
- **Session id timing.** The Sesori session id is allocated inside the
  `createSession` commit, as `existingBinding?.sessionId ?? await
  _allocateSessionId()` (about l.317), *after* `plugin.createSession` returns. So
  a per-session folder has no name yet at the moment the first prompt's files
  have to be written. `_allocateSessionId` draws a random 128-bit `ses_` id and
  checks the DB for it; nothing about it needs the transaction.
- **Session deletion.** `SessionDeletionService.deleteSession` runs the family
  delete through `SessionMutationDispatcher`, and its `onDeleted` callback does
  the post-delete side effects outside the family lock: it purges history for
  every id in `DeletedSessionSubtree.sessionIds`, and, only when asked, deletes
  the session folder (unawaited). Its doc comment says the stores are coordinated
  there rather than in `SessionRepository`. Sessions that disappear another way
  (the backend deleted them, `SessionUnseenService._deleteRowAndEmit`) don't go
  through it.
- **Analytics.** Accepted prompts are reported at three seams:
  `SessionDetailCubit._reportAcceptedSubmission`, and in `SessionLaunchService`
  the create success branch (`session_created_with_message`) and the follow-up
  success branch (`session_message_sent`). `DesktopProductAnalyticsDeliveryService`
  has an exhaustive switch that returns `null` for events outside the warehouse
  allowlist (`transcript_prompts_opened`, `founder_call_*`), and the analytics
  platform's `sql/10_events_flattened.sql` has its own allowlist that those
  events are not in either.
- **Storage precedents** (`bridge/sesori_bridge_foundation/lib/src/sesori_data_directory.dart`):
  - `~/.sesori/worktrees` and `~/.sesori/scratch` are agent-facing roots shared by
    every data directory.
  - `sesoriAttachmentsDirectory()` holds content-addressed transcript spill
    storage, with a manual lifetime because several databases can share a scope.
  - The data directory `~/.local/share/sesori` holds the DB and the auth token.
  - `ScratchRepository` creates `<YYYY-MM-DD>-<random>` folders with
    `FilesystemApi.createTemporaryDirectory`. It deletes a session's folder only
    when the user asks (`deleteSessionFolder`).
  - `data_directory_hardening.dart` sets 700/600 modes.
- **Reading a path outside the session cwd, per harness.**

  | Harness | Behavior |
  |---|---|
  | Codex | The default sandbox restricts writes, not reads, so reading works. |
  | OpenCode | The default agent has `external_directory: * → ask` (fixture `native_2_0_16.json`), so Sesori relays a permission prompt. |
  | Claude Code | Launched with `--permission-prompt-tool` and `--permission-mode` but no `--add-dir`. A read outside its working directories is expected to prompt. Verify this live in step 3. |
  | ACP | The ACP client advertises `fs.readTextFile: false` (`acp_protocol.dart:297`), so agents use their own tools and sandboxes. Copilot asks outside trusted directories; the others are unverified. |
  | Pi | No sandbox. |

  Phase 1's local path insertion already triggers the same prompts. `~/.sesori` is
  not protected by macOS TCC, unlike `~/Downloads`.
- **Mobile picker.** `FlutterComposerImagePicker`
  (`client/app/lib/core/platform/flutter_composer_image_picker.dart`) only opens
  the image_picker gallery, with `ComposerAttachKind.images`.
- **Clipboard.** The chain is `ImageClipboard` → `FlutterImageClipboard` →
  `PasteboardClient` (`client/module_app_ui/lib/src/platform/`). In pasteboard
  0.6.0:
  - On macOS, `files()` returns `NSURL.path` for *every* URL on the pasteboard,
    and `image` returns a copied Finder file's icon. A copied
    `https://example.com/` therefore comes back as `/`, which exists.
  - Windows reads only `CF_HDROP`.
  - Linux keeps only `file://` URIs.
- **Picker packages.**
  - `file_selector 1.1.0` is a direct desktop dependency.
    `file_selector_ios 0.5.3+7` and `file_selector_android 0.5.2+11` are already in
    `client/pubspec.lock`.
  - iOS opens the picker with `asCopy: true`, so Dart gets a sandbox path.
  - Android (`FileSelectorApiImpl`) allocates `new byte[size]`, reads the whole
    file and copies it to the cache before Dart sees it, so a multi-GB pick can
    run out of memory. `size` is an `int`, so a file over 2 GB overflows.
  - `file_picker` is not in the lock. The workspace pins `dbus 0.8.0` and
    `cross_file 0.3.5+5`, which is why `desktop_drop` is held at 0.8.0.
- **Tappable paths.** Inline code in a user message is tappable when it reads as
  an absolute path without whitespace, and it opens the bridge file preview
  (`docs/regression/file-previews.md`).

## Decided from code

- **Wire.** Reuse `PromptPart.file_data`, with no new variant. One rule lives in
  the bridge core:
  - A `file_data` part goes to the plugin unchanged only when the plugin's
    descriptor sets `supportsPromptAttachments` and the part's mime starts with
    `image/`.
  - Every other `file_data` part is saved, and a text part replaces it in the
    same position.
  - The client sends staged images with their sniffed raster mime, as today. It
    sends every staged *file* as `application/octet-stream`, with the original
    name and extension. The client therefore states the intent, and the bridge
    needs no mime list.
  - A new variant would break decoding on old bridges, which the capability gate
    already prevents. It would also need either a pre-plugin-only type or a
    throwing branch in `toPlugin()`.
- **Capability: one per-bridge flag** on `PluginListResponse`, following the
  `supportsSessionOptions` precedent. The bridge core owns the behavior the same
  way for every plugin, so a per-plugin flag would repeat one fact 11 times.
  ```dart
  // COMPATIBILITY 2026-11-08 (v1.12.0): Bridges before file uploads omit this, so
  // only images reach them and the client says so. Remove @Default and require
  // supportsFileUploads once those bridges are unsupported.
  @Default(false) bool supportsFileUploads,
  ```
- **Layering.** The work splits across the usual bridge layers:
  - *API (Layer 1):* `FilesystemApi` gains `writeOwnerOnlyFile({path, bytes})`.
    It creates the file, sets mode 600 with the async `hardenPath` from
    `foundation/data_directory_hardening.dart`, then writes with flush. It also
    gains `createOwnerOnlyDirectory`, `createOwnerOnlyTemporaryDirectory` and
    `listDirectoriesAsync`, so no upload path blocks the isolate. No `api/`
    class depends on another.
  - *Repository (Layer 2):* a new `PromptUploadRepository` owns the uploads
    folder on disk. `SessionRepository` keeps only plugin-part mapping, the id
    reservation and the capability lookups.
  - *Service (Layer 3):* a new `PromptPartDeliveryService` owns the rule for
    which parts go inline and which are saved, the note text, and the sweep
    policy. Both prompt callers already are Layer-3 services.
- **`PromptPartDeliveryService`** (`bridge/app/lib/src/services/prompt_part_delivery_service.dart`,
  depends on `PromptUploadRepository` and an injected `Clock`).
  - `deliverableParts({required String sessionId, required bool inlineImages,
    required List<PromptPart> parts}) → Future<List<PromptPart>>`.
  - A `file_data` part stays as it is only when `inlineImages` and its mime starts
    with `image/`. Every other `file_data` part is saved and replaced, in the same
    position, by a text part holding the note. Other parts pass through.
  - It is called only with parts that will actually reach the plugin. A create
    that carries a command drops the user parts (`_buildPromptParts`, about
    l.167 of `session_creation_service.dart`), so on that path the service is
    not called and nothing is saved.
  - After a save, it starts the sweep unawaited, with the cutoff
    `clock.now() - 30 days`. A sweep failure is logged.
  - `SessionPromptService._sendPrompt` calls it right after the `isAccepted`
    check (about l.106), with `inlineImages` from
    `SessionRepository.inlineImagesSupportedForSession({sessionId})`. So a
    repeated accepted prompt is never saved again.
    `SessionContinuationService` sends only text and doesn't call it.
  - `SessionCreationService._createSession` calls
    `SessionRepository.reserveSessionId()`, then the delivery service with
    `inlineImages` from `SessionRepository.inlineImagesSupported({pluginId})`.
    It builds `userVisibleText` (about l.68) from the *delivered* parts' texts,
    so the notes appear in position and the live user message matches the
    reloaded one. `firstText`, which names the session, still comes from the
    request's own texts. It passes the delivered parts and `reservedSessionId`
    to `createSession`.
- **`SessionRepository` changes.**
  - `PluginRuntime.supportsPromptAttachments({required pluginId})`, shaped like
    `quotaReportingSupport`, behind `inlineImagesSupported({pluginId})` and
    `inlineImagesSupportedForSession({sessionId})`. The second resolves the
    binding as `_useSessionPlugin` does.
  - `reserveSessionId()` makes the existing `_allocateSessionId()` public. The
    reservation is a random 128-bit id checked against the DB, so taking it
    outside the commit transaction adds no meaningful collision risk and no state.
  - `createSession` gains `required String reservedSessionId`, and the commit at
    about l.317 becomes `existingBinding?.sessionId ?? reservedSessionId`. When
    the backend id is already bound (the existing-binding path), the files stay
    under the unused reserved id and only the sweep removes them (accepted, see
    Lifetime). `SessionCreationService` is the only caller.
- **`PromptUploadRepository`** (`bridge/app/lib/src/repositories/prompt_upload_repository.dart`),
  following `ScratchRepository`. It depends on `FilesystemApi` and the uploads
  root path, and is constructed in `Orchestrator.create`, beside `ScratchRepository`.
  - Its root is a new `sesoriUploadsDirectory()` = `~/.sesori/uploads` in
    sesori_bridge_foundation, beside worktrees and scratch (D1).
  - Layout: `~/.sesori/uploads/<sessionId>/<YYYY-MM-DD>-<random>/<name>`. The
    per-session level makes deleting a session's files one recursive delete. The
    per-file folder is made with `FilesystemApi.createOwnerOnlyTemporaryDirectory`,
    so names never collide and no dedupe logic is needed.
  - The session id is a bridge-generated `ses_<hex>` id from the bridge's own
    DB, never client text, so it is safe as a path segment. The repository still
    rejects an id that isn't a single plain segment, with a `StateError`.
  - The root and folders are mode 700 and files are mode 600. The root and
    session folders are created with the default umask, so the repository
    creates them through `FilesystemApi.createOwnerOnlyDirectory`, which hardens
    them right after creating them; the repository never runs `chmod` itself.
    `createOwnerOnlyTemporaryDirectory`, the layout's one per-file folder call,
    hardens the folder it creates the same way, so its 700 mode doesn't rely on
    Dart's `createTemp`. On a failed write
    the per-file folder is deleted and the error propagates, so the send fails
    visibly.
  - Methods: `save({sessionId, bytes, filename}) → path`,
    `deleteSessions({sessionIds})`, and `deleteFileFoldersDatedBefore({cutoff})`.
    The last one only removes per-file folders whose date prefix is before the
    cutoff. It knows nothing about the 30 days or when it runs.
  - Name sanitizing:
    - Keep only the basename.
    - Replace these with `_`: whitespace, control characters, `"` `'` and
      backticks, `* ? < > | :`, the shell syntax `$ ; & ( ) [ ] { } !`, and
      both path separators.
    - Use `attachment` when the name is `.`, `..` or empty.
    - Cap the stem, on whole code points and keeping the extension, so the
      whole name stays at most 120 characters and 240 UTF-8 bytes (ext4 allows
      255 bytes per name, so long CJK names would otherwise fail to save).

    Removing whitespace and quotes keeps the noted path tappable, and removing
    shell syntax keeps it one unquoted shell word for agents.
- **Note text** is a visible text part (D3):
  ``Attached file "My Report.pdf": `/Users/me/.sesori/uploads/ses_3f9a…/2026-11-08-k3j2/My_Report.pdf` ``.
  The original name stays readable, and the path is inline code, so it opens the
  file preview.
- **Lifetime (D2 = C, both).**
  - *With the session.* `SessionDeletionService` takes `PromptUploadRepository`,
    as it already takes `ScratchRepository`. Its `onDeleted` calls
    `unawaited(_deletePromptUploads(deleted: deleted))`, beside the history purge
    and outside the family lock, like the session-folder delete. That calls
    `deleteSessions(sessionIds: deleted.sessionIds)`. It runs on every delete,
    whatever `deleteSessionFolder` says, because the uploads belong to Sesori and
    not to the user's project. It is best-effort: a failure is logged with the
    ids and the error, and the sweep removes the files later.
  - *By age.* After each save, the delivery service sweeps per-file folders older
    than 30 days in every session folder. The clock is injected, and folders with
    unparseable names are left alone. A concurrent sweep, or a session delete
    running at the same time, tolerates folders that are already gone. The sweep
    leaves session folders in place even when empty: removing them would race a
    save creating its per-file folder in the same session, and an empty folder
    costs nothing. The session delete removes them.
  - The sweep is what removes files the session hook can't reach: the
    existing-binding create path, a create that failed after its files were
    saved, the first copy of a send that failed after saving and was retried
    (the retry passes `isAccepted` and saves again), and sessions removed outside
    `SessionDeletionService` (for example when the backend deleted them). No
    startup step, no timer, no DB.
- **Size limits, no chunking.** One 50 MB budget per message covers images and
  files together, and anything larger gets the "too large" notice. The evidence:
  - The relay allows 64 MiB per message, and 50 MB of base64 fits.
  - Both send paths already encode with bounded yields.
  - Chunking would need a new route, reassembly state and cleanup of partial
    uploads, which is larger than the whole feature.
- **Client routing.** `routeHostPaths` gains a `fileUploadsSupported` parameter
  and applies these rules in order:
  1. A supported image, when the harness takes images and the image fits after
     downscaling, is staged as an image (unchanged).
  2. On a local bridge, the path is inserted as text (unchanged).
  3. On a remote bridge with uploads, a regular file that fits the rest of the
     budget is staged as a file: original bytes, no downscale, octet-stream mime
     and the basename as its name. This covers images the harness can't take and
     formats that aren't sniffed, such as HEIC and SVG. The full file is read
     only after its size has been checked.
  4. Anything else is rejected:
     - a folder gets the new `folderNotTransferable`;
     - an oversized file gets `overBudget`, with its copy generalized to
       "Attachments are limited to 50 MB per message";
     - on an old bridge, `notTransferable` keeps the phase 1 copy;
     - `attachmentsUnsupported` is unchanged.
- **Client routing of raw bytes.** Image bytes reach the composer from two
  sources: pasted clipboard bytes, and the mobile Photos picker
  (`ComposerPickedImage`, which `pick()` stages as an image unconditionally
  today). Both go through one new dispatcher method, `routeImageBytes({bytes,
  filename, attachmentsSupported, fileUploadsSupported, stagedAttachmentBytes})`:
  - when the harness takes images, it stages a downscaled image (today's
    `attachmentFromBytes`);
  - otherwise, when the bridge takes uploads, it stages the bytes as a file named
    after the picked file, or `pasted-image.<ext>` for clipboard bytes;
  - otherwise it rejects with `attachmentsUnsupported`.

  `pick()` gains `fileUploadsSupported` and uses it for its `ComposerPickedImage`
  branch, so a Photos pick on a Grok session becomes a file instead of an image
  that can't be sent.
- **Composer model.** `ComposerAttachment` gains
  `required ComposerAttachmentKind kind`, with values `image` and `file`. Both
  kinds carry the same data, so the kind is an enum rather than a sealed class.
  One module_core function, `canDeliverComposerAttachments({attachments,
  inlineImages, fileUploads})`, replaces the cubit and `PromptInput` gates: an
  image needs `inlineImages == true`, and a file needs `fileUploads`.
- **Where new client types live** (all in `client/module_core/lib/src/`):
  - `ComposerAttachmentKind` and `ComposerAttachmentSource`: beside
    `ComposerAttachment` in `foundation/models/composer/composer_attachment.dart`.
  - `canDeliverComposerAttachments`:
    `foundation/models/composer/composer_attachment_delivery.dart`. Foundation,
    so both cubits and `PromptInput` can import it.
  - `ComposerPickSource`: beside `ComposerFilePicker` in
    `foundation/platform/composer_file_picker.dart`.
  - `FileClipboard`: `foundation/platform/file_clipboard.dart`.
  - `AnalyticsFileCountBucket`, `AnalyticsFileSource` and `PromptFilesSentEvent`:
    `foundation/models/product_analytics/product_analytics_event.dart`, with the
    other events.
  - `promptFilesSentEvent({attachments})`:
    `foundation/models/product_analytics/prompt_files_sent_event_builder.dart`.
    Foundation, so `SessionDetailCubit` and `SessionLaunchService` can both
    import it.
- **FileClipboard** (step 7):
  - **Interface.** It lives in
    `module_core/lib/src/foundation/platform/file_clipboard.dart` as
    `Future<List<String>> readPaths()`.
  - **Adapter.** `DesktopFileClipboard` in `client/desktop/lib/core/platform/`,
    because only desktop uses it and `module_app_ui/lib/src/platform/` is for
    adapters both shells use unchanged. It calls the `pasteboard` package
    directly (`files()` and `text()`); desktop adds `pasteboard` to its
    pubspec, which changes nothing in the lock.
    - It returns `[]` when the clipboard text parses as a URI whose scheme isn't
      `file`. That guards against macOS turning a copied web link into a path.
    - Desktop registers it in DI. On mobile the scope's provider stays `null`, so
      mobile paste is unchanged.
  - **Routing.** `routeClipboardPaths` in the dispatcher returns `null` unless
    the list is non-empty and every path exists (`HostFileRepository.kindOf`).
    Otherwise it calls `routeHostPaths`.
  - **Paste order.** Files first, then image, then text. This uses the drop's
    turn and staleness guards, and is not gated on image support.
- **Analytics (D6 = B), step 8.** One closed account-linked event,
  `prompt_files_sent`, through `ProductAnalyticsService`.
  - *Decision it informs:* whether people adopt remote file transfer, which
    decides whether chunked uploads above 50 MB or a hidden note with a file chip
    are worth building.
  - *Meaning and authority:* a confirmed outcome. It fires at the three existing
    accepted-prompt seams above, right after their `session_message_sent` or
    `session_created_with_message`, and only when the accepted prompt holds at
    least one `kind == file` attachment. Those are exactly the files the bridge
    saves; inline images are not counted. Never on queueing, failure or retry.
  - *Unit:* an action (one accepted prompt).
  - *Parameters,* both closed enums:
    - `file_count`: `1`, `2_4` or `5_plus` (`AnalyticsFileCountBucket`);
    - `source`: `picker`, `drop`, `paste` or `mixed`
      (`AnalyticsFileSource`), where `mixed` means the prompt's files came from
      more than one source.
  - *Where the source comes from:* `ComposerAttachment` gains
    `required ComposerAttachmentSource source` (`picker`, `drop`, `paste`), set
    by the dispatcher entry point that staged it. It is immutable, in memory
    only, and is not sent to the bridge.
  - One pure module_core function, `promptFilesSentEvent({attachments})`,
    returns the event or `null`, so the three seams share the rule.
  - *Privacy:* no names, extensions, mimes, sizes, paths or ids.
  - *Desktop (user follow-up, 2026-11-08):* recorded on desktop too.
    `DesktopProductAnalyticsDeliveryService` returns its parameters, and the
    desktop allowlist is widened in the other repositories:
    - `sesori_auth_server`: `ProductAnalyticsEventName.PromptFilesSent`, its two
      parameter enums and a `z.strictObject` branch in
      `productAnalyticsEventBodySchema` (`src/types/product-analytics.ts`), plus
      tests. Until this is deployed, the server answers 400 and the desktop
      client drops the event without retrying.
    - `sesori_analytics_platform`: the event and its `file_count` and `source`
      columns in `sql/10_events_flattened.sql` (allowlist, parameter list,
      value check, projection), `tests/schema_allowlist_assertions.sql`,
      `tests/metric_contract_assertions.sql`, and the event table in
      `docs/reference/full-runbook.md`. This also brings the mobile GA4 rows into
      the warehouse.
    - **Merge order:** the auth server change is deployed and the analytics
      platform change is merged before, or together with, the client step 8
      PR, so no desktop event is dropped. The step 8 PR body records this.
  - *Reporting:* the flattened events model above. A curated metric (for
    example a count in `20_user_activity_daily.sql`) waits until a dashboard
    needs it.

## PR series (slug `file-transfer`)

| # | Title | Depends on | Size (est.) |
|---|---|---|---|
| 1 | `🌱 [file-transfer] Raise the remote file transfer plan [step 1/10]` | — | ~350 |
| 2 | `🚧 [file-transfer] Keep prompt uploads per session and delete them with it [step 2/10]` | 1 | ~550 |
| 3 | `🚧 [file-transfer] Save prompt files on the bridge and advertise it [step 3/10]` | 2 | ~700 incl. codegen |
| 4 | `🌿 [file-transfer] Carry the file upload capability to the composer [step 4/10]` | 3 | ~300 |
| 5 | `⚙️ [file-transfer] Send any file to a bridge on another computer [step 5/10]` | 4 | ~1,350 |
| 6 | `⚙️ [file-transfer] Pick photos or any file on mobile [step 6/10]` | 5 | ~700 |
| 7 | `⚙️ [file-transfer] Paste files copied in the file manager on desktop [step 7/10]` | 1 (parallel ok) | ~350 |
| 8 | `⚙️ [file-transfer] Report accepted prompts that carry files [step 8/10]` | 5, 6, 7, and the auth server and analytics platform PRs | ~350, plus ~150 and ~150 in the other two repos |
| 9 | `🌱 [file-transfer] Reconcile the attachments regression docs [step 9/10]` | 2-8 | ~150 |
| 10 | `🌱 [file-transfer] Record the verification and retire the plan [step 10/10]` | 9 | ~100 |

The bridge work is split up front into steps 2 and 3, because together they mix
filesystem security, a lifecycle hook, id reservation and a wire contract.
Step 2 stands alone: its deletion hook and sweep primitive are inert until step 3
saves files. No compatibility code bridges the split.

**Steps 5 and 7 share files.** Step 7 runs in parallel after step 1, and touches
`composer_attachment_dispatcher.dart` and the paste flow in `prompt_input.dart`
(about l.2755), which steps 4 and 5 also edit. Step 7 ships
`routeClipboardPaths({paths, attachmentsSupported, stagedAttachmentBytes})`,
forwarding to `routeHostPaths` with the signature on `main` at that time.
Whichever of steps 5 and 7 merges second rebases onto the other: it adds
`fileUploadsSupported` to that call and resolves the paste-flow conflict. Step 8
then adds the attachment source to both.

### Step 2 (🚧: host file writes, path safety, lifecycle hook)
- `bridge/sesori_bridge_foundation/.../sesori_data_directory.dart`: add
  `sesoriUploadsDirectory()`.
- `bridge/app/lib/src/api/filesystem_api.dart`: add `writeOwnerOnlyFile`,
  `createOwnerOnlyDirectory`, `createOwnerOnlyTemporaryDirectory` and
  `listDirectoriesAsync`.
- `bridge/app/lib/src/repositories/prompt_upload_repository.dart`: new, as
  described above: `save`, `deleteSessions`, `deleteFileFoldersDatedBefore`, the
  layout, the session-id segment check and the name sanitizing.
- `bridge/app/lib/src/services/session_deletion_service.dart`: take
  `PromptUploadRepository`, and delete the family's uploads in `onDeleted`.
- `orchestrator.dart`: construct the repository and pass it in.
- Tests: the new `FilesystemApi` methods (modes, missing parents, an existing
  folder), sanitizing, modes, layout, the segment check, a failed write removing
  its folder, the dated delete, no synchronous probe in the delete or the sweep,
  and the deletion hook (every family member, whatever
  `deleteSessionFolder` says, failure logged and not propagated).
- PR body: **What**: the bridge can keep prompt uploads per session and removes
  them when a session is deleted. **Expected result**: no user-visible or
  database change; nothing writes uploads yet.

### Step 3 (🚧: wire contract, delivery rule, id reservation)
- `shared/sesori_shared/.../plugin_list_response.dart`: add `supportsFileUploads`
  (above), and run codegen. Update the `PromptPart.fileData` doc comment to state
  the rule.
- `bridge/app/lib/src/routing/get_plugins_handler.dart`: set
  `supportsFileUploads: true`.
- `bridge/app/lib/src/runtime/plugin_runtime.dart`: add
  `supportsPromptAttachments({pluginId})`.
- `bridge/app/lib/src/services/prompt_part_delivery_service.dart`: new, as
  described above, including the 30-day sweep trigger.
- `bridge/app/lib/src/repositories/session_repository.dart`: `reserveSessionId`,
  the two capability lookups, and `createSession(reservedSessionId:)`.
- `session_prompt_service.dart` and `session_creation_service.dart`: call the
  delivery service as described above.
- `orchestrator.dart`: wire in the service.
- `docs/HARNESS_CAPABILITIES.md`: add a short section on whether each harness
  reads a saved file, and whether it asks first. Fill it in from the live checks.
- Plan review: approved by `architecture-plan-review` on 2026-11-08 after one
  revision (layering, the bytes route, the desktop clipboard adapter, step
  boundaries and the up-front bridge split).
- PR body: **What**: the bridge saves files that aren't inline images and
  advertises the support. **Expected result**: no client-visible change yet. A
  `file_data` octet-stream part sent by hand lands in
  `~/.sesori/uploads/<sessionId>/`, the agent receives the note, and deleting the
  session removes that folder.

### Step 4 (🌿: capability plumbing only)
- `PluginDiscoverySnapshot` and `PluginRepository.listPlugins` map the flag. The
  404 fallback sets it to false.
- `NewSessionPluginDiscovery`, `SessionLaunchComposer`,
  `SessionDetailSnapshot`/`SessionDetailLoaded` and
  `session_detail_load_service.dart` get a `supportsFileUploads` bool, read from
  the same `listPlugins` call.
- `PromptInput` gains `required bool fileUploadsSupported`, passed down but not
  yet used for any gate. The plus gate changes in step 5, together with the
  routes that make it useful, so no build offers a plus whose picks can't be sent.
- Expected result: no user-visible or database change.

### Step 5 (⚙️: composer model, routing, gates, file tiles)
- module_core:
  - `ComposerAttachment.kind`, and `canDeliverComposerAttachments` used in both
    cubits.
  - Dispatcher rule 3, the new rejection reason, and `routeImageBytes` used by
    both the paste path and `pick()`'s `ComposerPickedImage` branch.
  - `SessionApi` sends each file with octet-stream on both paths.
- module_app_ui:
  - The plus is offered when `attachmentsSupported == true ||
    fileUploadsSupported`.
  - The staged strip, `_QueuedAttachmentPreviews` and
    `session_launch_submission_view.dart` show a file tile for a file: the same
    52px tile, a file glyph, the extension label, the name in semantics and
    tooltip, and the close badge.
  - The `didUpdateWidget` clear rule changes: drop image attachments when inline
    images become unsupported, and drop files when uploads become unsupported.
    Today's clear-all rule would wipe a Grok session's files on every rebuild.
  - Strings: `sessionDetailFoldersNotTransferable`, and
    `sessionDetailImagesOverBudget` renamed to
    `sessionDetailAttachmentsOverBudget`.
- Expected result:
  - On desktop connected to a remote bridge, a dropped or picked PDF shows a
    file tile, sends, and the agent reads it.
  - An image on a Grok session is sent as a file, from a drop, a paste or a
    mobile gallery pick.
  - A Grok session on a new local bridge shows the plus, and its picks insert
    paths. That removes the phase 1 limitation.
  - Nothing changes for old bridges.

### Step 6 (⚙️: picker seam, iOS dependency, Android native picker)
- **Picker seam.**
  - `ComposerFilePicker.pick({required ComposerPickSource source})`, with
    sources `photos` and `files`.
  - `ComposerAttachKind`: mobile becomes `photosAndFiles`, desktop stays `files`,
    and `images` is removed.
  - `ComposerPickedHostPaths` gains `required int oversizedCount`, which the
    dispatcher counts as `overBudget`.
- **PromptInput** (D4): on mobile, when both sources apply, the plus opens a
  two-item menu.
  - Photos applies when the harness takes images or the bridge takes uploads.
  - Files applies when the bridge takes uploads.
  - When only Photos applies, the gallery opens directly, as today.
- **client/app.** Rename `FlutterComposerImagePicker` to
  `FlutterComposerFilePicker`.
  - Photos uses the unchanged image_picker path.
  - On iOS, Files calls `file_selector.openFiles()`. Add
    `file_selector: ^1.1.0`, which adds nothing to the lock.
  - On Android (D5), Files goes through a new `DocumentPickerService.kt` that
    follows the `MainActivity` channel pattern:
    - it opens `ACTION_OPEN_DOCUMENT` with multi-select;
    - it reads `OpenableColumns.SIZE` as a Long;
    - it stream-copies only files of at most 50 MB into
      `cacheDir/composer-picks/`, which is cleared at the start of each pick;
    - it returns `{paths, oversizedCount}`.

### Step 7 (⚙️: new platform seam with a macOS-specific guard)
- The `FileClipboard` interface, the desktop adapter and the dispatcher's
  `routeClipboardPaths`, as described above.
- `ComposerPresentationScope` gains
  `required ComposerCapabilityProvider<FileClipboard>? fileClipboard`. Desktop
  passes its adapter; mobile passes `null`.
- Change the `PromptInput` paste order, and add the desktop DI registration.
- Expected result:
  - A Finder copy of files pastes as paths on a local bridge, and as staged files
    on a remote one once step 5 is in.
  - A copied web link still pastes as text.
  - A copied image still pastes as an image.

### Step 8 (⚙️: one closed analytics event at existing seams, across three repos)
- module_core, following `add-analytics`:
  - `product_analytics_event.dart`: `PromptFilesSentEvent` (`prompt_files_sent`)
    with `AnalyticsFileCountBucket` and `AnalyticsFileSource`, as described above.
  - `ComposerAttachment.source` (`ComposerAttachmentSource`). The dispatcher's
    entry points take the source: `pick` stamps `picker`, the drop and clipboard
    calls into `routeHostPaths` pass `drop` and `paste`, and `routeImageBytes`
    takes it from its caller (`picker` from `pick()`, `paste` from the paste
    path).
  - `prompt_files_sent_event_builder.dart`: `promptFilesSentEvent({attachments})`,
    emitted after the existing event at the three accepted seams
    (`SessionDetailCubit`, and create and follow-up in `SessionLaunchService`).
- module_app_ui: pass the source at the drop and paste call sites in
  `PromptInput`.
- module_desktop_core: `PromptFilesSentEvent() => event.parameters` in the
  delivery switch.
- Cross-repo PRs, each in its own worktree under
  `/Users/alexandrudochioiu/.claude-worktrees/<repo>/<name>` and following that
  repo's `AGENTS.md`: `sesori_auth_server` and `sesori_analytics_platform`, as
  described under Analytics. They merge (and the auth server deploys) first.
- `docs/regression/analytics.md`: add the event, its parameters and where it
  fires.
- Tests: exact wire name and parameter values, each bucket and `mixed`; emitted
  only on success and only with a file attachment; not for image-only prompts;
  no sensitive values; the desktop switch returns the two parameters. In the
  auth server, the schema accepts every valid value and rejects unknown ones; in
  the analytics platform, the fixture assertions cover the event.
- Expected result: no user-visible change. On mobile, an accepted prompt with
  files sends one `prompt_files_sent` to Firebase; on desktop, one to the auth
  server's product events. No client database change; the auth server stores
  the new event in its existing product events collection.

## Complexity budget

- **New classes:** `PromptUploadRepository` and `PromptPartDeliveryService`
  (bridge), `DesktopFileClipboard` (desktop), `DocumentPickerService.kt`
  (Android). Each has one owner and no mutable fields beyond the Android pending
  result.
- **New persistent state:** one folder per session that received files, and one
  folder per saved file inside it, under `~/.sesori/uploads`. No DB table, column
  or setting; the folder name *is* the upload-to-session mapping.
- **New in-memory mutable state:**
  - Bridge: none. The sweep is stateless and idempotent. The pre-allocated
    session id is a local in `createSession`, and the deletion hook is one more
    call in an existing callback.
  - Client: none in `PromptInput`. The attachment list already exists, and
    `kind` and `source` are immutable. There are new immutable
    `supportsFileUploads` fields on the snapshot, state, launch composer and
    discovery.
  - Android: one pending-result field in `DocumentPickerService`.
- **New lifecycle hook:** one, the uploads delete in `SessionDeletionService`
  (D2 = C). It is justified by the user's decision that files go with their
  session.
- **Deliberately not added:**
  - chunking or resume, or a new wire part;
  - a per-plugin flag, or any plugin code change;
  - a DB mapping from uploads to sessions, or moving files when the
    existing-binding path picks another session id;
  - deleting uploads when `createSession` fails (the backend session may exist
    and be imported later, still reading them; the sweep covers it);
  - deletion hooks on paths other than `SessionDeletionService`, or a startup
    orphan reconcile (the sweep covers them);
  - a startup sweep or timer, or content-hash dedupe;
  - a curated warehouse metric for the analytics event (only its flattened rows);
  - upload progress UI, or a hidden note with a transcript file chip;
  - Claude `--add-dir` (D1 = A);
  - mime sniffing for non-images, or `file_picker`.

## Cleanup

- **Step 2:** none found; it only adds.
- **Step 3: no plugin cleanup.** The non-image `file_data` branches in Claude,
  ACP, Codex and Pi become unreachable for files. Their exhaustive switches still
  need a branch, and rewriting them would be churn. OpenCode's `data:` URI stays
  for images.
- **Step 4:** none found; it only plumbs a flag.
- **Step 5:**
  - Remove the regression-doc limitation "The plus action follows backend
    attachment support... even on a local bridge".
  - Generalize the image-only doc comments on `ComposerAttachment` and
    `ComposerAttachRejectionReason`.
  - Replace the clear-all rule.
  - Rename the over-budget string.
- **Step 6:** remove `ComposerAttachKind.images` and rename the mobile picker
  adapter.
- **Step 7:** none found.
- **Step 8:** none found. The new event sits beside the existing ones and
  replaces nothing.
- **Step 9:** remove three known limitations: remote non-image files, pasting
  copied files, and mobile being unchanged.
- **Superseded draft note:** `.plan/drafts/prompt-attachment-uploads/` recorded
  an older approved idea, a `has_attachments` value on the existing message
  events. The user chose a separate event instead (D6 = B). The draft stays,
  because it is about uploading images separately from the prompt, which this
  plan does not do.
- **Not in scope:** `PromptPart.filePath` is still unused by clients, but this
  change doesn't make it obsolete.

## Regression docs and verification

- **Docs affected.**
  - `docs/regression/attachments-and-images.md` is the primary doc. Each feature
    PR edits its own lines, and step 9 reconciles them.
  - `docs/regression/analytics.md`: the new event (step 8).
  - `docs/HARNESS_CAPABILITIES.md`: reading a saved file and permission prompts,
    per harness.
  - `docs/regression/file-previews.md`: only if a noted path isn't tappable.
- **New required behavior:**
  - Remote file staging, and the bridge save plus note.
  - Inline images unchanged; Grok images sent as files.
  - The advertisement, and the old-bridge notice.
  - The folder notice, and the combined 50 MB limit.
  - The mobile Photos/Files menu, and the Android oversize notice.
  - Pasting copied files with the URL-text guard.
  - Deleting a session from Sesori removes its saved files, and the 30-day sweep.
  - `prompt_files_sent` on accepted prompts with files.
- **New failure signals:**
  - Non-image `file_data` reaches a plugin.
  - A saved name escapes its folder, or a saved file isn't owner-only.
  - A file over budget is read in full, or an Android pick of a huge file
    crashes.
  - A copied web link pastes as a path.
  - A file is staged for an old bridge, or files are cleared on a Grok rebuild.
  - The note is missing from the live view of a new session.
  - A new session's files land under an id other than its own, or a deleted
    session's upload folder stays.
  - `prompt_files_sent` fires for a failed, queued or image-only prompt, or
    carries anything beyond its two enums.
- **New known limitations:**
  - Files over 50 MB can't be sent.
  - Saved files go when their session is deleted from Sesori, or 30 days after
    upload, whichever comes first. A session that runs past 30 days loses its
    older files. Files of a create that bound to an existing session, of a
    failed create, or of a session removed outside Sesori go only by age.
  - An image the harness takes is always sent inline and downscaled. Its original
    can't be sent as a file.
  - Some harnesses ask before reading outside the session folder.
  - Pasting copied files on Windows and Linux is only covered by adapter tests.
  - iOS picker copies stay in the app's tmp folder until iOS clears it.
- **Highest level: L3 Release.**

| Cell | Coverage | Proves |
|---|---|---|
| Automated: shared | L1 | The flag is omitted → `false`, and it round-trips |
| Automated: bridge/app | L2 | Image to a capable plugin stays inline. An octet-stream part is saved and replaced in place. An image to Grok is saved. Create joins the notes into `userVisibleText`. An accepted retry isn't saved again. Sanitizing (`../x`, `a\b`, `.`, spaces, 300 characters), 600/700 modes, one folder per file under the session's folder, and a sweep that removes only folders over 30 days, skips unparseable ones and keeps session folders. Create saves under the id it then commits; on the existing-binding path it commits the bound id. Deleting a session family removes every member's upload folder whatever `deleteSessionFolder` says, and a failed upload delete is logged and doesn't fail the delete. The handler sets the flag. |
| Automated: module_core | L2 | The full routing table, including old bridge, folder, over budget, Grok image and the local path. `canDeliverComposerAttachments`. Repository mapping and the 404 fallback. `routeClipboardPaths` with all, some or none of the paths existing. `prompt_files_sent`: wire name and values, buckets, `mixed`, success-only at all three seams, none for image-only prompts. |
| Automated: module_desktop_core | L1 | The delivery switch returns the two parameters for `prompt_files_sent`. |
| Automated: auth server and analytics platform | L1 | The schema accepts the event with every valid value and rejects others; the warehouse fixture assertions cover it. |
| Automated: module_app_ui | L2 | File tile in the strip, queued bubble and launch view. Clear rules. Plus gating. Source menu. Paste order with a fake `FileClipboard`. |
| Automated: client/app | L1 | The picker dispatches by source and handles `oversizedCount` (with fake channels) |
| iOS simulator → `sesori-local-testing` bridge slot (remote from the phone) | L3 | A Photos image to Claude goes inline (regression). A Files PDF and a `.txt` reach the agent, which quotes them, and the noted path opens the preview. A 49 MB file sends, and a 51 MB file gets the notice. Deleting that session from the app removes its folder under `~/.sesori/uploads`. The menu shows Photos only on a Grok-less old-bridge path, which is automated only. |
| macOS cell (pasteboard, desktop locality) | L3 | Desktop connected to a CLI bridge slot it doesn't supervise, so the bridge counts as remote: a dropped PDF shows a tile, sends, and the agent reads it. Pasting a Finder copy of two files stages them. With the supervised local bridge active, the same paste inserts paths. A copied `https://example.com/` from Safari pastes as text. |
| Android cell (Kotlin picker) | L3 | A small PDF stages. A video over 50 MB gets the notice and doesn't crash. Multi-select works. |
| Per harness, live, from the iOS simulator | L3 | Send a `.txt` holding a known sentence; the agent quotes it; record any prompt. Run this for Claude, Codex, OpenCode, Pi, Cursor, Copilot, Grok, Hermes, OMP, Antigravity and DeepSeek. Any harness that isn't installed is recorded as unverified, and the user must accept that in PLAN.md before retirement. |

An older bridge is covered only by the automated decode and routing tests. Running
a released v1.11.0 bridge live is optional.

## Risks

- On first read, Claude, OpenCode and Copilot will likely ask for permission (see
  D1). This matches the local case today.
- On the bridge, decoding a 50 MB file peaks at about 120 MB of memory, the same
  as images today.
- The user's home path appears in their own transcript message. That is the same
  kind of data that agent tool output already shows.

## Decisions (settled by the user, 2026-11-08)

- **D1. Where saved files land: A.** `~/.sesori/uploads`, outside every project.
  Claude, OpenCode and Copilot may ask once per read location, as they do for
  phase 1 local paths. Revisit a plugin-local `--add-dir` only if live checks show
  the prompts are annoying.
- **D2. Lifetime: C, both.** Files are deleted with their session through
  `SessionDeletionService`, *and* a 30-day age sweep runs after each save. This is
  why the layout has a per-session folder and why `createSession` allocates the
  Sesori id before calling the plugin. The sweep catches what the hook can't
  reach, such as the existing-binding create path.
- **D3. Transcript: A.** A visible note in the user's message, with a tappable
  path. No wire change.
- **D4. Mobile entry point: A.** The plus opens a Photos / Files menu when both
  apply, and opens the gallery directly when only Photos applies.
- **D5. Android picker: A.** A small Kotlin document picker that checks the size
  before copying. `file_selector` on iOS.
- **D6. Analytics: B.** One closed event, `prompt_files_sent`, when a prompt with
  saved files is accepted, with a file-count bucket and the source (picker, drop
  or paste). Built per `add-analytics` in step 8. Follow-up the same day:
  record it on desktop too, by widening the auth server and warehouse
  allowlists (option B over mobile-only).

### Critical files
- bridge/app/lib/src/services/prompt_part_delivery_service.dart (new)
- bridge/app/lib/src/repositories/prompt_upload_repository.dart (new)
- bridge/app/lib/src/repositories/session_repository.dart
- bridge/app/lib/src/services/session_deletion_service.dart
- shared/sesori_shared/lib/src/models/sesori/plugin_list_response.dart
- client/module_core/lib/src/services/composer_attachment_dispatcher.dart
- client/module_app_ui/lib/src/features/session_detail/widgets/prompt_input.dart
