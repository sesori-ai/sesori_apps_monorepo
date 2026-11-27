import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/composer_chip_presence.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_wake_up_chip.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );

  final soon = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
  final wakeUps = [
    SessionWakeUp(id: "w-1", nextDueAt: soon, label: "Check CI", repeats: true, runsCommand: true),
    SessionWakeUp(id: "w-2", nextDueAt: soon + 3600000, label: "Ping review", repeats: false, runsCommand: false),
  ];

  testWidgets("the menu lists each wake-up with its marks, and Cancel names the one tapped", (tester) async {
    final cancelled = <String>[];
    await tester.pumpWidget(
      app(
        SessionWakeUpChip(
          surfaceStyle: PregoComposerSurfaceStyle.subtle,
          wakeUps: wakeUps,
          showLabel: true,
          onCancel: cancelled.add,
        ),
      ),
    );
    expect(find.textContaining("Wakes "), findsOneWidget);

    await tester.tap(find.byKey(const Key("session-wake-up-chip")));
    await tester.pumpAndSettle();
    expect(find.text("Check CI"), findsOneWidget);
    expect(find.text("Ping review"), findsOneWidget);
    expect(find.byKey(const Key("session-wake-up-repeat-mark")), findsOneWidget);
    expect(find.byKey(const Key("session-wake-up-once-mark")), findsOneWidget);
    expect(find.byKey(const Key("session-wake-up-command-mark")), findsOneWidget);

    await tester.tap(find.byKey(const Key("session-wake-up-cancel-w-2")));
    await tester.pumpAndSettle();
    expect(cancelled, ["w-2"]);
    expect(find.text("Ping review"), findsNothing);
  });

  testWidgets("the chip grows in beside the pickers and folds away without a jump", (tester) async {
    final presence = ValueNotifier(false);
    addTearDown(presence.dispose);
    await tester.pumpWidget(
      app(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 40, height: 20),
            ValueListenableBuilder(
              valueListenable: presence,
              builder: (context, shown, _) => ComposerChipPresence(
                gap: 8,
                chip: shown ? const SizedBox(key: Key("chip"), width: 40, height: 20) : null,
              ),
            ),
          ],
        ),
      ),
    );
    Future<void> pump({required bool present}) async {
      presence.value = present;
      await tester.pump();
    }

    double width() => tester.getSize(find.byType(ComposerChipPresence)).width;

    expect(width(), 0);

    await pump(present: true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(width(), inExclusiveRange(0, 48));
    await tester.pumpAndSettle();
    expect(width(), 48);

    await pump(present: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(width(), inExclusiveRange(0, 48));
    expect(find.byKey(const Key("chip")), findsOneWidget);
    await tester.pumpAndSettle();
    expect(width(), 0);
    expect(find.byKey(const Key("chip")), findsNothing);
  });
}
