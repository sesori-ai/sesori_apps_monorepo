# Step 12 — Sidebar

Split in two. 12.a rebuilds the row hierarchy and adds the running count.
12.b replaces the New session button with a quiet row and slims the footer.

## 12.a — Row hierarchy and running count

### What changed

- `ProjectListLoaded` gains `runningByProjectId`. `orderProjects` already
  finds each project's running sessions with
  `SessionActivityCalculator.isRunning`; it now returns their count with the
  order. A session only waiting for input is not counted (MS10). The existing
  `activityById` still counts every active session and still feeds the phone
  list.
- Project rows are 14 medium primary in every state. Session titles, in the
  project tree and in Activity, are 14 regular secondary. An unread session is
  primary, with the sparkle it already had, instead of bold (D1).
- A project row with running sessions writes "Running" or "2 running" beside
  its sparkle while the sidebar is open. The rail keeps the sparkle badge.
- The project's add and fold controls appear only on hover or keyboard focus.
- The open session is highlighted once, on its row under its project. Activity
  rows in the sidebar no longer show it, and the project row is highlighted
  only on the project's own page. The rail's Activity popout still marks it,
  because the rail has no project tree.
- A highlighted row fills the list's full width, with no rounded inset.
- "Show more" reads "Show N more" (up to ten), in 12 tertiary.

### Verification

- `client/module_core`: `dart analyze --fatal-infos` is clean.
  `test/services` and `test/cubits/project_list` pass. The service test checks
  the count, including that a waiting-only project has none.
- `client/desktop`: `dart analyze --fatal-infos` is clean on tracked files.
  `test/core` and `test/features` pass.
  - A new shell test covers the type hierarchy, the single highlight, the
    full-width fill and the hover-only chevron.
  - The signals test checks the "2 running" text, and the Show more test
    checks its count, size and colour.
- Rendered the shell in the light theme and checked the sidebar by eye.
