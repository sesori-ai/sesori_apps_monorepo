# Voice Input

## Capability

The mobile composer records speech while the user holds the mic control, uploads the audio to the Sesori auth server
for transcription, and sends the words when the release finishes them; sliding onto the pencil target keeps them in the
prompt field instead. A voice-first or text-first preference decides which control leads. The desktop composer stays
text-first and adds the mic as an extra control on the same pipeline: one click starts listening, and a second click in
the same place or Enter sends; the pencil or Shift+Enter puts the words in the prompt field, and the X or Escape
cancels. The device microphone and transcription endpoint are external. The bridge independently prepares optional
project-scoped vocabulary from bounded local evidence; no backend plugin participates.

## Required Behavior

- Recording starts only with microphone permission. Denial or a failing check gives a distinct permission error and
  never leaves the composer stuck.
- Opening a composer never pauses another app's music or video. The iOS recorder warm-up is skipped while other
  audio plays, so only an actual recording takes the audio session.
- One interaction at a time: a concurrent start is ignored, and a release during recorder startup discards the
  incomplete recording.
- Starting, recording, transcribing, and cancelling are mutually exclusive composer interactions; input from a stale
  interaction cannot reset or append text into a newer one.
- Each composer requests current-project context in the background, refreshes missing context for later interactions,
  and snapshots only a validated, bridge-issued opaque glossary key when an interaction starts. Missing, pending,
  invalid, unsupported, or failed context remains unscoped without delaying capture. Retry preserves the original
  snapshot, and raw project identity never reaches auth.
- While recording the composer shows live amplitude, holds a stable layout, keeps the screen awake, and offers
  drag-to-cancel; recording reaches a maximum duration and signals auto-stop instead of running indefinitely.
- Initial cancel stops the recorder, releases the wake lock, attempts audio-file deletion, and invalidates any
  in-flight transcription so a late response cannot land in a newer interaction. Cancelling a manual retry returns
  to the saved-recording state without deleting its artifact.
- An empty or zero-byte recording fails as a recording error and is never uploaded as success. Errors map to distinct
  outcomes for permission, recording, auth, terminal server rejection, retryable server failure, empty transcript,
  local network failure, missing saved recording, and cancellation.
- A local transport failure or server response with authoritative `retryable: true` retains the exact completed async
  artifact and exposes persistent Retry and Discard actions in the composer. Retry reuses its path and MIME type
  without starting the recorder again; repeated retryable failures keep the same artifact.
- A server response with `retryable: false`, omitted/malformed retryability, authentication failure, empty transcript,
  missing artifact, success, explicit discard, a valid submission of other composer content, initial cancellation, or
  composer disposal attempts deletion and shows no Retry action. A valid submission cancels any active manual retry
  before deletion and is serialized so it cannot send twice; a refused/invalid submission retains the recording.
  Deletion remains best-effort and logs failures.
- On touch, the release decides the ending. Releasing sends everything the
  box holds as soon as the words arrive, on the session screen and the new-session screen alike. Sliding onto the
  pencil (far left in both input modes; it arms at 90% of the way from the hold point and fills solid) puts the words
  in the box. Sliding up out of the pill reddens it continuously and arms 64 px above its top edge with a haptic tick
  and "Release to cancel"; sliding back restores it, and cancelling keeps what the box held.
- Nothing leaves when the transcript is empty or the hold was under 200 ms. A dictation cut off at the limit, a retried
  recording, a hold the system cancelled, a keyboard tap during transcribing, and a composer that refuses the send all
  land in the box. An automatic send does not raise the keyboard unless the field already had it.
- The composer stays open and the X still stops a transcription under way.
- The feedback sheet keeps words in its own field and never sends by itself.
- The draft tracks voice-origin spans, so a message retaining one counts as voice-assisted input.
- A voice-assisted message reaches the agent, and shows in the sender's own bubble, marked whole as `🎙️ "words"`, so the
  agent allows for misheard words. The composer and a restored draft hold plain words, generated and pending titles use
  plain words, and slash commands are never marked, including a dictated argument.
- Existing-session voice entry is absent while that chat's harness is blocked. A block during recording or
  transcription disposes and invalidates the voice interaction, releases its resources, and prevents a late
  completion from restoring or sending input. Availability recovery creates a fresh eligible composer; the gate
  does not retain the recording or transcript.
- Successful transcription reports one content-free analytics event whose closed `finish` says how it ended: `sent`,
  `edited` or `cut_off`. No audio, transcript, or prompt text reaches logs or analytics.
