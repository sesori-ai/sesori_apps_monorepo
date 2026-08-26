# Projects And Sessions

## Capability

Browsing the durable project catalog and its sessions: opening, renaming, and
hiding projects, importing a plugin's existing sessions, and listing root and
child sessions with titles, activity, statuses, and unseen state.

## Required Behavior

- Catalog list summaries contain only durable fields from the bridge database:
  no backend start, no blocking on an in-progress import, no filesystem or Git
  inspection, always the last committed snapshot. A selected project receives
  real capability checks, bounded across concurrent requests. A failed check
  blocks creation with an explicit retry instead of being treated as
  unsupported, and dedicated-worktree support is revalidated when a dedicated
  session is created.
- Backends that own projects supply the list; the bridge derives it for backends
  without a project concept. Both appear as ordinary projects.
- A backend-native project identifier is stable and independent of its directory,
  so a moved folder keeps identity, sessions, and overrides. For bridge-derived
  project ownership, a normalized session directory becomes the identity when no
  existing binding applies; discovery after a move therefore creates a new project
  rather than mutating the old one. An unknown catalog identifier is never
  interpreted as a path.
- Opening validates the path and surfaces the git-initialization choice. Hiding
  delists without destroying sessions or history. Import is explicit, per
  plugin, atomic, non-destructive, cancellable, and attributes progress.
- A completed import reports both the totals it published and, separately, how
  much of that was new. The two are not interchangeable: a re-import of an
  unchanged catalog still publishes every row, so the totals stay at the full
  catalog size while the delta is zero. The delta is one optional group, so a
  producer that does not report it is distinguishable from one reporting that
  nothing changed; a consumer that cannot tell them apart would announce
  "nothing new" after an import that added everything. A headless completion
  line therefore states the delta, or `Nothing new.`, or the totals alone when
  the producer omits the delta.
- A user can start an import from the app. The three list surfaces — the
  project list, the full-screen session list, and the wide split-view pane —
  offer it as a second, deeper stage of their pull, which invites itself with a
  caption once the ordinary trigger is passed and commits at the deeper one
  while the finger is still down. It covers every harness the bridge reports as
  routable, which is not the same as enabled: a blocked or failed harness is
  refused by the bridge and is left out. The harness settings surface offers the
  same import for one named harness.
- One scan is one row above the list, however many harnesses take part. Between
  dispatch and the first progress event it can name neither a harness nor a
  count and says only that it is starting; from that event on it names the
  harness being read and how many sessions it has seen so far. It offers to
  cancel while it runs. The row keeps one height throughout, so the first
  progress event does not move the list, and it scrolls with the list rather
  than pinning.
- A scan the pull started is reported by that row alone: the pull raises no
  confirmation of its own, having run no ordinary refresh. A scan started from
  harness settings is the exception, because that surface has no row — it
  announces how the run ended, once, and only for a run it started itself.
- A finished scan says what it found, sessions first, and clears itself shortly
  after. Everything else waits to be dismissed: some harnesses failing, all of
  them failing, a bridge too old to import at all, and no harness available to
  read. A diagnostic the user did not get to read is worse than a row that
  outstays its welcome. Losing or regaining the connection clears any row,
  waiting or not, as does the connected bridge turning out to be a different
  machine — none of those rows describes a run this bridge is still party to.
- What a scan reports is what was new, not what was published. When any harness
  in the run omits its delta the whole row falls back to naming published
  totals instead, because a delta missing one harness's contribution would
  understate the result while still reading as authoritative. A clause counting
  nothing is dropped rather than joined.
- A scan that the client did not start, or did not see the whole of, settles
  without claiming a summary. Reconnecting seeds only from imports still in
  flight: the bridge retains terminal statuses indefinitely, so reading them
  back would announce a stale success on every connect.
- Every observed `CatalogImportCompleted` that publishes at least one project
  or session invalidates mounted project and session lists only after the
  bridge's atomic catalog transaction completed. An automatic hydration marker
  publishes zero rows and never interrupts an ordinary list read. A pre-commit
  list response cannot overwrite a later snapshot; another completion while it
  is loading produces one trailing read. If the snapshot fails, the committed
  change remains pending for the next ordinary, reconnect, or staleness refresh
  rather than being discarded. A failed forced snapshot replaces a full-screen
  load it superseded instead of leaving a spinner, and a superseded pull waits
  for the winning snapshot's result; a session pull keeps its bounded PR-data
  wait. A stale superseded read cannot rearm a failed change. Cancelling hides
  the progress row immediately, but a transaction already in progress that
  completes after that cancellation still drives the same list refresh.
