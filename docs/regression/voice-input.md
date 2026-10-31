# Voice Input

## Capability

The mobile composer records speech while the user holds the mic control, uploads the audio to the Sesori auth server
for transcription, and sends the words when the release finishes them; sliding onto the pencil target keeps them in the
prompt field instead. A voice-first or text-first preference decides which control leads. The desktop composer stays
text-first and adds the mic as an extra control on the same pipeline: one click starts listening, and a second click in
the same place or Enter sends; the pencil or Shift+Enter puts the words in the prompt field, and the X or Escape
cancels. The device microphone and transcription endpoint are external. The bridge independently prepares optional
project-scoped vocabulary from bounded local evidence; no backend plugin participates. When the voice mode switch turns
live on and the host can stream, the same gestures run over a realtime socket instead of an upload. On a phone the Firebase
Remote Config key `voice_live_enabled` controls the switch. On desktop the build fixes it: the `internal` channel runs live,
and `stable` records first.

## Required Behavior

- Recording starts only with microphone permission. Denial or a failing check gives a distinct permission error and
  never leaves the composer stuck.
- Opening a composer never pauses another app's music or video. The iOS recorder warm-up is skipped while other
  audio plays, so only an actual recording takes the audio session.
- One interaction at a time: a concurrent start is ignored, and a release during recorder startup discards the
  incomplete recording.
- Starting, recording, transcribing, and cancelling are mutually exclusive composer interactions; input from a stale
  interaction cannot reset or append text into a newer one.
- Each composer requests current-project context in the background, and starts with the key its project had earlier in
  this app run on the same computer. It asks again for later interactions when it still has no key, and uses only a
  validated, bridge-issued opaque glossary key: at the start of a live dictation, or at each upload of a recording, so a
  key that arrives while recording or before a retry still counts. An answer without a key keeps the known one. Missing,
  pending, invalid, unsupported, or failed context remains unscoped without delaying capture, raw project identity never
  reaches auth, and the client log says whether each transcription used a glossary.
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
- An unset `voice_live_enabled` means record first. A phone reads it at launch, so a Firebase change applies from its next
  cold launch.
- A hold takes the voice mode once, when it starts, and keeps it whatever the switch does next. It never waits for an
  answer: until the mode has loaded and the host has said it can stream, a hold records first. The feedback sheet always
  records first.
- A live dictation sends its audio as it is spoken. Audio spoken before the server is ready waits in memory, up to
  30 seconds, and goes first, so a start that reaches `ready` within that loses nothing. The server refuses more than 5 seconds ahead of real time,
  so up to 4 seconds go at once and the rest follows at real time, with new audio behind it. The words lag by that
  backlog until the release, and a release sends what is left at the same pace, up to about 26 seconds under Finishing,
  before it finishes. With the finger still down, 30 seconds without `ready` falls back and drops what was held. A
  release before `ready` waits for the server with no client deadline, only the X, then sends what was held the same
  way and finishes. Only confirmed words are the result; a blank result is the
  empty-transcript error.
- The socket starts with the microphone, and audio still waits for `ready`, which can come first. A microphone that
  cannot stream, a denied permission, a cancel or a dropped hold closes the socket. A socket that fails first falls back
  once the microphone is up. A hold dropped after `ready` can have sent its first frames before `cancel`; its words are
  never handed over.
- A live failure before any audio left while the user still holds continues as a recording, without losing the hold.
  Those words land in the box with a cut-off notice and are never sent. A denied microphone permission is not a failure
  of this kind and shows its own error. If the recorder cannot restart, or the user had already released, the dictation
  ends in an error notice with nothing in the box.
- A live failure after audio left puts every word heard, confirmed or provisional, in the box with the cut-off notice,
  and never sends them. With no words it shows an error notice. Live keeps no recording, so it never offers Retry.
- The server's session or quota limit ends a live dictation with its confirmed words in the box and a limit notice, even
  with the finger still down.
- Cancelling a live dictation at any point sends `cancel` when the socket is streaming, closes the socket, releases the
  microphone, and hands nothing over.
- The release hint centres over the whole composer. A background tasks pill beside it fades where it stands and takes
  no touches or keyboard focus while the hint shows, and comes back afterwards, taking neither until it shows again;
  nothing in that row moves.
