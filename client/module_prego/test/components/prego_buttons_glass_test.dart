import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness(Widget child) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets("renders leading icon, label, caret, and routes taps", (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        PregoButtonsGlass(
          leadingIcon: Icons.smart_toy_outlined,
          label: "Agent",
          onPressed: () => taps++,
        ),
      ),
    );

    expect(find.text("Agent"), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    // The trailing caret signals the pill opens a menu.
    expect(find.byIcon(Icons.unfold_more), findsOneWidget);

    await tester.tap(find.byType(PregoButtonsGlass));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets("ellipsizes a long label instead of overflowing", (tester) async {
    await tester.pumpWidget(
      _harness(
        Row(
          children: [
            Expanded(
              child: PregoButtonsGlass(
                leadingIcon: Icons.memory_outlined,
                label: "An extremely long model name that cannot possibly fit in one pill" * 3,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );

    // No overflow error: the label clamps to one ellipsized line inside the pill.
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
