import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/theme/sesori_dark_theme.dart";
import "package:sesori_mobile/core/theme/sesori_light_theme.dart";
import "package:sesori_mobile/core/theme/sesori_theme_tokens.dart";

void main() {
  test("light and dark themes use Sesori tokens", () {
    expect(sesoriLightTheme.textTheme.bodyMedium?.fontFamily, SesoriThemeTokens.fontFamily);
    expect(sesoriDarkTheme.textTheme.bodyMedium?.fontFamily, SesoriThemeTokens.fontFamily);
    expect(sesoriLightTheme.brightness, Brightness.light);
    expect(sesoriDarkTheme.brightness, Brightness.dark);
  });

  testWidgets("light theme renders material surfaces", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sesoriLightTheme,
        home: const Scaffold(
          body: Card(
            child: Text("light"),
          ),
        ),
      ),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.surface, isNotNull);
    expect(find.text("light"), findsOneWidget);
  });

  testWidgets("dark theme renders material surfaces", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sesoriDarkTheme,
        home: const Scaffold(
          body: Card(
            child: Text("dark"),
          ),
        ),
      ),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.surface, isNotNull);
    expect(find.text("dark"), findsOneWidget);
  });
}
