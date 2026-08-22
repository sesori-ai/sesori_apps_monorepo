# Voice Input

## Capability

The mobile composer records speech while the user holds the mic control, chooses realtime or async transcription from
auth capabilities before capture, and inserts confirmed text into the prompt field for review before sending. Missing
or failed capability discovery uses async. An advertised protocol 1 capability that is disabled uses async with an
opaque project key. A malformed capability response or one that does not advertise protocol 1 is a typed contract
failure and does not silently downgrade. A pre-audio realtime setup failure may fall back to async while the hold is
still active; any failure after audio starts never uploads retained audio. A voice-first or text-first preference
decides which control leads. No bridge route or backend plugin participates; the device microphone and transcription
endpoint are external.

## Required Behavior

- Recording starts only with microphone permission. Denial or a failing check gives a distinct permission error and
  never leaves the composer stuck.
- One interaction at a time: a concurrent start is ignored, and a release during recorder startup discards the
  incomplete recording.
- While recording the composer shows live amplitude, holds a stable layout, keeps the screen awake, and offers
  drag-to-cancel; recording reaches a maximum duration and signals auto-stop instead of running indefinitely.
- Realtime setup starts the recorder paused, validates the effective PCM16 mono format, waits for server readiness,
  discards pre-ready chunks, and retains no pre-ready audio queue.
- Project glossary context is scoped by an opaque project key only. Raw project IDs never leave the client and never
  appear in logs, evidence, or request summaries.
- Realtime preview is interaction-local: confirmed text is stable, provisional text is replacement-only, and neither
  mutates the editable draft while the gesture is active.
- Terminal success appends one voice-origin span from confirmed text. Terminal failure with confirmed partial text
  commits that confirmed text, drops provisional text, and shows the typed provider-neutral failure.
- Cancel stops the recorder, releases the wake lock, attempts audio-file deletion,
  and invalidates any in-flight transcription so a late response cannot land in
  a newer interaction.
- An empty or zero-byte recording fails as a recording error and is never uploaded as success. Errors map to distinct
  outcomes for permission, recording, auth, server, empty transcript, network, and cancellation.
- File deletion is attempted after stop, cancel, failure, and disposal. A deletion
  failure is logged with its path and error but is best-effort: the current path is
  cleared and no automatic retry owns residual audio.
- Text is inserted for review, never auto-sent. The draft tracks voice-origin spans, so a message retaining one counts
  as voice-assisted input.
- Successful transcription reports one content-free analytics event. No raw project ID, audio, transcript, prompt,
  provider, token, or provider error detail reaches logs, analytics, fixtures, or regression evidence.
- The preference defaults to voice-first, persists, and falls back to voice-first on a corrupt or unknown stored
  value.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because microphone and transcription setup is too expensive for a heartbeat. |
| L2 Routine | Automated, mobile client, no plugin, fake recorder, fake WebSocket, and fake HTTP client: capability-first realtime versus async selection; missing or failed discovery using async; disabled advertised protocol 1 using async with an opaque project key; malformed or unsupported advertised capability failing as a typed contract error without downgrade; pre-audio setup failure falling back async; post-audio failure not invoking async upload; opaque project key derivation and raw-ID non-transmission; start-paused ordering, effective format validation, pre-ready discard with no queue, confirmed and provisional preview without draft mutation, terminal success append, confirmed-partial failure append, cancel discard, stale-event safety, typed provider-neutral failure mapping, max-duration signalling, and file cleanup attempted on every exit path with deletion failure logged. |
| L3 Release | Client end to end on the release-target client platform with automated or fake services: hold to record, release to transcribe, confirmed text inserted and editable, very short hold, normal hold, drag-to-cancel, layout stability, quota failure, capacity failure, network loss, and the voice-first/text-first preference changing which control leads. |
| L4 Extended | Client end to end on the release-target client platform with automated or fake services: background/resume, system interruption, permission revoked between interactions, realtime setup fallback before audio, post-audio failure with confirmed partial commit and no retained upload, offline async failure, disposal while recording, wake lock released on every path. |
| L5 Full | Physical iOS and Android devices with real microphones and live auth transcription: realtime enabled and disabled capability paths, async compatibility path, audible speech yielding usable non-empty confirmed text, very short and normal holds, near-maximum auto-stop, drag cancel, quota exhaustion, provider capacity failure, network loss, background/resume, no local recording file remaining after realtime, and iOS haptics and system sounds staying audible while recording. |

## Exploration Guidance

Vary capability state, hold duration near the minimum and the limit, release timing relative to recorder startup and
realtime readiness, and whether the field already contains typed text. Alternate cancel methods, edit or delete part
of the inserted text before sending to exercise voice-span survival, and switch the preference between interactions.
For fake coverage, force quota, capacity, network loss, unsupported format, stale event, and malformed typed-failure
paths. On physical iOS and Android devices, vary ambient noise, background/resume, and interruptions such as a call.

## Failure Signals

- The composer stays in a recording or transcribing state after error, cancel, or disposal, or a cancelled transcript
  appears in a later interaction.
- Realtime is attempted when capability discovery is missing or failed, or when advertised protocol 1 is disabled;
  malformed or unsupported advertised capabilities silently downgrade instead of failing as a typed contract error;
  or async fallback starts after a realtime session has already sent audio.
- Pre-ready audio is queued or retained, preview mutates the draft before a terminal event, provisional text commits,
  or confirmed partial text is lost on terminal failure.
- A stale realtime event modifies a newer interaction, or a provider-specific error leaks through the app contract.
- Recording cleanup is not attempted, a deletion failure is unlogged, or the wake
  lock stays held.
- Audio is uploaded despite denied permission, or denial is reported as a generic network or server failure.
- Text is sent without review, or a message with surviving voice text is classified as typed.
- Any raw project ID, audio, transcript, prompt, provider detail, token, or unredacted provider error reaches logs,
  analytics, fixtures, or evidence.

## Known Limitations

- Microphone and hosted transcription are external and non-deterministic; assert usable non-empty text, never exact
  wording. Simulators and fakes cannot prove real capture, iOS audio-session behavior, or haptics; those stay partial
  without L5 physical-device evidence. Automated and fake coverage can prove ordering, fallback, preview, and typed
  error semantics, but not physical iOS or Android capture quality.
- Transcription is unavailable while unauthenticated or offline, which is expected degraded behavior. Mobile only:
  desktop and bridge have no voice capability.
- S03 automated and fake coverage is implemented, but physical iOS and Android proof remains required for S04 or
  rollout. Do not report L5 as passed until that evidence exists.
- Failed recording-file deletion can leave audio on disk because cleanup is
  best-effort and has no retry owner.

## Sources

`client/app/test/capabilities/voice/`, `client/app/test/features/session_detail/widgets/`,
`client/module_core/test/capabilities/voice/`, `client/module_prego/test/components/`; production code under
`client/app/lib/capabilities/voice/`, `client/app/lib/features/session_detail/widgets/`,
`client/module_core/lib/src/capabilities/voice/`, and `client/module_core/lib/src/foundation/models/composer/`.
