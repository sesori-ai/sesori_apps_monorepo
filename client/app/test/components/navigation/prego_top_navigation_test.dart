import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

/// Layout guards for [PregoTopNavigation].
///
/// 1. The bar title must stay centred on the whole bar regardless of whether a
///    leading button, trailing actions, both (even with mismatched widths), or
///    neither are present. `GlassAppBar` centres the title only within the gap
///    *between* its leading/actions slots, so a one-sided (or lopsided) bar used
///    to push the title off-centre; the bar lays itself out with a
///    [NavigationToolbar] to avoid that.
/// 2. The leading widget must keep its natural size. NavigationToolbar stretches
///    its leading slot to the full bar height, which squashed the circular glass
///    back button into an oval; the bar wraps the leading to prevent that.
void main() {
  const title = "Centered";

  Widget sideBox(double width, {Key? key}) =>
      SizedBox(key: key, width: width, height: 40, child: const ColoredBox(color: Color(0xFF000000)));

  Future<void> pumpBar(WidgetTester tester, {Widget? leading, List<Widget>? actions}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          appBar: PregoTopNavigation(
            title: title,
            inlineTitle: true,
            // Pin leading resolution to the explicit widget (or nothing) so the
            // test never depends on route-implied back buttons.
            automaticallyImplyLeading: false,
            leading: leading,
            actions: actions,
          ),
        ),
      ),
    );
  }

  double titleOffsetFromCentre(WidgetTester tester) {
    final screenCentreX = tester.getCenter(find.byType(MaterialApp)).dx;
    final titleCentreX = tester.getCenter(find.text(title)).dx;
    return titleCentreX - screenCentreX;
  }

  testWidgets("centres the title with a leading widget but no actions", (tester) async {
    await pumpBar(tester, leading: sideBox(48));
    expect(titleOffsetFromCentre(tester), moreOrLessEquals(0, epsilon: 1));
  });

  testWidgets("centres the title with actions but no leading widget", (tester) async {
    await pumpBar(tester, actions: [sideBox(48)]);
    expect(titleOffsetFromCentre(tester), moreOrLessEquals(0, epsilon: 1));
  });

  testWidgets("centres the title with leading and actions of different widths", (tester) async {
    // A wide leading and a narrow trailing would skew a between-the-slots
    // centring; the title must still sit on the bar's centre.
    await pumpBar(tester, leading: sideBox(96), actions: [sideBox(24)]);
    expect(titleOffsetFromCentre(tester), moreOrLessEquals(0, epsilon: 1));
  });

  testWidgets("centres the title with neither leading nor actions", (tester) async {
    await pumpBar(tester);
    expect(titleOffsetFromCentre(tester), moreOrLessEquals(0, epsilon: 1));
  });

  testWidgets("insets the leading and trailing buttons 16pt from the bar edges", (tester) async {
    const leadingKey = Key("leading");
    const trailingKey = Key("trailing");
    await pumpBar(tester, leading: sideBox(40, key: leadingKey), actions: [sideBox(40, key: trailingKey)]);

    // The bar spans the full width, so its edges are the screen edges.
    final screenWidth = tester.getSize(find.byType(MaterialApp)).width;
    expect(tester.getTopLeft(find.byKey(leadingKey)).dx, 16);
    expect(tester.getTopRight(find.byKey(trailingKey)).dx, screenWidth - 16);
  });

  testWidgets("keeps the leading widget at its natural size (no vertical stretch)", (tester) async {
    const leadingKey = Key("leading");
    await pumpBar(tester, leading: sideBox(40, key: leadingKey));

    // The bar is taller than the 40px button; the button must keep its natural
    // height instead of being stretched to fill the bar (which made the round
    // back button render as an oval).
    final renderedHeight = tester.getSize(find.byKey(leadingKey)).height;
    final barHeight = const PregoTopNavigation(title: title).preferredSize.height;
    expect(renderedHeight, 40);
    expect(renderedHeight, lessThan(barHeight));
  });
}
