# Voice Input

## Capability

The mobile composer records speech while the user holds the mic control, uploads the audio to the Sesori auth server
for transcription, and inserts the text into the prompt field for review before sending. A voice-first or text-first
preference decides which control leads. The bridge separately exposes an explicit route that can infer and upload
optional project-specific glossary terms; no backend plugin participates, and audio still travels directly from the
client to the external transcription endpoint.

## Required Behavior

- Recording starts only with microphone permission. Denial or a failing check gives a distinct permission error and
  never leaves the composer stuck.
- One interaction at a time: a concurrent start is ignored, and a release during recorder startup discards the
  incomplete recording.
- Starting, recording, transcribing, and cancelling are mutually exclusive composer interactions; input from a stale
  interaction cannot reset or append text into a newer one.
- While recording the composer shows live amplitude, holds a stable layout, keeps the screen awake, and offers
  drag-to-cancel; recording reaches a maximum duration and signals auto-stop instead of running indefinitely.
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
- Successful transcription reports one content-free analytics event. No audio, transcript, or prompt text reaches logs
  or analytics.
- Glossary population starts only from an explicit bridge request. The route returns a versioned opaque key after
  lazily loading a private persisted HMAC secret, then schedules best-effort work without waiting for inference.
- Git inference streams at most 50,000 tracked paths and never enumerates untracked or ignored root metadata. An
  operational Git failure aborts inference rather than treating the project as non-Git; non-Git enumeration is also
  streamed and bounded.
- README and package-manifest reads are capped. Quoted/unquoted credential assignments, authorization/bearer values,
  and prefixed/secret-shaped spans are removed before token splitting; generated/vendor/build paths, hashes, and
  generic terms are excluded before deterministic ranking. Only filtered terms and the opaque key reach auth—never
  source contents, paths, or raw identifiers.
- The bridge reads existing words before scanning, uploads at most enough to reach 50, attempts each project once per
  process, serializes different projects, and aborts/drains admitted work during shutdown.
- The preference defaults to voice-first, persists, and falls back to voice-first on a corrupt or unknown stored
  value.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because microphone and transcription setup is too expensive for a heartbeat. |
| L2 Routine | Automated, mobile client and bridge, no plugin: fake recorder and HTTP client cover permission denial, concurrent-start rejection, zero-byte rejection, cancellation, error mapping, duration signalling, cleanup, and draft voice-span/input-mode derivation; bridge coverage includes authenticated glossary calls, lazy secret persistence, deterministic HMAC scoping, tracked-only bounded streams, Git-failure handling, credential-span rejection, serialized/coalesced population, and shutdown drain. |
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
- Recording cleanup is not attempted, a deletion failure is unlogged, or the wake
  lock stays held.
- Audio is uploaded despite denied permission, or denial is reported as a generic network or server failure.
- Text is sent without review, or a message with surviving voice text is classified as typed.
- Any audio, transcript, or prompt content reaches logs or analytics.
- Source/path content, the bridge-local HMAC secret, or raw bridge/project identifiers reach auth; only filtered terms
  and the opaque bridge/project key may leave the bridge for glossary storage.
- A Git operational failure falls back to untracked root enumeration, a credential prefix is stripped before its
  suffix is filtered, multiple project scans compete, or shutdown leaves admitted glossary work undrained.

## Known Limitations

- Microphone and hosted transcription are external and non-deterministic; assert usable non-empty text, never exact
  wording. Simulators and fakes cannot prove real capture, iOS audio-session behavior, or haptics; those stay partial
  without L5.
- Transcription is unavailable while unauthenticated or offline, which is expected degraded behavior. Audio capture is
  mobile-only; desktop and bridge do not record or transport microphone audio.
- Failed recording-file deletion can leave audio on disk because cleanup is
  best-effort and has no retry owner.
- The current mobile client does not yet request glossary population or send the returned key; the bridge route is the
  first half of the stacked feature.
- Glossary inference is attempted only once per project per bridge process. A failed attempt waits for restart rather
  than retrying in the background, and deleting/corrupting the local secret starts a new empty opaque namespace.

## Sources

`client/app/test/capabilities/voice/`, `client/module_core/test/services/`, `client/module_prego/test/components/`, and
`bridge/app/test/bridge/{api,repositories,services,routing}/`; production code under
`client/app/lib/capabilities/voice/`, `client/module_core/lib/src/capabilities/voice/`,
`client/module_core/lib/src/foundation/models/composer/`, and `bridge/app/lib/src/{api,repositories,services,routing}/`.
