# Periodic cleanup

Status: proposed scope; investigation/planning requested, implementation scope
acceptance pending. Plan PR: [#1295](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1295).
Baseline: `480d82f090`. Date: 2026-09-04. Slug: `periodic-cleanup`.

## Goal, evidence, and scope

Remove code that exists because ownership is unclear or obsolete consumers are
still modeled. Prioritize demonstrated reliability failures and needless
production work over cosmetic extraction. The [audit](../../../docs/cleanup-audit-2026-09-04.md)
contains caller traces, source links, evidence limits, and deferred candidates;
[evidence](evidence/README.md) contains three executed diagnostic reproductions.
This plan consolidates [#1296](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1296)
at the user's request. The [consolidation ledger](CONSOLIDATION.md) maps every
source step to its retained, completed, or deferred disposition. The fixed
proposed series is now **25 steps**; no implementation step has opened, so this
replaces the earlier fourteen-step denominator everywhere.

Merged baseline update: [#1294](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1294),
`da2e9eeb47` (2026-09-04), adds `SessionSelectionCalculator` and its regression
coverage. Implementation rebases on that commit or newer main. Steps 2–3 retain
the calculator calls now present in `_doSilentRefresh`; they alter transcript
ownership, not selection policy. The recorded diagnostic results remain results
against `480d82f090`, not claimed reruns against the merged commit. Source review
of #1294 confirms the buffer clear and wholesale message replacement remain.

Deliver two transcript fixes; deletion of unused production APIs/state; removal
of unused options-cache metadata and its recovery branch; typed internal
status/message events; narrower database projections; removal of unused backend
event forwarding; and three bounded duplication cleanups. No backend upgrades,
new feature framework, synchronization protocol, cache scheduler, generic event
bus, or broad cubit/orchestrator rewrite.

The source changes are substantial in aggregate: approximately 8,000–15,000 changed implementation/test/generated lines,
plus roughly 3,000 historical-document deletions, across twenty-two implementation
or cleanup PRs. The user explicitly authorized consolidating useful findings
and closing #1296. That is authorization for this plan update; executing the
refactor series remains a separate scope decision before step 2. The root
AGENTS.md requires approval before a considerable refactor.
Remain in the dedicated worktree. Do not create another worktree or working directory.

## Implementation contracts

### 2. Keep the streaming accumulator across silent refresh

Owner: existing `SessionDetailCubit` and `StreamingTextBuffer`. Remove the
unconditional `_streamingBuffer.clear()` when a silent snapshot is installed.
Emit its current snapshot and keep the existing part-finalization, deletion,
session-load, and close paths responsible for clearing retired text. Do not
retain completed parts indefinitely or change the streaming timer.

Promote the `before-` / refresh / `after` diagnostic into a focused regression.
Cover a finalized part arriving during reload, normal completion, removal, and
closing during reload. Expected result: the next delta retains the prefix;
no database/wire change and no new mutable state.

### 3. Reconcile fetched messages with changes received during reload

Owner: `SessionDetailCubit._doSilentRefresh`, with a pure typed helper alongside
existing `session_detail_resolvers.dart` functions. Capture immutable messages
at reload start; reconcile that `before` value, the latest `live` messages and
`fetched` messages at completion. No event journal or new state owner.

Use message and part IDs for matching, and value equality for changes:

- Start with fetched messages in their supplied order. A message present before
  and removed from live is omitted. A live message added since before is
  included even if the fetched page does not yet contain it. A changed live
  message omitted by the fetched page is retained to avoid losing that change.
- For a matching message, take live envelope metadata only when it differs
  from before; otherwise use fetched metadata. Reconcile its parts the same
  way: retain fetched-only parts, overlay live additions/changes, and remove
  parts present before but removed from live. A changed envelope must not
  replace the whole fetched part list. Preserve fetched part order and append
  genuinely new live parts in their existing order.
- Use the existing message insertion ordering for live-only messages (extract
  the existing helper into the resolver file if necessary, without a second
  sorting policy). Collections and lookup maps are invocation-local values;
  add no persistent per-message versions or mutable cubit fields.

The required diagnostic result includes BOTH the fetched replacement of the
preexisting part and the new live part. Keeping the entire old live list would
fail that case and is not an acceptable implementation. Deltas remain in the
existing accumulator per step 2 and are never replayed as part of reconciliation.
Queue side effects are not replayed; they continue at their existing live and
snapshot owners. Install the reconciled transcript before declaring refresh
applied, consuming the coalesced stale signal, or reasserting the session view.

Keep pagination coherent using existing state: advance `_transcriptGeneration`
at silent-refresh start, clear `isLoadingOlderMessages` in that start emission,
and make `loadOlderMessages` a no-op while `isRefreshing`. Thus a previously
started page cannot join a refreshed transcript, and historical page additions
cannot be mistaken for new live messages. Existing history remains visible on
refresh failure; reset its cursor to the fetched newest page only on successful
refresh. Preserve deferred-part sequencing/discard and drain against the actual
installed messages; do not discard an in-flight part just because its envelope
also exists in fetched data. Closure and connection-generation checks remain.

Evidence is an ordinary intended-refresh/live-event interleaving reproduced by
the diagnostic. This is reconciliation of observable changes, not a globally
versioned snapshot: a create-and-delete cycle wholly within the fetch and absent
from both before/live cannot be inferred, and equal values do not reveal unseen
history. Accept those unobserved provenance limits without epochs/journals or
protocol changes. Likewise this does not solve separate question/status/child
snapshot groups. Those are source-level concerns retained in the audit.

Verify the diagnostic unchanged, added/updated/removed messages and parts,
snapshot-only missed messages, envelope-plus-part independence, next delta and
finalization, pagination overlap/failure, closure, connection replacement, and
queued stale-signal consumption only after the reconciled snapshot is installed.
No new wire/database model, retry schedule, timer, or lifecycle owner.

### 4. Delete obsolete production paths and the unread child index

Owners: `SessionRepository` and `SessionEventTracker`. Delete
`insertStoredSession`, whose only callers are tests/fakes. Use an app test
fixture that inserts through DAOs for setup; test the actual `createSession` /
`upsertObservedSessionBinding` path for transactional defaults/project/binding
behavior. Delete obsolete placeholder-orphan repair assertions rather than
moving that unused repair into production. This is no schema/data deletion.

Delete tracker `takeChildren`, `takeTranslations`, `takeReady`, `_children`, and
its maintenance. Keep `_sessions`, `_translations`, insertion order, generation
checks, bounded eviction and `takeRoot`/`takeNextReady`, used by the service.
Exercise deferred parent/child binding, event order, eviction, and generation
replacement via the production drain API. A test-only convenience API is not a
reason to keep state in production. Remove fake overrides of the deleted API.

### 5. Remove persisted completeness and the recovery path it creates

Owners: `SessionOptionsCacheTable` / DAO (persistence), repository (decode and
capture), existing service (replacement policy). Remove completeness from the
cache row and `SessionOptionsCacheEntry`; retain it on fresh capture observation
and `_canReplace`. The persisted value has no policy reader.

The current schema is 14 and the table exists in public v1.8.2. Add the next
Drift migration using the repository's normal schema/generator workflow; do not
edit generated/historical schema files. Rebuild just the options-cache table
with explicit retained-column mapping, omitting completeness, preserving valid
rows/revisions and all other tables. Exercise upgrade of a row with an unknown
old completeness string: migration must not deserialize the removed enum.
This addresses the diagnostic by removing its failure source.

After removal, `getRow` filters the remaining enum scope with the caller's known
scope. Decode failures in agents/providers/commands occur after a revision is
available. Make `SessionOptionsCacheDecodingException.revision` required and
non-null, remove the pre-row `ArgumentError` conversion and unknown-revision
retry branch. Keep original typed cause/stack and log recovered decoding failure
with plugin/operation context. Retain conditional deletion and existing
replacement conflict handling for revision-known payload failures.

Do not remove CAS, invalidation epochs, plugin-generation checks, or path
validation in this PR. Cache-only expiry reads and stale-send invalidation are
real writers; a broader single-writer claim has not been proved. Expected
user-visible result: old unused metadata cannot prevent discovery; no change to
fresh completeness policy. Database impact is one column removal, not a session
migration or defaults reset. Fresh install and schema-14 upgrade tests required.

### 6–7. Keep status and message payloads typed inside the bridge

Owner: `sesori_plugin_interface` defines backend-neutral observations; plugins
parse external data; bridge repository mappers translate to shared models.
Change one event kind across all producers and consumers in each PR:

- Step 6: `BridgeSseSessionStatus.status` becomes `PluginSessionStatus`.
  Producers emit their existing typed status without `.toJson()`. Repository
  normalization uses existing `toSharedSessionStatus`; the SSE mapper receives
  the resulting shared status and constructs `SesoriSseEvent.sessionStatus`.
  Preserve retry attempt/message/next values and
  terminal-handoff semantics. Remove only newly obsolete conversions.
- Step 7: `BridgeSseMessageUpdated.info` becomes `PluginMessage`. Producers emit
  typed messages; `SessionEventMapper` reads/remaps `sessionID` via typed
  `copyWith`. Repository normalization calls existing
  `toSharedMessage(sessionId: ...)` once; `ChatHistoryListener` and the SSE
  mapper consume that same shared message, so stored and delivered values agree.
  Remove internal JSON parsing/serialization and the impossible decode/drop
  branch from message capture. Verify user/assistant/error metadata, sender,
  prompt ID, time, provider/model, and stable IDs against existing wire fixtures.

Introduce a narrow app-owned sealed payload in
`bridge/app/lib/src/foundation/models/normalized_bridge_event.dart`:
`NormalizedStatusEvent` carries required stable session ID and shared
`SessionStatus`; `NormalizedMessageEvent` carries required shared `Message`;
`NormalizedOtherEvent` carries the remaining already-ID-normalized
`BridgeSseEvent`; `NormalizedTerminalHandoff` carries a required normalized
payload and preserves the existing terminal wrapper's meaning. Add the status
variant/seam in step 6 and the message variant in step 7. This is an incremental
replacement of the existing normalized stream's payload, not another stream.

`SessionEventMapper` owns conversion into these values using repository mapping
extensions. `SessionEventService` exposes that final conversion after its
identity/enrichment work; the existing dispatcher invokes it only after
publication/generation checks and emits it in the existing
`NormalizedSourcedBridgeEvent` record. Local and binding-commit events use that
same final conversion. Preserve existing metadata, per-plugin ordering,
allow-during-stop, handoff acknowledgment and error paths. No new subscription,
queue, timer, callback, nullable parallel payload or side-channel cache.

Orchestrator handles normalized message/status/terminal cases explicitly and
routes the remaining event case through its existing behavior. The history
listener consumes the normalized `Message` directly. `BridgeEventMapper`
constructs public message/status events from the shared values; it does not
import or call repository mapper extensions. Existing legacy mapping for
unchanged kinds is not widened. The remaining-event wrapper is constructed only
by the exhaustive normalizer for kinds not yet converted; it is not a public
fallback path for message/status or an internal JSON compatibility shim.
Avoid adding guards/registries for impossible callers of that internal owner.
Do not clone every plugin event into a second union during this scoped change.

Update every in-repository producer/fake in lockstep, including common ACP
producers and all supported harness dispatchers. Discover that set from actual
constructors before implementation; do not assume only named examples matter.
Keep external OpenCode/ACP/Codex/Claude/Pi parsing and unknown-backend decisions
inside their plugins. No optional map fallback or compatibility constructor.
No public `SesoriSseEvent` schema or transcript database change.

In step 7 remove the explicit raw-payload dump from the residual session parse
failure log, retaining event type, useful error and stack context. Log failure
reporter failures instead of `.catchError((_) {})`. Do not suppress whole error
categories. Session-created/updated/deleted JSON remains for now: those events
carry both raw observations and enriched catalog `Session` data. Their honest
replacement needs a separate app-owned normalized boundary, estimated
1,200–2,400 lines, and is deliberately outside this series.

### 8. Narrow identity and activity database reads

Ownership remains API/DAO -> Repository -> Service. Add a bulk SessionDao
projection selecting backend ID and stable ID for one plugin and requested IDs.
Replace `getStoredSessionsByBackendIds` with the honestly named
`getSessionIdsByBackendIds` returning `Map<String, String>`; update its two
production consumers (event translation and subtask-ID remapping) and tests.
Keep full-record methods used by other callers, missing/optional binding rules,
plugin isolation, and the existing generation fence around awaited reads.

Add a ProjectsDao query for the requested IDs and activity timestamp columns;
`ProjectRepository.getActivities` maps those rows without `getAllProjects()`.
Delete unused `getActivity`. Empty sets return an empty result at the query
owner. No cache, denormalized table, index, pagination, or mutable state added.
Use real SQLite tests for scope, missing IDs, overlapping backend IDs across
plugins, and timestamp semantics; inspect the generated SQL/projection shape.
No database schema or user-visible behavior change; no latency claim without
measurement.

### 9. Stop forwarding backend events with no product consumer

OpenCode `SseEventMapper` stops producing the 15 internal PTY/file-watcher/LSP/
MCP/installation/workspace/worktree variants listed in audit D3. Delete those
`BridgeSseEvent` variants and corresponding identity/wire mapping arms; retain
exhaustive handling of the remaining union. Keep external generated OpenCode
models and public shared/client decoders for released older bridges.

Before suppressing a category, verify no supported public client consumes it;
current and public v1.8.2 are already checked. Inspect remaining public release
baselines; retain any category with an actual released consumer and record that
narrowing. Internal/prerelease builds alone create no compatibility obligation.
Keep toast, VCS, file-edited, runtime lifecycle, and command/options signals.
Expected result: equivalent product behavior with less normalization/transport
work; no wire shape or schema deletion. Do not claim measured speed improvement.

### 10–12. Consolidate proven duplication at existing owners

**10 — native thumbnail storage.** Move the common pure-Dart implementation to
`client/module_core/lib/src/foundation/io/` as `FileAttachmentThumbnailStorage`
and `TemporaryDirectoryClient`. Define the required platform capability
`TemporaryDirectoryProvider` in core `foundation/platform/`, exposing async
directory lookup. Each shell supplies a thin path_provider adapter for that
interface. The shared client injects the interface, owns cached lookup/failure
retry, and offers logged best-effort warm-up. Shell RegisterModules bind the
provider and shared client/storage in phase 1 and regenerate injectable output.
Mobile recording injects the shared client and retains warm-up. Delete the
superseded duplicate storage/cache implementations; retain only the thin native
lookup adapters in shells. Consolidate common behavior tests in core.
Keep atomic flush/rename, path validation, unique temp names, finally cleanup,
cache paths, and account-scope deletion. Metadata reads ignore temp files;
delete opportunistic temp sweeping and both static active-path registries.
Accept rare interrupted-write temp residue in the OS cache. No database or
path change. No new web adapter or Flutter dependency in core.

**11 — optimistic rename.** Add a concrete
`client/module_core/lib/src/cubits/shared/optimistic_rename_tracker.dart` owner for
the common pending-token/visible/confirmed-value algorithm. Existing cubits
instantiate it per entity; no DI singleton. Replace `_ProjectRenameState` and
`_SessionRenameState`. Retain nullable originals, multiple outstanding requests,
and older-success/newer-failure semantics. Keep allocation, entity maps,
repository calls, refresh and UI projection with existing cubits. RenameSheet
closes immediately, so overlap is ordinary behavior, not speculative defense.
No generic optimistic mutation framework or new product/database behavior.
Place this cubit-owned bookkeeping beside cubit collaborators, incorporating
#1296's useful placement correction. Keep a separate tracker per entity; a
single visible/confirmed pair shared across all projects would mix renames.

**12 — managed installer graph.** Add an explicit named composition factory on
existing `ManagedRuntimeInstallService`, taking required manifest, executor,
downloader, version validator, and resolver. Construct existing checksum,
extractor, installer and cleaner dependencies there; retain the injected
constructor for tests/custom composition. Update seven current consumers:
Codex, OpenCode, Copilot, Cursor, Pi, OMP, DeepSeek; discover any newly added ones.
Descriptors retain operation-local HTTP client creation/finally close, executor
limits/Windows shell policy, timeout, validators, and per-plugin asset resolver
(including OMP dynamic resolution). No runtime pin/digest, installation format,
authentication, capability, lifecycle, or database change. No forwarding-only
new orchestration class or standardized descriptor policy.

## Additional work adopted from #1296

### 13. Share provisioning composition and bounded cold-start waiting

Extend existing `ManagedRuntimeProvisionService` with an explicit composition
factory taking required manifest, version validator, and fallback executable
candidates. It constructs the existing `ManagedRuntimeSelectionService` and
delegates to the current injected constructor. Update the same seven managed
plugins as step 12, retaining each version probe, explicit-bin short-circuit,
fallback ordering and exact-managed-version policy. Do not construct a default
executor that erases per-plugin output limits or validation choices.

For Codex and OpenCode's duplicated bounded initialize wait, introduce
`ManagedRuntimeColdStartService` in `sesori_plugin_runtime`: immutable required
budget and log tag; `run` receives the already-started `Future<void>` and
`ManagedRuntimeStatusReporter`. It owns only the existing budgeted wait,
connected/degraded report and observable post-budget failure sink. Preserve the
current timeout duration and recovery behavior. One invocation-local
`budgetExceeded` value replaces each local copy; no long-lived state is added.

Keep API creation/initialize invocation, OpenCode's condition for performing the
cold start, and unconditional abort-observed shutdown in the descriptors. The
abort check must run even when OpenCode skips the wait. Do not create a generic
plugin lifecycle coordinator or pass an entire plugin to the wait helper.
Do not add a single-use guard, owned HTTP-client field, new timeout, background
retry or subscription. Step 12 already shares installer composition while
preserving descriptor HTTP lifetime and OMP's asynchronous Linux asset resolver;
#1296's hard-coded `manifest.assetFor` substitution is explicitly rejected.

Validation: provisioning precedence for all seven consumers, explicit override,
missing/wrong version, and both cold-start paths completing/failing before or
after budget, degraded recovery, abort rollback including the skipped-wait path.
Use existing runtime/descriptor tests and the live matrix below. No wire,
database, runtime-version or user-visible behavior change.

### 14. Fold local repeated worktree and Codex algorithms

Sources: `WorktreeService.create` candidate loops; Codex
`CodexSessionService.startTurn`/`sendCommand`; the string/comment-aware scanner
in `codex_rollout_tool_mapper.dart`. Keep each extraction inside its existing
owning class. Fold common candidate creation and result construction, common
resume/model/mode/effort preparation, and the duplicated lexical cursor advance.
Do not introduce a generic retry service, operation callback abstraction, or
shared JavaScript parser package.

Retain two worktree caller loops where their termination differs: the suffix
loop stops after a failed creation on an available candidate. Do not turn this
into retries on every suffix just to express one loop. Keep branch/path
collision checks, candidate order, attempt bounds and fallback outcome. Codex
retains exactly one forced-resume retry on `CodexThreadNotFoundException`;
recompute model/mode/effort after the resume, and retain different command/turn
arguments and result types. Parser changes must preserve quoted escapes and
line/block comments. Existing owning tests plus analyzer are sufficient; add
cases only for an uncovered behavior affected by the fold. No new persistent or
mutable state, product behavior, wire or database change.

### 15. Preserve caught errors and stacks in bridge diagnostics

#1296 identifies about 53 candidate log sites across orchestrator/debug/SSE,
runtime runner, ACP and descriptor cold starts. Recount after steps 7/13/14;
fold overlapping sites there instead of changing them twice. Inspect each catch
and caller: use logger error/stack arguments for recovered failures, retaining
operation context. Some sites already interpolate a stack; do not claim every
site loses it. Do not add duplicate logs for rethrown/explicit failures.

Remove known payload dumps selectively per step 7, never blanket diagnostic
suppression. Keep expected typed failures at their existing appropriate level;
make recovered unexpected failures observable. Add no logging wrapper/category,
analytics, or new retry. Validation is owning analysis and any affected existing
log-capture assertions; no full plugin lifecycle suite solely for log edits.
No user-visible/wire/database change.

### 16. Share shell cubit composition at the DI boundary

Mobile/desktop repeat construction of SessionDetailCubit, ProjectListCubit,
SessionListCubit and NewSessionCubit. Add four named composition functions in
`client/module_core/lib/src/di/`, exported from the core barrel. They take a
required `GetIt locator` plus all runtime arguments (including nullable ones)
and return a fresh cubit with the same collaborators the shells currently
resolve. Inspect constructors after #1294; do not restore removed selector DI.
Each shell keeps `BlocProvider(create:)`, route IDs, ownership/disposal and
surface-specific presentation; it calls the shared composition function.

No GetIt import inside cubits, singleton cubit, static locator, new lifetime,
or wrapper widget. The session-activity analytics widgets remain separate:
desktop calls `setRouteVisible` through RouteSource, mobile deliberately does
not. Preserve notification-capability bindings and view/analytics semantics.
Validate both shell screen/provider tests, fresh-instance/disposal ownership,
core and shell analysis/build, and real screen navigation in the client matrix.
No product behavior, database or wire change.

### 17. Fold repeated auth response and login completion logic

Keep changes within the existing auth HTTP client and AuthManager. Share the
HTTP-response-to-ApiResponse branch between ordinary and multipart responses,
retaining empty-body handling, per-operation context, typed parsing causes and
non-success status/raw-error semantics. `_completeInteractiveLogin` accepts the
captured generation and parsed auth response, performs the existing persistence
call and returns AuthLoginResult. Email and Apple retain their own requests,
email's 401 behavior and input validation. Do not fold OAuth ownership or token
refresh into this helper merely because their tails look similar.

Preserve superseded-login fencing, secure persistence ordering, OAuth-state
clearing and returned account status. When a touched catch translates parsing
failure, retain its typed inner cause with a privacy-safe presentation; do not
carry forward string-only wrapping. If a local exception class is needed, keep
it within the owning file and include it in scoped architecture review.

Validation: both HTTP response suites and AuthManager tests for email/Apple
success, malformed/empty/non-2xx response, persistence failure, superseded
completion and logout overlap. Email client E2E proves unchanged composed path;
Apple native identity acquisition is unchanged and can use the existing
response fixture boundary. No authentication endpoint, credential format,
trust posture, public API or database change. This is higher sensitivity than
ordinary cosmetic deduplication despite its local implementation.

### 18–19. Consolidate substantial test fixtures by owning package

Step 18 covers bridge; step 19 client. Start from #1296's repeated setup blocks:
OpenCode active-session/repository tests, session DAO/creation/routing/question
and Git remote tests; client session-detail stale/event/cubit tests, auth,
new-session and project-tile suites. Use file-local builders for substantial
repeated setup and package-local `test/helpers` or existing testing libraries
for identical behavioral fakes shared across files. Both source plans' test
counts are discovery evidence, not targets or proof that a larger test corpus
is unhealthy.

Do not centralize every one-line Mock declaration or create a universal fake
registry/configuration framework. Keep different fake behavior local; do not
change assertions or default failures to fit a helper. Update fixtures after
their production steps and preserve #1294's new selection tests. A shared helper
must make setup clearer at its call sites. Core's testing library remains
Flutter-free; Flutter widget helpers belong to their owning Flutter test tree.

Run each changed suite and analyze the owning package. No production code,
product behavior, wire or database change. Target 500–1,200 changed lines per
workspace; narrow to meaningful fixture clusters rather than inflating either
PR to perform the entire census. Record unprofitable tiny copies as retained.

### 20. Remove verified unused dependencies, keys and symbols

Re-verify #1296's inventory on implementation main: `re_highlight` in app,
`cupertino_icons` in design_catalog, app-dev `fake_async`, runtime annotation
deps, linter `_fe_analyzer_shared`, and candidate direct `json_annotation`
declarations. Check generated/tool/test imports, exports and builder usage as
well as production imports. Remove only dependencies actually unnecessary;
keep packages with direct uses and do not rely on an accidental transitive
builder configuration. Antigravity's package is left to its active series.

Candidate keys: `sessionListStaleProjectTitle`, `sessionListStaleProjectMessage`,
`sessionListStaleProjectBack`, `voiceErrorNetwork`. Candidate symbols:
`currentProjectName`, `kStatusGreen`, `kStatusPurple`, `logwf`,
`testMultiSseQuestionAsked`, `lerpTextStyleNonNull`. Search all consumers before
deletion, including exports, generated code and tools. The narrow repository
methods from step 4 are separate findings, not replaced by this top-level scan.
Regenerate affected localization/lockfiles from sources. Resolve/build/analyze
owning packages and exercise code generation where annotation deps change.
No product behavior or database change; dependency graph changes are explicit.

### 21. Audit and simplify repository documentation

The user explicitly expanded documentation cleanup beyond historical reports.
Inventory tracked root/package READMEs, `docs/`, active-plan links and relevant
contributor/instruction docs, excluding generated or vendored text. Establish
one authoritative page per current capability/setup workflow; shorten repeated
explanations, fix misleading paths/commands, and replace copies with direct
links. Do not add another documentation management service or permanent audit
registry. Preserve active plan execution state and meaningful architectural
rules; editorial cleanup does not approve the deferred policy changes.

Historical deletion candidates from #1296: `docs/codex-plugin-stability-report.md`,
`docs/cursor-acp-followups/`, `docs/plans/auth-reconnect-ux-plan.md`, and
`docs/parallel-plugins/{PLAN.md,CONSIDERATIONS.md,baselines/}`. Verify completed
status and inbound references at execution; preserve any unresolved useful
follow-up in the appropriate active plan before deleting its only inventory.
Keep or integrate durable `docs/parallel-plugins/ARCHITECTURE.md` content into
`docs/ARCHITECTURE.md` before removal. Git history retains completed reports;
do not copy them wholesale into a new archive. Validate links from README,
VISION, ROADMAP and remaining docs. No code, product, wire or database impact.

### 22–23. Simplify all regression feature guides

Audit **every** `docs/regression/*.md` feature guide against supported behavior,
production callers and relevant existing tests. The baseline directory contains
roughly 4,300 lines; `session-turns.md` alone has 539 and
`projects-and-sessions.md` 437. Size selects where to look, not what to delete.
The attachments L1 row currently mixes a large routine/adverse-state inventory
with smoke checks; navigation coverage still describes legacy MaterialApp
implementation mechanics. These are concrete places to review for a clearer
current-behavior contract, not proof that the underlying assertions are useless.

Split the editing pass by ownership to keep reviews useful. Step 22 covers
account/onboarding, analytics, attachments, design catalog, native indicators,
navigation, notifications/popups, projects/sessions, session creation/options,
session turns and voice. Step 23 covers bridge connectivity/installation,
desktop supervision, diffs/source control, plugin installation/setup, provider
routes, PR monitoring, permissions/questions, archiving/deletion, history/recovery
and tools/file changes. Any newly added guide is assigned to its natural owner;
step 24 checks that no guide was missed. No feature is exempt merely because
its production code was not touched in this series.

For each guide, keep a short capability statement, the material supported
outcomes, distinct failure signals and the shortest complete proof boundary.
Remove duplicate assertions across prose/level tables, obsolete routes/classes,
completed-plan history, fixed click scripts, and checks for minor cosmetic or
hypothetical cases with no meaningful current consequence. Keep absence checks
only where reintroduction would violate a live capability/security invariant.
Document real harness limitations honestly. Do not erase live deletion
`tombstone` semantics because that word also describes obsolete documentation.

Put common level/coverage/evidence rules once in README; feature guides state
only their added coverage. L1 should identify critical heartbeats, not recite an
entire owning suite. Consolidate equivalent checks and move routine/extended
items to their honest level without losing the underlying material invariant.
Do not impose line/word reduction targets or fabricate a known limitation to
justify deleting coverage. Preserve account isolation, encryption, released
wire compatibility, persisted transcript integrity, abort/logout ordering and
honest failure reporting through their complete boundaries.

Record a compact per-step disposition in the PR: guide reviewed, obsolete or
redundant coverage removed, substantive invariant retained and its proof source.
No new permanent checklist alongside each guide. Validate links, source/test
references and cross-document consistency; rewriting docs alone does not require
rerunning product suites. Executed coverage remains whatever evidence actually
ran. The original plan's required verification rows stay intact; any proposed
reduction of that frozen matrix still needs the explicit acceptance required
by its retirement rule. The user's request authorizes removal of pointless
documentation; it is not permission to report unexecuted checks as passing.

Step 24 reconciles these edits with all final implementation changes and the
regression README/index before step 25 executes the recorded matrix and retires.

## Mutable-state budget and accepted risks

| Scope | Budget / evidence / limitation |
| --- | --- |
| Transcript | Zero new persistent or mutable cubit fields. Existing accumulator remains alive; invocation-local before/live/fetched reconciliation. Ordinary-flow failures reproduced; no globally versioned snapshot claim. |
| Dead paths | Remove one maintained map and three unused drain APIs plus the unused insertion API. Retain real ordering/identity guards; production callers verified. |
| Cache | Remove one persisted field and nullable recovery state. Zero new locks/epochs/retry loops. Injected corruption supports deletion, not more recovery machinery. |
| Typed events/queries/noise | Zero new mutable/persistent parts. Four immutable normalized payload variants replace the stream payload vocabulary; no additional stream or lifecycle owner. Reuse existing mapping owners. Public compatibility stays at the wire boundary. Cost reduction established structurally, unmeasured in time. |
| Native files | One shared cached-directory future and existing temp-name counter replace copies; remove two static active-path sets. Accept occasional temp residue; keep account retirement. |
| Rename/installer/provision/cold start | Preserve per-entity rename state; factory adds no long-lived state/resource owner. One immutable bounded-wait service replaces two blocks; invocation-local timeout flag only. Descriptor owns abort rollback and HTTP lifetime. |
| Composition/auth/logging/local folds | Zero new mutable/persistent parts. Fresh cubit lifetime unchanged; existing auth generation/persistence owner remains authoritative. |
| Fixtures/hygiene/docs | Test-local fixtures only; no production coordination. Deletions verified against callers and generation workflows. |

Deferred: whole-session event boundary redesign; broader options concurrency
rewrite; other snapshot groups; prune scheduling; dispatch queue replacement;
ancestry simplification; generic viewing tracker; paired-listener policy changes;
shared Flutter-plugin adapters; desktop attention redesign; compatibility-floor
retirement. The consolidation ledger records why these are not executable
steps. No original verification row is reduced. Add no
new analytics: no new user action or adoption decision is introduced.

## Fixed PR series and review

Exact titles live in [TRACKER.md](TRACKER.md); every body includes Complexity,
What, Why, Risk and test focus, Expected result, and Verification. Execute in
order. Each implementation PR remains independently valid; none leaves a typed
contract half-migrated across plugins. Estimates include tests and generators.

| Step | Review focus / expected result | Estimated changed lines |
| --- | --- | --- |
| 1 | Consolidated audit, evidence, plan and handoffs. No product/database change. | 1,500–2,000 |
| 2 | Prefix survives refresh and finalization still clears text; low risk, localized client logic. | 80–180 |
| 3 | Fetched data and live changes both survive; moderate risk, no replay/provenance registry. | 450–900 |
| 4 | Test setups no longer keep unused production paths alive; medium integrity risk, real creation and ordering tests. | 450–950 |
| 5 | Remove unused persisted metadata and failing recovery branch; high migration sensitivity. | 600–1,500 plus schema artifacts if necessary |
| 6 | Typed status and normalized stream seam in every producer/consumer; medium cross-plugin mapping risk. | 600–1,200 |
| 7 | Typed messages agree in history and live events; high persisted-content sensitivity, no schema change. | 700–1,400 |
| 8 | Scoped projections retain identity/timestamp semantics; medium query risk, no schema change. | 200–450 |
| 9 | Drop no-consumer internal events, preserve published consumers/decoders; medium compatibility risk. | 200–500 |
| 10 | Shared native storage/directory and fewer registries; medium filesystem/DI risk, paths unchanged. | 700–1,300 |
| 11 | One rename algorithm retains overlap/rollback behavior; medium UI-state risk. | 200–450 |
| 12 | One installer graph retains each plugin's inputs/lifetime; medium installation risk. | 350–800 |
| 13 | Shared provisioning composition/bounded cold start, plugin differences and abort ownership retained; medium lifecycle risk. | 350–700 |
| 14 | Fold worktree/Codex local loops without changing retry/termination semantics; moderate logic risk. | 200–450 |
| 15 | Typed local error/stack diagnostics; low operational risk, no new categories. | 150–250 |
| 16 | Share four cubit compositions with fresh ownership; medium shell/DI risk. | 250–450 |
| 17 | Local auth folds preserve secure persistence and stale-completion behavior; high sensitivity. | 180–400 |
| 18 | Consolidate meaningful bridge fixtures; test-only. | 500–1,200 |
| 19 | Consolidate meaningful client fixtures; test-only. | 500–1,200 |
| 20 | Verify and delete unused dependencies/keys/symbols; low risk, codegen/dependency checks. | 100–400 |
| 21 | Simplify root/package/general docs and remove completed reports; retain durable/unresolved content. | 2,500–4,000, mostly deletion |
| 22 | Simplify client and product-flow regression guides; no production/database change. | 500–1,200 |
| 23 | Simplify bridge/runtime/recovery regression guides; no production/database change. | 500–1,200 |
| 24 | Reconcile all final regression docs and README/index; no new product/database change. | 150–300 |
| 25 | Execute recorded matrix, record results, retire only after pass; no product change. | 100–350 |

1,500 changed lines is a soft cap. Step 1 consolidates two existing plans and
preserves their evidence/dispositions in one reviewable documentation PR;
its overage avoids leaving competing authorities. Step 21 may exceed the cap
for deletion of completed documents; keep any substantial content rewrite
within the normal cap rather than hiding it in the deletion count. Step 5 may exceed it because Drift requires
an atomic generated schema snapshot/migration with the column change; record
actual count and generated-versus-handwritten split. Do not manufacture an
intermediate incompatible schema to satisfy a line cap. Otherwise split only
with a coherent update to all titles/denominators before the affected PR opens.
Architecture plan review required now; implementation review required for
4–13 and 16 where production contracts/owners/files change, 17 if a production
exception type is introduced, and 20 for dependency-boundary changes.
No review for ordinary local method folds, logging, tests or docs.
Steps 2–3 are localized
existing-method logic unless implementation actually adds architecture.

## Verification and retirement

Follow [regression proof boundaries](../../../docs/regression/README.md).
Highest targeted level is **L4**, using this impact-scoped matrix; it is not a
claim that entire feature documents have passed cumulative L4. Per PR, run the
owning tests/analyzer and use CI for broader coverage. Reuse unchanged passing
evidence instead of rerunning it. Missing required coverage keeps the plan active.

| Affected feature documents | Required matrix and complete proof boundary |
| --- | --- |
| `session-history-and-recovery.md`, `session-turns.md`, `bridge-connectivity.md` | Steps 2–3: automated L2/L4 cubit+buffer tests above, then client E2E on macOS desktop and one supported mobile platform through a representative streaming backend: intended resume/reconnect refresh, continuing delta, finalization, snapshot-only catch-up, paged history. Record the other mobile platform as outside this scoped matrix, not passed. No network latency/protocol change claim. |
| `projects-and-sessions.md`, `session-archiving-and-deletion.md` | Steps 4/8: automated L2/L4 real SQLite repository/service/identity tests, deferred parent/child ordering, eviction, two plugins sharing a backend ID, current creation commit/defaults/binding notification and affected route tests. Representative faithful plugin sufficient for unchanged core policy. No destructive live user data mutation. |
| `session-creation-and-options.md` | Step 5: automated L2/L4 real database fresh install and schema-14 upgrade (valid and unknown old completeness), explicit successful discovery after upgrade, malformed remaining JSON, retained fresh completeness policy, invalidation/generation/path tests. Fake plugin plus real DAO/repository/service is the full cache-policy boundary; SQLite host macOS, migration CI as configured. |
| `session-turns.md`, `session-history-and-recovery.md`, `questions-and-permissions.md` | Steps 6–7: automated L2/L4 translator tests for every producing production plugin/common ACP path, status variants, user/assistant/error messages, stable IDs, terminal handoff, child routing, stored/live agreement and relay JSON round trips. Existing external API fixtures retained; compare emitted public wire fields with baseline. One headless bridge transcript/status smoke using representative live backend proves composed path. Public client wire fixtures exercise old/new decode; no backend upgrade or new capability claim. |
| `tools-and-file-changes.md`, `bridge-connectivity.md` | Step 9: automated L2 exact dropped-category OpenCode mapping fixtures and retained toast/file/VCS/options/lifecycle cases; public client consumer inspection and decoder regression tests. Suppressed external notifications stop at plugin boundary. No UI capability claimed removed. |
| `attachments-and-images.md`, `voice-input.md` | Step 10: automated L2/L4 shared storage, directory, image-repository, retirement, atomic replacement/concurrency/corruption and mobile recording tests. Core file suite on macOS/Linux/Windows (CI allowed). Native directory binding write/read/list/delete-scope smoke on macOS desktop, iOS and Android. Real platform lookup is required; mock-only wiring cannot prove it. |
| `projects-and-sessions.md` | Step 11: automated L2/L4 both cubit rename suites including overlapping success/failure, null originals and refresh, plus shared RenameSheet behavior/widget tests. Shared module and both shells analyze/build. Unchanged bridge persistence needs no additional live rename claim. |
| `plugin-runtime-installation.md` | Step 12: automated L2/L4 runtime and all seven descriptor install/setup suites, manifest target mapping, checksum/failure/cancellation and client closure. Headless live installation/verification/re-inspection on macOS arm64 for every managed-install consumer using isolated runtime roots. Existing fixture tests cover platform-specific executor/resolver inputs; no new binary/platform support claim. |


| `plugin-runtime-installation.md`, `plugin-setup-and-lifecycle.md` | Step 13: automated L2/L4 provisioning/descriptor tests for all seven managed plugins, existing-runtime precedence and each plugin's probe inputs; both Codex/OpenCode cold-start success/failure/timeout/late-failure/abort paths, including OpenCode skipped wait. Headless inspection/provisioning for all seven and live bounded cold-start smoke for Codex/OpenCode on macOS arm64. Reuse step 12 live installation evidence if unchanged. |
| `projects-and-sessions.md`, `session-turns.md`, `tools-and-file-changes.md` | Step 14: automated worktree collision/failure/fallback tests and Codex command/turn retry and scanner suites; actual Git fixture proves the repository creation outcome. No live backend needed for unchanged typed repository calls/fixture protocol semantics. |
| `projects-and-sessions.md`, `session-creation-and-options.md`, `session-history-and-recovery.md` | Step 16: both shell provider/screen tests and fresh cubit lifecycle assertions; real navigation through project/session/new-session/detail on macOS desktop and the mobile platform selected for steps 2–3. Preserve #1294 selection and per-surface view behavior. |
| `account-and-onboarding.md` | Step 17: automated L2/L4 real auth-owner tests with fake HTTP/secure storage, email/Apple completion, parse/non-2xx/empty failures, supersession/logout and persistence failure. Email client E2E on the same mobile platform. Apple acquisition is outside the changed code; existing native-response fixtures prove the changed completion boundary. |
| Test/tooling/documentation and local logs | Steps 15/18–24: changed fixture suites, owning analyzers, focused log assertions where present, dependency resolution/generation checks and doc link/source-reference validation across every regression guide. No product-level/full-workspace suite solely because test corpus or dependency counts changed. |

Step 24 completes these feature docs with supported behavior and material
failure signals, removing obsolete references without tombstones. Step 25
records Pass/Partial/Fail/Blocked/Not run per matrix row with commit/build,
platform/plugin, evidence and cleanup. Move to `.plan/completed/periodic-cleanup/`
only after required coverage passes. Reducing this matrix requires explicit
user acceptance recorded here. No production release/signing test is implied:
no packaging or shipped runtime artifact changes.

## Decisions, overlap, and review

- Plan consolidation and closing #1296: explicitly authorized by the user.
- Repository-wide documentation maintenance and simplification of all regression
  guides, including removing pointless content: explicitly requested during
  consolidation. Steps 21–24 own it; no narrow historical-report-only scope.
- Refactor implementation scope acceptance: pending; no production edits in step 1.
- #1294 merged and owns selection reconciliation; source diff inspected, no
  additional variant cleanup scheduled. Revalidate the original diagnostics
  against rebased code when steps 2–3 begin.
- Architecture plan review: the materially consolidated plan was **Approved**
  on 2026-09-04, with no new findings. Original review/corrections and this
  verdict are recorded in TRACKER.md.
- Existing `session-refresh-reconnects` diagnostic plan receives a linked
  handoff for the two reproduced issues. Its historical observation and
  retirement state remain intact; this plan does not falsely complete it.
- No observations establish that authentication, trust modes, account isolation,
  public wire defaults, generation fencing, or ancestry checks can be removed.
