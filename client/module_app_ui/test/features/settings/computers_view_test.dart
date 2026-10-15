import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockComputerSwitcherCubit() extends MockCubit<ComputerSwitcherState> implements ComputerSwitcherCubit;

class _MockComputersCubit() extends MockCubit<ComputersState> implements ComputersCubit;

BridgeSummary _computer({
  required String id,
  required String name,
  required String hostname,
  required BridgeRegistrationStatus status,
}) => BridgeSummary(
  id: id,
  name: name,
  hostname: hostname,
  platform: BridgePlatform.macos,
  status: status,
  addedAt: DateTime.utc(2026),
  lastSeenAt: null,
);

final _studio = _computer(
  id: "a",
  name: "Studio",
  hostname: "studio-mac.local",
  status: BridgeRegistrationStatus.active,
);
final _workLaptop = _computer(
  id: "b",
  name: "work-laptop",
  hostname: "work-laptop",
  status: BridgeRegistrationStatus.active,
);
final _buildBox = _computer(
  id: "c",
  name: "build-box",
  hostname: "build-box",
  status: BridgeRegistrationStatus.inactive,
);

void main() {
  late _MockComputersCubit computersCubit;
  late List<(String, ComputerSwitchSource)> switched;

  setUpAll(() => registerFallbackValue(_studio));

  setUp(() {
    computersCubit = _MockComputersCubit();
    whenListen(computersCubit, const Stream<ComputersState>.empty(), initialState: const ComputersIdle());
    when(
      () => computersCubit.rename(
        computer: any(named: "computer"),
        name: any(named: "name"),
      ),
    ).thenAnswer((_) async {});
    when(() => computersCubit.remove(bridgeId: any(named: "bridgeId"))).thenAnswer((_) async => null);
    switched = [];
  });

  Future<void> pumpView(
    WidgetTester tester, {
    String targetId = "b",
    WidgetBuilder? localBridgeTurnOffActionBuilder,
  }) async {
    final switcherCubit = _MockComputerSwitcherCubit();
    whenListen(
      switcherCubit,
      const Stream<ComputerSwitcherState>.empty(),
      initialState: ComputerSwitcherState(
        computers: [_studio, _workLaptop, _buildBox],
        targetId: targetId,
        localId: "a",
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: "/",
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<ComputerSwitcherCubit>.value(value: switcherCubit),
              BlocProvider<ComputersCubit>.value(value: computersCubit),
            ],
            child: ComputersView(
              chrome: SettingsPageOwnBar(title: "Computers", connectionBanner: null),
              onSwitchComputer: ({required bridgeId, required source}) => switched.add((bridgeId, source)),
              localBridgeTurnOffActionBuilder: localBridgeTurnOffActionBuilder,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openActions(WidgetTester tester, {required String id}) async {
    await tester.tap(find.byKey(ValueKey("computers-actions-$id")));
    await tester.pumpAndSettle();
  }

  Future<void> openRename(WidgetTester tester, {required String id}) async {
    await openActions(tester, id: id);
    await tester.tap(find.byKey(ValueKey("computers-rename-$id")));
    await tester.pumpAndSettle();
  }

  testWidgets("shows the hostname only under a name of its own and marks this computer", (tester) async {
    await pumpView(tester);

    expect(find.text("studio-mac.local"), findsOneWidget);
    expect(find.text("work-laptop"), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey("computers-row-a")), matching: find.text("This computer")),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const ValueKey("computers-row-b")), matching: find.text("This computer")),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byKey(const ValueKey("computers-row-b")), matching: find.byIcon(TablerRegular.check)),
      findsOneWidget,
    );
  });

  testWidgets("offers Switch and Rename, but no Switch on the current computer", (tester) async {
    await pumpView(tester);

    await openActions(tester, id: "a");
    expect(find.byKey(const ValueKey("computers-switch-a")), findsOneWidget);
    expect(find.byKey(const ValueKey("computers-rename-a")), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await openActions(tester, id: "b");
    expect(find.byKey(const ValueKey("computers-switch-b")), findsNothing);
    expect(find.byKey(const ValueKey("computers-rename-b")), findsOneWidget);
  });

  testWidgets("Switch reports the computers page as its source", (tester) async {
    await pumpView(tester);

    await openActions(tester, id: "a");
    await tester.tap(find.byKey(const ValueKey("computers-switch-a")));
    await tester.pumpAndSettle();

    expect(switched, [("a", ComputerSwitchSource.computersPage)]);
  });

  testWidgets("rename prefills the name and saves what was typed", (tester) async {
    await pumpView(tester);
    await openRename(tester, id: "a");

    expect(find.widgetWithText(TextField, "Studio"), findsOneWidget);
    await tester.enterText(find.byType(TextField), "  Desk  ");
    await tester.tap(find.byKey(const Key("computers-rename-save")));
    await tester.pumpAndSettle();

    verify(() => computersCubit.rename(computer: _studio, name: "  Desk  ")).called(1);
  });

  testWidgets("Use hostname saves the hostname", (tester) async {
    await pumpView(tester);
    await openRename(tester, id: "a");

    await tester.tap(find.byKey(const Key("computers-rename-use-hostname")));
    await tester.pumpAndSettle();

    verify(() => computersCubit.rename(computer: _studio, name: "studio-mac.local")).called(1);
  });

  testWidgets("a computer named by its hostname offers no Use hostname", (tester) async {
    await pumpView(tester);
    await openRename(tester, id: "b");

    expect(find.byKey(const Key("computers-rename-use-hostname")), findsNothing);
  });

  Future<void> tapRemove(WidgetTester tester, {required String id}) async {
    await openActions(tester, id: id);
    await tester.tap(find.byKey(ValueKey("computers-remove-$id")));
    await tester.pumpAndSettle();
  }

  testWidgets("an online computer's Remove is disabled and says to quit Sesori there", (tester) async {
    await pumpView(tester);
    await tapRemove(tester, id: "b");

    expect(find.text("Quit Sesori on work-laptop to remove it"), findsOneWidget);
    expect(find.text("Remove work-laptop?"), findsNothing);
    verifyNever(() => computersCubit.remove(bridgeId: any(named: "bridgeId")));
  });

  testWidgets("removing an offline computer asks first, and Cancel keeps it", (tester) async {
    await pumpView(tester);
    await tapRemove(tester, id: "c");

    expect(find.text("Remove build-box?"), findsOneWidget);
    expect(
      find.text("It disappears from every device. Starting Sesori on it signs it back in as a new computer."),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key("computers-remove-cancel")));
    await tester.pumpAndSettle();
    verifyNever(() => computersCubit.remove(bridgeId: any(named: "bridgeId")));

    await tapRemove(tester, id: "c");
    await tester.tap(find.byKey(const Key("computers-remove-confirm")));
    await tester.pumpAndSettle();
    verify(() => computersCubit.remove(bridgeId: "c")).called(1);
    expect(switched, isEmpty);
  });

  testWidgets("removing the computer the app works on switches to the replacement", (tester) async {
    when(() => computersCubit.remove(bridgeId: "c")).thenAnswer((_) async => "a");
    await pumpView(tester, targetId: "c");
    await tapRemove(tester, id: "c");
    await tester.tap(find.byKey(const Key("computers-remove-confirm")));
    await tester.pumpAndSettle();

    expect(switched, [("a", ComputerSwitchSource.computersPage)]);
  });

  testWidgets("Remove on this computer explains instead, with the shell's turn-off action", (tester) async {
    await pumpView(tester, localBridgeTurnOffActionBuilder: (_) => const Text("Turn off bridge"));
    await tapRemove(tester, id: "a");

    expect(find.text("This computer can't be removed"), findsOneWidget);
    expect(find.text("Turn off bridge"), findsOneWidget);
    await tester.tap(find.byKey(const Key("computers-this-computer-close")));
    await tester.pumpAndSettle();
    expect(find.text("This computer can't be removed"), findsNothing);
    verifyNever(() => computersCubit.remove(bridgeId: any(named: "bridgeId")));
  });

  testWidgets("the explanation has no turn-off action without one from the shell", (tester) async {
    await pumpView(tester);
    await tapRemove(tester, id: "a");

    expect(find.text("This computer can't be removed"), findsOneWidget);
    expect(find.text("Turn off bridge"), findsNothing);
  });
}
