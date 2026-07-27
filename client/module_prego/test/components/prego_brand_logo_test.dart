import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(PregoBrandLogo logo) {
  return MaterialApp(
    home: Scaffold(body: Center(child: logo)),
  );
}

void main() {
  for (final mapping in <({String pluginId, IconData icon})>[
    (pluginId: "opencode", icon: VESPRSolid.opencode),
    (pluginId: "codex", icon: VESPRSolid.codex),
    (pluginId: "cursor", icon: VESPRSolid.cursor),
    (pluginId: "future-plugin", icon: TablerRegular.plug),
  ]) {
    testWidgets("maps ${mapping.pluginId} to its bundled glyph", (tester) async {
      await tester.pumpWidget(_harness(PregoBrandLogo(pluginId: mapping.pluginId)));

      expect(find.byIcon(mapping.icon), findsOneWidget);
    });
  }

  testWidgets("forwards size and color while excluding decorative semantics", (tester) async {
    const color = Color(0xFF123456);
    await tester.pumpWidget(
      _harness(
        const PregoBrandLogo(
          pluginId: "opencode",
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
