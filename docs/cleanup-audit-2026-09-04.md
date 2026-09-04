# Periodic cleanup investigation — 2026-09-04

Baseline: `480d82f090`. Investigation and proposed series:
[PLAN.md](../.plan/active/periodic-cleanup/PLAN.md),
[tracker](../.plan/active/periodic-cleanup/TRACKER.md),
[reproducible evidence](../.plan/active/periodic-cleanup/evidence/README.md).

The highest-value work is in state ownership and internal contracts: refreshes
can overwrite live transcript content, tests keep an obsolete insertion path
alive, a pending-event index has no production reader, and typed plugin values
are repeatedly serialized and reparsed inside the bridge. These take priority
over the smaller duplication findings from the first pass.

This PR contains investigation and a proposed implementation plan. It does not
fix the reproduced failures or change production code. The findings below
separate exercised failures, confirmed source facts, and unmeasured costs.

## Investigation depth and limits

The structural scan covered 1,462 hand-written production Dart files, excluding
generated code. Selected deep reviews followed producers, normalization,
consumers, persistence, invalidation, recovery, tests, and relevant history.
They covered client snapshot/event interaction; plugin-to-core event contracts;
pending identity binding; session creation; options discovery/cache; project
activity queries; image storage; optimistic renames; dispatch ordering; and
runtime installation. This is not a claim to have read every line or performed
a complete security audit.

Three diagnostic tests were added temporarily to existing suites and executed
against unchanged production code. Two reproduced ordinary refresh/event
interleavings; one injected malformed persisted metadata. The existing nearby
refresh test passed while the new already-loaded-message case failed. Diagnostic
patches are preserved as evidence; the test files were restored afterward.
No live backend, full UI, performance benchmark, or full suite was run.

## Prioritized findings

| ID | Finding / removal opportunity | Evidence | Proposed scope |
| --- | --- | --- | --- |
| A1 | Refresh clears an active streaming accumulator, losing preceding text on the next delta | Executed failing test | Small client fix |
| A2 | A snapshot arriving after a live part update overwrites it for an already-loaded message | Executed failing test through intended stale-data refresh | Pure transcript reconciliation; no event replay |
| B1 | Session insertion and placeholder repair exist solely for test callers | Production-call search plus current create-path trace | Remove dead API; migrate fixtures and meaningful tests |
| B2 | Pending-event child index and three drain APIs have no production readers/callers | Full Dart caller search and actual service drain trace | Remove state and obsolete test paths |
| C | Persisted options completeness is never consumed and can make successful discovery unrecoverable | Unused-field trace plus real SQLite fault-injection failure | Remove column and obsolete unknown-revision recovery |
| D1 | Status/message events discard existing types and repeatedly parse JSON internally | Producer-to-storage-to-wire trace | Two lockstep internal contract PRs |
| D2 | Raw session events also conflate plugin observations with enriched bridge catalog data | Producer and normalization trace | Separate larger boundary redesign deferred |
| D3 | Fifteen OpenCode event variants reach no-op client handlers | Producer/consumer search; public v1.8.2 also inspected | Drop unused internal forwarding, preserve public decoders |
| D4 | Identity lookups materialize whole sessions; scoped project activity loads the whole catalog | All production callers inspected | Narrow DAO projections, no cache |
| E1/E3/E5 | Thumbnail storage, rename bookkeeping, installer graphs duplicated | Compared implementations and real differences | Three independent cleanup PRs |
| E2/E4 | Per-thumbnail whole-cache scans; locally reimplemented dispatch queues | Source cost/semantics established, benefit unmeasured | Defer optimization/queue replacement pending stronger benefit |

## A. Refresh ownership has two concrete failures

Sources: [SessionDetailCubit](../client/module_core/lib/src/cubits/session_detail/session_detail_cubit.dart),
[StreamingTextBuffer](../client/module_core/lib/src/cubits/session_detail/streaming_text_buffer.dart),
[event-buffer tests](../client/module_core/test/cubits/session_detail/session_detail_event_buffer_test.dart).

**A1 — accumulator reset.** `_doSilentRefresh` snapshots `_streamingBuffer`,
clears it, and emits the saved text into state. The screen can therefore look
correct immediately after refresh, while the mutable owner no longer contains
that prefix. An emitted `before-`, successful refresh, then `after` delta gives
`after`, where `before-after` was expected. The added test reproduces exactly
that outcome after awaiting the actual streaming flush.

