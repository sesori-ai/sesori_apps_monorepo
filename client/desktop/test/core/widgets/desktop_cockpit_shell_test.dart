import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late _MockBridgeControlCubit bridgeControlCubit;

  setUp(() {
    bridgeControlCubit = _MockBridgeControlCubit();
  });

  Widget app({required BridgeControlState state, required Widget child}) {
    whenListen(
      bridgeControlCubit,
      const Stream<BridgeControlState>.empty(),
      initialState: state,
    );
    return BlocProvider<BridgeControlCubit>.value(
      value: bridgeControlCubit,
      child: MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        home: child,
      ),
    );
  }

  testWidgets("renders stable sidebar destinations and dispatches selection", (tester) async {
    var bridgeOpens = 0;
    var projectOpens = 0;
    var settingsOpens = 0;
    await tester.pumpWidget(
      app(
        state: _state(processState: const BridgeProcessRunning(pid: 42)),
        child: DesktopCockpitShell(
          destination: DesktopCockpitDestination.projects,
          onOpenBridge: () => bridgeOpens++,
          onOpenProjects: () => projectOpens++,
          onOpenSettings: () => settingsOpens++,
          child: const ColoredBox(
            key: Key("cockpit-content"),
            color: Colors.transparent,
          ),
        ),
      ),
    );

    final rail = tester.widget<NavigationRail>(find.byKey(const Key("desktop-cockpit-sidebar")));
    expect(rail.selectedIndex, DesktopCockpitDestination.projects.index);
    expect(find.byKey(const Key("cockpit-content")), findsOneWidget);

    rail.onDestinationSelected!(DesktopCockpitDestination.bridge.index);
    rail.onDestinationSelected!(DesktopCockpitDestination.projects.index);
    rail.onDestinationSelected!(DesktopCockpitDestination.settings.index);
    expect((bridgeOpens, projectOpens, settingsOpens), (1, 1, 1));
  });

  testWidgets("keeps ordinary running supervision out of the content", (tester) async {
    await tester.pumpWidget(
      app(
        state: _state(processState: const BridgeProcessRunning(pid: 42)),
        child: const DesktopCockpitShell(
          destination: DesktopCockpitDestination.bridge,
          onOpenBridge: _noOp,
          onOpenProjects: _noOp,
          onOpenSettings: _noOp,
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byKey(const Key("desktop-supervision-notice")), findsNothing);
  });

  testWidgets("integrates crash recovery and logs above every destination", (tester) async {
    when(bridgeControlCubit.startBridge).thenAnswer((_) async {});
    when(bridgeControlCubit.openLogs).thenAnswer((_) async {});
    await tester.pumpWidget(
      app(
        state: _state(
          processState: BridgeProcessCrashGiveUp(
            exitCode: 1,
            crashCount: 6,
            recentLogs: const <BridgeProcessLogEntry>[],
          ),
        ),
        child: const DesktopCockpitShell(
          destination: DesktopCockpitDestination.projects,
          onOpenBridge: _noOp,
          onOpenProjects: _noOp,
          onOpenSettings: _noOp,
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text("The local bridge stopped after repeated crashes."), findsOneWidget);
    await tester.tap(find.text("Retry"));
    await tester.tap(find.text("Open Logs"));
    verify(bridgeControlCubit.startBridge).called(1);
    verify(bridgeControlCubit.openLogs).called(1);
  });

  testWidgets("offers takeover from the integrated supervision surface", (tester) async {
    when(bridgeControlCubit.takeOver).thenAnswer((_) async {});
    await tester.pumpWidget(
      app(
        state: _state(processState: const BridgeProcessContention()),
        child: const DesktopCockpitShell(
          destination: DesktopCockpitDestination.projects,
          onOpenBridge: _noOp,
          onOpenProjects: _noOp,
          onOpenSettings: _noOp,
          child: SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.text("Take Over"));
    verify(bridgeControlCubit.takeOver).called(1);
  });

  testWidgets("offers authenticated bridge retry without CLI-install copy", (tester) async {
    when(bridgeControlCubit.startBridge).thenAnswer((_) async {});
    await tester.pumpWidget(
      app(
        state: _state(processState: const BridgeProcessLoginRequired()),
        child: const DesktopCockpitShell(
          destination: DesktopCockpitDestination.projects,
          onOpenBridge: _noOp,
          onOpenProjects: _noOp,
          onOpenSettings: _noOp,
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.textContaining("account is required"), findsOneWidget);
    expect(find.textContaining("install"), findsNothing);
    await tester.tap(find.text("Start Bridge"));
    verify(bridgeControlCubit.startBridge).called(1);
  });
}

BridgeControlState _state({required BridgeProcessState processState}) => BridgeControlState(
  trayAvailability: SystemTrayAvailability.available,
  activity: BridgeControlActivity.idle,
  statusLabel: "Bridge status",
  processState: processState,
  desiredState: BridgeProcessDesiredState.on,
  toggleTarget: BridgeProcessDesiredState.off,
  launchAtLoginEnabled: false,
  controlStatus: processState is BridgeProcessContention
      ? const BridgeControlStatus(
          helperOnline: false,
          bridgeId: null,
          relay: ControlRelayConnectionState.takenOver,
          plugin: ControlPluginHealthState.unknown,
          activeSessionCount: 0,
        )
      : BridgeControlStatus.offline,
);

void _noOp() {}

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
