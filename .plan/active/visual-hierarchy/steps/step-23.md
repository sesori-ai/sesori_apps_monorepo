# Step 23 — New session page

## What changed

- The page is one grouped card under the bar title: Project, Harness and
  "New git worktree" (D9 wording). The separate heading, the pill project
  selector and the floating Refresh button are gone.
- The question is the composer placeholder: `PromptInput`'s `hasMessages`
  flag became a `restingHint` string that the new session page sets.
- The cached-options message is removed. Refresh is the harness menu's last
  entry, and the Harness row shimmers while a refresh runs. The separate
  options skeleton is deleted.
- On the phone, with the keyboard up, one summary line (project · harness ·
  worktree) replaces the card.
- `PregoBrandLogo` draws marks in square bounds, so OpenCode's 4:5 mark no
  longer pushes its label.

## Verification

- `client/app` new session screen tests (47) and session detail body tests.
- `client/desktop` new session screen tests.
- `client/module_app_ui` suite and the prompt input tests.
- `client/module_prego` `prego_brand_logo_test`.
- `dart analyze --fatal-infos` clean in app, desktop, module_app_ui and
  module_prego.