**A2 — stale snapshot replacement.** `_handleEvent` buffers during
`SessionDetailLoading`; a silent refresh remains `SessionDetailLoaded`. Live
parts are applied while the reload is pending, then `messages: snapshot.messages`
replaces them. `_deferredPartEvents` protects a message that is not loaded yet,
which explains why the existing adjacent test passes. It does not protect a
part added to an already-loaded message. The diagnostic's live part is absent
when the held snapshot completes.

These are plausible ordinary sequences during reconnect, resume, or explicit
stale-data refresh while a turn streams. They are deterministic unit
reproductions, not an assertion about incidence in production. Pending
questions/statuses/children are also replaced from the snapshot; that broader
state interaction is source-level concern, not a separately reproduced bug.

The proposed fix keeps the accumulator alive and reconciles fetched messages
with changes between immutable before/live transcript values. It preserves
both snapshot-only updates and in-flight live parts, without replaying deltas
or modal side effects. Whole-list preservation was rejected because it would
also discard useful fetched changes; the diagnostic explicitly expects both.
See the plan for pagination ownership and the limits of unversioned snapshots.

The existing [session-refresh-reconnects plan](../.plan/active/session-refresh-reconnects/PLAN.md)
already identified both risks but left behavioral changes pending diagnostics.
The new tests provide the intended-refresh evidence it requested. Some older
trigger descriptions are stale: current code ignores `sessions.updated` for
full-detail reload. Do not reimplement its earlier proposed trigger changes.

## B. Tests are preserving obsolete production machinery

**B1 — insertion path.** [SessionRepository.insertStoredSession](../bridge/app/lib/src/repositories/session_repository.dart)
has no production caller; references are test setups, direct tests, and fake
overrides. Its transaction includes a placeholder-project reattribution repair,
extra ownership/state checks, and orphan deletion. Actual `createSession` uses
`_runtime.useAndCommit` and `upsertObservedSessionBinding`, followed by binding
notifications. The repair is not protecting that current path.

Delete the dead repository method. Put setup-only row insertion in a test
fixture using DAOs; exercise the current `createSession` path for real project,
prompt-default, transaction, and binding-notification assertions. Remove tests
whose sole contract is the obsolete helper's repair behavior. Do not preserve a
test-only public production API or move its orphan cleanup into the live path.

**B2 — maintained but unread index.** [SessionEventTracker](../bridge/app/lib/src/repositories/trackers/session_event_tracker.dart)
maintains `_children`, but the only reader is `takeChildren`, itself called only
by tests. `takeTranslations` and `takeReady` also have no production callers.
[SessionEventService](../bridge/app/lib/src/services/session_event_service.dart)
actually drains with `takeRoot`/`takeNextReady`; the latter uses the insertion
order and each session's parent directly.

Remove `_children`, its update/removal bookkeeping, and those three unused APIs.
Keep the session and translation maps used for pending binding, ordering, and
bounded eviction. Rewrite meaningful tests through the real drain path;
otherwise a green suite continues proving behavior the application never uses.

## C. A cache field with no reader creates a recovery failure

Sources: [service](../bridge/app/lib/src/services/session_options_service.dart),
[repository](../bridge/app/lib/src/repositories/session_options_repository.dart),
[table](../bridge/app/lib/src/api/database/tables/session_options_cache_table.dart),
[DAO](../bridge/app/lib/src/api/database/daos/session_options_cache_dao.dart).

`SessionOptionsCacheEntry.completeness` is written and read back, but no policy
consumes the cached value. `_canReplace` depends on the **fresh observation's**
completeness and whether a retained entry exists. Fresh completeness matters;
persisted completeness does not.

Injecting an unknown completeness string into a real SQLite row makes Drift
throw before the repository can read its revision. `_readValidAttempt` retries
the same undecodable row and returns a miss without deleting it. A successful
explicit capture then tries a revision-null insert, which conflicts with the
still-existing row twice. The service returns
`SessionOptionsRefreshFailedUnavailable` despite one successful plugin capture.
The existing repository test verifies only that the decoding error is wrapped;
the new diagnostic traverses the repository/service/DAO chain.

