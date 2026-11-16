import "package:flutter/rendering.dart" show RenderParagraph;
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  const suffix = " (fork)";
  const style = TextStyle(fontSize: 16);
  const boundsKey = Key("bounds");

  Widget app({required String text, required double width}) => MaterialApp(
    home: Center(
      child: SizedBox(
        key: boundsKey,
        width: width,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: PregoKeptSuffixText(text: text, keptSuffix: suffix, style: style),
        ),
      ),
    ),
  );

  Finder inside(Finder matching) => find.descendant(of: find.byType(PregoKeptSuffixText), matching: matching);

  testWidgets("a long suffixed text cuts before the suffix and keeps the suffix whole", (tester) async {
    final semantics = tester.ensureSemantics();
    const text = "Math Utilities Summary of every helper$suffix";
    await tester.pumpWidget(app(text: text, width: 200));

    expect(tester.takeException(), isNull);
    expect(
      tester.renderObject<RenderParagraph>(find.text("Math Utilities Summary of every helper")).didExceedMaxLines,
      isTrue,
    );
    expect(tester.renderObject<RenderParagraph>(find.text(suffix)).didExceedMaxLines, isFalse);
    expect(tester.getTopRight(find.text(suffix)).dx, lessThanOrEqualTo(tester.getTopRight(find.byKey(boundsKey)).dx));
    // Read as one whole title, not as two fragments.
    expect(find.text(text), findsOneWidget);
    expect(tester.getSemantics(find.byType(PregoKeptSuffixText)), isSemantics(label: text));
    semantics.dispose();
  });

  testWidgets("a short suffixed text shows whole, as wide as the plain text", (tester) async {
    const text = "Math$suffix";
    await tester.pumpWidget(app(text: text, width: 200));

    expect(tester.renderObject<RenderParagraph>(find.text("Math")).didExceedMaxLines, isFalse);
    expect(tester.renderObject<RenderParagraph>(find.text(suffix)).didExceedMaxLines, isFalse);
    final plain = TextPainter(
      text: const TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    addTearDown(plain.dispose);
    expect(tester.getSize(find.byType(PregoKeptSuffixText)).width, moreOrLessEquals(plain.width, epsilon: 1));
  });

  testWidgets("a text without the suffix is a plain Text", (tester) async {
    const text = "Math Utilities Summary of every helper";
    await tester.pumpWidget(app(text: text, width: 200));

    expect(inside(find.byType(Row)), findsNothing);
    expect(inside(find.byType(RichText)), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(inside(find.byType(RichText)));
    expect(paragraph.text.toPlainText(), text);
    expect(paragraph.maxLines, 1);
    expect(paragraph.overflow, TextOverflow.ellipsis);
  });
}
