import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// The test font renders every glyph 14px wide at this size, so a painted
/// width is a glyph count: "Claude Opus 5" is 13 glyphs, "…Opus 5" is 7.
void main() {
  const style = TextStyle(fontSize: 14);

  /// Loose constraints, as inside a chip's [Expanded]: the text may be narrower
  /// than its room.
  Future<void> pump(WidgetTester tester, {required Widget child}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ),
    );
  }

  double paintedWidth(WidgetTester tester) => tester.getSize(find.byType(PregoStartEllipsisText)).width;

  testWidgets("text that fits is shown whole", (tester) async {
    await pump(
      tester,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: const PregoStartEllipsisText(text: "Claude Opus 5", style: style),
      ),
    );
    expect(paintedWidth(tester), 13 * 14);
  });

  testWidgets("text that does not fit keeps its end behind a leading ellipsis", (tester) async {
    await pump(
      tester,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 100),
        child: const PregoStartEllipsisText(text: "Claude Opus 5", style: style),
      ),
    );
    // Seven glyphs fit: the ellipsis and "Opus 5", never "Claude".
    expect(paintedWidth(tester), 7 * 14);
  });

  testWidgets("an intrinsic-width parent sizes to the whole text", (tester) async {
    await pump(
      tester,
      child: const IntrinsicWidth(
        child: PregoStartEllipsisText(text: "Claude Opus 5", style: style),
      ),
    );
    expect(paintedWidth(tester), 13 * 14);
  });

  testWidgets("the system bold-text setting bolds the label, as it does any Text", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(boldText: true),
          child: Center(
            child: PregoStartEllipsisText(text: "Claude Opus 5", style: style),
          ),
        ),
      ),
    );
    final label = tester.renderObject<RenderStartEllipsisText>(find.byType(PregoStartEllipsisText));
    expect(label.style.fontWeight, FontWeight.bold);
  });

  testWidgets("screen readers get the whole text", (tester) async {
    await pump(
      tester,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 100),
        child: const PregoStartEllipsisText(text: "Claude Opus 5", style: style),
      ),
    );
    expect(find.bySemanticsLabel("Claude Opus 5"), findsOneWidget);
  });
}
