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

  testWidgets("PregoStatusLabel keeps an ambient style that declares no line height", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: const Scaffold(
          body: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
              width: 80,
              child: DefaultTextStyle(
                style: TextStyle(fontSize: 12),
                child: PregoStatusLabel(
                  status: PregoNavStatus.online,
                  text: "Offline · last seen 3h ago",
                  style: null,
                  maxLines: null,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final text = find.text("Offline · last seen 3h ago");
    final dot = find.descendant(of: find.byType(PregoStatusLabel), matching: find.byType(Container));
    final textRect = tester.getRect(text);
    expect(textRect.height, greaterThan(24), reason: "the text wraps");
    // Centred on the first of the wrapped lines, not the whole block.
    expect(tester.getCenter(dot).dy, lessThan(textRect.top + 12));
  });
}
