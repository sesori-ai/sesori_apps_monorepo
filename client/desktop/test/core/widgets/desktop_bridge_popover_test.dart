import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/widgets/desktop_bridge_popover.dart";
import "package:sesori_desktop/core/widgets/desktop_escape_dismissal.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late _BridgeCubit bridge;
  late _OverlayCubit overlay;
  late StreamController<BridgeControlState> updates;
  late int settingsOpens;
  final popover = find.byKey(const Key("desktop-bridge-popover"));

  setUp(() {
    bridge = _BridgeCubit();
    overlay = _OverlayCubit();
    updates = StreamController<BridgeControlState>();
    settingsOpens = 0;
    when(() => bridge.refreshLaunchAtLogin()).thenAnswer((_) async {});
    when(() => bridge.toggleBridge()).thenAnswer((_) async {});
    when(() => bridge.toggleLaunchAtLogin()).thenAnswer((_) async {});
    when(() => bridge.takeOver()).thenAnswer((_) async {});
    when(() => bridge.openLogs()).thenAnswer((_) async {});
    when(() => bridge.quit()).thenAnswer((_) async {});
    whenListen(
      overlay,
      const Stream<ConnectionOverlayState>.empty(),
      initialState: const ConnectionOverlayState.hidden(connected: true),
    );
  });
  tearDown(() => updates.close());

  Future<void> pumpPopover({required WidgetTester tester, required BridgeControlState state}) async {
    whenListen(bridge, updates.stream, initialState: state);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<BridgeControlCubit>.value(value: bridge),
          BlocProvider<ConnectionOverlayCubit>.value(value: overlay),
        ],
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

  testWidgets("refreshes on open, shows status and delegates switches and logs", (tester) async {
    await pumpPopover(tester: tester, state: _state());
    expect(find.text("Bridge: Off"), findsOneWidget);
    expect(find.text("Client connected"), findsOneWidget);
    expect(find.text("Take Over"), findsNothing);
    final switches = tester.widgetList<PregoSwitch>(find.byType(PregoSwitch)).toList();
    expect(switches.map((widget) => widget.value), [false, false]);
    await tester.tap(find.byType(PregoSwitch).first);
    await tester.tap(find.byType(PregoSwitch).last);
    await tester.tap(find.text("Open Logs"));
    verify(() => bridge.refreshLaunchAtLogin()).called(1);
    verify(() => bridge.toggleBridge()).called(1);
    verify(() => bridge.toggleLaunchAtLogin()).called(1);
    verify(() => bridge.openLogs()).called(1);
    expect(popover, findsOneWidget);
  });

  testWidgets("live state locks mutations, keeps diagnostics, and does not reread", (tester) async {
    await pumpPopover(tester: tester, state: _state());
    updates.add(_state(process: const BridgeProcessContention(), activity: BridgeControlActivity.toggling));
    await tester.pumpAndSettle();
    expect(tester.widget<PregoSwitch>(find.byType(PregoSwitch).first).onChanged, isNull);
    expect(tester.widget<PregoSwitch>(find.byType(PregoSwitch).last).onChanged, isNull);
    for (final label in ["Take Over", "Quit Sesori"]) {
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, label)).onPressed, isNull);
    }
    await tester.tap(find.text("Open Logs"));
    verify(() => bridge.openLogs()).called(1);
    verify(() => bridge.refreshLaunchAtLogin()).called(1);
    updates.add(_state(process: const BridgeProcessContention()));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Take Over"));
    verify(() => bridge.takeOver()).called(1);
  });

  testWidgets("bridge switch follows the command target instead of stale intent", (tester) async {
    await pumpPopover(
      tester: tester,
      state: _state(process: const BridgeProcessLoginRequired()),
    );
    expect(tester.widget<PregoSwitch>(find.byType(PregoSwitch).first).value, isFalse);
    updates.add(_state(target: BridgeProcessDesiredState.off, launchAtLogin: true));
    await tester.pumpAndSettle();
    expect(tester.widgetList<PregoSwitch>(find.byType(PregoSwitch)).every((widget) => widget.value), isTrue);
  });

  testWidgets("settings and Quit dismiss before delegating", (tester) async {
    await pumpPopover(tester: tester, state: _state());
    await tester.tap(find.text("Bridge settings…"));
    await tester.pumpAndSettle();
    expect(popover, findsNothing);
    expect(settingsOpens, 1);
    await tester.tap(find.text("Bridge control"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Quit Sesori"));
    await tester.pumpAndSettle();
    expect(popover, findsNothing);
    verify(() => bridge.quit()).called(1);
    verify(() => bridge.refreshLaunchAtLogin()).called(2);
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
    verifyNever(() => bridge.toggleBridge());
    verifyNever(() => bridge.quit());
  });

  testWidgets("minimum window keeps the bounded flat panel and actions on screen", (tester) async {
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
    await tester.ensureVisible(find.text("Quit Sesori"));
    expect(find.text("Quit Sesori").hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

BridgeControlState _state({
  BridgeProcessState process = const BridgeProcessStopped(),
  BridgeControlActivity activity = BridgeControlActivity.idle,
  BridgeProcessDesiredState target = BridgeProcessDesiredState.on,
  bool launchAtLogin = false,
}) => BridgeControlState(
  trayAvailability: SystemTrayAvailability.available,
  activity: activity,
  statusLabel: "Bridge: Off",
  processState: process,
  desiredState: BridgeProcessDesiredState.on,
  toggleTarget: target,
  launchAtLoginEnabled: launchAtLogin,
  controlStatus: BridgeControlStatus.offline,
);

class _BridgeCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
class _OverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit;
