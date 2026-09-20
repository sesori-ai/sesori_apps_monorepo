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

### Review follow-up

The first review wave found two real gaps; commit
`56aaebcd19da4c01a0f5ddaa2033f59f4db21f98` closes both (3 files, 89 additions
and 13 deletions, no generated lines).

- **The popout closes with its last row.** When the last Activity row left an
  open popout (marked read from its own menu, finished, or changed remotely),
  the rail dropped the button but the popover's route stayed as an empty bubble
  behind its modal barrier. `_SidebarActivityPopoutList` now takes the
  popover's `close` and calls it after the frame in which its projection
  becomes empty. `close` pops the top route, so the list pops only while
  `ModalRoute.of(context).isCurrent`: a popout that is already closing, or
  that sits under a row's menu, never pops another route, and the route
  dependency rebuilds the list when it becomes the top route again.
- **The button says only what its rows' flags say.** A seen, idle row that
  stays listed because it is selected made the button's tooltip and
  screen-reader label claim "New activity". The label is now built from the
  rows' running, awaiting-input and unseen flags, and a sticky-only count says
  just "Activity · 1". `_SidebarButton`'s status label became nullable for
  that; no string was added.

Re-measured at that commit with a clean tree; both commands exited 0:

```sh
cd client/desktop
flutter test --no-pub
flutter analyze --no-pub
```

- `desktop`: the full suite, 252 cases, passes. The new shell case opens the
  popout over one unseen session, marks it seen, and requires the popout and
  the button to be gone and exactly one `ModalBarrier` to remain — the app's
  own page route always has one, and the open popout's route was the second
  (the case asserts two while it is open); then, with that session selected
  and seen, it requires the tooltip to be exactly "Activity · 1". With
  the `close` call removed the case fails on the popout still being found
  (checked once by hand, then restored). The first rail case now expects
  "Activity · 2, Running, New activity" for one running and one unseen row.
- `flutter analyze` reports no issues. No generated file changed.

### Review follow-up 2

The second review wave had one accessibility gap and one unclear sentence
above; commit `487e4c0d9bbd13ca80201f47a4ab6f39607817c0` closes both (3 files,
25 additions and 13 deletions, no generated lines).

- **The count pill grows with larger text.** `_CountPill` had a fixed 16-point
  height, so from about 134 % system text size the 12-point count was clamped
  and clipped. The height and width are now minimums and the shape a stadium,
  so the pill is unchanged at the default size and grows with the text.
- **Which barrier leaves.** The shell case now also asserts two
  `ModalBarrier`s while the popout is open, so the single one that remains
  after the last row leaves is visibly the app's page route's own.

Two findings of that wave were declined on the PR with reasons: closing the
popout when the window is resized past the auto-collapse breakpoint while it
is open, and when authentication ends while it is open. Both are rare timing
windows with a one-click recovery that every popover and menu in the app
shares; the owner of a sign-out dismissal would be the auth gate, for all root
popups at once, not this popout.

Re-measured at that commit with a clean tree; both commands exited 0:

```sh
cd client/desktop
flutter test --no-pub
flutter analyze --no-pub
```

- `desktop`: the full suite, 252 cases, passes. The shell case now requires
  the count's text to be 12 points high at the default size and 24 at a text
  scale of 2; with the fixed 16-point height restored it fails with 16
  (checked once by hand, then restored).
- `flutter analyze` reports no issues. No generated file changed.

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
