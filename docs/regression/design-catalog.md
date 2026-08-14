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
| L1 Smoke | Automated: validate unique scenario identifiers, production-valid button combinations, manifest parity, navigation coverage, Prego canvas-background mappings, layout-guide defaults and safe/content geometry, inspector token-candidate resolution, transform-correct inspection bounds, nested target cycling, and rendering of every curated state. |
| L2 Routine | Client end to end: build the release web catalog and interact with the solid-button playground, light/dark themes, Prego canvas backgrounds, toggleable safe-area/content/spacing guides, iOS/Android viewports, enabled clicks, disabled/loading states, the all-states matrix, and hover/pinned inspection in a browser. |
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
- Enable Prego layout guides and confirm safe-area bands follow the selected
  viewport while the content bounds stay 16 logical pixels inside the safe
  region. Toggle each guide independently, confirm the spacing grid is off by
  default, and verify the overlay does not block component interaction. Treat
  the Android safe-area presets as representative rather than device chrome.
- Enable the inspector and hover text plus nested layout/decorated elements.
  Confirm bounds stay on the visible target in scaled phone viewports; pin,
  cycle, copy an unambiguous token, and clear without replacing the preview or
  activating the inspected component. Ambiguous equal-valued tokens must be
  labeled as value matches and must not produce an arbitrary copy action.
- Exercise the compact iPhone SE, an iPhone 16 Pro size, and both the Pixel and
  Galaxy Android presets. Treat Android dimensions as representative because
  display-size and system-navigation settings can change the logical viewport.
  Phone presets must also select the matching production interaction path:
  iPhone presets use the iOS scale, shadow, and haptic-triggering behavior;
  Android presets use the Material ripple behavior.
- Compare an individual scenario with the same card in the all-states matrix.
- Confirm `web/catalog_manifest.json` changes only after the typed registry is
  intentionally changed and regenerated.

## Maintenance Sources

- `.github/workflows/design-catalog-preview.yml`
- `client/design_catalog/Makefile`
- `client/design_catalog/README.md`
- `client/design_catalog/lib/src/prego_catalog_background.dart`
- `client/design_catalog/lib/src/prego_catalog_inspector.dart`
- `client/design_catalog/lib/src/prego_catalog_layout_guides.dart`
- `client/design_catalog/lib/src/inspector/`
- `client/design_catalog/lib/src/prego_catalog_viewports.dart`
- `client/design_catalog/lib/src/catalog_scenarios.dart`
- `client/design_catalog/lib/src/prego_button_catalog.dart`
- `client/design_catalog/test/`
- `client/module_prego/lib/components/buttons/prego_buttons_solid.dart`
