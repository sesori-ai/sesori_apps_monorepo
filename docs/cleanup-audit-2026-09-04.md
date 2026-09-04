# Periodic cleanup investigation — 2026-09-04

Baseline: `480d82f090` on `purple-heron`.

The best next cleanup is the client thumbnail cache. It combines nearly
identical mobile/desktop implementations, tests that have diverged, and
maintenance work on the image-loading path. Consolidate the implementations
first; measure and reduce pruning work separately. Avoid a repository-wide
rewrite or a generic framework for all similar-looking services.

This is an investigation, not an implementation plan or a completed refactor.
No production behavior, database schema, or transport contract changes here.

## Scope and evidence

- Scanned 1,462 hand-written Dart files under production `lib/` directories
  across bridge, client, and shared packages. Excluded generated models, DI,
  database steps, and localization files. File size and repeated 15-line
  windows were used to select areas for inspection, not to judge quality.
- Read the relevant ownership rules, then inspected selected implementations,
  production callers, existing tests, and recent Git history. This is a broad
  structural scan with targeted source review, not a line-by-line review of
  every file or a complete security audit.
- Investigated thumbnail storage and loading, optimistic rename state,
  session-operation ordering, runtime installation composition, options-cache
  writes and invalidation, event handling, and viewing trackers.
- Tests cited below were inspected, not executed. No performance benchmark or
  end-to-end reproduction was performed; distinguish source-level costs and
  maintenance findings from measured latency or demonstrated runtime failures.

## Recommended cleanup candidates

| Priority | Candidate | Evidence strength | Approximate scope |
| --- | --- | --- | --- |
| 1 | Share thumbnail storage and temporary-directory lookup; remove abandoned-temp sweeping from metadata reads | Confirmed duplication and unnecessary coupling | One moderate PR, roughly 10–14 source/test/DI files |
| 2 | Reduce whole-cache pruning on image loads | Confirmed repeated filesystem work; latency unmeasured | Separate moderate PR, roughly 3–5 files including focused measurements/tests |
| 3 | Share optimistic rename bookkeeping | Confirmed duplicate state machine and real overlapping callers | Small/moderate PR, roughly 4–6 files |
| 4 | Reuse existing queue primitives in session dispatch | Confirmed parallel implementations; replacement needs ordering verification | Moderate PR, roughly 2–4 files |
| 5 | Share managed-install dependency composition | Confirmed repeated construction; plugin differences remain important | Moderate PR across runtime and applicable plugin descriptors |

These estimates are review boundaries, not commitments to touch every file or
introduce a new class. Each implementation must earn its size through removed
duplication or simpler ownership.

### 1. One thumbnail storage implementation

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

### 2. Stop pruning the entire cache for every downloaded thumbnail

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

### 3. One optimistic rename state machine

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

### 4. Compose existing locks for session-operation ordering

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

### 5. Share managed-install construction, not whole descriptors

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

## Complex areas that do not yet justify a rewrite

- **Options cache:**
  [`SessionOptionsService`](../bridge/app/lib/src/services/session_options_service.dart)
  contains repeated epoch/path checks and two-attempt compare-and-set recovery.
  Its single production composition and per-key refresh coalescing make the
  retry machinery worth a separate audit. However, cache-only reads can delete
  invalid/expired rows, stale-send rejection deletes immediately, and moved
  project paths can address the same persisted owner through different cache
  keys. Do not conclude that there is only one effective writer or remove
  conditional deletes from a text search. The existing conflict tests inject
  replacement rows directly; they document behavior but do not alone prove
  that every simulated interleaving has a production caller. A focused review
  should identify each real conflicting flow and remove only surplus recovery.
- **Session-family resolution:**
  [`resolveSessionFamily`](../bridge/app/lib/src/repositories/session_repository.dart)
  walks ancestry and checks depth, cycles, and plugin identity. This may be
  expensive for deep trees, but archive/delete and child-session ownership have
  material integrity implications. No recommendation to remove those checks
  without establishing the writers' guarantees and measuring normal depth.
- **Large files:** orchestrator, session-detail cubit, and ACP plugin size alone
  is not an extraction justification. No file-length-driven split is proposed.

## Apparent cleanup opportunities deliberately rejected

- Replacing long ignored-event case lists with wildcard defaults conflicts with
  the repository's
  [exhaustive-switch lint](../shared/no_slop_linter/lib/src/rules/prefer_exhaustive_switch_rule.dart).
  Those lists provide compile-time prompts when the event contract grows.
- Project and session viewing trackers have similar maps but different event
  contracts: aggregate project-set changes versus each connection's session
  view start. A generic tracker would need policy machinery for this difference.
- Auth/account cleanup, plugin generation fencing, archive integrity, and
  published client/bridge compatibility are not low-benefit defenses merely
  because their code is long. This investigation establishes no basis for
  weakening them or removing released wire defaults.
- Backend-specific setup and event normalization stay inside their owning
  plugins; superficial similarities do not justify shared backend knowledge.

## Suggested decision

Start with candidate 1 as a focused refactor, then use measurements to decide
candidate 2. Candidates 3–5 can be independent small review scopes. Keep the
options-cache and session-family questions as investigations rather than
pre-approved deletions. Architecture-bearing implementations require the
repository's scoped architecture reviews; this documentation-only audit does
not.
