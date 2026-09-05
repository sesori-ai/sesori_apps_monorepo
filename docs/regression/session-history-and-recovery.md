# Session History And Recovery

## Capability

The bridge supplies the durable transcript boundary. History is served from its
own store, with an owning plugin's bounded replay used as the backfill source,
paged on demand, kept honest against backend-side changes, and rejoined after
reconnect or restart.

## Required Behavior

- Reading an already-synced session serves from the bridge store and
  never starts a stopped backend. Only a first backfill or a re-read after the
  backend advanced may reach it; backfill is lazy and per session, and a session
  advanced outside Sesori is detected as stale, re-read, and re-cached.
- A first or externally stale backend replay adopts the latest assistant/error
  message's agent, provider, model, and available variant as the session's prompt
  defaults. The bridge persists that selection and returns it with the replay so
  the opening client cannot retain older session metadata fetched in parallel.
  A replay with no assistant/error attribution leaves existing defaults intact.
- When DeepSeek needs a first or stale backfill, its plugin calls
  `deepseek/session/history` through the one long-lived adapter connection and
  reads isolated persistence without resuming an agent or starting a scratch
  process. It pages at complete message boundaries, returns at most 100 messages
  per page, rejects non-progressing or over-100-page traversal, and reuses the
  shared ACP replay collector. Direct user message IDs remain exact; assistant
  IDs use the deterministic ACP projection. Known DeepSeek history metadata is
  decoded once into typed fields and validated at the API boundary; malformed
  timestamps or sub-agent metadata fail the read rather than reaching replay.
  Unrecognized additive metadata remains intact when envelopes are serialized.
- GitHub Copilot history uses standard ACP `session/load` on a dedicated
  short-lived connection. Replayed updates backfill the bridge transcript, while
  reopening a prior session after plugin, process, or bridge restart loads it
  before the next prompt without duplicating replay into the live stream. Sesori
  uses the public protocol and never reads Copilot credential or history files.
- Grok history also uses standard ACP `session/load` on a dedicated short-lived
  connection and never reads its local credential or session files. Replay
  initialization validates Grok identity without changing live process defaults;
  after load, the session's complete model/provider/effort selection is captured
  atomically and stamps replayed assistant/error messages. Cold continuation
  loads that same session before prompting after process, plugin, or bridge
  restart. Both standard `session/update` history and historical Grok
  `_x.ai/session/update` lifecycle frames remain suppressed from the live event
  stream during that load window; extension frames received outside it remain
  live.
- Messages visible live but absent from the backend's replay remain visible
  after a stale re-read. Exact identities satisfy their replay occurrences
  first and anchor neighboring order by identity even when replay revises their
  payload. Among the remaining rows, replay replaces a live row only when it has
  the same normalized message and nearest-distinct visible-message context,
  up to the remaining replay multiplicity. When either side contains repeated
  occurrences in one context, equal creation times align them even at equal
  cardinality; ambiguous rows with absent or different times remain. Conflicting
  known creation times also keep a singleton pair distinct. Equal content in
  another ordered context and additional repeated occurrences remain, while
  stored rows already stale at this import do not shape the comparison context.
  The content fingerprint ignores identity, time, agent/model attribution, and
  internal parts hidden from transcripts; alignment still uses available
  creation times as above, normalizes spilled attachments, and keeps replay
  metadata authoritative. Other retained rows
  rejoin at their recorded creation time while preserving relative order, so a
  catalog re-import cannot move old rows to the newest edge. A message a backend
  replay once contained is the opposite case: its later absence is a removal,
  so a re-read drops it. That is how a session rolled back outside Sesori — an
  edited message in the backend's own client, with no removal events reaching
  this bridge — stops showing the messages it replaced.
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
  Text or reasoning still streaming through a client refresh keeps its
  accumulated content: the refreshed transcript replaces it only when the same
  part's fetched text starts or ends with everything streamed so far (the
  latter after a reconnect that missed the part's beginning), and a later delta
  continues from that fetched text. History supplies no completion signal for
  every backend, so this is decided by content, never by timestamps or status.
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
  the turn-start race is corrected by its next live capture. An open subtask
  part is swept the same way but to `cancelled` with no error text; because a
  root stays busy while any of its sub-agents runs, a live background
  sub-agent is never swept, only one whose bridge died.
