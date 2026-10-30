# Step 2: Mic Marker

## Built

- `wrapDictatedText` and `unwrapDictatedText` in `sesori_shared`, one pair owning
  the `🎙️ "…"` form.
- `outgoingText` and `plainText` on `QueuedSessionSubmission` and
  `NewSessionSubmissionSnapshot`. They sit on the sealed parents because every send
  site holds the parent type. `displayText` shows the marked form for text only.
- Both new-session sends and the session-detail send use `outgoingText`.
- `withFollowUps` and the pending launch title read `plainText`.
- `SessionCreationService` unwraps the first text before generating metadata.
- The Claude catalog's first-prompt title fallback unwraps too, so a session whose
  generated title has not landed or failed never shows the marker as its title.

No wire, schema or generated-file change.

## Verification

Toolchain Flutter 3.47.8, Dart 3.13.7.

| Command | Result |
| --- | --- |
| `shared/sesori_shared`: `dart test test/voice/dictated_text_test.dart` | 3 passed |
| `client/module_core`: `dart test` on the queued submission, snapshot, launch service, launch repository, session detail cubit and prompt queue tests | 159 passed |
| `bridge/app`: `dart test test/bridge/services/session_creation_service_test.dart` | 17 passed |
| `bridge/sesori_plugin_claude`: `dart test test/claude_transcript_catalog_repository_test.dart` | 30 passed |
| `dart analyze --fatal-infos` in those four packages | No issues |

The existing test "connection restored drains queued messages" sends a voice-assisted
prompt, so its expected text is now the marked form.

Not exercised: a real session through a real bridge. The plan's coverage matrix holds
that for step 12.

## Existing Behaviour Worth Knowing

- Settling a pending bubble is by prompt identity only. `_releaseDeliveredPrompt`
  documents that content never settles a prompt, so plain and marked text cannot
  duplicate or flicker. The search found no text comparison between the client's
  submission and the server's echo.
- Text in the transcript comes back from the harness marked, so the bubble, the
  sticky prompt and the prompt list all show the marked form (D18). Bridge-queued
  bubbles likewise show the marked text the bridge holds.
- A bridge-queued prompt that is cancelled does not return to the box, so nothing
  restores marked text from the server.
- Harnesses that title sessions themselves from the first prompt (for example ACP
  `info.title`) may include the marker until the generated title lands. An older
  bridge generates a title from marked text, which the plan accepts.
- `withFollowUps` keeps only the first draft's voice spans. A failed launch with a
  typed first message and a dictated follow-up restores as typed, so that re-send is
  not marked. A dictated first message stays voice-assisted. This path is rare and
  was left as is.
