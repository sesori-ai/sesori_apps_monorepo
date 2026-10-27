import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockComputerSwitcherCubit() extends MockCubit<ComputerSwitcherState> implements ComputerSwitcherCubit;

BridgeSummary _computer({required String id, required BridgeRegistrationStatus status}) => BridgeSummary(
  id: id,
  name: "computer-$id",
  hostname: "computer-$id",
  platform: BridgePlatform.linux,
  status: status,
  addedAt: DateTime.utc(2026),
  lastSeenAt: null,
);

BridgeSummary _online(String id) => _computer(id: id, status: BridgeRegistrationStatus.active);

BridgeSummary _offline(String id) => _computer(id: id, status: BridgeRegistrationStatus.inactive);

void main() {
  late List<(String, ComputerSwitchSource)> switches;

  setUp(() => switches = []);

  /// Pumps the card for an account whose computers are [computers], with the
  /// app pointed at the offline computer "target".
  Future<void> pumpCard(WidgetTester tester, {required List<BridgeSummary> computers}) async {
    final cubit = _MockComputerSwitcherCubit();
    whenListen(
      cubit,
      const Stream<ComputerSwitcherState>.empty(),
      initialState: ComputerSwitcherState(
        computers: [_offline("target"), ...computers],
        targetId: "target",
        localId: null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<ComputerSwitcherCubit>.value(
            value: cubit,
            child: OtherComputersCard(
              onSwitchComputer: ({required bridgeId, required source}) => switches.add((bridgeId, source)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("takes no space when the account has no other computer", (tester) async {
    await pumpCard(tester, computers: const []);

    expect(find.text("Other computers"), findsNothing);
    expect(tester.getSize(find.byType(OtherComputersCard)).height, 0);
  });

  testWidgets("grows to fit the list that arrives under reduced motion", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpCard(tester, computers: const []);

    await pumpCard(tester, computers: [_online("b")]);

    expect(find.text("computer-b"), findsOneWidget);
    expect(tester.getSize(find.byType(OtherComputersCard)).height, greaterThan(0));
  });

  testWidgets("says so when no other computer is online", (tester) async {
    await pumpCard(tester, computers: [_offline("b"), _offline("c")]);

    expect(find.text("Other computers"), findsOneWidget);
    expect(find.text("No other computers online"), findsOneWidget);
    expect(find.text("computer-b"), findsNothing);
  });

  testWidgets("lists only the online computers, never the offline target, and switches on tap", (tester) async {
    await pumpCard(tester, computers: [_offline("b"), _online("c")]);

    expect(find.text("computer-target"), findsNothing);
    expect(find.text("computer-b"), findsNothing);
    expect(find.text("No other computers online"), findsNothing);

    await tester.tap(find.text("computer-c"));
    await tester.pumpAndSettle();

    expect(switches, [("c", ComputerSwitchSource.offlineScreen)]);
  });

  testWidgets("lists two online computers without a fold row", (tester) async {
    await pumpCard(tester, computers: [_online("b"), _online("c")]);

    expect(find.text("computer-b"), findsOneWidget);
    expect(find.text("computer-c"), findsOneWidget);
    expect(find.textContaining("+ "), findsNothing);
  });

  testWidgets("folds the rest into a row that opens the computer menu", (tester) async {
    await pumpCard(tester, computers: [_online("b"), _online("c"), _online("d"), _online("e")]);

    expect(find.text("computer-b"), findsOneWidget);
    expect(find.text("computer-c"), findsOneWidget);
    expect(find.text("computer-d"), findsNothing);

    await tester.tap(find.text("+ 2 others"));
    await tester.pumpAndSettle();
    // The menu lists every computer, the offline target included.
    expect(find.byKey(const ValueKey("computer-menu-target")), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("computer-menu-e")));
    await tester.pumpAndSettle();

    expect(switches, [("e", ComputerSwitchSource.offlineScreen)]);
  });

  testWidgets("a single unlisted computer reads as one other", (tester) async {
    await pumpCard(tester, computers: [_online("b"), _online("c"), _online("d")]);

    expect(find.text("+ 1 other"), findsOneWidget);
  });
}
