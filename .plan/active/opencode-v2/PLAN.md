# OpenCode v2 Support

## Status

- **Plan slug:** `opencode-v2`
- **Status:** Active; through Step 6.a merged, Step 6.b activity/service preparing PR 9/13.
- **Plan date:** 2026-09-25
- **Implementation base:** `main` at `fed841c2f9`
- **Trigger:** issue #1677 — OpenCode 2.0.11 on PATH fails cold start with `FormatException ... <!doctype html>`.
- **User decisions (2026-09-25):** one OpenCode plugin with a second protocol adapter (not a separate plugin, not a v1
  replacement), and the managed download moves to the latest v2.
- **Architecture review:** the first pass rejected nine layering/ownership points. All were applied as written: a v2
  Service layer, a standalone tracker, a stateless mapper, the catalog decision in the repository, layered directories,
  the factory protocol parameter, probe naming, and the D1 wording. Per the review rules, the fixes are not re-reviewed.

## Goal

A user whose `opencode` is 2.x gets the same Sesori OpenCode experience they get on 1.x, through a second protocol
adapter inside `sesori_plugin_opencode`. OpenCode 1.x on PATH or passed explicitly keeps working. The managed
runtime moves to the latest OpenCode v2.

## Evidence

Verified against source tags `v2.0.11` / `v2.0.16` and a sandboxed live `opencode serve` of both 2.0.11 and 1.18.32.

- **Auth is not the cause.** v2 honors `OPENCODE_SERVER_PASSWORD` (`OPENCODE_PASSWORD` first), which the bridge already
  sets. The issue's printed password came from a manual run without the variable.
- **The API moved.** v2 serves only `/api/*` plus `/openapi.json`. Every v1 route, including `/global/health`, falls
  through to the web UI and returns `200` HTML. The bridge's health probe therefore passes falsely, and the first JSON call
  throws.
- **1.18.32 is not a bridge.** It serves an earlier experimental `/api/*` draft. Paths overlap partly, but bodies, responses
  and event names differ, and `/api/info` and `/api/project` are missing. One client cannot target both versions.
- **Readiness:** `GET /api/info` → `{version, pid, urls, paths}`. It needs auth and returns `503` while booting.
- **Events:** `GET /api/event` is one global SSE stream of `data:` frames with a `{id, created, type, location?, data}`
  envelope, plus a 15 s heartbeat comment. It has no replay, so after reconnecting the state is re-fetched over REST.
  `session.status` / `session.idle` are defined but never emitted; busy/idle comes from `session.execution.*` and
  `GET /api/session/active`.
- **Messages are flat.** There are no parts. Assistant messages carry `content: (text | reasoning | tool)[]`, and
  streaming events are keyed by `assistantMessageID` + `ordinal` (text/reasoning) or tool `id`.
- **Questions became forms** (`/api/session/{id}/form`, `form.created|replied|cancelled`). Their fields are typed:
  string (options/custom), multiselect, number, integer, boolean and external.
- **No archive API** exists in v2. Bridge archive is best-effort and the bridge database stays authoritative
  (`BridgePlugin.archiveSession`).
- **Database:** v2 migrates `opencode.db` in place with no backup. It adds `session_v2`, keeps the v1
  `session`/`message`/`part` tables as stale copies, drops three v1 tables and empties `event`. The pre-start catalog
  reader would silently read the stale v1 `session` table from a v2-migrated database.
- **Codegen:** `tool/generate_opencode_client.dart` generates v2 REST models from `packages/protocol/openapi.json`
  (trial run: 71 models, no errors). The event union is opaque in the spec (`V2EventEncoded` is a JSON string), so v2
  events need a hand-written manifest like v1's `tool/opencode_events_v1.json`.
- **Distribution:** v2 ships as npm packages `@opencode/cli-<target>` (latest `2.0.16`). All six managed targets exist:
  darwin, linux and windows, each on arm64 and x64. Each tarball holds `package/bin/opencode[.exe]`, which
  `ArchiveRuntimeAsset.archiveBinaryName` already supports as a nested path. The GitHub "latest" release and
  `opencode.ai/install` still ship 1.18.x.

## Decisions

- **D1 — Two adapters, one plugin.**
  - **Unchanged:** the v1 Layer 2–4 stack (`OpenCodeApi`, `OpenCodeRepository`, `ActiveSessionTracker`,
    `OpenCodeService`, the v1 mappers and `OpenCodePlugin`).
  - **Shared Layer 0–1 pieces, used by both adapters:** `OpenCodeRawHttpClient`, `SseConnection` (gains an event-path
    parameter), the runtime policy probes, and the catalog database Api and repository. They change only as Steps 2 and
    4 state.
  - **Not generalized:** the v1 service, tracker and repository stay v1-only. They are ~2.3k lines bound to v1 types, so
    making them serve both protocols would be a large regression risk for working v1 users.