This is fault injection, not an observed common corruption source. The response
should be less schema and less recovery code: remove persisted completeness,
keep observation completeness, and remove the resulting unknown-revision branch.
The remaining enum `scope` is selected by a known scope in `getRow`; JSON decoding
occurs after a row and its revision are available. Database I/O errors remain
explicit failures, not permission to delete arbitrary state.

The table exists in public production tag **v1.8.2**. Use the next real Drift
migration from current schema 14, regenerate outputs, and preserve session,
transcript, project, and new-session-default data. Do not rewrite historical
schemas or retain a dual-read shim. This cleanup does not justify removing the
remaining CAS, plugin-generation fencing, invalidation epoch, or project-path
checks: cache-only reads and stale-send invalidation are additional writers.

## D. Internal boundaries add conversions and work with no consumer

**D1 — typed values become JSON too early.** [BridgeSseEvent](../bridge/sesori_plugin_interface/lib/src/bridge_sse_event.dart)
uses `Map<String, dynamic>` for message/status payloads even though
`PluginMessage` and `PluginSessionStatus` already model them. Producers serialize;
[SessionEventMapper](../bridge/app/lib/src/repositories/mappers/session_event_mapper.dart)
parses to identify/remap a message, then serializes again;
[ChatHistoryListener](../bridge/app/lib/src/listeners/chat_history_listener.dart)
parses again and can drop an undecodable internal message;
[BridgeEventMapper](../bridge/app/lib/src/sse/bridge_event_mapper.dart)
builds another JSON event and parses it to construct the public model.

Use typed plugin payloads across the internal boundary and existing
[message](../bridge/app/lib/src/repositories/mappers/plugin_message_mapper.dart)/
[status](../bridge/app/lib/src/repositories/mappers/plugin_session_status_mapper.dart)
core conversion functions at repository normalization, producing shared typed
values for history and the independent SSE subgroup. Do not add SSE imports of
repository mappers. All plugin
producers and consumers update together; no internal compatibility shim is
needed. External backend parsing stays inside each plugin. Preserve terminal
handoff fencing, stable IDs, and persisted/live message agreement.

The mapper also logs the entire failed payload, which can include known
message content, and silently swallows failure-reporter errors. Remove the
explicit raw-payload dump and make reporter failure observable while retaining
useful error/stack/event context. This is a concrete log call, not a suggestion
to suppress all diagnostics because they might contain private data.

**D2 — session events need a separate design.** The same session event type
first carries a plugin observation, then a full bridge catalog `Session` with
bridge-owned metadata after enrichment. Changing its map directly to
`PluginSession` would lose that metadata or leak it into the plugin contract.
This needs an app-owned normalized session-notification boundary and careful
listener/terminal-handoff accounting. Defer it as an estimated 1,200–2,400-line
cross-layer follow-up; do not make D1 depend on inventing a generic event envelope.
The residual session parsing helper remains until that work is justified.

**D3 — unused event transport.** OpenCode alone produces these internal groups:
PTY created/updated/exited/deleted (4), file watcher (1), LSP (2), MCP (2),
installation (2), workspace (2), worktree (2): **15 variants**. Core passes them
through normalization and wire mapping; current client production references
are null-routing or ignored-case lists. Public v1.8.2 has the same no-op uses.
Keep toast, VCS, file-edited, command/options, and lifecycle signals with real
consumers. No traffic volume or latency reduction has been measured.

Stop generating unused internal events at the OpenCode mapper; delete the
unused internal union cases and forwarding branches. Keep generated external
OpenCode API models and released public wire decoders. Confirm older supported
public clients have no meaningful consumer before suppressing each category;
retain any category with a real published consumer. Exhaustive switches remain
exhaustive; wildcarding long ignore lists is not the cleanup.

**D4 — query only what the owner uses.** Both production callers of
`SessionRepository.getStoredSessionsByBackendIds` need only the stable ID;
the event normalizer calls it even for normal part deltas. Today it builds full
stored-session objects. Replace this bulk helper with a DAO/repository
backend-ID-to-stable-ID projection, retaining plugin scoping and optional-ID
semantics. Full-session methods with real consumers remain.

[ProjectRepository.getActivities](../bridge/app/lib/src/repositories/project_repository.dart)
reads all projects then filters the requested set for
[ProjectActivityService](../bridge/app/lib/src/services/project_activity_service.dart).
Push scope and required timestamp columns into the DAO query. The singular
`getActivity` has no callers and can be removed. These simplify work by
construction; neither warrants a new cache or an unmeasured speed claim.

