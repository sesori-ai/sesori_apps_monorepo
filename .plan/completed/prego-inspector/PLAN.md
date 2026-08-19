# PREGO Inspector

## Goal

Replace Widgetbook's generic floating inspector with a Sesori-owned,
PREGO-aware inspector for the design catalog. A reviewer can hover or pin a
rendered element, understand its resolved geometry and styling, and see honest
matches to PREGO typography and design-token categories without disturbing the
simulated viewport.

## Current Behavior And Evidence

- `client/design_catalog/lib/main.dart` enables Widgetbook's
  `InspectorAddon`, which wraps the catalog through the transitive
  `inspector 4.0.0` package.
- Its unlabeled floating rail sits inside the selected phone viewport.
- In the scaled iPhone 16 Pro Max preview, hover bounds render displaced from
  the target.
- Pinning a target currently replaces the preview with a
  `No MaterialLocalizations found` exception from the inspector's Material
  details panel.
- The upstream package can derive some raw render values, but it cannot name
  PREGO tokens or distinguish exact matches, aliases, derived values, and
  unmapped values.

## Scope

### Included

- A catalog-local inspector interaction layer with hover preview, click-to-pin,
  clear, and nested hit-target cycling.
- Transform-correct highlighting inside Widgetbook's scaled viewports.
- A compact hover summary and an adaptive pinned details panel that remain
  outside the simulated device content when space allows.
- Resolved dimensions, typography, colors, radius, spacing/padding, decoration,
  constraints, and useful semantics/touch-target information when Flutter
  exposes them at the selected render boundary.
- PREGO token matching for typography, semantic and primitive colors, spacing,
  radius, and widths. Equal-valued aliases are shown as possible matches; the
  UI never claims source provenance that runtime values cannot prove.
- Copy actions for resolved values, token names, and useful PREGO Dart access
  expressions.
- Focused automated tests, release-web browser verification, and regression
  documentation.

### Excluded

- A full widget-tree browser, jump-to-source, live style editing, performance
  profiling, or DevTools replacement.
- Production app integration, analytics, persistence, network access, or
  instrumentation across every PREGO component.
- Exact source-variable lineage when a computed runtime value has lost it.

## Ownership And Design

- `client/design_catalog` owns pointer/keyboard interaction, selection state,
  overlays, panels, and inspection presentation. The catalog stays synthetic
  and dependency-light.
- PREGO token metadata should come from existing exported design values and the
  Figma-token generator rather than a second hand-maintained value list.
  Catalog-only matching code owns the inspection-specific confidence language.
- The inspector uses one ephemeral controller containing the current hover,
  pinned target, and hit-path index. There is no persistence, registry of live
  render objects, background subscription, queue, or lifecycle service.
- Inspector selection is disabled by default so normal component interaction
  remains unchanged. The active mode is URL-shareable through the Widgetbook
  addon setting; a render-object selection is intentionally not persisted.

## Implementation

1. Add a typed `PregoInspectorAddon` and controller in
   `client/design_catalog/lib/src/inspector/`. Replace the generic addon while
   preserving the current background, viewport, alignment, semantics, grid,
   text-scale, and time-dilation addons.
2. Build transform-aware hit testing and immutable selection snapshots. Hover
   chooses the smallest useful render target; pinning freezes it; bracket keys
   or explicit controls cycle the hit path; Escape clears the selection.
3. Add the hover card and adaptive pinned panel with overview, typography,
   appearance, layout, and accessibility sections. Use PREGO-compatible widgets
   and avoid assumptions about Flutter Material localizations.
4. Add token descriptors/resolvers. Match typography properties separately
   from color so `copyWith` styles can still produce honest derived matches.
   Return all equal-valued aliases with an explicit match kind instead of
   selecting an arbitrary token.
5. Add copy affordances and optional two-target distance comparison only if the
   existing hit-path state supports it without another coordination model.
6. Remove the generic `InspectorAddon` and any inspector-specific workaround
   made obsolete by the replacement.

## Complexity Budget

- New persistent mutable parts: **none**.
- New in-memory mutable parts: one catalog-local controller with hover, pinned
  selection, active hit-path index, and optional comparison selection.
- A short hover coalescing mechanism is acceptable only if browser evidence
  shows pointer events rebuilding excessively; it is not planned by default.
- Deliberately omitted: live render-object registries, source maps, timers,
  services, DI, cross-package state, and component instrumentation.

## Cleanup Assessment

The custom inspector directly makes Widgetbook's `InspectorAddon` and its
floating rail obsolete. Remove that addon from the catalog. No persisted data,
wire contract, database field, job, production setting, or compatibility path
is affected. The existing Semantics, Grid, and Time Dilation addons remain
independent and useful.

## Verification

Highest required regression level: **L2 Routine**, client end to end through a
release Flutter Web catalog. No plugin, account, service, database, relay, or
production-app matrix applies.

Automated coverage:

- hit-path ordering, transformed bounds, hover/pin/clear/cycle interaction;
- typography, color, spacing, radius, and width token matching, including
  ambiguous aliases and unmapped values;
- panel rendering for text, decorated boxes, nested elements, semantics, and
  compact space;
- existing catalog tests, manifest parity, analysis, and release build.

Browser matrix:

- Prego light and dark themes;
- text scale 1.0 and 2.0;
- iPhone SE, iPhone 16 Pro Max, and one Android viewport;
- hover, pin, nested-target cycling, copy, clear, normal interaction while the
  inspector is off, and release-web behavior;
- inspector overlay bounds align with the visual target and never crash or
  replace the preview.

The affected feature document is `docs/regression/design-catalog.md`.

## Risks And Decisions

- Render trees expose computed output, not the Dart expression that created it.
  Token names are therefore presented as matches with explicit confidence.
- Flutter render-object details differ by target type. Unsupported properties
  remain absent rather than being guessed from ancestors.
- The inspector is developer tooling, not production app architecture, so the
  repository's architecture plan and implementation reviewers do not apply.
- This work is the local successor to open design-catalog PR #906. It stays
  local until that PR merges, following the repository's one-step-ahead rule.

## Delivery

Single follow-up PR after #906 merges:

`⚙️ Add a PREGO-aware design catalog inspector`

The implementation commit is expected to slightly exceed the 1,500-line soft
cap because 470 lines are a mechanically generated token index. The handwritten
implementation and focused tests remain below the cap, and splitting the index
from its only consumer would not produce an independently useful review unit.

Expected result: reviewers can inspect elements and sub-elements by hover or
pin, see resolved styling and honest PREGO token matches, navigate nested hit
targets, and use the catalog normally when inspection is disabled. There is no
database, persisted-data, service, production app, or analytics impact.