- **D2 — Detect by probing after start.** Once the server answers, the descriptor probes `GET /api/info`. A JSON body
  with a parseable version `>= 2.0.0` selects v2; anything else keeps v1. One mechanism covers every binary source:
  explicit, PATH, managed and attach.
- **D3 — Health for both.** The readiness probe accepts `/api/info` JSON (v2) or `/global/health` JSON (v1). An HTML
  `200` no longer counts as healthy.
- **D4 — Version bounds.**
  - v2 minimum is `2.0.11`. The descriptor refuses anything below it with `PluginStartException`.
  - The generated models and the managed runtime target `2.0.16`, or whatever v2 is latest when Step 8 lands; if so,
    the models are regenerated from that tag in the same PR.
  - `minPathVersion` stays `1.14.0`, so a v1 PATH install is still used as-is, because PATH is authoritative.
- **D5 — Catalog snapshot.** `OpenCodeCatalogRepository.read` returns `PluginCatalogSnapshotUnavailable` when the
  database contains `session_v2`, and the existing live import runs. Reading the v2 schema directly is out of scope.
- **D6 — Session JSON.** The v2 adapter emits `shared.Session` maps built from its own mapping, as Codex does. v2 shapes
  never cross the plugin boundary.
- **D7 — v2 capability gaps** (recorded in `docs/HARNESS_CAPABILITIES.md`):
  - **Archive:** a no-op on v2; Sesori's own archive still works.
  - **Form fields:** `external` fields and `when` conditions are not rendered. `number`/`integer` fields are answered
    as free text and validated before reply.
  - Parity features that v2 supports through a different route are ported, not dropped: compaction via `POST /compact`,
    child sessions via `GET /api/session?parentID=`, and worktree removal via `DELETE /api/worktree`.
- **D8 — No new transport or bridge database contract.** Clients see the same plugin-neutral models, so older and newer
  apps are unaffected.
- **D9 — Managed download moves to v2 (user decision).**
  - **One-way migration:** existing managed-runtime users are upgraded through the existing
    `needsManagedRuntimeUpgrade` path. Their first v2 launch migrates `opencode.db` in place, and there is no way back.
    Users whose own `opencode` 1.x is on PATH are unaffected, because PATH wins.
  - **Ordering:** this lands only after the v2 adapter is active (Step 7). Otherwise the bridge would install a runtime it
    cannot drive.

## Scope

**In:**
- protocol detection;
- the v2 REST client and event stream;
- v2→plugin model mapping;
- live activity tracking;
- write actions, permissions and forms;
- the catalog guard;
- managed v2 download;
- docs;
- live verification on v1 and v2.

**Out:**
- Reading the v2 database for the pre-start snapshot.
- New v2-only features: inbox/queue, revert, shell, fork.
- `opencode upgrade` v2 awareness. That belongs to the `path-runtime-authority-split` plan's updater step.
- The orphaned `serve` child from #1677, which is tracked separately if it reproduces.

## Layout

All v2 code lives under `bridge/sesori_plugin_opencode/lib/src/v2/`, one directory per layer:

| Path | Class | Layer |
|---|---|---|
| `models/openapi/*.g.dart`, `models/v2_event.g.dart` | generated DTOs | 0 |
| `models/v2_agent_names.dart` | `V2AgentNames` | 0 (immutable identity/display lookup) |
| `api/opencode_v2_api.dart` | `OpenCodeV2Api` | 1 |
| `sse/v2_event_parser.dart` | `V2EventParser` | 1 |
| `repositories/opencode_v2_repository.dart` | `OpenCodeV2Repository` | 2 |
| `repositories/opencode_v2_activity_tracker.dart` | `OpenCodeV2ActivityTracker` | 2 (standalone state) |
| `repositories/v2_model_mapper.dart` | `V2ModelMapper` | 2 (pure) |
| `repositories/v2_message_mapper.dart` | `V2MessageMapper` | 2 (pure transcript projection, reused for event parity) |
| `sse/v2_event_mapper.dart` | `V2EventMapper` | pure, stateless |
| `mappers/v2_form_answer_mapper.dart` | `V2FormAnswerMapper` | pure |
| `mappers/v2_form_answer_validator.dart` | `V2FormAnswerValidator` | pure |
| `services/opencode_v2_service.dart` | `OpenCodeV2Service` | 3 |
| `opencode_v2_plugin.dart` | `OpenCodeV2Plugin` | 4 |