- Project and session row actions remain swipeable without competing visually
  with system back navigation. On iOS, drags beginning in the row's leading 10%
  are reserved for back; on Android gesture navigation, both 10% edges are
  reserved. Android button navigation and other platforms retain the full row
  as a swipe target.
- Pull-to-refresh provides visible drag and in-flight feedback in both the
  full-screen lists and the wide split-view session pane. The refresh itself is
  dispatched when the pull is let go, not when it crosses the trigger, so the
  gesture has already chosen its stage by the time anything runs. On every
  platform, releasing an ordinary pull while its refresh is pending keeps the
  pane content displaced and its Cupertino indicator visible, and reports the
  outcome when it settles.
- A pull that crossed the deeper catalog-scan threshold runs no ordinary refresh
  at all: the scan reaches the same backend and settles into a list refresh of
  its own. It stops holding the content the moment that stage fires and shows
  neither indicator nor caption afterwards, because the scan row is the only
  report from then on. A pull that finds no harness to scan therefore reports
  that and leaves the list as it was.
- A session created in a dedicated worktree receives a system prompt identifying
  that worktree, its initial branch, and base branch. The prompt requires all
  work to remain in that worktree, while permitting use of the initial branch,
  branch switches, and new branches within it.
- When dedicated-worktree creation falls back, the session runs in the fallback
  directory and persists as in-place with the resolved HEAD base commit, not as
  a dedicated session without a worktree.
- Session listings are project-scoped and pageable and carry plugin attribution,
  times, worktree and branch facts, prompt defaults, and unseen state that
  advances on activity and clears on view or mark-as-read.
- A listed session's `session.updated` reports the newest instant the bridge
  knows: the backend's own updated time, or the live user-message marker when
  that is newer. A plugin that reports an updated time only at import or rename
  — Claude and Pi, unlike Codex, ACP, and OpenCode — therefore still shows a
  recently prompted session as recent, instead of the transcript time read at
  the last import. Marking a session unread never moves that time, and
  assistant-only work does not advance it past the prompt that started it.
- A newly committed session can list before generated metadata. Later generated
  title and eligible dedicated-branch refinement reuse `session.updated`; lists
  and detail adopt the durable session facts without marking unseen or moving the
  worktree directory. The initial system prompt remains truthful about the
  directory and branch that existed when the backend session was created.
- Pi import discovers persisted JSONL sessions from its inherited environment,
  configured storage, default per-project storage, and bridge-known directories.
  Enumeration is metadata-only and bounded: it reads session headers and
  explicit `session_info` names, uses file modification time for activity,
  preserves resolvable parent-session lineage, and never decodes transcript
  messages to derive titles.
- Running root sessions remain ahead of inactive roots and order by the latest
  durable user-side activity marker, descending, then session ID. Projects with
  running roots likewise remain ahead of inactive projects and order by the
  latest effective activity among their running roots, then project ID. Running
  means main-agent work, retry, or a background task; awaiting-input alone does
  not promote a session or project. A missing root marker falls back to that
  root's updated time; an older bridge omitting active-root ordering facts falls
  back to the project's updated time. Inactive roots retain updated-time order,
  then session ID; inactive projects retain updated-time, effective-name, then
  ID order. Archived filtering and child-session ordering are unchanged.
- REST seeds the marker and live list-state patches reorder an already-running
  session and its running project without another status event or project
  summary. A current client accepts an older bridge omitting the marker and
  active-root ordering facts and uses the documented updated-time fallbacks;
  null facts remain omitted on the wire. Activity markers merge monotonically
  across live session updates and REST refreshes without preventing authoritative
  unseen or project aggregate replacement.
- Statuses report per-session idle/busy/retry plus unavailable plugins. A
  payload without plugin attribution means the historical OpenCode identity,
  never "the first enabled plugin".
- Project and session rename sheets start from the current display name, reject
  a blank trimmed value, prevent duplicate submission while saving, and show
  success or failure feedback without losing the failed edit.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, representative plugin: project list and one project's session list return committed data with plugin attribution. |
