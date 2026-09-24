# Step 9 — Icon size, radius and code text tokens

## What changed

- New hand-written `PregoIconSize`: `sm` 14 (a glyph beside text), `md` 18 (a
  control's icon), `lg` 22 (a prominent bar action). Figma exports no icon size
  variables.
- 85 icon size literals now use it. 12 and 16 became `sm`, 20 became `md`, and
  14/18/22 map directly. The session row's action button (16) became `md`.
  Result: small glyphs lose up to 2pt, and 20pt control icons (sidebar,
  menus, recovery card, scaffold rows) become 18.
- Deliberate literals stay, each with a comment: the attachment badge ✕ (10),
  the bridge status dot (8), and the empty-state and error illustrations (32,
  48).
- New `PregoTextTheme.code`: 12-point monospace, line height 18. The tool
  output block (was 11), the shell preview, the code block, the diff lines and
  hunk headers, the permission modal and the onboarding command use it.
  The `monospace` extension moved from `sesori_app_ui` into Prego, and inline
  code in prose still uses it. The diff file header and stats stay as they are
  until step 10.
- Radius literals map to `PregoRadius`: 3 and 4 → `xs`, 8 → `md`, 12 → `xl`,
  20 → `x3l`. The sparkle loader's path arcs and the catalog scan bar's traced
  radius are artwork, and they stay. The plan counted 94 literals; only 15
  remained, because the rest already use tokens or computed values.
- The design catalog has no token page yet. The catalog covers buttons only,
  and a token page would add a registry and manifest change without a
  consumer. The tokens are documented where they are declared.

## Verification

- `dart analyze --fatal-infos lib` is clean in module_prego, module_app_ui, app
  and desktop.
- `client/module_prego`: all tests pass.
- `client/module_app_ui`: all tests pass. The diff line and hunk widget tests
  now pump a Prego theme, because the widgets read `context.prego`.
- `client/app`: `test/features`, `test/components` and `test/core` pass.
- `client/desktop`: `test/features` and `test/core` pass.