- A press dissolves: the header and the hint cross over each other, and so do the composer's resting words and the
  waveform. A release is clean: the hint and the waveform leave first, then the header and the words or shimmer return
  in the same place, for a send, a cancel, and a pointer shell's Send or X. A tap released before the press's fade ends
  dissolves back from where it had reached and never shows nothing. Pressing again mid-release carries on from there.
- When a transcription or a live finish ends, "Transcribing..." or "Finishing..." leaves first, then the resting words
  return in the same place, with a release's timing, in every layout. One ending before those words finished fading in
  retraces from where they had reached while the resting words rise from the first frame, so nothing waits. A failure's
  Retry and Discard show from the first frame, as they take taps at once.
- On touch in text-first, the mic stays under the finger on every frame of a hold and its release. The send button
  beside it fades where it stands and keeps its room, which costs the waveform 44 pt, and the waveform never resizes.
  The faded button takes no touches, focus or screen reader taps, and fades back on release or cancel.
- In voice-first the pill takes the hold. Its trailing buttons (keyboard and stop on the resting pill, send on the
  typing pill) never move or get cut off through a hold. They fade out where they rest as the hold starts, take no
  touches, focus or screen reader taps while gone, and fade back on release or cancel as the waveform's end clears their
  place, with the tasks pill's timing. They stay inert until that fade starts to show, 132 ms into the return once a
  hold has settled, so a tap on the empty spot never sends a draft the hold left in the box or stops running work. Send
  stays disabled while dictated words are on their way. The room behind the buttons matches their width, still closes
  and reopens so the waveform gets it, and the waveform's faint end shows through them as they fade out. Reduced motion
  keeps the buttons' fades and their inert stretch, and moves only the room, at once. iOS Reduce Motion runs every fade
  at its full length. Android's Remove animations also runs the framework's animations at 5%, so there a fade takes
  about a frame and the inert stretch with it.
- On the resting voice-first pill, when work starts, the keyboard button glides left and the stop button fades in at the
  row's end, uncut and never travelling, once the keyboard button has cleared that spot. When work ends it fades where
  it is, still a stop button, and the keyboard button glides back over it. The words re-centre with the glide. Stop
  takes no touch, focus or screen reader tap until 132 ms into its arrival, nor from the moment it starts to leave, and
  its empty room still takes a hold. Work starting or ending during a hold moves nothing; both buttons return in their
  new places on release. Reduced motion keeps stop's fade and its inert stretch, and the keyboard button and the words
  move at once.
- The send and stop buttons of the text-first pills and the typing pills dissolve in one 44 pt spot as typing clears or
  returns and as work starts or ends. Stop fades over a send that stays at full strength and keeps its look until it is
  covered, so the spot never goes faint. A swap turned back midway retraces with no restart and no third layer. Reduced
  motion keeps the fade. The outgoing button takes no touch, focus or screen reader tap from the frame of the swap, and
  screen readers see only the current one. The current one takes input once it shows, 132 ms into a settled fade, so the
  second tap of a double tap on send stops nothing, and that holds where the send collapses the box to the resting pill.
  A press lifted after its stop left stops nothing. Send's disabled and enabled looks stay one button, with no fade.
- A live dictation's words show in a panel, in a layer of their own, while the user speaks. Nothing under that layer moves
  or resizes for them, and they never take a touch away from the pill or the chat.
- The panel leaves the chat in view, on phone and desktop alike. It opens at the first word and grows to five lines, as
  wide as the composer and clear of the release hint. The newest words stay at the bottom, a new line rises smoothly, and
  older lines fade away at the top once the words run out of room.
- A tentative word fades in dim and brightens where it stands when it turns final or when the user releases, and on its
  way to the box when a dictation is cut off. It also brightens once the server has left it unchanged for half a second,
  so most of a sentence reads as solid while only the latest words stay dim. This is presentation only: only confirmed
  words are the result, and a bright word can still change.
- A word the server changes keeps its place. It eases dim again, as do the words after it, and each waits out its half
  second again; words before it are untouched. A word gaining only its spacing hasn't changed, nor has one the server
  confirms partway through. A word that keeps changing stays dim. None of this moves or rewraps the text, and each word
  leaves on a glide as bright as it stood.
