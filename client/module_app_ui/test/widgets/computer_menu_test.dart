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

  Future<void> pumpMenu(
    WidgetTester tester, {
    required VoidCallback? onManageComputers,
    String targetId = "a",
    bool currentFirst = false,
  }) async {
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
        targetId: targetId,
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
              currentFirst: currentFirst,
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

  testWidgets("leads each presence with a dot on its line: green online, red offline", (tester) async {
    await pumpMenu(tester, onManageComputers: null);

    final colors = PregoDesignSystem.light.colors;
    final rows = {
      "a": ("Online", colors.fgSuccessSecondary),
      "b": ("Offline · last seen 5h ago", colors.fgErrorPrimary),
      "c": ("Offline", colors.fgErrorPrimary),
    };
    for (final MapEntry(key: id, value: (presence, color)) in rows.entries) {
      final row = find.byKey(ValueKey("computer-menu-$id"));
      final dot = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (widget) => switch (widget) {
            Container(decoration: BoxDecoration(shape: BoxShape.circle)) => true,
            _ => false,
          },
        ),
      );
      final text = find.descendant(of: row, matching: find.text(presence));

      expect(dot, findsOneWidget, reason: id);
      expect(tester.widget<Container>(dot).decoration, isA<BoxDecoration>().having((d) => d.color, "color", color));
      expect(tester.getCenter(dot).dx, lessThan(tester.getTopLeft(text).dx), reason: id);
      expect(tester.getCenter(dot).dy, moreOrLessEquals(tester.getCenter(text).dy, epsilon: 0.5), reason: id);
    }
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

  /// The menu's computer names, top to bottom.
  List<String> menuOrder(WidgetTester tester) =>
      ["studio-mac", "work-laptop", "old-tower"]
        ..sort((a, b) => tester.getTopLeft(find.text(a)).dy.compareTo(tester.getTopLeft(find.text(b)).dy));

  testWidgets("keeps the account's order by default", (tester) async {
    await pumpMenu(tester, onManageComputers: null, targetId: "b");

    expect(menuOrder(tester), ["studio-mac", "work-laptop", "old-tower"]);
  });

  testWidgets("leads with the current computer for a trigger that does not name it", (tester) async {
    await pumpMenu(tester, onManageComputers: null, targetId: "b", currentFirst: true);

    expect(menuOrder(tester), ["work-laptop", "studio-mac", "old-tower"]);
    expect(
      find.descendant(of: find.byKey(const ValueKey("computer-menu-b")), matching: find.byIcon(TablerRegular.check)),
      findsOneWidget,
    );
  });
}
