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

## Inspect rendered values

Enable **Addons → Inspector**, then hover any rendered text, decoration,
padding, constraint, layout, or semantic element. The hover card shows its
logical size and the strongest PREGO token matches available from the computed
Flutter value. Click to pin the full details panel, use **[** and **]** (or the
panel arrows) to move through nested elements, and press **Escape** to clear.

Token names are value matches, not source-code provenance. When multiple PREGO
variables resolve to the same value, the inspector shows the ambiguity and
does not offer to copy an arbitrary token reference.

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
