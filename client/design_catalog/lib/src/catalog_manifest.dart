import "catalog_scenarios.dart";

const catalogManifestPath = "web/catalog_manifest.json";
const catalogScenarioSourcePath = "client/design_catalog/lib/src/catalog_scenarios.dart";
const catalogComponentSourcePath = "client/module_prego/lib/components/buttons/prego_buttons_solid.dart";

/// Agent-readable design graph generated from the same registry as Widgetbook.
// ignore: no_slop_linter/prefer_specific_type, JSON-compatible recursive value boundary
Map<String, Object?> buildCatalogManifest() => {
  "schemaVersion": 1,
  "catalog": "Sesori Flutter design catalog",
  "source": catalogScenarioSourcePath,
  "dependencies": [
    {
      "from": "client/design_catalog",
      "to": "client/module_prego",
      "package": "theme_prego",
    },
  ],
  "components": [
    {
      "id": "prego-buttons-solid",
      "name": "PregoButtonsSolid",
      "source": catalogComponentSourcePath,
      "scenarioCount": catalogScenarios.length,
      "scenarios": catalogScenarios.map((scenario) => scenario.toJson()).toList(growable: false),
    },
  ],
};
