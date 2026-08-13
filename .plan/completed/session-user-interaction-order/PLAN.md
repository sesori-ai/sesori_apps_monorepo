# Running Session And Project User-Activity Order

## Status

- **Plan slug:** `session-user-interaction-order`
- **Status:** Completed and retired
- **Plan date:** 2026-08-13
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main` at `6ee94bfe`
- **Implementation branch/worktree:** `session-user-interaction-order-verification`
- **Delivery:** four PRs: plan, implementation, regression contract,
  verification/retirement

This revision supersedes the earlier seven-step plugin-classifier design and the
intermediate proposal for a second persisted interaction timestamp. The existing
`last_user_message_at` marker is adequate for this session-list heuristic once
its current semantics are stated honestly.

## Goal

Keep running root sessions promoted at the top of a project's session list and
projects with running roots promoted at the top of the project list, but order
both running prefixes by the bridge's latest recorded user-side activity
instead of alphabetically.

The visible policy otherwise remains unchanged:

- running means `mainAgentRunning || isRetrying || backgroundTaskCount > 0`;
- awaiting-input alone does not promote a session;
- inactive sessions remain ordered by `Session.time.updated` descending;
- archived filtering remains unchanged; and
- inactive project ordering and child-task ordering remain unchanged.

"User-side activity" deliberately means the bridge's existing unseen-state
marker, not perfect human-origin provenance. It advances for normalized user
messages and question/permission reply or rejection events, and it excludes
permission replies consumed by bridge auto-approval before normal event routing.
Lifecycle cleanup also emits those normalized events when abort, thread close,
process exit, or disposal cancels pending input, so that cleanup can advance the
marker without a human reply. A backend that represents automatic compaction or
other generated input as a user message can also advance it. These are accepted
for a low-impact running-list heuristic rather than adding per-plugin inference
and correlation state.

## Complexity Budget

The implementation must stay within all of these constraints:

- no database column, schema migration, or backfill;
- no new bridge or client long-lived mutable state;
- no plugin API, classifier, or behavioral plugin change; mechanical shared
  `Session` constructor updates pass null where a plugin builds a pre-enrichment
  event payload;
- no dispatcher flag, operation hook, backend classifier, message correlation,
  dedupe collection, timer, lock, registry, or lifecycle owner;
- one existing persisted scalar projected additively onto existing REST and SSE
  shapes; and
- two client running-prefix comparators, using existing activity and list-state
  delivery; and
- nullable ordering facts added to the existing active-session summary, with no
  new route, event, cache, timer, or lifecycle owner.

If implementation exceeds this budget, stop and ask before adding machinery.

## Current Behavior And History

- `SessionListService.visibleSessions` partitions running roots using
  `SessionActivityCalculator.isRunning`, alphabetizes the running prefix, then
  appends inactive sessions by `time.updated` descending.
- `ProjectListService.orderProjects` uses the same running calculation,
  alphabetizes the running project prefix, then appends inactive projects by
  the existing project timestamp/name/ID order.
- Session rows already persist nullable `last_user_message_at`. The bridge's
  ordered `SessionUnseenService` writes it from normalized user messages and
  manual question/permission replies.
- User-message events with known creation times are idempotent: re-emissions at
  or before the stored marker are skipped. Replies without a payload time use
  the service's strictly monotonic local timestamp.
- Permission auto-approval replies are consumed in `Orchestrator` before mapping
  and therefore do not advance the marker.
- ACP abort/dispose cleanup, Codex thread-close cleanup, and Claude process-exit
  cleanup emit ordinary normalized reply/rejection events so open clients retire
  pending input. Those events currently advance the same marker and are part of
  its accepted lifecycle semantics.
- Root REST projections already read the stored row but currently expose only
  the derived `unseen` boolean. The existing `session.unseen_changed` event is
  emitted after each relevant marker write but also omits the timestamp.
- `SessionUnseenTracker` already caches that list-state patch, including events
  received while a session-list REST request is in flight, and owns the existing
  per-project tick that prevents an older REST seed from replacing live state.
- PR #474 (`578970ae3`) previously reused `last_user_message_at`, but coupled it
  to a bridge-authored project/session ordering service, retry timer, summary
  snapshots, and cross-layer order flags. PR #480 (`c302c5df3`) reverted that
  entire pipeline to restore prior ordering. PR #482 (`ddfd6d1a6`) then
  established the current simpler client-owned running prefix. The historical
  problem was the oversized ordering pipeline, not the persisted scalar.

## Design

### Reuse the existing marker

Expose the stored row's `lastUserMessageAt` as nullable
`lastUserActivityAt` on shared `Session` and the existing
`SesoriSseEvent.sessionUnseenChanged` variant.

The product-facing name describes how the value is used without renaming the
released database column or changing unseen semantics. Do not add the misleading
`lastUserInteractionAt` name, which would imply stronger human provenance than
the source provides.

- `SessionCatalogMapper` and stored enrichment map `lastUserMessageAt` into the
  shared field for root/detail projections.
- `SessionUnseenService` includes the row's committed marker in `UnseenChange`;
  the orchestrator adds it to the existing patch.
- Delete patches carry null because the row no longer exists.
- Shared null omission keeps new-bridge/old-app payloads additive, and missing
  fields from old bridges decode as null.
- Plugin-originated session DTOs remain unaware of the field; bridge enrichment
  adds the durable value after the normalized plugin boundary.
- Existing ACP and Codex mappers that directly construct shared `Session`
  payloads pass `lastUserActivityAt: null`. These are required mechanical
  constructor updates only; plugins neither derive nor own the marker.

No write path changes. Existing timestamp ordering, idempotence, auto-approval
filtering, and persistence preservation remain authoritative.

### Extend the existing list-state cache

Extend `SessionUnseenTracker`'s per-session value from a bare unseen boolean to a
small typed list-state value carrying:

- `unseen`; and
- nullable `lastUserActivityAt`.

This is not another cache or state machine. It replaces the value already stored
under the same project/session maps and reuses the same stream, subscription,
tick, seeding, optimistic unseen update, and disposal lifecycle.

Live patches replace `unseen` and max-merge a non-null activity timestamp with
the cached timestamp. REST seeding replaces project membership only when the
existing tick guard permits it and seeds each session's timestamp from the
fetched `Session`. A local mark-read/unread changes only `unseen`, retaining the
cached activity timestamp.

The two test fake implementations update in lockstep; no product shell owns
business logic.

### Client ordering

`SessionListCubit` continues orchestrating only. It reads the current tracker
map and passes it with the current activity map to `SessionListService`.
Its tracker subscription must call `_emitFiltered` so a committed activity
patch re-runs the comparator even when the session was already running and no
separate status event follows. Retain the existing `SessionListLoaded` guard
before calling `_emitFiltered`: the tracker's seeded `BehaviorSubject` replays
during initial loading and must not replace the loading state with an empty
loaded list. Replace only the current loaded-state unseen update after that
guard; do not add another subscription or stream.

`SessionListService.visibleSessions` keeps its existing partition. For running
roots, compare:

1. `lastUserActivityAt ?? session.time?.updated ?? 0`, descending; and
2. session ID ascending for deterministic ties.

For inactive roots, retain `time.updated` descending and add the same ID
tie-breaker. A running session with no marker therefore has useful old-bridge
and pre-activity behavior without requiring a backfill. Once it has a marker,
assistant/tool/title updates do not move it because the comparator prefers the
marker over `time.updated`.

Do not add optimistic interaction timestamps on send acceptance. The normalized
event and existing patch are the authority; the list reorders when that event is
committed, and reconnect/refresh self-heals a missed patch.

### Project ordering follow-up

The project list follows the same policy without adding project-owned marker
state. Extend each existing `ActiveSession` in `projects.summary` with nullable
`lastUserActivityAt` and `updatedAt` facts from its durable bridge
session binding. The bridge does not calculate project order and plugins remain
unaware of both fields.

`SseEventTracker` carries those two nullable facts alongside the existing root
activity status. `ProjectListService.orderProjects` keeps its current partition.
For each running project, compare the maximum effective value among only its
running roots:

1. the newer committed marker from `SessionUnseenTracker` and the active
   summary, when either is present;
2. otherwise that active root's updated time;
3. otherwise the project's updated time; and
4. project ID ascending for deterministic ties.

Inactive projects retain the existing `Project.time.updated`, effective name,
and ID order. Awaiting-input alone still does not promote either a session or a
project.

`ProjectListCubit` reuses its existing `SessionUnseenTracker` dependency and
subscribes to the tracker's existing per-session stream so a committed marker
re-runs project ordering while status remains unchanged. No additional cache or
business state is introduced.

## Compatibility

- **New bridge, old app:** extra nullable keys on known REST/SSE shapes are
  ignored; that app retains its current alphabetical running order.
- **Old bridge, new app:** omitted fields decode to null and running order falls
  back to session or project `time.updated` as available.
- **Existing databases:** no migration; every current marker remains intact.
- **Internal packages:** shared, bridge, and clients update together; no plugin
  contract changes.

No new route, event variant, capability, or compatibility shim is added. The
existing `projects.summary` shape gains only nullable keys that old apps ignore.

## Accepted Limitations

- Automatic compaction or generated backend input normalized as a user message
  can move a running session. The marker is explicitly user-side activity, not a
  proof of human intent.
- Lifecycle-generated permission replies and question rejections used to clear
  pending UI can move a running session after abort, thread close, process exit,
  or disposal. They retain their existing unseen-routing semantics; this plan
  does not add plugin-specific origin metadata to distinguish them.
- Markers carrying backend event times are comparable only when those backends
  share a sufficiently aligned clock domain. A remote or clock-skewed backend
  can pin one running session above or below genuinely newer activity from
  another clock domain. Existing within-session clamping protects unseen state,
  not cross-session chronology. This bounded ordering limitation is accepted
  instead of adding a second bridge-observation scalar or changing released
  unseen timestamp semantics.
- Direct laptop/backend activity counts only when the backend exposes it through
  the existing normalized user-message/reply events. No effort is made to infer
  activity a bridge-owned process cannot observe.
- A new app connected to an old bridge, and a session whose marker is still
  null, falls back to `time.updated`.
- An old bridge also omits active-root ordering facts, so a running project
  falls back to its project updated time. This is useful but less precise than
  current bridge data when inactive activity also advanced that project.
- A patch missed across disconnect reorders on the next relevant event or list
  refresh; no replay repair or optimistic timestamp is added.
- Server-paged third-party root requests retain server order. The current app
  fetches the complete project list and owns activity-aware visible order.

These are bounded list-order effects with natural refresh recovery. They do not
justify new persistence, classifier state, or cross-plugin coordination.

## Cleanup Assessment

- Remove `_compareSessionsByTitleAndId` and `_compareProjectsByNameAndId`, and
  replace alphabetical-running tests.
- Update `session.unseen_changed` and tracker documentation to describe their
  complete session-list state payload.
- Keep `last_user_message_at`, its existing write logic, unseen calculations,
  and persistence tests unchanged; they remain required production behavior.
- Do not restore `ActiveWorkSummaryService`, `userInteractionOrdered`,
  bridge-owned project reordering, or any prototype plugin event/origin changes.

No other service, cache, field, setting, job, or transport variant becomes
obsolete.

## Delivery Plan

The final step uses the existing `session-user-interaction-order-verification`
branch/worktree. Prior step branches are recorded in the tracker.

### Step 1/4 - Plan

**Exact PR title:**
`🌱 [session-user-interaction-order] docs: simplify running session activity order [step 1/4]`

- Publish this revised plan and tracker.
- Update the plan-maker skill to require existing-state/history inspection and
  explicit mutable-part budgeting.
- Record why the seven-step classifier design and second-scalar proposal were
  superseded.
- No production, database, wire, generated, or user-visible change.

**Changed-line target:** 350-650 documentation lines.

### Step 2/4 - Coherent implementation

**Exact PR title:**
`⚙️ [session-user-interaction-order] feat: order running sessions by user activity [step 2/4]`

- Add nullable `lastUserActivityAt` to shared `Session` and
  `session.unseen_changed`, then regenerate shared source.
- Project `last_user_message_at` through bridge REST and post-write patch seams.
- Add required null arguments to existing ACP/Codex shared `Session`
  constructors without changing plugin behavior or marker ownership.
- Replace the existing unseen tracker value with typed session-list state while
  retaining its one cache/tick/subscription lifecycle.
- Replace alphabetical running order with activity recency and stable ties.
- Test additive JSON, bridge projections/patches, tracker retention, initial and
  in-flight REST behavior, comparator fallback, and unchanged inactive/activity
  policy.
- Verify there is no database schema or production plugin diff.

This is one coherent PR because transport without a consumer or a comparator
without the bridge fact would be dead intermediate behavior. Generated shared
source is expected; no Drift generation occurs.

### Step 3/4 - Regression contract

**Exact PR title:**
`🌱 [session-user-interaction-order] docs: define running session activity coverage [step 3/4]`

- Update `docs/regression/projects-and-sessions.md` with running-root activity
  ordering, null fallback, live patching, and accepted generated-input semantics.
- Update `docs/regression/session-turns.md` and
  `docs/regression/questions-and-permissions.md` only where needed to identify
  the existing normalized actions feeding the marker and auto-approval exclusion.
- No production, database, wire, generated, or new user-visible change.

### Step 4/4 - Verify and retire

**Exact PR title:**
`⚙️ [session-user-interaction-order] feat: order active projects and verify activity ordering [step 4/4]`

- Carry durable marker and updated-time facts through the existing active-root
  summary and order running projects by their latest running-root activity.
- Reuse the existing session list-state stream for live project reordering while
  preserving awaiting-only and inactive project behavior.
- Update regression coverage for project and session ordering.
- Run cumulative L3 coverage below.
- Record privacy-safe evidence and accepted limitations.
- Move the plan to `.plan/completed/` only after required coverage passes.

## Verification

**Highest required level:** L3 Release, cumulative through L1/L2.

Automated proof:

- shared `Session` and known SSE event omit null on encode and accept omission on
  decode;
- bridge catalog/detail projections and committed unseen patches carry the
  existing marker without changing any write or unseen formula;
- permission auto-approval remains filtered before marker routing;
- lifecycle-generated reply/rejection events retain their documented activity
  semantics and clear pending input without new provenance state;
- tracker live max-merge, REST replacement, optimistic unseen update, initial
  load, and in-flight fetch behavior retain the latest marker;
- a tracker patch while the target is already running immediately re-runs the
  visible comparator without waiting for another status event or refresh, while
  the initial replay remains guarded until `SessionListLoaded`;
- running comparator, null fallback, deterministic ties, and unchanged inactive,
  awaiting-only, archived, inactive-project, and child ordering;
- running-project comparator, maximum across running roots, old-bridge fallback,
  and live marker reordering without another status summary; and
- Git diff proves no schema/migration or production plugin change.

End-to-end proof:

- one release-target phone and bridge host;
- one representative registered plugin, because ordering starts after the
  existing normalized event boundary and no plugin changes;
- two running roots reorder after user-side activity while inactive rows retain
  updated-time order;
- two projects with running roots follow the same activity order while inactive
  projects retain their prior order; and
- a current app connected to a pre-feature bridge that omits the marker uses the
  documented fallback.

The exact awaiting-only state is representable by an ACP idle permission
request, but normal production root prompts remain running while awaiting input.
Focused ACP protocol and client ordering tests therefore provide the
proportionate proof that awaiting-only is not promoted; no synthetic backend
flow is required for the release matrix.

No every-plugin live matrix is required. Existing plugin event normalization is
not changed or newly claimed by this work. Focused mapper analysis/tests cover
the mechanical null constructor updates in packages that directly build shared
`Session` payloads.

## Architecture Review History

The initial seven-step plan received architecture review and then accumulated
plugin-specific classifiers, correlation state, dedupe, reconnect handling, and
an every-plugin matrix. The user rejected that direction on 2026-08-13 because
the coordination machinery outweighed the list-ordering behavior.

The first simplification removed plugin logic but introduced a second persisted
scalar and bridge operation hooks. A subsequent history/data-flow audit found
that PR #474 had already demonstrated reuse of `last_user_message_at`, and that
current code still owns and maintains that field independently of the reverted
ordering pipeline. This revision therefore removes the second scalar and all
operation hooks. A fresh `architecture-plan-review` approved this revision on
2026-08-13 with no findings. It confirmed bridge repository/service ownership,
orchestrator SSE projection, existing tracker lifecycle ownership, client
comparator ownership, and additive shared-wire compatibility.

After the session implementation merged, the user identified on 2026-08-13 that
the project list's running prefix should follow the same policy. Step 4 therefore
changed from documentation-only retirement to a moderate additive follow-up.
It reuses the same durable marker and client tracker rather than introducing a
project marker or bridge-owned ordering service.
