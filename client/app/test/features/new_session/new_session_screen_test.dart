import "dart:async";
import "dart:math" as math;
import "dart:typed_data";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/gestures.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/sent_bubble_landing.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_discovery_snapshot.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/repositories/plugin_preference_repository.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/features/session_detail/widgets/session_detail_composer_controls.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class MockComposerAttachmentDispatcher() extends Mock implements ComposerAttachmentDispatcher;

class MockImageClipboard() extends Mock implements ImageClipboard;

class _MockPluginManagementService() extends Mock implements PluginManagementService;

class _MockUrlLauncher() extends Mock implements UrlLauncher;

class MockPluginRepository() extends Mock implements PluginRepository;

class MockPluginPreferenceRepository() extends Mock implements PluginPreferenceRepository;

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

class _MockMessageImageRepository() extends Mock implements MessageImageRepository;

class _MockImageSaver() extends Mock implements ImageSaver;

class _MockImageSharer() extends Mock implements ImageSharer;

final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x62,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

AgentInfo _testAgent({required String name, required String description, required String? variant}) {
  return AgentInfo(
    name: name,
    description: description,
    model: AgentModel(providerID: "anthropic", modelID: "claude-3-5-sonnet", variant: variant),
    mode: AgentMode.primary,
  );
}

SessionOptionsCatalog _testSessionOptionsCatalog() => SessionOptionsCatalog(
  // Two agents, so the composer shows the agent entry these tests look for.
  agents: [
    _testAgent(name: "coder", description: "A coding assistant", variant: "xhigh"),
    _testAgent(name: "reviewer", description: "A review assistant", variant: null),
  ],
  providers: testProviderListResponse().items,
  providersConnectedOnly: testProviderListResponse().connectedOnly,
  commands: const [],
  lastUsedPromptDefaults: null,
);

Finder _pickerMenuItem(String label) => find.descendant(
  of: find.byType(SingleChildScrollView),
  matching: find.widgetWithText(InkWell, label),
);

/// The harness row for [pluginId] inside the open harness menu.
Finder _harnessRow(String pluginId) => find.byKey(Key("new_session_plugin_$pluginId"));

/// The tappable surface of a harness row — null [InkWell.onTap] is how a row
/// that cannot be picked reports itself.
InkWell _harnessRowInk(WidgetTester tester, String pluginId) =>
    tester.widget<InkWell>(find.descendant(of: _harnessRow(pluginId), matching: find.byType(InkWell)));

/// Opens the harness menu, which is where the pickable harnesses live.
Future<void> openHarnessMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key("new_session_plugin_trigger")));
  await tester.pumpAndSettle();
}

