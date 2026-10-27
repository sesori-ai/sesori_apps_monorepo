import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("PregoStatusLabel centres its dot on the first line of wrapped text", (tester) async {
    final style = PregoDesignSystem.light.textTheme.textXs.regular;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
              width: 80,
              child: PregoStatusLabel(
                status: PregoNavStatus.error,
                text: "Offline · last seen 3h ago",
                style: style,
                maxLines: null,
              ),
            ),
          ),
        ),
      ),
    );

    final text = find.text("Offline · last seen 3h ago");
    final dot = find.descendant(of: find.byType(PregoStatusLabel), matching: find.byType(Container));
    final TextStyle(:fontSize, :height) = style;
    if (fontSize == null || height == null) fail("Prego text styles declare font size and height.");
    final lineHeight = fontSize * height;
    expect(tester.getSize(text).height, greaterThan(lineHeight), reason: "the text wraps");
    expect(tester.getCenter(dot).dy, moreOrLessEquals(tester.getTopLeft(text).dy + lineHeight / 2, epsilon: 0.5));
    expect(
      tester.widget<Container>(dot).decoration,
      isA<BoxDecoration>().having((d) => d.color, "color", PregoDesignSystem.light.colors.fgErrorPrimary),
    );
  });
}