- A successful current-project load starts best-effort bridge glossary population. It delegates to one serialized
  coordinator that coalesces concurrent work for the same project and never delays the route response, recording, or
  transcription.
- Apps older than v1.10.0 still send `project_view`. The bridge decodes it, with a project id or null, and ignores it:
  no reply, no warning, and later requests are still answered.
- Glossary population derives an exact opaque repository or bridge-local scope, caches the validated key for later
  current-project responses, scans bounded local Git/filesystem evidence, filters credential-shaped content before
  tokenization, and reconciles at most 100 deterministic terms. Terms are whole ASCII identifiers; common English
  words and their simple inflections, generic scaffolding names, hash/serial fragments, and a plural beside its
  singular are dropped. Only the opaque scope and filtered terms leave the bridge. Scope, scan, or publication failure
  leaves voice input available without an updated glossary.
- The preference defaults to voice-first, persists, and falls back to voice-first on a corrupt or unknown stored
  value.
- Mobile Settings lists Default input under Preferences, directly after Notifications. The keyboard row shows the live
  Voice/Text value and opens a dedicated page rather than selecting a mode inline.
  Desktop's composer always leads with text, so General does not expose this ineffective preference.
- Desktop click-to-talk: the mic click starts listening without moving keyboard focus out of the composer. While
  listening the mic and send merge into a wide `Send ↑` that covers the mic's place, so a second click needs no mouse
  movement; the options give way to a pencil and an X with tooltips, the hint reads "Enter to send", and the composer
  does not resize. Clicking the wide Send or pressing Enter sends everything the box holds as one message once the
  words arrive, on the session screen and the new-session screen alike, and inserts no newline. The pencil or
  Shift+Enter puts the words in the box. The X or Escape cancels and keeps what the box held. Keys work only while focus
  is inside the composer. While transcribing, the wide Send stays dimmed and inert, the pencil is gone, and the X or
  Escape stops the work. The rules above for empty, short, cut-off, retried and refused dictations apply. Clicking
  elsewhere never stops or discards the recording; only those controls, the maximum duration, or leaving the composer
  ends it. No sound plays. macOS asks for microphone access once through the system prompt.
- The Default input page has an inline title, explanatory subtitle, and two mutually exclusive Voice/Text previews.
  Selection updates the existing app-root preference and persists immediately; external preference changes update
  both the row and the open page. Back is the sole navigation action and returns to Settings.
  Labels and subtitle remain readable with accessibility text scaling, and preview artwork is excluded from semantics.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because microphone and transcription setup is too expensive for a heartbeat. |