## E. Smaller findings retained from the first pass

### E1. One thumbnail storage implementation

Sources:
[mobile storage](../client/app/lib/core/platform/flutter_attachment_thumbnail_storage.dart),
[desktop storage](../client/desktop/lib/core/platform/desktop_attachment_thumbnail_storage.dart),
[mobile temporary-directory client](../client/app/lib/core/platform/temporary_directory_client.dart),
[desktop temporary-directory client](../client/desktop/lib/core/platform/desktop_temporary_directory_client.dart).

After normalizing platform class/import names and excluding comments and blank
lines, the storage implementations share 115 lines out of 118 mobile and 116
desktop lines. Both implement atomic writes, path validation, metadata reads,
entry deletion, and account-scope deletion. The directory clients repeat the
same cached-future lookup and retry-after-failure logic; mobile additionally
exposes voice warm-up.

The test copies have already drifted:
[mobile](../client/app/test/core/platform/flutter_attachment_thumbnail_storage_test.dart)
tests active-write/listing overlap and failed replacement cleanup, while
[desktop](../client/desktop/test/core/platform/desktop_attachment_thumbnail_storage_test.dart)
does not include those cases. This is a maintenance gap, not evidence that the
desktop implementation currently fails them.

`listMetadata` also deletes abandoned `.tmp-` files. That makes a read operation
compete with writes and requires a static `_activeTemporaryPaths` registry in
each implementation. Normal writes already clean their temporary file in
`finally`. The extra sweep primarily repairs residue from interrupted writes.
An occasional temporary cache file does not justify maintaining this registry
on every write and consulting it on metadata reads.

Recommended boundary: one shared implementation for this native filesystem
capability, with platform directory resolution behind its existing injectable
seam. Keep `module_core` free of Flutter dependencies and avoid a new generic
storage framework. Metadata reads can ignore temporary files; normal writes
still clean up their own temporary files. Account-scope deletion must continue
to remove the entire directory, including temporary residue.

Preserve atomic replacement, unique temporary names for concurrent writes,
safe path segments, existing cache directory/key conventions, asynchronous
filesystem operations, and account retirement. Keep mobile voice warm-up and
failed-directory-lookup retry behavior. Validate one shared storage suite and
both shell compositions; run the existing image repository and voice tests
affected by directory-client wiring.

### E2. Measure whole-cache pruning on thumbnail downloads

Sources:
[`MessageImageRepository._loadStoredData` and `_writeAndPruneThumbnail`](../client/module_core/lib/src/repositories/message_image_repository.dart),
the storage implementations above, and
[image repository tests](../client/module_core/test/repositories/message_image_repository_test.dart).

A successful uncached thumbnail load awaits `_writeAndPruneThumbnail` before
returning its result. After each write, that method lists the entire account
cache, obtains metadata for every file through the storage adapter, sorts all
entries, totals their sizes, and then applies the 64 MiB budget.

For sequential cache growth with no eviction, N successful thumbnail downloads
therefore inspect approximately `N * (N + 1) / 2` file entries, plus repeated
sorting. Concurrent downloads can also overlap whole-cache scans. This is a
source-level cost model, not a timing measurement. The byte limit does not
provide a small bound on the number of thumbnail files.

First measure metadata-call counts and completion time with a populated cache.
Then make pruning bounded maintenance in the existing repository rather than
an obligatory complete scan per result. Prefer a small batching/coalescing or
rate-limiting change over a persistent index, new database, or timer service.
The exact trigger should follow the measurement and keep the byte budget
eventually enforced under sustained writes.

Preserve immediate account retirement, write-generation fencing, cache
corruption recovery, and original-image non-persistence. Any deferred work must
retain observable errors and be covered by existing shutdown/account cleanup.
Account isolation is not an acceptable tradeoff for faster pruning.

### E3. One optimistic rename state machine

Sources:
[`_ProjectRenameState`](../client/module_core/lib/src/cubits/project_list/project_list_cubit.dart),
[`_SessionRenameState`](../client/module_core/lib/src/cubits/session_list/session_list_cubit.dart),
and [`RenameSheet._save`](../client/module_app_ui/lib/src/widgets/rename_sheet.dart).

The two private classes implement the same pending-token map, latest visible
intent, confirmed value, and failure selection algorithm, with `name` versus
`title` vocabulary. Every future correction needs parallel edits.

