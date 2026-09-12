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
- A store-only read (`storedOnly` on `POST /session/messages`) never backfills.
  It serves the store even when that store is behind the harness and reports
  that through `awaitingHarnessSync`, so a caller that cannot wake the harness
  still receives whatever transcript exists. A session for which the bridge
  holds no row reads as an empty transcript that the harness still owes. It
  also stays off the session write queue, so another reader's slow or failing
  backfill can neither delay it nor fail it; its rows and its sync marker come
  from one database snapshot instead, so a concurrent backfill or purge lands
  wholly before or wholly after the page. Every other read keeps the
  backfilling behavior, and an older app or bridge on either side of the
  contract keeps it too.
- Session detail resolves canonical catalog metadata before the history request.
  A block does not itself withhold history: a cold blocked open reads store-only
  and renders whatever the bridge holds, with the block reported in the composer's
  place, whether or not that store is behind the harness. The chat falls back to an
  honest history-unavailable state only when there is genuinely nothing to show —
  the read fails, or it comes back empty and awaiting harness sync, so the
  transcript exists only behind the harness the user must enable. An empty store
  the bridge reports as current is an ordinary empty chat.
- A blocked load never requires harness-owned options and never asks for them
  dynamically: option discovery is served through the bridge's may-activate path,
  so a blocked open reads options cache-only rather than stalling behind a start
  attempt the block cannot complete. That cache-only read declines both the
  stale-options refresh and the legacy-bridge option fallback, which capture
  through the runtime the same way. A load that ran blocked also never opens the
  composer on that degraded catalog: eligibility arriving mid-load keeps
  interaction blocked until a strict refresh applies complete options, and a
  failure is classified against the interaction as it stands when the load lands.
- If a block arrives during reload, or metadata refresh fails, the loaded
  transcript remains and buffered session/global/part events are applied. That
  holds when the block also fails the content request: only a session with no
  rendered transcript to keep falls back to the unavailable-history state. Paging
  older messages is not gated on eligibility: a blocked chat pages store-only, the
  same way it opened, so scrolling back through a rendered transcript never waits
  on the harness. A page that fails keeps the cursor for retry.
- A blocked chat that stays on screen keeps its bridge-side view declaration. A
  resume or reconnect that released it re-declares it even though the refresh
  itself is a no-op while blocked, so the visible chat does not mark its own
  updates unread.
- On restored eligibility, the client refreshes history, options and pending input
  before interaction resumes. Failed content restoration keeps the transcript
  read-only, directs the user to reopen the chat, and does not misreport a successful
  availability check or offer a harness-status Recheck action.
- A first or externally stale backend replay adopts the latest assistant/error
  message's agent, provider, model, and available variant as the session's prompt
  defaults. The bridge persists that selection and returns it with the replay so
  the opening client cannot retain older session metadata fetched in parallel.
  A replay with no assistant/error attribution leaves existing defaults intact.
- When DeepSeek needs a first or stale backfill, its plugin calls
  `deepseek/session/history` through the one long-lived adapter connection and
  reads isolated persistence without resuming an agent or starting a scratch
  process. Native session observations preserve seeded-child inherited boundaries
  and parent lineage. Released JSONL sessions use the harness's native format
  migration; history reads leave source bytes unchanged, and resuming may create
  a new native generation. It pages at complete message boundaries, returns at
  most 100 messages per page, rejects non-progressing or over-100-page traversal, and reuses the
  shared ACP replay collector. Direct user message IDs remain exact; assistant
  IDs use the deterministic ACP projection. Known DeepSeek history metadata is
  decoded once into typed fields and validated at the API boundary; malformed
  timestamps or sub-agent metadata fail the read rather than reaching replay.
  Unrecognized additive metadata remains intact when envelopes are serialized.
  Replay replaces a delegation's generic tool part using its enclosing tool-call
  ID and the latest typed metadata in chronological page order, without reading
  or mutating live child/delegation trackers. Child-linked tiles use the same
  direct-parent message/part IDs as live updates. Ordinary parts before, between,
  and after tiles preserve their order: the first ordinary run retains its IDs,
  and later runs get deterministic unique IDs with parts referencing their owning
  envelope, so database import cannot collapse separated runs.
- Antigravity history uses standard ACP `session/load` for replay and resume-first residency for live continuation when
  the exact capability is advertised, falling back to load only when resume is unavailable. Both paths run through the
  same bounded update normalizer and isolated profile. Cold metadata recovery reads only bounded `.meta` session/cwd
  records once per live connection; it does not parse SQLite/brain content or mutate Google-owned history. Bridge/live
  directory bindings stay authoritative over recovered fallbacks.
