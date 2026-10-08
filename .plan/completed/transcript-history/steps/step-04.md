# Step 4 — App Deflate

Branch `transcript-history/app-deflate`. `module_core` and docs only; the
wire field and the bridge side landed in step 3 (#1876).

## Scope Delivered

- `RelayHttpApiClient._request` and `_sendViaRelay` take a required
  `acceptsDeflatedResponse` and copy it into the `RelayRequest`. `get`,
  `post`, `patch` and `delete` pass `true`; `postWithTimeout`, whose only
  caller is the attachment fetch, passes `false`. The health request in
  `connection_service.dart` keeps the default `false`.
- `RelayClient._decryptRelayMessage` inflates a plaintext that starts with
  `RelayProtocol.deflatedPlaintextMarker` with `ZLibDecoder(raw: true)` from
  byte 1; any other plaintext is read as JSON exactly as before. An inflate
  failure throws inside `_decryptRelayMessage` and is logged by the same
  `Failed to route incoming relay message` path as malformed JSON today.
- Unchanged: live events, key exchange, rekey, resume and ready messages,
  app-to-bridge requests, and attachment responses. No size threshold, no
  inflate cap, no isolate.
- Docs: `SECURITY.md` gains a Compression paragraph (order, scope, the
  accepted length-leak risk, no inflate cap); `HOW_IT_WORKS.md` one sentence
  in the phone-to-bridge section; `regression/bridge-connectivity.md` the
  required behavior, the L3 pairings and the failure signals.

## Evidence

- `client/module_core/test/api/client/relay_http_client_test.dart`: GET,
  POST, PATCH and DELETE send `acceptsDeflatedResponse: true`; the attachment
  POST sends `false`.
- `client/module_core/test/capabilities/relay/relay_client_handshake_replay_test.dart`:
  through a fake socket and real encryption, a deflated and a plain
  `RelayResponse` frame each decode to the exact response.
- Tests and analysis on code commit
  `3663f1b09ce08d7744ab71e0558e8ecdd97cfd48` (tree
  `02dad17cbd6ce12ca69b264a98b62b481a8de2d2`) with Dart 3.13.4 from
  Flutter 3.47.5-stable; this evidence commit changes no code. In
  `client/module_core/`: `dart test test/capabilities/relay test/api/client`
  (48 tests) and `dart analyze --fatal-infos` passed.
- Live relay checks on 2026-10-07, on that code, against the production
  relay with the slot-1 dev account. Throwaway test files were deleted
  afterwards.
  - **New app, new bridge** (bridge from `main` at `b573bf6454`): the app's
    `RelayClient` completed key exchange and sent the same
    `POST /session/messages` page (limit 50) with the flag on and off. Both
    returned 200 and identical bodies of 26,933 characters. The bridge's
    bandwidth log for that minute (36.17 KB) matches one deflated and one
    plain response.
  - **New app, v1.9.0 bridge** (bridge built from tag `v1.9.0`, fresh data
    directory): asking requests for `/global/health` and `/projects` returned
    200 with plain JSON bodies (67 and 67,526 bytes) that the new app read.
  - **v1.9.0 app, new bridge**: not run live. A request without the key
    decodes to `false` (step 3, `relay_request_test.dart`), and the bridge
    then sends today's plain bytes (step 3,
    `orchestrator_request_concurrency_test.dart`). The live run above sent
    the flag as `false` and got plain bytes too. Step 15's L3 matrix runs the
    released app.
- Observed sizes, from the same new bridge's routed JSON through its debug
  server, deflated with raw deflate at level 6 (the `ZLibEncoder` default),
  plus the marker byte. Dev-account data, which has small sessions:

  | Response | Raw | Deflated |
  |---|---|---|
  | `/projects` | 9,165 B | 1,259 B |
  | 27 session lists, total | 42,128 B | 11,160 B |
  | 49 first pages over 2 KB, median | 4,230 B | 1,034 B |
  | Largest first page | 26,935 B | 9,595 B |
  | 49 first pages, total | 318,401 B | 77,203 B |

  Page compression ranged from 2.6× to 7.3× (median 4.5×), in line with the
  plan's 5× estimate from the largest real session.
- No architecture review: no production class was added or moved, and the
  wire contract was set in step 3.
