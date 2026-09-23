import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("the large title is 36 bold primary over the caller's subtitle row", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: const PregoGlassScaffold(
          title: "Projects",
          subtitle: PregoNavSubtitle(text: "Macbook-Pro.local", status: PregoNavStatus.online),
          automaticallyImplyLeading: false,
          slivers: [SliverFillRemaining(child: SizedBox.expand())],
        ),
      ),
    );

    final largeTitle = find.descendant(of: find.byType(CustomScrollView), matching: find.text("Projects"));
    final style = tester.widget<Text>(largeTitle).style!;
    expect(style.fontSize, 36);
    expect(style.fontWeight, FontWeight.bold);
    expect(style.color, PregoDesignSystem.light.colors.textPrimary);

    final subtitle = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(PregoNavSubtitle));
    expect(subtitle, findsOneWidget);
    expect(tester.getTopLeft(subtitle).dy, greaterThan(tester.getBottomLeft(largeTitle).dy - 1));
  });
}
