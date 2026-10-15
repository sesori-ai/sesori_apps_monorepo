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

BridgeSummary _computer({required String id, required String name, required String hostname}) => BridgeSummary(
  id: id,
  name: name,
  hostname: hostname,
  platform: BridgePlatform.macos,
  status: BridgeRegistrationStatus.active,
  addedAt: DateTime.utc(2026),
  lastSeenAt: null,
);

final _studio = _computer(id: "a", name: "Studio", hostname: "studio-mac.local");
final _workLaptop = _computer(id: "b", name: "work-laptop", hostname: "work-laptop");

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
    switched = [];
  });

  Future<void> pumpView(WidgetTester tester) async {
    final switcherCubit = _MockComputerSwitcherCubit();
    whenListen(
      switcherCubit,
      const Stream<ComputerSwitcherState>.empty(),
      initialState: ComputerSwitcherState(
        computers: [_studio, _workLaptop],
        targetId: "b",
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
}
