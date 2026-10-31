import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/gestures.dart" show PointerDeviceKind, kSecondaryButton;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/menus/anchored_flat_panel.dart";
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
    when(
      () => computersCubit.remove(
        bridgeId: any(named: "bridgeId"),
        isCurrent: any(named: "isCurrent"),
      ),
    ).thenAnswer((_) async => null);
    switched = [];
  });

  Future<ComputerSwitcherCubit> pumpView(
    WidgetTester tester, {
    String targetId = "b",
    WidgetBuilder? localBridgeTurnOffActionBuilder,
    required bool pointer,
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
    final app = MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
    await tester.pumpWidget(pointer ? PregoInteractionScope(mode: PregoInteractionMode.pointer, child: app) : app);
    await tester.pumpAndSettle();
    return switcherCubit;
  }

  final Finder menuPanel = find.descendant(of: find.byType(AnchoredFlatPanel), matching: find.byType(Material)).first;

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
    await pumpView(tester, pointer: false);

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
    await pumpView(tester, pointer: false);

    await openActions(tester, id: "a");
    expect(find.byKey(const ValueKey("computers-switch-a")), findsOneWidget);
    expect(find.byKey(const ValueKey("computers-rename-a")), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await openActions(tester, id: "b");
    expect(find.byKey(const ValueKey("computers-switch-b")), findsNothing);
    expect(find.byKey(const ValueKey("computers-rename-b")), findsOneWidget);
  });

  testWidgets("a row's ⋯ drops the menu just below itself, right edges aligned, down to the last row", (
    tester,
  ) async {
    await pumpView(tester, pointer: false);

    for (final id in ["b", "c"]) {
      await openActions(tester, id: id);
      final actions = tester.getRect(find.byKey(ValueKey("computers-actions-$id")));
      expect(tester.getRect(menuPanel).topRight, actions.bottomRight + const Offset(0, 8));
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    }
  });

  testWidgets("a secondary click on a row drops the menu from the pointer", (tester) async {
    await pumpView(tester, pointer: true);

    final click = tester.getCenter(find.text("Studio"));
    await tester.tapAt(click, buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(menuPanel), click);
    expect(find.byKey(const ValueKey("computers-rename-a")), findsOneWidget);
  });

  testWidgets("Switch reports the computers page as its source", (tester) async {
    await pumpView(tester, pointer: false);

    await openActions(tester, id: "a");
    await tester.tap(find.byKey(const ValueKey("computers-switch-a")));
    await tester.pumpAndSettle();

    expect(switched, [("a", ComputerSwitchSource.computersPage)]);
  });

  testWidgets("rename prefills the name and saves what was typed", (tester) async {
    await pumpView(tester, pointer: false);
    await openRename(tester, id: "a");

    expect(find.widgetWithText(TextField, "Studio"), findsOneWidget);
    await tester.enterText(find.byType(TextField), "  Desk  ");
    await tester.tap(find.byKey(const Key("computers-rename-save")));
    await tester.pumpAndSettle();

    verify(() => computersCubit.rename(computer: _studio, name: "  Desk  ")).called(1);
  });

  testWidgets("Use hostname saves the hostname", (tester) async {
    await pumpView(tester, pointer: false);
    await openRename(tester, id: "a");

    await tester.tap(find.byKey(const Key("computers-rename-use-hostname")));
    await tester.pumpAndSettle();

    verify(() => computersCubit.rename(computer: _studio, name: "studio-mac.local")).called(1);
  });

  testWidgets("a screen reader hears each row's actions as a named button, disabled while busy", (tester) async {
    final semantics = tester.ensureSemantics();
    final actions = StreamController<ComputersState>();
    addTearDown(actions.close);
    whenListen(computersCubit, actions.stream, initialState: const ComputersIdle());
    await pumpView(tester, pointer: false);
    actions.add(const ComputersRemoving(bridgeId: "c"));
    await tester.pump();
    await tester.pump();

    expect(
      find.semantics.byLabel("Actions for Studio").evaluate().single,
      isSemantics(label: "Actions for Studio", tooltip: "", isButton: true, isEnabled: true, hasTapAction: true),
    );
    expect(
      find.semantics.byLabel("Actions for build-box").evaluate().single,
      isSemantics(
        label: "Actions for build-box",
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    semantics.dispose();
  });

  testWidgets("while an action runs, other computers can switch but not rename", (tester) async {
    final actions = StreamController<ComputersState>();
    addTearDown(actions.close);
    whenListen(computersCubit, actions.stream, initialState: const ComputersIdle());
    await pumpView(tester, pointer: false);
    // The busy row's spinner never settles, so frames are pumped by hand: one
    // delivers the action, the next rebuilds the rows with it.
    actions.add(const ComputersRemoving(bridgeId: "c"));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("computers-actions-a")));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey("computers-rename-a")));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key("computers-rename-field")), findsNothing);
    expect(find.byKey(const ValueKey("computers-switch-a")), findsOneWidget);
  });

  testWidgets("a computer named by its hostname offers no Use hostname", (tester) async {
    await pumpView(tester, pointer: false);
    await openRename(tester, id: "b");

    expect(find.byKey(const Key("computers-rename-use-hostname")), findsNothing);
  });

  Future<void> tapRemove(WidgetTester tester, {required String id}) async {
    await openActions(tester, id: id);
    await tester.tap(find.byKey(ValueKey("computers-remove-$id")));
    await tester.pumpAndSettle();
  }

  testWidgets("an online computer's Remove is disabled and says to quit Sesori there", (tester) async {
    await pumpView(tester, pointer: false);
    await tapRemove(tester, id: "b");

    expect(find.text("Quit Sesori on work-laptop to remove it"), findsOneWidget);
    expect(find.text("Remove work-laptop?"), findsNothing);
    verifyNever(
      () => computersCubit.remove(
        bridgeId: any(named: "bridgeId"),
        isCurrent: any(named: "isCurrent"),
      ),
    );
  });

  testWidgets("removing an offline computer asks first, and Cancel keeps it", (tester) async {
    await pumpView(tester, pointer: false);
    await tapRemove(tester, id: "c");

    expect(find.text("Remove build-box?"), findsOneWidget);
    expect(
      find.text("It disappears from every device. Starting Sesori on it signs it back in as a new computer."),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key("computers-remove-cancel")));
    await tester.pumpAndSettle();
    verifyNever(
      () => computersCubit.remove(
        bridgeId: any(named: "bridgeId"),
        isCurrent: any(named: "isCurrent"),
      ),
    );

    await tapRemove(tester, id: "c");
    await tester.tap(find.byKey(const Key("computers-remove-confirm")));
    await tester.pumpAndSettle();
    verify(() => computersCubit.remove(bridgeId: "c", isCurrent: false)).called(1);
    expect(switched, isEmpty);
  });

  testWidgets("removing the computer the app works on switches to the replacement", (tester) async {
    when(() => computersCubit.remove(bridgeId: "c", isCurrent: true)).thenAnswer((_) async => "a");
    await pumpView(tester, targetId: "c", pointer: false);
    await tapRemove(tester, id: "c");
    await tester.tap(find.byKey(const Key("computers-remove-confirm")));
    await tester.pumpAndSettle();

    expect(switched, [("a", ComputerSwitchSource.computersPage)]);
  });

  testWidgets("a computer that came online while the user confirmed is kept", (tester) async {
    final switcherCubit = await pumpView(tester, pointer: false);
    await tapRemove(tester, id: "c");
    when(() => switcherCubit.state).thenReturn(
      ComputerSwitcherState(
        computers: [
          _studio,
          _workLaptop,
          _buildBox.copyWith(status: BridgeRegistrationStatus.active),
        ],
        targetId: "b",
        localId: "a",
      ),
    );
    await tester.tap(find.byKey(const Key("computers-remove-confirm")));
    await tester.pumpAndSettle();

    verifyNever(
      () => computersCubit.remove(
        bridgeId: any(named: "bridgeId"),
        isCurrent: any(named: "isCurrent"),
      ),
    );
  });

  testWidgets("Remove on this computer explains instead, with the shell's turn-off action", (tester) async {
    await pumpView(tester, localBridgeTurnOffActionBuilder: (_) => const Text("Turn off bridge"), pointer: false);
    await tapRemove(tester, id: "a");

    expect(find.text("This computer can't be removed"), findsOneWidget);
    expect(find.text("Turn off bridge"), findsOneWidget);
    await tester.tap(find.byKey(const Key("computers-this-computer-close")));
    await tester.pumpAndSettle();
    expect(find.text("This computer can't be removed"), findsNothing);
    verifyNever(
      () => computersCubit.remove(
        bridgeId: any(named: "bridgeId"),
        isCurrent: any(named: "isCurrent"),
      ),
    );
  });

  testWidgets("the explanation has no turn-off action without one from the shell", (tester) async {
    await pumpView(tester, pointer: false);
    await tapRemove(tester, id: "a");

    expect(find.text("This computer can't be removed"), findsOneWidget);
    expect(find.text("Turn off bridge"), findsNothing);
  });
}
