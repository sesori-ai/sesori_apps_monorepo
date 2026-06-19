import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/widgets/connection_graphic.dart";

/// Pumps [graphic] under a theme of the given [brightness] and returns the
/// asset name the resulting [Image] resolves to, so each test can assert the
/// state×brightness → artwork mapping.
///
/// Each test pumps a fresh tree exactly once: the named constructors are
/// `const`, so reusing one across pumps would canonicalize to the same element
/// and skip the rebuild on a theme change.
Future<String> _resolveAssetName(
  WidgetTester tester, {
  required Widget graphic,
  required Brightness brightness,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // ThemeData.light()/dark() set colorScheme.brightness, which is what
      // Theme.of(context).brightness (and thus context.isDarkMode) reads.
      theme: brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(body: Center(child: graphic)),
    ),
  );
  final image = tester.widget<Image>(find.byType(Image)).image as AssetImage;
  return image.assetName;
}

void main() {
  const base = "assets/images/projects_onboarding/connection_graphic";

  group("ConnectionGraphic.connectionOff", () {
    testWidgets("uses light artwork in light mode", (tester) async {
      final asset = await _resolveAssetName(
        tester,
        graphic: const ConnectionGraphic.connectionOff(),
        brightness: Brightness.light,
      );
      expect(asset, "$base/connection_off-light.png");
    });

    testWidgets("uses dark artwork in dark mode", (tester) async {
      final asset = await _resolveAssetName(
        tester,
        graphic: const ConnectionGraphic.connectionOff(),
        brightness: Brightness.dark,
      );
      expect(asset, "$base/connection_off-dark.png");
    });
  });

  group("ConnectionGraphic.connectionOn", () {
    testWidgets("uses light artwork in light mode", (tester) async {
      final asset = await _resolveAssetName(
        tester,
        graphic: const ConnectionGraphic.connectionOn(),
        brightness: Brightness.light,
      );
      expect(asset, "$base/connection_on-light.png");
    });

    testWidgets("uses dark artwork in dark mode", (tester) async {
      final asset = await _resolveAssetName(
        tester,
        graphic: const ConnectionGraphic.connectionOn(),
        brightness: Brightness.dark,
      );
      expect(asset, "$base/connection_on-dark.png");
    });
  });
}
