import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Widget app({required String? subtitle, required double scale}) => MaterialApp(
    theme: buildPregoThemeData(brightness: Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Center(
        child: SizedBox(
          height: PregoTopNavigation.barHeight,
          width: 300,
          child: Center(
            child: PregoNavTitle(title: "Bridge", subtitle: subtitle),
          ),
        ),
      ),
    ),
  );

  for (final subtitle in [null, ""]) {
    testWidgets("single title respects toolbar bounds without reducing text scale (subtitle: $subtitle)", (
      tester,
    ) async {
      await tester.pumpWidget(app(subtitle: subtitle, scale: 2.5));
      expect(tester.takeException(), isNull);
      final title = find.text("Bridge");
      expect(MediaQuery.textScalerOf(tester.element(title)).scale(18), 45);
      expect(tester.getSize(title).height, lessThanOrEqualTo(PregoTopNavigation.barHeight));
      expect(tester.widget<Text>(title).maxLines, 1);
      expect(tester.widget<Text>(title).overflow, TextOverflow.ellipsis);
    });
  }

  testWidgets("a subtitle retains its separate centered line", (tester) async {
    await tester.pumpWidget(app(subtitle: "This computer", scale: 1));
    final title = find.text("Bridge");
    final subtitle = find.text("This computer");
    expect(tester.takeException(), isNull);
    expect(tester.getCenter(title).dx, tester.getCenter(subtitle).dx);
    expect(tester.getRect(title).bottom, lessThanOrEqualTo(tester.getRect(subtitle).top));
    expect(tester.widget<Text>(subtitle).maxLines, 1);
  });
}
