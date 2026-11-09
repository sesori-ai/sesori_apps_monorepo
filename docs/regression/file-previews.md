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
  - `text`: UTF-8 content of at most 20 MiB, enough for an HTML page with
    inline images.
  - `image`: base64 bytes with a MIME type for `png`, `jpg`/`jpeg`, `gif`, and
    `webp`, up to `maxTranscriptImageBytes` (20 MiB).
  - `pdf`: base64 bytes of a `.pdf` file up to 20 MiB, only when the request
    sets `acceptsPdf`. Without it, as from an app that predates PDF previews
    and cannot read this outcome, a PDF is `unsupported`.
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
  when it reads as a path: it contains `/` or `\`, has an
  extension with a letter, and may end in `:line` or `:line:col`. A path with
  whitespace, `~`, quotes, backticks, `*`, `?`, `<`, `>`, or `|` is not
  tappable. Other inline code stays plain. A local `file://` URI (no host or
  `localhost`, percent-escapes decoded) or any other non-web link href is
  treated the same way; web and `mailto` links keep opening in the browser.
- Every chat link is one inline unit in the brand link colour, with no
  underline, that dims while pressed:
  - A file reference shows a type badge for common languages (dart, js, jsx,
    ts, tsx, py, rs, go, swift, kt, java, md, json, yaml/yml, sh) or a plain
    file icon, then the file name and " (line N)" when it has a line.
  - A bare GitHub URL shows the GitHub mark and "<repo> PR #n",
    "<repo> #n" or "<repo> @<short sha>", or its host on other GitHub pages;
    any other bare URL shows a globe and its host. Labels are built locally,
    with nothing fetched.
  - A web link with its own text keeps that text, led by the GitHub mark or a
    globe. Other links, such as `mailto`, keep their text with no icon.
  - A desktop hover shows the full target under the click cursor, never the
    text cursor, and copying a selection that
    touches a link copies its full URL or path, never the short label.
- A relative path resolves against the session's directory, with Windows path
  rules when that directory is on a drive.
- Claude Code and Codex agents are told so through their native system prompt
  or developer instructions, and asked to write a file outside the session's
  directory as an absolute path. The note never appears in the transcript;
  `docs/HARNESS_CAPABILITIES.md` lists the other harnesses.
- When the active bridge runs on this computer, the file opens in the system's
  default app and the line is dropped. If that launch fails, the preview opens
  instead.
