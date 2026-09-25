# Step 13 — Session rows

Split in two. 13.a shortens long text in the middle and removes the repository
subtitle's popover. 13.b rebuilds the session row.

## 13.a — Middle ellipsis and the repository subtitle

### What changed

- `PregoStartEllipsisText` becomes `PregoEllipsisText` with a required
  `PregoEllipsis` position, start or middle. The model picker keeps start; a
  middle cut keeps both ends, the head taking the odd character.
- `PregoNavSubtitle` loses its chevron and info popover (SL5). Its text
  shortens in the middle, and a tooltip shows it whole on long press or hover.
  The unused "Show full repository name" string is removed.

### Verification

- `client/module_prego`: `dart analyze --fatal-infos` is clean and
  `test/components` passes, with a new middle-ellipsis test.
- `client/app`: `test/components/navigation` passes. The subtitle test checks
  no chevron, the middle cut and the long-press full text.
- `client/module_app_ui` and `client/desktop`: analyze is clean;
  `module_app_ui` `test/widgets` and `test/features/session_list` pass.

## 13.b — Session row

### What changed

- `SessionTile` leads with a 16-point status slot on both apps: a turning
  sparkle while running, an amber dot while waiting for the user, a resting
  sparkle when unread, or nothing (D3, D6). The slot stays reserved so titles
  line up.
- The time sits at the right in secondary and always shows (D4). The pointer
  row no longer says "Running" in its place; hover still swaps it for the read
  toggle and Archive.
- One tertiary meta line replaces the footer: any state that needs words, then
  the harness name, the branch shortened in the middle and the pull request.
  A waiting row says "Waiting" in amber (D24). The harness logo and its spoken
  "{harness} session" label go; the name is now text.
- The `isActive` parameter is removed from `SessionTile`. The service-owned
  `isRunning` drives the sparkle on both apps, and waiting takes precedence,
  so a session waiting for input shows the dot.

### Verification

- `client/module_app_ui`: `dart analyze --fatal-infos` is clean and the whole
  suite passes. Tile tests cover idle, running, unread, waiting and a long
  branch in touch and pointer modes, plus harness names, colours, spoken order,
  the pull request and 3x text.
- `client/app`: analyze is clean and the playbook tests pass.
- `client/desktop`: analyze is clean and `test/features` passes. Rendered the
  session list page and checked the rows by eye.
