import "dart:io";

import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;
import "package:theme_prego/module_prego.dart";

Widget _harness({required PregoBrandLogo logo, Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      extensions: [brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark],
    ),
    home: Scaffold(body: Center(child: logo)),
  );
}

SvgAssetLoader _loaderOf(WidgetTester tester) =>
    tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader as SvgAssetLoader;

List<String> _pathElements(String svg) =>
    RegExp(r"<path\b[^>]*>").allMatches(svg).map((match) => match.group(0)!).toList();

void main() {
  for (final mapping in <({String pluginId, String lightAsset, String darkAsset})>[
    (
      pluginId: Harness.opencode.name,
      lightAsset: "assets/svgs/brands/opencode_light.svg",
      darkAsset: "assets/svgs/brands/opencode_dark.svg",
    ),
    (
      pluginId: Harness.codex.name,
      lightAsset: "assets/svgs/brands/codex_light.svg",
      darkAsset: "assets/svgs/brands/codex_dark.svg",
    ),
    (
      pluginId: Harness.cursor.name,
      lightAsset: "assets/svgs/brands/cursor_light.svg",
      darkAsset: "assets/svgs/brands/cursor_dark.svg",
    ),
    (
      pluginId: Harness.claude.name,
      lightAsset: "assets/svgs/brands/claude_light.svg",
      darkAsset: "assets/svgs/brands/claude_dark.svg",
    ),
    (
      pluginId: Harness.hermes.name,
      lightAsset: "assets/svgs/brands/hermes_light.svg",
      darkAsset: "assets/svgs/brands/hermes_dark.svg",
    ),
    (
      pluginId: Harness.pi.name,
      lightAsset: "assets/svgs/brands/pi_light.svg",
      darkAsset: "assets/svgs/brands/pi_dark.svg",
    ),
    (
      pluginId: Harness.omp.name,
      lightAsset: "assets/svgs/brands/omp.svg",
      darkAsset: "assets/svgs/brands/omp.svg",
    ),
  ]) {
    testWidgets("maps ${mapping.pluginId} to its bundled artwork", (tester) async {
      await tester.pumpWidget(_harness(logo: PregoBrandLogo(pluginId: mapping.pluginId, color: null)));

      final loader = _loaderOf(tester);
      expect(loader.assetName, mapping.lightAsset);
      expect(loader.packageName, "theme_prego");
    });

    testWidgets("follows the dark theme with ${mapping.pluginId}'s dark artwork", (tester) async {
      await tester.pumpWidget(
        _harness(
          logo: PregoBrandLogo(pluginId: mapping.pluginId, color: null),
          brightness: Brightness.dark,
        ),
      );

      expect(_loaderOf(tester).assetName, mapping.darkAsset);
    });
  }

  testWidgets("falls back to a tinted plug for a harness it has no artwork for", (tester) async {
    const color = Color(0xFF123456);
    await tester.pumpWidget(
      _harness(
        logo: const PregoBrandLogo(pluginId: "future-plugin", color: color),
      ),
    );

    expect(find.byType(SvgPicture), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(TablerRegular.plug));
    expect(icon.color, color);
  });

  test("names each harness it has a mark for, and speaks an unknown id as-is", () {
    expect(PregoBrandLogo.displayNameFor(Harness.opencode.name), "OpenCode");
    expect(PregoBrandLogo.displayNameFor(Harness.codex.name), "Codex");
    expect(PregoBrandLogo.displayNameFor(Harness.cursor.name), "Cursor");
    expect(PregoBrandLogo.displayNameFor(Harness.claude.name), "Claude Code");
    expect(PregoBrandLogo.displayNameFor(Harness.hermes.name), "Hermes Agent");
    expect(PregoBrandLogo.displayNameFor(Harness.pi.name), "Pi");
    expect(PregoBrandLogo.displayNameFor(Harness.omp.name), "Oh My Pi");
    expect(PregoBrandLogo.displayNameFor("future-plugin"), "future-plugin");
  });

  test("dark Hermes artwork insets the same mark inside a white circle", () {
    final light = File("assets/svgs/brands/hermes_light.svg").readAsStringSync();
    final dark = File("assets/svgs/brands/hermes_dark.svg").readAsStringSync();

    expect(_pathElements(dark), _pathElements(light));
    expect(dark, contains('<circle cx="12" cy="12" r="12" fill="#FFFFFF"/>'));
    expect(dark, contains('transform="translate(3 3) scale(0.75)"'));
    expect(light, isNot(contains("<circle")));
  });

  testWidgets("forwards size and keeps the mark decorative", (tester) async {
    await tester.pumpWidget(_harness(logo: PregoBrandLogo(pluginId: Harness.opencode.name, size: 28, color: null)));

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, 28);
    expect(svg.height, 28);
    expect(
      find.descendant(of: find.byType(PregoBrandLogo), matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
  });
}