| L2 Routine | Headless bridge, representative plugin: open, rename, hide; create a session and see it listed before metadata, then observe generated title and eligible branch refinement through the existing session update without unseen change; unseen otherwise advances and clears; the existing activity marker appears in REST and live list-state projections; statuses report idle/busy. A first import reports every published row as new, a re-import of an unchanged catalog reports the same totals with a zero delta, and a completion whose delta is absent reports its totals without claiming nothing changed. Focused client coverage holds pre-commit list reads through a completion, ignores a zero-count hydration completion, proves the post-commit snapshot wins and a second completion gets a trailing snapshot, retains a failed snapshot for the next refresh, proves an interrupted full-screen load and pull surface the winning failure while retaining session PR-data waiting, and covers a completion after immediate cancellation. Focused client coverage also proves the deeper pull starts one scan however far it travels, that a pull which fired it runs no ordinary refresh and raises no confirmation while an ordinary pull still does, that the row keeps one height from starting through running to its result, and that a scan started from harness settings is announced there while one started elsewhere is not. |
| L3 Release | Client end to end (phone): every supporting production plugin still covers native/derived ownership, import, and child resolution; Pi imports configured/default/known roots with explicit names and resolvable lineage; one representative plugin proves two running roots and two projects with running roots reorder after committed user-side activity, inactive session/project order is unchanged, a live patch reorders without another status event or project summary, and omitted ordering facts use updated-time fallbacks. Focused ACP protocol and client ordering tests prove the exact awaiting-only state is not promoted because normal production root prompts remain running while awaiting input. Lists and unseen badges render; project and session row swipes stay inert from the iOS back edge and both Android gesture-navigation edges while remaining active at unreserved edges and under Android button navigation. A catalog scan started by the deeper pull renders its row through starting, running, and its result on one mobile platform and in the wide split-view pane, which drives its pull through a different scroll owner; two *routable* harnesses at once, so the fan-out has two members and a partial failure is reachable at all — enabled is not enough, since a blocked or failed harness is enabled and still left out; one native-ownership and one bridge-derived harness, which count new projects differently; and one run that genuinely imports a new session, visible in the list without a second manual refresh. |
| L4 Extended | Relay integration, every supporting production plugin: bridge and plugin restart preserve identity and overrides; a moved backend-native project keeps them while a moved bridge-derived project is discovered as new without mutating the old catalog; a cancelled or failed import leaves the prior catalog intact; reads during import stay consistent; an unavailable plugin is reported while others keep listing. Scanning against older and interrupted peers: a bridge that omits its new-item delta falls back to totals rather than reporting nothing new; a supported bridge with no import route at all reports that it cannot scan; a bridge holding terminal import statuses is reconnected to without announcing a stale success; a disconnect mid-scan reconnects and settles without claiming a summary; and a bridge whose harnesses are all blocked reports that there is nothing to scan. |
| L5 Full | Client end to end, every supporting production plugin: multiple clients observe consistent listings and unseen transitions; large catalogs and paged listings behave; unattributed payloads resolve to the historical identity. |

## Exploration Guidance

Vary the owning plugin, manual open versus import discovery, git and non-git
folders, and whether the directory moved between runs. Alternate empty,
child-only, and large projects, and reorder import, listing, creation. Remove
disposable sessions and projects and restore hidden-state changes afterwards.
For activity order, vary REST versus live delivery, null versus populated
markers, ties, awaiting-only versus running state, and assistant/tool updates
after a marker has been established.
For list-row swipes, alternate iOS, Android gesture navigation, Android button
navigation, and a non-mobile platform; begin drags inside and just outside each
10% edge buffer.
For catalog scanning, vary the number of enabled harnesses, whether any is
blocked or failed, and which surface starts the run — each of the three lists
and the harness settings card. Vary a first import against a re-import of an
unchanged catalog, and a bridge that reports its delta against one that omits
it. Interrupt runs: cancel mid-scan, disconnect mid-scan and reconnect, and
leave the surface that started one. Restore harness eligibility afterwards.

## Failure Signals

- A catalog read starts a backend, hangs on import, returns a partial list, or an
  older response overwrites a post-commit snapshot.
- A zero-count hydration completion interrupts an ordinary list read, a
  committed catalog change is lost after a failed list snapshot, a forced
  catalog failure leaves a full-screen list loading or reports a superseded pull
  as successful or without its requested PR data, or a commit that finishes
  after cancellation leaves the mounted list stale.
- A moved backend-native project appears new or empty, loses sessions, or resolves
  git in the old location; a moved bridge-derived project mutates the old catalog
  identity instead of being discovered as new.
- Sessions lose attribution, land under the wrong project, or a child lists as a
  root.
- Pi import exposes prompt/transcript text, treats it as a title, follows an
  unbounded symlink/parent tree, or loses sessions stored under a configured or
  bridge-known directory.
