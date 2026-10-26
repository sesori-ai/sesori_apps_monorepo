import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/features/home/desktop_home_pane.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late _MockBridgeControlCubit bridgeControlCubit;
  late _MockProjectListCubit projects;
  late MockRegisteredBridgesService bridges;
  late BehaviorSubject<ConnectionStatus> statuses;
  late BehaviorSubject<String?> localIds;
  late _MockComputerSwitchDispatcher switches;
  late _MockFileAccessCubit fileAccess;
  late _MockAllSessionsCubit sessions;
  late _MockLocalBridgeStartupCubit startup;

  setUp(() {
    startup = _MockLocalBridgeStartupCubit();
    whenListen(startup, const Stream<LocalBridgeStartupState>.empty(), initialState: LocalBridgeStartupState.settled);
    projects = _MockProjectListCubit();
    sessions = _MockAllSessionsCubit();
    whenListen(sessions, const Stream<AllSessionsState>.empty(), initialState: _list(defaultProjectId: null));
    fileAccess = _MockFileAccessCubit();
    whenListen(
      fileAccess,
      const Stream<FileAccessState>.empty(),
      initialState: const FileAccessState(status: FileAccessStatus.unsupported, dismissed: false),
    );
    when(fileAccess.openSystemSettings).thenAnswer((_) async {});
    bridges = MockRegisteredBridgesService();
    when(bridges.hasRegisteredBridges).thenAnswer((_) async => false);
    when(bridges.getRegisteredBridges).thenAnswer((_) async => []);
    final connection = _MockConnectionService();
    statuses = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
    addTearDown(statuses.close);
    when(() => connection.status).thenAnswer((_) => statuses);
    when(() => connection.currentStatus).thenAnswer((_) => statuses.value);
    getIt.registerSingleton<RegisteredBridgesService>(bridges);
    getIt.registerSingleton<ConnectionService>(connection);
    getIt.registerSingleton<SelectedComputerService>(_ConnectionTargetSelection(statuses: statuses));
    localIds = BehaviorSubject<String?>.seeded(null);
    addTearDown(localIds.close);
    getIt.registerSingleton<ActiveBridgeLocality>(_Locality(localIds: localIds));
    switches = _MockComputerSwitchDispatcher();
    when(
      () => switches.switchTo(
        bridgeId: any(named: "bridgeId"),
        source: ComputerSwitchSource.menu,
      ),
    ).thenAnswer((_) async {});
    when(
      () => switches.switchTo(
        bridgeId: any(named: "bridgeId"),
        source: ComputerSwitchSource.offlineScreen,
      ),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<ComputerSwitchDispatcher>(switches);
    final voice = MockVoiceTranscriptionService();
    stubVoiceTranscriptionService(service: voice);
    getIt.registerSingleton<VoiceTranscriptionService>(voice);
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
            BlocProvider<AllSessionsCubit>.value(value: sessions),
            BlocProvider<LocalBridgeStartupCubit>.value(value: startup),
          ],
          child: Scaffold(
            body: DesktopHomePane(
              onOpenSession: ({required context, required project, required displayName, required session}) {},
              onOpenHarnessSettings: () {},
              onManageComputers: () {},
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
      state: const ProjectListState.loaded(projects: [], folderProjects: [], scratchProject: null),
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
          hostname: "workstation.local",
          platform: BridgePlatform.macos,
          status: BridgeRegistrationStatus.active,
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

  testWidgets("this computer's starting bridge is a load until the start fails", (tester) async {
    final starts = BehaviorSubject<LocalBridgeStartupState>.seeded(LocalBridgeStartupState.starting);
    addTearDown(starts.close);
    whenListen(startup, starts, initialState: starts.value);
    await pumpHome(tester: tester, state: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: false));

    expect(find.byType(PregoAiLoader), findsOneWidget);
    expect(find.text("Start the bridge"), findsNothing);

    starts.add(LocalBridgeStartupState.settled);
    await tester.pumpAndSettle();
    expect(find.byType(PregoAiLoader), findsNothing);
    expect(find.text("Start the bridge"), findsOneWidget);
  });

  group("with several computers", () {
    final local = _computer(id: "local", name: "this-mac", status: BridgeRegistrationStatus.active);
    final remote = _computer(id: "remote", name: "workstation", status: BridgeRegistrationStatus.inactive);
    final gpu = _computer(id: "gpu", name: "gpu-box", status: BridgeRegistrationStatus.active);

    void arrange({required List<BridgeSummary> computers, required String? targetId, required String? localId}) {
      when(bridges.hasRegisteredBridges).thenAnswer((_) async => true);
      when(bridges.getRegisteredBridges).thenAnswer((_) async => computers);
      bridges.emitBridges(bridges: computers);
      if (targetId != null) {
        statuses.add(
          ConnectionStatus.reconnecting(
            config: ServerConnectionConfig(relayHost: "relay", authToken: "token", bridgeId: targetId),
          ),
        );
      }
      localIds.add(localId);
    }

    testWidgets("an offline remote computer offers switching, never a supervised start", (tester) async {
      arrange(computers: [local, remote, gpu], targetId: remote.id, localId: local.id);
      await pumpHome(tester: tester, state: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true));
      await tester.pumpAndSettle();

      expect(find.text("workstation is offline"), findsOneWidget);
      expect(find.text("Start the bridge on that computer to load its projects and sessions here."), findsOneWidget);
      expect(find.text("Start the bridge"), findsNothing);
      expect(find.text("Viewing: workstation"), findsOneWidget);

      await tester.tap(find.text("this-mac"));
      verify(() => switches.switchTo(bridgeId: local.id, source: ComputerSwitchSource.offlineScreen)).called(1);
      verifyNever(bridgeControlCubit.recoverConnection);
    });

    testWidgets("an offline remote computer shows offline while this computer's bridge starts", (tester) async {
      whenListen(
        startup,
        const Stream<LocalBridgeStartupState>.empty(),
        initialState: LocalBridgeStartupState.starting,
      );
      arrange(computers: [local, remote], targetId: remote.id, localId: local.id);
      await pumpHome(tester: tester, state: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true));
      await tester.pumpAndSettle();

      expect(find.text("workstation is offline"), findsOneWidget);
      expect(find.byType(PregoAiLoader), findsNothing);
    });

    testWidgets("this computer offline keeps the supervised start", (tester) async {
      arrange(computers: [local, remote], targetId: local.id, localId: local.id);
      await pumpHome(tester: tester, state: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true));
      await tester.pumpAndSettle();

      expect(find.text("Viewing: This computer"), findsOneWidget);
      expect(find.text("workstation is offline"), findsNothing);
      await tester.tap(find.text("Start the bridge"));
      verify(bridgeControlCubit.recoverConnection).called(1);
    });

    testWidgets("before this computer's id is known, header and body both treat it as this computer", (tester) async {
      // A fresh install: no target yet, the helper has not registered, and the
      // account already lists other computers.
      arrange(computers: [remote, gpu], targetId: null, localId: null);
      await pumpHome(tester: tester, state: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true));
      await tester.pumpAndSettle();

      expect(find.text("Viewing: This computer"), findsOneWidget);
      expect(find.text("Viewing: workstation"), findsNothing);
      expect(find.text("Start the bridge"), findsOneWidget);
    });

    testWidgets("the header's menu switches to another computer", (tester) async {
      arrange(computers: [local, remote, gpu], targetId: remote.id, localId: local.id);
      await pumpHome(
        tester: tester,
        state: const ProjectListState.loaded(projects: [], folderProjects: [], scratchProject: null),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("desktop-computer-header")));
      await tester.pumpAndSettle();
      await tester.tap(find.text("gpu-box"));
      await tester.pumpAndSettle();

      verify(() => switches.switchTo(bridgeId: gpu.id, source: ComputerSwitchSource.menu)).called(1);
    });

    testWidgets("the header stays hidden while this computer is the account's only one", (tester) async {
      arrange(computers: [local], targetId: local.id, localId: local.id);
      await pumpHome(
        tester: tester,
        state: const ProjectListState.loaded(projects: [], folderProjects: [], scratchProject: null),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("desktop-computer-header")), findsNothing);
    });
  });

  testWidgets("a home without projects asks for one, through the picker's Open folder", (tester) async {
    await pumpHome(
      tester: tester,
      state: const ProjectListState.loaded(projects: [], folderProjects: [], scratchProject: null),
    );
    expect(find.byKey(const Key("desktop-home-prompt")), findsOneWidget);
    final button = tester.widget<PregoButtonsSolid>(find.byKey(const Key("new_session_project")));
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
    late List<ProjectKind> createdKinds;
    late List<({String projectId, String sessionId})> opened;
    late _MockChatInputModeCubit inputMode;

    _MockNewSessionCubit newSessionCubit({required Stream<NewSessionState> states}) {
      final cubit = _MockNewSessionCubit();
      whenListen(cubit, states, initialState: _composing);
      when(() => cubit.needsHarnessDiscovery).thenReturn(false);
      when(() => cubit.hasNoHarnesses).thenReturn(false);
      when(cubit.readDedicatedWorktreePreference).thenAnswer((_) async => true);
      when(() => cubit.canSubmit).thenReturn(true);
      when(() => cubit.canRefreshOptions).thenReturn(false);
      when(() => cubit.composerPresentation).thenReturn(const NewSessionComposerReady());
      when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
      return cubit;
    }

    setUp(() {
      createdFor = [];
      createdKinds = [];
      opened = [];
      inputMode = _MockChatInputModeCubit();
      whenListen(inputMode, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.voiceFirst);
    });

    Future<void> pumpStart({
      required WidgetTester tester,
      required AllSessionsState list,
      Stream<AllSessionsState> listUpdates = const Stream.empty(),
      Stream<NewSessionState> states = const Stream<NewSessionState>.empty(),
      List<ProjectSummary> projects = const [one, two],
    }) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      whenListen(sessions, listUpdates, initialState: list);
      final projectList = _MockProjectListCubit();
      whenListen(
        projectList,
        const Stream<ProjectListState>.empty(),
        initialState: ProjectListState.loaded(
          projects: projects,
          folderProjects: [
            for (final project in projects)
              if (project.kind == ProjectKind.folder) project,
          ],
          scratchProject: projects.where((project) => project.kind == ProjectKind.scratch).firstOrNull,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<FileAccessCubit>.value(value: fileAccess),
              BlocProvider<AllSessionsCubit>.value(value: sessions),
              BlocProvider<ChatInputModeCubit>.value(value: inputMode),
              BlocProvider<ProjectListCubit>.value(value: projectList),
            ],
            child: DesktopHomeStart(
              projects: projects,
              createNewSessionCubit: ({required projectId, required projectName, required projectKind}) {
                createdFor.add(projectId);
                createdKinds.add(projectKind);
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

    // The switch builds, then its crossfade runs out, so only the pane switched
    // to remains.
    Future<void> crossfade(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    }

    String shownProject(WidgetTester tester) => tester.widget<NewSessionView>(find.byType(NewSessionView)).projectId;

    testWidgets("starts a new session in the list's default project", (tester) async {
      await pumpStart(
        tester: tester,
        list: _list(defaultProjectId: "two"),
      );

      expect(createdFor, ["two"]);
      expect(find.byType(PromptInput), findsOneWidget);
      expect(shownProject(tester), "two");
    });

    testWidgets("a computer with only No project still starts a session, in No project", (tester) async {
      const scratch = ProjectSummary(
        id: "scratch",
        name: null,
        path: "/scratch",
        time: null,
        kind: ProjectKind.scratch,
      );
      await pumpStart(
        tester: tester,
        list: _list(defaultProjectId: "scratch"),
        projects: const [scratch],
      );

      expect(createdFor, ["scratch"]);
      expect(createdKinds, [ProjectKind.scratch]);
      expect(find.byType(PromptInput), findsOneWidget);
      expect(find.byKey(const Key("desktop-home-prompt")), findsNothing);
    });

    testWidgets("waits while the list loads, then takes up the first default", (tester) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpStart(
        tester: tester,
        list: _list(defaultProjectId: null, isLoading: true),
        listUpdates: updates.stream,
      );
      expect(find.byKey(const Key("desktop-home-waiting")), findsOneWidget);
      expect(find.byKey(const Key("desktop-home-prompt")), findsNothing);

      updates.add(_list(defaultProjectId: "one"));
      await tester.pump();
      await crossfade(tester);

      expect(createdFor, ["one"]);
      expect(find.byKey(const Key("desktop-home-waiting")), findsNothing);
    });

    testWidgets("a newer session elsewhere keeps the draft's project; another filter moves it", (tester) async {
      final updates = StreamController<AllSessionsState>();
      addTearDown(updates.close);
      await pumpStart(
        tester: tester,
        list: _list(defaultProjectId: "one"),
        listUpdates: updates.stream,
      );

      updates.add(_list(defaultProjectId: "two"));
      await tester.pump();
      await crossfade(tester);
      expect(createdFor, ["one"]);

      updates.add(_list(projectId: "two", defaultProjectId: "two"));
      await tester.pump();
      await crossfade(tester);
      expect(createdFor, ["one", "two"]);
      expect(shownProject(tester), "two");
    });

    testWidgets("without a default, asks for a project and starts in the one picked", (tester) async {
      await pumpStart(tester: tester, list: _list(defaultProjectId: null));
      expect(find.byKey(const Key("desktop-home-prompt")), findsOneWidget);
      expect(find.text("Choose a project"), findsOneWidget);
      expect(createdFor, isEmpty);

      tester
          .widget<NewSessionProjectPrompt>(find.byType(NewSessionProjectPrompt))
          .onProjectSelected(projectId: "two", projectName: "Two");
      await tester.pump();
      await crossfade(tester);

      expect(createdFor, ["two"]);
      expect(shownProject(tester), "two");
    });

    testWidgets("picking another project gives it its own cubit", (tester) async {
      await pumpStart(
        tester: tester,
        list: _list(defaultProjectId: "one"),
      );

      tester
          .widget<NewSessionView>(find.byType(NewSessionView))
          .onProjectSelected
          ?.call(projectId: "two", projectName: "Two");
      await tester.pump();
      await crossfade(tester);

      expect(createdFor, ["one", "two"]);
      expect(shownProject(tester), "two");
    });

    testWidgets("a reordered project list keeps the project already shown", (tester) async {
      await pumpStart(
        tester: tester,
        list: _list(defaultProjectId: "one"),
      );
      await pumpStart(
        tester: tester,
        list: _list(defaultProjectId: "one"),
        projects: const [two, one],
      );

      expect(createdFor, ["one"]);
      expect(shownProject(tester), "one");
    });

    testWidgets("a session started from home opens in the picked project", (tester) async {
      final created = _session(id: "created", projectId: "one", updated: 1);
      await pumpStart(
        tester: tester,
        list: _list(defaultProjectId: "one"),
        states: Stream.value(NewSessionState.created(session: created, launchId: "launch-1")),
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
  updateState: DesktopUpdateManagedBySystem(),
);

BridgeSummary _computer({required String id, required String name, required BridgeRegistrationStatus status}) =>
    BridgeSummary(
      id: id,
      name: name,
      hostname: name,
      platform: BridgePlatform.macos,
      status: status,
      addedAt: DateTime.utc(2026, 1, 1),
      lastSeenAt: null,
    );

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
class _MockFileAccessCubit() extends MockCubit<FileAccessState> implements FileAccessCubit;

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

class _MockLocalBridgeStartupCubit() extends MockCubit<LocalBridgeStartupState> implements LocalBridgeStartupCubit;

/// Names the live connection's target, as the real service does.
class _ConnectionTargetSelection({required final BehaviorSubject<ConnectionStatus> _statuses})
    extends FakeSelectedComputerService {
  @override
  Future<String?> targetBridgeId() async => _statuses.value.targetBridgeId;
}

class _MockComputerSwitchDispatcher() extends Mock implements ComputerSwitchDispatcher;

class _MockConnectionService() extends Mock implements ConnectionService;

class _MockNewSessionCubit() extends MockCubit<NewSessionState> implements NewSessionCubit;

class _MockAllSessionsCubit() extends MockCubit<AllSessionsState> implements AllSessionsCubit;

/// The sidebar's list as the home reads it: only its filter, default and
/// loading matter here.
AllSessionsState _list({String? projectId, required String? defaultProjectId, bool isLoading = false}) =>
    AllSessionsState(
      projectId: projectId,
      query: "",
      quickFilter: SessionListQuickFilter.all,
      everyProjectRows: const [],
      rows: const [],
      counts: const SessionListChipCounts(all: 0, running: 0, unread: 0),
      failures: const [],
      isLoading: isLoading,
      scratchProjectId: null,
      defaultProjectId: defaultProjectId,
    );

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

Session _session({required String id, required String projectId, required int updated}) => Session(
  approvalOverride: null,
  autoContinuation: null,
  id: id,
  title: id,
  projectID: projectId,
  pluginId: "plugin",
  directory: "/$projectId",
  parentID: null,
  branchName: null,
  time: SessionTime(created: 1, updated: updated, archived: null),
  promptDefaults: null,
  lastUserActivityAt: null,
  unseen: false,
);

class _Locality({required final BehaviorSubject<String?> _localIds}) implements ActiveBridgeLocality {
  @override
  String? get localBridgeId => _localIds.value;

  @override
  Stream<String?> get localBridgeIdStream => _localIds.stream;

  @override
  bool isLocalBridge({required String bridgeId}) => bridgeId == _localIds.value;
}
