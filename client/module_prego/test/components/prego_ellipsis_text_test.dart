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

  double paintedWidth(WidgetTester tester) => tester.getSize(find.byType(PregoEllipsisText)).width;

  testWidgets("text that fits is shown whole", (tester) async {
    await pump(
      tester,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: const PregoEllipsisText(text: "Claude Opus 5", style: style, ellipsis: PregoEllipsis.start),
      ),
    );
    expect(paintedWidth(tester), 13 * 14);
  });

  testWidgets("text that does not fit keeps its end behind a leading ellipsis", (tester) async {
    await pump(
      tester,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 100),
        child: const PregoEllipsisText(text: "Claude Opus 5", style: style, ellipsis: PregoEllipsis.start),
      ),
    );
    // Seven glyphs fit: the ellipsis and "Opus 5", never "Claude".
    expect(paintedWidth(tester), 7 * 14);
  });

  testWidgets("a middle ellipsis keeps both ends, the head taking the odd glyph", (tester) async {
    await pump(
      tester,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 100),
        child: const PregoEllipsisText(text: "feature/queue-fix", style: style, ellipsis: PregoEllipsis.middle),
      ),
    );
    // Seven glyphs fit: three from the head, the ellipsis, three from the tail.
    expect(tester.renderObject<RenderEllipsisText>(find.byType(PregoEllipsisText)).shownText, "fea…fix");
    expect(find.bySemanticsLabel("feature/queue-fix"), findsOneWidget);
  });

  testWidgets("an intrinsic-width parent sizes to the whole text", (tester) async {
    await pump(
      tester,
      child: const IntrinsicWidth(
        child: PregoEllipsisText(text: "Claude Opus 5", style: style, ellipsis: PregoEllipsis.start),
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
            child: PregoEllipsisText(text: "Claude Opus 5", style: style, ellipsis: PregoEllipsis.start),
          ),
        ),
      ),
    );
    final label = tester.renderObject<RenderEllipsisText>(find.byType(PregoEllipsisText));
    expect(label.style.fontWeight, FontWeight.bold);
  });

  testWidgets("screen readers get the whole text", (tester) async {
    await pump(
      tester,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 100),
        child: const PregoEllipsisText(text: "Claude Opus 5", style: style, ellipsis: PregoEllipsis.start),
      ),
    );
    expect(find.bySemanticsLabel("Claude Opus 5"), findsOneWidget);
  });
}
