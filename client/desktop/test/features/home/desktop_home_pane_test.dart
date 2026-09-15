import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/features/home/desktop_home_pane.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late _MockBridgeControlCubit bridgeControlCubit;
  late _MockProjectListCubit projects;
  late _MockRegisteredBridgesService bridges;

  setUp(() {
    projects = _MockProjectListCubit();
    bridges = _MockRegisteredBridgesService();
    when(bridges.hasRegisteredBridges).thenAnswer((_) async => false);
    when(bridges.getRegisteredBridges).thenAnswer((_) async => []);
    final connection = _MockConnectionService();
    final statuses = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
    addTearDown(statuses.close);
    when(() => connection.status).thenAnswer((_) => statuses);
    getIt.registerSingleton<RegisteredBridgesService>(bridges);
    getIt.registerSingleton<ConnectionService>(connection);
    bridgeControlCubit = _MockBridgeControlCubit();
    when(bridgeControlCubit.recoverConnection).thenAnswer((_) async {});
    whenListen(
      bridgeControlCubit,
      const Stream<BridgeControlState>.empty(),
      initialState: _bridgeControlState,
    );
  });

  tearDown(() => getIt.reset());

  Future<void> pumpHome({required WidgetTester tester, required ProjectListState state}) async {
    whenListen(projects, const Stream<ProjectListState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<BridgeControlCubit>.value(value: bridgeControlCubit),
            BlocProvider<ProjectListCubit>.value(value: projects),
          ],
          child: const Scaffold(body: DesktopHomePane()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("never-registered recovery offers supervised Start without CLI guidance", (tester) async {
    await pumpHome(
      tester: tester,
      state: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: false),
    );

    expect(find.text("Start the bridge"), findsOneWidget);
    expect(find.text("Start the local bridge to load your projects and sessions in Sesori."), findsOneWidget);
    expect(find.text("Install commands"), findsNothing);
    expect(find.text("Make sure the Bridge is running"), findsNothing);

    await tester.tap(find.text("Start the bridge"));
    verify(bridgeControlCubit.recoverConnection).called(1);
  });

  testWidgets("registered-but-disconnected recovery uses the same supervised action", (tester) async {
    when(bridges.hasRegisteredBridges).thenAnswer((_) async => true);
    when(bridges.getRegisteredBridges).thenAnswer(
      (_) async => [
        BridgeSummary(
          id: "bridge-1",
          name: "workstation.local",
          platform: "macos",
          addedAt: DateTime.utc(2026, 1, 1),
          lastSeenAt: DateTime.utc(2026, 9, 1),
        ),
      ],
    );
    await pumpHome(
      tester: tester,
      state: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true),
    );

    expect(find.text("workstation.local"), findsOneWidget);
    expect(find.text("Start the bridge"), findsOneWidget);
    expect(find.text("Install commands"), findsNothing);

    await tester.tap(find.text("Start the bridge"));
    verify(bridgeControlCubit.recoverConnection).called(1);
  });

  testWidgets("connected home directs to the sidebar without another project list", (tester) async {
    await pumpHome(
      tester: tester,
      state: const ProjectListState.loaded(
        projects: [ProjectSummary(id: "p", name: "Project", path: "/project", time: null)],
        activityById: {},
      ),
    );
    expect(find.text("Pick a session from the sidebar to get started."), findsOneWidget);
    expect(find.byType(ProjectListView), findsNothing);
    expect(find.byType(ProjectTile), findsNothing);
    expect(find.byType(PregoButtonsSolid), findsNothing);
    verifyNever(bridges.hasRegisteredBridges);
  });

  testWidgets("empty home offers the shared add-project action", (tester) async {
    await pumpHome(
      tester: tester,
      state: const ProjectListState.loaded(projects: [], activityById: {}),
    );
    final button = tester.widget<PregoButtonsSolid>(find.byType(PregoButtonsSolid));
    expect(button.onPressed, isNotNull);
    expect(find.text("Pick a session from the sidebar to get started."), findsNothing);
    verifyNever(bridgeControlCubit.recoverConnection);
  });

  testWidgets("failed home retries the shared inventory through its recovery path", (tester) async {
    when(projects.retryLoadProjects).thenAnswer((_) async {});
    await pumpHome(
      tester: tester,
      state: const ProjectListState.failed(reason: RemoteFailureReason.networkDown),
    );
    await tester.tap(find.text("Retry"));
    verify(projects.retryLoadProjects).called(1);
    verifyNever(projects.refreshProjects);
  });

  testWidgets("loading home is labelled and does not substitute a Flutter renderer", (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpHome(tester: tester, state: const ProjectListState.loading());
      final loader = tester.widget<PregoAiLoader>(find.byType(PregoAiLoader));
      expect(loader.color, isNull);
      expect(find.bySemanticsLabel("Loading projects"), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
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

class _MockRegisteredBridgesService() extends Mock implements RegisteredBridgesService;

class _MockConnectionService() extends Mock implements ConnectionService;
