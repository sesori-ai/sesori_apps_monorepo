# Step 6 — Realtime transport

Split at 1,818 changed lines, over the soft cap. Step 6.i (#2220) landed the protocol,
domain model, fixture and error move. Step 6.ii adds the client and repository. These
notes cover both.

## Built

- `capabilities/voice/realtime_voice_protocol.dart`: wire enums, events, exceptions,
  the `start`, `finish` and `cancel` frames, and a strict event parser. Fixture copied
  byte for byte to `test/fixtures/voice_realtime_protocol_v1.json`.
- `capabilities/voice/realtime_voice_client.dart`: `RealtimeVoiceClient` with a
  `withChannelConnector` test seam like `RelayClient`, and one `RealtimeVoiceSession`
  per socket, whose phase is `awaitingReady`, `streaming`, `finishing` or `ended`.
- `VoiceRepository.openRealtime`, returning `VoiceRealtimeConnection`. Client and
  protocol are not exported, so this is the only way in.
- `foundation/models/voice/voice_realtime.dart`: sample rate and domain events.
- `VoiceTranscriptionError` moved from the service to `foundation/models/voice/`,
  because the repository sits below the service. `notAuthenticated`,
  `retryableServerError`, `serverError` and `networkError` gain a required
  `innerError`. After-recording callers pass null: their outcomes hold no cause.

No consumer and no user-visible change.

## Choices the plan left open

| Choice | Decision | Why |
| --- | --- | --- |
| 401 at upgrade | No refresh and retry | Rare, falls back (D21), and the fallback's upload refreshes the token, so the next live attempt heals. Differs from #918 |
| `open` returns | After the upgrade and `start`, not after `ready` | Step 8 buffers until `ready` (D29); `ready` is an event |
| Before `ready`, or audio after `finish` | `StateError` | The server would end the session; the order is step 8's |
| Sends after the session ended | Ignored | The microphone can outrun the terminal event, which the caller still hears |
| `cancel` | Sends the control only while streaming | Before `ready` the server answers `invalid_message`; after `finish` it ignores text. Closing releases the session either way |
| `statusCode` for socket errors | The code's fixed close code; 1002 for a protocol violation | Existing types need an int, and no HTTP status exists there |
| Complete reason | Maps to `VoiceDictationOutcome` | Saves a second enum; the plan treats both limits alike |
| Sample rate | All four, as an enum | Step 7 uses 16 kHz, but bad rates become unrepresentable |

Mapping: 401 or no token gives `notAuthenticated`. 429 and 5xx give
`retryableServerError`. Other upgrade statuses, including the disabled server's 404,
give `serverError`. Timeouts and closes without a terminal event give `networkError`.
Server error events follow their fixed `retryable`.

## For steps 7 and 8

- Frames must be even and at most 65,536 bytes, so capture chunks need realigning.
- `finish` before `ready` throws, so a quick release must wait for `ready`.
- The cubit sends `NetworkVoiceError` and `RetryableServerVoiceError` to `retryPending`.
  Live has no recording to retry (D20), so live failures must not take that path.
- The transport has no deadline for `ready` or for the terminal event after `finish`.
  It relies on the server's timeouts and the 15 s ping, about 30 s on a dead network.
- A failed token refresh returns null, so it reads as `notAuthenticated`, as it does
  over HTTP.
- The parser rejects unknown fields, as the fixture requires. A server adding a field
  to protocol v1 would fail live sessions into the fallback.

## Found while building

- `package:web_socket` throws from an uncatchable callback for a close code other than
  1000 or 3000–4999. The first draft closed with 1002 after a protocol violation. It
  now always closes with 1000, and a loopback test covers it.
- `FormatException.source` holds the whole frame, which can include transcript text.
  The parser keeps only the message and offset. This is the one cause not retained.
- #918's protocol test classified `startWithAuthField` as a server event, so it passed
  for the wrong reason. Client-bound cases are now separated by type. The client has no
  client-message parser: it only encodes, checked against the valid fixture cases.
- Review of step 6.i: the parser's error messages now echo only string values, and
  `protocolVersion` must be an integer.
- Server ordering, read from source: `ready` is emitted before `start` resolves, but
  only microtasks follow it, so audio sent on `ready` cannot hit the `starting` state.

## Verification

Toolchain: Flutter 3.47.8. Fixture compared with the server's: identical.

| Command | Result |
| --- | --- |
| `module_core`: `dart test` | +2541 passed |
| `module_app_ui`: `flutter test --no-pub` | +1050 passed |
| `app`: `flutter test --no-pub` | +854 passed |
| `dart analyze --fatal-infos` in `module_core`, `module_app_ui`, `app` | No issues |

`module_app_ui` and `app` changed only in tests, for the new `innerError` argument.

Real server, no credentials, on 2026-10-30:

| Probe | Result |
| --- | --- |
| `curl` upgrade to `wss://api.sesori.com/voice/realtime` with no token | 401 |
| `VoiceRepository.openRealtime` through the real connector, with the made-up token `not-a-real-token` | `NotAuthenticatedVoiceError`, inner `RealtimeVoiceUpgradeRejectedException(statusCode: 401)` |
| `GET /voice/capabilities` | Realtime enabled, protocol 1 |

Loopback tests run the real `dart:io` connector against a local server: 401, 404, 429,
a refused connection, a whole session, a close before `ready`, a protocol violation and
`cancel`.

Mutations, each failing a test: closing with 1002; allowing audio before `ready`.

## Not checked

- No authenticated session against the real server: `ready`, `transcript`, `complete`
  and real error events are proven only against the fixture and local servers. Step 12's
  matrix covers this with a dev account.
- A real 404 and 429 from production: exercised on loopback only.
- A real 1013 close: `dart:io` refuses to send it, so the loopback test uses 1011.
- No run on a phone or desktop build; all runs were `dart:io` on macOS.
