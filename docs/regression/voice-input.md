# Voice Input

## Capability

The mobile composer records speech while the user holds the mic control, uploads the audio to the Sesori auth server
for transcription, and inserts the text into the prompt field for review before sending. A voice-first or text-first
preference decides which control leads. The device microphone and transcription endpoint are external. The bridge
independently prepares optional project-scoped vocabulary from bounded local evidence; no backend plugin participates.

## Required Behavior

- Recording starts only with microphone permission. Denial or a failing check gives a distinct permission error and
  never leaves the composer stuck.
- One interaction at a time: a concurrent start is ignored, and a release during recorder startup discards the
  incomplete recording.
- Starting, recording, transcribing, and cancelling are mutually exclusive composer interactions; input from a stale
  interaction cannot reset or append text into a newer one.
- Before capture, the client discovers the server-owned voice capability. Missing, unavailable, or timed-out discovery
  preserves released async behavior; an advertised incompatible contract fails visibly rather than silently downgrading.
  The bridge derives the exact opaque repository or bridge-local glossary key and returns it through the typed current-
  project contract; older bridges omit it and voice continues without glossary context. Raw project IDs never reach
  auth.
- While async recording the composer shows live amplitude, holds a stable layout, keeps the screen awake, and offers
  drag-to-cancel; recording reaches a maximum duration and signals auto-stop instead of running indefinitely.
- Protocol-1 realtime capture starts paused as PCM16 mono with the same iOS haptics/system-sounds policy as async,
  opens the authenticated Sesori WebSocket, force-refreshes once and retries when the upgrade rejects a locally fresh
  token, waits for `ready`, revalidates the effective native sample rate, then resumes and forwards naturally paced
  frames. Frames before `ready` are discarded rather than queued. A transport or supported-format failure before the
  first sent frame may restart as a fresh async recording; after the first sent frame there is no file fallback.
- Realtime confirmed text appends and provisional text replaces in the interaction-local preview without mutating the
  draft. Finish commits one final voice span. Server `session_limit` and `quota_limit` completion auto-stop through the
  same Cubit seam; an empty confirmed completion is terminal rather than a false success. A post-audio socket or
  recorder failure immediately leaves recording through the same Cubit seam, commits only non-empty confirmed text,
  drops provisional text, shows the typed provider-neutral error, and never exposes async Retry/Discard.
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
- Text is inserted for review, never auto-sent. The draft tracks voice-origin spans, so a message retaining one counts
  as voice-assisted input.
- Successful transcription reports one content-free analytics event. No audio, transcript, or prompt text reaches logs
  or analytics.
- A current-project load resolves the bridge-owned opaque scope for the typed response, then starts best-effort
  glossary population; a project entering the active-view set also starts population. Population itself stays behind
  one serialized background coordinator and never delays recording or transcription.
- Glossary population derives an exact opaque repository or bridge-local scope, scans bounded local Git/filesystem
  evidence, filters credential-shaped content before tokenization, and reconciles at most 50 deterministic terms.
  Only the opaque scope and filtered terms leave the bridge. Scope, scan, or publication failure leaves voice input
  available without an updated glossary.
- The preference defaults to voice-first, persists, and falls back to voice-first on a corrupt or unknown stored
  value.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because microphone and transcription setup is too expensive for a heartbeat. |
