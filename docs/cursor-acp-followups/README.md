# Cursor / ACP Backend — Deferred Follow-ups

> Status: **in progress — resolved themes are marked per section**. This
> document tracks improvements that were consciously deferred during (and at
> merge time of) the review of PR #332 (`feat(bridge): add Cursor backend via
> ACP`). Each item is something a reviewer (human or bot) raised and we agreed
> was real, but out of scope for that PR — either because it needs a
> bridge-side change beyond aligning the plugin, because it needs a real
> protocol trace before it can be done safely, or because the finding landed as
> the PR merged (Themes H and I, and C5, are these last).
>
> When you pick one up, **re-verify the claim against current code first** —
> file/line references were accurate at review time and may have drifted. Every
> item cites its source PR thread so you can read the original reasoning and any
> later discussion.
>
> Related reading: `docs/parallel-plugins/CONSIDERATIONS.md` (Theme A and B here
> touch the same bridge-owned session/project attribution and `plugin_id`
> routing that parallel-plugin support will build on — design them coherently).

## Orientation

Sesori talks to Cursor through the Agent Client Protocol (ACP). `AcpPlugin`
extends `BridgeDerivedProjectsPluginApi`: the **backend does not own projects**,
the **bridge derives them** from `listAllSessions()` + stored rows. Two facts
drive most of the items below:

1. **The plugin has no database access.** Session→directory and
   session→parent-project attribution live in the bridge's Drift rows. Several
   plugin-API calls (`sendPrompt`, `getSessionMessages`, `getActiveSessionsSummary`)
   carry only a `sessionId`, so the plugin cannot self-resolve the cwd/parent a
   directory-scoped ACP backend needs.
2. **ACP/Cursor wire shapes are undocumented and allowed to drift.** Parsing is
   deliberately raw-map and fail-soft. That makes some spec-completeness work
   (Theme C) risky to do speculatively, and motivates typed boundary DTOs
   (Theme E) — but only once real traces pin the shapes down.

Cursor, the one shipping ACP backend, does **not** exercise most of the
protocol-completeness gaps because it supports the unfiltered `session/list` and
emits one assistant message per turn. The gaps matter for the *next* ACP
backend, so several items are correctness/robustness for compliant agents rather
than observed Cursor bugs. That is called out per item.

## Priority (suggested)

| #  | Theme                                                | Why it matters                                                  | Status |
|----|------------------------------------------------------|----------------------------------------------------------------|------------|
| H  | Resume-load & per-session turn robustness            | **User-facing:** stuck conversations, dropped queued prompts, replay leak | **Resolved** |
| A  | Bridge↔plugin stored-directory / attribution seam    | Real worktree flows on restart; one hook resolves three threads | **Resolved** |
| B  | Durable derive-plugin session state (bridge schema)  | Title loss + deleted sessions reappearing                       | **Resolved** |
| C  | ACP protocol completeness in the mapper / parsers    | Correctness for the next ACP backend                            | **Resolved** |
| G  | Concurrent multi-session turn attribution            | Wrong-conversation routing of `sessionId`-less requests         | **Resolved** |
| I  | Lossy `session.updated` payload on title changes     | List row loses time/summary/defaults until refresh             | **Resolved** |
| E  | Typed ACP/Cursor boundary DTOs                        | Enabler / safety net for C and F                                | Blocked on traces (Large) |
| F  | `getSessionMessages` richer failure contract         | "Broken replay" vs "empty thread" on the phone                  | **Resolved** |
| D  | Cursor decisions needing a trace / product call      | Small, but blocked on evidence                                  | D2 resolved; D1 blocked on a trace |

---

## Theme A — The bridge↔plugin stored-directory / attribution seam ✅ Resolved

**Resolved with the recommended root fix.** One root cause (a directory-scoped
derived plugin needing the bridge's stored attribution it cannot self-resolve),
one seam:

- **A1/A2 — `primeSessionDirectory` seam.** `BridgeDerivedProjectsPluginApi`
  gained `primeSessionDirectory({required String sessionId, required String
  directory})` with a no-op default. `SessionRepository` resolves
  `worktreePath ?? projectId` from the stored session row and primes the
  plugin at the top of `sendPrompt`, `sendCommand`, and the new repository
  `getSessionMessages` — so a cold restart + push-first prompt (or a
  history replay as the first plugin call) runs `session/load` in the
  session's own cwd on any agent, compliant or not, with no warm-up
  enumeration. The ACP plugin treats the prime as a hint (an agent-reported
  cwd stays authoritative) and adds it to its scan-hint set; codex spells out
  an explicit no-op (it `implements` the interface, and its global rollout
  index self-resolves). The messages handler now goes through
  `SessionRepository.getSessionMessages` (which also moved the
  plugin→shared message mapping out of the routing layer, closing a known
  Layer-1 leak).
  Sources: [#332 r3536171402](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536171402),
  [r3537566944](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3537566944)

- **A3 — worktree activity attribution.** The SSE `projects.summary` path now
  matches the REST grouping: `SessionRepository.getProjectActivitySummaries()`
  regroups a derived plugin's active sessions under the stored parent project
  (via the existing pluginId-scoped `SessionDao.getSessionProjectPaths` join)
  before mapping to the shared model; `BridgeEventMapper` became a pure
  builder over that data (its direct plugin dependency is gone) and the
  orchestrator owns fetching + building the summary event, per "Orchestrator
  Owns SSE Decisions". Project activity badges no longer vanish for worktree
  sessions.
  Source: [#332 r3536293277](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536293277)

The `plugin_id` routing datum is respected throughout (the DAO join is
pluginId-filtered; no cross-plugin resolution) — the seam stays compatible
with the parallel-plugins direction in `parallel-plugins/CONSIDERATIONS.md`.

---

## Theme B — Durable derive-plugin session state the backend won't persist ✅ Resolved

**Resolved** — schema v10 (`title` column on `sessions_table` + a new
`deleted_sessions_table`), migrated with structural + data-integrity tests per
the Drift workflow, and `plugin_id`-scoped throughout so one plugin's state
never touches another's rows (CONSIDERATIONS §2).

- **B1 — session title persistence.** The bridge now keeps the authoritative
  title copy for derived-plugin sessions: `renameSession` persists the title
  (covering both the explicit `PATCH /session/title` and the bridge's
  post-create generated title), and a title-bearing `session.updated` from the
  backend itself (ACP's `session_info_update` and codex's
  `thread/name/updated`) is captured into the stored row *before* enrichment.
  A null title removes the stored copy rather than adding durable tri-state
  semantics. Reads overlay non-null stored titles for derived
  plugins, so a rename survives enumeration even though the backend keeps
  reporting its own auto-title, while the backend's newer auto-titles still
  flow through the event capture. Native backends (OpenCode) stay fully
  authoritative for their own titles — nothing is stored or overlaid.
  Source: [#332 r3536171429](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536171429)

- **B2 — session-delete tombstone.** `SessionRepository.deleteSession`
  records a tombstone with the row removal in one transaction (written even
  for rowless-but-enumerable sessions — the delete handler no longer gates on
  a stored row), and every derived enumeration path filters tombstoned ids
  right after `listAllSessions`: session lists, project derivation, rowless
  session resolution, and project-question scoping. Because the filter runs
  upstream, `persistSessionsForProject` never re-inserts a tombstoned
  placeholder row. Tombstones are permanent (session ids are UUIDs, never
  reused) and bounded by actual deletions.
  Source: [#332 r3536293271](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536293271)

---

## Theme C — ACP protocol completeness in the mapper ✅ Resolved

**Resolved** — all five items. Each was verified against the published ACP v1
JSON schema (`zed-industries/agent-client-protocol`, `schema/v1/schema.json`)
before implementation, satisfying the "gate on evidence" requirement without a
live trace: the schema pins `ContentChunk.messageId`, the `{type: "diff"}`
tool-content variant, `available_commands_update.availableCommands`,
`sessionCapabilities.resume` + `session/resume` (documented as replaying no
history), and grouped `SessionConfigSelectOptions`. Parsing stays fail-soft
raw-map (Theme E's typed DTOs remain deferred).

- **C1 — `ContentChunk.messageId` honoured for message boundaries.** Both the
  live mapper and the replay collector group chunks by the explicit
  `messageId` when present (a change starts a new sesori message, same-id
  chunks merge back), and fall back to the previous synthesis (per-turn id
  live, role-grouping in replay) when absent — Cursor today stamps none.
  Sources: [#332 r3542170721](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3542170721),
  [r3536293262](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536293262),
  [r3542170730](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3542170730)

- **C2 — diff `content` and initial file-mutating `tool_call` emit the diff
  signal.** `_isFileMutation` also detects `content` entries of
  `type: "diff"`, and the initial `tool_call` mirrors `tool_call_update`'s
  `BridgeSseSessionDiff` emission.
  Source: [#332 r3542170739](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3542170739)

- **C3 — ACP slash commands are cached and served.** The mapper caches the
  latest `available_commands_update` payload (process-global, last update
  wins — the notification is per-session but commands are agent-global for
  every shipping backend) and `getCommands` serves it.
  Source: [#332 r3542170736](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3542170736)

- **C4 — resume-only sessions.** `sessionCapabilities.resume` is parsed, and
  an agent advertising it without `loadSession` gets `session/resume`
  (session cwd, no replay suppression — resume replays nothing) before the
  first prompt of a prior-run session, with the same residency policy as the
  load path: resident on success or permanently-unsupported RPC, transient
  failures retry on the next turn.
  Source: [#332 r3545348046](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3545348046)

- **C5 — grouped `SessionConfigSelectOptions` are flattened.**
  `CursorModelProbe.options` expands group entries (`{group, name, options}`)
  in order, so a grouped model/mode catalog surfaces every nested value for
  `getProviders` and `applyTurnSelection`.
  Source: [#332 r3545873657](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3545873657)

---

## Theme G — Concurrent multi-session turn attribution ✅ Resolved

**Resolved.** The single last-writer `_activeTurnSessionId` field was replaced
with dispatch-ordered in-flight turn tracking in `AcpPlugin`. A
`sessionId`-less server request (Cursor's `cursor/create_plan`, some question
requests) now resolves:

- **precisely** when exactly one turn is in flight — the common case, and the
  exact scenario from the review thread (A's request arriving after B's turn
  already completed now routes to A, not B);
- to the **most recent dispatch, with a logged warning**, when several turns
  are in flight — ACP carries no request→turn correlation, so this residual
  ambiguity is inherent to the protocol and now explicitly diagnosed instead
  of silent;
- to the **last dispatched turn's session** when none is in flight (unchanged
  boundary behaviour).

The base `AcpApprovalRegistry` wiring also gained the same
`activeSessionResolver` Cursor already used, so a spec-violating
`sessionId`-less permission request on any ACP harness resolves instead of
auto-cancelling. Per-session turn serialization (Theme H) removed the
same-session overlap half of the problem; covered by
`acp_turn_serialization_test.dart`.
Source: [#332 r3545348052](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3545348052)

---

## Theme H — Resume-load & per-session turn robustness ✅ Resolved

**Resolved** — all three items, designed together with Theme G as one
turn-lifecycle rework in `acp_plugin.dart`, covered by
`acp_turn_serialization_test.dart` plus the updated resume tests.

- **H1 — failed resume loads are no longer cached as resident.**
  `_ensureResident` marks a session resident only after a *successful*
  `session/load` (or when the agent lacks the capability entirely). A
  permanently unsupported load (`-32601`/`-32602` from an agent that
  advertised `loadSession` anyway) is memoized as resident, preserving the
  original no-reload-loop guarantee; transient failures (timeout, RPC hiccup)
  leave the session non-resident. Residency is ensured at *dispatch time*
  inside each serialized turn, so even a turn already queued when the load
  failed retries the load itself before prompting.
  Source: [#332 r3545873646](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3545873646)

- **H2 — prompts are serialized per session.** Each session owns a turn chain
  (`_SessionTurnState`): a prompt enqueues, marks the session busy
  immediately, and dispatches `session/prompt` only after the previous turn's
  future settles, so agents never see overlapping turns for one session. The
  session reports idle only when its *last* queued turn finishes (the old
  Set-based early-idle is gone), turn model/mode selection is applied inside
  the serialized turn (a queued prompt can no longer flip Cursor's
  process-global selection under the still-running previous turn), and
  `abortSession` drops queued-but-undispatched turns via a generation bump.
  Source: [#332 r3545873662](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3545873662)

- **H3 — resume loads no longer race each other's suppression window.**
  Resume loads run inside the session's serialized turn chain, so one
  session's loads can never overlap — each `session/load` owns its whole
  replay-suppression window (no early unsuppress mid-replay) — and the replay
  quiet-window counters are per-session so two sessions resuming concurrently
  don't reset each other's drain.
  Source: [#332 r3545873652](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3545873652)

---

## Theme I — Lossy `session.updated` payload on title changes ✅ Resolved

**Resolved at the emitter.** The plugin feeds the mapper a per-session
title/time snapshot (from every enumeration hit and from `createSession`, so
the creation race before `insertStoredSession` is covered), and the
`session_info_update` emission merges against it: the payload keeps the new
title semantics (explicit null still clears) but now carries the best-known
`time` — including the notification's own `updatedAt` when the agent sends
one — instead of nulling it, so the mobile list row keeps its sort position
even when no stored bridge row exists to enrich from.

The client's `SessionListCubit._onSessionUpdated` replace semantics were
deliberately left unchanged: a client-side merge would have to guess whether a
null field means "unknown" or "cleared", while the emitter knows exactly which
fields it has — fidelity is fixed at the source. (`summary`/`promptDefaults`/
`pullRequest`/`unseen` are bridge-enrichment fields filled from the stored row
when one exists; when none exists there is genuinely nothing to restore.)
Source: [#332 r3545873668](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3545873668)

---

## Theme D — Cursor decisions needing a trace or product call

- **D1 — plan-mode rejection routing. STILL OPEN (blocked on evidence).** For
  `cursor/create_plan`, the modal's standard Reject button calls
  `rejectQuestion`, which sends a JSON-RPC error; Cursor may expect a normal
  `{accepted: false}` response instead, so plan-mode turns could abort
  unexpectedly. Needs a real trace of Cursor's plan-response contract before
  changing — altering it blind risks breaking the accept path. This is the one
  remaining item in this document that requires a live `agent acp` trace.
  Source: [#332 r3536293286](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536293286)

- **D2 — default binary name. ✅ Resolved (product call made).** The official
  Cursor CLI docs (cursor.com/docs/cli) install and document the binary as
  `agent` — including `agent acp`, the exact ACP server mode this plugin
  drives — so the default flipped from the legacy `cursor-agent` to `agent`.
  Availability/update guidance is derived from the configured path, and legacy
  installs that only ship `cursor-agent` keep working via
  `--cursor-bin cursor-agent`.
  Source: [#332 r3536171386](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536171386)

---

## Theme E — Typed ACP/Cursor boundary DTOs — STILL OPEN (deliberately deferred)

Core ACP parsing is raw `Map`/`List` today. Replacing it with typed/freezed
boundary DTOs would restore compile-time safety in a central bridge flow —
**but only once the undocumented ACP/Cursor wire shapes are pinned down by real
traces.** Modeling drifting, undocumented payloads as freezed now would be
brittle; the individual unsafe casts were hardened fail-soft in the meantime
(`acpToolName` / `_str` guards). This is the enabler/safety net for Theme C and
Theme F.
Source: [#332 r3481369047](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3481369047)

**Affected surfaces.** `acp_content.dart`, `acp_event_mapper.dart`,
`acp_session_loader.dart`, plugin models.

---

## Theme F — `getSessionMessages` richer failure contract ✅ Resolved

**Resolved without a signature change.** The `BridgePluginApi.getSessionMessages`
contract now states that implementations MUST throw (e.g.
`PluginOperationException`) when history retrieval fails — an empty list means
a genuinely empty thread. The ACP plugin's replay catch-all stops swallowing
failures into `[]` and throws a typed `PluginOperationException` instead;
the bridge router already forwards it as a 502, and the phone already renders
a failed messages load as a full-screen retry state — so "broken replay" and
"empty thread" are distinguishable end to end with zero client changes. An
agent that doesn't advertise `loadSession` still serves `[]` (history is
genuinely unavailable, and the session must stay usable for new prompts).
This landed together with the `getSessionMessages` repository method from
Theme A.
Source: [#332 r3536171443](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536171443)
