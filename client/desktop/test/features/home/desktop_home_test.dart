import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/features/home/desktop_home.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

const AuthUser _user = AuthUser(
  id: "user-1",
  provider: AuthProvider.github,
  providerUserId: "gh-1",
  providerUsername: "alex",
);

void main() {
  late _MockBridgeControlCubit bridgeControlCubit;
  late _MockAuthGateCubit authGateCubit;

  setUp(() {
    bridgeControlCubit = _MockBridgeControlCubit();
    authGateCubit = _MockAuthGateCubit();
    when(() => bridgeControlCubit.toggleBridge()).thenAnswer((_) async {});
    when(() => bridgeControlCubit.toggleLaunchAtLogin()).thenAnswer((_) async {});
    when(() => bridgeControlCubit.openLogs()).thenAnswer((_) async {});
    when(() => authGateCubit.signOut()).thenAnswer((_) async {});
  });

  Future<void> pumpHome({required WidgetTester tester, required BridgeControlState state}) {
    whenListen(bridgeControlCubit, const Stream<BridgeControlState>.empty(), initialState: state);
    whenListen(
      authGateCubit,
      const Stream<AuthGateState>.empty(),
      initialState: const AuthGateState.signedIn(user: _user),
    );
    return tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BridgeControlCubit>.value(value: bridgeControlCubit),
            BlocProvider<AuthGateCubit>.value(value: authGateCubit),
          ],
          child: const DesktopHome(user: _user),
        ),
      ),
    );
  }

  testWidgets("renders live supervision details and delegates user actions", (WidgetTester tester) async {
    await pumpHome(
      tester: tester,
      state: _state(
        processState: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
        status: const BridgeControlStatus(
          helperOnline: true,
          relay: ControlRelayConnectionState.connected,
          plugin: ControlPluginHealthState.healthy,
          activeSessionCount: 2,
          bridgeId: "bridge-1",
        ),
        statusLabel: "Bridge: Connected",
      ),
    );

    expect(find.text("Signed in as alex (GitHub)"), findsOneWidget);
    expect(find.text("Bridge: Connected"), findsOneWidget);
    expect(find.text("Registered"), findsOneWidget);
    expect(find.text("Connected"), findsOneWidget);
    expect(find.text("Healthy"), findsOneWidget);
    expect(find.text("2"), findsOneWidget);
    expect(find.text("Turn Bridge Off"), findsOneWidget);
    expect(find.text("Launch at login"), findsOneWidget);
    expect(find.text("Enable Launch at Login"), findsOneWidget);

    await tester.tap(find.text("Turn Bridge Off"));
    await tester.tap(find.text("Enable Launch at Login"));
    await tester.tap(find.text("Open Logs"));
    await tester.tap(find.text("Sign out"));

    verify(() => bridgeControlCubit.toggleBridge()).called(1);
    verify(() => bridgeControlCubit.toggleLaunchAtLogin()).called(1);
    verify(() => bridgeControlCubit.openLogs()).called(1);
    verify(() => authGateCubit.signOut()).called(1);
  });

  testWidgets("shows recent helper output after the crash budget is exhausted", (WidgetTester tester) async {
    await pumpHome(
      tester: tester,
      state: _state(
        processState: BridgeProcessCrashGiveUp(
          exitCode: 1,
          crashCount: 6,
          recentLogs: <BridgeProcessLogEntry>[
            BridgeProcessLogEntry(
              timestamp: DateTime.utc(2026, 8, 28),
              source: BridgeProcessLogSource.stderr,
              message: "relay bootstrap failed",
            ),
          ],
        ),
        desiredState: BridgeProcessDesiredState.on,
        status: BridgeControlStatus.offline,
        statusLabel: "Bridge: Stopped after repeated crashes",
      ),
    );

    expect(find.text("Recent bridge output"), findsOneWidget);
    expect(find.textContaining("relay bootstrap failed"), findsOneWidget);
  });
}

BridgeControlState _state({
  required BridgeProcessState processState,
  required BridgeProcessDesiredState desiredState,
  required BridgeControlStatus status,
  required String statusLabel,
}) => BridgeControlState(
  trayAvailability: SystemTrayAvailability.available,
  menu: SystemTrayMenu(entries: const <SystemTrayMenuEntry>[]),
  activity: BridgeControlActivity.idle,
  statusLabel: statusLabel,
  processState: processState,
  desiredState: desiredState,
  toggleTarget: desiredState == BridgeProcessDesiredState.on
      ? BridgeProcessDesiredState.off
      : BridgeProcessDesiredState.on,
  launchAtLoginEnabled: false,
  controlStatus: status,
);

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;

class _MockAuthGateCubit() extends MockCubit<AuthGateState> implements AuthGateCubit;
