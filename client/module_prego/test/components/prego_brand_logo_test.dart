import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;
import "package:theme_prego/module_prego.dart";

Widget _harness({required PregoBrandLogo logo}) {
  return MaterialApp(
    home: Scaffold(body: Center(child: logo)),
  );
}

void main() {
  for (final mapping in <({String pluginId, IconData icon})>[
    (pluginId: Harness.opencode.name, icon: VESPRSolid.opencode),
    (pluginId: Harness.codex.name, icon: VESPRSolid.codex),
    (pluginId: Harness.cursor.name, icon: VESPRSolid.cursor),
    (pluginId: "future-plugin", icon: TablerRegular.plug),
  ]) {
    testWidgets("maps ${mapping.pluginId} to its bundled glyph", (tester) async {
      await tester.pumpWidget(
        _harness(
          logo: PregoBrandLogo(
            pluginId: mapping.pluginId,
            color: null,
          ),
        ),
      );

      expect(find.byIcon(mapping.icon), findsOneWidget);
    });
  }

  test("names each harness it has a glyph for, and speaks an unknown id as-is", () {
    expect(PregoBrandLogo.displayNameFor(Harness.opencode.name), "OpenCode");
    expect(PregoBrandLogo.displayNameFor(Harness.codex.name), "Codex");
    expect(PregoBrandLogo.displayNameFor(Harness.cursor.name), "Cursor");
    expect(PregoBrandLogo.displayNameFor("future-plugin"), "future-plugin");
  });

  testWidgets("forwards size and color while excluding decorative semantics", (tester) async {
    const color = Color(0xFF123456);
    await tester.pumpWidget(
      _harness(
        logo: PregoBrandLogo(
          pluginId: Harness.opencode.name,
          size: 28,
          color: color,
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(VESPRSolid.opencode));
    expect(icon.size, 28);
    expect(icon.color, color);
    expect(
      find.descendant(
        of: find.byType(PregoBrandLogo),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
  });
}