- Sliding up to cancel fades the words with the finger, to 40% at the arm line, and coming back restores them. A cancel
  fades them with a 12 px drop. Reduced motion removes the movement and keeps the fades. Word fades and brightening run
  on the words' own clock, so they keep their length under iOS Reduce Motion and Android's Remove animations alike.
- A sent dictation's words glide to its bubble, in session detail and in a new session's launch view. The bubble is built
  hidden, the list rises for its row as the words come down, and the bubble shows under the words once they have landed
  on it, so there is one copy throughout. If no bubble is built within five frames, the words glide to where it would
  have been, right-aligned above the composer, and fade. If the screen goes mid-glide, they go with it.
- Live words that land in the box (the pencil or a cut-off) glide to the field, which holds its text back
  until they arrive. A dictation with nothing to land in, or under reduced motion, fades where it stands.
- Successful transcription reports one content-free analytics event whose closed `finish` says how it ended: `sent`,
  `edited` or `cut_off`, and whose closed `mode` says how it actually ran: `live` or `after_recording`, which a fallback
  counts as. No audio, transcript, or prompt text reaches logs or analytics.
- A successful current-project load starts a best-effort bridge glossary refresh when that glossary is due: at most once
  every 24 hours, 10 minutes after a failure, and shared by worktrees of one repository. Refreshes run one at a time and
  never delay the route response, recording, or transcription. A bridge restart allows one more refresh, and the bridge
  log records each refresh with its word counts, never the words.
- Apps older than v1.10.0 still send `project_view`. The bridge decodes it, with a project id or null, and ignores it:
  no reply, no warning, and later requests are still answered.
- A current-project response carries the project's glossary key from its first load; a failed key lookup leaves it
  out without failing the route.
- Glossary population derives an exact opaque repository or bridge-local scope, scans bounded local Git/filesystem
  evidence, filters credential-shaped content before tokenization, and reconciles at most 100 deterministic terms. Terms
  are whole ASCII identifiers; common English words and their simple inflections, generic scaffolding names, hash/serial
  fragments, and a plural beside its singular are dropped. Only the opaque scope and filtered terms leave the bridge.
  Scope, scan, or publication failure leaves voice input available without an updated glossary.
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
- Desktop's resting hint fades where it rests through a dictation and back, while the row beneath it gives the options'
  place to the pencil and X. Tapping anywhere in the row's middle focuses the field; a screen reader hears the hint once
  and can tap it. Touch layouts keep the hint in the row, where nothing moves it.
- Voice-first's hold surface tells screen readers what its pill shows, on a node of its own with no other words:
  "Transcribing..." while transcribing, or "Finishing..." while a live session finishes, and otherwise its hint, "Hold
  to talk" or, with a draft in the box, "Hold to talk more".
  A semantic tap on it toggles recording.
- The composer's icon buttons are each a named screen reader button that can be activated, in every layout: "Type a
  message", "Stop", "Send", "Cancel transcription", a pointer shell's "Record voice", "More actions", "Attach image",
  "Slash commands" and "Expand editor". Send reads as disabled when there is nothing to send, and "Attach image",
  "Slash commands" and "Expand editor" while a dictation is under way. No button's tooltip lands on the pill. During a
  hold the keyboard button takes no screen reader tap.
- The Default input page has an inline title, explanatory subtitle, and two mutually exclusive Voice/Text previews.
  Selection updates the existing app-root preference and persists immediately; external preference changes update
  both the row and the open page. Back is the sole navigation action and returns to Settings.
  Labels and subtitle remain readable with accessibility text scaling, and preview artwork is excluded from semantics.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because microphone and transcription setup is too expensive for a heartbeat. |
