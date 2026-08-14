import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_design_catalog/src/catalog_manifest.dart";
import "package:sesori_design_catalog/src/catalog_scenario.dart";
import "package:sesori_design_catalog/src/catalog_scenarios.dart";

void main() {
  test("curated scenario ids are unique", () {
    final ids = catalogScenarios.map((scenario) => scenario.id).toSet();

    expect(ids, hasLength(catalogScenarios.length));
  });

  test("curated scenarios contain only production-valid combinations", () {
    for (final scenario in catalogScenarios) {
      final isPrimaryAltWithUnsupportedTone =
          scenario.hierarchy == CatalogButtonHierarchy.primaryAlt && scenario.tone != CatalogButtonTone.regular;
      final isRestrictedToneOutsidePrimary =
          (scenario.tone == CatalogButtonTone.warning || scenario.tone == CatalogButtonTone.success) &&
          scenario.hierarchy != CatalogButtonHierarchy.primary;

      expect(isPrimaryAltWithUnsupportedTone, isFalse, reason: scenario.id);
      expect(isRestrictedToneOutsidePrimary, isFalse, reason: scenario.id);
    }
  });

  test("manifest source paths resolve to repository files", () {
    expect(File("../../$catalogScenarioSourcePath").existsSync(), isTrue);
    expect(File("../../$catalogComponentSourcePath").existsSync(), isTrue);
  });

  test("checked-in manifest matches the scenario registry", () {
    final checkedInManifest = jsonDecode(File(catalogManifestPath).readAsStringSync());

    expect(checkedInManifest, buildCatalogManifest());
  });
}
