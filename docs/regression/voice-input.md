# Voice Input

## Capability

The mobile composer records speech while the user holds the mic control, uploads the audio to the Sesori auth server
for transcription, and inserts the text into the prompt field for review before sending. A voice-first or text-first
preference decides which control leads. After a user successfully begins recording, the client explicitly asks the
bridge to seed optional project-specific glossary context; no backend plugin participates, and audio still travels
directly from the client to the transcription endpoint.

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
- A scoped transcription sends only the versioned opaque glossary key derived by the bridge using a private persisted
  HMAC secret over its stable registration id and the stable project id. The client reuses that exact returned key; the
  secret and identifiers never reach auth, and equal local paths on different bridges cannot share a glossary.
- Pure-Dart core logic owns recording-to-population/key/transcription coordination and routes hosted transcription
  through its repository layer. Flutter only adapts native recording lifecycle; generation-scoped cleanup from a stale
  upload cannot invalidate a successor recording.
- Glossary population starts only from explicit hosted-voice use and is best effort; it never delays recording or
  transcription. A transcription remains unscoped when the local route has not answered yet or is unsupported. The
  bridge attempts a project once per process, serializes different projects, reads existing server words before local
  inference, and skips local scanning once the project already has 50 terms.
- Git inference streams at most 50,000 tracked path names and never inspects ignored/untracked root metadata. A Git
  operational failure aborts inference rather than falling back to root enumeration; definite non-Git enumeration is
  also streamed and bounded. README/package-manifest reads are capped, and quoted/unquoted credential assignments,
  authorization/Bearer values, prefixed/secret-shaped spans, ignored vendor/build/generated paths, hashes, and generic
  terms are excluded before ranking. At most enough terms to reach 50 are uploaded; source contents and paths never
  leave the bridge.
- The preference defaults to voice-first, persists, and falls back to voice-first on a corrupt or unknown stored
  value.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because microphone and transcription setup is too expensive for a heartbeat. |
| L2 Routine | Automated, mobile client and bridge, no plugin: fake recorder and HTTP client cover permission denial, concurrent-start rejection, zero-byte rejection, generation-scoped stale cleanup, cancellation, error mapping, duration signalling, file cleanup, draft voice-span/input-mode derivation, repository-routed opaque-key handoff, pending/old-bridge unscoped degradation, layered lazy secret persistence, bounded/fail-closed Git detection, tracked-only metadata, credential-assignment/prefixed-span rejection, ranked term selection, serialized/coalesced population, authenticated glossary reads/additions, and shutdown drain. |
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
- Any audio, transcript, prompt, or local metadata content reaches glossary requests, logs, or analytics, a raw bridge
  or project identifier/path reaches the auth server, or equal project ids on two bridges derive the same key. Only
  filtered inferred terms and the opaque bridge/project key may reach the glossary endpoint.
- Starting voice waits for glossary population, starts multiple glossary scans for that project, or lets several
  project scans run concurrently.
- A Git operational failure falls back to root enumeration, or stale completion/cleanup from one recording clears the
  glossary scope owned by its successor.

## Known Limitations

- Microphone and hosted transcription are external and non-deterministic; assert usable non-empty text, never exact
  wording. Simulators and fakes cannot prove real capture, iOS audio-session behavior, or haptics; those stay partial
  without L5.
- Transcription is unavailable while unauthenticated or offline, which is expected degraded behavior. Audio capture is
  mobile-only; desktop and bridge do not record or transport microphone audio.
- Failed recording-file deletion can leave audio on disk because cleanup is
  best-effort and has no retry owner.
- Glossary inference is intentionally attempted only once per project per bridge process. A failed attempt waits for a
  bridge restart rather than retrying in the background; an existing 50-term glossary is not rescanned during that
  process.
- Deleting or corrupting the bridge-local glossary secret starts a new opaque namespace. The optional glossary
  self-heals empty rather than attempting to recover or migrate unreachable server words.

## Sources

`client/app/test/capabilities/voice/`, `client/module_core/test/capabilities/voice/`,
`bridge/app/test/bridge/{repositories,services,routing}/`, `bridge/app/test/api/sesori_server_api_test.dart`, and
`client/module_prego/test/components/`; production code under `client/app/lib/capabilities/voice/`,
`client/module_core/lib/src/{capabilities/voice,repositories,services}/`,
`bridge/app/lib/src/{api,foundation,repositories,services,routing}/`, and
`shared/sesori_shared/lib/src/{crypto,models/auth,models/sesori}/`.
