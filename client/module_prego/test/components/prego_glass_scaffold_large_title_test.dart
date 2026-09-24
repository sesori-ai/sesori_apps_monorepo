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

  testWidgets("largeTitleInBar rests the title in the bar row beside the actions", (tester) async {
    Future<void> pump({required bool inBar}) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: PregoGlassScaffold(
          title: "Settings",
          largeTitleInBar: inBar,
          automaticallyImplyLeading: false,
          actions: [PregoButtonsIconGlass(icon: Icons.close, semanticLabel: "Close", onPressed: () {})],
          slivers: const [SliverFillRemaining(child: SizedBox.expand())],
        ),
      ),
    );
    final largeTitle = find.descendant(of: find.byType(CustomScrollView), matching: find.text("Settings"));
    final close = find.bySemanticsLabel("Close");

    await pump(inBar: false);
    final belowBarTop = tester.getTopLeft(largeTitle).dy;
    expect(belowBarTop, greaterThan(tester.getBottomLeft(close).dy));

    await pump(inBar: true);
    // Centred on the close button's row, and one bar row higher than before.
    expect(tester.getCenter(largeTitle).dy, moreOrLessEquals(tester.getCenter(close).dy, epsilon: 1));
    expect(tester.getTopLeft(largeTitle).dy, lessThan(belowBarTop));
    // It takes the bar's own inset, the same edge as page content.
    expect(tester.getTopLeft(largeTitle).dx, PregoSpacing.xl);
  });
}
