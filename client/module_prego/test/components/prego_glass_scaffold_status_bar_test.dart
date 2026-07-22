import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness({required PregoDesignSystem prego}) {
  return MaterialApp(
    theme: ThemeData(extensions: [prego]),
    home: const PregoGlassScaffold(
      title: "Title",
      automaticallyImplyLeading: false,
      slivers: [SliverToBoxAdapter(child: SizedBox(height: 10))],
    ),
  );
}

SystemUiOverlayStyle _statusBarStyle(WidgetTester tester) {
  final AnnotatedRegion<SystemUiOverlayStyle> region = tester.widget(
    find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
  );
  return region.value;
}

void main() {
  // The scaffold paints the app's own theme, so the status-bar icons have to
  // contrast with that — not with the device's appearance setting, which an
  // in-app light/dark choice deliberately overrides.

  testWidgets("a light app keeps dark status-bar icons on a dark device", (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(_harness(prego: PregoDesignSystem.light));
    await tester.pump();

    expect(_statusBarStyle(tester), SystemUiOverlayStyle.dark);
  });

  testWidgets("a dark app keeps light status-bar icons on a light device", (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(_harness(prego: PregoDesignSystem.dark));
    await tester.pump();

    expect(_statusBarStyle(tester), SystemUiOverlayStyle.light);
  });
}