- GitHub Copilot history uses standard ACP `session/load` on a dedicated
  short-lived connection. Replayed updates backfill the bridge transcript, while
  reopening a prior session after plugin, process, or bridge restart loads it
  before the next prompt without duplicating replay into the live stream. Sesori
  uses the public protocol and never reads Copilot credential or history files.
- Grok history uses standard ACP `session/load` on a dedicated short-lived
  connection. Historical `_x.ai/session/update` and standard `session/update`
  frames are suppressed from the live stream only during the load window;
  extension frames received outside it remain live. The plugin reads only typed
  `summary.json` and `updates.jsonl` session data under the known Grok sessions
  tree for catalog attribution and child-owned prompt context; credential and
  configuration files remain outside the API. Root replay suppresses exact
  metadata-identified `spawn_subagent` cards and inserts one child-linked tile
  at the persisted lifecycle position only when that exact child's first
  user-message run is nonblank. A blank or missing first run produces no tile;
  later runs never substitute. Child ids use the same inherited load transport
  and replay their own standard prompt/tool/text history. Replay initialization validates Grok
  identity without changing live process defaults; after load, the session's
  complete model/provider/effort selection stamps all assistant/error/tile
  envelopes. Both persisted `_x.ai/session/update` facts and late
  `_x.ai/session_notification` settlement remain inside the existing quiet drain
  and never read or mutate live child state or the event stream. Corrected
  production-composition QA after PR #1429 verified one exact root/child catalog
  link, one root tile linked to that child, and a nonblank child-owned prompt in
  child replay. Owned-phone QA reached cold read-only child history. Fixed build
  `0187bb2b10` retained one tool row but two adjacent assistant rows on each side
  across two opens and another backfill. Structural inspection found replay's
  final text nonempty while live retained an empty text part. Anchored
  reconciliation now treats that empty retained snapshot as a strict prefix
  only when replay text is nonempty and every existing window guard passes;
  fixed-build phone confirmation remains pending.
- Cursor `session/load` replaces only a fully typed completed foreground Task's
  generic card, preserving its replay-local part identity, title, output,
  attachments, and transcript order. Its native replay input uses
  `subagentType.unspecified`, distinct from the live request's
  `subagentType.custom.unspecified`; separate typed DTOs map both exact shapes
  to one closed presentation value. Background, incomplete, malformed,
  unknown, nonterminal, unmatched, and update-only facts remain generic; an
  omitted cancelled Task remains absent. Bounded production-composition QA
  passed two fresh cold loads with one equivalent completed childless tile and
  stable replay-local identity, without requiring equality with the live id.
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
  metadata authoritative. One narrower boundary case also reconciles
  atomically: a standalone tool row with one exact deterministic identity may
  anchor immediately adjacent assistant rows when the preceding row is exactly
  equal and replay's following `MessagePartText.text` strictly extends nonempty
  live text as its only difference. Both three-row windows must be uniquely
  consumed, ordered identically, and free of conflicting known timestamps;
  ambiguity, a reverse prefix, changed reasoning/parts, or unrelated text keeps
  retained rows. Other retained rows rejoin at their recorded creation time
  while preserving relative order, so a
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
- A client refresh reconciles the fetched page with the message and part events
  that arrived while the fetch was in flight instead of replacing the transcript
  wholesale: messages and parts added or changed live survive, removals seen
  live are honored, and a fetched replacement of an older part still lands. The
  agent and model shown for the session come from that installed transcript. An
  older-history page cannot start during a refresh, and one already in flight is
  dropped rather than spliced onto the refreshed transcript.
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
- Codex parent history joins a `spawn_agent` only to the exact nested
  `item_completed/SubAgentActivity` id and replaces that generic card with one
  child-linked subtask tile. Child replay first trims any copied parent prefix,
  then uses only the initial child-owned turn for plaintext `NEW_TASK` prompt
  precedence and first-terminal selection; resumed turns cannot rewrite either.
  Encrypted input keeps the exact matching spawn message and never exposes its
  envelope header. Missing or mismatched activity leaves the generic card.
