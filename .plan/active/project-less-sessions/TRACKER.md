# Project-less sessions tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Current step: 7/7. The L3 run is recorded below. Its one failure (F1) is fixed in #2094. The four macOS cells are
  pending, so the plan is not retired yet.
- User decisions: D1–D15 in `PLAN.md`, agreed 2026-10-25 over two review rounds.

## Delivery

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/7 | Publish the plan | Done | #2067 |
| 2/7 | Floating new-session button; Archived in Settings | Done | #2070 |
| 3/7 | Picker actions in a footer | Done | #2071 |
| 4/7 | Sesori folder and per-session scratch folders (inert) | Done | #2069 |
| 5/7 | No project project turned on | Done | #2074 |
| 6/7 | No project in the apps | Done | #2087 |
| 7/7 | L3 matrix run; plan retired | In progress: run recorded, F1 fixed (#2094), macOS pending | [L3 run](#l3-run-2026-10-25) |

## L3 run (2026-10-25)

- **Builds:**
  - new app and new bridge: `4ddd0af679` (step 6 on `main`), Flutter 3.47.7;
  - v1.9.1 app and v1.9.1 bridge: tag `v1.9.1` (`8bfeda9416`), Flutter 3.47.5, each from its own worktree.
- **Slot:** 1. Simulators `sesori-dev-1` (iPhone 17, iOS 27.0), `sesori-dev-1-ipad` and `sesori-dev-1-v191`.
- **HOME:** a fixture HOME with two neutral git repos (`demo-api`, `demo-app`) for every app cell. The plugin cells ran
  with the real HOME, because the harness logins live there; no screenshots were taken in that run.

### Narrow iPhone (new app, new bridge)

| Cell | Result | Seen |
|---|---|---|
| Two-button top bar | Pass | The computer button with its status dot, and Settings. |
| + over a long list | Pass | The + stays fixed while the list scrolls; the last row clears it. |
| Settings › Archived sessions | Pass | The row opens the Archived page. |
| Send from + with no filter lands in "No project" | Fail (F1) | The composer opens on "No project", but the OpenCode send fails; see F1. A send without a model lands in "No project" in its own folder. |
| A project filter starts there | Pass, with F1 | With `demo-api` as the filter, the composer opens on `demo-api`. With "New worktree" off, the send lands in `demo-api` and the reply arrives; with it on (the default), F1. |
| Picker footer | Pass | "No project" (checked) beside "Open folder…"; "Open folder…" opens the folder browser. |
| Row has no project name | Pass | "No project" rows show the title and the harness only. |
| Switcher footer | Pass | "No project" beside "All projects"; picking "No project" titles the home "No project". |
| Delete removes the folder after the warning | Pass | The sheet adds "Its folder and every file in it will be deleted too."; the folder is gone after delete. |
| Archive keeps it, and restore works | Pass | Archive keeps the folder, and the session is listed in Settings › Archived sessions. Its detail reads "This session is archived and read-only." Unarchive returns 409 `archived_read_only`: archiving is final by design, so "restore" is the read-only archived view. |

### Landscape iPhone and iPad (new app, new bridge)

| Cell | Result | Seen |
|---|---|---|
| Landscape iPhone: sidebar footer without Archived | Pass | The footer holds the computer, Settings and Collapse. |
| Landscape iPhone: composer defaults to "No project" | Pass | With "All projects" and a newest session in `demo-api`, the composer opens on "No project". |
| iPad: sidebar footer without Archived | Pass | Same footer as landscape. |
| iPad: composer defaults to "No project" | Pass | Same default as landscape. |

### macOS desktop

| Cell | Result | Seen |
|---|---|---|
| Home composer defaults to "No project" | Pending | The Mac was locked; a separate macOS QA build runs them. |
| Popover footers | Pending | The Mac was locked; a separate macOS QA build runs them. |
| Sidebar footer without Archived | Pending | The Mac was locked; a separate macOS QA build runs them. |
| Settings modal row opens Archived | Pending | The Mac was locked; a separate macOS QA build runs them. |

### Plugins (new bridge, debug API)

Steps per harness:
1. create in the scratch root with a prompt;
2. a refresh import;
3. a bridge stop and start;
4. archive;
5. restore;
6. delete with `deleteSessionFolder: true`;
7. a second refresh import.

After each step:
- `GET /projects` lists one "No project" of kind `scratch`;
- no project row lies under `~/.sesori/scratch/`;
- no scratch session is bound to another project;
- hiding "No project" returns 409.

All four checks held after every step. In every row below, the session got its own folder under the scratch root,
was listed under "No project" after the import and after the restart, and was archived with its folder kept. Restore
returned 409 `archived_read_only` (by design). Delete returned 200 and wrote a tombstone. The folder was removed just
after the response (folder removal runs unawaited). The session did not come back on the second import.

| Harness | Model | Prompt | Lifecycle |
|---|---|---|---|
| OpenCode 2.1.3 (shared local service) | `deepseek/deepseek-flash` | Fail (F1) | Create failed; it left an empty folder and no session. |
| OpenCode | none (default) | OK | Pass. |
| Claude Code 2.1.310 | Haiku | OK | Pass. |
| Codex 0.164.0 | `gpt-5.6-luna` | OK | Pass. |
| Pi 1.4.0 | `deepseek/deepseek-flash` | OK | Pass. |
| DeepSeek 0.2.0 | Flash | OK | Pass. |
| Oh My Pi 18.12.6 | `deepseek/deepseek-flash` | OK | Pass. |
| Hermes 0.21.5 (ACP) | default; the only model is a local custom proxy | No reply in 240 s: the local proxy timed out, a local provider problem, as step 5 saw | Pass. |

Not run:
- Grok: needs sign-in.
- Cursor: CLI 2026.07.23 is below the 2026.09.23 floor.
- Antigravity and Copilot: not installed.

### Mixed versions

| Cell | Result | Seen |
|---|---|---|
| v1.9.1 app on the new bridge: lists "No project" | Pass | Listed as an ordinary project, "No project …/.sesori/scratch". |
| v1.9.1 app: its session gets its own folder | Pass | A Claude Code (Haiku) send from "No project" created its own folder under the scratch root, bound to "No project"; reply OK. An OpenCode send hit F1. |
| v1.9.1 app: its delete keeps the folder | Pass | No folder warning; the row is removed and the folder stays. |
| v1.9.1 app: hiding "No project" fails | Pass | "Failed to hide project", and the row stays. |
| New app on the v1.9.1 bridge: no "No project", defaults as today | Pass | There is no "No project" anywhere, and the switcher footer is "All projects" alone. With no sessions, + asks "Choose a project", and the picker footer is "Open folder…" alone. Once a `demo-app` session exists, + defaults to `demo-app`. |

### F1: OpenCode create with a model fails in a new folder

Fixed in #2094. OpenCode 2 registers a newly loaded folder's providers asynchronously, and only its model routes wait
for that. The plugin now reads the models before the providers, which gave a complete catalog in 60 of 60 new
folders against a live OpenCode 2.1.4. The empty folder a failed create leaves behind is pre-existing cleanup
behaviour and stays out of scope.

- **Steps:** on the new bridge, start an OpenCode session with an explicit model in a folder OpenCode has not loaded
  yet. That covers every "No project" send and every send with "New worktree" on. From the app this means + with no
  filter, picking an OpenCode model such as DeepSeek V4.1 Flash Free (low) or Big Pickle, and sending.
- **Seen:**
  - The app says "The server returned an error. Please try again. Sesori couldn't confirm whether a session was
    created. It may still appear in the session list, and sending again may create a duplicate."
  - The bridge logs `POST /session/create: stale session options` and `PluginOperationException: selectModel failed
    with status 409: OpenCode no longer offers the selected model or variant.`
  - Each attempt leaves its new scratch folder (or detached worktree) on disk with no session.
  - `/session/options` for the scratch root also reported no available OpenCode models.
- **Reproduced:**
  - in the new app, from "No project" and from `demo-api` with "New worktree" on;
  - in the v1.9.1 app, from "No project";
  - through the debug API, with the fixture HOME (bridge-spawned OpenCode 2.1.4) and with the real HOME (shared
    OpenCode 2.1.3 service).

  A create without a model, or into an existing folder, succeeds.
- **Cause:** for a directory it has not seen, OpenCode's first `GET /api/provider?location[directory]=<dir>` returns
  `{"data":[]}`, while `/api/model` already lists the models; a second call returns the providers.
  `OpenCodeV2Service._validateModel` (`opencode_v2_service.dart`, called from `createSession`) finds no provider
  and throws `PluginStaleOptionsException`.
- **Status:** not fixed in this branch; reported for a fix PR.

### Other observations

- Slot 1's database still holds four sessions from step 5's live check (DeepSeek, two Oh My Pi, Hermes; created
  before this run). They are bound to "No project", but their folders are gone and they have no tombstone. This
  run's deletes all wrote tombstones and stayed deleted after a re-import, so that state was not reproduced.
- Regression docs: the "No project", delete and archive wording in `projects-and-sessions.md`,
  `session-creation-and-options.md`, `session-archiving-and-deletion.md`, `desktop-cockpit-shell.md` and
  `analytics.md` matches what the run saw. None was stale.

## Decision log

- 2026-10-25: two review rounds settled D1–D15.
  - Round 1 covered folders, defaults, the list label, folder lifetime, git, Archived and the floating +.
  - Round 2 covered the picker and switcher footers, and no bottom bar for now.
- 2026-10-25: D2 corrects round 1. `~/.sesori-worktrees` never reached a public release, so it gets no legacy path.
- 2026-10-25: the plan review's findings were applied.
  - Step order: inert scratch machinery first, then the row.
  - The docs-only step was folded into retirement.
  - Older apps' deletes keep the folder (`deleteSessionFolder` defaults to false).
  - The bridge refuses to hide "No project".
  - A folder is removed only when no session row still uses it.
- No reduction of the retirement matrix has been requested or accepted.

## Review record

- Architecture plan review, 2026-10-25: rejected with 14 findings, all applied directly.
  - Layering and ownership:
    - folder access goes through `FilesystemApi`;
    - `ScratchRepository` owns the row, with a named startup call before hydration;
    - `kind` maps by id in `ProjectRepository`;
    - the calculator is the single owner of the scratch-path rule;
    - the binding sites are listed, including active-root hydration.
  - Deletion: it reads the `DeletedSessionSubtree` and removes a folder only when unused.
  - Compatibility: the hide refusal, and the additive delete flag for older apps.
  - Client: the project-list derivations, and `kind` reaching analytics.
  - Steps: the order was swapped and the docs step folded.
  - Smaller items: the sealed footer, the private home helper, and the async delete.
