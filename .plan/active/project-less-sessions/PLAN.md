# Project-less sessions, a floating new-session button and Archived in Settings

## Status and scope

- Status: planned 2026-10-25. Decisions D1–D15 were agreed with the user over two HTML review rounds on
  2026-10-25 (follow-up to #2052).
- Scope:
  - sessions that need no project, each run in its own folder under `~/.sesori/scratch`;
  - bridge worktrees moving to `~/.sesori/worktrees`;
  - on the narrow phone, a floating + and a two-button top bar;
  - Archived moving into Settings on every surface;
  - the new-session picker and the project switcher moving their actions into a footer.
- Out of scope:
  - a bottom bar that splits chats from project work (D13);
  - moving a project-less session into a project;
  - git in scratch folders;
  - removing PR tracking, which is reviewed separately.

## Outcome

- **Start without a project.** You can open the app, type and send without choosing a project. The session
  runs in a fresh folder such as `~/.sesori/scratch/2026-10-25-k3f9q2/`.
- **One "No project" entry.** These sessions sit in the one session list without a project name. The
  switcher and the desktop filter can show only them.
- **Folder lifetime.** Deleting such a session removes its folder; archiving keeps it.
- **Scratch folders stay out of the project list.** No harness's history import turns them into projects.
- **Phone home.** The narrow top bar holds only the computer and Settings. New session is a floating + at the
  bottom right.
- **Archived** lives in Settings on every surface.

## Decisions

- **D1 — One Sesori folder.**
  - New worktrees go to `~/.sesori/worktrees/`.
  - Project-less sessions go to `~/.sesori/scratch/<YYYY-MM-DD>-<random>/`, one folder per session.
  - It is a hidden home folder, so cloud-sync tools leave it alone. Codex users report exactly that sync
    problem with Codex's own `~/Documents/Codex/<date>/<thread>/` scratch folders.
- **D2 — No legacy worktree root.**
  - `~/.sesori-worktrees` arrived on 2026-10-17 (af2b390bf5), after the latest public release v1.9.1. So per
    `AGENTS.md` it gets no fallback.
  - Worktrees that internal builds left there are no longer removed by the bridge; remove them by hand. This
    corrects a round-1 "decided" item that promised to keep removing them.
  - The released `.worktrees/` compatibility branch stays.
- **D3 — Every harness.** OpenCode, Claude Code, Codex, Pi and the ACP family (Cursor, OMP and the others) all
  start project-less sessions. A harness that cannot is surfaced honestly and recorded in
  `docs/HARNESS_CAPABILITIES.md`.
- **D4 — Scratch folders never become projects.** The bridge binds every root session run under the scratch
  root to one "No project" project. It never publishes a scratch folder as a project.
- **D5 — No dedicated worktree** for a project-less session. There is no repository to branch from.
- **D6 — New-session picker** (Q1 A, Q9 A).
  - The search sits right under the title. The list holds only projects.
  - A footer holds two buttons side by side: "No project" and "Open folder…", the latter replacing the pinned
    "Open another folder…" row above the search.
  - The desktop popover gets the same footer.
- **D7 — Default project** (Q2 A).
  - With a project filter, a new session starts in that project.
  - With all projects showing, it starts in "No project". This applies on every surface: the desktop home
    composer, the wide pane and the phone's +.
  - On a bridge without "No project", it starts in the first project, as today.
- **D8 — In the list** (Q3 B amended, Q10 A).
  - Rows of project-less sessions show no project name.
  - The switcher and desktop filter footer splits into "No project" and "All projects", the latter shortened
    from "Show all projects". It is always shown, so it never changes shape. Filtered to it, the title reads
    "No project".
- **D9 — Folder lifetime** (Q4 A). Deleting a session removes its folder and everything in it. Archiving keeps
  the folder, so a restored session has its files.
- **D10 — A plain folder** (Q5 A), with no `git init`. The Changes page has nothing to show for these sessions.
- **D11 — Archived in Settings** (Q6 A, Q7 A).
  - Settings gets an "Archived sessions" row that opens the existing Archived page, on every surface.
  - The narrow top bar, the wide sidebar footer and the desktop sidebar footer drop their Archived button.
- **D12 — Phone top bar and floating +** (round 1 section 4, Q8 A).
  - The narrow phone top bar keeps only the computer button, with its status dot, and Settings.
  - New session becomes a round glass + at the bottom right, above the home indicator. It never moves while the
    list scrolls, and the list gets matching bottom padding.
  - The wide layout keeps the sidebar's "New session" row. Desktop keeps its own controls.
- **D13 — No bottom bar now** (Q11 A). Revisit a Chats / Projects split once project-less sessions get real use.
  `workspace_kind = no_project` on the session analytics events measures that.
- **D14 — Mixed versions.**
  - An older app on a newer bridge lists "No project" as an ordinary project with that name. Every session it
    starts there still gets its own folder.
  - A newer app on an older bridge offers no "No project". Its defaults stay as today.
- **D15 — Not now:** moving a project-less session into a project, as ChatGPT offers for its chats.

## Current behavior (evidence, 2026-10-25, `origin/main` 04f9e375fb)

- **Worktree root.** `sesoriWorktreesDirectory()` in `sesori_bridge_foundation/lib/src/sesori_data_directory.dart`
  returns `<home>/.sesori-worktrees`. It is injected once, at `orchestrator.dart:347`, into `WorktreeRepository`.
  - `worktreePathFor` joins under it.
  - `isValidWorktreePath` accepts anything within it, plus the released `.worktrees/` branch.
- **Projects.** `projects_table` rows have an id, a path, `hidden` and `displayName`. `sessions_table.project_id`
  references `projects_table` with cascade. `GET /projects` returns `Projects(data: List<ProjectSummary>)` from
  `ProjectActivityService.getProjects`.
- **Creation.** `SessionCreationService._createSession` resolves the project's stored path, optionally prepares a
  worktree, then creates the backend session with `directory` and persists `projectId`, `directory`,
  `worktreePath` and `baseCommit`. In-place sessions take `resolveHeadCommit` as `baseCommit`; it returns null
  outside git.
- **Import binding.**
  - `CatalogImportRepository` publishes plugin-owned projects as observed, and binds each root session to the
    project of its `rootProjectPath`. For OpenCode, that is a virtual project per directory, so a scratch session
    would be rebound to a new per-folder project.
  - Bridge-derived plugins (Pi, ACP, Claude) keep an existing binding and otherwise use the session directory.
  - `_shouldHideDiscoveredProject` hides new projects under `/tmp` or a home dot-folder.
- **Connect-time activity.** `ProjectActivityRepository` inserts missing native-plugin projects as visible
  (`insertProjectsWithPathsIfMissing(hidden: false)`). For bridge-derived plugins, it passes known directories
  built from project paths and worktree paths only.
- **Deletion.** `SessionDeletionService` owns the cleanup-and-delete workflow: worktree cleanup under the family
  lock, the row delete, then best-effort history purge in `onDeleted`. Archiving runs worktree cleanup only.
- **Client.**
  - The new-session picker pins "Open another folder…" above its search (`PregoPickerSearchList.header`). The
    switcher has the full-width "Show all projects" `footer` (#2059).
  - `AllSessionsState.defaultProjectId` is the filter or the first merged project.
  - The narrow home top bar (`sessions_home_view.dart`) holds New session, the computer, Archived and Settings.
  - The wide footer (`home_sidebar_footer.dart`) and the desktop sidebar footer (`desktop_sidebar.dart`) hold
    Archived.
  - `AnalyticsWorkspaceKind` has `project` and `dedicatedWorktree`.

## Product behavior and feel

- **The floating +.** It sits still over the list, with a soft shadow, in the top-bar glass style. Rows scroll
  under it, and the last row can scroll clear of it.
- **Picker footers.** These follow the switcher's footer, which already rides above the keyboard, so the search
  field never moves when the sheet opens or the keyboard rises.
- **Choosing "No project".** In the picker it closes the sheet the same way picking a project does. The composer
  chip then reads "No project".
- **Filtering to "No project".** The list's existing filter transition applies: rows fade, and the title changes
  in place.
- **Delete confirmation.** For a project-less session, it says the session's files are deleted too, because they
  cannot be recovered.

## Ownership and contracts

### `sesori_bridge_foundation`

- `sesoriWorktreesDirectory()` → `<home>/.sesori/worktrees`.
- `sesoriScratchDirectory()` → `<home>/.sesori/scratch`.
- Both join under a private `<home>/.sesori` helper, which resolves the home through `resolveUserHomeDirectory`.

### `sesori_shared`

- `enum ProjectKind { folder, scratch }`.
- `ProjectSummary.kind`: `@JsonKey(unknownEnumValue: ProjectKind.folder) @Default(ProjectKind.folder)`, with a
  `COMPATIBILITY 2026-10-25 (v1.9.2)` marker. Older bridges omit it, and all of their projects are folders.
- `DeleteSessionRequest.deleteSessionFolder`: `@Default(false)`, with a `COMPATIBILITY 2026-10-25 (v1.9.2)`
  marker.
  - Older apps omit it, and they never warn that files go with the session, so their deletes keep the folder.
  - The new app sends `true` after its warning.
  - Retiring condition: no supported app omits it.
- `CreateSessionRequest` keeps `projectId`. The client sends the "No project" project's id with
  `dedicatedWorktree: false`.

### `bridge/app`

- **`FilesystemApi`** gains two async methods:
  - `createTemporaryDirectory({required parent, required prefix})`, which wraps `Directory.createTemp`;
  - `deleteDirectoryRecursivelyAsync(path)`. The existing synchronous delete would block the bridge on a large
    folder.
- **`ProjectCatalogIdentityCalculator`** owns the one scratch-path rule.
  - It takes the scratch root at construction (`orchestrator.dart`) and exposes `isScratchRoot(path)` and
    `isWithinScratch(path)`. Both go through `normalizeProjectDirectory`.
  - Every site below already routes observed paths through it, so no repository depends on another.
- **`ScratchRepository` (new, `repositories/`)** owns the scratch folders and the "No project" row. It takes
  `FilesystemApi`, `ProjectsDao`, `SessionDao` and the calculator, and has three methods.
  - `ensureScratchProject()`:
    - creates the root;
    - inserts the row if it is missing. The id and path are the normalized scratch root, the row is visible,
      and `displayName` is "No project", the name older apps show;
    - is an ordinary `projects_table` row, with no schema change.
  - `createSessionDirectory()` creates a `<YYYY-MM-DD>-<random>` folder in the root through
    `createTemporaryDirectory`.
  - `deleteSessionDirectoryIfUnused(path)` deletes a folder only when all of these hold:
    - its parent is the root itself;
    - no remaining session row has a directory at or under it (one `SessionDao` query, run only here);
    - `FilesystemApi.entityType` reports a directory and not a link.

    The delete is the async recursive one. This one rule also keeps a child session's delete, and any other session
    sharing the folder, from removing it.
- **Startup.**
  - `BridgeRuntime` exposes `ensureScratchProject`, just as it exposes `reconcileDeletedSessionStorage`.
  - `bridge_runtime_runner.dart` calls it before `reconcileDeletedSessionStorage` and
    `catalogHydrationListener.start()`, so no import can see a scratch session before the row exists.
  - On failure it logs `Log.w` with the path and the error, then continues without "No project". Imports then
    publish nothing for scratch paths, rather than throwing.
- **`kind`.** `ProjectRepository.getProjects`, through `ProjectCatalogMapper.mapSummary`, maps `scratch` for the
  row whose id is the scratch root, and `folder` for every other row. The id is stable; an import may rewrite
  `path`.
- **Hiding.** `ProjectMutationService.hideProject` refuses the scratch id with a 409. Without that, an older app
  could hide the row, and every app on that bridge would lose "No project" with no way to get it back.
- **Discovery and binding (D4).** Each site asks the calculator and skips publishing or inserting any project
  `isWithinScratch` apart from the row itself. Root sessions whose project path or directory is within it bind
  to the "No project" id. The sites are:
  - `CatalogImportRepository`: plugin-owned and bridge-derived publishing and binding;
  - `ProjectActivityRepository`: connect-time native inserts;
  - `SessionRepository._collectActiveRootHydrations` and `_persistNativeRootSessions`: unbound active roots.
  - **Accepted, not guarded:** "Open folder…" on a path inside the scratch root makes an ordinary project.
    Reaching it means browsing into a hidden folder, and the damage is one odd project.
- **Known directories.** `SessionDao.getSessionProjectPaths` rows gain `directory`. `ProjectActivityRepository`
  and `CatalogImportRepository` add the scratch-session directories to the known directories they pass to
  bridge-derived plugins, so Pi and ACP find their history.
- **Creation.** When the resolved project id is the scratch root, `SessionCreationService`:
  - creates the folder through `ScratchRepository` and uses it as `directory`;
  - skips worktree preparation even if a peer sends `dedicatedWorktree: true`;
  - persists no `worktreePath` and a null `baseCommit`.
- **Deletion.**
  - `SessionMutationDispatcher.deleteSession` passes the `DeletedSessionSubtree` to `onDeleted`, instead of only
    the ids. Its root snapshot already carries `directory`.
  - When the request has `deleteSessionFolder`, `SessionDeletionService` then calls
    `deleteSessionDirectoryIfUnused` for the root's directory without awaiting it, so the family lock is not
    held during the delete. A failure logs `Log.w` with the path and the error, like the history purge.
  - Archiving is unchanged and keeps the folder.

### Client

- **`module_core`.**
  - `ProjectListLoaded` gains `folderProjects` and a nullable `scratchProject`, both derived once in
    `ProjectInventoryService` from `kind`. `projects` stays the full list for name lookups.
  - Which consumers read which field:
    - the project picker, the switcher and Settings › Projects list `folderProjects`;
    - the picker and switcher footers show "No project" when `scratchProject` is non-null;
    - "no projects yet" means both `folderProjects` is empty and `scratchProject` is null. A bridge with only
      "No project" still shows the composer (D7).
  - `AllSessionsState.scratchProjectId` comes from the same source.
    - `defaultProjectId` is the filter, else `scratchProjectId`, else the first folder project.
  - The client `Project` model gains `kind`, mapped from `ProjectSummary.kind`.
  - `NewSessionCubit` receives it alongside `projectName` and passes it to `SessionLaunchService.launch`, which maps
    `scratch` to `AnalyticsWorkspaceKind.noProject("no_project")`. That value applies to
    `session_created_with_message` and `session_creation_failed`.
  - `SessionApi.deleteSession` sends `deleteSessionFolder: true` for scratch sessions, after the confirmation.
- **`module_prego`.**
  - `PregoPickerSearchList.footer` takes a sealed `PregoPickerSearchFooter` with two variants:
    - `single(action)`;
    - `pair(leading, trailing)`: equal width; Down from the last row reaches `leading` first, then `trailing`.
  - The `header` slot is removed once the new-session picker stops using it, since no other caller passes one.
- **`module_app_ui`.**
  - The project picker's footers:
    - new session: `pair` of "No project" and "Open folder…", or `single` of "Open folder…" without
      `scratchProject`;
    - switcher: `pair` of "No project" and "All projects", or `single` of "All projects".
  - Rows omit the project name for the scratch project, and the title reads "No project" when filtered to it.
  - The delete confirmation says the folder and its files go too.
  - The narrow home top bar holds the computer and Settings, with a floating + over the list.
  - Settings gains an "Archived sessions" row.
- **`app` and `desktop`.**
  - The `onOpenArchived` plumbing goes from the home view, the wide sidebar footer, the desktop shell and the
    desktop sidebar.
  - The desktop settings modal's "Archived sessions" row closes the modal and opens the Archived pane.

## Compatibility

- **`ProjectSummary.kind` and `DeleteSessionRequest.deleteSessionFolder`** are additive, with honest defaults.
  Older peers ignore keys they don't know.
- **v1.9.1 apps on a new bridge** list "No project" as a project with that name.
  - Sessions they start there each get their own folder.
  - The dedicated-worktree toggle is hidden, because the scratch root is not a git repository
    (`supportsDedicatedWorktrees` is false).
  - Their deletes keep the folder (the default of `deleteSessionFolder`), because their confirmation never warns
    that files go too. Folders left this way are accepted disk use.
  - They can rename the row, which is cosmetic: the new app shows its own label from `kind`.
  - They cannot hide it; the bridge refuses.
- **A new app on an older bridge** sees no `scratch` project. It shows no "No project" button and defaults as
  today.
- **`~/.sesori-worktrees`** was never public (D2). The released `.worktrees/` branch stays as it is.

## Complexity budget

- **New persistent state:** none. No column, migration or table. The "No project" project is an ordinary row,
  and `kind` comes from its id.
- **New in-memory mutable state:** none. `folderProjects`, `scratchProject` and `scratchProjectId` are derived
  inside existing state computations.
- **New production files:** `scratch_repository.dart` and the `ProjectKind` enum.
- **Deliberately not added:**
  - a `kind` column;
  - a cleanup job or retention timer;
  - `git init`;
  - an all-sessions endpoint;
  - per-harness production code, unless a harness check finds a gap;
  - a move-to-project action;
  - the bottom bar.

## Cleanup

- The pinned "Open another folder…" header row, plus `PregoPickerSearchList.header` and its keyboard wiring once
  it has no caller.
- The Archived buttons and their `onOpenArchived` callbacks in the narrow top bar, the wide footer and the
  desktop sidebar, plus the narrow top bar's New session button.
- `.sesori-worktrees` wording in code comments and docs.

## Steps

The series has 7 steps, and the titles are exact. Each implementation step updates the regression documents it
touches.

| Step | Title | Estimate (changed lines) | Depends on |
|---|---|---|---|
| 1 | 🌱 [project-less-sessions] Publish the plan [step 1/7] | 450 | — |
| 2 | 🌿 [project-less-sessions] Floating new-session button and Archived in Settings [step 2/7] | 700 | 1 |
| 3 | 🌿 [project-less-sessions] Picker actions move into a footer [step 3/7] | 500 | 1 |
| 4 | ⚙️ [project-less-sessions] Sesori folder and per-session scratch folders [step 4/7] | 1,000 | 1 |
| 5 | ⚙️ [project-less-sessions] Turn on the No project project [step 5/7] | 1,100 | 4 |
| 6 | ⚙️ [project-less-sessions] No project in the apps [step 6/7] | 1,100 | 3, 5 |
| 7 | 🌱 [project-less-sessions] Run the L3 matrix and retire the plan [step 7/7] | 250 | 2–6 |

- Steps 2, 3 and 4 are independent.
- Step 4 lands everything that stays inert until a "No project" row exists.
- Step 5 creates the row last, so no peer can start a session in the shared scratch root itself.

### Step 1 — Publish the plan (🌱)

This plan and its tracker.

### Step 2 — Floating new-session button and Archived in Settings (🌿)

- **Scope.** D11 and D12, client-only.
  - The narrow phone top bar holds the computer and Settings.
  - The floating + opens the new-session page, as the top-bar button did. The list gets bottom padding for the +.
  - Settings gains "Archived sessions" on the phone and in the desktop settings modal.
  - The Archived buttons and their `onOpenArchived` plumbing go.
- **Tests:**
  - the narrow top bar has exactly two buttons;
  - the + stays put while the list scrolls, and the last row clears it;
  - the Settings row opens Archived on the phone and on desktop;
  - the wide and desktop footers have no Archived button.
- **Regression docs:** `projects-and-sessions.md`, `session-archiving-and-deletion.md`,
  `desktop-cockpit-shell.md` and `navigation-transitions.md`.

### Step 3 — Picker actions move into a footer (🌿)

- **Scope.** D6's layout, client-only.
  - The sealed `PregoPickerSearchFooter` with `single` and `pair`.
  - The new-session picker moves "Open another folder…" into a `single` footer as "Open folder…".
  - The `header` slot goes.
  - The switcher keeps its `single` "Show all projects" footer until step 6.
- **Tests:**
  - the search is the first control under the title;
  - the footer opens the folder browser;
  - keyboard order through a `pair`;
  - a `pair` shares the width.
- **Regression docs:** `session-creation-and-options.md`.

### Step 4 — Sesori folder and per-session scratch folders (⚙️)

- **Scope.**
  - D1 and D2: the foundation's `~/.sesori` directories, so new worktrees land in `~/.sesori/worktrees`.
  - Shared: `ProjectKind` and `ProjectSummary.kind` (always `folder` until step 5), and
    `DeleteSessionRequest.deleteSessionFolder`.
  - `FilesystemApi`'s two async methods.
  - The calculator's scratch rule.
  - `ScratchRepository`'s `createSessionDirectory` and `deleteSessionDirectoryIfUnused`.
  - The creation branch and `DeletedSessionSubtree` in `onDeleted`, with the folder removal.
  - Every branch keys on the scratch project id, so all of it stays inert until step 5 inserts the row.
- **Tests:**
  - directory resolution;
  - `kind` and `deleteSessionFolder` decoding, both with missing values;
  - creation makes a dated folder under the root, persists it as `directory`, and ignores
    `dedicatedWorktree: true`;
  - delete removes the folder only with the flag, never when another session row still uses it, never outside
    the root, for the root itself, for a link, or for `..` segments;
  - Windows-path cases;
  - archive keeps the folder.
- **Regression docs:** `session-creation-and-options.md` (including D10's empty Changes page in
  `diffs-and-source-control.md`) and `session-archiving-and-deletion.md`.

### Step 5 — Turn on the No project project (⚙️)

- **Scope.**
  - `ensureScratchProject` and its startup call.
  - The `kind` mapping.
  - The hide refusal.
  - Discovery and binding at every listed site (D4).
  - `directory` in `getSessionProjectPaths`, and the known directories.
- **Harness check:** on a live dev bridge, for every installed harness:
  - start a project-less session by its project id and send a prompt;
  - run a refresh import, restart the bridge, then archive, restore and delete;
  - confirm no scratch folder becomes a project.

  Record any harness that cannot in `docs/HARNESS_CAPABILITIES.md`, and fix it here only when the fix is small.
- **Tests:**
  - the row is ensured once, before hydration, and survives an import;
  - `kind` maps by id;
  - hide is refused;
  - an OpenCode-style per-folder project inside the root is not published, and its root sessions bind to
    "No project";
  - a bridge-derived session inside the root binds;
  - an unbound active root inside the root binds and inserts no project;
  - connect-time activity skips such projects;
  - Pi and ACP list sessions from scratch folders.
- **Regression docs:** `projects-and-sessions.md` and `plugin-setup-and-lifecycle.md`.

### Step 6 — No project in the apps (⚙️)

- **Scope.**
  - `folderProjects`, `scratchProject` and `scratchProjectId`, and the D7 default.
  - The client `Project.kind`, through `NewSessionCubit` and `SessionLaunchService` to
    `AnalyticsWorkspaceKind.noProject`.
  - The `pair` footers (D6, D8).
  - Rows without a project name, and the "No project" title.
  - The delete confirmation copy, and sending `deleteSessionFolder`.
- **Tests:**
  - defaults with a filter, without one, and on a bridge without "No project";
  - a bridge with only "No project" shows the composer;
  - both footers with and without "No project";
  - the row label is omitted;
  - the analytics value;
  - Settings › Projects omits the row;
  - delete sends the flag only for scratch sessions.
- **Regression docs:** `projects-and-sessions.md`, `session-creation-and-options.md`,
  `desktop-cockpit-shell.md`, `session-archiving-and-deletion.md` and `analytics.md`.

### Step 7 — Run the L3 matrix and retire the plan (🌱)

- Run the matrix below.
- Reconcile any regression document whose text the matrix shows to be stale.
- Record the results in `TRACKER.md`, and move the plan to `.plan/completed/project-less-sessions/`.

## Verification and regression matrix

**Highest level: L3 Release.** The plan adds wire fields, deletes directories on the user's disk, and changes the
home on every surface.

**Live dev bridge plus a headless iOS simulator** (slot device `sesori-dev-{x}`):
- **Narrow iPhone:**
  - the two-button top bar;
  - the + over a long list;
  - Settings › Archived sessions;
  - a send from the + with no filter lands in "No project";
  - a project filter starts there;
  - the picker footer's "No project" and "Open folder…";
  - the row has no project name;
  - the switcher's "No project" and "All projects";
  - delete removes the folder on disk after the warning;
  - archive keeps it, and restore works.
- **Landscape iPhone and iPad:**
  - the sidebar footer without Archived;
  - the composer pane defaults to "No project".

**macOS desktop:**
- the home composer defaults to "No project";
- the popover footers;
- the sidebar footer without Archived;
- the settings modal row opens Archived.

**Plugins**, for each installed harness (OpenCode, Claude Code, Codex, Pi and the ACP family where installed):
- start, prompt, refresh import, restart, archive, restore and delete;
- no scratch folder appears as a project.

**Mixed versions:**
- A v1.9.1 app on the new bridge:
  - it lists "No project", and its session gets its own folder;
  - its delete keeps the folder;
  - hiding "No project" fails.
- The new app on a v1.9.1 bridge shows no "No project" and defaults as today.

**Platforms:** Android, Windows and Linux are covered by shared widget and unit tests. Folder handling uses
`package:path` and `dart:io` with Windows-path unit tests.

**Reductions:** any reduction needs explicit user acceptance, recorded here before retirement. None is accepted.

## Risks and accepted behavior

- **Delete loses files.** Deleting a project-less session in the new app deletes what the agent wrote there (D9,
  accepted). The confirmation says so.
- **Directory deletion is security-sensitive.** Only `ScratchRepository.deleteSessionDirectoryIfUnused` deletes,
  and every one of these must hold:
  - the folder comes from the bridge's own session snapshot;
  - its parent is the scratch root;
  - no remaining session row uses it;
  - it is a real directory and not a link.

  `Directory.delete(recursive: true)` removes links inside without following them.
- **Disk use.** These folders stay until their session is deleted (D9 and Compatibility, both accepted), and
  there is no retention job:
  - archived sessions' folders;
  - folders of sessions that older apps deleted.
- **Internal-build leftovers** in `~/.sesori-worktrees` stay on disk (D2, accepted).
- **"Open folder…" on a scratch path** makes an ordinary project (accepted; see Discovery).
- **Shared folder.** Several dev bridges share `~/.sesori/scratch`, as they share the worktree root. A bridge
  deletes a folder only when its own sessions no longer use it.
- **Evidence level.** Every safeguard here addresses an ordinary flow: creation, import, deletion, a second
  session in the same folder, and mixed versions. None addresses a theoretical interleaving.

## Later phases (rough intent only)

- A Chats / Projects bottom bar (D13), if `workspace_kind = no_project` shows real use.
- Moving a project-less session into a project (D15).