## Steps

Series titles: `<emoji> [opencode-v2] <description> [step x/13]`.

Step 5 is split into 5.a catalog normalization (PR 5), 5.b transcript mapping (PR 6), and
5.c repository integration (PR 7). Step 6 splits into 6.a event projection (PR 8) and
6.b activity/service integration (PR 9); durable Steps 7–10 correspond to PRs 10–13.
The stateless event boundary and stateful refresh/summary owner are separate reviewable changes.
Review feedback exposed independent catalog/identity and transcript seams near the soft cap. The transcript
implementation through `ef5015416a` remains in #1733's published history and moves into the immediate successor;
no history rewrite, compatibility shim or new mutable owner is needed. Count all authored/generated churn.

1. **🌱 Raise plan.** Adds `PLAN.md` and `TRACKER.md` only.
2. **🌿 Detect v2 and refuse it honestly.**
   - `open_code_runtime_policy.dart`: the health probe also accepts `/api/info` JSON and rejects HTML (D3).
   - A new top-level `probeOpenCodeProtocol(...)` sits next to `probeOpenCodeHealth` and uses the same probe client
     factory. It maps `/api/info` to the sealed `OpenCodeProtocol { OpenCodeProtocolV1 | OpenCodeProtocolV2(version) }`
     in `lib/src/runtime/open_code_protocol.dart`.
   - Descriptor `start`: on v2, stop the owned runtime and throw `PluginStartException` that names the version and
     says not to downgrade, because 2.x has already migrated the database in place.
   - Health/protocol probes share a minimal generated `OpenCodeProbeResponse` DTO. Response bodies are capped at
     64 KiB before decoding; oversized v1-route HTML still permits the v2 info fallback.
   - Catalog guard (D5): `OpenCodeCatalogDatabaseApi` returns the sealed `OpenCodeCatalogDatabaseReadResult`:
     either `OpenCodeCatalogDatabaseSnapshot` with v1 rows or `OpenCodeCatalogDatabaseMigratedToV2` without rows.
     `OpenCodeCatalogRepository.read` maps the migrated variant to `PluginCatalogSnapshotUnavailable`.
   - Tests: probe, policy and catalog.
3. **⚙️ Generate v2 models.**
   - The generator gains a `--surface <file>` option; v1 keeps its default.
   - Add `tool/opencode_v2_surface.json` (≈25 operations) and generated `lib/src/v2/models/openapi/*.g.dart` from the
     target tag.
   - Add `tool/opencode_events_v2.json` (session lifecycle, execution, step, text, reasoning, tool, retry, compaction,
     permission, form and project events) and generated `lib/src/v2/models/v2_event.g.dart`, via a `--manifest/--out`
     option on `generate_sse_events.dart`.
   - Round-trip tests for representative models and events. Most churn is generated.
4. **⚙️ v2 API and event stream.**
   - `OpenCodeV2Api` over the shared `OpenCodeRawHttpClient`: every surface operation, with `location[directory]` query
     or header, `{data}`/`{location, data}` unwrapping, and cursor paging for sessions and messages.
   - `SseConnection` takes its event path as a parameter.
   - `V2EventParser` decodes the envelope; unknown types are logged and dropped.
   - Tests: `MockClient` HTTP tests and parser tests.
5.a. **⚙️ v2 catalog normalization (PR 5/12).**
   - `V2ModelMapper`: project and session (`location.directory`, `time`, `parentID`) → plugin models and
     `shared.Session`; agents, providers/models/variants, commands and form/permission presentation.
   - `V2AgentNames`: immutable catalog lookup keeps display names in selections and session defaults,
     with reverse translation to native IDs inside the plugin. No cache or mutable lifecycle owner.
   - Tests: native 2.0.16 catalog/session fixtures and source-derived form projection cases.
5.b. **🚧 v2 transcript mapping (PR 6/12).**
   - Restore the transcript mapper and typed tool-display DTOs preserved in `ef5015416a`.
   - Flat v2 messages → existing plugin message/part models. Text/reasoning retain `<messageID>:<ordinal>`;
     tools retain their native tool IDs. Apply the catalog's agent-name lookup at projection boundaries.
   - Tool state: `streaming` → pending, `running`, `completed`, `error`; shell-command extraction is gated
     on recognized shell tools. Preserve bounded attachments and native errors without payload logging.
   - Include assistant retry metadata (`<messageID>:retry`, independent of content growth) and
     system-authored agent-switch notices (`<messageID>:0`) raised during #1733 review.
   - Source-derived transcript tests; no caches, timers, persistence or lifecycle owners.
