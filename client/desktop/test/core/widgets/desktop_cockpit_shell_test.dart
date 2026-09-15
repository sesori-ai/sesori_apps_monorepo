import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late _MockBridgeControlCubit bridgeControlCubit;
  late _MockProjectListCubit projects;
  late _MockRepository repository;
  late DesktopSidebarCubit sidebar;

  setUpAll(() => registerFallbackValue(const DesktopSidebarLayout()));
  setUp(() {
    bridgeControlCubit = _MockBridgeControlCubit();
    projects = _MockProjectListCubit();
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(
        projects: [ProjectSummary(id: "project-1", name: "Sesori Desktop", path: "/work/sesori", time: null)],
        activityById: {},
      ),
    );
    repository = _MockRepository();
    when(repository.readSidebarLayout).thenAnswer((_) async => const DesktopSidebarLayout());
    when(() => repository.writeSidebarLayout(layout: any(named: "layout"))).thenAnswer((_) async {});
  });

  Widget app({required BridgeControlState state, Widget? child}) {
    whenListen(bridgeControlCubit, const Stream<BridgeControlState>.empty(), initialState: state);
    return MultiBlocProvider(
      providers: [
        BlocProvider<BridgeControlCubit>.value(value: bridgeControlCubit),
        BlocProvider<ProjectListCubit>.value(value: projects),
        BlocProvider<DesktopSidebarCubit>(create: (_) => sidebar = DesktopSidebarCubit(repository: repository)),
      ],
      child: MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home:
            child ??
            const DesktopCockpitShell(
              selectedProjectId: "project-1",
              onOpenProject: _openProject,
              onOpenBridge: _noOp,
              onOpenProjects: _noOp,
              onOpenSettings: _noOp,
              child: ColoredBox(key: Key("cockpit-content"), color: Colors.transparent),
            ),
      ),
    );
  }

  final running = _state(processState: const BridgeProcessRunning(pid: 42));
  final rail = find.byKey(const Key("desktop-cockpit-sidebar"));
  final resize = find.byKey(const Key("desktop-sidebar-resize"));
  final toggle = find.byKey(const Key("desktop-sidebar-toggle"));

  testWidgets("renders shared projects and dispatches existing route actions", (tester) async {
    var bridgeOpens = 0;
    var projectOpens = 0;
    var settingsOpens = 0;
    String? openedProject;
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          selectedProjectId: "project-1",
          onOpenProject: ({required context, required project, required displayName}) => openedProject = project.id,
          onOpenBridge: () => bridgeOpens++,
          onOpenProjects: () => projectOpens++,
          onOpenSettings: () => settingsOpens++,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getSize(rail).width, 260);
    await tester.tap(find.text("Bridge"));
    await tester.tap(find.text("Sesori"));
    await tester.tap(find.text("Settings"));
    await tester.tap(find.text("Sesori Desktop"));
    expect((bridgeOpens, projectOpens, settingsOpens, openedProject), (1, 1, 1, "project-1"));
  });

  testWidgets("drag resizes immediately, persists on end, and double-click resets", (tester) async {
    await tester.pumpWidget(app(state: running));
    final gesture = await tester.startGesture(tester.getCenter(resize));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(tester.getSize(rail).width, greaterThan(260));
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    await gesture.up();
    await tester.pump();
    verify(() => repository.writeSidebarLayout(layout: any(named: "layout"))).called(1);
    await tester.tap(resize);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(resize);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(rail).width, 260);
  });

  testWidgets("collapse shows initials in a 56px rail and restores user width", (tester) async {
    await tester.pumpWidget(app(state: running));
    sidebar.resize(width: 310);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.getSize(rail).width, 56);
    expect(find.text("Sesori Desktop"), findsNothing);
    expect(find.text("SD"), findsOneWidget);
    expect(find.byTooltip("Sesori Desktop"), findsOneWidget);
    expect(resize, findsNothing);
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.getSize(rail).width, 310);
    expect(tester.takeException(), isNull);
  });

  testWidgets("narrow-window collapse is temporary and never persisted", (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(759, 600);
    await tester.pumpWidget(app(state: running));
    expect(tester.getSize(rail).width, 56);
    expect(sidebar.state.collapsed, isFalse);
    tester.view.physicalSize = const Size(760, 600);
    await tester.pump();
    expect(tester.getSize(rail).width, 260);
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    unawaited(sidebar.toggleCollapsed());
    tester.view.physicalSize = const Size(1200, 700);
    await tester.pump();
    expect(tester.getSize(rail).width, 56);
  });

  testWidgets("keeps ordinary running supervision out of the content", (tester) async {
    await tester.pumpWidget(app(state: running));
    expect(find.byKey(const Key("desktop-supervision-notice")), findsNothing);
  });

  testWidgets("integrates crash recovery and logs above every destination", (tester) async {
    when(bridgeControlCubit.openLogs).thenAnswer((_) async {});
    when(bridgeControlCubit.recoverConnection).thenAnswer((_) async {});
    await tester.pumpWidget(
      app(
        state: _state(
          processState: BridgeProcessCrashGiveUp(
            exitCode: 1,
            crashCount: 6,
            recentLogs: const <BridgeProcessLogEntry>[],
          ),
        ),
      ),
    );
    expect(find.text("The local bridge stopped after repeated crashes."), findsOneWidget);
    await tester.tap(find.text("Retry"));
    await tester.tap(find.text("Open Logs"));
    verify(bridgeControlCubit.recoverConnection).called(1);
    verify(bridgeControlCubit.openLogs).called(1);
  });

  testWidgets("offers takeover from the integrated supervision surface", (tester) async {
    when(bridgeControlCubit.takeOver).thenAnswer((_) async {});
    await tester.pumpWidget(app(state: _state(processState: const BridgeProcessContention())));
    await tester.tap(find.text("Take Over"));
    verify(bridgeControlCubit.takeOver).called(1);
  });

  testWidgets("prioritizes takeover when a displaced relay meets a login-required process state", (tester) async {
    when(bridgeControlCubit.takeOver).thenAnswer((_) async {});
    await tester.pumpWidget(
      app(
        state: _state(
          processState: const BridgeProcessLoginRequired(),
          relay: ControlRelayConnectionState.takenOver,
        ),
      ),
    );
    expect(find.text("Take Over"), findsOneWidget);
    expect(find.text("Start Bridge"), findsNothing);
    await tester.tap(find.text("Take Over"));
    verify(bridgeControlCubit.takeOver).called(1);
  });

  testWidgets("offers authenticated bridge retry without CLI-install copy", (tester) async {
    when(bridgeControlCubit.recoverConnection).thenAnswer((_) async {});
    await tester.pumpWidget(app(state: _state(processState: const BridgeProcessLoginRequired())));
    expect(find.textContaining("account is required"), findsOneWidget);
    expect(find.textContaining("install"), findsNothing);
    await tester.tap(find.text("Start Bridge"));
    verify(bridgeControlCubit.recoverConnection).called(1);
  });
}

BridgeControlState _state({
  required BridgeProcessState processState,
  ControlRelayConnectionState relay = ControlRelayConnectionState.disconnected,
}) => BridgeControlState(
  trayAvailability: SystemTrayAvailability.available,
  activity: BridgeControlActivity.idle,
  statusLabel: "Bridge status",
  processState: processState,
  desiredState: BridgeProcessDesiredState.on,
  toggleTarget: BridgeProcessDesiredState.off,
  launchAtLoginEnabled: false,
  controlStatus: BridgeControlStatus(
    startup: ControlStartupState.ready,
    helperOnline: false,
    bridgeId: null,
    relay: relay,
    plugin: ControlPluginHealthState.unknown,
    activeSessionCount: 0,
  ),
);

void _noOp() {}
void _openProject({required BuildContext context, required ProjectSummary project, required String displayName}) {}

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;
class _MockRepository() extends Mock implements DesktopInstanceRepository;
