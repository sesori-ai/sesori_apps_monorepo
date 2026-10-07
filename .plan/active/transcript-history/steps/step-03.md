# Step 3 — Bridge Deflate

Branch `transcript-history/bridge-deflate`. Bridge and `sesori_shared` only;
no app asks yet, so every released and current app still receives plain
responses.

## Scope Delivered

- `RelayRequest.acceptsDeflatedResponse`, `@Default(false)`, with the
  `COMPATIBILITY 2026-10-07 (v1.9.1)` marker. Generated Freezed and JSON code
  regenerated with `build_runner`.
- `RelayProtocol.deflatedPlaintextMarker = 0x00`, documenting the plaintext
  layout. `framing.dart` and `protocolVersion` are unchanged.
- `bridge/app/lib/src/foundation/relay_plaintext_codec.dart`:
  `encodeRelayPlaintext({json, deflate})` returns the JSON unchanged, or the
  marker followed by `ZLibEncoder(raw: true)` output.
- The orchestrator passes `req.acceptsDeflatedResponse` through
  `_completeRoutedRequest`, `_deliverRoutedResponse` and
  `_encryptRelayMessage`. `_completeShutdownRejection` passes `false`.
  `BandwidthTracker` receives the framed plaintext length, and the verbose log
  prints both that length and the JSON length.
- Unchanged: SSE frames, key exchange, rekey, resume and ready messages, and
  app-to-bridge requests.
- Docs: none. The plan assigns `SECURITY.md`, `HOW_IT_WORKS.md` and
  `bridge-connectivity.md` to step 4, when an app first asks.

## Evidence

- `shared/sesori_shared/test/protocol/relay_request_test.dart`: a request
  without the key decodes to `false` (the v1.9.0 app shape), and the key
  round-trips.
- `bridge/app/test/foundation/relay_plaintext_codec_test.dart`: plain output
  is the input; deflated output starts with `0x00`, is smaller, and inflates
  byte-exactly to the input.
- `bridge/app/test/bridge/orchestrator_request_concurrency_test.dart`: through
  a real relay socket and encryption, an asking request's decrypted plaintext
  starts with the marker and inflates to its `RelayResponse`; a non-asking
  request's starts with `{` as today.
- `dart test` on those files plus `test/bridge/routing` passed;
  `dart analyze --fatal-infos` is clean for `sesori_shared` and `bridge/app`.
- `architecture-implementation-review` (sub-agent, first pass): approved, no
  findings.
- The relay compatibility pairings are checked in step 4, once the app can
  ask. A v1.9.0 bridge ignoring the key was verified in the plan from its
  generated `messages.g.dart`.
