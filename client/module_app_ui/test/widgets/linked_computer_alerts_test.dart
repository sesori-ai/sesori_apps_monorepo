import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late MockRegisteredBridgesService registeredBridges;
  late List<(String, ComputerSwitchSource)> switches;

  final laptop = testBridgeSummary(id: "br_laptop", name: "dev-laptop");
  final workstation = testBridgeSummary(id: "br_workstation", name: "workstation");

  Future<void> pumpAlerts(WidgetTester tester) async {
    registeredBridges = MockRegisteredBridgesService();
    switches = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => LinkedComputerAlertCubit(
            registeredBridgesService: registeredBridges,
            activeBridgeLocality: const FakeActiveBridgeLocality(),
          ),
          child: LinkedComputerAlerts(
            navigatorKey: null,
            onSwitchComputer: ({required bridgeId, required source}) => switches.add((bridgeId, source)),
            child: const Scaffold(),
          ),
        ),
      ),
    );
  }

  Future<void> linkWorkstation(WidgetTester tester) async {
    registeredBridges.emitBridges(bridges: [laptop]);
    await tester.pump();
    registeredBridges.emitBridges(bridges: [workstation, laptop]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets("names a newly linked computer and offers to switch to it", (tester) async {
    await pumpAlerts(tester);

    await linkWorkstation(tester);

    expect(find.text("workstation is now linked"), findsOneWidget);
    expect(find.text("Switch"), findsOneWidget);
  });

  testWidgets("Switch switches to that computer from the alert and dismisses it", (tester) async {
    await pumpAlerts(tester);
    await linkWorkstation(tester);

    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Switch"));
    await tester.pumpAndSettle();

    expect(switches, [("br_workstation", ComputerSwitchSource.alert)]);
    expect(find.text("workstation is now linked"), findsNothing);
  });

  testWidgets("stays long enough to act on, then leaves on its own", (tester) async {
    await pumpAlerts(tester);
    await linkWorkstation(tester);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text("workstation is now linked"), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text("workstation is now linked"), findsNothing);
  });
}
