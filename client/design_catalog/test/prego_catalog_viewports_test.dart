import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_design_catalog/src/prego_catalog_viewports.dart";

void main() {
  test("catalog viewport names are unique", () {
    final names = PregoCatalogViewports.all.map((viewport) => viewport.name);

    expect(names.toSet(), hasLength(names.length));
  });

  test("catalog phone presets use mobile target platforms", () {
    final phoneViewports = PregoCatalogViewports.all.skip(1);

    expect(
      phoneViewports.map((viewport) => viewport.platform),
      everyElement(isIn([TargetPlatform.iOS, TargetPlatform.android])),
    );
  });
}
