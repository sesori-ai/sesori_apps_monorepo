import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Widget app({required Brightness brightness}) {
    final design = brightness == Brightness.dark ? PregoDesignSystem.dark : PregoDesignSystem.light;
    final scheme = brightness == Brightness.dark ? const ColorScheme.dark() : const ColorScheme.light();
    return MaterialApp(
      theme: ThemeData(colorScheme: scheme, extensions: [design]),
      home: const Scaffold(
        body: PregoInlineAlertsNotifications(
          title: "Loading",
          type: PregoInlineAlertsNotificationsType.loading,
        ),
      ),
    );
  }

  Color spinnerColor(WidgetTester tester) =>
      tester.widget<PregoActivityIndicator>(find.byType(PregoActivityIndicator)).color ?? const Color(0x00000000);

  testWidgets("a loading alert on the inverted light-theme card uses the dark-surface grey", (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(app(brightness: Brightness.light));
      expect(spinnerColor(tester), PregoActivityIndicator.naturalColor(brightness: Brightness.dark));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets("a loading alert on the inverted dark-theme card uses the light-surface grey", (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(app(brightness: Brightness.dark));
      expect(spinnerColor(tester), PregoActivityIndicator.naturalColor(brightness: Brightness.light));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
