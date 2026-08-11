# Voice Input

## Capability

The mobile composer records speech while the user holds the mic control, uploads the audio to the Sesori auth server
for transcription, and inserts the text into the prompt field for review before sending. A voice-first or text-first
preference decides which control leads. No bridge route or backend plugin participates; the device microphone and
transcription endpoint are external.

## Required Behavior

- Recording starts only with microphone permission. Denial or a failing check gives a distinct permission error and
  never leaves the composer stuck.
- One interaction at a time: a concurrent start is ignored, and a release during recorder startup discards the
  incomplete recording.
- While recording the composer shows live amplitude, holds a stable layout, keeps the screen awake, and offers
  drag-to-cancel; recording reaches a maximum duration and signals auto-stop instead of running indefinitely.
- Cancel stops the recorder, releases the wake lock, deletes the audio file, and invalidates any in-flight
  transcription so a late response cannot land in a newer interaction.
- An empty or zero-byte recording fails as a recording error and is never uploaded as success. Errors map to distinct
  outcomes for permission, recording, auth, server, empty transcript, network, and cancellation.
- Every recording file is deleted after stop, cancel, failure, and disposal; no audio is retained.
- Text is inserted for review, never auto-sent. The draft tracks voice-origin spans, so a message retaining one counts
  as voice-assisted input.
- Successful transcription reports one content-free analytics event. No audio, transcript, or prompt text reaches logs
  or analytics.
- The preference defaults to voice-first, persists, and falls back to voice-first on a corrupt or unknown stored
  value.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because microphone and transcription setup is too expensive for a heartbeat. |
| L2 Routine | Automated, mobile client, no plugin, fake recorder and HTTP client: permission denial, concurrent-start rejection, zero-byte rejection, cancel invalidating an in-flight upload, error mapping, max-duration signalling, file cleanup on every exit path, draft voice-span and input-mode derivation. |
| L3 Release | Client end to end on the release-target client platform: hold to record, release to transcribe, transcript inserted and editable, drag-to-cancel, layout stability, and the voice-first/text-first preference changing which control leads. |
| L4 Extended | Client end to end on the release-target client platform: background or system interruption, permission revoked between interactions, transcription failure and retry, offline upload failure, disposal while recording, wake lock released on every path. |
| L5 Full | Real device microphone and live transcription endpoint on every supported mobile platform: audible speech yields usable text, a near-maximum recording auto-stops and still transcribes, iOS haptics and system sounds stay audible while recording. |

## Exploration Guidance

Vary hold duration near the minimum and the limit, release timing relative to recorder startup, and whether the field
already contains typed text. Alternate cancel methods, edit or delete part of the inserted text before sending to
exercise voice-span survival, and switch the preference between interactions. On hardware, vary ambient noise and
interruptions such as a call.

## Failure Signals

- The composer stays in a recording or transcribing state after error, cancel, or disposal, or a cancelled transcript
  appears in a later interaction.
- A recording file survives any exit path, or the wake lock stays held.
- Audio is uploaded despite denied permission, or denial is reported as a generic network or server failure.
- Text is sent without review, or a message with surviving voice text is classified as typed.
- Any audio, transcript, or prompt content reaches logs or analytics.

## Known Limitations

- Microphone and hosted transcription are external and non-deterministic; assert usable non-empty text, never exact
  wording. Simulators and fakes cannot prove real capture, iOS audio-session behavior, or haptics; those stay partial
  without L5.
- Transcription is unavailable while unauthenticated or offline, which is expected degraded behavior. Mobile only:
  desktop and bridge have no voice capability.

## Sources

`client/app/test/capabilities/voice/`, `client/module_core/test/services/`, `client/module_prego/test/components/`;
production code under `client/app/lib/capabilities/voice/`, `client/module_core/lib/src/capabilities/voice/`, and
`client/module_core/lib/src/foundation/models/composer/`.
