import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(PregoBrandLogo logo) {
  return MaterialApp(
    home: Scaffold(body: Center(child: logo)),
  );
}

void main() {
  for (final mapping in <({String? key, IconData icon})>[
    (key: "opencode", icon: VESPRSolid.opencode),
    (key: "codex", icon: VESPRSolid.codex),
    (key: "cursor", icon: VESPRSolid.cursor),
    (key: "future-brand", icon: TablerRegular.plug),
    (key: null, icon: TablerRegular.plug),
  ]) {
    testWidgets("maps ${mapping.key ?? "null"} to its bundled glyph", (tester) async {
      await tester.pumpWidget(_harness(PregoBrandLogo(brandLogoKey: mapping.key)));

      expect(find.byIcon(mapping.icon), findsOneWidget);
    });
  }

  testWidgets("forwards size and color while excluding decorative semantics", (tester) async {
    const color = Color(0xFF123456);
    await tester.pumpWidget(
      _harness(
        const PregoBrandLogo(
          brandLogoKey: "opencode",
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
