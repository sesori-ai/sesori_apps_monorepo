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
- A first or externally stale backend replay adopts the latest assistant/error
  message's agent, provider, model, and available variant as the session's prompt
  defaults. The bridge persists that selection and returns it with the replay so
  the opening client cannot retain older session metadata fetched in parallel.
  A replay with no assistant/error attribution leaves existing defaults intact.
- Messages visible live but absent from the backend's replay remain visible
  after a stale re-read. They rejoin at their recorded creation time while
  preserving relative order, so a catalog re-import cannot move old rows to the
  newest edge. A message a backend replay once contained is the opposite case:
  its later absence is a removal, so a re-read drops it. That is how a session
  rolled back outside Sesori — an edited message in the backend's own client,
  with no removal events reaching this bridge — stops showing the messages it
  replaced.
- Live streamed messages and parts become queryable immediately after they
  finalize, with the same visibility filtering and tool-output bound a backend
  fetch returns. Reasoning finalizes when the stream advances to assistant or
  tool output rather than remaining active for the rest of the turn, and an idle
  boundary still finalizes it when a backend omits its explicit end snapshot.
  Final text and reasoning snapshots are retained whether a backend emits them
  before or after its stream block-stop event. Clients request the latest page
  and page older messages on demand; a client predating pagination gets the full
  transcript.
- Client history uses a reversed list. Nearing its oldest edge prefetches the
  next page, one request at a time, so paging back through history rarely stops
  dead at the edge; prepended rows become visible without shifting the detached
  reading position or admitting messages and streaming changes that arrived at
  the newest edge while detached.
- After a reconnect inside the replay window, buffered events are delivered;
  after a longer gap, a refresh reconciles without losing finalized content.
  After a backend event-stream gap, that plugin's stored transcripts stay marked
  incomplete until a full re-sync; later captures do not mark them complete.
- Binary and attachment payloads are never stored inline in database tables; they
  round-trip through spill storage and still render. A slow or stuck request
  never blocks unrelated requests, other plugins, key exchange, or reconnects.
- Database rows and audit files written with the released flattened message-part
  contract remain readable after the in-memory model becomes sealed variants,
  including known part types whose variant-specific fields were omitted. Those
  omissions become temporary non-null compatibility defaults when decoded.
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
| L2 Routine | Live plugin, representative: first backfill, replayed prompt-default persistence and response precedence, live capture that becomes immediately queryable, stale re-read ordering for retained live-only rows, and paging older messages on a transcript longer than one page. Automated OpenCode coverage preserves effort variants from assistant/error messages. Automated Pi coverage: active branches, v1-v3 fallback migration, compaction visibility, hidden-context decoding, bounded tool/image mapping, content-index streaming, cumulative tool updates, and live/replay final parity. |
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
- Reasoning still says `Thinking...` after answer or tool output has started, or
  disappears after reopening because only its empty start snapshot was retained.
- A page boundary duplicates, drops, or reorders messages, or history ends early.
- Loading an older page shifts the reader's viewport, remains hidden until
  reattachment, or triggers repeated requests while one page is in flight.
- A session advanced outside Sesori keeps serving the old transcript, or stored
  transcripts are marked complete after a gap without a full re-sync.
- A stale re-read moves an older retained message to the newest edge, or keeps
  showing a message the backend removed — a rolled-back turn reappearing above
  the edited one that replaced it.
- A released database row or audit file is rejected because a known message-part
  payload omitted variant-specific data, or a decoded known variant still carries
  null variant data.
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
SSE replay window, and routed request dispatch; database and audit compatibility
tests under `bridge/app/test/bridge/services/`; Pi session process repository,
storage API, and history mapper; shared pagination cursor; client detail load
service and cubit.
