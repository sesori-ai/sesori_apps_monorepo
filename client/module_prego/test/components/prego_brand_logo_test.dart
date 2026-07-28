import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_test/flutter_test.dart";
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

void main() {
  for (final mapping in <({String pluginId, String asset})>[
    (pluginId: Harness.opencode.name, asset: "assets/svgs/brands/opencode.svg"),
    (pluginId: Harness.codex.name, asset: "assets/svgs/brands/codex.svg"),
    (pluginId: Harness.cursor.name, asset: "assets/svgs/brands/cursor.svg"),
  ]) {
    testWidgets("maps ${mapping.pluginId} to its bundled artwork", (tester) async {
      await tester.pumpWidget(_harness(logo: PregoBrandLogo(pluginId: mapping.pluginId, color: null)));

      final loader = _loaderOf(tester);
      expect(loader.assetName, mapping.asset);
      expect(loader.packageName, "theme_prego");
    });
  }

  testWidgets("falls back to a tinted plug for a harness it has no artwork for", (tester) async {
    const color = Color(0xFF123456);
    await tester.pumpWidget(_harness(logo: const PregoBrandLogo(pluginId: "future-plugin", color: color)));

    expect(find.byType(SvgPicture), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(TablerRegular.plug));
    expect(icon.color, color);
  });

  test("names each harness it has a mark for, and speaks an unknown id as-is", () {
    expect(PregoBrandLogo.displayNameFor(Harness.opencode.name), "OpenCode");
    expect(PregoBrandLogo.displayNameFor(Harness.codex.name), "Codex");
    expect(PregoBrandLogo.displayNameFor(Harness.cursor.name), "Cursor");
    expect(PregoBrandLogo.displayNameFor("future-plugin"), "future-plugin");
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

  group("the greys the artwork is drawn in", () {
    testWidgets("stay as exported under the light theme", (tester) async {
      await tester.pumpWidget(_harness(logo: PregoBrandLogo(pluginId: Harness.opencode.name, color: null)));

      // A no-op in light mode: the export already carries these values.
      final mapper = _loaderOf(tester).colorMapper!;
      expect(mapper.substitute(null, "path", "fill", const Color(0xFF141414)), PregoDesignSystem.light.colors.textPrimary);
      expect(
        mapper.substitute(null, "path", "fill", const Color(0xFF474747)),
        PregoDesignSystem.light.colors.textSecondary,
      );
    });

    testWidgets("flip with the dark theme, leaving brand colours alone", (tester) async {
      await tester.pumpWidget(
        _harness(logo: PregoBrandLogo(pluginId: Harness.opencode.name, color: null), brightness: Brightness.dark),
      );

      final mapper = _loaderOf(tester).colorMapper!;
      // Near-black marks would all but vanish on a dark surface.
      expect(mapper.substitute(null, "path", "fill", const Color(0xFF141414)), PregoDesignSystem.dark.colors.textPrimary);
      expect(
        mapper.substitute(null, "path", "fill", const Color(0xFF474747)),
        PregoDesignSystem.dark.colors.textSecondary,
      );
      // Codex's gradient is its own, and white is load-bearing in the masks.
      expect(mapper.substitute(null, "stop", "stop-color", const Color(0xFF3941FF)), const Color(0xFF3941FF));
      expect(mapper.substitute(null, "path", "fill", const Color(0xFFFFFFFF)), const Color(0xFFFFFFFF));
    });
  });
}