- Codex rollout replay applies each `thread_rolled_back` marker to the history
  surviving before it. `num_turns` counts user turns; each removed turn includes
  its user, assistant, reasoning, tool, and terminal records, while earlier
  turns and content appended after rollback remain visible. Repeated markers
  therefore compose cumulatively. A child rollout created with `fork_turns`
  first omits the copied parent prefix from its transcript. Trimming requires
  the child's leading `thread_source == subagent` metadata followed by the
  copied parent `session_meta`; root sessions, ordinary forks, malformed
  headers, and copies whose first child-turn boundary is unresolved remain
  untouched.
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
| L1 Smoke | Headless bridge, one representative plugin: a previously synced session's transcript is served with every backend stopped, and an unsynced session's store-only read serves its stored rows flagged as awaiting harness sync without starting one. Automated client: a cold management block resolves canonical metadata, requests the transcript store-only, renders it with the block reported in the composer's place even when the store is behind the harness, and falls back to the history-unavailable state when the read fails or comes back empty and awaiting sync. |
| L2 Routine | Automated client: a live block preserves messages; a block or metadata failure during reload restores the transcript and replays buffered events; content restoration failure stays read-only with guidance to reopen the chat. Live plugin, representative: first backfill, replayed prompt-default persistence and response precedence, live capture that becomes immediately queryable, semantic identity reconciliation with ordered-context and multiplicity preservation (including normalized attachments), stale re-read ordering for retained live-only rows, and paging older messages on a transcript longer than one page. Automated OpenCode, Codex, Claude, and Pi coverage preserves available historical effort or thinking-level variants from assistant/error messages; Codex also trims only verified sub-agent copied prefixes while preserving root and ordinary-fork history, and replays rollback markers to remove reverted turn content and subtasks while retaining prior and subsequently appended turns, including cumulative rollbacks and fork-prefix boundaries; Claude also covers one stable live/replay identity for a CLI-authored API failure and suppression of its duplicate terminal result, while Pi covers active-branch attribution and file fallback. Automated Pi coverage also includes v1-v3 fallback migration, compaction visibility, hidden-context decoding, bounded tool/image mapping, content-index streaming, early tool-call metadata with the pre-0.84.3 fallback, duplicate terminal suppression, cumulative tool updates, and live/replay final parity. Automated DeepSeek coverage checks direct-parent live/replay tile identity, multiple ordered storage-safe content runs, latest metadata across pages, unbound startup errors, and live-state isolation. |
| L3 Release | Client end to end on the release-target client platform: compare cold blocked history, a live block after history renders, and restored eligibility without route reopening. Every supporting production plugin: open a long session, page back, continue a live turn, reopen cold, and confirm live and replayed content converge including tool parts and image parts where declared. Grok additionally retains its exact loaded model/effort attribution across first load, cold reopen, plugin restart, and bridge restart. |
| L4 Extended | Client end to end on macOS desktop and iOS, plus an Android variation: change availability from a second client while history is visible and while reload is in flight, page back through an older page on a blocked session whose store is behind the harness, and confirm a blocked session the bridge stored nothing for reports the block instead of an empty transcript; reconnect inside/outside replay and switch bridge identity without losing retained or buffered content. Relay integration plus owning client automated coverage, every supporting production plugin: session advanced through the backend's own CLI, plugin restart and event-stream-gap invalidation, bridge restart, client reconnect inside and outside the replay window without refresh losing concurrently finalized content, two clients on one session, a slow request beside unrelated traffic. Copilot and Grok additionally replace their ACP process, reload the same session, and converge standard replay with the bridge transcript without duplicate live delivery. |
| L5 Full | Automated and headless bridge for unreadable or partial store artifacts, interrupted backfill, and startup reconciliation; packaged or external for pagination's released-client shape; live plugin for very large transcripts. Every supporting production plugin. |

## Exploration Guidance

Vary transcript size relative to page size and how far back you page. Vary the
disruption: stop the plugin, restart the bridge, drop the client link briefly and
then beyond the replay window, or advance the session from the backend's own CLI
between reads. For Antigravity, compare load replay with resume-first live
residency, plugin/process/bridge restart, metadata fallback against bridge/live
attribution, and a malformed or absent `.meta` record. For Copilot and Grok,
compare ordinary reopen, plugin restart,
bridge restart, and forced ACP process replacement for the same imported
session. For Grok, also vary a changed loaded model/effort and confirm replay
uses the loaded tuple without replacing live defaults. Vary root versus child
sessions and content types, since tool and image parts converge by their own
rules where supported.

## Failure Signals

- A cold blocked chat hides a stored transcript behind a full-screen notice,
  renders an empty chat for a session whose history the bridge says the harness
  still owes, fails to load because harness-owned options were required, or
  reports a blocked read failure as a generic error instead of the block. A blocked
  open or a blocked page-back requests the harness-backed read. A live
  block/reload race blanks messages, loses buffered events or turns a metadata
  refresh failure into a cold shell.
- A blocked open waits on dynamic option discovery, a stale-options refresh, or
  the legacy option fallback, or lets any of them start the harness. A block that
  races a reload replaces the rendered transcript with the unavailable shell.
  A blocked load opens the composer on its degraded option catalog when eligibility
  arrives mid-load, or reports a mid-load eligibility change against the stale
  interaction the load began with. A resumed blocked chat stays undeclared and
  marks its own updates unread. Interaction returns before a successful content/options refresh. A failed restoration erases the retained
  transcript or tells the user that availability itself could not be checked. A
  blocked state other than authentication-required offers harness-status Recheck.