- A running root or project stays alphabetically ordered, a stale marker masks
  newer committed activity, a null marker fails to use updated time,
  awaiting-only is promoted, or inactive session/project or child order changes.
- A session prompted minutes ago reports a days-old updated time, or sorts to
  the top of its list while still displaying that stale time.
- Unseen never clears, clears without viewing, or an unavailable plugin is idle.
- Hiding destroys sessions, or a cancelled import destroys the committed catalog.
- A project or session row animates under a system back gesture, or an edge that
  has no active system back gesture stops accepting row actions.
- A wide session pane starts an ordinary refresh without showing or holding its
  pull indicator until the operation completes.
- A scan offered for a harness the bridge will not import from, a pull
  confirming itself beside the row reporting the same run, two rows for one
  scan, or a row whose height changes as harnesses report.
- A successful scan that never clears, a failure that clears itself, a row
  reporting totals as though they were new, or a delta claimed while a harness
  in the run omitted one.
- A reconnect announcing a scan that already finished, a recovered run claiming
  a summary it never saw, or a cancelled scan leaving its row behind.
- A bridge with no import route reported as a failure rather than as one that
  cannot scan, or a pull that finds no harness reporting nothing at all.
- A generated title/branch update fails to reach list/detail, changes unseen,
  moves the worktree, or rewrites the backend's creation-time system context.

## Known Limitations

- Client end-to-end coverage is phone-only; the desktop shell has no catalog
  surface.
- Derived lists are bounded by backend enumeration; a directory-scoped backend
  only rediscovers sessions in directories the bridge already knows.
- Only plugins registered in the build under test count.
- User-side activity is an ordering heuristic, not proof of human intent.
  Generated backend input normalized as a user message and lifecycle-generated
  replies or rejections that clear pending input can advance it.
- Markers use source event clocks. Skew between backends can misorder running
  sessions across clock domains; no second bridge-observation timestamp exists.
- A missed live patch self-heals on a later relevant event or list refresh.
- An old bridge cannot provide per-running-root ordering facts in
  `projects.summary`, so the current app falls back to project updated time.
- Untested Hermes gap (remove this entry once verified): a failed or cancelled
  in-flight Hermes import was never exercised; only completed explicit imports
  and non-destructive re-imports were verified.

## Sources

- Bridge: `bridge/app/lib/src/repositories/` (project, session, derived session),
  `bridge/app/lib/src/services/project_*`,
  `bridge/app/lib/src/services/catalog_import_service.dart`, and catalog and
  session handlers in `bridge/app/lib/src/routing/`
- Contract: `bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart`
- Client-triggered scanning: `client/module_core/lib/src/services/catalog_rescan_service.dart`,
  `client/app/lib/core/widgets/catalog_scan_row.dart`,
  `client/module_prego/lib/components/navigation/prego_sliver_refresh_control.dart`
- Pi metadata catalog: `bridge/sesori_plugin_pi/lib/src/api/pi_session_storage_api.dart`,
  `bridge/sesori_plugin_pi/lib/src/repositories/pi_session_catalog_repository.dart`
- Tests: `bridge/app/test/bridge/routing/catalog_read_handlers_test.dart`,
  `bridge/app/test/bridge/repositories/project_repository_test.dart`,
  `bridge/sesori_plugin_pi/test/pi_session_storage_api_test.dart`,
  `bridge/sesori_plugin_pi/test/pi_session_catalog_repository_test.dart`,
  `client/module_core/test/services/session_list_service_test.dart`,
  `client/module_core/test/services/session_unseen_tracker_test.dart`,
  `client/module_core/test/services/catalog_rescan_service_test.dart`,
  `client/module_core/test/cubits/project_list/project_list_cubit_test.dart`,
  `client/module_core/test/cubits/session_list/session_list_cubit_test.dart`,
  `client/module_prego/test/interactions/prego_swipe_actions_test.dart`,
  `client/module_prego/test/components/prego_sliver_refresh_control_test.dart`,
  `client/app/test/core/widgets/catalog_scan_row_test.dart`,
  `client/app/test/features/project_list/project_list_catalog_scan_test.dart`,
  `client/app/test/features/session_list/session_list_panel_test.dart`
- Client row swipe behavior:
  `client/module_prego/lib/interactions/prego_swipe_actions.dart`
- Plans (discovery only): `.plan/completed/multi-plugin-release-prep`,
  `setup-aware-plugin-management`, `relay-request-concurrency`;
  `.plan/active/session-user-interaction-order`
