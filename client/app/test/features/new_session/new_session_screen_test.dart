import "dart:async";
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
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_discovery_snapshot.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/repositories/plugin_preference_repository.dart";
import "package:sesori_mobile/capabilities/media/composer_image_picker.dart";
import "package:sesori_mobile/features/new_session/new_session_plugin_chooser.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/features/session_detail/widgets/prompt_input.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";
import "../../helpers/voice_test_helpers.dart";

class MockComposerImagePicker() extends Mock implements ComposerImagePicker;

class MockImageClipboard() extends Mock implements ImageClipboard;

class MockPluginRepository() extends Mock implements PluginRepository;

class MockPluginPreferenceRepository() extends Mock implements PluginPreferenceRepository;

class _MockSessionListCubit() extends MockCubit<SessionListState> implements SessionListCubit;

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
  agents: [_testAgent(name: "coder", description: "A coding assistant", variant: "xhigh")],
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
  ThemeMode themeMode = ThemeMode.light,
  SessionListState sessionListState = const SessionListState.loaded(
    sessions: [],
    baseBranch: null,
    repoSlug: null,
  ),
}) {
  final router = GoRouter(
    initialLocation: "/projects/project-1/sessions/new",
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
        routes: [
          GoRoute(
            path: "projects/:projectId/sessions/new",
            builder: (context, state) => const NewSessionScreen(
              projectId: "project-1",
              projectName: "Project One",
            ),
          ),
        ],
      ),
      GoRoute(
        path: "/settings/harnesses",
        builder: (context, state) => const Material(child: Text("harnesses-settings")),
      ),
      GoRoute(
        path: "/projects/:projectId/sessions/:sessionId",
        builder: (context, state) {
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

  // The screen wears the sessions bar, whose second line comes from the
  // project's session-list cubit — the sessions shell provides it in the app.
  final sessionListCubit = _MockSessionListCubit();
  when(() => sessionListCubit.state).thenReturn(sessionListState);
  whenListen(sessionListCubit, const Stream<SessionListState>.empty(), initialState: sessionListState);

  return MultiBlocProvider(
    providers: [
      BlocProvider<ConnectionOverlayCubit>(create: (_) => StubConnectionOverlayCubit()),
      BlocProvider<ChatInputModeCubit>(create: (_) => StubChatInputModeCubit()),
      BlocProvider<SessionListCubit>.value(value: sessionListCubit),
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
  late MockComposerImagePicker imagePicker;
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
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
        health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
      ),
    );
    projectRepository = MockProjectRepository();
    voiceTranscriptionService = MockVoiceTranscriptionService();
    imagePicker = MockComposerImagePicker();
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
        defaultModelSelector: const DefaultModelSelector(),
      ),
    );
    GetIt.instance.registerSingleton<ConnectionService>(connectionService);
    GetIt.instance.registerSingleton<CatalogRescanService>(FakeCatalogRescanService());
    GetIt.instance.registerSingleton<ProjectRepository>(projectRepository);
    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
    GetIt.instance.registerSingleton<ComposerImagePicker>(imagePicker);
    GetIt.instance.registerSingleton<ImageClipboard>(imageClipboard);
    GetIt.instance.registerSingleton<NewSessionSelectionTracker>(NewSessionSelectionTracker());
    GetIt.instance.registerSingleton<ComposerDraftRepository>(composerDraftRepository);
    GetIt.instance.registerSingleton<ProductAnalyticsService>(productAnalyticsService);
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

    expect(find.text(loc.newSessionProjectUnavailable), findsOneWidget);
    // The status line above names what is missing; the action keeps the one
    // name it has in every state.
    expect(find.widgetWithText(PregoButtonsSolid, loc.newSessionOptionsRefresh), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.ancestor(of: find.byType(PromptInput), matching: find.byType(IgnorePointer)).first,
          )
          .ignoring,
      isTrue,
    );

    await tester.tap(find.byKey(const Key("new_session_options_refresh")));
    await tester.pumpAndSettle();

    expect(find.text(loc.newSessionProjectUnavailable), findsNothing);
    expect(find.byType(PregoSwitch), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.ancestor(of: find.byType(PromptInput), matching: find.byType(IgnorePointer)).first,
          )
          .ignoring,
      isFalse,
    );
  });

  testWidgets("old bridge guidance keeps Create available and Refresh uses legacy routes", (tester) async {
    when(() => voiceTranscriptionService.start(session: voiceSession)).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession)).thenAnswer((_) async => "");
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

    expect(find.text(loc.newSessionOptionsLegacyBridge), findsOneWidget);
    expect(find.byKey(const Key("new_session_options_refresh")), findsOneWidget);
    final composerPointer = tester.widget<IgnorePointer>(
      find.ancestor(of: find.byType(PromptInput), matching: find.byType(IgnorePointer)).first,
    );
    expect(composerPointer.ignoring, isFalse);
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
    expect(find.text(loc.voiceReleaseToTranscribe), findsOneWidget);
    expect(tester.getSize(find.byType(PromptInput)).height, closeTo(restingComposerHeight, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("new_session_options_refresh")));
    await tester.pumpAndSettle();

    verify(() => sessionService.listAgents(projectId: "project-1", pluginId: "plugin-1")).called(1);
    verify(() => sessionService.listProviders(projectId: "project-1", pluginId: "plugin-1")).called(1);
    verify(() => sessionService.listCommands(projectId: "project-1", pluginId: "plugin-1")).called(1);
    expect(find.widgetWithText(PregoPickerButton, "coder"), findsOneWidget);
    expect(find.text(loc.newSessionOptionsLegacyBridge), findsOneWidget);
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
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(testSession(id: "session-cache-miss")));

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;
    expect(find.text(loc.newSessionOptionsUnavailable), findsOneWidget);

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
        command: null,
        dedicatedWorktree: true,
      ),
    ).called(1);
  });

  testWidgets("failed dynamic load uses load guidance instead of refresh guidance", (tester) async {
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: SessionOptionsRequestMode.dynamic,
      ),
    ).thenAnswer((_) async => const SessionOptionsRepositoryRefreshFailedUnavailable());

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    expect(find.text(loc.newSessionOptionsLoadFailedUnavailable), findsOneWidget);
    expect(find.text(loc.newSessionOptionsRefreshFailedUnavailable), findsNothing);
  });

  testWidgets("authentication-required options show guidance and block creation until refresh recovers", (
    tester,
  ) async {
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
    final alert = find.widgetWithText(
      PregoPopupAlertsNotifications,
      loc.newSessionAuthenticationRequiredTitle("Plugin One"),
    );

    expect(alert, findsOneWidget);
    expect(
      find.descendant(of: alert, matching: find.text("Run the harness locally and use /login.")),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IgnorePointer>(
            find.ancestor(of: find.byType(PromptInput), matching: find.byType(IgnorePointer)).first,
          )
          .ignoring,
      isTrue,
    );

    await tester.tap(find.byKey(const Key("new_session_options_refresh")));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PregoPickerButton, "coder"), findsOneWidget);
    expect(
      tester
          .widget<IgnorePointer>(
            find.ancestor(of: find.byType(PromptInput), matching: find.byType(IgnorePointer)).first,
          )
          .ignoring,
      isFalse,
    );
  });

  testWidgets("refresh action stops spinning for a harness the user left behind", (tester) async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: const [
            PluginMetadata(
              id: "plugin-1",
              displayName: "First Tool",
              isDefault: true,
              state: PluginLifecycleState.ready,
              actionHint: null,
            ),
            PluginMetadata(
              id: "plugin-2",
              displayName: "Second Tool",
              isDefault: false,
              state: PluginLifecycleState.ready,
              actionHint: null,
            ),
          ],
        ),
      ),
    );
    // The first harness's refresh never answers.
    final stranded = Completer<SessionOptionsRepositoryResult>();
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: any(named: "mode"),
      ),
    ).thenAnswer((invocation) async {
      return invocation.namedArguments[#mode] == SessionOptionsRequestMode.forceRefresh
          ? await stranded.future
          : SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false);
    });
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-2",
        mode: any(named: "mode"),
      ),
    ).thenAnswer((_) async => SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false));

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final refreshAction = find.byKey(const Key("new_session_options_refresh"));

    await tester.tap(refreshAction);
    await tester.pump();
    expect(tester.widget<PregoButtonsSolid>(refreshAction).isLoading, isTrue);

    // Explicit pumps throughout: pumpAndSettle never returns while the
    // indeterminate spinner is on screen.
    await tester.tap(find.byKey(const Key("new_session_plugin_trigger")));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(_harnessRow("plugin-2"));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The second harness has its own settled options; the first harness's
    // request is still outstanding and must not hold this action hostage.
    expect(tester.widget<PregoButtonsSolid>(refreshAction).isLoading, isFalse);
    expect(tester.widget<PregoButtonsSolid>(refreshAction).onPressed, isNotNull);
  });

  testWidgets("refresh action stays in view and spins while its load runs", (tester) async {
    final refreshed = Completer<SessionOptionsRepositoryResult>();
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: any(named: "mode"),
      ),
    ).thenAnswer((invocation) async {
      final mode = invocation.namedArguments[#mode]! as SessionOptionsRequestMode;
      return mode == SessionOptionsRequestMode.forceRefresh
          ? await refreshed.future
          : SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false);
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final refreshAction = find.byKey(const Key("new_session_options_refresh"));

    await tester.tap(refreshAction);
    await tester.pump();

    expect(refreshAction, findsOneWidget);
    expect(tester.widget<PregoButtonsSolid>(refreshAction).isLoading, isTrue);

    refreshed.complete(SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false));
    await tester.pumpAndSettle();

    expect(tester.widget<PregoButtonsSolid>(refreshAction).isLoading, isFalse);
  });

  testWidgets("retained refresh failure keeps cached options visible", (tester) async {
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: any(named: "mode"),
      ),
    ).thenAnswer((invocation) async {
      final mode = invocation.namedArguments[#mode]! as SessionOptionsRequestMode;
      return mode == SessionOptionsRequestMode.forceRefresh
          ? const SessionOptionsRepositoryRefreshFailedRetained()
          : SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false);
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;
    expect(find.text(loc.newSessionOptionsCached), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "coder"), findsOneWidget);

    await tester.tap(find.byKey(const Key("new_session_options_refresh")));
    await tester.pumpAndSettle();

    expect(find.text(loc.newSessionOptionsUpdateFailedRetained), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "coder"), findsOneWidget);
  });

  testWidgets("unavailable refresh failure clears options immediately", (tester) async {
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        mode: any(named: "mode"),
      ),
    ).thenAnswer((invocation) async {
      final mode = invocation.namedArguments[#mode]! as SessionOptionsRequestMode;
      return mode == SessionOptionsRequestMode.forceRefresh
          ? const SessionOptionsRepositoryRefreshFailedUnavailable()
          : SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog(), isStale: false);
    });

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;
    expect(find.widgetWithText(PregoPickerButton, "coder"), findsOneWidget);

    await tester.tap(find.byKey(const Key("new_session_options_refresh")));
    await tester.pumpAndSettle();

    expect(find.text(loc.newSessionOptionsRefreshFailedUnavailable), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "coder"), findsNothing);
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
      find.descendant(of: _harnessRow("degraded-id"), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _harnessRow("other-id"), matching: find.byIcon(Icons.check)),
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

    expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    expect(find.widgetWithText(PregoPickerButton, "Claude 3.5 Sonnet"), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);
  });

  testWidgets("scrolls plugin and worktree options while keeping the composer pinned", (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 400));
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

    // The refresh action floats above the composer rather than riding the
    // options it reloads, so scrolling must not carry it away.
    final refresh = find.byKey(const Key("new_session_options_refresh"));
    expect(find.descendant(of: optionsScroll, matching: refresh), findsNothing);

    final composerTop = tester.getTopLeft(find.byType(PromptInput)).dy;
    final refreshRect = tester.getRect(refresh);
    expect(refreshRect.bottom, lessThanOrEqualTo(composerTop));

    await tester.drag(optionsScroll, const Offset(0, -250));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(PromptInput)).dy, closeTo(composerTop, 0.01));
    expect(tester.getRect(refresh), refreshRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets("scrolls the last option clear of the refresh at a large text scale", (tester) async {
    // The refresh pill is padding around its label, not a fixed box, so it
    // grows with the text scale. The band reserved beneath the options has to
    // grow with it or the last row stays stranded underneath.
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.binding.setSurfaceSize(const Size(700, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    final optionsScroll = find.byKey(const Key("new_session_options_scroll"));
    final refresh = find.byKey(const Key("new_session_options_refresh"));

    final scrollRect = tester.getRect(optionsScroll);
    await tester.dragFrom(Offset(scrollRect.center.dx, scrollRect.top + 8), const Offset(0, -2000));
    await tester.pumpAndSettle();

    // Scrolled to the end, the reserved band must still span everything the
    // pill covers — measured, so it holds however tall the pill has grown.
    final reserved = tester.widget<SingleChildScrollView>(optionsScroll).padding! as EdgeInsetsDirectional;
    expect(reserved.bottom, greaterThanOrEqualTo(scrollRect.bottom - tester.getRect(refresh).top));
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
            agents: [_testAgent(name: "coder", description: "Coder", variant: "xhigh")],
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
    final disabledComposer = find.ancestor(
      of: find.byType(PromptInput),
      matching: find.byWidgetPredicate((widget) => widget is IgnorePointer && widget.ignoring),
    );
    expect(disabledComposer, findsOneWidget);

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
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    );
    toolBAgents.complete(ApiResponse.success(const Agents(agents: [])));
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
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
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
      find.descendant(of: _harnessRow("tool-a"), matching: find.byIcon(Icons.check)),
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
      find.descendant(of: _harnessRow("tool-b"), matching: find.byIcon(Icons.check)),
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
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
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
    expect(
      tester.widget<PregoButtonsSolid>(find.byKey(const Key("new_session_options_refresh"))).onPressed,
      isNull,
    );
    expect(
      find.ancestor(
        of: find.byType(PromptInput),
        matching: find.byWidgetPredicate((widget) => widget is IgnorePointer && widget.ignoring),
      ),
      findsOneWidget,
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
    expect(
      find.ancestor(
        of: find.byType(PromptInput),
        matching: find.byWidgetPredicate((widget) => widget is IgnorePointer && widget.ignoring),
      ),
      findsOneWidget,
    );

    // The disabled composer ignores pointers entirely: the keyboard affordance
    // cannot even enter the typing layout, so no field or send control exists
    // to submit through.
    await tester.tap(find.byIcon(TablerRegular.keyboard), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing);
    expect(find.byIcon(TablerRegular.arrow_up), findsNothing);
    await tester.pump();
    verifyNever(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
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
    expect(find.byKey(const Key("new_session_options_refresh")), findsNothing);
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
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
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
    expect(
      tester
          .widget<IgnorePointer>(
            find.ancestor(of: find.byType(PromptInput), matching: find.byType(IgnorePointer)).first,
          )
          .ignoring,
      isFalse,
    );
  });

  testWidgets("keeps discovery retry when discovery fails before finding a harness", (tester) async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null)),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    expect(find.text(loc.apiErrorServerRejected), findsOneWidget);
    final refresh = find.byKey(const Key("new_session_options_refresh"));
    expect(tester.widget<PregoButtonsSolid>(refresh).label, loc.newSessionOptionsRefresh);
    expect(tester.widget<PregoButtonsSolid>(refresh).onPressed, isNotNull);
    // The bridge never confirmed an empty harness list, so the error banner is
    // the honest explanation and discovery remains retryable.
    expect(find.byKey(const Key("new_session_no_harness_notice")), findsNothing);
    expect(find.text(loc.newSessionDedicatedWorkspace), findsNothing);
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
                  id: "claude-3-5-sonnet",
                  providerID: "anthropic",
                  name: "Claude 3.5 Sonnet",
                  variants: ["xhigh", "low"],
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
                  id: "claude-3-5-sonnet",
                  providerID: "anthropic",
                  name: "Claude 3.5 Sonnet",
                  variants: ["xhigh", "low"],
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

  testWidgets("shows detail-shaped launch status during sending", (tester) async {
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

    expect(find.byType(PregoLaunchStatus), findsOneWidget);
    expect(find.byType(PromptInput), findsNothing);
    expect(find.bySemanticsLabel(loc.newSessionLoadingSemantics), findsOneWidget);
    expect(find.text(loc.newSessionLoadingMessage1), findsOneWidget);
    expect(find.text(loc.sessionListNewSession), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.byType(PregoLaunchStatus))).routeInformationProvider.value.uri.path,
      "/projects/project-1/sessions/new",
    );
  });

  testWidgets("removes composer and closes its voice lifecycle while a session is sending", (tester) async {
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
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byType(PromptInput), findsNothing);
    expect(find.byIcon(TablerSolid.player_stop), findsNothing);
    expect(find.byIcon(TablerRegular.arrow_up), findsNothing);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    verify(() => voiceTranscriptionService.invalidate(session: voiceSession)).called(1);
    verify(() => voiceTranscriptionService.close(session: voiceSession)).called(1);

    verify(
      () => sessionService.createSessionWithMessage(
        attachments: const [],
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        model: any(named: "model"),
        variant: any(named: "variant"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
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

    expect(find.byType(PregoLaunchStatus), findsOneWidget);

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

    expect(find.byType(PregoLaunchStatus), findsOneWidget);

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
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byType(PregoLaunchStatus), findsOneWidget);

    createCompleter.complete(ApiResponse.success(testSession(id: "session-1", title: null)));
    await tester.pumpAndSettle();

    expect(find.text("session-detail:session-1"), findsOneWidget);
    expect(
      find.text("uri:/projects/project-1/sessions/session-1?readOnly=false&name=Project+One"),
      findsOneWidget,
    );
    expect(find.byType(NewSessionScreen), findsNothing);
    expect(find.byType(EditableText), findsNothing);
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

    expect(find.byType(PregoLaunchStatus), findsOneWidget);

    createCompleter.complete(ApiResponse.success(testSession(id: "session-1", title: "Created session")));
    await tester.pumpAndSettle();

    expect(find.text("session-detail:session-1"), findsOneWidget);
    expect(find.byType(NewSessionScreen), findsNothing);
    expect(find.text(loc.newSessionLaunchingInBackground), findsNothing);
  });

  testWidgets("restores a coalesced failed submission without remounting the composer", (tester) async {
    final attachment = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: "screenshot.png");
    when(imagePicker.pickImage).thenAnswer((_) async => attachment);
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
    await tester.tap(find.byIcon(TablerRegular.photo));
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

  testWidgets("removes the loading overlay and keeps retry UI usable after an error", (tester) async {
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
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byType(PregoLaunchStatus), findsOneWidget);

    createCompleter.complete(ApiResponse.error(ApiError.generic()));
    await tester.pumpAndSettle();

    expect(find.byType(PregoLaunchStatus), findsNothing);
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
}
