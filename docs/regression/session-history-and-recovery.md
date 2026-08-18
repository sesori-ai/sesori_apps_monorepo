# Session History And Recovery

## Capability

The bridge is the durable source of a session's transcript. History is served
from its own store, paged on demand, kept honest against backend-side changes,
and rejoined after a client reconnect, plugin restart, or bridge restart.

## Required Behavior

- Reading history of an already-synced session serves from the bridge store and
  never starts a stopped backend. Only a first backfill or a re-read after the
  backend advanced may reach it; backfill is lazy and per session, and a session
  advanced outside Sesori is detected as stale, re-read, and re-cached.
- Live streamed messages and parts become queryable immediately after they
  finalize, with the same visibility filtering and tool-output bound a backend
  fetch returns. Clients request the latest page and page older messages on
  demand; a client predating pagination gets the full transcript.
- After a reconnect inside the replay window, buffered events are delivered;
  after a longer gap, a refresh reconciles without losing finalized content.
  After a backend event-stream gap, that plugin's stored transcripts stay marked
  incomplete until a full re-sync; later captures do not mark them complete.
- Binary and attachment payloads are never stored inline in database tables; they
  round-trip through spill storage and still render. A slow or stuck request
  never blocks unrelated requests, other plugins, key exchange, or reconnects.
- A tool part stranded in `pending`/`running` after its turn ended is finalized
  to a terminal error, for every backend. The sweep runs when the session goes
  idle (finalized parts are also delivered live as part updates) and on a
  history read whose page still holds an open tool part while the session is
  not currently busy — whether the page came from a backfill or from a store
  kept fresh across an abrupt bridge death — including when the status is
  unobservable, since a stopped backend hosts no live tool. Finalization never
  advances the session's freshness marks, and a genuinely running tool swept by
  the turn-start race is corrected by its next live capture.
- Pi history follows the active `leafId` branch while retaining visible
  pre-compaction messages and omitting compaction and branch-summary payloads.
  File fallback is allowed only for Pi's exact no-model startup failure, applies
  v1-v3 migration in memory, and never exposes persisted paths or execution-only
  prompt context to remote clients.
- Pi live assistant finals use the same message identities, parts, bounded tool
  results, terminal failures, and visible compaction card as cold replay.
  Streaming text and reasoning follow their content indices, tool progress
  replaces cumulative output, edit/write completion invalidates the diff once,
  and only `agent_settled` marks the session idle.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, one representative plugin: a previously synced session's transcript is served with every backend stopped. |
| L2 Routine | Live plugin, representative: first backfill, live capture that becomes immediately queryable, and paging older messages on a transcript longer than one page. Automated Pi coverage: active branches, v1-v3 fallback migration, compaction visibility, hidden-context decoding, bounded tool/image mapping, content-index streaming, cumulative tool updates, and live/replay final parity. |
| L3 Release | Client end to end on the release-target client platform, every supporting production plugin: open a long session, page back, continue a live turn, reopen cold, and confirm live and replayed content converge including tool and image parts. |
| L4 Extended | Relay integration plus owning client automated coverage, every supporting production plugin: session advanced through the backend's own CLI, plugin restart and event-stream-gap invalidation, bridge restart, client reconnect inside and outside the replay window without refresh losing concurrently finalized content, two clients on one session, a slow request beside unrelated traffic. |
| L5 Full | Automated and headless bridge for unreadable or partial store artifacts, interrupted backfill, and startup reconciliation; packaged or external for pagination's released-client shape; live plugin for very large transcripts. Every supporting production plugin. |

## Exploration Guidance

Vary transcript size relative to page size and how far back you page. Vary the
disruption: stop the plugin, restart the bridge, drop the client link briefly and
then beyond the replay window, or advance the session from the backend's own CLI
between reads. Vary root versus child sessions and content types, since tool and
image parts converge by their own rules.

## Failure Signals

- Opening a synced session starts a stopped backend, or content visible live
  disappears after a refresh or reopen.
- A page boundary duplicates, drops, or reorders messages, or history ends early.
- A session advanced outside Sesori keeps serving the old transcript, or stored
  transcripts are marked complete after a gap without a full re-sync.
- Pi falls back after an arbitrary RPC failure, shows an abandoned branch or
  summary payload, or exposes a private path, raw backend error, or hidden prompt
  prefix in mapped history.
- A Pi streamed part changes identity when finalized, cumulative tool output is
  appended, a duplicate terminal tool event repeats a diff invalidation, or
  `agent_end` marks the session idle before `agent_settled`.
- Buffered events are lost after a reconnect inside the replay window, or a slow
  request stalls other requests, plugins, or reconnects.

## Known Limitations

- A first-ever open or a stale re-read still needs the backend; if it is
  unavailable and cannot auto-start, that read fails.
- An independently owned backend can outlive a bridge restart holding state an
  inactive runtime slot cannot see, so bridge inactivity and backend
  unavailability are not fully distinguished. Agent, provider, and command
  discovery can also still start a stopped backend.
- Client session-detail refresh triggers are still under diagnosis; only the
  diagnostic logging is in place and any refresh correction is unfinished.

## Sources

Bridge chat-history service, repository, reconcile service, history listeners,
SSE replay window, and routed request dispatch; Pi session process repository,
storage API, and history mapper; shared pagination cursor; client detail load
service and cubit.