| L2 Routine | Automated, mobile client and bridge, no plugin, fake recorder, HTTP client, Git, and filesystem: permission denial, concurrent-start rejection, zero-byte rejection, cancel invalidating an in-flight upload, authoritative true/false/omitted/malformed retryability mapping, retained-artifact Retry/Discard and retry cancellation, serialized send-time abandonment including an active retry, available/pending/invalid opaque project context, terminal/missing cleanup, max-duration signalling, deletion failure logging, draft voice-span and input-mode derivation, the dictated marker on sends with plain restored drafts and titles, the current-project glossary trigger, legacy `project_view` accepted and ignored, serialized bounded inference with common-word and fragment filtering, exact-scope reconciliation, and shutdown cancellation. |
| L3 Release | Mobile and macOS desktop client E2E: [recording and preference navigation](#client-release-coverage-l3). |
| L4 Extended | Client end to end on iOS: change harness availability from another surface while recording and while transcription is pending; no text or send lands after the block, and voice returns only after session prerequisites recover. Client end to end on the release-target client platform: background or system interruption, permission revoked between interactions, offline async upload failure followed by successful Retry without re-recording, explicit retryable and terminal server outcomes, older-server omission fallback, discard/disposal cleanup, wake lock released on every path. |
| L5 Full | Real device microphone and live transcription endpoint on every supported mobile platform: audible speech yields usable text, a near-maximum recording auto-stops and still transcribes, iOS haptics and system sounds stay audible while recording, and music from another app keeps playing when a chat opens. |

### Client release coverage (L3)

On the release-target mobile platform, hold to record and release to send, slide onto the pencil and edit the inserted
transcript, slide up to cancel, slide up and back, and check layout stability and which control leads under each input preference.
Open Settings → Default input, select each mode, check Back returns to Settings from a non-home opener,
reopen the page and verify the saved row value.
On the macOS desktop build, grant the first microphone prompt, click the mic, speak, and click again without moving the
mouse to send; start again and press Enter to send, with text already in the box; start again and use Shift+Enter, then
the pencil, and edit the inserted transcript; start again and cancel with Escape, then the X, and confirm the box keeps
its text; click into the transcript mid-recording and confirm the recording continues.
On either, send a dictated message and confirm the bubble and the harness transcript show `🎙️ "words"`, while the
generated session title shows plain words.

## Exploration Guidance

Vary hold duration near the minimum and the limit, release timing relative to recorder startup, and whether the field
already contains typed text. Alternate cancel methods, edit or delete part of the inserted text before sending to
exercise voice-span survival, and switch the preference between interactions. On hardware, vary ambient noise and
interruptions such as a call.

## Failure Signals

- Default input shows a stale row value, selection fails to persist, Back skips Settings, or
  enlarged text clips the labels/subtitle.

- A blocked existing chat exposes voice entry, keeps capture/transcription alive,
  accepts a late transcript or send, leaks a wake-lock/recording resource, or
  restores content from a recording/transcription that was still in flight when
  the block began.
- Sending during transcribing delivers the box and the dictated words as two messages.
- The composer stays in a recording or transcribing state after error, cancel, or disposal, or a cancelled transcript
  appears in a later interaction.
- A retryable async failure loses the artifact or lacks persistent Retry/Discard controls; a terminal/unknown failure
  exposes Retry; a manual retry invokes the recorder; a retry cancellation deletes the saved recording; send-time
  abandonment duplicates a submission or lets a retry finish into the cleared composer; cleanup is not attempted on
  terminal paths; a deletion failure is unlogged; or the wake lock stays held.
- Audio is uploaded despite denied permission, or denial is reported as a generic network or server failure.
- A project glossary contains connector or everyday English words, or exceeds 100 terms.
- A cut-off, failed, cancelled or retried dictation sends by itself, a feedback-sheet dictation sends by itself, or a
  message with surviving voice text is classified as typed.
- A desktop dictation sends the box and the words as two messages, Enter inserts a newline while listening, or the
  second click misses because the control moved.
- A dictated message reaches the agent unmarked, a typed message or slash command is marked, or the marker appears in a
  draft or a generated title.
- Any audio, transcript, or prompt content reaches logs or analytics; raw project identity, project paths, repository
  origins, filenames, or metadata source text reach auth voice transport; glossary failure blocks recording or
  transcription; or concurrent
  triggers run overlapping local scans.

## Known Limitations

- Microphone and hosted transcription are external and non-deterministic; assert usable non-empty text, never exact
  wording. Simulators and fakes cannot prove real capture, iOS audio-session behavior, or haptics; those stay partial
  without L5.
- Transcription is unavailable while unauthenticated or offline, which is expected degraded behavior. The bridge has
  no voice capability beyond the glossary.
- Desktop capture is unverified on device: the macOS feel check has not been run yet and is pending a check on a
  build from `main` after merge. Windows records through Media Foundation and is unverified. Linux needs
  `parecord` and `ffmpeg` on the PATH; the DEB and RPM packages recommend them, the AppImage cannot, and without them
  the composer shows the recording-failed notice. Leaving a
  desktop session while recording discards the recording, as on the phone.
- Retained recordings are composer-local and memory-owned. They do not survive composer disposal, route replacement,
  process restart, or a valid submission of other composer content. Failed best-effort deletion can still leave an
  unowned audio file on disk.
- Manual Retry has no exactly-once guarantee. If the provider completed work but the response was lost, resubmitting the
  same artifact can repeat provider processing and quota usage.

## Sources

`client/module_app_ui/test/features/settings/default_input_settings_view_test.dart`,
`client/app/test/features/settings/`, `client/desktop/test/features/settings/`,
`client/module_app_ui/test/platform/voice/`, `client/app/test/features/session_detail/widgets/`,
`client/module_app_ui/test/features/session_detail/widgets/prompt_input_pointer_voice_test.dart`,
`client/module_core/test/{capabilities,cubits,repositories,services}/`, and bridge glossary tests under
`bridge/app/test/{bridge,listeners}/`; production code under `client/module_app_ui/lib/src/platform/voice/`,
`client/module_app_ui/lib/src/features/session_detail/widgets/`, `client/app/lib/features/session_detail/widgets/`,
`client/desktop/lib/core/widgets/desktop_composer_presentation_scope.dart`,
`client/module_core/lib/src/{capabilities,cubits,platform,repositories,services}/`, and
`bridge/app/lib/src/{listeners,repositories,services}/`.