Do not replace this with unconditional rollback to an old snapshot. The sheet
closes immediately after starting the request, so a user can reopen it and
rename again before the first request settles. The existing cubit tests cover
failed overlapping requests, nullable original values, and an older request
succeeding after a newer request fails.

Extract only the common rename bookkeeping into a narrowly scoped client-core
owner. Keep project/session repository calls, list projection, refresh policy,
and UI decisions in their existing owners. Do not introduce a generic optimistic
mutation framework or merge the two cubits. Existing
[project tests](../client/module_core/test/cubits/project_list/project_list_cubit_test.dart)
and [session tests](../client/module_core/test/cubits/session_list/session_list_cubit_test.dart)
provide the relevant behavior checks.

### E4. Compose existing locks for session-operation ordering

Sources:
[`SessionOperationDispatcher`](../bridge/app/lib/src/services/session_operation_dispatcher.dart),
[`ParallelLock` / `KeyedParallelLock`](../bridge/sesori_bridge_foundation/lib/src/parallel_lock.dart),
[`PendingOperations`](../bridge/sesori_bridge_foundation/lib/src/pending_operations.dart),
and [dispatcher tests](../bridge/app/test/bridge/services/session_operation_dispatcher_test.dart).

The dispatcher hand-rolls a resolution tail, family-lane tokens, in-flight
settlements, removal callbacks, and drain handling. Foundation already owns
FIFO serialization, keyed serialization, and tracking/draining primitives.
This is a better consolidation target than adding another queue abstraction.

Keep two distinct requirements: family resolution is admitted in arrival
order, while operation bodies serialize only within a family. An unrelated
family must run while another family is blocked. Register the family operation
before releasing resolution ordering, without awaiting its entire body under
the global resolution lock.

Preserve immediate rejection after shutdown starts, idempotent drain, release
after failure, and errors delivered to the original caller. In particular,
`PendingOperations.drain` propagates failures whereas current dispatcher drain
waits for settlements without rethrowing operation errors; it is not a drop-in
replacement without preserving that semantic difference. Do not combine this
cleanup with changing family resolution or archive/delete semantics.

### E5. Share managed-install construction, not whole descriptors

Sources: `installRuntime` in the
[Codex](../bridge/sesori_plugin_codex/lib/src/runtime/codex_plugin_descriptor.dart),
[OpenCode](../bridge/sesori_plugin_opencode/lib/src/runtime/open_code_plugin_descriptor.dart),
[Copilot](../bridge/sesori_plugin_copilot/lib/src/runtime/copilot_plugin_descriptor.dart),
and [DeepSeek](../bridge/sesori_plugin_deepseek/lib/src/runtime/deepseek_plugin_descriptor.dart)
descriptors, plus
[`ManagedRuntimeInstallService`](../bridge/sesori_plugin_runtime/lib/src/provisioning/managed_runtime_install_service.dart).

Descriptors repeatedly construct the same HTTP client, downloader, checksum
validator, extractor, installer, and cleaner graph and close the HTTP client in
`finally`. Share the operation-scoped construction and ownership where this
removes code across the actual callers. Existing installer orchestration is
already shared; another forwarding-only layer would not help.

Preserve per-plugin manifests, probe limits, validators, asset resolution,
setup/authentication interpretation, and attach-mode behavior. For example,
Copilot bounds captured installer command output while the inspected Codex and
OpenCode paths do not. Do not silently standardize such choices during an
extraction. Assess every managed-install descriptor, but leave unsupported or
externally installed harnesses alone.

## Disposition and deliberately retained complexity

The [plan](../.plan/active/periodic-cleanup/PLAN.md) prioritizes A, B, C and D1/D3/D4,
then E1/E3/E5. E2 remains a measurable cost hypothesis; E4 is valid duplication
but a correct ordering boundary is not worth churn solely to save a few queue
fields. D2 needs separate architecture scope. These are explicit deferrals,
not claims that the code is already clean.

Keep authentication/account retirement, generation fencing, released wire
defaults, session-family ancestry integrity, and atomic cache writes. Their
consequences are materially different from an abandoned thumbnail temp file.
No evidence here establishes that removing those defenses would be safe.
Project/session viewing trackers also have different event contracts; a common
policy framework would increase complexity. Large-file size alone still does
not justify splitting the orchestrator, session cubit, or ACP implementation.