/// Dismisses the harness menu through its barrier. Picking a row closes the
/// menu on its own; a row that cannot be picked leaves it standing.
Future<void> closeHarnessMenu(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

Widget _buildApp({
  bool useHarnessFlow = false,
  ThemeMode themeMode = ThemeMode.light,
  GoRouterWidgetBuilder? sessionDetailBuilder,
}) {
  final router = GoRouter(
    initialLocation: "/sessions/new?project=project-1",
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
        routes: [
          GoRoute(
            path: "sessions/new",
            builder: (context, state) => NewSessionScreen(
              projectId: state.uri.queryParameters["project"],
              projectName: "Project One",
              entry: const NewSessionEntry.platform(),
            ),
          ),
        ],
      ),
      if (useHarnessFlow)
        buildHarnessSettingsRoute()
      else
        GoRoute(
          path: "/settings/harnesses",
          builder: (context, state) => const Material(child: Text("harnesses-settings")),
        ),
      GoRoute(
        path: "/sessions/:projectId/:sessionId",
        builder:
            sessionDetailBuilder ??
            (context, state) {
              return Material(
                child: Column(
                  children: [
                    Text("session-detail:${state.pathParameters['sessionId']}"),
                    Text("uri:${state.uri}"),
                    Text("canPop=${GoRouter.of(context).canPop()}"),
                  ],
                ),
              );
            },
      ),
    ],
  );

  final projectList = _MockProjectListCubit();
  final projects = [
    testProjectSummary(id: "project-1", name: "Project One"),
    testProjectSummary(id: "project-2", name: "Project Two"),
  ];
  whenListen(
    projectList,
    const Stream<ProjectListState>.empty(),
    initialState: ProjectListState.loaded(projects: projects, folderProjects: projects, scratchProject: null),
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider<ConnectionOverlayCubit>(create: (_) => StubConnectionOverlayCubit()),
      BlocProvider<ChatInputModeCubit>(create: (_) => StubChatInputModeCubit()),
      // The session scope's live project list, above every signed-in route.
      BlocProvider<ProjectListCubit>.value(value: projectList),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// The composer rests in its hold-to-talk pill (no text field) until the
/// keyboard button switches it to the typing layout and focuses the field.
Future<void> enterTypingMode(WidgetTester tester) async {
  await tester.tap(find.byIcon(TablerRegular.keyboard));
  await tester.pumpAndSettle();
}

/// Types a prompt and sends it. The pump in between lets the composer rebuild
/// around the new text — send only accepts taps once the field has content.
Future<void> enterTextAndSend({required WidgetTester tester, required String text}) async {
  await tester.enterText(find.byType(EditableText), text);
  await tester.pump();
  await tester.tap(find.byIcon(TablerRegular.arrow_up));
}

void main() {
  late MockSessionRepository sessionService;
  late MockSessionRepository sessionRepository;
  late MockPluginRepository pluginRepository;
  late MockPluginPreferenceRepository pluginPreferenceRepository;
  late MockConnectionService connectionService;
  late BehaviorSubject<ConnectionStatus> connectionStatus;
  late MockProjectRepository projectRepository;
  late MockVoiceTranscriptionService voiceTranscriptionService;
  late MockVoiceTranscriptionSession voiceSession;
  late MockComposerAttachmentDispatcher attachmentDispatcher;
  late MockImageClipboard imageClipboard;
  late ComposerDraftRepository composerDraftRepository;
  late MockProductAnalyticsService productAnalyticsService;

  setUpAll(registerAllFallbackValues);

  // Composer pickers force PregoAnchorMenu's flat cue path on every platform,
  // so the menu rows are Material InkWells.
  setUp(() async {
    KeyboardVisibilityTesting.setVisibilityForTesting(false);
    await GetIt.instance.reset();
    sessionService = MockSessionRepository();
    sessionRepository = MockSessionRepository();
    pluginRepository = MockPluginRepository();
    pluginPreferenceRepository = MockPluginPreferenceRepository();
    connectionService = MockConnectionService();
    connectionStatus = BehaviorSubject.seeded(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
        health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
      ),
    );
    projectRepository = MockProjectRepository();
    voiceTranscriptionService = MockVoiceTranscriptionService();
    attachmentDispatcher = MockComposerAttachmentDispatcher();
    imageClipboard = MockImageClipboard();
    when(imageClipboard.readImage).thenAnswer((_) async => null);
    composerDraftRepository = inMemoryComposerDraftRepository();
    productAnalyticsService = MockProductAnalyticsService();
    stubProductAnalyticsService(service: productAnalyticsService);

    when(() => connectionService.status).thenAnswer((_) => connectionStatus.stream);
    when(() => connectionService.currentStatus).thenAnswer((_) => connectionStatus.value);

    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: const [
            PluginMetadata(
              id: "plugin-1",
              displayName: "Plugin One",
              isDefault: true,
              state: PluginLifecycleState.ready,
              actionHint: null,
            ),
          ],
        ),
      ),
    );

    when(
      () => sessionService.listAgents(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        Agents(
          agents: [
            _testAgent(name: "coder", description: "A coding assistant", variant: "xhigh"),
            _testAgent(name: "reviewer", description: "A review assistant", variant: null),
          ],
        ),
      ),
    );
    when(
      () => sessionService.listProviders(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(testProviderListResponse()),
    );
    when(
      () => sessionService.listCommands(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(const CommandListResponse(items: [])),
    );
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        mode: any(named: "mode"),
      ),
    ).thenAnswer((invocation) async {
      final projectId = invocation.namedArguments[#projectId]! as String;
      final pluginId = invocation.namedArguments[#pluginId]! as String;
      final (agents, providers, commands) = await (
        sessionService.listAgents(projectId: projectId, pluginId: pluginId),
        sessionService.listProviders(projectId: projectId, pluginId: pluginId),
        sessionService.listCommands(projectId: projectId, pluginId: pluginId),
      ).wait;
      return switch ((agents, providers, commands)) {
        (
          SuccessResponse(data: final agentData),
          SuccessResponse(data: final providerData),
          SuccessResponse(data: final commandData),
        ) =>
          SessionOptionsRepositoryAvailable(
            isStale: false,
            catalog: SessionOptionsCatalog(
              agents: agentData.agents,
              providers: providerData.items,
              providersConnectedOnly: providerData.connectedOnly,
              commands: commandData.items,
              lastUsedPromptDefaults: null,
            ),
          ),
        (ErrorResponse(:final error), _, _) => SessionOptionsRepositoryFailure(error: error),
        (_, ErrorResponse(:final error), _) => SessionOptionsRepositoryFailure(error: error),
        (_, _, ErrorResponse(:final error)) => SessionOptionsRepositoryFailure(error: error),
      };
    });
    when(
      () => sessionRepository.loadLegacySessionOptions(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer((invocation) async {
      final projectId = invocation.namedArguments[#projectId]! as String;
      final pluginId = invocation.namedArguments[#pluginId]! as String;
      final (agents, providers, commands) = await (
        sessionService.listAgents(projectId: projectId, pluginId: pluginId),
        sessionService.listProviders(projectId: projectId, pluginId: pluginId),
        sessionService.listCommands(projectId: projectId, pluginId: pluginId),
      ).wait;
      return switch ((agents, providers, commands)) {
        (
          SuccessResponse(data: final agentData),
          SuccessResponse(data: final providerData),
          SuccessResponse(data: final commandData),
        ) =>
          LegacySessionOptionsRepositoryAvailable(
            catalog: SessionOptionsCatalog(
              agents: agentData.agents,
              providers: providerData.items,
              providersConnectedOnly: providerData.connectedOnly,
              commands: commandData.items,
              lastUsedPromptDefaults: null,
            ),
          ),
        (ErrorResponse(:final error), _, _) => LegacySessionOptionsRepositoryFailure(
          errors: [LegacySessionOptionError(source: LegacySessionOptionSource.agents, error: error)],
        ),
        (_, ErrorResponse(:final error), _) => LegacySessionOptionsRepositoryFailure(
          errors: [LegacySessionOptionError(source: LegacySessionOptionSource.providers, error: error)],
        ),
        (_, _, ErrorResponse(:final error)) => LegacySessionOptionsRepositoryFailure(
          errors: [LegacySessionOptionError(source: LegacySessionOptionSource.commands, error: error)],
        ),
      };
    });
    when(
      () => projectRepository.getProject(projectId: any(named: "projectId")),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        const Project(
          id: "project-1",
          name: "Project One",
          path: "/project-one",
          time: null,
          supportsDedicatedWorktrees: true,
          voiceGlossaryKey: null,
        ),
      ),
    );

    final maxDurationReached = StreamController<void>.broadcast();
    addTearDown(maxDurationReached.close);
    voiceSession = stubVoiceTranscriptionService(
      service: voiceTranscriptionService,
      maxDurationStream: maxDurationReached.stream,
    );

    when(
      () => pluginPreferenceRepository.readPluginId(bridgeId: any(named: "bridgeId")),
    ).thenAnswer((_) async => null);
    when(
      () => pluginPreferenceRepository.writePluginId(
        bridgeId: any(named: "bridgeId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer((_) async {});

    GetIt.instance.registerSingleton<SessionRepository>(sessionService);
    GetIt.instance.registerSingleton<PluginRepository>(pluginRepository);
    GetIt.instance.registerSingleton<NewSessionPluginService>(
      NewSessionPluginService(
        pluginRepository: pluginRepository,
        pluginPreferenceRepository: pluginPreferenceRepository,
      ),
    );
    GetIt.instance.registerSingleton<NewSessionOptionsService>(
      NewSessionOptionsService(
        sessionRepository: sessionRepository,
      ),
    );
    GetIt.instance.registerSingleton<ConnectionService>(connectionService);
    GetIt.instance.registerSingleton<CatalogRescanService>(FakeCatalogRescanService());
    GetIt.instance.registerSingleton<ProjectRepository>(projectRepository);
    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
    GetIt.instance.registerSingleton<ComposerAttachmentDispatcher>(attachmentDispatcher);
    GetIt.instance.registerSingleton<ImageClipboard>(imageClipboard);
    GetIt.instance.registerSingleton<NewSessionSelectionTracker>(NewSessionSelectionTracker());
    GetIt.instance.registerSingleton<ComposerDraftRepository>(composerDraftRepository);
    GetIt.instance.registerSingleton<ProductAnalyticsService>(productAnalyticsService);
    GetIt.instance.registerSingleton<FeedbackPromptService>(FakeFeedbackPromptService());
    GetIt.instance.registerSingleton<SessionLaunchRepository>(inMemorySessionLaunchRepository());
    GetIt.instance.registerSingleton<DedicatedWorktreePreferenceStore>(FakeDedicatedWorktreePreferenceStore());
    GetIt.instance.registerSingleton<SessionLaunchService>(
      SessionLaunchService(
        sessionRepository: sessionService,
        launchRepository: GetIt.instance<SessionLaunchRepository>(),
        feedbackPromptService: GetIt.instance<FeedbackPromptService>(),
        productAnalyticsService: productAnalyticsService,
        selectionTracker: GetIt.instance<NewSessionSelectionTracker>(),
        authSession: FakeAuthSession(initialState: const AuthState.initial()),
      ),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await connectionStatus.close();
  });

  testWidgets("toolbar back pops the route while the Android keyboard is visible", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    KeyboardVisibilityTesting.setVisibilityForTesting(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();

    expect(find.byType(NewSessionScreen), findsNothing);
  });

  testWidgets("a sent dictation has a landing over the composer", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(SentBubbleLanding.of(context: tester.element(find.byType(PromptInput))), isNotNull);
  });

  testWidgets("the header names the project and switches to another one", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.text("What should we work on?"), findsOneWidget);
    await tester.tap(find.byKey(const Key("new_session_project")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Project Two"));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(NewSessionScreen)));
    expect(router.state.uri.toString(), "/sessions/new?project=project-2&name=Project+Two");
    // The replaced route keeps its page; the new project still gets its own cubit.
    verify(() => projectRepository.getProject(projectId: "project-2")).called(1);
  });

  testWidgets("the header stays where it is while the composer holds the keyboard", (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final project = find.byKey(const Key("new_session_project"));
    final before = tester.getRect(project);

    await enterTypingMode(tester);
    await tester.pumpAndSettle();
    expect(tester.getRect(project), before);
  });

  testWidgets("hides the worktree toggle while project capability loads", (tester) async {
    final projectResponse = Completer<ApiResponse<Project>>();
    when(
      () => projectRepository.getProject(projectId: any(named: "projectId")),
    ).thenAnswer((_) => projectResponse.future);

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    expect(find.byType(PregoSwitch), findsNothing);

    projectResponse.complete(
      ApiResponse.success(
        const Project(
          id: "project-1",
          name: "Project One",
          path: "/project-one",
          time: null,
          supportsDedicatedWorktrees: false,
          voiceGlossaryKey: null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets("blocks creation and retries when project capability is unavailable", (tester) async {
    var attempts = 0;
    when(
      () => projectRepository.getProject(projectId: any(named: "projectId")),
    ).thenAnswer((_) async {
      attempts++;
      return attempts == 1
          ? ApiResponse.error(ApiError.generic())
          : ApiResponse.success(
              const Project(
                id: "project-1",
                name: "Project One",
                path: "/project-one",
                time: null,
                supportsDedicatedWorktrees: true,
                voiceGlossaryKey: null,
              ),
            );
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    // The composer is replaced by a blocked notice: nothing can be typed or
    // sent until the project's worktree capability can be checked again.
    expect(find.byKey(const Key("new_session_project_unavailable")), findsOneWidget);
    expect(find.text(loc.newSessionProjectUnavailable), findsOneWidget);
    expect(find.byType(PromptInput), findsNothing);

    await tester.tap(find.byKey(const Key("session_harness_recheck")));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("new_session_project_unavailable")), findsNothing);
    expect(find.byType(PregoSwitch), findsOneWidget);
    expect(find.byType(PromptInput), findsOneWidget);
  });

  testWidgets("legacy bridge shows a Load action, stays typeable, and Load uses legacy routes", (tester) async {
    when(() => voiceTranscriptionService.start(session: voiceSession)).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession))
        .thenAnswer((_) async => afterRecordingResult(transcript: ""));
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: false,
          plugins: const [
            PluginMetadata(
              id: "plugin-1",
              displayName: "Plugin One",
              isDefault: true,
              state: PluginLifecycleState.ready,
              actionHint: null,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    expect(find.byKey(const Key("new_session_options_load")), findsOneWidget);
    expect(find.widgetWithText(PregoButtonsSolid, loc.newSessionOptionsLoad), findsOneWidget);
    expect(find.byType(PromptInput), findsOneWidget);
    expect(find.byType(PregoPickerButton), findsNothing);
    verifyNever(
      () => sessionRepository.loadSessionOptions(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        mode: any(named: "mode"),
      ),
    );

    final restingComposerHeight = tester.getSize(find.byType(PromptInput)).height;
    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(loc.voiceReleaseToSend), findsOneWidget);
    expect(tester.getSize(find.byType(PromptInput)).height, closeTo(restingComposerHeight, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("new_session_options_load")));
    await tester.pumpAndSettle();

    verify(() => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-1")).called(1);
    verify(() => sessionService.listProviders(projectId: "project-1", pluginId: "plugin-1")).called(1);
    verify(() => sessionService.listCommands(projectId: "project-1", pluginId: "plugin-1")).called(1);
    expect(find.widgetWithText(PregoPickerButton, "coder"), findsOneWidget);
  });

  testWidgets("unavailable dynamic load keeps creation available with backend defaults", (tester) async {
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: SessionOptionsRequestMode.dynamic,
      ),
    ).thenAnswer((_) async => const SessionOptionsRepositoryCacheUnavailable());
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(testSession(id: "session-cache-miss")));

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;
    expect(find.widgetWithText(PregoButtonsSolid, loc.newSessionOptionsRetry), findsOneWidget);

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "use backend defaults");
    await tester.pumpAndSettle();

    verify(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: "project-1",
        pluginId: "plugin-1",
        text: "use backend defaults",
        agent: null,
        model: null,
        variant: null,
        fastMode: false,
        command: null,
        dedicatedWorktree: true,
      ),
    ).called(1);
  });

  testWidgets("authentication required on first load shows a login card with no popup", (tester) async {
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: any(named: "mode"),
      ),
    ).thenAnswer((invocation) async {
      final mode = invocation.namedArguments[#mode]! as SessionOptionsRequestMode;
      return mode == SessionOptionsRequestMode.dynamic
          ? const SessionOptionsRepositoryAuthenticationRequired(
              actionHint: "Run the harness locally and use /login.",
            )
          : SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false);
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    // The login card takes the composer's place; nothing was usable before,
    // so the popup — reserved for a harness that logged out mid-session —
    // must not show on this first load.
    expect(find.byKey(const Key("new_session_login_required")), findsOneWidget);
    expect(find.text(loc.newSessionAuthenticationRequiredTitle("Plugin One")), findsOneWidget);
    expect(find.text("Run the harness locally and use /login."), findsOneWidget);
    expect(find.byType(PromptInput), findsNothing);
    expect(find.byType(PregoPopupAlertsNotifications), findsNothing);

    await tester.tap(find.byKey(const Key("session_harness_recheck")));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("new_session_login_required")), findsNothing);
    expect(find.widgetWithText(PregoPickerButton, "coder"), findsOneWidget);
    expect(find.byType(PromptInput), findsOneWidget);
  });

  testWidgets("authentication newly required after usable options shows the login card and a popup", (
    tester,
  ) async {
    var loadCalls = 0;
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: any(named: "mode"),
      ),
    ).thenAnswer((_) async {
      loadCalls++;
      return loadCalls == 1
          ? SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: true)
          : const SessionOptionsRepositoryAuthenticationRequired(
              actionHint: "Run the harness locally and use /login.",
            );
    });

    // The stale cache shows at once; its background refresh finds the harness
    // logged out since it was last checked.
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;
    expect(loadCalls, 2);

    expect(find.byKey(const Key("new_session_login_required")), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key("new_session_login_required")),
        matching: find.text(loc.newSessionAuthenticationRequiredTitle("Plugin One")),
      ),
      findsOneWidget,
    );
    final alert = find.widgetWithText(
      PregoPopupAlertsNotifications,
      loc.newSessionAuthenticationRequiredTitle("Plugin One"),
    );
    expect(alert, findsOneWidget);
    expect(
      find.descendant(of: alert, matching: find.text("Run the harness locally and use /login.")),
      findsOneWidget,
    );
  });

  testWidgets("prefills the bridge-stored selection from the last successful creation", (tester) async {
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: any(named: "mode"),
      ),
    ).thenAnswer(
      (_) async => SessionOptionsRepositoryAvailable(
        isStale: false,
        catalog: SessionOptionsCatalog(
          agents: [
            _testAgent(name: "coder", description: "A coding assistant", variant: "xhigh"),
            _testAgent(name: "review", description: "A reviewing assistant", variant: "xhigh"),
          ],
          providers: testProviderListResponse().items,
          providersConnectedOnly: false,
          commands: const [],
          lastUsedPromptDefaults: const SessionPromptDefaults(
            agent: "review",
            model: AgentModel(
              providerID: "anthropic",
              modelID: "claude-3-5-sonnet",
              variant: "xhigh",
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PregoPickerButton, "review"), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);
  });

  testWidgets("shows variant picker when selected agent has a variant", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(PregoPickerButton, "xhigh"));
    await tester.pumpAndSettle();

    // Tapping the variant pill opens a popup listing the model's variants.
    expect(_pickerMenuItem("xhigh"), findsOneWidget);

    await tester.tap(_pickerMenuItem("xhigh"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);
  });

  testWidgets("renders bridge order with generic degraded and blocked presentation", (tester) async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: const [
            PluginMetadata(
              id: "failed-id",
              displayName: "First Tool",
              isDefault: false,
              state: PluginLifecycleState.failed,
              actionHint: "Restart the bridge to retry.",
            ),
            PluginMetadata(
              id: "codex",
              displayName: "Second Tool",
              isDefault: true,
              state: PluginLifecycleState.degraded,
              actionHint: "Check the bridge console.",
            ),
            PluginMetadata(
              id: "cursor",
              displayName: "Third Tool",
              isDefault: false,
              state: PluginLifecycleState.unavailable,
              actionHint: "Make this tool available on the bridge.",
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(NewSessionPluginChooser), findsOneWidget);
    await openHarnessMenu(tester);

    expect(tester.getTopLeft(_harnessRow("failed-id")).dy, lessThan(tester.getTopLeft(_harnessRow("codex")).dy));
    expect(tester.getTopLeft(_harnessRow("codex")).dy, lessThan(tester.getTopLeft(_harnessRow("cursor")).dy));
    expect(find.text("Needs attention"), findsOneWidget);
    expect(find.text("Failed"), findsOneWidget);
    expect(find.text("Unavailable"), findsOneWidget);
    // Codex is the picked harness, so its mark shows twice: on the trigger and
    // in its row. The plug stands in for the harness this build has no artwork
    // for, which is only in the menu.
    expect(findBrandLogo("codex"), findsNWidgets(2));
    expect(findBrandLogo("cursor"), findsOneWidget);
    expect(find.byIcon(TablerRegular.plug), findsOneWidget);

    // A row that can't be picked dims as a whole, artwork included — the marks
    // carry their own colours, so a tint alone would leave them reading active.
    double rowOpacity(String pluginId) => tester
        .widget<Opacity>(find.descendant(of: _harnessRow(pluginId), matching: find.byType(Opacity)).first)
        .opacity;
    expect(rowOpacity("cursor"), lessThan(1.0));
    expect(rowOpacity("codex"), 1.0);

    expect(_harnessRowInk(tester, "failed-id").onTap, isNull);
    expect(_harnessRowInk(tester, "cursor").onTap, isNull);
    expect(_harnessRowInk(tester, "codex").onTap, isNotNull);
    expect(find.text("failed-id"), findsNothing);
    expect(find.text("codex"), findsNothing);
  });

  testWidgets("names the picked harness on the trigger and checks its row", (tester) async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: const [
            PluginMetadata(
              id: "other-id",
              displayName: "Other Tool",
              isDefault: false,
              state: PluginLifecycleState.ready,
              actionHint: null,
            ),
            PluginMetadata(
              id: "degraded-id",
              displayName: "Selected Tool",
              isDefault: true,
              state: PluginLifecycleState.degraded,
              actionHint: "Check the bridge console.",
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final trigger = find.byKey(const Key("new_session_plugin_trigger"));
    expect(find.descendant(of: trigger, matching: find.text("Selected Tool")), findsOneWidget);

    await openHarnessMenu(tester);

    expect(
      find.descendant(of: _harnessRow("degraded-id"), matching: find.byIcon(TablerRegular.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _harnessRow("other-id"), matching: find.byIcon(TablerRegular.check)),
      findsNothing,
    );
    expect(find.descendant(of: _harnessRow("degraded-id"), matching: find.text("Needs attention")), findsOneWidget);
  });

  testWidgets("opens harness settings from the menu header", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await openHarnessMenu(tester);

    await tester.tap(find.byKey(const Key("new_session_harness_settings")));
    await tester.pumpAndSettle();

    expect(find.text("harnesses-settings"), findsOneWidget);
  });

  for (final closeFromDetail in [false, true]) {
    testWidgets("harness modal X retains the same New Session and draft (detail: $closeFromDetail)", (tester) async {
      final service = _MockPluginManagementService();
      when(service.onDispose).thenAnswer((_) async {});
      final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
        const PluginManagementLoadResult.supported(
          response: PluginManagementResponse(
            snapshotToken: "navigation-test",
            bridgeId: "bridge-1",
            defaultPluginId: "test-harness",
            defaultIdleTimeoutMins: 10,
            plugins: [],
          ),
          refreshError: null,
        ),
      );
      when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
      final installs = BehaviorSubject<Map<String, PluginInstallState>>.seeded(const {});
      addTearDown(installs.close);
      when(() => service.installStates).thenAnswer((_) => installs.stream);
      final challenges = BehaviorSubject<Map<String, PluginAuthenticationChallenge>>.seeded(const {});
      final browserStates = BehaviorSubject<Map<String, PluginAuthenticationBrowserState>>.seeded(const {});
      addTearDown(challenges.close);
      addTearDown(browserStates.close);
      when(() => service.authenticationChallenges).thenAnswer((_) => challenges.stream);
      when(() => service.authenticationBrowserStates).thenAnswer((_) => browserStates.stream);
      when(() => service.authenticationTerminal)
          .thenAnswer((_) => const Stream<PluginAuthenticationTerminalUpdate>.empty());
      GetIt.instance.registerSingleton<PluginManagementService>(service);
      GetIt.instance.registerSingleton<UrlLauncher>(_MockUrlLauncher());
      addTearDown(snapshots.close);
      await tester.pumpWidget(_buildApp(useHarnessFlow: true));
      await tester.pumpAndSettle();
      await enterTypingMode(tester);
      await tester.enterText(find.byType(EditableText), "half-written idea");
      await tester.pump();
      final opener = tester.element(find.byType(NewSessionScreen));
      final composer = tester.element(find.byType(PromptInput));
      final newSessionCubit = composer.read<NewSessionCubit>();
      await openHarnessMenu(tester);
      await tester.tap(find.byKey(const Key("new_session_harness_settings")));
      await tester.pumpAndSettle();
      final overview = tester.element(find.byType(HarnessesSettingsView));
      final harnessCubit = overview.read<PluginManagementCubit>();
      if (closeFromDetail) {
        unawaited(
          overview.pushRoute(
            const AppRoute.settingsHarnessDetail(
              pluginId: "removed",
              presentation: HarnessSettingsPresentation.modal,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.element(find.byType(HarnessSettingsDetailView)).read<PluginManagementCubit>(),
          same(harnessCubit),
        );
      }
      await tester.tap(find.bySemanticsLabel("Close settings"));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(NewSessionScreen)), same(opener));
      expect(tester.element(find.byType(PromptInput)), same(composer));
      expect(tester.element(find.byType(PromptInput)).read<NewSessionCubit>(), same(newSessionCubit));
      expect(newSessionCubit.composerDraft, ComposerDraft.typed(text: "half-written idea"));
      expect(find.text("half-written idea"), findsOneWidget);
      // Stream cancellation completes outside the widget-test clock.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(harnessCubit.isClosed, isTrue);
      expect(snapshots.hasListener, isFalse);
    });
  }

  testWidgets("keeps the harness settings icon layout-safe on hover", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await openHarnessMenu(tester);

    final settings = find.byKey(const Key("new_session_harness_settings"));
    final loc = AppLocalizations.of(tester.element(settings))!;
    expect(
      tester.getSemantics(settings),
      matchesSemantics(
        label: loc.newSessionHarnessSettings,
        isButton: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(settings)));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });

  testWidgets("keeps model and variant controls available when no agents load", (tester) async {
    when(
      () => sessionService.listAgents(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(const Agents(agents: [])));

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerRegular.robot), findsNothing);
    expect(find.widgetWithText(PregoPickerButton, "Claude 3.5 Sonnet"), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);
  });

  testWidgets("scrolls plugin and worktree options while keeping the composer pinned", (tester) async {
    // Tall enough for the header above the options.
    await tester.binding.setSurfaceSize(const Size(700, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: [
            for (var index = 0; index < 8; index++)
              PluginMetadata(
                id: "plugin-$index",
                displayName: "Plugin $index",
                isDefault: index == 0,
                state: PluginLifecycleState.ready,
                actionHint: "Plugin $index action hint",
              ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final optionsScroll = find.byKey(const Key("new_session_options_scroll"));
    expect(optionsScroll, findsOneWidget);
    expect(
      find.descendant(of: optionsScroll, matching: find.byType(NewSessionPluginChooser)),
      findsOneWidget,
    );
    expect(find.descendant(of: optionsScroll, matching: find.byType(PregoSwitch)), findsOneWidget);
    expect(find.descendant(of: optionsScroll, matching: find.byType(PromptInput)), findsNothing);
    expect(tester.takeException(), isNull);

    final composerTop = tester.getTopLeft(find.byType(PromptInput)).dy;

    await tester.drag(optionsScroll, const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(PromptInput)).dy, closeTo(composerTop, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets("keeps a multiline composer visible in a short viewport", (tester) async {
    tester.view.physicalSize = const Size(700, 300);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    await tester.enterText(find.byType(EditableText), "one\ntwo\nthree\nfour\nfive");
    await tester.pumpAndSettle();

    final screenBottom = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final composerRect = tester.getRect(find.byType(PromptInput));
    final inputRect = tester.getRect(find.byType(EditableText));

    expect(composerRect.top, greaterThanOrEqualTo(0));
    expect(composerRect.bottom, closeTo(screenBottom, 0.01));
    expect(inputRect.top, greaterThanOrEqualTo(0));
    expect(inputRect.bottom, lessThanOrEqualTo(screenBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets("hides the dedicated worktree toggle when the project does not support it", (tester) async {
    when(
      () => projectRepository.getProject(projectId: any(named: "projectId")),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        const Project(
          id: "project-1",
          name: "Plain folder",
          path: "/plain-folder",
          time: null,
          supportsDedicatedWorktrees: false,
          voiceGlossaryKey: null,
        ),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;
    expect(find.text(loc.newSessionDedicatedWorkspace), findsNothing);
  });

  testWidgets("keeps chooser usable while clearing and reloading composer data", (tester) async {
    const toolA = PluginMetadata(
      id: "tool-a",
      displayName: "Tool A",
      isDefault: true,
      state: PluginLifecycleState.ready,
      actionHint: null,
    );
    const toolB = PluginMetadata(
      id: "tool-b",
      displayName: "Tool B",
      isDefault: false,
      state: PluginLifecycleState.degraded,
      actionHint: "Check the bridge console.",
    );
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: const [toolA, toolB],
        ),
      ),
    );
    final toolBAgents = Completer<ApiResponse<Agents>>();
    when(
      () => sessionService.listAgents(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer((invocation) {
      final pluginId = invocation.namedArguments[#pluginId] as String;
      if (pluginId == "tool-b") return toolBAgents.future;
      return Future.value(
        ApiResponse.success(
          Agents(
            agents: [
              _testAgent(name: "coder", description: "Coder", variant: "xhigh"),
              _testAgent(name: "reviewer", description: "Reviewer", variant: null),
            ],
          ),
        ),
      );
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PregoPickerButton, "coder"), findsOneWidget);

    await openHarnessMenu(tester);
    await tester.tap(_harnessRow("tool-b"));
    await tester.pump();

    expect(find.widgetWithText(PregoPickerButton, "coder"), findsNothing);

    // tool-b's options were still pending; let them settle before reopening
    // the menu, since the composer header's shimmer would otherwise animate
    // indefinitely and pumpAndSettle would never return.
    toolBAgents.complete(ApiResponse.success(const Agents(agents: [])));
    await tester.pumpAndSettle();

    await openHarnessMenu(tester);
    expect(_harnessRowInk(tester, "tool-a").onTap, isNotNull);

    await tester.tap(_harnessRow("tool-a"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PregoPickerButton, "coder"), findsOneWidget);
    verifyNever(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    );
  });

  testWidgets("disables plugin selection only while reconnect discovery is in flight", (tester) async {
    const toolA = PluginMetadata(
      id: "tool-a",
      displayName: "Tool A",
      isDefault: true,
      state: PluginLifecycleState.ready,
      actionHint: null,
    );
    const toolB = PluginMetadata(
      id: "tool-b",
      displayName: "Tool B",
      isDefault: false,
      state: PluginLifecycleState.ready,
      actionHint: null,
    );
    final reconnectDiscovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
    var discoveryCalls = 0;
    when(pluginRepository.listPlugins).thenAnswer((_) {
      discoveryCalls++;
      if (discoveryCalls == 1) {
        return Future.value(
          ApiResponse.success(
            PluginDiscoverySnapshot(
              bridgeId: null,
              supportsSessionOptions: true,
              plugins: const [toolA, toolB],
            ),
          ),
        );
      }
      return reconnectDiscovery.future;
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    connectionStatus
      ..add(const ConnectionStatus.disconnected())
      ..add(
        const ConnectionStatus.connected(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
          health: HealthResponse(
            healthy: true,
            version: "test",
            filesystemAccessDegraded: false,
          ),
        ),
      );
    await tester.pump();
    await tester.pump();

    expect(discoveryCalls, 2);
    expect(tester.widget<NewSessionPluginChooser>(find.byType(NewSessionPluginChooser)).isSelectionEnabled, isFalse);
    await openHarnessMenu(tester);
    expect(_harnessRowInk(tester, "tool-b").onTap, isNull);
    await tester.tap(_harnessRow("tool-b"));
    await tester.pump();
    expect(
      find.descendant(of: _harnessRow("tool-a"), matching: find.byIcon(TablerRegular.check)),
      findsOneWidget,
    );
    verifyNever(() => sessionService.listAgents(projectId: "project-1", pluginId: "tool-b"));
    await closeHarnessMenu(tester);

    reconnectDiscovery.complete(
      ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: const [toolA, toolB],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<NewSessionPluginChooser>(find.byType(NewSessionPluginChooser)).isSelectionEnabled, isTrue);
    await openHarnessMenu(tester);
    expect(_harnessRowInk(tester, "tool-b").onTap, isNotNull);
    await tester.tap(_harnessRow("tool-b"));
    await tester.pumpAndSettle();

    await openHarnessMenu(tester);
    expect(
      find.descendant(of: _harnessRow("tool-b"), matching: find.byIcon(TablerRegular.check)),
      findsOneWidget,
    );
    verify(() => sessionService.listAgents(projectId: "project-1", pluginId: "tool-b")).called(1);
  });

  testWidgets("refresh discovery failure keeps prior context but disables backend actions", (tester) async {
    var discoveryCalls = 0;
    when(pluginRepository.listPlugins).thenAnswer((_) async {
      discoveryCalls++;
      if (discoveryCalls == 1) {
        return ApiResponse.success(
          PluginDiscoverySnapshot(
            bridgeId: null,
            supportsSessionOptions: true,
            plugins: const [
              PluginMetadata(
                id: "plugin-1",
                displayName: "Plugin One",
                isDefault: true,
                state: PluginLifecycleState.ready,
                actionHint: null,
              ),
            ],
          ),
        );
      }
      return ApiResponse.error(ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null));
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    connectionStatus
      ..add(const ConnectionStatus.disconnected())
      ..add(
        const ConnectionStatus.connected(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
          health: HealthResponse(
            healthy: true,
            version: "test",
            filesystemAccessDegraded: false,
          ),
        ),
      );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(NewSessionScreen));
    final loc = AppLocalizations.of(context)!;
    expect(find.text(loc.apiErrorServerRejected), findsOneWidget);
    expect(tester.widget<NewSessionPluginChooser>(find.byType(NewSessionPluginChooser)).isSelectionEnabled, isFalse);
    await openHarnessMenu(tester);
    expect(_harnessRow("plugin-1"), findsOneWidget);
    expect(_harnessRowInk(tester, "plugin-1").onTap, isNull);
    await closeHarnessMenu(tester);

    // The composer stays visible and typeable with the prior options, but the
    // invalidated backend scope keeps it from actually sending.
    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byType(QueuedMessageBubble), findsNothing);
    verifyNever(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    );
  });

  testWidgets("discovery failure shows localized error with no chooser or creation path", (tester) async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(NewSessionScreen));
    final loc = AppLocalizations.of(context)!;
    expect(find.text(loc.apiErrorServerRejected), findsOneWidget);
    expect(find.text(loc.newSessionCreationDuplicateWarning), findsNothing);
    expect(find.byKey(const Key("new_session_plugin_trigger")), findsNothing);
    expect(_harnessRow("plugin-1"), findsNothing);

    // The composer stays typeable, but with no verified backend scope there
    // is nothing routable to send to.
    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byType(QueuedMessageBubble), findsNothing);
    verifyNever(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    );
  });

  testWidgets("names the missing harness and hides unavailable controls", (tester) async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(bridgeId: null, supportsSessionOptions: true, plugins: const []),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    // A machine with no coding tool installed reports no harness at all. The
    // page has to name that rather than render blank or unusable controls.
    expect(find.text(loc.newSessionNoHarnessTitle), findsOneWidget);
    expect(find.text(loc.newSessionNoHarnessDescription), findsOneWidget);
    expect(find.byKey(const Key("new_session_plugin_trigger")), findsNothing);
    expect(find.text(loc.newSessionDedicatedWorkspace), findsNothing);
    expect(find.byKey(const Key("new_session_options_retry")), findsNothing);
    expect(find.byKey(const Key("new_session_options_load")), findsNothing);
    expect(find.byType(PromptInput), findsNothing);
  });

  testWidgets("restores the chooser and composer when reconnect finds a harness", (tester) async {
    var discoveryCalls = 0;
    when(pluginRepository.listPlugins).thenAnswer((_) async {
      discoveryCalls++;
      return ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: discoveryCalls == 1
              ? const []
              : const [
                  PluginMetadata(
                    id: "plugin-1",
                    displayName: "Plugin One",
                    isDefault: true,
                    state: PluginLifecycleState.ready,
                    actionHint: null,
                  ),
                ],
        ),
      );
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(discoveryCalls, 1);
    expect(find.byKey(const Key("new_session_no_harness_notice")), findsOneWidget);
    expect(find.byType(PromptInput), findsNothing);

    connectionStatus
      ..add(const ConnectionStatus.disconnected())
      ..add(
        const ConnectionStatus.connected(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
          health: HealthResponse(
            healthy: true,
            version: "test",
            filesystemAccessDegraded: false,
          ),
        ),
      );
    await tester.pumpAndSettle();

    expect(discoveryCalls, 2);
    expect(find.byKey(const Key("new_session_no_harness_notice")), findsNothing);
    expect(find.byType(NewSessionPluginChooser), findsOneWidget);
    expect(find.byType(PromptInput), findsOneWidget);
  });

  testWidgets("folds the composer away as the no-harness notice opens, and opens it again for a harness", (
    tester,
  ) async {
    var discoveryCalls = 0;
    when(pluginRepository.listPlugins).thenAnswer((_) async {
      discoveryCalls++;
      return ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: discoveryCalls == 1
              ? const []
              : const [
                  PluginMetadata(
                    id: "plugin-1",
                    displayName: "Plugin One",
                    isDefault: true,
                    state: PluginLifecycleState.ready,
                    actionHint: null,
                  ),
                ],
        ),
      );
    });
    final composer = find.byType(PromptInput);
    final notice = find.byKey(const Key("new_session_no_harness_notice"));

    /// The composer's top edge in each frame it shares with the notice.
    Future<List<double>> composerTopsBesideNotice() async {
      final tops = <double>[];
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (composer.evaluate().isNotEmpty && notice.evaluate().isNotEmpty) tops.add(tester.getRect(composer).top);
      }
      return tops;
    }

    await tester.pumpWidget(_buildApp());
    final promptState = tester.state(composer);
    final folding = await composerTopsBesideNotice();

    // It sinks under the bottom edge over the frames the notice opens in,
    // rather than blinking out.
    expect(folding.length, greaterThan(3));
    expect(folding, orderedEquals([...folding]..sort()));
    expect(folding.last - folding.first, greaterThan(20));
    expect(composer, findsNothing);
    expect(notice, findsOneWidget);

    connectionStatus
      ..add(const ConnectionStatus.disconnected())
      ..add(
        const ConnectionStatus.connected(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
          health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
        ),
      );
    final opening = await composerTopsBesideNotice();

    expect(opening.length, greaterThan(3));
    expect(opening.reversed, orderedEquals([...opening]..sort()));
    expect(opening.first - opening.last, greaterThan(20));
    await tester.pumpAndSettle();
    expect(discoveryCalls, 2);
    expect(composer, findsOneWidget);
    expect(notice, findsNothing);
    // Kept mounted while folded, so staged images survive the notice.
    expect(tester.state(composer), same(promptState));
  });

  testWidgets("holds the no-harness notice still through a reconnect that finds none again", (tester) async {
    final noHarness = ApiResponse.success(
      PluginDiscoverySnapshot(bridgeId: "bridge-1", supportsSessionOptions: true, plugins: const []),
    );
    final rediscovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
    var discoveryCalls = 0;
    when(pluginRepository.listPlugins).thenAnswer((_) {
      discoveryCalls++;
      return discoveryCalls == 1 ? Future.value(noHarness) : rediscovery.future;
    });
    final notice = find.byKey(const Key("new_session_no_harness_notice"));
    final harnessRoom = find.descendant(of: find.byType(NewSessionHeader), matching: find.byType(PregoShimmer));

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final noticeRect = tester.getRect(notice);

    /// Every frame shows the page as the bridge's answer left it.
    Future<void> expectStill() async {
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(notice), noticeRect);
        expect(find.byType(PromptInput), findsNothing);
        expect(find.byKey(const Key("new_session_options_retry")), findsNothing);
        expect(harnessRoom, findsNothing);
      }
    }

    connectionStatus.add(const ConnectionStatus.disconnected());
    await expectStill();
    connectionStatus.add(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
        health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
      ),
    );
    await expectStill();
    expect(discoveryCalls, 2);
    rediscovery.complete(noHarness);
    await expectStill();
  });

  testWidgets("holds the option pills still through a reconnect that finds the same harness", (tester) async {
    final harness = ApiResponse.success(
      PluginDiscoverySnapshot(
        bridgeId: "bridge-1",
        supportsSessionOptions: true,
        plugins: const [
          PluginMetadata(
            id: "plugin-1",
            displayName: "Plugin One",
            isDefault: true,
            state: PluginLifecycleState.ready,
            actionHint: null,
          ),
        ],
      ),
    );
    final rediscovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
    var discoveryCalls = 0;
    when(pluginRepository.listPlugins).thenAnswer((_) {
      discoveryCalls++;
      return discoveryCalls == 1 ? Future.value(harness) : rediscovery.future;
    });
    final project = ApiResponse.success(
      const Project(
        id: "project-1",
        name: "Project One",
        path: "/project-one",
        time: null,
        supportsDedicatedWorktrees: true,
        voiceGlossaryKey: null,
      ),
    );
    final projectRecheck = Completer<ApiResponse<Project>>();
    var projectCalls = 0;
    when(() => projectRepository.getProject(projectId: any(named: "projectId"))).thenAnswer((_) {
      projectCalls++;
      return projectCalls == 1 ? Future.value(project) : projectRecheck.future;
    });
    final pills = find.byType(AgentModelButtons);
    final worktreeToggle = find.byKey(const Key("new_session_dedicated_workspace"));
    List<String> agentNames() => [for (final agent in tester.widget<AgentModelButtons>(pills).agents) agent.name];

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final pillsRect = tester.getRect(pills);
    final toggleRect = tester.getRect(worktreeToggle);
    final shownAgents = agentNames();

    /// Every frame shows the pills and the worktree toggle as they were, with
    /// no Retry and nothing shimmering in their place.
    Future<void> expectStill() async {
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(pills, findsOneWidget);
        expect(tester.getRect(pills), pillsRect);
        expect(agentNames(), shownAgents);
        expect(tester.getRect(worktreeToggle), toggleRect);
        expect(find.byKey(const Key("new_session_options_retry")), findsNothing);
        expect(find.byType(PregoShimmer), findsNothing);
      }
    }

    connectionStatus.add(const ConnectionStatus.disconnected());
    await expectStill();
    connectionStatus.add(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
        health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
      ),
    );
    await expectStill();
    expect(discoveryCalls, 2);
    expect(projectCalls, 2);
    rediscovery.complete(harness);
    await expectStill();
    projectRecheck.complete(project);
    await expectStill();
  });

  testWidgets("holds the login card still through a reconnect that finds the harness still logged out", (
    tester,
  ) async {
    final harness = ApiResponse.success(
      PluginDiscoverySnapshot(
        bridgeId: "bridge-1",
        supportsSessionOptions: true,
        plugins: const [
          PluginMetadata(
            id: "plugin-1",
            displayName: "Plugin One",
            isDefault: true,
            state: PluginLifecycleState.ready,
            actionHint: null,
          ),
        ],
      ),
    );
    final rediscovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
    var discoveryCalls = 0;
    when(pluginRepository.listPlugins).thenAnswer((_) {
      discoveryCalls++;
      return discoveryCalls == 1 ? Future.value(harness) : rediscovery.future;
    });
    const loginRequired = SessionOptionsRepositoryAuthenticationRequired(
      actionHint: "Run the harness locally and use /login.",
    );
    final optionsRecheck = Completer<SessionOptionsRepositoryResult>();
    var optionLoads = 0;
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: any(named: "mode"),
      ),
    ).thenAnswer((_) {
      optionLoads++;
      return optionLoads == 1 ? Future.value(loginRequired) : optionsRecheck.future;
    });
    final project = ApiResponse.success(
      const Project(
        id: "project-1",
        name: "Project One",
        path: "/project-one",
        time: null,
        supportsDedicatedWorktrees: true,
        voiceGlossaryKey: null,
      ),
    );
    final projectRecheck = Completer<ApiResponse<Project>>();
    var projectCalls = 0;
    when(() => projectRepository.getProject(projectId: any(named: "projectId"))).thenAnswer((_) {
      projectCalls++;
      return projectCalls == 1 ? Future.value(project) : projectRecheck.future;
    });
    final card = find.byKey(const Key("new_session_login_required"));
    final worktreeToggle = find.byKey(const Key("new_session_dedicated_workspace"));

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final cardRect = tester.getRect(card);
    final toggleRect = tester.getRect(worktreeToggle);

    /// Every frame shows the login card and the worktree toggle as they were:
    /// no composer, Retry, pills or shimmer in its place, and no popup saying
    /// the harness logged out.
    Future<void> expectStill() async {
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(card, findsOneWidget);
        expect(tester.getRect(card), cardRect);
        expect(find.text("Run the harness locally and use /login."), findsOneWidget);
        expect(tester.getRect(worktreeToggle), toggleRect);
        expect(find.byType(PromptInput), findsNothing);
        expect(find.byKey(const Key("new_session_options_retry")), findsNothing);
        expect(find.byType(AgentModelButtons), findsNothing);
        expect(find.byType(PregoShimmer), findsNothing);
        expect(find.byType(PregoPopupAlertsNotifications), findsNothing);
      }
    }

    connectionStatus.add(const ConnectionStatus.disconnected());
    await expectStill();
    connectionStatus.add(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
        health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
      ),
    );
    await expectStill();
    expect(discoveryCalls, 2);
    expect(projectCalls, 2);
    rediscovery.complete(harness);
    await expectStill();
    expect(optionLoads, 2);
    projectRecheck.complete(project);
    await expectStill();
    optionsRecheck.complete(loginRequired);
    await expectStill();
  });

  group("through a reconnect", () {
    final harness = ApiResponse.success(
      PluginDiscoverySnapshot(
        bridgeId: "bridge-1",
        supportsSessionOptions: true,
        plugins: const [
          PluginMetadata(
            id: "plugin-1",
            displayName: "Plugin One",
            isDefault: true,
            state: PluginLifecycleState.ready,
            actionHint: null,
          ),
        ],
      ),
    );
    final project = ApiResponse.success(
      const Project(
        id: "project-1",
        name: "Project One",
        path: "/project-one",
        time: null,
        supportsDedicatedWorktrees: true,
        voiceGlossaryKey: null,
      ),
    );
    const connected = ConnectionStatus.connected(
      config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
      health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
    );

    /// Answers the first discovery with [harness] and every later one with the
    /// returned completer. Called from each test body, so the completer
    /// answers in the test's fake time.
    ({Completer<ApiResponse<PluginDiscoverySnapshot>> rediscovery, int Function() calls}) stubDiscovery() {
      final rediscovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
      var calls = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) {
        calls++;
        return calls == 1 ? Future.value(harness) : rediscovery.future;
      });
      return (rediscovery: rediscovery, calls: () => calls);
    }

    /// Answers the options with [answers], in order, and every later load with
    /// the returned completer.
    ({Completer<SessionOptionsRepositoryResult> later, int Function() loads}) stubOptions({
      required List<SessionOptionsRepositoryResult> answers,
    }) {
      final later = Completer<SessionOptionsRepositoryResult>();
      var loads = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) {
        loads++;
        return loads <= answers.length ? Future.value(answers[loads - 1]) : later.future;
      });
      return (later: later, loads: () => loads);
    }

    testWidgets("holds the option placeholders still when the drop cuts off their load", (tester) async {
      final discovery = stubDiscovery();
      final options = stubOptions(answers: const []);
      final placeholder = find.byType(PregoShimmer);

      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(options.loads(), 1);
      final placeholderRect = tester.getRect(placeholder);

      /// Every frame shows the placeholders as they were, with no Retry in
      /// their place.
      Future<void> expectStill() async {
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(placeholder, findsOneWidget);
          expect(tester.getRect(placeholder), placeholderRect);
          expect(find.byKey(const Key("new_session_options_retry")), findsNothing);
          expect(find.byType(AgentModelButtons), findsNothing);
        }
      }

      connectionStatus.add(const ConnectionStatus.disconnected());
      await expectStill();
      connectionStatus.add(connected);
      await expectStill();
      expect(discovery.calls(), 2);
      discovery.rediscovery.complete(harness);
      await expectStill();
      expect(options.loads(), 2);
      options.later.complete(SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false));
      await tester.pumpAndSettle();
      expect(find.byType(AgentModelButtons), findsOneWidget);
    });

    testWidgets("holds the project card still when the project still cannot be checked", (tester) async {
      final discovery = stubDiscovery();
      final projectRecheck = Completer<ApiResponse<Project>>();
      var projectCalls = 0;
      when(() => projectRepository.getProject(projectId: any(named: "projectId"))).thenAnswer((_) {
        projectCalls++;
        return projectCalls == 1 ? Future.value(ApiResponse<Project>.error(ApiError.generic())) : projectRecheck.future;
      });
      final card = find.byKey(const Key("new_session_project_unavailable"));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      final cardRect = tester.getRect(card);

      /// Every frame shows the card as it was, with no composer, pills, Retry
      /// or shimmer in its place.
      Future<void> expectStill() async {
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(card, findsOneWidget);
          expect(tester.getRect(card), cardRect);
          expect(find.byType(PromptInput), findsNothing);
          expect(find.byType(AgentModelButtons), findsNothing);
          expect(find.byKey(const Key("new_session_options_retry")), findsNothing);
          expect(find.byType(PregoShimmer), findsNothing);
        }
      }

      connectionStatus.add(const ConnectionStatus.disconnected());
      await expectStill();
      connectionStatus.add(connected);
      await expectStill();
      expect(discovery.calls(), 2);
      expect(projectCalls, 2);
      discovery.rediscovery.complete(harness);
      await expectStill();
      projectRecheck.complete(ApiResponse.error(ApiError.generic()));
      await expectStill();
    });

    testWidgets("a recheck on the login card while the project is rechecked opens the composer once logged in", (
      tester,
    ) async {
      const loginRequired = SessionOptionsRepositoryAuthenticationRequired(
        actionHint: "Run the harness locally and use /login.",
      );
      final discovery = stubDiscovery();
      final options = stubOptions(answers: const [loginRequired, loginRequired]);
      final projectRecheck = Completer<ApiResponse<Project>>();
      var projectCalls = 0;
      when(() => projectRepository.getProject(projectId: any(named: "projectId"))).thenAnswer((_) {
        projectCalls++;
        return projectCalls == 1 ? Future.value(project) : projectRecheck.future;
      });
      final card = find.byKey(const Key("new_session_login_required"));

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      connectionStatus.add(const ConnectionStatus.disconnected());
      await tester.pump();
      connectionStatus.add(connected);
      await tester.pump();
      discovery.rediscovery.complete(harness);
      await tester.pump();
      expect(options.loads(), 2);
      expect(projectCalls, 2);
      final cardRect = tester.getRect(card);

      await tester.tap(find.byKey(const Key("session_harness_recheck")));
      // The card stays as it is while the press asks for the options.
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(card), cardRect);
        expect(find.byType(PregoShimmer), findsNothing);
      }
      expect(options.loads(), 3);
      options.later.complete(SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(find.byType(PromptInput), findsOneWidget);
      expect(find.byType(AgentModelButtons), findsOneWidget);
      projectRecheck.complete(project);
      await tester.pumpAndSettle();
    });
  });

  group("Recheck shows that it is checking", () {
    const loginRequired = SessionOptionsRepositoryAuthenticationRequired(
      actionHint: "Run the harness locally and use /login.",
    );
    final harness = ApiResponse.success(
      PluginDiscoverySnapshot(
        bridgeId: "bridge-1",
        supportsSessionOptions: true,
        plugins: const [
          PluginMetadata(
            id: "plugin-1",
            displayName: "Plugin One",
            isDefault: true,
            state: PluginLifecycleState.ready,
            actionHint: null,
          ),
        ],
      ),
    );
    final project = ApiResponse.success(
      const Project(
        id: "project-1",
        name: "Project One",
        path: "/project-one",
        time: null,
        supportsDedicatedWorktrees: true,
        voiceGlossaryKey: null,
      ),
    );
    final loginCard = find.byKey(const Key("new_session_login_required"));
    final projectCard = find.byKey(const Key("new_session_project_unavailable"));
    final recheck = find.byKey(const Key("session_harness_recheck"));
    final spinner = find.descendant(of: recheck, matching: find.byType(PregoActivityIndicator));
    const frame = Duration(milliseconds: 16);

    /// Opens the page on the login card. The options load a Recheck starts
    /// waits for the returned completer.
    Future<({Completer<SessionOptionsRepositoryResult> answer, int Function() loads})> openLoginCard({
      required WidgetTester tester,
    }) async {
      final answer = Completer<SessionOptionsRepositoryResult>();
      var loads = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) {
        loads++;
        return loads == 1 ? Future.value(loginRequired) : answer.future;
      });
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      expect(loginCard, findsOneWidget);
      return (answer: answer, loads: () => loads);
    }

    /// Opens the page on the "project cannot be checked" card. The check a
    /// Recheck starts waits for the returned completer.
    Future<({Completer<ApiResponse<Project>> answer, int Function() checks})> openProjectCard({
      required WidgetTester tester,
    }) async {
      final answer = Completer<ApiResponse<Project>>();
      var checks = 0;
      when(() => projectRepository.getProject(projectId: any(named: "projectId"))).thenAnswer((_) {
        checks++;
        return checks == 1 ? Future.value(ApiResponse<Project>.error(ApiError.generic())) : answer.future;
      });
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      expect(projectCard, findsOneWidget);
      return (answer: answer, checks: () => checks);
    }

    /// Presses Recheck and holds the answer for 640 ms, frame by frame: the
    /// card and the button never move, the spinner stays away until 300 ms
    /// after the press and shows from then on, and presses meanwhile, before
    /// and after it shows, ask the bridge nothing more.
    Future<void> pressAndHold({
      required WidgetTester tester,
      required Finder card,
      required int Function() requests,
    }) async {
      final cardRect = tester.getRect(card);
      final buttonRect = tester.getRect(recheck);
      final asked = requests();
      await tester.tap(recheck);
      for (var elapsed = frame; elapsed <= const Duration(milliseconds: 640); elapsed += frame) {
        await tester.pump(frame);
        expect(tester.getRect(card), cardRect);
        expect(tester.getRect(recheck), buttonRect);
        expect(spinner, elapsed < const Duration(milliseconds: 300) ? findsNothing : findsOneWidget);
        if (elapsed == const Duration(milliseconds: 112) || elapsed == const Duration(milliseconds: 496)) {
          await tester.tap(recheck, warnIfMissed: false);
        }
      }
      expect(requests(), asked + 1);
      // Screen readers hear a Recheck that takes no press while it checks.
      expect(
        find.semantics.byLabel("Recheck").evaluate().single,
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false, hasTapAction: false),
      );
    }

    /// Lets the answer land and the spinner fade out.
    Future<void> expectSpinnerGone({required WidgetTester tester}) async {
      for (var elapsed = Duration.zero; elapsed < const Duration(milliseconds: 400); elapsed += frame) {
        await tester.pump(frame);
      }
      expect(spinner, findsNothing);
    }

    testWidgets("on the login card until the harness has logged in", (tester) async {
      final login = await openLoginCard(tester: tester);

      await pressAndHold(tester: tester, card: loginCard, requests: login.loads);
      login.answer.complete(SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false));
      await expectSpinnerGone(tester: tester);

      expect(loginCard, findsNothing);
      expect(find.byType(PromptInput), findsOneWidget);
    });

    testWidgets("on the login card until the harness still needs a login, then takes a press again", (tester) async {
      final login = await openLoginCard(tester: tester);
      final cardRect = tester.getRect(loginCard);
      final buttonRect = tester.getRect(recheck);

      await pressAndHold(tester: tester, card: loginCard, requests: login.loads);
      login.answer.complete(loginRequired);
      await expectSpinnerGone(tester: tester);

      expect(tester.getRect(loginCard), cardRect);
      expect(tester.getRect(recheck), buttonRect);
      await tester.tap(recheck);
      await tester.pump();
      expect(login.loads(), 3);
    });

    testWidgets("on the login card until the load fails and Retry takes its place", (tester) async {
      final login = await openLoginCard(tester: tester);

      await pressAndHold(tester: tester, card: loginCard, requests: login.loads);
      login.answer.complete(SessionOptionsRepositoryFailure(error: ApiError.generic()));
      await expectSpinnerGone(tester: tester);

      expect(loginCard, findsNothing);
      expect(find.byKey(const Key("new_session_options_retry")), findsOneWidget);
    });

    testWidgets("on the login card through the rediscovery and options load of an unverified bridge", (
      tester,
    ) async {
      final rediscovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
      var discoveries = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) {
        discoveries++;
        return discoveries == 1 ? Future.value(harness) : rediscovery.future;
      });
      final login = await openLoginCard(tester: tester);
      connectionStatus.add(const ConnectionStatus.disconnected());
      await tester.pump();
      final cardRect = tester.getRect(loginCard);

      await pressAndHold(tester: tester, card: loginCard, requests: () => discoveries);
      rediscovery.complete(harness);
      for (var index = 0; index < 20; index++) {
        await tester.pump(frame);
        expect(tester.getRect(loginCard), cardRect);
        expect(spinner, findsOneWidget);
      }
      expect(login.loads(), 2);
      login.answer.complete(loginRequired);
      await expectSpinnerGone(tester: tester);

      expect(tester.getRect(loginCard), cardRect);
    });

    testWidgets("on the login card until its rediscovery fails and Retry takes its place", (tester) async {
      final rediscovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
      var discoveries = 0;
      when(pluginRepository.listPlugins).thenAnswer((_) {
        discoveries++;
        return discoveries == 1 ? Future.value(harness) : rediscovery.future;
      });
      await openLoginCard(tester: tester);
      connectionStatus.add(const ConnectionStatus.disconnected());
      await tester.pump();

      await pressAndHold(tester: tester, card: loginCard, requests: () => discoveries);
      rediscovery.complete(ApiResponse.error(ApiError.generic()));
      await expectSpinnerGone(tester: tester);

      expect(loginCard, findsNothing);
      expect(find.byKey(const Key("new_session_options_retry")), findsOneWidget);
    });

    testWidgets("on the project card until the project is checked", (tester) async {
      final check = await openProjectCard(tester: tester);

      await pressAndHold(tester: tester, card: projectCard, requests: check.checks);
      check.answer.complete(project);
      await expectSpinnerGone(tester: tester);

      expect(projectCard, findsNothing);
      expect(find.byType(PromptInput), findsOneWidget);
    });

    testWidgets("on the project card until it still cannot be checked, then takes a press again", (tester) async {
      final check = await openProjectCard(tester: tester);
      final cardRect = tester.getRect(projectCard);
      final buttonRect = tester.getRect(recheck);

      await pressAndHold(tester: tester, card: projectCard, requests: check.checks);
      check.answer.complete(ApiResponse.error(ApiError.generic()));
      await expectSpinnerGone(tester: tester);

      expect(tester.getRect(projectCard), cardRect);
      expect(tester.getRect(recheck), buttonRect);
      await tester.tap(recheck);
      await tester.pump();
      expect(check.checks(), 3);
    });

    testWidgets("on the project card until its check fails", (tester) async {
      final check = await openProjectCard(tester: tester);
      final cardRect = tester.getRect(projectCard);

      await pressAndHold(tester: tester, card: projectCard, requests: check.checks);
      check.answer.completeError(StateError("connection lost"));
      await expectSpinnerGone(tester: tester);

      expect(tester.getRect(projectCard), cardRect);
    });

    testWidgets("swaps at once under reduced motion", (tester) async {
      final login = await openLoginCard(tester: tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pump();
      final fades = find.descendant(of: recheck, matching: find.byType(FadeTransition));
      List<double> opacities() => [for (final fade in tester.widgetList<FadeTransition>(fades)) fade.opacity.value];

      await tester.tap(recheck);
      await tester.pump(const Duration(milliseconds: 304));
      expect(spinner, findsOneWidget);
      expect(opacities(), everyElement(anyOf(0.0, 1.0)));
      login.answer.complete(loginRequired);
      await tester.pump();
      expect(spinner, findsNothing);
    });
  });

  testWidgets("keeps discovery retry when discovery fails before finding a harness", (tester) async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null)),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    expect(find.text(loc.apiErrorServerRejected), findsOneWidget);
    final retry = find.byKey(const Key("new_session_options_retry"));
    expect(tester.widget<PregoButtonsSolid>(retry).label, loc.newSessionOptionsRetry);
    expect(tester.widget<PregoButtonsSolid>(retry).onPressed, isNotNull);
    // The bridge never confirmed an empty harness list, so the error banner is
    // the honest explanation and discovery remains retryable.
    expect(find.byKey(const Key("new_session_no_harness_notice")), findsNothing);
    expect(find.text(loc.newSessionDedicatedWorkspace), findsNothing);
  });

  group("the project slides to the centre as the harness's room leaves", () {
    final failed = ApiResponse<PluginDiscoverySnapshot>.error(
      ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null),
    );
    final noHarness = ApiResponse.success(
      PluginDiscoverySnapshot(bridgeId: null, supportsSessionOptions: true, plugins: const []),
    );
    for (final (name, outcome, width) in [
      ("discovery fails", failed, 800.0),
      ("the bridge has no harness", noHarness, 800.0),
      // Too narrow for both pills, so the shimmer waits on a line of its own.
      ("the pills wrap and discovery fails", failed, 360.0),
    ]) {
      testWidgets("when $name", (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final discovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
        when(pluginRepository.listPlugins).thenAnswer((_) => discovery.future);
        final project = find.byKey(const Key("new_session_project"));
        final harnessRoom = find.descendant(of: find.byType(NewSessionHeader), matching: find.byType(PregoShimmer));
        double projectX() => tester.getCenter(project).dx;

        await tester.pumpWidget(_buildApp());
        await tester.pump(const Duration(milliseconds: 300));
        expect(harnessRoom, findsOneWidget);
        final centre = tester.getCenter(find.byType(NewSessionHeader)).dx;
        final wrapped = tester.getRect(harnessRoom).top > tester.getRect(project).bottom;
        expect(wrapped, width < 800);
        final loading = projectX();
        // Beside the room the pair is centred; alone on its line it is.
        expect(loading, wrapped ? moreOrLessEquals(centre) : lessThan(centre - 50));

        discovery.complete(outcome);
        // Frames with no time passing, until the room is gone.
        for (var frame = 0; frame < 10 && harnessRoom.evaluate().isNotEmpty; frame++) {
          await tester.pump();
        }
        expect(harnessRoom, findsNothing);

        // The first frame without the room paints the project where it was,
        // and the rest of the motion carries it to the centre.
        expect(projectX(), moreOrLessEquals(loading));
        await tester.pump(const Duration(milliseconds: 100));
        if (!wrapped) expect(projectX(), allOf(greaterThan(loading + 10), lessThan(centre - 1)));
        await tester.pumpAndSettle();
        expect(projectX(), moreOrLessEquals(centre));
      });
    }
  });

  testWidgets("the error banner opens over the composer while its pills hold their place", (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final discovery = Completer<ApiResponse<PluginDiscoverySnapshot>>();
    when(pluginRepository.listPlugins).thenAnswer((_) => discovery.future);
    final composer = find.byType(PromptInput);
    final retry = find.byKey(const Key("new_session_options_retry"));
    // The placeholder pills while discovery runs, then Retry in their place.
    Rect pills() => tester.getRect(
      retry.evaluate().isEmpty ? find.descendant(of: composer, matching: find.byType(PregoSkeletonBar)).first : retry,
    );

    await tester.pumpWidget(_buildApp());
    await tester.pump(const Duration(milliseconds: 300));
    final loc = tester.element(find.byType(NewSessionScreen)).loc;
    final pillsBottom = pills().bottom;
    final composerTops = [tester.getRect(composer).top];

    discovery.complete(ApiResponse.error(ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null)));
    await tester.pump(Duration.zero);
    for (var frame = 0; frame < 20; frame++) {
      expect(pills().bottom, pillsBottom);
      composerTops.add(tester.getRect(composer).top);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    composerTops.add(tester.getRect(composer).top);

    expect(find.text(loc.apiErrorServerRejected), findsOneWidget);
    expect(pills().bottom, pillsBottom);
    // The composer's top edge rises over the motion as the banner's room
    // opens above the pills, never by the whole banner in one frame.
    final rise = composerTops.first - composerTops.last;
    expect(rise, greaterThan(20));
    for (var frame = 1; frame < composerTops.length; frame++) {
      expect(composerTops[frame - 1] - composerTops[frame], lessThan(rise / 4));
    }
  });

  testWidgets("opens harness settings from the empty harness notice", (tester) async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(bridgeId: null, supportsSessionOptions: true, plugins: const []),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("new_session_no_harness_settings")));
    await tester.pumpAndSettle();

    expect(find.text("harnesses-settings"), findsOneWidget);
  });

  testWidgets("selecting a different variant updates the displayed variant", (tester) async {
    when(
      () => sessionService.listProviders(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        const ProviderListResponse(
          connectedOnly: false,
          items: [
            ProviderInfo(
              id: "anthropic",
              name: "Anthropic",
              defaultModelID: "claude-3-5-sonnet",
              models: {
                "claude-3-5-sonnet": ProviderModel(
                  fastMode: null,
                  id: "claude-3-5-sonnet",
                  providerID: "anthropic",
                  name: "Claude 3.5 Sonnet",
                  variants: ["xhigh", "low"],
                  defaultVariant: null,
                  family: null,
                  releaseDate: null,
                ),
              },
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Initially shows the agent's default variant.
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);

    // Open variant picker.
    await tester.tap(find.widgetWithText(PregoPickerButton, "xhigh"));
    await tester.pumpAndSettle();

    // Select a different variant.
    await tester.tap(_pickerMenuItem("low"));
    await tester.pumpAndSettle();

    // The UI should now reflect the newly selected variant.
    expect(find.widgetWithText(PregoPickerButton, "low"), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsNothing);
  });

  testWidgets("selecting another variant updates the displayed variant", (tester) async {
    when(
      () => sessionService.listProviders(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        const ProviderListResponse(
          connectedOnly: false,
          items: [
            ProviderInfo(
              id: "anthropic",
              name: "Anthropic",
              defaultModelID: "claude-3-5-sonnet",
              models: {
                "claude-3-5-sonnet": ProviderModel(
                  fastMode: null,
                  id: "claude-3-5-sonnet",
                  providerID: "anthropic",
                  name: "Claude 3.5 Sonnet",
                  variants: ["xhigh", "low"],
                  defaultVariant: null,
                  family: null,
                  releaseDate: null,
                ),
              },
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Initially shows the agent's default variant.
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);

    // Open variant picker.
    await tester.tap(find.widgetWithText(PregoPickerButton, "xhigh"));
    await tester.pumpAndSettle();

    // Select the model's other variant.
    await tester.tap(_pickerMenuItem("low"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PregoPickerButton, "low"), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsNothing);
  });

  testWidgets("preserves selectedAgentModel variant when changing agent", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(PregoPickerButton, "xhigh"));
    await tester.pumpAndSettle();

    await tester.tap(_pickerMenuItem("xhigh"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(PregoPickerButton, "coder"));
    await tester.pumpAndSettle();

    await tester.tap(_pickerMenuItem("reviewer"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PregoPickerButton, "reviewer"), findsOneWidget);
    // Variant intent is independent, so the explicit xhigh choice survives the
    // agent change while that variant remains valid for the selected model.
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);
  });

  testWidgets("shows the submitted message as a sending bubble during sending", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    // The first sending frame already shows the message, with no spinner page.
    final bubble = find.byType(QueuedMessageBubble);
    expect(bubble, findsOneWidget);
    expect(find.descendant(of: bubble, matching: find.text("test message")), findsOneWidget);
    expect(find.descendant(of: bubble, matching: find.text(loc.sessionDetailSendingMessage)), findsOneWidget);
    expect(find.byType(PregoLaunchStatus), findsNothing);
    expect(find.text(loc.sessionListNewSession), findsOneWidget);
    expect(
      GoRouter.of(tester.element(bubble)).routeInformationProvider.value.uri.toString(),
      "/sessions/new?project=project-1",
    );

    // The composer stays where it was, keeping the keyboard, for follow-ups.
    final composerRect = tester.getRect(find.byType(PromptInput));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(PromptInput), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.getRect(find.byType(PromptInput)).bottom, composerRect.bottom);

    // A slow creation names the harness it waits on.
    await tester.pump(const Duration(seconds: 2));
    // Named from the plugin id, as the session screen names the bubble.
    expect(find.text(loc.sessionDetailSendingToHarness(PregoBrandLogo.displayNameFor("plugin-1"))), findsOneWidget);
  });

  testWidgets("a message sent while the first one is sending queues below it in the same composer", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "first message");
    await tester.pumpAndSettle();
    final promptState = tester.state(find.byType(PromptInput));
    final firstRect = tester.getRect(
      find.ancestor(of: find.text("first message"), matching: find.byType(QueuedMessageBubble)),
    );

    await enterTextAndSend(tester: tester, text: "second message");
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(PromptInput)), same(promptState));
    final secondBubble = find.ancestor(of: find.text("second message"), matching: find.byType(QueuedMessageBubble));
    expect(secondBubble, findsOneWidget);
    // The new row sits below the first, which moves up to make room.
    final first = tester.getRect(
      find.ancestor(of: find.text("first message"), matching: find.byType(QueuedMessageBubble)),
    );
    expect(tester.getRect(secondBubble).top, greaterThan(first.bottom - 1));
    expect(first.bottom, lessThan(firstRect.bottom));
    // Only the first message created the session.
    verify(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).called(1);
  });

  testWidgets("keeps the composer and its voice session while a session is sending", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pumpAndSettle();

    expect(find.byType(PromptInput), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    verifyNever(() => voiceTranscriptionService.close(session: voiceSession));

    verify(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).called(1);
  });

  testWidgets("releasing a hold creates the session with the words", (tester) async {
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(testSession(id: "session-1", title: null)));
    when(() => voiceTranscriptionService.start(session: voiceSession)).thenAnswer((_) async {});
    when(
      () => voiceTranscriptionService.stopAndTranscribe(session: voiceSession),
    ).thenAnswer((_) async => afterRecordingResult(transcript: "spoken words"));

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();

    verify(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: wrapDictatedText(text: "spoken words"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).called(1);
  });

  testWidgets("a creation landing mid-recording waits for a transcript slid onto the pencil, then hands it over", (
    tester,
  ) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);
    when(() => voiceTranscriptionService.start(session: voiceSession)).thenAnswer((_) async {});
    final transcript = Completer<String>();
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession))
        .thenAnswer((_) => afterRecordingResultOf(transcript: transcript.future));
    SessionLaunchHandoff? handoff;
    await tester.pumpWidget(
      _buildApp(
        sessionDetailBuilder: (context, state) {
          final sessionId = state.pathParameters["sessionId"] ?? "";
          handoff ??= GetIt.instance<SessionLaunchRepository>().takeHandoff(sessionId: sessionId);
          return Text("session-detail:$sessionId");
        },
      ),
    );
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));

    createCompleter.complete(ApiResponse.success(testSession(id: "session-1", title: null)));
    await tester.pump();
    await tester.pump();
    expect(find.byType(NewSessionScreen), findsOneWidget, reason: "the recording keeps the screen");

    await gesture.moveTo(tester.getCenter(find.byType(PregoVoiceTarget)));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(find.byType(NewSessionScreen), findsOneWidget, reason: "the transcription keeps it too");

    transcript.complete("spoken words");
    await tester.pumpAndSettle();
    expect(find.text("session-detail:session-1"), findsOneWidget);
    expect(handoff?.composer?.unsent?.draft.text, contains("spoken words"));
  });

  testWidgets("a hold released while creating follows the first message once the transcript lands", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);
    when(() => voiceTranscriptionService.start(session: voiceSession)).thenAnswer((_) async {});
    final transcript = Completer<String>();
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession))
        .thenAnswer((_) => afterRecordingResultOf(transcript: transcript.future));
    when(
      () => sessionService.sendMessage(
        sessionId: any(named: "sessionId"),
        promptId: any(named: "promptId"),
        text: any(named: "text"),
        attachments: any(named: "attachments"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(null));
    SessionLaunchHandoff? handoff;
    await tester.pumpWidget(
      _buildApp(
        sessionDetailBuilder: (context, state) {
          final sessionId = state.pathParameters["sessionId"] ?? "";
          handoff ??= GetIt.instance<SessionLaunchRepository>().takeHandoff(sessionId: sessionId);
          return Text("session-detail:$sessionId");
        },
      ),
    );
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));

    createCompleter.complete(ApiResponse.success(testSession(id: "session-1", title: null)));
    await tester.pump();
    await tester.pump();
    expect(find.byType(NewSessionScreen), findsOneWidget, reason: "the recording keeps the screen");

    await gesture.up();
    await tester.pump();
    expect(find.byType(NewSessionScreen), findsOneWidget, reason: "the transcription keeps it too");

    transcript.complete("spoken words");
    await tester.pumpAndSettle();
    expect(find.text("session-detail:session-1"), findsOneWidget);
    expect(handoff?.composer?.unsent, isNull, reason: "the words were sent, not left in the composer");
    verify(
      () => sessionService.sendMessage(
        sessionId: "session-1",
        promptId: any(named: "promptId"),
        text: wrapDictatedText(text: "spoken words"),
        attachments: const [],
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: null,
      ),
    ).called(1);
  });

  testWidgets("shows snackbar and allows navigation when aborting while sending", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byType(QueuedMessageBubble), findsOneWidget);

    // Simulate system back navigation (which should be allowed while sending).
    // PregoTopNavigation renders a glass back button (not a stock BackButton),
    // so tester.pageBack() can't find it — tap the glass chevron directly.
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Route disposal schedules the snackbar post-frame, so render that frame.
    await tester.pump();

    // Snackbar should appear after the screen pops.
    expect(find.text(loc.newSessionLaunchingInBackground), findsOneWidget);

    // The screen has popped (no longer showing NewSessionScreen).
    expect(find.byType(NewSessionScreen), findsNothing);
  });

  testWidgets("does not hijack navigation when creation completes after the user navigated away", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byType(QueuedMessageBubble), findsOneWidget);

    // User leaves while the creation request is still in flight.
    // PregoTopNavigation renders a glass back button (not a stock BackButton),
    // so tester.pageBack() can't find it — tap the glass chevron directly.
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Route disposal schedules the snackbar post-frame, so render that frame.
    await tester.pump();
    expect(find.text(loc.newSessionLaunchingInBackground), findsOneWidget);

    // Creation completes while the screen is still animating out.
    createCompleter.complete(ApiResponse.success(testSession(id: "session-1", title: "Created session")));
    await tester.pumpAndSettle();

    // The user's chosen location must be preserved — no redirect to the
    // created session's detail route.
    expect(find.text("session-detail:session-1"), findsNothing);
    expect(find.byType(NewSessionScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("still navigates to session detail after creating a session", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byType(QueuedMessageBubble), findsOneWidget);

    createCompleter.complete(ApiResponse.success(testSession(id: "session-1", title: null)));
    await tester.pumpAndSettle();

    expect(find.text("session-detail:session-1"), findsOneWidget);
    expect(
      find.text("uri:/sessions/project-1/session-1?readOnly=false&name=Project+One&fromLaunch=1"),
      findsOneWidget,
    );
    expect(find.byType(NewSessionScreen), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets("the session screen takes over the sending bubble without moving it or changing its words", (
    tester,
  ) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);
    // The detail screen's first state, seeded from the launch as its cubit
    // seeds it, and built once however often the route rebuilds.
    _MockSessionDetailCubit? detailCubit;
    _MockSessionDetailCubit detailCubitFor({required String sessionId}) {
      final cubit = _MockSessionDetailCubit();
      final handoff = GetIt.instance<SessionLaunchRepository>().takeHandoff(sessionId: sessionId);
      whenListen(
        cubit,
        const Stream<SessionDetailState>.empty(),
        initialState: SessionDetailState.loading(
          launchHandoff: handoff,
          seededComposer: switch (handoff?.composer) {
            final composer? => SeededComposer(composer: composer, stagedCommand: null),
            null => null,
          },
        ),
      );
      when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.noticeStream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
      when(() => cubit.launchAttachments).thenReturn(const []);
      when(cubit.acknowledgeLaunchAttachments).thenReturn(null);
      return cubit;
    }

    await tester.pumpWidget(
      _buildApp(
        sessionDetailBuilder: (context, state) {
          final sessionId = state.pathParameters["sessionId"] ?? "";
          return BlocProvider<SessionDetailCubit>.value(
            value: detailCubit ??= detailCubitFor(sessionId: sessionId),
            child: SessionDetailPresentationScope(
              openHarnessSettings: () {},
              openBridgeSettings: () {},
              messageImageRepository: _MockMessageImageRepository.new,
              imageSaver: _MockImageSaver.new,
              imageClipboard: () => GetIt.instance<ImageClipboard>(),
              imageSharer: _MockImageSharer.new,
              sessionRepository: () => throw UnimplementedError("Prompt search is not under test"),
              createPendingFormCubit: ({required requestId, required sessionId}) =>
                  throw StateError("Unused fixture form"),
              createFilePreviewCubit: ({required reference}) =>
                  throw UnimplementedError("File previews are not under test"),
              createExternalActionCubit: ({required requestId, required sessionId}) =>
                  throw UnimplementedError("External actions are not under test"),
              canShareImages: true,
              openExternalLink: ({required url, required mode}) async => false,
              openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
              child: SessionDetailBody(
                projectId: "project-1",
                sessionId: sessionId,
                sessionTitle: null,
                readOnly: false,
                banner: null,
                onBack: null,
                onShowDiffs: null,
                pageChrome: null,
                menuEntriesBuilder: null,
                bottomControlsBuilder: ({required context, required projectId, required sessionId, required source}) =>
                    MobileSessionDetailComposerControls(projectId: projectId, sessionId: sessionId, source: source),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pumpAndSettle();
    // Past the slow-send threshold, so the words must survive the swap too.
    await tester.pump(const Duration(seconds: 3));
    final loc = AppLocalizations.of(tester.element(find.byType(QueuedMessageBubble)))!;
    final slowSendCopy = loc.sessionDetailSendingToHarness(PregoBrandLogo.displayNameFor("plugin-1"));
    expect(find.text(slowSendCopy), findsOneWidget);
    final sendingRect = tester.getRect(find.byType(QueuedMessageBubble));
    final composerRect = tester.getRect(find.byType(PromptInput));

    createCompleter.complete(ApiResponse.success(testSession(id: "session-1", title: null)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SessionDetailBody), findsOneWidget);
    expect(find.byType(PregoLaunchStatus), findsNothing);
    expect(find.text(slowSendCopy), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(NewSessionScreen), findsNothing);
    expect(tester.getRect(find.byType(QueuedMessageBubble)), sendingRect);
    // The session screen's composer stands where the new-session one stood.
    expect(tester.getRect(find.byType(PromptInput)), composerRect);
    expect(find.text(slowSendCopy), findsOneWidget);
  });

  testWidgets("does not show snackbar when auto-navigating after creating a session", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byType(QueuedMessageBubble), findsOneWidget);

    createCompleter.complete(ApiResponse.success(testSession(id: "session-1", title: "Created session")));
    await tester.pumpAndSettle();

    expect(find.text("session-detail:session-1"), findsOneWidget);
    expect(find.byType(NewSessionScreen), findsNothing);
    expect(find.text(loc.newSessionLaunchingInBackground), findsNothing);
  });

  testWidgets("restores a coalesced failed submission without remounting the composer", (tester) async {
    final attachment = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: "screenshot.png");
    when(attachmentDispatcher.pickImage).thenAnswer((_) async => attachment);
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: const [
            PluginMetadata(
              id: "plugin-1",
              displayName: "Plugin One",
              isDefault: true,
              state: PluginLifecycleState.ready,
              actionHint: null,
              supportsPromptAttachments: true,
            ),
          ],
        ),
      ),
    );
    final retryCompleter = Completer<ApiResponse<Session>>();
    addTearDown(() {
      if (!retryCompleter.isCompleted) retryCompleter.complete(ApiResponse.error(ApiError.generic()));
    });
    final submittedAttachments = <List<ComposerAttachment>>[];
    var creationCalls = 0;
    when(
      () => sessionService.createSessionWithMessage(
        attachments: any(named: "attachments"),
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((invocation) {
      creationCalls++;
      submittedAttachments.add(
        invocation.namedArguments[#attachments]! as List<ComposerAttachment>,
      );
      if (creationCalls == 1) return Future.value(ApiResponse.error(ApiError.generic()));
      return retryCompleter.future;
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Attach image"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), "test message");
    await tester.pump();

    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();
    await tester.pump();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;
    expect(find.byType(PromptInput), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, "test message");
    expect(find.bySemanticsLabel("screenshot.png"), findsOneWidget);
    expect(find.text(loc.newSessionCreationDuplicateWarning), findsOneWidget);
    expect(tester.widget<PromptInput>(find.byType(PromptInput)).restorationKey, isNull);
    expect(
      tester.element(find.byType(PromptInput)).read<NewSessionCubit>().state,
      isA<NewSessionComposing>().having((state) => state.phase, "phase", isA<NewSessionPhaseCreationError>()),
    );
    expect(creationCalls, 1);
    expect(identical(submittedAttachments.single.single, attachment), isTrue);

    await tester.pump();
    expect(find.bySemanticsLabel("screenshot.png"), findsOneWidget);
    expect(find.text(loc.newSessionCreationDuplicateWarning), findsOneWidget);

    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    expect(creationCalls, 2);
    expect(identical(submittedAttachments.last.single, attachment), isTrue);
  });

  testWidgets("removes the sending bubble and keeps retry UI usable after an error", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        fastMode: any(named: "fastMode"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byType(QueuedMessageBubble), findsOneWidget);

    createCompleter.complete(ApiResponse.error(ApiError.generic()));
    await tester.pumpAndSettle();

    expect(find.byType(QueuedMessageBubble), findsNothing);
    // Error text now comes from the shared, localized ApiError mapping.
    expect(find.text("An unknown error occurred"), findsOneWidget);

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;
    expect(find.text("test message"), findsOneWidget);
    expect(find.text(loc.newSessionCreationDuplicateWarning), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
    expect(find.byIcon(TablerRegular.arrow_up), findsOneWidget);

    await tester.enterText(find.byType(EditableText), "retry message");
    await tester.pump();

    expect(find.text("retry message"), findsOneWidget);
  });

  testWidgets("persists and restores the per-project new-session draft", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await tester.enterText(find.byType(EditableText), "half-written idea");
    await tester.pump();

    // Tear the screen down (e.g. the user navigates away) before creating a
    // session. The owning Cubit has already persisted the immutable draft.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(
      composerDraftRepository.readForNewSession(projectId: "project-1"),
      ComposerDraft.typed(text: "half-written idea"),
    );

    // Re-open the new-session screen — the per-project draft is restored.
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.text("half-written idea"), findsOneWidget);
  });

  group("the composer and a card trade places", () {
    const frame = Duration(milliseconds: 16);
    const loginRequired = SessionOptionsRepositoryAuthenticationRequired(
      actionHint: "Run the harness locally and use /login.",
    );
    final card = find.byKey(const Key("new_session_login_required"));
    final composer = find.byType(PromptInput);
    final header = find.byType(NewSessionHeader);
    final worktreeToggle = find.byKey(const Key("new_session_dedicated_workspace"));

    /// Answers the options with [first] and every later load with the
    /// returned completer.
    Completer<SessionOptionsRepositoryResult> stubOptions({required SessionOptionsRepositoryResult first}) {
      final later = Completer<SessionOptionsRepositoryResult>();
      var loads = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) => loads++ == 0 ? Future.value(first) : later.future);
      return later;
    }

    Future<void> pumpPhone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
    }

    /// How opaque [finder]'s widget paints, or null while it is not on screen.
    double? opacityOf(WidgetTester tester, Finder finder) {
      if (finder.evaluate().isEmpty) return null;
      var opacity = 1.0;
      for (final fade in tester.widgetList<FadeTransition>(
        find.ancestor(of: finder, matching: find.byType(FadeTransition)),
      )) {
        opacity *= fade.opacity.value;
      }
      return opacity;
    }

    /// The top edge of the room the card and the composer share, where the
    /// options' scroll view above it ends.
    double roomTop(WidgetTester tester) => tester.getRect(find.byKey(const Key("new_session_options_scroll"))).bottom;

    /// Steps 16 ms frames until the swap has long finished, expecting the
    /// header and the options above it, and the card and the composer each
    /// while on screen, to hold still, and returns every frame's opacities
    /// and room top.
    Future<List<({double? card, double? composer, double roomTop})>> stepThroughSwap({
      required WidgetTester tester,
      required Rect cardRect,
      required Rect composerRect,
    }) async {
      final headerRect = tester.getRect(header);
      final toggleRect = tester.getRect(worktreeToggle);
      final frames = [(card: opacityOf(tester, card), composer: opacityOf(tester, composer), roomTop: roomTop(tester))];
      for (var elapsed = Duration.zero; elapsed <= const Duration(milliseconds: 400); elapsed += frame) {
        await tester.pump(frame);
        expect(tester.getRect(header), headerRect);
        expect(tester.getRect(worktreeToggle), toggleRect);
        if (card.evaluate().isNotEmpty) expect(tester.getRect(card), cardRect);
        if (composer.evaluate().isNotEmpty) expect(tester.getRect(composer), composerRect);
        frames.add((card: opacityOf(tester, card), composer: opacityOf(tester, composer), roomTop: roomTop(tester)));
      }
      return frames;
    }

    /// Expects [frames] to show [leaving] fading out as [arriving] fades in
    /// over it, both on screen together, and the room's top edge easing by
    /// [travel] over many frames rather than jumping.
    void expectCrossFade({
      required List<({double? card, double? composer, double roomTop})> frames,
      required double? Function(({double? card, double? composer, double roomTop})) leaving,
      required double? Function(({double? card, double? composer, double roomTop})) arriving,
      required double travel,
    }) {
      final together = [
        for (final frame in frames)
          if ((leaving(frame), arriving(frame)) case (final out?, final into?) when out > 0 && into < 1) frame,
      ];
      expect(together.length, greaterThan(5));
      final outs = <double>[for (final frame in frames) ?leaving(frame)];
      final ins = <double>[for (final frame in frames) ?arriving(frame)];
      expect(outs, orderedEquals(outs.toList()..sort((a, b) => b.compareTo(a))));
      expect(ins, orderedEquals(ins.toList()..sort()));
      expect(leaving(frames.last), isNull);
      expect(arriving(frames.last), 1);

      final tops = [for (final frame in frames) frame.roomTop];
      expect(tops.last - tops.first, moreOrLessEquals(travel, epsilon: 0.5));
      for (var index = 1; index < tops.length; index++) {
        final step = tops[index] - tops[index - 1];
        expect(step.sign, anyOf(0, travel.sign));
        // The steepest 16 ms of the 200 ms ease covers about an eighth.
        expect(step.abs(), lessThan(travel.abs() / 6));
      }
    }

    testWidgets("Recheck's answer fades the login card out as the composer fades in over it", (tester) async {
      final recheck = stubOptions(first: loginRequired);
      await pumpPhone(tester);
      final cardRect = tester.getRect(card);
      final startTop = roomTop(tester);

      // The press itself shows in place: the card neither fades nor moves.
      await tester.tap(find.byKey(const Key("session_harness_recheck")));
      for (var index = 0; index < 20; index++) {
        await tester.pump(frame);
        expect(opacityOf(tester, card), 1);
        expect(tester.getRect(card), cardRect);
        expect(composer, findsNothing);
      }
      expect(roomTop(tester), startTop);

      recheck.complete(SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false));
      await tester.pump();
      final composerRect = tester.getRect(composer);
      // Both rest on the bottom edge.
      expect(composerRect.bottom, cardRect.bottom);
      final frames = await stepThroughSwap(tester: tester, cardRect: cardRect, composerRect: composerRect);

      expectCrossFade(
        frames: frames,
        leaving: (frame) => frame.card,
        arriving: (frame) => frame.composer,
        travel: cardRect.height - composerRect.height,
      );
      expect(find.byType(AgentModelButtons), findsOneWidget);
    });

    /// Presses [blocked]'s Recheck, holds the answer until the spinner shows,
    /// then lets [answer] land: every frame until the card is gone, it keeps
    /// the spinner as it stood and never says Recheck again.
    Future<void> expectCardLeavesChecking({
      required WidgetTester tester,
      required Finder blocked,
      required void Function() answer,
    }) async {
      final recheck = find.descendant(of: blocked, matching: find.byKey(const Key("session_harness_recheck")));
      final spinner = find.descendant(of: recheck, matching: find.byType(PregoActivityIndicator));
      final label = find.descendant(of: recheck, matching: find.text("Recheck"));
      await tester.tap(recheck);
      for (var index = 0; index < 35; index++) {
        await tester.pump(frame);
      }
      expect(opacityOf(tester, spinner), 1);
      expect(opacityOf(tester, label), 0);

      answer();
      var fading = 0;
      for (var elapsed = Duration.zero; elapsed <= const Duration(milliseconds: 400); elapsed += frame) {
        await tester.pump(frame);
        final cardOpacity = opacityOf(tester, blocked);
        if (cardOpacity == null) continue;
        if (cardOpacity < 1) fading++;
        expect(opacityOf(tester, spinner), cardOpacity);
        expect(opacityOf(tester, label), 0);
      }
      expect(fading, greaterThan(5));
      expect(blocked, findsNothing);
      expect(opacityOf(tester, composer), 1);
    }

    testWidgets("the login card fades out still showing the check its answer ended", (tester) async {
      final recheck = stubOptions(first: loginRequired);
      await pumpPhone(tester);

      await expectCardLeavesChecking(
        tester: tester,
        blocked: card,
        answer: () => recheck.complete(
          SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false),
        ),
      );
    });

    testWidgets("the project card fades out still showing the check its answer ended", (tester) async {
      final recheck = Completer<ApiResponse<Project>>();
      var checks = 0;
      when(() => projectRepository.getProject(projectId: any(named: "projectId"))).thenAnswer((_) {
        checks++;
        return checks == 1 ? Future.value(ApiResponse<Project>.error(ApiError.generic())) : recheck.future;
      });
      await pumpPhone(tester);

      await expectCardLeavesChecking(
        tester: tester,
        blocked: find.byKey(const Key("new_session_project_unavailable")),
        answer: () => recheck.complete(
          ApiResponse.success(
            const Project(
              id: "project-1",
              name: "Project One",
              path: "/project-one",
              time: null,
              supportsDedicatedWorktrees: true,
              voiceGlossaryKey: null,
            ),
          ),
        ),
      );
    });

    testWidgets("a login card called back as it fades turns back from where it is and checks as before", (
      tester,
    ) async {
      // Recheck finds the harness logged in, a reconnect as the card fades
      // finds it logged out again, and the next Recheck waits for its answer.
      final loggedIn = Completer<SessionOptionsRepositoryResult>();
      final nextRecheck = Completer<SessionOptionsRepositoryResult>();
      var loads = 0;
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) {
        loads++;
        return switch (loads) {
          2 => loggedIn.future,
          4 => nextRecheck.future,
          _ => Future.value(loginRequired),
        };
      });
      await pumpPhone(tester);
      final recheck = find.byKey(const Key("session_harness_recheck"));
      final spinner = find.descendant(of: recheck, matching: find.byType(PregoActivityIndicator));
      final label = find.descendant(of: recheck, matching: find.text("Recheck"));
      final cardRect = tester.getRect(card);
      await tester.tap(recheck);
      for (var index = 0; index < 35; index++) {
        await tester.pump(frame);
      }

      loggedIn.complete(SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false));
      final opacities = <double>[];
      for (var index = 0; index < 30; index++) {
        if (index == 4) connectionStatus.add(const ConnectionStatus.disconnected());
        if (index == 5) {
          connectionStatus.add(
            const ConnectionStatus.connected(
              config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
              health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
            ),
          );
        }
        await tester.pump(frame);
        opacities.add(opacityOf(tester, card) ?? 0);
      }
      expect(loads, 3);

      // It turns back partway rather than vanishing or snapping back.
      final lowest = opacities.reduce(math.min);
      final turn = opacities.indexOf(lowest);
      expect(lowest, inExclusiveRange(0, 1));
      expect(
        opacities.take(turn + 1),
        orderedEquals(opacities.take(turn + 1).toList()..sort((a, b) => b.compareTo(a))),
      );
      expect(opacities.skip(turn), orderedEquals(opacities.skip(turn).toList()..sort()));
      for (var index = 1; index < opacities.length; index++) {
        expect((opacities[index] - opacities[index - 1]).abs(), lessThan(1 / 6));
      }
      expect(opacities.last, 1);
      expect(tester.getRect(card), cardRect);
      expect(opacityOf(tester, label), 1);
      expect(spinner, findsNothing);

      // Back, its Recheck shows that it is checking just as before.
      final labelOpacities = <double>[];
      await tester.tap(recheck);
      for (var index = 0; index < 35; index++) {
        await tester.pump(frame);
        labelOpacities.add(opacityOf(tester, label) ?? 0);
      }
      expect(loads, 4);
      expect(labelOpacities.where((opacity) => opacity > 0 && opacity < 1), isNotEmpty);
      expect(opacityOf(tester, label), 0);
      expect(opacityOf(tester, spinner), 1);
      nextRecheck.complete(loginRequired);
      await tester.pumpAndSettle();
      expect(opacityOf(tester, label), 1);
      expect(spinner, findsNothing);
    });

    testWidgets("a harness found logged out fades the composer out under the login card, keeping its draft", (
      tester,
    ) async {
      final refresh = stubOptions(
        first: SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: true),
      );
      await pumpPhone(tester);
      await enterTypingMode(tester);
      await tester.enterText(find.byType(EditableText), "half-written idea");
      await tester.pump();
      final promptState = tester.state(composer);
      final composerRect = tester.getRect(composer);
      final field = tester.widget<EditableText>(find.byType(EditableText)).focusNode;
      expect(field.hasFocus, isTrue);

      refresh.complete(loginRequired);
      await tester.pump();
      // Leaving, the composer lets go of the keyboard at once.
      expect(field.hasFocus, isFalse);
      final cardRect = tester.getRect(card);
      expect(cardRect.bottom, composerRect.bottom);
      final frames = await stepThroughSwap(tester: tester, cardRect: cardRect, composerRect: composerRect);

      expectCrossFade(
        frames: frames,
        leaving: (frame) => frame.composer,
        arriving: (frame) => frame.card,
        travel: composerRect.height - cardRect.height,
      );

      // Behind the card the composer is the same one, draft and all, and it
      // comes back as it was.
      final relogin = Completer<SessionOptionsRepositoryResult>();
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) => relogin.future);
      await tester.tap(find.byKey(const Key("session_harness_recheck")));
      await tester.pump();
      relogin.complete(SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false));
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(tester.state(composer), same(promptState));
      expect(find.text("half-written idea"), findsOneWidget);
    });

    testWidgets("pills arriving while the composer is typed in neither fade it nor take its focus", (tester) async {
      final options = Completer<SessionOptionsRepositoryResult>();
      when(
        () => sessionRepository.loadSessionOptions(
          projectId: "project-1",
          pluginId: "plugin-1",
          mode: any(named: "mode"),
        ),
      ).thenAnswer((_) => options.future);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(TablerRegular.keyboard));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(EditableText), "half-written idea");
      await tester.pump();
      final field = find.byType(EditableText);
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      final composerBottom = tester.getRect(composer).bottom;

      options.complete(SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false));
      for (var index = 0; index < 25; index++) {
        await tester.pump(frame);
        expect(opacityOf(tester, composer), 1);
        expect(tester.getRect(composer).bottom, composerBottom);
        expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
      }
      expect(find.byType(AgentModelButtons), findsOneWidget);
      expect(find.text("half-written idea"), findsOneWidget);
    });

    testWidgets("reduced motion swaps the login card for the composer in one frame", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final recheck = stubOptions(first: loginRequired);
      await pumpPhone(tester);
      final cardRect = tester.getRect(card);
      await tester.tap(find.byKey(const Key("session_harness_recheck")));
      await tester.pump();

      recheck.complete(SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false));
      await tester.pump();
      expect(card, findsNothing);
      expect(opacityOf(tester, composer), 1);
      final settledTop = roomTop(tester);
      expect(settledTop - cardRect.top, cardRect.height - tester.getRect(composer).height);
      for (var index = 0; index < 15; index++) {
        await tester.pump(frame);
        expect(roomTop(tester), settledTop);
      }
    });
  });
}
