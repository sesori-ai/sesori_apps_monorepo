import "dart:async";
import "dart:math" as math;

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

  Future<void> pumpHome({
    required WidgetTester tester,
    required ProjectListState state,
    Stream<ProjectListState> updates = const Stream.empty(),
    Brightness brightness = Brightness.light,
  }) async {
    whenListen(projects, updates, initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: brightness),
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

  group("a slow start of this computer's bridge", () {
    const line = "Still starting this computer's bridge…";
    const disconnected = ProjectListState.bridgeDisconnected(hasRegisteredBridges: false);
    final loader = find.byType(PregoAiLoader);

    void arrangeStarting() => whenListen(
      startup,
      const Stream<LocalBridgeStartupState>.empty(),
      initialState: LocalBridgeStartupState.starting,
    );

    // The opacity the line is painted with now: its nearest fade's.
    double lineOpacity(WidgetTester tester) => tester
        .widget<FadeTransition>(find.ancestor(of: find.text(line), matching: find.byType(FadeTransition)).first)
        .opacity
        .value;

    testWidgets("keeps the running loader in place, and a launch ending before 10 s never shows the line", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final starts = BehaviorSubject<LocalBridgeStartupState>.seeded(LocalBridgeStartupState.starting);
        addTearDown(starts.close);
        whenListen(startup, starts, initialState: starts.value);
        final updates = StreamController<ProjectListState>();
        addTearDown(updates.close);
        // The relay is still connecting as the launch begins: a load.
        await pumpHome(tester: tester, state: const ProjectListState.loading(), updates: updates.stream);
        final running = tester.state(loader);
        final place = tester.getRect(loader);

        // The state lands, then the frame it schedules builds the launch.
        updates.add(disconnected);
        await tester.pump();
        await tester.pump();
        expect(tester.state(loader), same(running));
        expect(tester.getRect(loader), place);
        expect(find.text("Start the bridge"), findsNothing);

        await tester.pump(const Duration(milliseconds: 9900));
        expect(lineOpacity(tester), 0);
        expect(find.bySemanticsLabel(line), findsNothing);
        expect(find.bySemanticsLabel("Loading projects"), findsOneWidget);

        // The app reaches the bridge and loads the projects: the launch's wait
        // is dropped, so its 10 s pass without the line.
        updates.add(const ProjectListState.loading());
        starts.add(LocalBridgeStartupState.settled);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(lineOpacity(tester), 0);
        expect(tester.state(loader), same(running));
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    });

    testWidgets("after 10 s the line fades in under the loader, which stays put", (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        arrangeStarting();
        await pumpHome(tester: tester, state: disconnected);
        final place = tester.getRect(loader);
        // Centred in the body, as any load shows it.
        expect(place.center, tester.getCenter(find.ancestor(of: loader, matching: find.byType(SafeArea)).first));

        // The timer fires, and the frame it builds starts the fade.
        await tester.pump(const Duration(seconds: 10));
        await tester.pump(const Duration(milliseconds: 110));
        expect(lineOpacity(tester), allOf(greaterThan(0), lessThan(1)));
        expect(tester.getRect(loader), place);

        await tester.pump(const Duration(milliseconds: 200));
        expect(lineOpacity(tester), 1);
        expect(tester.getRect(loader), place);
        expect(tester.getRect(find.text(line)).top, greaterThan(place.bottom));
        expect(find.bySemanticsLabel(line), findsOneWidget);
        expect(find.bySemanticsLabel("Loading projects"), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    });

    testWidgets("when the launch gives way to an ordinary load, the line fades out over the running loader", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final starts = BehaviorSubject<LocalBridgeStartupState>.seeded(LocalBridgeStartupState.starting);
        addTearDown(starts.close);
        whenListen(startup, starts, initialState: starts.value);
        final updates = StreamController<ProjectListState>();
        addTearDown(updates.close);
        await pumpHome(tester: tester, state: disconnected, updates: updates.stream);
        await tester.pump(const Duration(seconds: 10));
        await tester.pump(const Duration(milliseconds: 300));
        expect(lineOpacity(tester), 1);
        final running = tester.state(loader);
        final place = tester.getRect(loader);

        // The app reaches the bridge: the launch ends and the projects load.
        updates.add(const ProjectListState.loading());
        starts.add(LocalBridgeStartupState.settled);
        // The states land, then the frame they schedule starts the fade.
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        expect(lineOpacity(tester), allOf(greaterThan(0), lessThan(1)));
        expect(tester.state(loader), same(running));
        expect(tester.getRect(loader), place);

        await tester.pump(const Duration(milliseconds: 200));
        expect(lineOpacity(tester), 0);
        // The live tree: the faded line's node stays cached on its render object.
        expect(find.semantics.byLabel(line), findsNothing);
        expect(tester.state(loader), same(running));
        expect(tester.getRect(loader), place);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    });

    testWidgets("with reduced motion, the line shows and leaves at once", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final starts = BehaviorSubject<LocalBridgeStartupState>.seeded(LocalBridgeStartupState.starting);
      addTearDown(starts.close);
      whenListen(startup, starts, initialState: starts.value);
      final updates = StreamController<ProjectListState>();
      addTearDown(updates.close);
      await pumpHome(tester: tester, state: disconnected, updates: updates.stream);

      await tester.pump(const Duration(milliseconds: 9999));
      expect(lineOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(lineOpacity(tester), 1);

      updates.add(const ProjectListState.loading());
      starts.add(LocalBridgeStartupState.settled);
      await tester.pump();
      await tester.pump();
      expect(lineOpacity(tester), 0);
    });

    testWidgets("a start that fails or stops after the line shows still gives way to recovery", (tester) async {
      final starts = BehaviorSubject<LocalBridgeStartupState>.seeded(LocalBridgeStartupState.starting);
      addTearDown(starts.close);
      whenListen(startup, starts, initialState: starts.value);
      await pumpHome(tester: tester, state: disconnected);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 300));
      expect(lineOpacity(tester), 1);

      // Failed and stopped alike leave the launch.
      starts.add(LocalBridgeStartupState.settled);
      await tester.pumpAndSettle();
      expect(find.text(line), findsNothing);
      expect(loader, findsNothing);
      expect(find.text("Start the bridge"), findsOneWidget);
    });

    testWidgets("a launch still waiting on the relay counts from its start, through its offline report", (
      tester,
    ) async {
      arrangeStarting();
      final updates = StreamController<ProjectListState>();
      addTearDown(updates.close);
      await pumpHome(tester: tester, state: const ProjectListState.loading(), updates: updates.stream);
      await tester.pump(const Duration(seconds: 6));
      updates.add(disconnected);
      await tester.pump();
      await tester.pump();
      expect(lineOpacity(tester), 0);

      // 10 s after the launch began, not after the offline report.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      expect(lineOpacity(tester), 1);
    });

    testWidgets("an ordinary load never shows the line", (tester) async {
      await pumpHome(tester: tester, state: const ProjectListState.loading());
      await tester.pump(const Duration(seconds: 11));
      expect(loader, findsOneWidget);
      expect(lineOpacity(tester), 0);
    });
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

  group("a computer switch", () {
    const project = ProjectSummary(id: "one", name: "demo-app", path: "/one", time: null);
    const ready = ProjectListState.loaded(projects: [project], folderProjects: [project], scratchProject: null);
    final composer = find.byType(PromptInput);
    final loader = find.byType(PregoAiLoader);
    late StreamController<ProjectListState> updates;

    setUp(() {
      // The composer's own services, on a bridge that never answers.
      final plugins = _MockPluginService();
      when(
        () => plugins.discover(
          currentSelectedPluginId: any(named: "currentSelectedPluginId"),
          currentSelectionBridgeId: any(named: "currentSelectionBridgeId"),
        ),
      ).thenAnswer((_) => Completer<ApiResponse<NewSessionPluginDiscovery>>().future);
      final projectRepository = MockProjectRepository();
      when(
        () => projectRepository.getProject(projectId: any(named: "projectId")),
      ).thenAnswer((_) => Completer<ApiResponse<Project>>().future);
      final analytics = MockProductAnalyticsService();
      final tracker = NewSessionSelectionTracker();
      getIt
        ..registerSingleton<NewSessionPluginService>(plugins)
        ..registerSingleton<NewSessionOptionsService>(_MockOptionsService())
        ..registerSingleton<ProjectRepository>(projectRepository)
        ..registerSingleton<NewSessionSelectionTracker>(tracker)
        ..registerSingleton<ComposerDraftRepository>(inMemoryComposerDraftRepository())
        ..registerSingleton<ProductAnalyticsService>(analytics)
        ..registerSingleton<SessionLaunchService>(
          SessionLaunchService(
            sessionRepository: MockSessionRepository(),
            launchRepository: inMemorySessionLaunchRepository(),
            feedbackPromptService: FakeFeedbackPromptService(),
            productAnalyticsService: analytics,
            selectionTracker: tracker,
            authSession: FakeAuthSession(initialState: const AuthState.initial()),
          ),
        )
        ..registerSingleton<DedicatedWorktreePreferenceStore>(FakeDedicatedWorktreePreferenceStore());
      whenListen(sessions, const Stream<AllSessionsState>.empty(), initialState: _list(defaultProjectId: project.id));
      updates = StreamController<ProjectListState>();
      addTearDown(updates.close);
    });

    Future<void> pumpReadyHome({required WidgetTester tester, Brightness brightness = Brightness.light}) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpHome(tester: tester, state: ready, updates: updates.stream, brightness: brightness);
    }

    // The state lands, then the frame it schedules starts the cross-fade.
    Future<void> land({required WidgetTester tester, required ProjectListState state}) async {
      updates.add(state);
      await tester.pump();
      await tester.pump();
    }

    // The opacity [finder] is painted with: every fade above it, multiplied.
    double opacityOf({required WidgetTester tester, required Finder finder}) => tester
        .widgetList<FadeTransition>(find.ancestor(of: finder, matching: find.byType(FadeTransition)))
        .fold<double>(1, (opacity, fade) => opacity * fade.opacity.value);

    testWidgets("cross-fades from the composer to the loader and back, each staying in its place", (tester) async {
      await pumpReadyHome(tester: tester);
      final composerRect = tester.getRect(composer);
      expect(opacityOf(tester: tester, finder: composer), 1);

      // Switching away: the composer fades out as the next computer loads.
      await land(tester: tester, state: const ProjectListState.loading());
      await tester.pump(const Duration(milliseconds: 110));
      expect(opacityOf(tester: tester, finder: composer), inExclusiveRange(0, 1));
      expect(opacityOf(tester: tester, finder: loader), inExclusiveRange(0, 1));
      expect(tester.getRect(composer), composerRect);
      final loaderRect = tester.getRect(loader);

      await tester.pump(const Duration(milliseconds: 120));
      expect(composer, findsNothing);
      expect(opacityOf(tester: tester, finder: loader), 1);
      expect(tester.getRect(loader), loaderRect);

      // Its projects arrive: the composer fades in over the leaving loader.
      await land(tester: tester, state: ready);
      await tester.pump(const Duration(milliseconds: 110));
      expect(opacityOf(tester: tester, finder: composer), inExclusiveRange(0, 1));
      expect(opacityOf(tester: tester, finder: loader), inExclusiveRange(0, 1));
      expect(tester.getRect(composer), composerRect);
      expect(tester.getRect(loader), loaderRect);
      // The arriving composer takes clicks while it fades in.
      expect(composer.hitTestable(), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 120));
      expect(loader, findsNothing);
      expect(opacityOf(tester: tester, finder: composer), 1);
      expect(tester.getRect(composer), composerRect);
    });

    testWidgets("the leaving body takes no clicks, focus or announcements as it fades", (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpReadyHome(tester: tester);
        // A draft keeps the field open once it loses focus.
        await tester.tap(composer);
        await tester.pump();
        await tester.enterText(find.byType(EditableText), "Fix the flaky test");
        await tester.pump(const Duration(milliseconds: 300));
        final field = tester.widget<EditableText>(find.byType(EditableText)).focusNode;
        expect(field.hasFocus, isTrue);

        await land(tester: tester, state: const ProjectListState.loading());
        await tester.pump(const Duration(milliseconds: 110));
        expect(find.byType(EditableText), findsOneWidget);
        expect(field.hasFocus, isFalse);
        field.requestFocus();
        await tester.pump();
        expect(field.hasFocus, isFalse);
        expect(find.semantics.byLabel("Loading projects"), findsOne);

        await tester.pump(const Duration(milliseconds: 230));
        await land(tester: tester, state: ready);
        await tester.pump(const Duration(milliseconds: 110));
        expect(loader, findsOneWidget);
        expect(find.semantics.byLabel("Loading projects"), findsNothing);
        expect(composer.hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    });

    testWidgets("with reduced motion, swaps at once", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpReadyHome(tester: tester);

      await land(tester: tester, state: const ProjectListState.loading());
      expect(composer, findsNothing);
      expect(opacityOf(tester: tester, finder: loader), 1);

      await land(tester: tester, state: ready);
      expect(loader, findsNothing);
      expect(opacityOf(tester: tester, finder: composer), 1);
    });

    testWidgets("switching back and forth faster than the fade settles on the last body alone", (tester) async {
      await pumpReadyHome(tester: tester);
      final composerRect = tester.getRect(composer);

      await land(tester: tester, state: const ProjectListState.loading());
      await tester.pump(const Duration(milliseconds: 60));
      final leaving = opacityOf(tester: tester, finder: composer);
      await land(tester: tester, state: ready);
      // The composer coming back is a new one: the one leaving goes on fading
      // from where it was, under the leaving loader and the new composer.
      expect(find.byType(DesktopHomeStart), findsNWidgets(2));
      expect(opacityOf(tester: tester, finder: composer.first), leaving);
      expect(opacityOf(tester: tester, finder: composer.last), 0);
      expect(loader, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      await land(tester: tester, state: const ProjectListState.loading());
      await tester.pump(const Duration(milliseconds: 60));
      await land(tester: tester, state: ready);

      await tester.pump(const Duration(milliseconds: 230));
      expect(tester.takeException(), isNull);
      expect(find.byType(DesktopHomeStart), findsOneWidget);
      expect(loader, findsNothing);
      expect(opacityOf(tester: tester, finder: composer), 1);
      expect(tester.getRect(composer), composerRect);
    });

    for (final brightness in Brightness.values) {
      testWidgets("only the pane paints the page, beneath both bodies as they cross (${brightness.name})", (
        tester,
      ) async {
        await pumpReadyHome(tester: tester, brightness: brightness);
        final page = Theme.of(tester.element(find.byType(DesktopHomePane))).scaffoldBackgroundColor;
        expect(page, buildPregoThemeData(brightness: brightness).scaffoldBackgroundColor);
        // Whatever in the pane paints the page's color.
        final painted = find.descendant(
          of: find.byType(DesktopHomePane),
          matching: find.byWidgetPredicate(
            (widget) => switch (widget) {
              ColoredBox(:final color) => color == page,
              Scaffold(:final backgroundColor) => (backgroundColor ?? page) == page,
              _ => false,
            },
          ),
        );
        const noProjects = ProjectListState.loaded(projects: [], folderProjects: [], scratchProject: null);

        // Halfway through each cross: the composer leaving, then arriving,
        // then the project prompt arriving.
        for (final state in [const ProjectListState.loading(), ready, const ProjectListState.loading(), noProjects]) {
          await land(tester: tester, state: state);
          await tester.pump(const Duration(milliseconds: 110));
          expect(find.byType(FadeTransition), findsWidgets);
          expect(painted, findsOneWidget);
          expect(find.ancestor(of: find.byType(AnimatedSwitcher).first, matching: painted), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 120));
        }
        expect(find.byKey(const Key("desktop-home-prompt")), findsOneWidget);
      });
    }

    testWidgets("a second computer's Viewing line fades in over the top band; the composer stays put", (tester) async {
      final heading = find.text("What should we work on?");
      final header = find.byKey(const Key("desktop-computer-header"));
      await pumpReadyHome(tester: tester);
      final composerRect = tester.getRect(composer);
      final headingRect = tester.getRect(heading);
      expect(header, findsNothing);

      // The account's list loads after the home, naming a second computer.
      bridges.emitBridges(
        bridges: [
          _computer(id: "local", name: "this-mac", status: BridgeRegistrationStatus.active),
          _computer(id: "studio", name: "Studio Mac", status: BridgeRegistrationStatus.active),
        ],
      );
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 33));
        expect(tester.getRect(composer), composerRect);
        expect(tester.getRect(heading), headingRect);
      }
      expect(find.text("Viewing: This computer"), findsOneWidget);
      expect(opacityOf(tester: tester, finder: header), 1);
      expect(header.hitTestable(), findsOneWidget);
      // Beside the line, the band leaves clicks to the body beneath it.
      final beside = Offset(
        tester.getRect(find.byType(DesktopHomePane)).right - PregoSpacing.x2l,
        tester.getCenter(header).dy,
      );
      expect(
        tester.hitTestOnBinding(beside).path.map((entry) => entry.target),
        contains(tester.renderObject(find.byType(NewSessionView))),
      );

      // Back to one computer, the line fades out the same way.
      bridges.emitBridges(
        bridges: [_computer(id: "local", name: "this-mac", status: BridgeRegistrationStatus.active)],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(opacityOf(tester: tester, finder: header), inExclusiveRange(0, 1));
      expect(tester.getRect(composer), composerRect);
      await tester.pump(const Duration(milliseconds: 120));
      expect(header, findsNothing);
      expect(tester.getRect(composer), composerRect);
    });

    testWidgets("with reduced motion the Viewing line appears at once", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final header = find.byKey(const Key("desktop-computer-header"));
      await pumpReadyHome(tester: tester);
      final composerRect = tester.getRect(composer);

      bridges.emitBridges(
        bridges: [
          _computer(id: "local", name: "this-mac", status: BridgeRegistrationStatus.active),
          _computer(id: "studio", name: "Studio Mac", status: BridgeRegistrationStatus.active),
        ],
      );
      await tester.pump();
      await tester.pump();
      expect(opacityOf(tester: tester, finder: header), 1);
      expect(tester.getRect(composer), composerRect);
    });

    testWidgets("a status page of another kind cross-fades in; one whose content changes stays put", (tester) async {
      final starts = BehaviorSubject<LocalBridgeStartupState>.seeded(LocalBridgeStartupState.starting);
      addTearDown(starts.close);
      whenListen(startup, starts, initialState: starts.value);
      final retry = find.text("Retry");
      final start = find.text("Start the bridge");
      await pumpHome(tester: tester, state: const ProjectListState.loading(), updates: updates.stream);
      final running = tester.state(loader);

      // The load turns into a launch of this computer's bridge: the same page.
      await land(tester: tester, state: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: false));
      expect(tester.state(loader), same(running));
      expect(opacityOf(tester: tester, finder: loader), 1);

      // The launch stops, so recovery cross-fades in over the loader.
      starts.add(LocalBridgeStartupState.settled);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(opacityOf(tester: tester, finder: loader), inExclusiveRange(0, 1));
      expect(opacityOf(tester: tester, finder: start), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(loader, findsNothing);

      await land(
        tester: tester,
        state: const ProjectListState.failed(reason: RemoteFailureReason.networkDown),
      );
      await tester.pump(const Duration(milliseconds: 110));
      expect(opacityOf(tester: tester, finder: start), inExclusiveRange(0, 1));
      expect(opacityOf(tester: tester, finder: retry), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(start, findsNothing);

      // Another failure only changes what the page says.
      await land(
        tester: tester,
        state: const ProjectListState.failed(reason: RemoteFailureReason.serverRejected),
      );
      expect(retry, findsOneWidget);
      expect(opacityOf(tester: tester, finder: retry), 1);

      await land(tester: tester, state: const ProjectListState.loading());
      await tester.pump(const Duration(milliseconds: 110));
      expect(opacityOf(tester: tester, finder: retry), inExclusiveRange(0, 1));
      expect(opacityOf(tester: tester, finder: loader), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(retry, findsNothing);
      expect(opacityOf(tester: tester, finder: loader), 1);
    });

    testWidgets("the loader holds until the list names the home's project, then fades into its composer", (
      tester,
    ) async {
      const other = ProjectSummary(id: "two", name: "api", path: "/two", time: null);
      final lists = StreamController<AllSessionsState>();
      addTearDown(lists.close);
      whenListen(sessions, lists.stream, initialState: _list(defaultProjectId: project.id));
      await pumpReadyHome(tester: tester);
      final composerRect = tester.getRect(composer);

      // The next computer has no project for new sessions until its sessions
      // load, after its projects.
      lists.add(_list(defaultProjectId: null, isLoading: true));
      await land(tester: tester, state: const ProjectListState.loading());
      await tester.pump(const Duration(milliseconds: 230));
      final running = tester.state(loader);
      await land(tester: tester, state: ready);
      await tester.pump(const Duration(milliseconds: 230));
      expect(tester.state(loader), same(running));
      expect(opacityOf(tester: tester, finder: loader), 1);
      expect(find.byType(DesktopHomeStart), findsNothing);

      lists.add(_list(defaultProjectId: project.id, isLoading: true));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(opacityOf(tester: tester, finder: loader), inExclusiveRange(0, 1));
      expect(opacityOf(tester: tester, finder: composer), inExclusiveRange(0, 1));
      expect(find.byKey(const Key("desktop-home-waiting")), findsNothing);
      await tester.pump(const Duration(milliseconds: 120));
      expect(loader, findsNothing);
      expect(opacityOf(tester: tester, finder: composer), 1);
      expect(tester.getRect(composer), composerRect);

      // A project added later loads without taking the home back to the loader.
      lists.add(_list(defaultProjectId: null, isLoading: true));
      await land(
        tester: tester,
        state: const ProjectListState.loaded(
          projects: [project, other],
          folderProjects: [project, other],
          scratchProject: null,
        ),
      );
      await tester.pump(const Duration(milliseconds: 230));
      expect(loader, findsNothing);
      expect(opacityOf(tester: tester, finder: composer), 1);
      expect(tester.widget<NewSessionView>(find.byType(NewSessionView)).projectId, project.id);
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

    _MockNewSessionCubit newSessionCubit({
      required Stream<NewSessionState> states,
      NewSessionState initialState = _composing,
      ProjectKind projectKind = ProjectKind.folder,
    }) {
      final cubit = _MockNewSessionCubit();
      whenListen(cubit, states, initialState: initialState);
      when(() => cubit.needsHarnessDiscovery).thenReturn(false);
      when(() => cubit.hasNoHarnesses).thenReturn(false);
      when(cubit.readDedicatedWorktreePreference).thenAnswer((_) async => true);
      when(() => cubit.canSubmit).thenReturn(true);
      when(() => cubit.canRefreshOptions).thenReturn(false);
      when(() => cubit.composerPresentation).thenReturn(const NewSessionComposerReady());
      when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
      when(() => cubit.projectKind).thenReturn(projectKind);
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

      /// Each composer's cubit in the order they are built; otherwise every
      /// composer reads [states].
      List<NewSessionCubit>? cubits,
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
                return cubits?.removeAt(0) ?? newSessionCubit(states: states);
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

    testWidgets("the worktree row opens and folds as the project changes, so the composer glides", (tester) async {
      const scratch = ProjectSummary(
        id: "scratch",
        name: null,
        path: "/scratch",
        time: null,
        kind: ProjectKind.scratch,
      );
      final oneAnswers = StreamController<NewSessionState>();
      addTearDown(oneAnswers.close);
      final checking = _composingWith(capability: NewSessionProjectWorktreeCapability.loading);
      await pumpStart(
        tester: tester,
        list: _list(defaultProjectId: "one"),
        projects: const [one, scratch],
        cubits: [
          newSessionCubit(states: const Stream.empty()),
          // The bridge's check never answers: No project needs none.
          newSessionCubit(states: const Stream.empty(), initialState: checking, projectKind: ProjectKind.scratch),
          newSessionCubit(states: oneAnswers.stream, initialState: checking),
        ],
      );
      // While the panes cross-fade the composer picked is the last one.
      final options = find.byKey(const Key("new_session_options")).last;
      double optionsHeight() => tester.getSize(options).height;
      double composerTop() => tester.getTopLeft(find.byType(PromptInput).last).dy;
      void select(String projectId) => tester
          .widget<NewSessionView>(find.byType(NewSessionView))
          .onProjectSelected
          ?.call(projectId: projectId, projectName: projectId);
      Future<void> pick(String projectId) async {
        select(projectId);
        await tester.pump();
        await crossfade(tester);
      }

      void expectNothingInTheRoom() {
        expect(find.descendant(of: options, matching: find.byType(PregoShimmer)), findsNothing);
        expect(find.descendant(of: options, matching: find.byType(PregoSwitch)), findsNothing);
      }

      // The first build shows the row's room at once rather than opening it.
      final rowHeight = optionsHeight();
      final withRow = composerTop();
      expect(rowHeight, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(optionsHeight(), rowHeight);
      expect(composerTop(), withRow);
      expect(find.byType(PregoSwitch), findsOneWidget);

      // No project never has the row, so the room it is left starts where it
      // was, then folds as it fades without waiting for the bridge's check.
      select("scratch");
      await tester.pump();
      expect(optionsHeight(), rowHeight);
      expect(composerTop(), withRow);
      expectNothingInTheRoom();
      // The next frame starts the fold.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(optionsHeight(), allOf(greaterThan(0), lessThan(rowHeight)));
      expectNothingInTheRoom();
      final foldingTop = composerTop();
      await tester.pump(const Duration(milliseconds: 200));
      expect(optionsHeight(), 0);
      expectNothingInTheRoom();
      final withoutRow = composerTop();
      expect(withoutRow, isNot(withRow));
      expect(foldingTop, inExclusiveRange(math.min(withRow, withoutRow), math.max(withRow, withoutRow)));

      // Back in a project that supports worktrees, the composer starts where
      // No project left it and the row opens as it fades in.
      await pick("one");
      expect(optionsHeight(), 0);
      expect(composerTop(), withoutRow);
      oneAnswers.add(_composingWith(capability: NewSessionProjectWorktreeCapability.supported));
      // The answer lands, then the frame it builds starts the transition.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(optionsHeight(), allOf(greaterThan(0), lessThan(rowHeight)));
      expect(composerTop(), inExclusiveRange(math.min(withRow, withoutRow), math.max(withRow, withoutRow)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(optionsHeight(), rowHeight);
      expect(composerTop(), withRow);
      expect(find.byType(PregoSwitch), findsOneWidget);
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

class _MockPluginService() extends Mock implements NewSessionPluginService;

class _MockOptionsService() extends Mock implements NewSessionOptionsService;

class _MockAllSessionsCubit() extends MockCubit<AllSessionsState> implements AllSessionsCubit;

/// The sidebar's list as the home reads it: only its filter, default and
/// loading matter here.
AllSessionsState _list({String? projectId, required String? defaultProjectId, bool isLoading = false}) =>
    AllSessionsState(
      projectId: projectId,
      query: "",
      quickFilter: SessionListQuickFilter.all,
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

NewSessionState _composingWith({required NewSessionProjectWorktreeCapability capability}) => NewSessionState.composing(
  config: NewSessionComposeConfig(
    availablePlugins: const [],
    selectedPlugin: null,
    options: const NewSessionOptionsLoadState.unsupported(),
    backendScope: const NewSessionBackendScope.verified(bridgeId: null),
    isPluginDiscoveryInFlight: false,
    projectWorktreeCapability: capability,
  ),
  phase: const NewSessionPhase.idle(),
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
