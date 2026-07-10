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
| A  | Bridge↔plugin stored-directory / attribution seam    | Real worktree flows on restart; one hook resolves three threads | Open (Medium) |
| B  | Durable derive-plugin session state (bridge schema)  | Title loss + deleted sessions reappearing                       | Open (Medium) |
| C  | ACP protocol completeness in the mapper / parsers    | Correctness for the next ACP backend                            | **Resolved** |
| G  | Concurrent multi-session turn attribution            | Wrong-conversation routing of `sessionId`-less requests         | **Resolved** |
| I  | Lossy `session.updated` payload on title changes     | List row loses time/summary/defaults until refresh             | **Resolved** |
| E  | Typed ACP/Cursor boundary DTOs                        | Enabler / safety net for C and F                                | Blocked on traces (Large) |
| F  | `getSessionMessages` richer failure contract         | "Broken replay" vs "empty thread" on the phone                  | Open (Small–Med) |
| D  | Cursor decisions needing a trace / product call      | Small, but blocked on evidence                                  | Blocked on evidence |

---

## Theme A — The bridge↔plugin stored-directory / attribution seam

**One root cause, raised three times.** A directory-scoped derived plugin needs
the bridge's stored attribution before an operation it cannot self-resolve. The
plugin has no DB access and the call carries only a `sessionId`, so this cannot
be fixed inside the plugin.

- **A1 — resume `sendPrompt` cwd.** After a bridge restart, a prompt opened
  directly from a push/deep link for a bridge-created dedicated-worktree session
  can leave `_sessionDirectories` empty; `_directoryForSession()` falls back to
  the launch directory and `session/load` resumes against the wrong cwd (or
  fails). Partially mitigated in-plugin (`_hintedDirectories` accumulation +
  unfiltered `session/list`, which Cursor supports); the residual gap is a cold
  restart + push-first prompt on a non-compliant agent.
  Source: [#332 r3536171402](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536171402)

- **A2 — `getSessionMessages` history replay cwd.** Same warm-up gap on the
  history-replay path: an empty hint set means only the launch directory is
  scanned before `session/load` replays, so a directory-scoped agent can replay
  the wrong thread or fail. Covered for Cursor via unfiltered `session/list`.
  Source: [#332 r3537566944](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3537566944)

- **A3 — worktree activity attribution.** `getActiveSessionsSummary` reports the
  active/awaiting session under the *worktree* cwd, but the repositories fold
  that session back under the stored *parent* project row. So project activity
  badges can vanish for Cursor worktree sessions. This is the same seam viewed
  from the summary side (remap, not prime).
  Source: [#332 r3536293277](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536293277)

**Recommended root fix.**

- For A1/A2: add a no-op-default
  `primeSessionDirectory({required String sessionId, required String directory})`
  on `BridgeDerivedProjectsPluginApi`. The bridge resolves `worktreePath ??
  projectId` from the stored session row (in `SessionRepository`) and calls it
  before delegating `sendPrompt` / `getSessionMessages`. Codex inherits the
  no-op default and is unaffected.
- For A3: remap **bridge-side** in `BridgeEventMapper.buildProjectsSummaryEvent`
  / the repository layer, which today passes the plugin's id straight through.
  The join already exists (`SessionDao.getSessionProjectPaths`,
  sessions⋈projects filtered by `plugin_id`).

**Affected surfaces.** `sesori_plugin_interface` (`BridgeDerivedProjectsPluginApi`),
`sesori_plugin_codex` (no-op), `sesori_plugin_acp`, bridge `SessionRepository`
(+ a `getSessionMessages` repository method), routing/handler wiring,
`BridgeEventMapper`, bridge-app tests.

**Design note.** This is a `sesori_plugin_interface` evolution, as is
"events carry plugin identity" from `parallel-plugins/CONSIDERATIONS.md` §3.4.
If both land near each other, design the interface change once. Respect the
`plugin_id` routing datum (CONSIDERATIONS §2) — never resolve a session's
directory/parent across plugin boundaries.

---

## Theme B — Durable derive-plugin session state the backend won't persist

The bridge must hold session state that a derived backend does not. Both items
are Drift schema migrations plus reconciliation-path changes; both must keep the
existing `plugin_id` scoping so one plugin's reconcile never touches another's
rows (CONSIDERATIONS §2).

- **B1 — ACP session title persistence.** Both explicit `PATCH /session/title`
  and the post-create generated title flow through `renameSession`, which only
  echoes the title in its immediate response. The bridge session table has no
  title column and no ACP rename is performed, so the next `/session`
  enumeration loses the title. Options: a bridge-side title-override column, or
  report rename unsupported (which breaks the app's optimistic rename UX). Today
  the mobile DB is authoritative, consistent with `renameSession`'s best-effort
  contract.
  Source: [#332 r3536171429](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536171429)

- **B2 — session-delete tombstone.** Cursor does not advertise `session/delete`,
  so a deleted session reappears from `session/list`. A capability-guarded call
  wouldn't stop it. The robust fix is a bridge-side tombstone so a deleted
  derive-plugin session is filtered from enumeration after its row is removed.
  Source: [#332 r3536293271](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536293271)

**Affected surfaces.** Bridge persistence (new column/table + migration +
migration tests — see the Drift workflow in root `AGENTS.md`), `SessionDao` /
reconcile paths, `SessionRepository`, derived-session enumeration filtering.

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

Small changes, blocked on evidence rather than effort.

- **D1 — plan-mode rejection routing.** For `cursor/create_plan`, the modal's
  standard Reject button calls `rejectQuestion`, which sends a JSON-RPC error;
  Cursor may expect a normal `{accepted: false}` response instead, so plan-mode
  turns could abort unexpectedly. Needs a real trace of Cursor's plan-response
  contract before changing — altering it blind risks breaking the accept path.
  Source: [#332 r3536293286](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536293286)

- **D2 — default binary name (`cursor-agent` vs `agent`).** The PR was
  live-verified end-to-end against `cursor-agent`, and `--cursor-bin` overrides
  the default. Whether the current Cursor CLI installs `agent` or `cursor-agent`
  on PATH is a product/naming call for the maintainer before flipping the
  default.
  Source: [#332 r3536171386](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536171386)

---

## Theme E — Typed ACP/Cursor boundary DTOs

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

## Theme F — `getSessionMessages` richer failure contract

History replay currently returns a plain `List`, so a **broken replay**
(connect/init/auth/`session/load` failure) is indistinguishable from a
**genuinely empty thread** to the phone. The replay catch was widened to
`on Object catch` + `Log.w` so failures are diagnosable server-side, but the
phone still can't tell the two apart. Distinguishing them needs a
`getSessionMessages` contract change (a typed result instead of a bare list).
This pairs naturally with the `getSessionMessages` repository method from
Theme A and the typing effort in Theme E.
Source: [#332 r3536171443](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536171443)

**Affected surfaces.** Plugin-interface `getSessionMessages` signature,
`SessionRepository`, routing handler, client-side rendering of the failure
state.
