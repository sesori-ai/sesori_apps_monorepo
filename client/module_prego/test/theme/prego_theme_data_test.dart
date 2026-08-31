import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  test("assembles the complete light Prego Material theme", () {
    final ThemeData theme = buildPregoThemeData(brightness: Brightness.light);

    expect(theme.colorScheme, PregoColors.light.toFlutterColorScheme());
    expect(theme.textTheme.bodyLarge?.fontFamily, PregoTextTheme.fontFamily);
    expect(theme.textTheme.bodyLarge?.color, PregoTextTheme.light.asFlutterTextTheme().bodyLarge.color);
    expect(theme.extension<PregoDesignSystem>(), same(PregoDesignSystem.light));
    expect(theme.scaffoldBackgroundColor, PregoDesignSystem.light.colors.bgSurface1);
    expect(theme.appBarTheme.systemOverlayStyle, SystemUiOverlayStyle.dark);
  });

  test("assembles the complete dark Prego Material theme", () {
    final ThemeData theme = buildPregoThemeData(brightness: Brightness.dark);

    expect(theme.colorScheme, PregoColors.dark.toFlutterColorScheme());
    expect(theme.textTheme.bodyLarge?.fontFamily, PregoTextTheme.fontFamily);
    expect(theme.textTheme.bodyLarge?.color, PregoTextTheme.dark.asFlutterTextTheme().bodyLarge.color);
    expect(theme.extension<PregoDesignSystem>(), same(PregoDesignSystem.dark));
    expect(theme.scaffoldBackgroundColor, PregoDesignSystem.dark.colors.bgSurface1);
    expect(theme.appBarTheme.systemOverlayStyle, SystemUiOverlayStyle.light);
  });
}