- A store-only read reaches the harness, waits on or fails with another reader's
  backfill, fails instead of serving what the store holds, returns parts that
  belong to a different transcript than its messages, or misreports freshness in
  either direction — a current store flagged as awaiting sync, or a stale one
  served as complete.
- Cursor replay duplicates a generic Task card and tile, changes replay-local
  identity or order across loads, or turns incomplete/background facts into a
  completed subtask.
- DeepSeek replay duplicates a generic delegation card and child tile, attributes
  a nested tile to the root instead of its direct parent, changes live child
  activity, loses latest terminal metadata across pages, or collapses/reorders
  ordinary-content runs when imported by message/part identity.

- Opening synced history starts a stopped backend, or content visible live
  disappears after a refresh or reopen.
- Reasoning still says `Thinking...` after answer or tool output has started, or
  disappears after reopening because only its empty start snapshot was retained.
- A refresh during a streaming answer drops the text streamed before it, so the
  next delta renders alone, or shows a shorter fetched part over longer live
  text.
- A message or part that arrived while a refresh was fetching disappears when
  the refresh lands, or the session's agent/model label lags behind an assistant
  message already on screen.
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
- A Codex rollback leaves reverted user, assistant, reasoning, tool, or subtask
  content visible; removes an earlier retained turn; drops content added after
  the marker; or applies a repeated marker to the original instead of already-
  rolled-back history. A Codex child transcript repeats copied parent turns, or
  a root, ordinary fork, or malformed rollout loses its own first turn because
  it resembled a copied sub-agent prefix.
- A Claude API failure appears once as ordinary assistant text and again as an
  error, or changes identity between live delivery and transcript replay. After
  a bridge restart an idle Claude root still shows a running subtask tile, or a
  busy root's live background sub-agent tile is swept to cancelled; a child
  transcript duplicates its parts after reload.
- Antigravity scans private SQLite/brain/token content, writes Google history, recovers metadata more than once per live
  connection, lets fallback attribution replace bridge/live data, retries an arbitrary resume failure through load, or
  normalizes live and replay differently.
- A Copilot restart prompts before `session/load`, duplicates replay as new live
  output, or reads private history files instead of the ACP replay boundary.
- Grok replay mutates live defaults or child state, stamps messages from an
  incomplete tuple, loses loaded effort/model attribution, duplicates replay as
  live output, prompts before cold load, reads credential/configuration files,
  merges child prompt chunks across the first non-user boundary, renders both a
  generic spawn card and subtask tile, or fabricates a tile without a child-owned
  prompt.

## Known Limitations

- A first-ever open or a stale re-read still needs the backend; if it is
  unavailable and cannot auto-start, that read fails. A store-only read avoids
  that at the cost of a possibly incomplete transcript. A store-only read also
  skips the open-tool-part sweep, because that sweep is a queued write; a tool
  tile left spinning by an abrupt bridge death stays that way until the next
  ordinary read.
- An independently owned backend can outlive a bridge restart holding state an
  inactive runtime slot cannot see, so bridge inactivity and backend
  unavailability are not fully distinguished. Agent, provider, and command
  discovery can also still start a stopped backend.
- Client session-detail refresh triggers are still under diagnosis; only the
  diagnostic logging is in place and any refresh correction is unfinished.
- Antigravity's native personal-authenticated history, cold bridge restart, retained-history import/tombstone behavior,
  and cross-target pairs remain unverified.
- The final DeepSeek phone gate did not cold-reload a root or child, open a
  read-only child transcript, restart the bridge/plugin, or test reconnect
  convergence. Existing package tests remain the evidence for replay identity
  and ordering; no client E2E history pass is claimed from scoped-stop QA.
- Grok permission denial persistence remains unverified because the unchanged
  1.0.5 runtime auto-resolved probe interactions without exposing a permission
  request. Replay therefore has no permission-outcome model; a denied generic
  spawn card may be absent. An early-cancelled child with no persisted prompt
  intentionally has no replayed tile.

## Sources

Bridge chat-history service, repository, reconcile service, history listeners,
SSE replay window, and routed request dispatch; database and audit compatibility
tests under `bridge/app/test/bridge/services/`; client session-detail load/cubit
code and focused metadata, blocking, reload-race and event-buffer tests; Pi
session process repository, storage API, and history mapper; shared ACP event mapper, turn serialization,
and session loader plus Antigravity, Copilot, Cursor, and Grok plugins and package tests; shared
pagination cursor; client detail load service and cubit.
