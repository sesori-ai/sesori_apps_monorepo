import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_auto_continuation_chip.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Future<void> pumpChip(
    WidgetTester tester, {
    required SessionAutoContinuationView view,
    required bool updating,
    required VoidCallback onDisable,
    bool showLabel = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SessionAutoContinuationChip(
            surfaceStyle: PregoComposerSurfaceStyle.subtle,
            view: view,
            showLabel: showLabel,
            updating: updating,
            onDisable: onDisable,
          ),
        ),
      ),
    ),
  );

  PregoMenuItem disableEntry(WidgetTester tester) =>
      tester.widget<PregoAnchorMenu>(find.byType(PregoAnchorMenu)).entriesBuilder().whereType<PregoMenuItem>().single;

  testWidgets("tapping the chip offers Disable", (tester) async {
    var disabled = 0;
    await pumpChip(
      tester,
      view: const SessionAutoContinuationView(
        enabled: true,
        availability: AutoContinuationAvailability.conditional,
        status: SessionAutoContinuationStatus.idle(),
      ),
      updating: false,
      onDisable: () => disabled++,
    );
    expect(find.text("Auto-continue"), findsOneWidget);

    await tester.tap(find.byKey(const Key("session-auto-continuation-chip")));
    await tester.pumpAndSettle();
    expect(find.text("After quota resets"), findsOneWidget);
    await tester.tap(find.text("Disable"));
    await tester.pumpAndSettle();
    expect(disabled, 1);
  });

  testWidgets("a touch row shows only the clock and keeps the name for assistive tech", (tester) async {
    await pumpChip(
      tester,
      view: const SessionAutoContinuationView(
        enabled: true,
        availability: AutoContinuationAvailability.conditional,
        status: SessionAutoContinuationStatus.idle(),
      ),
      updating: false,
      onDisable: () {},
      showLabel: false,
    );
    expect(find.text("Auto-continue"), findsNothing);
    expect(find.bySemanticsLabel("Auto-continue"), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key("session-auto-continuation-chip"))), const Size.square(36));
  });

  testWidgets("the menu says when the last continuation was sent and waits while saving", (tester) async {
    final acceptedAt = DateTime(2030, 9, 25, 10, 2).millisecondsSinceEpoch;
    await pumpChip(
      tester,
      view: SessionAutoContinuationView(
        enabled: true,
        availability: AutoContinuationAvailability.conditional,
        status: SessionAutoContinuationStatus.submitted(acceptedAt: acceptedAt),
      ),
      updating: true,
      onDisable: () {},
    );
    final entry = disableEntry(tester);
    expect(entry.subtitle, allOf(contains("Continuation sent at"), contains("Sep 25, 2030")));
    expect(entry.isEnabled, isFalse);
  });

  testWidgets("an unavailable harness still offers Disable and says why", (tester) async {
    await pumpChip(
      tester,
      view: const SessionAutoContinuationView(
        enabled: true,
        availability: AutoContinuationAvailability.unavailable,
        status: SessionAutoContinuationStatus.idle(),
      ),
      updating: false,
      onDisable: () {},
    );
    final entry = disableEntry(tester);
    expect(entry.subtitle, contains("unavailable for this harness"));
    expect(entry.isEnabled, isTrue);
  });
}