5.c. **🚧 v2 repository integration (PR 7/12).**
   - `OpenCodeV2Repository` (Api → mapped plugin models) reads projects, sessions, children, messages, agents, models
     with variants and commands. Root paging uses the native project-ID filter across worktrees; canonical project
     identity stays separate from an opened directory. Project activity comes only from root sessions.
   - Active IDs are global; pending permission/form reads remain directory-scoped and retain native constraints
     for the tracker/validator. The repository exposes every write Step 7 needs:
     - create, prompt, command, interrupt;
     - project/session rename, session delete, worktree delete;
     - agent/model selection, compact, synthetic message;
     - permission reply, form reply/cancel.
   - Compose the immutable agent-name lookup from the target directory's catalog for readable selections and
     native write IDs; reject stale explicit selections before dispatch. Omitted selections retain native defaults.
   - Complexity budget: three final injected dependencies, no mutable runtime state, caches, timers or new
     persistence. No obsolete production mechanism is replaced; v1 and the v2 startup refusal remain intact.
   - Tests: repository tests over a fake `OpenCodeV2Api`, using preceding fixtures, plus scoped root-paging HTTP tests.
6.a. **🚧 v2 live-event projection.**
   - `V2EventMapper` stays stateless, reusing the transcript's part/retry identities and tool/attachment policies.
     Directly map text/reasoning deltas, tool start, retry/status, permission/form and agent/synthetic notices.
   - Add `session.inbox.*`, `session.synthetic`, `session.agent.selected` and typed interrupt reasons to the manifest.
     Inbox enqueue is not a user transcript message; delivery is. Queue controls remain out of scope.
   - Add single-message and latest-by-type REST reads to API/repository. Native tool terminal events omit the name/input;
     compaction completion omits the message ID. Hydrate those from committed native projections, not a second transcript
     cache. Native bus projection commits before SSE publication (`core/src/bus.ts` and `session/projector.ts`).
   - Hydrated tool events emit only their named tool part; assistant terminal snapshots emit only the header/retry state,
     never replaying unrelated text into a stream of later deltas. Compaction uses the latest native compaction row.
   - Session-event projection receives the authoritative shared session value from the later service. No nullable
     multi-purpose enrichment container, mutable name cache, stream subscription or lifecycle owner is introduced.
   - Tests: parser/mapper sequences plus targeted REST/repository reads. V2 remains inactive.
6.b. **🚧 v2 activity and service integration.**
   - `OpenCodeV2ActivityTracker` is standalone, with no Api or Repository dependency. It owns session metadata for
     hierarchy/project attribution, active/retry states, native pending permissions/forms, and baseline trust.
     It exposes `seed(...)`, `apply(event)` and `reset()`; deletion can use previously observed session metadata.
   - `OpenCodeV2Service` owns cold start and reconnect re-fetch through the repository, seeds the tracker, resolves
     event enrichments and uses the stateless mapper. It builds activity summaries and never touches `OpenCodeV2Api`.
   - Seed session metadata globally without agent-catalog lookups, then read pending inputs for observed session
     directories and active IDs globally. Keep useful state on refresh failure, but preserve unknown work state until
     a complete baseline. Reuse the existing shared session value; do not copy v1's instance/alias registries.
   - Tests: event-sequence tests for tracker state, and service tests over a fake repository.
7. **🚧 v2 writes and activation.**
   - `OpenCodeV2Service` gains the write flows:
     - create + first prompt; prompt with files; command;
     - resolve the existing `parentSessionId` creation contract before activation: native `POST /api/session` has
       no parent field; inspect fork/import semantics rather than silently creating an unrelated root session;
     - interrupt of the root plus active children;
     - rename, delete, worktree delete;
     - compaction (guidance `synthetic` message first, then `compact`);
     - session options from agents, models and commands;
     - permission reply; form reply/cancel via `V2FormAnswerMapper` and `V2FormAnswerValidator`;
     - archive as a no-op (D7).
   - `OpenCodeV2Plugin` implements `OpenCodeManagedApi` and delegates every operation to `OpenCodeV2Service`. It
     composes `SseConnection → V2EventParser → OpenCodeV2Service → V2EventMapper → event buffer` and holds no business
     logic. Extend the existing SSE callback to await enrichment before the next frame/reconnect refresh; keep one
     transport owner rather than adding a separate queue, and drop late publication after plugin disposal.
   - Activation:
     - `OpenCodeManagedApiFactory` gains `required OpenCodeProtocol protocol`.
     - The descriptor's `start` runs `probeOpenCodeProtocol`, refuses a v2 below `2.0.11` with `PluginStartException`
       (the D4 check stays in the descriptor), and passes the protocol to `_defaultBuildApi`.
     - `_defaultBuildApi` switches on the protocol to construct `OpenCodePlugin` or `OpenCodeV2Plugin`.
     - The Step 2 blanket refusal is removed.
     - `--no-auto-start` with no server at start (`handle == null`) has no protocol to probe. Decide how the
       server that appears later gets its adapter: probe on late connect, or require a bridge restart. Today
       that path silently builds the v1 adapter.
   - Tests: a plugin test against a loopback fake v2 server, as the v1 impl test does.
