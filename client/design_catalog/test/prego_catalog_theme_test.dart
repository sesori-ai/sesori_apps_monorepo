import "package:flutter_test/flutter_test.dart";
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  test("catalog themes use the Prego surface background", () {
    expect(
      pregoCatalogLightTheme.scaffoldBackgroundColor,
      PregoDesignSystem.light.colors.bgSurface1,
    );
    expect(
      pregoCatalogDarkTheme.scaffoldBackgroundColor,
      PregoDesignSystem.dark.colors.bgSurface1,
    );
  });
}