| L2 Routine | Automated, mobile client and bridge, no plugin, fake recorder, HTTP/WebSocket clients, Git, and filesystem: permission denial, concurrent-start rejection, zero-byte rejection, cancel invalidating an in-flight upload, authoritative true/false/omitted/malformed retryability mapping, retained-artifact Retry/Discard and retry cancellation, serialized send-time abandonment including an active retry, capability fallback/contract failure, bridge-derived opaque project context, one forced-refresh handshake retry, paused-ready-resume ordering, pre-ready frame discard, realtime preview replacement, confirmed-partial failure with no async Retry, terminal/missing cleanup, max-duration signalling, deletion failure logging, draft voice-span and input-mode derivation, current-project/active-view glossary triggers, serialized bounded inference, exact-scope reconciliation, and shutdown cancellation. |
| L3 Release | Client end to end on the release-target client platform: hold to record, release to transcribe, async or realtime transcript inserted and editable, realtime confirmed/provisional preview, drag-to-cancel, layout stability, and the voice-first/text-first preference changing which control leads. |
| L4 Extended | Client end to end on the release-target client platform: background or system interruption, permission revoked between interactions, offline async upload failure followed by successful Retry without re-recording, explicit retryable and terminal server outcomes, older-server omission fallback, realtime pre-audio async fallback, post-audio confirmed-partial/no-Retry behavior, discard/disposal cleanup, wake lock released on every path. |
| L5 Full | Real device microphone and live transcription endpoint on every supported mobile platform: audible speech yields usable text, a near-maximum recording auto-stops and still transcribes, iOS haptics and system sounds stay audible while recording. |

## Exploration Guidance

Vary hold duration near the minimum and the limit, release timing relative to recorder startup, and whether the field
already contains typed text. Alternate cancel methods, edit or delete part of the inserted text before sending to
exercise voice-span survival, and switch the preference between interactions. On hardware, vary ambient noise and
interruptions such as a call.

## Failure Signals

- The composer stays in a recording or transcribing state after error, cancel, or disposal, or a cancelled transcript
  appears in a later interaction.
- A retryable async failure loses the artifact or lacks persistent Retry/Discard controls; a terminal/unknown failure
  exposes Retry; a manual retry invokes the recorder; a retry cancellation deletes the saved recording; send-time
  abandonment duplicates a submission or lets a retry finish into the cleared composer; cleanup is not attempted on
  terminal paths; a deletion failure is unlogged; or the wake lock stays held.
- Realtime audio is forwarded before `ready`, a raw project ID or client-derived mismatched glossary key leaves the
  device, provisional text mutates the draft, a terminal event leaves the composer recording, an empty completion
  silently succeeds, a post-audio failure offers full-recording Retry, confirmed partial text is lost, or a late finish
  lands in a newer composer interaction.
- Audio is uploaded despite denied permission, or denial is reported as a generic network or server failure.
- Text is sent without review, or a message with surviving voice text is classified as typed.
- Any audio, transcript, or prompt content reaches logs or analytics; raw project paths, repository origins, filenames,
  or metadata source text reach auth transport; glossary failure blocks recording or transcription; or concurrent
  triggers run overlapping local scans.

## Known Limitations

- Microphone and hosted transcription are external and non-deterministic; assert usable non-empty text, never exact
  wording. Simulators and fakes cannot prove real capture, iOS audio-session behavior, or haptics; those stay partial
  without L5.
- Transcription is unavailable while unauthenticated or offline, which is expected degraded behavior. Mobile only:
  desktop and bridge have no voice capability.
- Retained recordings are composer-local and memory-owned. They do not survive composer disposal, route replacement,
  process restart, or a valid submission of other composer content. Failed best-effort deletion can still leave an
  unowned audio file on disk.
- Manual Retry has no exactly-once guarantee. If the provider completed work but the response was lost, resubmitting the
  same artifact can repeat provider processing and quota usage.
- Realtime capture intentionally has no full-recording spool or post-audio async fallback. Process death or transport
  failure can preserve only confirmed text already delivered to the app; provisional text and unsent speech are lost.

## Sources

`client/app/test/capabilities/voice/`, `client/app/test/features/session_detail/widgets/`,
`client/module_core/test/{capabilities,cubits,repositories,services}/`, and bridge glossary tests under
`bridge/app/test/{bridge,listeners}/`; production code under `client/app/lib/core/platform/`,
`client/app/lib/features/session_detail/widgets/`,
`client/module_core/lib/src/{capabilities,cubits,platform,repositories,services}/`, and
`bridge/app/lib/src/{listeners,repositories,services}/`.