- A Codex child rollout created with `fork_turns` omits the copied parent
  prefix from the child transcript. Trimming requires the child's leading
  `thread_source == subagent` metadata followed by the copied parent
  `session_meta`; root sessions, ordinary forks, malformed headers, and copies
  whose first child-turn boundary is unresolved remain untouched.
- Claude's CLI-authored API-failure assistant frame and its terminal result
  render as one error with the persisted assistant message identity. Transcript
  records marked `isApiErrorMessage` replay as that same error rather than as a
  synthetic assistant reply, so live capture, cold open, and stale re-read do
  not show the backend text twice. Claude sub-agent transcripts
  (`<root>/subagents/agent-<agentId>.jsonl`) replay as child sessions with stable
  message and part identities, so an open child screen converges after a reload
  without duplicates; nested sub-agents replay under the root.
- Pi history follows the active `leafId` branch while retaining visible
  pre-compaction messages, applies thinking-level changes to later assistant and
  error messages on that branch, and omits compaction and branch-summary
  payloads. File fallback is allowed only for Pi's exact no-model startup
  failure, applies v1-v3 migration in memory, and never exposes persisted paths
  or execution-only prompt context to remote clients.
- Pi live assistant finals use the same message identities, parts, bounded tool
  results, terminal failures, and visible compaction card as cold replay.
  Streaming text and reasoning follow their content indices, tool progress
  replaces cumulative output, and Pi v0.84.3+ `toolcall_start` metadata
  announces a pending tool before execution begins without duplicating it at
  `toolcall_end`; older Pi output waits for the terminal tool-call metadata.
  `message_end` remains authoritative, edit/write completion invalidates the
  diff once, and only `agent_settled` marks the session idle.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, one representative plugin: a previously synced session's transcript is served with every backend stopped. |
| L2 Routine | Live plugin, representative: first backfill, replayed prompt-default persistence and response precedence, live capture that becomes immediately queryable, semantic identity reconciliation with ordered-context and multiplicity preservation (including normalized attachments), stale re-read ordering for retained live-only rows, and paging older messages on a transcript longer than one page. Automated OpenCode, Codex, Claude, and Pi coverage preserves available historical effort or thinking-level variants from assistant/error messages; Codex also trims only verified sub-agent copied prefixes while preserving root and ordinary-fork history; Claude also covers one stable live/replay identity for a CLI-authored API failure and suppression of its duplicate terminal result, while Pi covers active-branch attribution and file fallback. Automated Pi coverage also includes v1-v3 fallback migration, compaction visibility, hidden-context decoding, bounded tool/image mapping, content-index streaming, early tool-call metadata with the pre-0.84.3 fallback, duplicate terminal suppression, cumulative tool updates, and live/replay final parity. |
| L3 Release | Client end to end on the release-target client platform, every supporting production plugin: open a long session, page back, continue a live turn, reopen cold, and confirm live and replayed content converge including tool parts and image parts where declared. Grok additionally retains its exact loaded model/effort attribution across first load, cold reopen, plugin restart, and bridge restart. |
| L4 Extended | Relay integration plus owning client automated coverage, every supporting production plugin: session advanced through the backend's own CLI, plugin restart and event-stream-gap invalidation, bridge restart, client reconnect inside and outside the replay window without refresh losing concurrently finalized content, two clients on one session, a slow request beside unrelated traffic. Copilot and Grok additionally replace their ACP process, reload the same session, and converge standard replay with the bridge transcript without duplicate live delivery. |
| L5 Full | Automated and headless bridge for unreadable or partial store artifacts, interrupted backfill, and startup reconciliation; packaged or external for pagination's released-client shape; live plugin for very large transcripts. Every supporting production plugin. |

## Exploration Guidance

