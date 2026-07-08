# Cursor / ACP Backend — Deferred Follow-ups

> Status: **not scoped, not started**. This document tracks improvements that
> were consciously deferred during review of PR #332 (`feat(bridge): add Cursor
> backend via ACP`). Each item is something a reviewer (human or bot) raised and
> we agreed was real, but out of scope for that PR — either because it needs a
> bridge-side change beyond aligning the plugin, or because it needs a real
> protocol trace before it can be done safely.
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

| #  | Theme                                                | Why it matters                                                  | Rough cost |
|----|------------------------------------------------------|----------------------------------------------------------------|------------|
| A  | Bridge↔plugin stored-directory / attribution seam    | Real worktree flows on restart; one hook resolves three threads | Medium     |
| B  | Durable derive-plugin session state (bridge schema)  | Title loss + deleted sessions reappearing                       | Medium     |
| C  | ACP protocol completeness in the mapper              | Correctness for the next ACP backend                            | Medium     |
| G  | Concurrent multi-session turn attribution            | Wrong-conversation routing of `sessionId`-less requests         | Medium     |
| E  | Typed ACP/Cursor boundary DTOs                        | Enabler / safety net for C and F                                | Large      |
| F  | `getSessionMessages` richer failure contract         | "Broken replay" vs "empty thread" on the phone                  | Small–Med  |
| D  | Cursor decisions needing a trace / product call      | Small, but blocked on evidence                                  | Small      |

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

## Theme C — ACP protocol completeness in the mapper

Cursor does not exercise these; a spec-compliant ACP agent would. **Gate each on
a real trace of a driving agent** — do not add speculative branches (the live
per-chunk `messageId` variant was already declined once on exactly this YAGNI
ground). Theme E (typed DTOs) is the safety net that makes these less error-prone.

- **C1 — honor `ContentChunk.messageId` for message boundaries.** ACP v1 says a
  change in `messageId` starts a new message; the mapper groups solely by role,
  so an agent emitting multiple same-role messages in one turn collapses distinct
  ids into one Sesori message (later chunks can merge/overwrite the wrong one).
  Applies to both the **live** path (`acp_event_mapper.dart`) and the **replay**
  path (`acp_session_loader.dart` `_ensureRole`). Use chunk `messageId` when
  present; synthesize a fallback only when absent.
  Sources: [#332 r3542170721](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3542170721),
  [r3536293262](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3536293262),
  [r3542170730](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3542170730)

- **C2 — treat diff `content` and initial file-mutating `tool_call` as
  mutations.** Today `BridgeSseSessionDiff` is emitted only when a
  `tool_call_update` carries `kind` `edit`/`delete`/`move`. An agent that reports
  an edit through the standard tool `content` diff shape (`type: "diff"`), or
  sends the mutation as a complete initial `tool_call`, never triggers the SSE,
  so mobile diff/unseen refresh leaves session diff state stale. Detect `content`
  entries with `type: "diff"` and mirror the emission for initial file-mutating
  `tool_call`s.
  Source: [#332 r3542170739](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3542170739)

- **C3 — cache and serve ACP slash commands.** When an ACP agent advertises
  commands via `available_commands_update`, the mapper emits a refresh signal but
  the `/commands` endpoint (`getCommands`) always returns empty, so ACP/Cursor
  users never see backend-provided slash commands. Store the latest command
  payload from `available_commands_update` and map it in `getCommands`.
  Source: [#332 r3542170736](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3542170736)

- **C4 — resume-only sessions (`session/resume`).** `_ensureResident` only
  handles agents advertising `loadSession`; for one that advertises
  `sessionCapabilities.resume` but not `loadSession`, it marks the session
  resident without any resume RPC. After a bridge restart `_residentSessions` is
  empty, so the next prompt hits `session/prompt` against a session the new agent
  process never loaded, and resume-only agents reject it as unknown. Parse the
  resume capability and issue `session/resume` before prompting. Cursor uses the
  `loadSession` path, so no shipping backend needs this yet.
  Source: [#332 r3545348046](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3545348046)

**Affected surfaces.** `acp_event_mapper.dart`, `acp_session_loader.dart`,
`acp_plugin.dart` (command cache + `getCommands` + `_ensureResident`), plugin
models.

---

## Theme G — Concurrent multi-session turn attribution

`_dispatchPrompt` records the in-flight turn in a single process-wide
`_activeTurnSessionId`, and server-originated requests that arrive without their
own `sessionId` (Cursor's `cursor/create_plan`, some question requests) are
attributed to it. With two sessions prompting concurrently on one agent process,
the last dispatch wins: a `sessionId`-less request raised for session A after
session B's prompt was dispatched is attributed to B, so the phone shows and
answers it in the *wrong* conversation while A stays blocked. A precise fix needs
request→session correlation (or serialization of `sessionId`-less turns), not a
single last-writer field — a design change, so it is tracked here rather than
patched inline. Not observed with Cursor single-session use; it needs two
concurrent in-flight prompts on one process to bite.
Source: [#332 r3545348052](https://github.com/sesori-ai/sesori_apps_monorepo/pull/332#discussion_r3545348052)

**Affected surfaces.** `acp_plugin.dart` (`_activeTurnSessionId`,
`_dispatchPrompt`, turn lifecycle), `acp_approval_registry.dart`
(server-request → session attribution).

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