| L2 Routine | Automated, mobile client and bridge, no plugin, fake recorder, HTTP client, Git, and filesystem: permission denial, concurrent-start rejection, zero-byte rejection, cancel invalidating an in-flight upload, authoritative true/false/omitted/malformed retryability mapping, retained-artifact Retry/Discard and retry cancellation, serialized send-time abandonment including an active retry, available/pending/invalid opaque project context, a key arriving mid-recording, a remembered key per computer and project, terminal/missing cleanup, max-duration signalling, deletion failure logging, draft voice-span and input-mode derivation, the dictated marker on sends with plain restored drafts and titles, the current-project glossary trigger with its daily and after-failure refresh limits, the first-load glossary key and its failed lookup, legacy `project_view` accepted and ignored, serialized bounded inference with common-word and fragment filtering, exact-scope reconciliation, shutdown cancellation, and live dictation over a fake socket: the mode decision at the hold, the socket starting with the microphone and closing when that start fails or is dropped, `ready` before the microphone is up, the held audio and a release before ready, the backlog's pace and its stops, every fallback, the cut-off and limit endings, and cancel and close at each stage. Automated, widget level with a fake cubit: the live-word panel, a composer mounting mid-dictation, the slide-out fade, the cancel's fade and drop, reduced motion, a tentative word brightening after its unchanged half second, easing dim again when the server changes it while the words before it stay put, a spacing-only update or a word confirmed partway through leaving it alone, and the glide: the bubble's handover with one copy on every frame, the five-frame fallback above the composer, the screen or row going mid-glide, the box holding its text back, and no travel under reduced motion. The release hint centred over the composer with a trailing control that fades in place, takes no focus, and doesn't move. Per frame through a hold: the press's dissolve, a release or cancel, and a pointer shell's Send and X, with the hint and waveform never visibly over what returns, quick taps with no empty blink or jump, pressing again mid-release, reduced motion, and the composer's eased height at large text. Text-first's mic and waveform holding still per frame through a hold, its release and a slide up, at small widths and large text, with send fading in place, inert to touch, focus and screen reader, under both reduced motion settings too, and back with the text after a cancel. Voice-first's keyboard, stop and send buttons holding their place unclipped per frame through a hold, its release and a cancel, at small widths and large text, inert to touch, focus and screen reader, under both reduced motion settings too, with the waveform opening into their room and their return waiting for its end to clear; the room matching each button's real width, disabled and awaiting words included; send disabled while words are on their way; and a tap in the return's unseen first 132 ms after a cancel or inserted words sending nothing, stopping nothing and opening nothing. The screen reader label of voice-first's hold surface while transcribing and finishing, and on every composer icon button its own name and tap on its own node, with no tooltip on the pill, touch and pointer, at rest and busy; a semantic tap on the keyboard button opening typing, on the pill toggling recording, and the keyboard button taking none during a hold; its tooltip still showing on long-press and hover. Desktop's hint: identical position on every frame of a dictation and its cancelled or empty ending, with and without the attach action, its tap target, text cursor and single screen reader label; on touch it stays in its row. Voice-first's stop button per frame as work starts and ends, at small widths and large text: uncut in its place, the keyboard button and words gliding, its fade only once the keyboard button has cleared, no touch, focus or screen reader tap until it shows or once it goes, its empty room taking a hold, flipping again mid-fade with no jump, work changing mid-hold, and both reduced motion settings. A transcription's end per frame in every layout, touch and pointer, and a live finish's on touch: the words clear before what rests returns with no frame showing both, an ending mid-fade retracing with no wait, the shimmer's timing from a release with a trailing control, a failure's Retry showing from the first frame, and a press after words landed still dissolving. Send and stop per frame in text-first, voice-first and a pointer shell, as typing clears and returns and as work starts and ends: one spot, stop's fade over a held send that keeps its look, turned back midway by typing or busy with one copy of each and no restart, no touch or screen reader tap until the current button shows and none on the outgoing one, a double tap on send, a press lifted after its button left on both touch platforms, a press's scale through the swap, disabled to enabled send staying one button, and reduced motion keeping the fade. |
| L3 Release | Mobile and macOS desktop client E2E: [recording and preference navigation](#client-release-coverage-l3). |
| L4 Extended | Client end to end on iOS: change harness availability from another surface while recording and while transcription is pending; no text or send lands after the block, and voice returns only after session prerequisites recover. Client end to end on the release-target client platform: background or system interruption, permission revoked between interactions, offline async upload failure followed by successful Retry without re-recording, explicit retryable and terminal server outcomes, older-server omission fallback, discard/disposal cleanup, wake lock released on every path. |
| L5 Full | Real device microphone and live transcription endpoint on every supported mobile platform: audible speech yields usable text, a near-maximum recording auto-stops and still transcribes, iOS haptics and system sounds stay audible while recording, music from another app keeps playing when a chat opens, and live words keep up with speech with first words not clipped, on a real microphone. |

### Client release coverage (L3)

On the release-target mobile platform, hold to record and release to send, slide onto the pencil and edit the inserted
transcript, slide up to cancel, slide up and back, and check layout stability and which control leads under each input preference.
Open Settings → Default input, select each mode, check Back returns to Settings from a non-home opener,
reopen the page and verify the saved row value.
On the macOS desktop build, grant the first microphone prompt, click the mic, speak, and click again without moving the
mouse to send; start again and press Enter to send, with text already in the box; start again and use Shift+Enter, then
the pencil, and edit the inserted transcript; start again and cancel with Escape, then the X, and confirm the box keeps
its text; click into the transcript mid-recording and confirm the recording continues.
With live on, hold and speak on the mobile platform, and confirm the words appear as they are
spoken and nothing under them moves. Release to send and confirm the words glide into the bubble; slide onto the pencil
and confirm they glide into the box; slide out and confirm the fade. Repeat with the server unreachable, and confirm the
dictation falls back and lands in the box with a notice. On the desktop `internal` build, confirm the same with its
controls.
Before the first public release containing this code, confirm `voice_live_enabled` is `false` in Firebase.
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
- A hold waits for the voice mode, a switch change alters a dictation already running, a live failure offers Retry, a
  fallback loses the hold, audio or `finish` reaches the socket before ready, or a failed microphone, a denied permission
  or a dropped hold leaves a socket open.
- A start slower than 4 seconds and under 30 loses or reorders audio, or ends in `invalid_audio`; `finish` goes before
  the last byte; a cancel, a close, a socket failure or the X leaves the backlog sending; or a start with no backlog
  runs a pacing timer.
- While the user speaks, live words move, relayout or rebuild the chat or the composer, snap when they wrap, hide the
  release hint, or block the pill's gesture. Words stay on screen after their glide or fade ends.
- A tentative word brightens before its half second is up, stays dim once the server has left it alone, or stays bright
  after the server changes it; or a spacing-only update dims it again.
- A glide shows two copies of the words, or pops the text at its end: a change of weight, wrap or position when the
  bubble or the box takes over. The list jumps instead of rising for the row, a word lands on an older
  row or a pinned copy, the panel's shadow shows as a plate under a clear surface, or reduced motion travels.
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
  `parecord` and `ffmpeg` on the PATH; the DEB and RPM packages recommend them on a fresh install (an upgrade may not
  add them), the AppImage cannot, and without them the composer shows the recording-failed notice. With `parecord` but
  no `ffmpeg`, live can start, and a failure before any audio leaves ends in the transcription-failed notice because the
  fallback cannot record. Leaving a desktop session while recording discards the recording, as on the phone.
- Live has no client deadline for `ready` once the user has released: a dead network shows Finishing until the socket
  gives up, and the X still stops it. A slow start's backlog also has to drain under Finishing; it is lost if the socket
  drops first, and the words so far land in the box with the cut-off notice.
- A fallen-back recording that fails and is retried lands in the box without the cut-off notice.
- A microphone slow to send its first frame after `ready`, such as behind the first permission prompt, meets the server's
  `audio_timeout` and the dictation falls back to a recording. The auth server's `REALTIME_FIRST_AUDIO_TIMEOUT_MS`
  defaults to 5 seconds.
- A live dictation takes the glossary key when the microphone starts, so a key that first loads during that start applies
  from the next dictation; this one runs without it.
- A very long live dictation lays out its whole text once per update; no slowdown showed at about 100 words, and much
  longer text is unmeasured. A route pushed mid-dictation followed by a window resize can trip an assert while the live
  words' portal is open (flutter/flutter#192030).
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
`client/module_app_ui/test/features/session_detail/widgets/prompt_input_live_words_test.dart`,
`client/module_app_ui/test/features/session_detail/widgets/composer_live_words_glide_test.dart`,
`client/module_core/test/{capabilities,cubits,repositories,services}/`, and bridge glossary tests under
`bridge/app/test/{bridge,listeners}/`; production code under `client/module_app_ui/lib/src/platform/voice/`,
`client/module_app_ui/lib/src/features/session_detail/widgets/`, `client/app/lib/features/session_detail/widgets/`,
`client/desktop/lib/core/widgets/desktop_composer_presentation_scope.dart`,
`client/module_core/lib/src/{capabilities,cubits,platform,repositories,services}/`, and
`bridge/app/lib/src/{listeners,repositories,services}/`.
