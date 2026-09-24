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
  late _MockFileAccessCubit fileAccess;

  setUp(() {
    projects = _MockProjectListCubit();
    fileAccess = _MockFileAccessCubit();
    whenListen(
      fileAccess,
      const Stream<FileAccessState>.empty(),
      initialState: const FileAccessState(status: FileAccessStatus.unsupported, dismissed: false),
    );
    when(fileAccess.openSystemSettings).thenAnswer((_) async {});
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

  tearDown(getIt.reset);

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
            BlocProvider<FileAccessCubit>.value(value: fileAccess),
          ],
          child: Scaffold(
            body: DesktopHomePane(
              onOpenSession: ({required context, required project, required displayName, required session}) {},
              onOpenHarnessSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("optional local-access card remains usable in a narrow home pane", (tester) async {
    tester.view.physicalSize = const Size(300, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final states = BehaviorSubject<FileAccessState>.seeded(
      const FileAccessState(status: FileAccessStatus.denied, dismissed: false),
    );
    addTearDown(states.close);
    whenListen(fileAccess, states, initialState: states.value);
    when(fileAccess.dismiss)
        .thenAnswer((_) => states.add(const FileAccessState(status: FileAccessStatus.denied, dismissed: true)));
    await pumpHome(
      tester: tester,
      state: const ProjectListState.loaded(projects: [], activityById: {}),
    );
    expect(find.text("Full Disk Access"), findsOneWidget);
    await tester.ensureVisible(find.text("Open System Settings"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Open System Settings"));
    verify(fileAccess.openSystemSettings).called(1);
    await tester.ensureVisible(find.text("Not now"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Not now"));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("desktop-file-access-card")), findsNothing);
    expect(find.byType(PregoButtonsSolid).hitTestable(), findsOneWidget);
    verifyNever(bridgeControlCubit.recoverConnection);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets("empty home offers the shared add-project action", (tester) async {
    await pumpHome(
      tester: tester,
      state: const ProjectListState.loaded(projects: [], activityById: {}),
    );
    final button = tester.widget<PregoButtonsSolid>(find.byType(PregoButtonsSolid));
    expect(button.onPressed, isNotNull);
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

  group("with projects", () {
    const one = ProjectSummary(id: "one", name: "One", path: "/one", time: null);
    const two = ProjectSummary(id: "two", name: "Two", path: "/two", time: null);
    late List<String> createdFor;
    late List<({String projectId, String sessionId})> opened;
    late _MockRecentSessionsCubit recent;
    late _MockPendingSessionArchiveCubit archive;
    late _MockChatInputModeCubit inputMode;

    _MockNewSessionCubit newSessionCubit({required Stream<NewSessionState> states}) {
      final cubit = _MockNewSessionCubit();
      whenListen(cubit, states, initialState: _composing);
      when(() => cubit.needsHarnessDiscovery).thenReturn(false);
      when(() => cubit.hasNoHarnesses).thenReturn(false);
      when(() => cubit.canCreateSession).thenReturn(true);
      when(() => cubit.canRefreshOptions).thenReturn(false);
      when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
      return cubit;
    }

    setUp(() {
      createdFor = [];
      opened = [];
      recent = _MockRecentSessionsCubit();
      archive = _MockPendingSessionArchiveCubit();
      inputMode = _MockChatInputModeCubit();
      whenListen(
        archive,
        const Stream<PendingSessionArchiveState>.empty(),
        initialState: const PendingSessionArchiveState(window: PendingArchiveIdle(), archivingIds: {}),
      );
      whenListen(inputMode, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.voiceFirst);
    });

    Future<void> pumpStart({
      required WidgetTester tester,
      required Map<String, RecentSessionsEntry> entries,
      Stream<NewSessionState> states = const Stream<NewSessionState>.empty(),
    }) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      whenListen(recent, const Stream<Map<String, RecentSessionsEntry>>.empty(), initialState: entries);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<FileAccessCubit>.value(value: fileAccess),
              BlocProvider<RecentSessionsCubit>.value(value: recent),
              BlocProvider<PendingSessionArchiveCubit>.value(value: archive),
              BlocProvider<ChatInputModeCubit>.value(value: inputMode),
            ],
            child: DesktopHomeStart(
              projects: const [one, two],
              createNewSessionCubit: ({required projectId}) {
                createdFor.add(projectId);
                return newSessionCubit(states: states);
              },
              onOpenSession: ({required context, required project, required displayName, required session}) =>
                  opened.add((projectId: project.id, sessionId: session.id)),
              onOpenHarnessSettings: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets("shows the composer, then needs-you, running and recent sessions", (tester) async {
      final waiting = _session(id: "waiting", projectId: "two", updated: 3);
      final running = _session(id: "running", projectId: "one", updated: 2);
      final settled = _session(id: "settled", projectId: "two", updated: 1);
      await pumpStart(
        tester: tester,
        entries: {
          "one": RecentSessionsLoaded(
            sourceSessions: [running],
            visibleSessions: [running],
            activityBySessionId: {"running": _activity(awaitingInput: false)},
            listStateBySessionId: const {},
          ),
          "two": RecentSessionsLoaded(
            sourceSessions: [waiting, settled],
            visibleSessions: [waiting, settled],
            activityBySessionId: {"waiting": _activity(awaitingInput: true)},
            listStateBySessionId: const {},
          ),
        },
      );

      expect(createdFor, ["one"]);
      expect(find.byType(PromptInput), findsOneWidget);
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top("Needs you"), lessThan(top("waiting")));
      expect(top("waiting"), lessThan(top("Running")));
      expect(top("Running"), lessThan(top("running")));
      expect(top("running"), lessThan(top("Recent")));
      expect(top("Recent"), lessThan(top("settled")));

      await tester.tap(find.text("settled"));
      expect(opened, [(projectId: "two", sessionId: "settled")]);
    });

    testWidgets("picking another project gives it its own cubit", (tester) async {
      await pumpStart(tester: tester, entries: const {});
      expect(find.text("Needs you"), findsNothing);

      tester
          .widget<NewSessionView>(find.byType(NewSessionView))
          .onProjectSelected(projectId: "two", projectName: "Two");
      await tester.pump();

      expect(createdFor, ["one", "two"]);
      expect(tester.widget<NewSessionView>(find.byType(NewSessionView)).projectId, "two");
    });

    testWidgets("a session started from home opens in the picked project", (tester) async {
      final created = _session(id: "created", projectId: "one", updated: 1);
      await pumpStart(
        tester: tester,
        entries: const {},
        states: Stream.value(NewSessionState.created(session: created)),
      );
      await tester.pump();

      expect(opened, [(projectId: "one", sessionId: "created")]);
    });
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
class _MockFileAccessCubit() extends MockCubit<FileAccessState> implements FileAccessCubit;

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

class _MockRegisteredBridgesService() extends Mock implements RegisteredBridgesService;

class _MockConnectionService() extends Mock implements ConnectionService;

class _MockNewSessionCubit() extends MockCubit<NewSessionState> implements NewSessionCubit;

class _MockRecentSessionsCubit() extends MockCubit<Map<String, RecentSessionsEntry>> implements RecentSessionsCubit;

class _MockPendingSessionArchiveCubit()
    extends MockCubit<PendingSessionArchiveState>
    implements PendingSessionArchiveCubit;

class _MockChatInputModeCubit() extends MockCubit<ChatInputMode> implements ChatInputModeCubit;

const _composing = NewSessionState.composing(
  config: NewSessionComposeConfig(
    availablePlugins: [],
    selectedPlugin: null,
    options: NewSessionOptionsLoadState.unsupported(),
    backendScope: NewSessionBackendScope.verified(bridgeId: null),
    isPluginDiscoveryInFlight: false,
    projectWorktreeCapability: NewSessionProjectWorktreeCapability.supported,
  ),
  phase: NewSessionPhase.idle(),
);

SessionActivityInfo _activity({required bool awaitingInput}) => SessionActivityInfo(
  mainAgentRunning: true,
  awaitingInput: awaitingInput,
  lastUserActivityAt: null,
  updatedAt: null,
);

Session _session({required String id, required String projectId, required int updated}) => Session(
  id: id,
  title: id,
  projectID: projectId,
  pluginId: "plugin",
  directory: "/$projectId",
  parentID: null,
  branchName: null,
  pullRequest: null,
  time: SessionTime(created: 1, updated: updated, archived: null),
  promptDefaults: null,
  lastUserActivityAt: null,
  unseen: false,
);
