# File Previews

## Capability

The bridge serves a read-only preview of a file on its host through
`POST /filesystem/file`, so a client can show a file a session refers to. The
bridge owns this route, and no plugin takes part in it.

In a session transcript, a link or inline code that reads as a file path opens
that file. On the bridge's own computer the client opens it in the system's
default app; otherwise it shows a read-only preview.

## Required Behavior

- The request carries one absolute path. Any readable file is allowed and links
  are followed; there is no project containment check. The route never lists a
  directory or writes anything.
- A relative path or one with a `..` segment is a client bug and gets `400`.
- Every domain outcome is a `200` with a tagged `FilePreviewResponse`:
  - `text`: UTF-8 content of at most 1 MiB.
  - `image`: base64 bytes with a MIME type for `png`, `jpg`/`jpeg`, `gif`, and
    `webp`, up to `maxTranscriptImageBytes` (20 MiB).
  - `too_large`: over the cap for its kind.
  - `missing`: no file, including a link whose target is gone.
  - `unsupported`: a directory, a pipe, socket, or other non-regular file
    (never opened), another known binary extension, a NUL byte, or invalid
    UTF-8.
  - `denied`: the host refused the lookup or read, for example macOS Full Disk
    Access or an unreadable parent folder.
- Another filesystem failure gets `500`, and the local bridge log keeps the
  path and error.
- An older bridge without the route answers `404`. Because every domain
  outcome is a `200`, a `404` always means the route is missing.

### Client flow

- Inline code in text parts and user messages is tappable, in the link colour,
  when it reads as a path: it contains `/` (or `\` on Windows), has an
  extension with a letter, and may end in `:line` or `:line:col`. A path with
  whitespace, `~`, quotes, backticks, `*`, `?`, `<`, `>`, or `|` is not
  tappable. Other inline code stays plain. A local `file://` URI (no host or
  `localhost`, percent-escapes decoded) or any other non-web link href is
  treated the same way; web and `mailto` links keep opening in the browser.
- A relative path resolves against the session's directory, with Windows path
  rules when that directory is on a drive.
- When the active bridge runs on this computer, the file opens in the system's
  default app and the line is dropped. If that launch fails, the preview opens
  instead.
- The preview is a full-screen page that slides up and closes with its close
  button or Escape:
  - Text shows line numbers and, with a line, starts scrolled to that line with
    it highlighted. Markdown renders with the session's styles and has a source
    toggle; with a line it opens on the source.
  - An image opens in the image viewer once the page has slid in.
  - Every other outcome is a one-line message. A `404` from an older bridge
    shows "Update the bridge to preview files".

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: repository outcomes for text, image, cap edges, missing, dangling link, binary, NUL, invalid UTF-8, directory, FIFO and device left unopened, followed link, denied read, and denied lookup; handler `400` and passthrough; wire tags. Client: path recognition, the open-locally or preview decision, repository `404` mapping, cubit states, and the preview page for each state. |
| L2 Routine | Headless bridge: request a text file, an image, and a missing path, and confirm each outcome. |
| L3 Release | Phone on a remote bridge: tap a `path:line` in a reply and confirm the preview slides up scrolled to that line; tap a Markdown file and toggle its source; tap an image path. Desktop on the same computer: confirm the file opens in its default app. |
| L4 Extended | A client against a bridge older than this route shows "Update the bridge to preview files". Headless bridge: on macOS, request a file under a Full Disk Access-protected folder without access and confirm `denied`. |
| L5 Full | No additional coverage. |

## Failure Signals

- A domain outcome answered with a non-200 status.
- A text file over 1 MiB, or an image over the image cap, returned in full.
- A directory listing, a write, or binary bytes returned as text.
- A `500` without a bridge log line naming the path.
- Ordinary inline code such as `foo()` or `v1.2` becomes tappable, or a web
  link inside inline code stops opening in the browser.
- The transcript jumps or scrolls when a preview opens or closes.
- A remote bridge's path is opened on this computer instead of previewed.

## Sources

- `shared/sesori_shared/lib/src/models/sesori/file_preview.dart`
- `bridge/app/lib/src/repositories/filesystem_repository.dart`
- `bridge/app/lib/src/routing/read_file_preview_handler.dart`
- `bridge/app/test/bridge/repositories/filesystem_repository_test.dart`
- `bridge/app/test/bridge/routing/read_file_preview_handler_test.dart`
- `shared/sesori_shared/test/models/file_preview_test.dart`
- `client/module_core/lib/src/foundation/models/file_reference/file_reference.dart`
- `client/module_core/lib/src/repositories/file_preview_repository.dart`
- `client/module_core/lib/src/services/file_reference_open_service.dart`
- `client/module_core/lib/src/cubits/file_preview/file_preview_cubit.dart`
- `client/module_app_ui/lib/src/features/session_detail/file_preview/`
- `client/module_app_ui/lib/src/features/session_detail/session_detail_markdown_link_handler.dart`
- `client/module_app_ui/test/features/session_detail/file_preview/file_preview_screen_test.dart`
