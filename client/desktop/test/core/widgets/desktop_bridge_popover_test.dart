import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_desktop/core/widgets/desktop_bridge_popover.dart";
import "package:sesori_desktop/core/widgets/desktop_escape_dismissal.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late _BridgeCubit bridge;
  late StreamController<BridgeControlState> updates;
  late int settingsOpens;
  final popover = find.byKey(const Key("desktop-bridge-popover"));

  setUp(() {
    bridge = _BridgeCubit();
    updates = StreamController<BridgeControlState>();
    settingsOpens = 0;
    when(() => bridge.startBridge()).thenAnswer((_) async {});
    when(() => bridge.stopBridge()).thenAnswer((_) async {});
    when(() => bridge.recoverConnection()).thenAnswer((_) async {});
    when(() => bridge.takeOver()).thenAnswer((_) async {});
    when(() => bridge.openLogs()).thenAnswer((_) async {});
  });
  tearDown(() => updates.close());

  Future<void> pumpPopover({required WidgetTester tester, required BridgeControlState state}) async {
    whenListen(bridge, updates.stream, initialState: state);
    await tester.pumpWidget(
      BlocProvider<BridgeControlCubit>.value(
        value: bridge,
        child: DesktopEscapeDismissal(
          child: MaterialApp(
            theme: buildPregoThemeData(brightness: Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomLeft,
                child: PregoPopover(
                  popoverWidth: 300,
                  popoverMaxHeight: null,
                  contentScrolls: false,
                  onClosed: null,
                  triggerBuilder: (_, toggle) => TextButton(onPressed: toggle, child: const Text("Bridge control")),
                  contentBuilder: (_, close) =>
                      DesktopBridgePopover(close: close, onOpenSettings: () => settingsOpens++),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Bridge control"));
    await tester.pumpAndSettle();
  }

  testWidgets("local quick controls offer Start and diagnostics, not app preferences", (tester) async {
    await pumpPopover(tester: tester, state: _state());
    expect(find.text("Local bridge"), findsOneWidget);
    expect(find.text("Off"), findsOneWidget);
    expect(find.text("Take Over"), findsNothing);
    expect(find.text("Quit Sesori"), findsNothing);
    expect(find.byType(PregoSwitch), findsNothing);
    await tester.tap(find.text("Start Bridge"));
    await tester.tap(find.text("Open Logs"));
    verify(() => bridge.startBridge()).called(1);
    verify(() => bridge.openLogs()).called(1);
    verifyNever(() => bridge.quit());
    verifyNever(() => bridge.toggleLaunchAtLogin());
    expect(popover, findsOneWidget);
  });

  testWidgets("live contention replaces Start with Take Over and respects command locks", (tester) async {
    await pumpPopover(tester: tester, state: _state());
    updates.add(_state(process: const BridgeProcessContention(), activity: BridgeControlActivity.toggling));
    await tester.pumpAndSettle();
    expect(find.text("Start Bridge"), findsNothing);
    expect(tester.widget<PregoButtonsSolid>(find.byType(PregoButtonsSolid)).onPressed, isNull);
    await tester.tap(find.text("Open Logs"));
    verify(() => bridge.openLogs()).called(1);
    updates.add(_state(process: const BridgeProcessContention()));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Take Over"));
    verify(() => bridge.takeOver()).called(1);
  });

  testWidgets("a stopped crash offers recovery rather than Stop for retained On intent", (tester) async {
    await pumpPopover(
      tester: tester,
      state: _state(
        process: const BridgeProcessCrashGiveUp(exitCode: 1, crashCount: 6),
        target: BridgeProcessDesiredState.off,
      ),
    );
    expect(find.text("Stop Bridge"), findsNothing);
    await tester.tap(find.text("Retry"));
    verify(() => bridge.recoverConnection()).called(1);
  });

  testWidgets("a running helper can be stopped without reclaiming a displaced relay", (tester) async {
    await pumpPopover(
      tester: tester,
      state: _state(
        process: const BridgeProcessRunning(pid: 42),
        target: BridgeProcessDesiredState.off,
      ),
    );
    await tester.tap(find.text("Stop Bridge"));
    updates.add(
      _state(
        process: const BridgeProcessRunning(pid: 42),
        target: BridgeProcessDesiredState.off,
        status: const BridgeControlStatus(
          helperOnline: true,
          startup: ControlStartupState.ready,
          relay: ControlRelayConnectionState.takenOver,
          plugin: ControlPluginHealthState.healthy,
          activeSessionCount: 0,
          bridgeId: "demo",
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Take Over"), findsOneWidget);
    await tester.tap(find.text("Stop Bridge"));
    verify(() => bridge.stopBridge()).called(2);
    verifyNever(() => bridge.takeOver());
  });

  testWidgets("settings dismisses before opening configuration", (tester) async {
    await pumpPopover(tester: tester, state: _state());
    await tester.tap(find.text("Bridge settings…"));
    await tester.pumpAndSettle();
    expect(popover, findsNothing);
    expect(settingsOpens, 1);
  });

  testWidgets("outside tap and Escape dismiss without an action", (tester) async {
    await pumpPopover(tester: tester, state: _state());
    await tester.tapAt(const Offset(700, 10));
    await tester.pumpAndSettle();
    expect(popover, findsNothing);
    await tester.tap(find.text("Bridge control"));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(popover, findsNothing);
    verifyNever(() => bridge.startBridge());
    verifyNever(() => bridge.stopBridge());
    verifyNever(() => bridge.takeOver());
  });

  testWidgets("minimum window keeps the panel and configuration action on screen", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(560, 480);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPopover(
      tester: tester,
      state: _state(process: const BridgeProcessContention()),
    );
    final rect = tester.getRect(popover);
    expect(rect.left, greaterThanOrEqualTo(12));
    expect(rect.top, greaterThanOrEqualTo(12));
    expect(rect.right, lessThanOrEqualTo(548));
    expect(rect.bottom, lessThanOrEqualTo(468));
    expect(find.text("Bridge settings…").hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

BridgeControlState _state({
  BridgeProcessState process = const BridgeProcessStopped(),
  BridgeControlActivity activity = BridgeControlActivity.idle,
  BridgeProcessDesiredState target = BridgeProcessDesiredState.on,
  BridgeControlStatus status = BridgeControlStatus.offline,
}) => BridgeControlState(
  trayAvailability: SystemTrayAvailability.available,
  activity: activity,
  statusLabel: "Off",
  processState: process,
  desiredState: BridgeProcessDesiredState.on,
  toggleTarget: target,
  launchAtLoginEnabled: false,
  controlStatus: status,
);

class _BridgeCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