Vary transcript size relative to page size and how far back you page. Vary the
disruption: stop the plugin, restart the bridge, drop the client link briefly and
then beyond the replay window, or advance the session from the backend's own CLI
between reads. For Copilot and Grok, compare ordinary reopen, plugin restart,
bridge restart, and forced ACP process replacement for the same imported
session. For Grok, also vary a changed loaded model/effort and confirm replay
uses the loaded tuple without replacing live defaults. Vary root versus child
sessions and content types, since tool and image parts converge by their own
rules where supported.

## Failure Signals

- Opening synced history starts a stopped backend, or content visible live
  disappears after a refresh or reopen.
- Reasoning still says `Thinking...` after answer or tool output has started, or
  disappears after reopening because only its empty start snapshot was retained.
- A refresh during a streaming answer drops the text streamed before it, so the
  next delta renders alone, or shows a shorter fetched part over longer live
  text.
- A page boundary duplicates, drops, or reorders messages, or history ends early.
- An id-less ACP reply reuses a pre-restart fallback identity and overwrites an
  earlier answer instead of remaining distinct.
- Loading an older page shifts the reader's viewport, remains hidden until
  reattachment, or triggers repeated requests while one page is in flight.
- A session advanced outside Sesori keeps serving the old transcript, or stored
  transcripts are marked complete after a gap without a full re-sync.
- A stale re-read moves an older retained message to the newest edge, keeps a
  second copy of one visible message solely because replay changed its identity,
  collapses equal content from a different ordered context or beyond replay's
  multiplicity, or keeps showing a message the backend removed — a rolled-back
  turn reappearing above the edited one that replaced it.
- Replay reconciliation logs malformed persisted prompt, transcript, or tool
  content instead of a privacy-safe decode failure with message/session context.
- A released database row or audit file is rejected because a known message-part
  payload omitted variant-specific data, or a decoded known variant still carries
  null variant data.
- Pi falls back after an arbitrary RPC failure, shows an abandoned branch or
  summary payload, exposes a private persisted path or hidden prompt prefix, or
  rewrites backend-provided error text in mapped history.
- A Pi streamed part changes identity when finalized, a tool remains invisible
  until execution ends despite valid start metadata, a duplicate terminal tool
  event repeats the pending card or a diff invalidation, or `agent_end` marks
  the session idle before `agent_settled`.
- Buffered events are lost after a reconnect inside the replay window, or a slow
  request stalls other requests, plugins, or reconnects.
- A Codex child transcript repeats copied parent turns, or a root, ordinary fork,
  or malformed rollout loses its own first turn because it resembled a copied
  sub-agent prefix.
- A Claude API failure appears once as ordinary assistant text and again as an
  error, or changes identity between live delivery and transcript replay. After
  a bridge restart an idle Claude root still shows a running subtask tile, or a
  busy root's live background sub-agent tile is swept to cancelled; a child
  transcript duplicates its parts after reload.
- A Copilot restart prompts before `session/load`, duplicates replay as new live
  output, or reads private history files instead of the ACP replay boundary.
- Grok replay mutates live defaults during initialize, stamps messages from an
  incomplete tuple, loses loaded effort/model attribution, duplicates replay as
  live output, prompts before cold load, or reads private local files.

## Known Limitations

- A first-ever open or a stale re-read still needs the backend; if it is
  unavailable and cannot auto-start, that read fails.
- An independently owned backend can outlive a bridge restart holding state an
  inactive runtime slot cannot see, so bridge inactivity and backend
  unavailability are not fully distinguished. Agent, provider, and command
  discovery can also still start a stopped backend.
- Client session-detail refresh triggers are still under diagnosis; only the
  diagnostic logging is in place and any refresh correction is unfinished.
- Grok's sub-agent tile and child catalog are live/persisted lifecycle views;
  reconstructing the inline tile and child transcript from `session/load` is the
  separate planned child-history step, so the capability matrix remains open.

## Sources

Bridge chat-history service, repository, reconcile service, history listeners,
SSE replay window, and routed request dispatch; database and audit compatibility
tests under `bridge/app/test/bridge/services/`; Pi session process repository,
storage API, and history mapper; shared ACP event mapper, turn serialization,
and session loader plus Copilot and Grok plugins and package tests; shared
pagination cursor; client detail load service and cubit.
