# Projects And Sessions

## Capability

Browsing the durable project catalog and its sessions: opening, renaming, and
hiding projects, importing a plugin's existing sessions, and listing root and
child sessions with titles, activity, statuses, and unseen state.

## Required Behavior

- Catalog reads come from the bridge database: no backend start, no blocking on
  an in-progress import, always the last committed snapshot.
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
- A session created in a dedicated worktree receives a system prompt identifying
  that worktree, its initial branch, and base branch. The prompt requires all
  work to remain in that worktree, while permitting use of the initial branch,
  branch switches, and new branches within it.
- Session listings are project-scoped and pageable and carry plugin attribution,
  times, worktree and branch facts, prompt defaults, and unseen state that
  advances on activity and clears on view or mark-as-read.
- Running root sessions remain ahead of inactive roots and order by the latest
  durable user-side activity marker, descending, then session ID. Running means
  main-agent work, retry, or a background task; awaiting-input alone does not
  promote a session. A missing marker falls back to the session's updated time.
  Inactive roots retain updated-time order, then session ID; archived filtering
  and project and child-session ordering are unchanged.
- REST seeds the marker and live list-state patches reorder an already-running
  session without another status event. A current client accepts an older bridge
  omitting the marker and uses the updated-time fallback; null markers remain
  omitted on the wire. Activity markers merge monotonically across live session
  updates and REST refreshes without preventing authoritative unseen or project
  aggregate replacement.
- Statuses report per-session idle/busy/retry plus unavailable plugins. A
  payload without plugin attribution means the historical OpenCode identity,
  never "the first enabled plugin".

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Headless bridge, representative plugin: project list and one project's session list return committed data with plugin attribution. |
| L2 Routine | Headless bridge, representative plugin: open, rename, hide; create a session and see it listed; unseen advances and clears; the existing activity marker appears in REST and live list-state projections; statuses report idle/busy. |
| L3 Release | Client end to end (phone): every supporting production plugin still covers native/derived ownership, import, and child resolution; one representative plugin proves two running roots reorder after committed user-side activity while awaiting-only is not promoted, inactive order is unchanged, a live patch reorders without another status event, and an omitted marker uses updated-time fallback. Lists and unseen badges render. |
| L4 Extended | Relay integration, every supporting production plugin: bridge and plugin restart preserve identity and overrides; a moved backend-native project keeps them while a moved bridge-derived project is discovered as new without mutating the old catalog; a cancelled or failed import leaves the prior catalog intact; reads during import stay consistent; an unavailable plugin is reported while others keep listing. |
| L5 Full | Client end to end, every supporting production plugin: multiple clients observe consistent listings and unseen transitions; large catalogs and paged listings behave; unattributed payloads resolve to the historical identity. |

## Exploration Guidance

Vary the owning plugin, manual open versus import discovery, git and non-git
folders, and whether the directory moved between runs. Alternate empty,
child-only, and large projects, and reorder import, listing, creation. Remove
disposable sessions and projects and restore hidden-state changes afterwards.
For activity order, vary REST versus live delivery, null versus populated
markers, ties, awaiting-only versus running state, and assistant/tool updates
after a marker has been established.

## Failure Signals

- A catalog read starts a backend, hangs on import, or returns a partial list.
- A moved backend-native project appears new or empty, loses sessions, or resolves
  git in the old location; a moved bridge-derived project mutates the old catalog
  identity instead of being discovered as new.
- Sessions lose attribution, land under the wrong project, or a child lists as a
  root.
- A running root stays alphabetically ordered, a stale marker masks newer
  committed activity, a null marker fails to use updated time, awaiting-only is
  promoted, or inactive/project/child order changes.
- Unseen never clears, clears without viewing, or an unavailable plugin is idle.
- Hiding destroys sessions, or a cancelled import destroys the committed catalog.

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

## Sources

- Bridge: `bridge/app/lib/src/bridge/repositories/` (project, session, derived
  session), `bridge/services/project_*`, `services/catalog_import_service.dart`,
  catalog and session handlers in `bridge/routing/`
- Contract: `bridge/sesori_plugin_interface/lib/src/bridge_plugin.dart`
- Tests: `bridge/app/test/bridge/routing/catalog_read_handlers_test.dart`,
  `bridge/app/test/bridge/repositories/project_repository_test.dart`;
  `client/module_core/test/services/session_list_service_test.dart`,
  `client/module_core/test/services/session_unseen_tracker_test.dart`,
  `client/module_core/test/cubits/session_list/session_list_cubit_test.dart`
- Plans (discovery only): `.plan/completed/multi-plugin-release-prep`,
  `setup-aware-plugin-management`, `relay-request-concurrency`;
  `.plan/active/session-user-interaction-order`