8. **🌿 Managed runtime on v2 (D9).**
   - `OpenCodeRuntimeManifest`:
     - `targetVersion` becomes the latest v2;
     - six `ArchiveRuntimeAsset`s point at `cli-<target>-<version>.tgz` (`ArchiveFormat.tarGz`), with
       `archiveBinaryName: package/bin/opencode[.exe]`, `RuntimeArchiveLayout.singleBinary`, and sha256 computed from
       the downloaded tarballs;
     - `downloadUrlFor` returns `https://registry.npmjs.org/@opencode/cli-<target>/-/cli-<target>-<version>.tgz`.
   - The class doc's bump procedure is updated for npm.
   - Tests: manifest tests, plus an install-service test extracting a nested-path tarball if none exists.
9. **🌱 Reconcile docs.**
   - `docs/HARNESS_CAPABILITIES.md`: v2 row, D7 gaps and the managed v2 runtime.
   - `docs/regression/plugin-setup-and-lifecycle.md`: v2 detection, bounds, health and the managed target.
   - `docs/regression/plugin-runtime-installation.md`: npm asset source.
   - `docs/regression/projects-and-sessions.md`: catalog guard.
   - Touch `session-turns.md`, `session-history-and-recovery.md` and `session-creation-and-options.md` only where v2
     behavior differs.
10. **🌱 Run coverage and retire.** Run the matrix below, record the results, and move the plan to
    `.plan/completed/`.

## Verification Matrix

Highest level: **L3** for the OpenCode plugin, on macOS arm64, with a real provider on a dev account.

| Runtime | Source | Cases |
|---|---|---|
| OpenCode 2.0.x (latest) | managed (fresh install and upgrade from 1.18.32) | install; cold start; project/session list; prompt with streaming; attachment; command; abort; permission; form with multiple fields; compaction; rename/delete; archive; reconnect re-fetch; catalog fallback on a migrated database |
| OpenCode 1.18.32 | PATH | cold start; project/session list; prompt with streaming; attachment; command; abort; permission; question; compaction; rename/delete; archive |
| OpenCode 2.0.x | `--opencode-no-auto-start` attach | detection and the list/prompt heartbeat |

Linux and Windows are covered by CI unit tests only; the protocol code is platform-neutral. Reducing the matrix
requires the user's explicit acceptance recorded here.

## Complexity Budget

- **New in-memory mutable state:** only `OpenCodeV2ActivityTracker`: four maps (session metadata, active/retry state,
  pending permissions, pending forms) and baseline trust. Metadata is required to attribute active children and pending
  input to the correct root/project and to represent deletions after native rows disappear. Baseline trust prevents a
  failed refresh from claiming idle. No transcript, tool-input, agent-name or inbox cache is added.
- **Stateless:** `V2EventMapper`, because part ids are derived deterministically.
- **Not added:** persistence, protocol switching at runtime, dual-protocol generic services, or event replay through
  `/session/{id}/log`. Reconnect re-fetches over REST, as v1 does.

## Risks

- **Upstream v2 churn** (fast cadence): mitigated by the minimum/target pins, generated models, and unknown events being
  dropped instead of failing.
- **Flat-content → part mapping fidelity** for tool metadata and diffs. Accepted: tool output and state are mapped;
  rare metadata-only fields may not render.
- **Managed users migrate one-way** to a v2 database (D9, user-accepted).
- **Evidence level:** protocol facts include a live sandbox probe and Step 5 native catalog/session REST fixtures.
  Transcript/form examples and streaming event order remain source-derived; native turn/event parity still requires
  the later native-fixture and L3 gates.

## Cleanup Assessment

No v1 code becomes obsolete, because v1 stays supported on PATH and through explicit binaries. Step 2's refusal branch
is removed by Step 7. The v1.18.32 GitHub asset pins are replaced in Step 8. No other cleanup was found.
