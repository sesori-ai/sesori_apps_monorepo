# File Previews

## Capability

The bridge serves a read-only preview of a file on its host through
`POST /filesystem/file`, so a client can show a file a session refers to. The
bridge owns this route, and no plugin takes part in it.

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
  - `unsupported`: a directory, another known binary extension, a NUL byte, or
    invalid UTF-8.
  - `denied`: the host refused the read, for example macOS Full Disk Access.
- Another filesystem failure gets `500`, and the local bridge log keeps the
  path and error.
- An older bridge without the route answers `404`. Because every domain
  outcome is a `200`, a `404` always means the route is missing.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: repository outcomes for text, image, cap edges, missing, dangling link, binary, NUL, invalid UTF-8, directory, followed link, and denial; handler `400` and passthrough; wire tags. |
| L2 Routine | Headless bridge: request a text file, an image, and a missing path, and confirm each outcome. |
| L3 Release | Not included. |
| L4 Extended | Headless bridge: on macOS, request a file under a Full Disk Access-protected folder without access and confirm `denied`. |
| L5 Full | No additional coverage. |

## Failure Signals

- A domain outcome answered with a non-200 status.
- A text file over 1 MiB, or an image over the image cap, returned in full.
- A directory listing, a write, or binary bytes returned as text.
- A `500` without a bridge log line naming the path.

## Sources

- `shared/sesori_shared/lib/src/models/sesori/file_preview.dart`
- `bridge/app/lib/src/repositories/filesystem_repository.dart`
- `bridge/app/lib/src/routing/read_file_preview_handler.dart`
- `bridge/app/test/bridge/repositories/filesystem_repository_test.dart`
- `bridge/app/test/bridge/routing/read_file_preview_handler_test.dart`
