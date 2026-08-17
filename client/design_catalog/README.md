# Sesori Design Catalog

Free, interactive Flutter component catalog built with Widgetbook OSS. It is a
workspace package that depends on `theme_prego`, not on either product shell or
business modules.

## Work on a component

1. Start the catalog with `flutter run -d chrome` from this directory.
2. Open **Prego → Solid button → Playground** and adjust its knobs for size,
   hierarchy, tone, interaction state, icons, and width.
3. Edit the production component in
   `../module_prego/lib/components/buttons/prego_buttons_solid.dart`.
4. Hot reload, then inspect **All curated states** in both Prego themes, the
   available iOS/Android viewports, and the **Canvas background** options under
   **Addons**.
5. Add a curated scenario when the change creates a meaningful product state,
   then regenerate the manifest.

## Commands

```bash
make manifest
make manifest-check
make analyze
make test
make build
make check
```

`web/catalog_manifest.json` is generated from the same typed scenario registry
that drives Widgetbook navigation and the all-states matrix. Do not edit it by
hand.

## Phone viewports

The focused viewport menu covers iPhone SE, iPhone 16 Pro, iPhone 16 Pro Max,
Google Pixel 10 Pro, and Samsung Galaxy S26 Ultra, plus an unconstrained mode.
Android logical dimensions represent default app viewports; display-size and
system-navigation settings can change the effective size on physical devices.
Each phone preset also selects its production interaction behavior: iPhone
presets use the iOS press animation and Android presets use the Material ripple.

## Canvas backgrounds

Use **Addons → Canvas background** to place the current component on Prego's
surface and brand background tokens. The selected semantic token resolves
against the active light or dark Prego theme and is stored in the URL, so an
exact interactive preview can be shared with another reviewer.

## Layout guides

Enable **Addons → Prego layout guides** to audit the selected phone viewport
without changing or blocking the component. Safe-area bands come from the
viewport's simulated `MediaQuery.viewPadding`; content bounds sit one
`container-padding-mobile` token (16 logical pixels) inside that safe region.
The optional spacing grid uses 8-pixel major lines and 4-pixel subdivisions.

The guide master switch and spacing grid start off. Every switch is stored in
the URL so teammates can share the same interactive audit view. Safe areas and
content margins are deliberately separate: the 16-pixel margin is a PREGO
content rule, not an iOS or Android system inset.

## Canvas navigation

Use **Addons → Canvas navigation** to zoom the complete component preview from
50% to 300%. Zoom is stored in the URL so a close-up can be shared. Enable
**Move canvas** while **Review tools → Interact** is selected to drag the
enlarged preview with a mouse, trackpad, or touch gesture. The pan position is
temporary and resets when the use case or viewport changes.

Move canvas is deliberately inactive in Inspect, Measure, and Annotate so its
drag gesture cannot compete with those tools. Turn Move canvas off to exercise
the component's own taps and drags.

## Review tools

Use **Addons → Review tools** to switch between four mutually exclusive modes:

- **Interact** leaves the preview fully interactive.
- **Inspect** reads rendered bounds, semantics, and PREGO value matches without
  activating the component.
- **Measure** lets you drag between canvas or component points. Endpoints snap
  to nearby edges and centers, **Shift** locks the dominant axis, and
  **Escape** clears all temporary measurements. Values are Flutter logical
  pixels inside the selected viewport, which are the appropriate design pixel
  values for comparing iOS and Android layouts.
- **Annotate** lets you click the canvas or a rendered element, write a note,
  resolve or reopen it, and delete it. Pins attached to a rendered element
  follow that element when its bounds move; a saved canvas fallback keeps the
  note visible if that render target disappears.

In **Inspect**, hover any rendered text, decoration,
padding, constraint, layout, or semantic element. The hover card shows its
logical size and the strongest PREGO token matches available from the computed
Flutter value. Click to pin the full details panel, use **[** and **]** (or the
panel arrows) to move through nested elements, and press **Escape** to clear.

Token names are value matches, not source-code provenance. When multiple PREGO
variables resolve to the same value, the inspector shows the ambiguity and
does not offer to copy an arbitrary token reference.

Measurements are intentionally temporary. Saved annotations are scoped to the
exact Widgetbook use-case path and viewport name and persist only in that
browser's `localStorage`; they never enter the URL, manifest, logs, analytics,
or product data. **Copy JSON** and **Import JSON** provide an explicit portable
backup when the local development port or browser changes. Import validates the
schema and exact scope, previews the replacement count, and only overwrites the
current scope after confirmation. Corrupted local data is left untouched so it
can be replaced through the import recovery path.

The catalog must use synthetic examples only. It must not import production
authentication, routing, relay, analytics, credentials, or service setup.

## Private pull-request previews

Relevant pull requests from branches in this repository receive a stable,
interactive Cloudflare Pages preview. Forks never receive preview secrets, and
the workflow uses `pull_request`, never `pull_request_target`. Deployment stays
disabled until the repository variable
`CLOUDFLARE_DESIGN_CATALOG_ACCESS_ENABLED` is explicitly set to `true` after
Cloudflare Access is enabled.

One-time setup, in this order:

1. Authenticate Wrangler against the Sesori Cloudflare account and create the
   static Pages project:

   ```bash
   npx wrangler@4.119.0 pages project create sesori-design-catalog --production-branch=main
   ```

2. In **Workers & Pages → sesori-design-catalog → Settings → General**, enable
   the preview access policy and allow only the intended Sesori teammates.
3. Create a least-privilege Cloudflare token with **Cloudflare Pages: Edit** for
   the Sesori account. Add it and that account's ID to the GitHub repository as
   `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` secrets.
4. Add the GitHub repository variable
   `CLOUDFLARE_DESIGN_CATALOG_ACCESS_ENABLED=true` last. This is the fail-closed
   switch that allows `.github/workflows/design-catalog-preview.yml` to deploy.
5. Open or update a trusted pull request touching the catalog or
   `module_prego`, follow the bot's preview link, and confirm Cloudflare Access
   requires authentication before the catalog loads.

The expected cost is $0 for the current team: the catalog is static, Pages
static requests are free, the free Pages allowance includes 500 deployments
per month, and Cloudflare Access Free covers up to 50 users. Recheck the current
Cloudflare limits before substantially increasing PR volume or team size.
