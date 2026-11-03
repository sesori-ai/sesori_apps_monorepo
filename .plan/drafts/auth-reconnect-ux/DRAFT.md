# Faster Reconnect After Resume

## Status

Draft only. Tier 1 shipped: proactive reconnect on resume (#262), stale-socket
teardown, an immediate first attempt (#265) and skipping `GET /health` on
resumed reconnects that already hold the last health.

## Intent

Cut the remaining time between opening the app and seeing live data again:

- Cache the room key in memory in `RoomKeyStorage` and the access token in
  `TokenStorageService`, so a reconnect skips keychain reads.
- Let the bridge resume a client's SSE subscriptions keyed by its persistent
  room/device identity instead of the per-connection id.
- Recover when the bridge went offline before a key exchange completed.

Persisting the bridge's room key across restarts would also skip a key
exchange, but it weakens forward secrecy and needs an explicit product call
before anyone starts it.

Rejected: a shorter relay ping interval, a warm background socket, a longer
token lifetime, plaintext room-key storage and always running a full key
exchange.
