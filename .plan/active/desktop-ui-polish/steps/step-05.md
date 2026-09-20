# Step 5 — The rail: one Activity button and one chip per project

## Scope

- **Every rail button means one thing (D9).** While anything is in motion the
  collapsed rail leads with one Activity button: the unchanged sparkle, turning
  while a session runs, with a count pill; its tooltip and screen-reader label
  name the count and what is running. Below it the rail shows one chip per
  project with its sparkle badge. Sessions no longer stand in as their
  project's initials, so the per-session rail branch of
  `_SidebarActivitySessionRow` is deleted.
- **Popout.** The button opens the same Activity rows in
  `DesktopSidebarActivityPopout` (its own file), a `PregoPopover` framed to
  open beside the rail instead of over its project chips. The popout's route
  owns whether it is open. Opening a row's session closes it; the rows keep
  their right-click menus.
- **Live rows across the navigator.** Popovers mount on the root navigator,
  outside `DesktopCockpitCubitProvider`, which sits inside the router's shell
  route. The sidebar therefore hands `RecentSessionsCubit` and
  `DesktopSidebarCubit` to the popout with `BlocProvider.value`, and
  `_SidebarActivityPopoutList` recomputes the pure projection from them, so a
  session that finishes or is marked read leaves the open popout.
- No new string, no wire, database or analytics change. The phone is
  unchanged.

**Test harness.** The shell test's `app()` helper mounted every cubit above
`MaterialApp`, where any popup could reach it. It now mounts the four
cockpit-scoped cubits below the navigator, as the router does. With the
hand-over removed, the new rail case fails with `ProviderNotFoundException`
(checked once by hand, then restored); every other shell case passes unchanged
under the stricter harness.

## Automated Evidence

Measured checkpoint: commit `f52cc74cbf4b6aba6ea5d1ce8752a0b51993feaf` with a
clean working tree, Flutter 3.47.4 (Dart 3.13) from `.tool-versions`. Every
command below exited 0. No log files were kept; CI on the PR is the durable
record. This file and the tracker row were added afterwards as documentation
only and were not re-measured.

```sh
cd client/desktop
flutter test --no-pub
flutter analyze --no-pub
```

- `desktop`: the full suite, 251 cases, passes. The new shell case restores a
  collapsed layout with one unseen and one running session in two projects and
  proves the button's count ("2") and tooltip, two project avatars and no
  session title in the rail, the popout opening to the right of the 56-point
  rail with both rows, the running row leaving the open popout when its state
  changes, and a row tap opening the session and closing the popout. The
  section-folding case now expects the rail's Activity button in place of
  inline rows.
- `flutter analyze` reports no issues. No generated file changed.
- Architecture review: `architecture-implementation-review` ran once through a
  sub-agent on this step's diff, before it was rebased unchanged onto the
  merged step 4, and approved it with no violations. Its one optional note:
  `_SidebarActivityPopoutList` stays in `desktop_sidebar.dart` because it
  renders that file's private Activity group and menu types; only the popout
  frame, which needs neither, is its own file.

## Size

**320 changed lines = 259 additions + 61 deletions** at the measured
checkpoint, with no generated lines. Reproduce from the root:

```sh
git diff --numstat 155a33038a325ee74eb2805f1a4044569a152046 f52cc74cbf4b6aba6ea5d1ce8752a0b51993feaf
```

The base is `git merge-base origin/main f52cc74cbf4b6aba6ea5d1ce8752a0b51993feaf`.
The step target was 400; the repository soft cap is 1,500. This file and the
tracker row come on top; final self-inclusive accounting belongs in the PR
body.

## Regression Documents

`desktop-cockpit-shell.md` now describes the rail's one Activity button with
its count and tooltip, the popout beside the rail with live rows and menus, one
chip per project, the matching coverage, and two new failure signals.
