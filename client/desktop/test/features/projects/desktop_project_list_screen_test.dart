import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/features/projects/desktop_project_list_screen.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late _MockBridgeControlCubit bridgeControlCubit;
  late _MockProjectListCubit projectListCubit;

  setUp(() {
    bridgeControlCubit = _MockBridgeControlCubit();
    projectListCubit = _MockProjectListCubit();
    when(bridgeControlCubit.startBridge).thenAnswer((_) async {});
    when(projectListCubit.reconnectBridge).thenAnswer((_) async {});
    whenListen(
      bridgeControlCubit,
      const Stream<BridgeControlState>.empty(),
      initialState: _bridgeControlState,
    );
  });

  Future<void> pumpRecovery({required WidgetTester tester, required BridgeSummary? bridge}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<BridgeControlCubit>.value(
          value: bridgeControlCubit,
          child: Scaffold(
            body: DesktopBridgeRecoveryView(
              bridge: bridge,
              onStartBridge: bridgeControlCubit.startBridge,
            ),
          ),
        ),
      ),
    );
  }

  test("recovery starts the helper and establishes the relay connection", () async {
    await recoverDesktopProjectConnection(
      bridgeControlCubit: bridgeControlCubit,
      projectListCubit: projectListCubit,
    );

    verify(bridgeControlCubit.startBridge).called(1);
    verify(projectListCubit.reconnectBridge).called(1);
  });

  testWidgets("never-registered recovery offers supervised Start without CLI guidance", (tester) async {
    await pumpRecovery(tester: tester, bridge: null);

    expect(find.text("Start the bridge"), findsOneWidget);
    expect(find.text("Start the local bridge to load your projects and sessions in Sesori."), findsOneWidget);
    expect(find.text("Install commands"), findsNothing);
    expect(find.text("Make sure the Bridge is running"), findsNothing);

    await tester.tap(find.text("Start the bridge"));
    verify(bridgeControlCubit.startBridge).called(1);
  });

  testWidgets("registered-but-disconnected recovery uses the same supervised action", (tester) async {
    await pumpRecovery(
      tester: tester,
      bridge: BridgeSummary(
        id: "bridge-1",
        name: "workstation.local",
        platform: "macos",
        addedAt: DateTime.utc(2026, 1, 1),
        lastSeenAt: DateTime.utc(2026, 9, 1),
      ),
    );

    expect(find.text("workstation.local"), findsOneWidget);
    expect(find.text("Start the bridge"), findsOneWidget);
    expect(find.text("Install commands"), findsNothing);

    await tester.tap(find.text("Start the bridge"));
    verify(bridgeControlCubit.startBridge).called(1);
  });
}

const BridgeControlState _bridgeControlState = BridgeControlState(
  trayAvailability: SystemTrayAvailability.available,
  activity: BridgeControlActivity.idle,
  statusLabel: "Bridge: Off",
  processState: BridgeProcessStopped(),
  desiredState: BridgeProcessDesiredState.off,
  toggleTarget: BridgeProcessDesiredState.on,
  launchAtLoginEnabled: false,
  controlStatus: BridgeControlStatus.offline,
);

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;
