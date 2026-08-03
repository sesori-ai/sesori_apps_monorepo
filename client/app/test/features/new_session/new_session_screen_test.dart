import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/new_session/new_session_plugin_chooser.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/features/session_detail/widgets/prompt_input.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class MockVoiceTranscriptionService extends Mock implements VoiceTranscriptionService {}

class MockPluginRepository extends Mock implements PluginRepository {}

class MockPluginPreferenceRepository extends Mock implements PluginPreferenceRepository {}

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
  commands: const [],
);

Finder _pickerMenuItem(String label) => find.descendant(
  of: find.byType(SingleChildScrollView),
  matching: find.widgetWithText(InkWell, label),
);

Widget _buildApp({
  ThemeMode themeMode = ThemeMode.light,
  bool? initialSupportsDedicatedWorktrees = true,
}) {
  final router = GoRouter(
    initialLocation: "/new",
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
        routes: [
          GoRoute(
            path: "new",
            builder: (context, state) => NewSessionScreen(
              projectId: "project-1",
              projectName: "Project One",
              initialSupportsDedicatedWorktrees: initialSupportsDedicatedWorktrees,
            ),
          ),
        ],
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

  return MultiBlocProvider(
    providers: [
      BlocProvider<ConnectionOverlayCubit>(create: (_) => StubConnectionOverlayCubit()),
      BlocProvider<ChatInputModeCubit>(create: (_) => StubChatInputModeCubit()),
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
  late MockSessionService sessionService;
  late MockSessionRepository sessionRepository;
  late MockPluginRepository pluginRepository;
  late MockPluginPreferenceRepository pluginPreferenceRepository;
  late MockConnectionService connectionService;
  late BehaviorSubject<ConnectionStatus> connectionStatus;
  late MockProjectRepository projectRepository;
  late MockVoiceTranscriptionService voiceTranscriptionService;
  late ComposerDraftRepository composerDraftRepository;
  late MockProductAnalyticsService productAnalyticsService;

  setUpAll(registerAllFallbackValues);

  // Composer pickers force PregoAnchorMenu's flat cue path on every platform,
  // so the menu rows are Material InkWells.
  setUp(() async {
    KeyboardVisibilityTesting.setVisibilityForTesting(false);
    await GetIt.instance.reset();
    sessionService = MockSessionService();
    sessionRepository = MockSessionRepository();
    pluginRepository = MockPluginRepository();
    pluginPreferenceRepository = MockPluginPreferenceRepository();
    connectionService = MockConnectionService();
    connectionStatus = BehaviorSubject.seeded(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com"),
        health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: null),
      ),
    );
    projectRepository = MockProjectRepository();
    voiceTranscriptionService = MockVoiceTranscriptionService();
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
        forceRefresh: any(named: "forceRefresh"),
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
            catalog: SessionOptionsCatalog(
              agents: agentData.agents,
              providers: providerData.items,
              commands: commandData.items,
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
              commands: commandData.items,
            ),
          ),
        (ErrorResponse(:final error), _, _) => LegacySessionOptionsRepositoryFailure(error: error),
        (_, ErrorResponse(:final error), _) => LegacySessionOptionsRepositoryFailure(error: error),
        (_, _, ErrorResponse(:final error)) => LegacySessionOptionsRepositoryFailure(error: error),
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
        ),
      ),
    );

    final maxDurationReached = StreamController<void>.broadcast();
    addTearDown(maxDurationReached.close);
    when(() => voiceTranscriptionService.onMaxDurationReached).thenAnswer((_) => maxDurationReached.stream);
    when(() => voiceTranscriptionService.prewarmRecording()).thenAnswer((_) async {});

    when(
      () => pluginPreferenceRepository.readPluginId(bridgeId: any(named: "bridgeId")),
    ).thenAnswer((_) async => null);
    when(
      () => pluginPreferenceRepository.writePluginId(
        bridgeId: any(named: "bridgeId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer((_) async {});

    GetIt.instance.registerSingleton<SessionService>(sessionService);
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
    GetIt.instance.registerSingleton<ProjectRepository>(projectRepository);
    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
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

  testWidgets("known unsupported project never shows the worktree toggle while composer data loads", (tester) async {
    final projectResponse = Completer<ApiResponse<Project>>();
    when(
      () => projectRepository.getProject(projectId: any(named: "projectId")),
    ).thenAnswer((_) => projectResponse.future);

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: false));
    await tester.pump();

    expect(find.byType(SwitchListTile), findsNothing);

    projectResponse.complete(
      ApiResponse.success(
        const Project(
          id: "project-1",
          name: "Project One",
          path: "/project-one",
          time: null,
          supportsDedicatedWorktrees: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets("old bridge guidance keeps Create available and Refresh uses legacy routes", (tester) async {
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "");
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
        forceRefresh: any(named: "forceRefresh"),
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
        forceRefresh: false,
      ),
    ).thenAnswer((_) async => const SessionOptionsRepositoryCacheUnavailable());
    when(
      () => sessionService.createSessionWithMessage(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
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
        projectId: "project-1",
        pluginId: "plugin-1",
        text: "use backend defaults",
        agent: null,
        providerID: null,
        modelID: null,
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
        forceRefresh: false,
      ),
    ).thenAnswer((_) async => const SessionOptionsRepositoryRefreshFailedUnavailable());

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    expect(find.text(loc.newSessionOptionsLoadFailedUnavailable), findsOneWidget);
    expect(find.text(loc.newSessionOptionsRefreshFailedUnavailable), findsNothing);
  });

  testWidgets("retained refresh failure keeps cached options visible", (tester) async {
    when(
      () => sessionRepository.loadSessionOptions(
        projectId: "project-1",
        pluginId: "plugin-1",
        forceRefresh: any(named: "forceRefresh"),
      ),
    ).thenAnswer((invocation) async {
      final forceRefresh = invocation.namedArguments[#forceRefresh]! as bool;
      return forceRefresh
          ? const SessionOptionsRepositoryRefreshFailedRetained()
          : SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog());
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
        forceRefresh: any(named: "forceRefresh"),
      ),
    ).thenAnswer((invocation) async {
      final forceRefresh = invocation.namedArguments[#forceRefresh]! as bool;
      return forceRefresh
          ? const SessionOptionsRepositoryRefreshFailedUnavailable()
          : SessionOptionsRepositoryAvailable(catalog: _testSessionOptionsCatalog());
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

  testWidgets("shows variant picker when selected agent has a variant", (tester) async {
    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(PregoPickerButton, "xhigh"));
    await tester.pumpAndSettle();

    // Tapping the variant pill opens a popup listing the Default option plus
    // the model's variants.
    expect(_pickerMenuItem("Default"), findsOneWidget);
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
    expect(tester.getTopLeft(find.text("First Tool")).dy, lessThan(tester.getTopLeft(find.text("Second Tool")).dy));
    expect(tester.getTopLeft(find.text("Second Tool")).dy, lessThan(tester.getTopLeft(find.text("Third Tool")).dy));
    expect(find.text("Needs attention"), findsOneWidget);
    expect(find.text("Failed"), findsOneWidget);
    expect(find.text("Unavailable"), findsOneWidget);
    expect(find.text("Restart the bridge to retry."), findsOneWidget);
    expect(find.text("Check the bridge console."), findsOneWidget);
    expect(find.byIcon(TablerRegular.plug), findsOneWidget);
    expect(findBrandLogo("codex"), findsOneWidget);
    expect(findBrandLogo("cursor"), findsOneWidget);

    // The marks carry their own colours, so a row that can't be picked has to
    // mute its artwork or it reads as active beside the row's greyed-out text.
    double markOpacity(String pluginId) => tester
        .widget<Opacity>(find.ancestor(of: findBrandLogo(pluginId), matching: find.byType(Opacity)).first)
        .opacity;
    expect(markOpacity("cursor"), lessThan(1.0));
    expect(markOpacity("codex"), 1.0);

    expect(
      tester.widget<InkWell>(find.byKey(const Key("new_session_plugin_failed-id"))).onTap,
      isNull,
    );
    expect(
      tester.widget<InkWell>(find.byKey(const Key("new_session_plugin_cursor"))).onTap,
      isNull,
    );
    expect(
      tester.widget<InkWell>(find.byKey(const Key("new_session_plugin_codex"))).onTap,
      isNotNull,
    );
    expect(find.text("failed-id"), findsNothing);
    expect(find.text("codex"), findsNothing);
  });

  testWidgets("uses on-brand foreground tokens for a selected plugin in dark mode", (tester) async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: true,
          plugins: const [
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

    await tester.pumpWidget(_buildApp(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text("Selected Tool")).style?.color, PregoColorsDark.textPrimaryOnBrand);
    expect(tester.widget<Text>(find.text("Needs attention")).style?.color, PregoColorsDark.textSecondaryOnBrand);
    expect(
      tester.widget<Text>(find.text("Check the bridge console.")).style?.color,
      PregoColorsDark.textSecondaryOnBrand,
    );
    final selectedRow = find.byKey(const Key("new_session_plugin_degraded-id"));
    final radio = find.descendant(of: selectedRow, matching: find.byIcon(Icons.radio_button_checked));
    expect(tester.widget<Icon>(radio).color, PregoColorsDark.iconFgBrandOnBrand);
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
    expect(find.widgetWithText(PregoPickerButton, "Default"), findsOneWidget);
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
    expect(find.descendant(of: optionsScroll, matching: find.byType(SwitchListTile)), findsOneWidget);
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
        ),
      ),
    );

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;
    expect(find.text(loc.newSessionDedicatedWorktree), findsNothing);
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

    await tester.tap(find.byKey(const Key("new_session_plugin_tool-b")));
    await tester.pump();

    expect(find.widgetWithText(PregoPickerButton, "coder"), findsNothing);
    final disabledComposer = find.ancestor(
      of: find.byType(PromptInput),
      matching: find.byWidgetPredicate((widget) => widget is IgnorePointer && widget.ignoring),
    );
    expect(disabledComposer, findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(const Key("new_session_plugin_tool-a"))).onTap,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key("new_session_plugin_tool-a")));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(PregoPickerButton, "coder"), findsOneWidget);
    verifyNever(
      () => sessionService.createSessionWithMessage(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
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
          config: ServerConnectionConfig(relayHost: "relay.example.com"),
          health: HealthResponse(
            healthy: true,
            version: "test",
            filesystemAccessDegraded: null,
          ),
        ),
      );
    await tester.pump();
    await tester.pump();

    expect(discoveryCalls, 2);
    expect(tester.widget<NewSessionPluginChooser>(find.byType(NewSessionPluginChooser)).isSelectionEnabled, isFalse);
    expect(
      tester.widget<InkWell>(find.byKey(const Key("new_session_plugin_tool-b"))).onTap,
      isNull,
    );
    await tester.tap(find.byKey(const Key("new_session_plugin_tool-b")));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key("new_session_plugin_tool-a")),
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
    verifyNever(() => sessionService.listAgents(projectId: "project-1", pluginId: "tool-b"));

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
    expect(
      tester.widget<InkWell>(find.byKey(const Key("new_session_plugin_tool-b"))).onTap,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key("new_session_plugin_tool-b")));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key("new_session_plugin_tool-b")),
        matching: find.byIcon(Icons.radio_button_checked),
      ),
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
          config: ServerConnectionConfig(relayHost: "relay.example.com"),
          health: HealthResponse(
            healthy: true,
            version: "test",
            filesystemAccessDegraded: null,
          ),
        ),
      );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(NewSessionScreen));
    final loc = AppLocalizations.of(context)!;
    expect(find.text(loc.apiErrorServerRejected), findsOneWidget);
    expect(find.byKey(const Key("new_session_plugin_plugin-1")), findsOneWidget);
    expect(tester.widget<NewSessionPluginChooser>(find.byType(NewSessionPluginChooser)).isSelectionEnabled, isFalse);
    expect(tester.widget<InkWell>(find.byKey(const Key("new_session_plugin_plugin-1"))).onTap, isNull);
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
    expect(find.text(loc.newSessionPluginChooserLabel), findsNothing);
    expect(find.byKey(const Key("new_session_plugin_plugin-1")), findsNothing);
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
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
        variant: any(named: "variant"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    );
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

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
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

  testWidgets("selecting Default clears the displayed variant", (tester) async {
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

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    // Initially shows the agent's default variant.
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);

    // Open variant picker.
    await tester.tap(find.widgetWithText(PregoPickerButton, "xhigh"));
    await tester.pumpAndSettle();

    // Select Default (null variant).
    await tester.tap(_pickerMenuItem("Default"));
    await tester.pumpAndSettle();

    // The UI should now show "Default".
    expect(find.widgetWithText(PregoPickerButton, "Default"), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsNothing);
  });

  testWidgets("preserves selectedAgentModel variant when changing agent", (tester) async {
    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
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

  testWidgets("shows the loading overlay with accessible message during sending", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
        variant: any(named: "variant"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byKey(const Key("new_session_loading_overlay")), findsOneWidget);
    expect(find.byKey(const Key("new_session_loading_progress")), findsOneWidget);
    expect(find.bySemanticsLabel(loc.newSessionLoadingSemantics), findsOneWidget);
    expect(find.text(loc.newSessionLoadingMessage1), findsOneWidget);
  });

  testWidgets("blocks submit UI while a session is sending", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
        variant: any(named: "variant"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    final absorbingFinder = find.byWidgetPredicate(
      (widget) => widget is AbsorbPointer && widget.absorbing,
    );
    expect(absorbingFinder, findsOneWidget);
    // With the message sent (field cleared) and creation in flight, the dark
    // action button turns into the stop control — there is no send affordance
    // left to double-submit through.
    expect(find.byIcon(TablerSolid.player_stop), findsOneWidget);
    expect(find.byIcon(TablerRegular.arrow_up), findsNothing);

    verify(
      () => sessionService.createSessionWithMessage(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
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
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
        variant: any(named: "variant"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byKey(const Key("new_session_loading_overlay")), findsOneWidget);

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
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
        variant: any(named: "variant"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byKey(const Key("new_session_loading_overlay")), findsOneWidget);

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
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
        variant: any(named: "variant"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byKey(const Key("new_session_loading_overlay")), findsOneWidget);

    createCompleter.complete(ApiResponse.success(testSession(id: "session-1", title: "Created session")));
    await tester.pumpAndSettle();

    expect(find.text("session-detail:session-1"), findsOneWidget);
    expect(
      find.text("uri:/projects/project-1/sessions/session-1?readOnly=false&name=Project+One&title=Created+session"),
      findsOneWidget,
    );
    expect(find.byType(NewSessionScreen), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets("does not show snackbar when auto-navigating after creating a session", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
        variant: any(named: "variant"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byKey(const Key("new_session_loading_overlay")), findsOneWidget);

    createCompleter.complete(ApiResponse.success(testSession(id: "session-1", title: "Created session")));
    await tester.pumpAndSettle();

    expect(find.text("session-detail:session-1"), findsOneWidget);
    expect(find.byType(NewSessionScreen), findsNothing);
    expect(find.text(loc.newSessionLaunchingInBackground), findsNothing);
  });

  testWidgets("removes the loading overlay and keeps retry UI usable after an error", (tester) async {
    final createCompleter = Completer<ApiResponse<Session>>();
    when(
      () => sessionService.createSessionWithMessage(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        text: any(named: "text"),
        agent: any(named: "agent"),
        providerID: any(named: "providerID"),
        modelID: any(named: "modelID"),
        variant: any(named: "variant"),
        command: any(named: "command"),
        dedicatedWorktree: any(named: "dedicatedWorktree"),
      ),
    ).thenAnswer((_) => createCompleter.future);

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await enterTextAndSend(tester: tester, text: "test message");
    await tester.pump();

    expect(find.byKey(const Key("new_session_loading_overlay")), findsOneWidget);

    createCompleter.complete(ApiResponse.error(ApiError.generic()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("new_session_loading_overlay")), findsNothing);
    // Error text now comes from the shared, localized ApiError mapping.
    expect(find.text("An unknown error occurred"), findsOneWidget);

    // Sending excluded focus from the composer, so it collapsed back to its
    // resting pill; it must be usable again for the retry.
    await enterTypingMode(tester);
    expect(find.byType(EditableText), findsOneWidget);
    expect(find.byIcon(TablerRegular.arrow_up), findsOneWidget);

    await tester.enterText(find.byType(EditableText), "retry message");
    await tester.pump();

    expect(find.text("retry message"), findsOneWidget);
  });

  testWidgets("persists and restores the per-project new-session draft", (tester) async {
    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
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
    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();
    expect(find.text("half-written idea"), findsOneWidget);
  });
}
