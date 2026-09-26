import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";

void main() {
  for (final brightness in Brightness.values) {
    testWidgets("standalone recovery renders at large text scale in $brightness without DI", (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const PersistenceStartupFailureApp());
      await tester.pumpAndSettle();

      expect(find.text("Storage upgrade paused"), findsOneWidget);
      expect(
        find.text("Sesori couldn’t finish upgrading your local storage. Close and reopen Sesori to try again."),
        findsOneWidget,
      );
      expect(Theme.of(tester.element(find.byType(Scaffold))).brightness, brightness);
      expect(find.byType(Scrollable), findsOneWidget);
      expect(find.byType(ButtonStyleButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
