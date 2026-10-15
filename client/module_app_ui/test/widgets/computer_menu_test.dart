import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockComputerSwitcherCubit() extends MockCubit<ComputerSwitcherState> implements ComputerSwitcherCubit;

BridgeSummary _computer({
  required String id,
  required String name,
  required BridgeRegistrationStatus status,
  required DateTime? lastSeenAt,
}) => BridgeSummary(
  id: id,
  name: name,
  hostname: name,
  platform: BridgePlatform.macos,
  status: status,
  addedAt: DateTime.utc(2026),
  lastSeenAt: lastSeenAt,
);

void main() {
  late List<String> selected;

  setUp(() => selected = []);

  Future<void> pumpMenu(WidgetTester tester, {required VoidCallback? onManageComputers}) async {
    final cubit = _MockComputerSwitcherCubit();
    whenListen(
      cubit,
      const Stream<ComputerSwitcherState>.empty(),
      initialState: ComputerSwitcherState(
        computers: [
          _computer(id: "a", name: "studio-mac", status: BridgeRegistrationStatus.active, lastSeenAt: null),
          _computer(
            id: "b",
            name: "work-laptop",
            status: BridgeRegistrationStatus.inactive,
            lastSeenAt: DateTime.now().subtract(const Duration(hours: 5)),
          ),
          _computer(id: "c", name: "old-tower", status: BridgeRegistrationStatus.inactive, lastSeenAt: null),
        ],
        targetId: "a",
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
            child: ComputerMenu(
              onSelect: ({required bridgeId}) => selected.add(bridgeId),
              onManageComputers: onManageComputers,
              triggerBuilder: (context, toggle) => TextButton(onPressed: toggle, child: const Text("trigger")),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("trigger"));
    await tester.pumpAndSettle();
  }

  testWidgets("lists each computer with its presence and checks the current one", (tester) async {
    await pumpMenu(tester, onManageComputers: null);

    expect(find.text("studio-mac"), findsOneWidget);
    expect(find.text("Online"), findsOneWidget);
    expect(find.text("Offline · last seen 5h ago"), findsOneWidget);
    expect(find.text("Offline"), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey("computer-menu-a")), matching: find.byIcon(TablerRegular.check)),
      findsOneWidget,
    );
    expect(find.byIcon(TablerRegular.check), findsOneWidget);
  });

  testWidgets("picking another computer switches to it and closes the menu", (tester) async {
    await pumpMenu(tester, onManageComputers: null);

    await tester.tap(find.text("work-laptop"));
    await tester.pumpAndSettle();

    expect(selected, ["b"]);
    expect(find.text("work-laptop"), findsNothing);
  });

  testWidgets("picking the current computer only closes the menu", (tester) async {
    await pumpMenu(tester, onManageComputers: null);

    await tester.tap(find.text("studio-mac"));
    await tester.pumpAndSettle();

    expect(selected, isEmpty);
    expect(find.text("studio-mac"), findsNothing);
  });

  testWidgets("offers no management footer without a callback", (tester) async {
    await pumpMenu(tester, onManageComputers: null);

    expect(find.byKey(const ValueKey("computer-menu-manage")), findsNothing);
  });

  testWidgets("the management footer closes the menu and calls back", (tester) async {
    var managed = 0;
    await pumpMenu(tester, onManageComputers: () => managed++);

    expect(find.text("Manage computers…"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("computer-menu-manage")));
    await tester.pumpAndSettle();

    expect(managed, 1);
    expect(selected, isEmpty);
    expect(find.text("Manage computers…"), findsNothing);
  });
}
