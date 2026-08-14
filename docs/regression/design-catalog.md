# Design Catalog

The design catalog renders production `theme_prego` components without loading
either product shell or any authentication, relay, routing, analytics, or
production service setup. A single typed scenario registry drives Widgetbook
navigation, the curated state matrix, and the checked-in agent-readable JSON
manifest.

Synthetic examples are mandatory. A component edit is reviewable only when the
catalog still resolves, analyzes, renders its curated scenarios, and builds as
a static Flutter Web application.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: validate unique scenario identifiers, production-valid button combinations, manifest parity, navigation coverage, Prego canvas-background mappings, and rendering of every curated state. |
| L2 Routine | Client end to end: build the release web catalog and interact with the solid-button playground, light/dark themes, Prego canvas backgrounds, iOS/Android viewports, enabled clicks, disabled/loading states, and the all-states matrix in a browser. |
| L3 Release | Packaged or external: once private PR previews are enabled, verify a trusted same-repository PR receives an Access-protected interactive preview without production credentials, services, data, or analytics. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

## Exploration Guidance

- Change hierarchy and tone in different orders, including unsupported pairs;
  the playground must explain invalid combinations instead of constructing a
  production-invalid widget.
- Exercise hover, press, focus, enabled, disabled, loading, icon-only, and
  full-width behavior in both Prego themes.
- Switch between surface and brand canvas backgrounds. Confirm the selected
  semantic background follows the active Prego theme and survives in a shared
  preview URL.
- Exercise the compact iPhone SE, an iPhone 16 Pro size, and both the Pixel and
  Galaxy Android presets. Treat Android dimensions as representative because
  display-size and system-navigation settings can change the logical viewport.
- Compare an individual scenario with the same card in the all-states matrix.
- Confirm `web/catalog_manifest.json` changes only after the typed registry is
  intentionally changed and regenerated.

## Maintenance Sources

- `.github/workflows/design-catalog-preview.yml`
- `client/design_catalog/Makefile`
- `client/design_catalog/README.md`
- `client/design_catalog/lib/src/prego_catalog_background.dart`
- `client/design_catalog/lib/src/prego_catalog_viewports.dart`
- `client/design_catalog/lib/src/catalog_scenarios.dart`
- `client/design_catalog/lib/src/prego_button_catalog.dart`
- `client/design_catalog/test/`
- `client/module_prego/lib/components/buttons/prego_buttons_solid.dart`