- The preview is a full-screen page that slides up and closes with its close
  button or Escape:
  - Text shows line numbers and, with a line, starts scrolled to that line with
    it highlighted. A line over 10,000 characters, such as an inline image's
    data, shows its first 10,000 and an ellipsis; Copy still copies the whole
    file. Markdown renders with the session's styles and has a source toggle;
    with a line it opens on the source. Markdown over about 1 MiB (1,048,576
    characters) shows only its source, with no toggle, because rendering builds every block at once.
  - HTML (`.html`, `.htm`) renders in a web view on iOS, Android and macOS,
    with the same source toggle and line rule; a loading indicator shows
    until the page has loaded, and switching back to it shows the page where
    it was. Its scripts and in-page anchors work, but the page never
    navigates away: a tapped link the chat would open (web without
    credentials, or `mailto`) opens outside the app, a script's navigation
    opens nothing, frames load their own content, any other navigation is
    blocked, and a page that starts loading anyway, such as a submitted form
    on Android, is replaced with the file again, with its scripts off when no
    tap started it. Relative assets beside the file do not load. The page
    fills to the screen's bottom edge, under the iOS home indicator, as in
    Safari. The web view adds no inset for the indicator, so the app adds a
    spacer the height of the bottom inset to the end of the page's body with
    an appended style rule, and even a page that ends flush, with no bottom
    margin, scrolls its last line clear of the indicator. The source view and
    copy show the file's own text, without the rule. Windows and Linux show
    only the source, with no toggle.
  - An image opens in the image viewer once the page has slid in.
  - A PDF shows its pages in one scrolling column (pdfrx, PDFium), zoomed by
    pinching or a double tap; repeated double taps step through the zoom
    stops and back to fit. The pages fill to the bottom edge, under the home
    indicator, and the last page scrolls clear of it. The app always sets
    `acceptsPdf`; a bridge that
    predates PDF previews answers `unsupported`, which shows "This file can’t
    be previewed". A PDF that PDFium cannot open, such as a broken or
    password-protected one, shows "Couldn’t load this file".
  - Every other outcome is a one-line message. A `404` from an older bridge
    shows "Update the bridge to preview files".

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: repository outcomes for text, image, PDF with and without `acceptsPdf`, cap edges, missing, dangling link, binary, NUL, invalid UTF-8, directory, FIFO and device left unopened, followed link, denied read, and denied lookup; handler `400` and passthrough, including `acceptsPdf`; wire tags and a request without `acceptsPdf`. Client: path recognition, the open-locally or preview decision, repository `404` mapping, cubit states, and the preview page for each state. Bridge: the Sesori note in Claude launch arguments and Codex `thread/start`/`thread/resume`, after the user's developer instructions, and absent from mapped Codex history. |
| L2 Routine | Headless bridge: request a text file, an image, and a missing path, and confirm each outcome. |
| L3 Release | Phone on a remote bridge: tap a `path:line` in a reply and confirm the preview slides up scrolled to that line; tap a Markdown file and toggle its source; tap an image path; tap a sent PDF's path from its `Attached file` note and confirm its pages render, zoom by pinching and by double tap, scroll, and that the last page clears the home indicator. HTML on iOS, Android and macOS (desktop on a remote bridge): the page renders with its scripts run, a page with its own background fills to the bottom edge with no app-coloured strip above the home indicator, and scrolled to its end a page that ends flush with no bottom margin, and one that sets `html,body{height:100%}`, keeps its last line clear of the indicator, scrolls, keeps its place across the source toggle, and a web link opens outside the app while the page stays. A self-contained HTML page of 10+ MiB with inline images renders, and its source opens within about half a second and scrolls sideways smoothly; Markdown of several MiB opens on its source with no toggle. Desktop on the same computer: confirm the file opens in its default app. A Claude Code session repeats the Sesori note when asked, a Codex session's rollout records it as a developer message, and neither transcript shows it, new or resumed. |
| L4 Extended | A client against a bridge older than this route shows "Update the bridge to preview files", and a PDF against a bridge that predates PDF previews shows "This file can’t be previewed". Headless bridge: on macOS, request a file under a Full Disk Access-protected folder without access and confirm `denied`. |
| L5 Full | No additional coverage. |

## Failure Signals

- A domain outcome answered with a non-200 status.
- A text file over 20 MiB, or an image over the image cap, returned in full.
- A preview under the cap that times out on a slow link before two minutes.
- A large file's source or Markdown view freezes the app for seconds or
  balloons its memory, for example a line of megabytes laid out whole.
- A source row whose end is hidden or whose lines overlap under larger
  letter, word or line spacing in the system's accessibility settings, or an
  ASCII file's source that scrolls sideways far past its longest line.
- A directory listing, a write, or binary bytes returned as text.
- A `pdf` outcome sent to a request without `acceptsPdf`.
- A PDF preview that stays blank, stays loading, or crashes the app instead
  of showing its pages or "Couldn’t load this file".
- A `500` without a bridge log line naming the path.
- Ordinary inline code such as `foo()` or `v1.2` becomes tappable, or a web
  link inside inline code stops opening in the browser.
- A link shows the wrong icon or label, the text cursor on hover, or copying it
  yields the short label instead of the full URL or path.
- The transcript jumps or scrolls when a preview opens or closes.
- An HTML preview shows anything but the file inside the app, stays blank
  while it loads, stops above the home indicator with an app-coloured strip
  below it, keeps its last line under the indicator when scrolled to its end,
  shows the added style rule in its source or copy, a tapped web or `mailto` link in it does nothing, or its script
  opens something outside the app without a tap.
- A remote bridge's path is opened on this computer instead of previewed.
- The Sesori note shows in a transcript, or a new or resumed Claude Code or Codex
  session does not receive it.

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
- `bridge/sesori_bridge_foundation/lib/src/sesori_agent_instructions.dart`
- `client/module_core/lib/src/cubits/file_preview/file_preview_cubit.dart`
- `client/module_app_ui/lib/src/features/session_detail/file_preview/`
- `client/module_app_ui/lib/src/features/session_detail/session_detail_markdown_link_handler.dart`
- `client/module_core/lib/src/foundation/models/chat_link/chat_link_presentation.dart`
- `client/module_app_ui/lib/src/widgets/chat_link.dart`
- `client/module_app_ui/test/widgets/chat_link_test.dart`
- `client/module_core/test/foundation/models/chat_link/chat_link_presentation_test.dart`
- `client/module_app_ui/test/features/session_detail/file_preview/file_preview_screen_test.dart`
