import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/features/session_detail/widgets/prompt_input.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class MockVoiceTranscriptionService extends Mock implements VoiceTranscriptionService {}

class MockPluginRepository extends Mock implements PluginRepository {}

AgentInfo _testAgent({required String name, required String description, required String? variant}) {
  return AgentInfo(
    name: name,
    description: description,
    model: AgentModel(providerID: "anthropic", modelID: "claude-3-5-sonnet", variant: variant),
    mode: AgentMode.primary,
  );
}

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

  return BlocProvider<ConnectionOverlayCubit>(
    create: (_) => StubConnectionOverlayCubit(),
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

void main() {
  late MockSessionService sessionService;
  late MockPluginRepository pluginRepository;
  late MockConnectionService connectionService;
  late BehaviorSubject<ConnectionStatus> connectionStatus;
  late MockProjectRepository projectRepository;
  late MockVoiceTranscriptionService voiceTranscriptionService;

  // flutter_test defaults `defaultTargetPlatform` to android, so PregoAnchorMenu
  // renders its flat (cue) menu here — the menu rows are Material InkWells, not
  // GlassMenuItems. Finders below target those InkWells.
  setUp(() async {
    await GetIt.instance.reset();
    sessionService = MockSessionService();
    pluginRepository = MockPluginRepository();
    connectionService = MockConnectionService();
    connectionStatus = BehaviorSubject.seeded(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com"),
        health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: null),
      ),
    );
    projectRepository = MockProjectRepository();
    voiceTranscriptionService = MockVoiceTranscriptionService();

    when(() => connectionService.status).thenAnswer((_) => connectionStatus.stream);
    when(() => connectionService.currentStatus).thenAnswer((_) => connectionStatus.value);

    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        const PluginListResponse(
          plugins: [
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

    GetIt.instance.registerSingleton<SessionService>(sessionService);
    GetIt.instance.registerSingleton<PluginRepository>(pluginRepository);
    GetIt.instance.registerSingleton<ConnectionService>(connectionService);
    GetIt.instance.registerSingleton<ProjectRepository>(projectRepository);
    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
    GetIt.instance.registerSingleton<NewSessionSelectionTracker>(NewSessionSelectionTracker());
  });

  tearDown(() async {
    await GetIt.instance.reset();
    await connectionStatus.close();
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

  testWidgets("shows variant picker when selected agent has a variant", (tester) async {
    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(GlassButton, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(GlassButton, "xhigh"));
    await tester.pumpAndSettle();

    // Tapping the variant pill opens a popup listing the Default option plus
    // the model's variants.
    expect(find.widgetWithText(InkWell, "Default"), findsOneWidget);
    expect(find.widgetWithText(InkWell, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, "xhigh"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(GlassButton, "xhigh"), findsOneWidget);
  });

  testWidgets("does not render plugin selection even when discovery returns multiple plugins", (tester) async {
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        const PluginListResponse(
          plugins: [
            PluginMetadata(
              id: "failed-id",
              displayName: "First Tool",
              isDefault: false,
              state: PluginLifecycleState.failed,
              actionHint: "Restart the bridge to retry.",
            ),
            PluginMetadata(
              id: "degraded-id",
              displayName: "Second Tool",
              isDefault: true,
              state: PluginLifecycleState.degraded,
              actionHint: "Check the bridge console.",
            ),
            PluginMetadata(
              id: "unavailable-id",
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

    final loc = AppLocalizations.of(tester.element(find.byType(NewSessionScreen)))!;
    expect(find.text(loc.newSessionPluginChooserLabel), findsNothing);
    expect(find.text("First Tool"), findsNothing);
    expect(find.text("Second Tool"), findsNothing);
    expect(find.text("Third Tool"), findsNothing);
    expect(find.byKey(const Key("new_session_plugin_failed-id")), findsNothing);
    expect(find.byKey(const Key("new_session_plugin_degraded-id")), findsNothing);
    expect(find.byKey(const Key("new_session_plugin_unavailable-id")), findsNothing);
    expect(find.text("failed-id"), findsNothing);
    expect(find.text("degraded-id"), findsNothing);
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
    expect(find.widgetWithText(GlassButton, "Claude 3.5 Sonnet"), findsOneWidget);
    expect(find.widgetWithText(GlassButton, "Default"), findsOneWidget);
  });

  testWidgets("keeps the composer pinned while worktree options scroll", (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginListResponse(
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
    expect(find.byKey(const Key("new_session_plugin_plugin-0")), findsNothing);
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

  testWidgets("refresh discovery failure keeps the composer usable without plugin selection", (tester) async {
    var discoveryCalls = 0;
    when(pluginRepository.listPlugins).thenAnswer((_) async {
      discoveryCalls++;
      if (discoveryCalls == 1) {
        return ApiResponse.success(
          const PluginListResponse(
            plugins: [
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
    expect(find.byKey(const Key("new_session_plugin_plugin-1")), findsNothing);
    expect(
      find.ancestor(
        of: find.byType(PromptInput),
        matching: find.byWidgetPredicate((widget) => widget is IgnorePointer && widget.ignoring),
      ),
      findsNothing,
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

    await tester.enterText(find.byType(EditableText), "must not send");
    await tester.tap(find.byIcon(Icons.send), warnIfMissed: false);
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
    expect(find.widgetWithText(GlassButton, "xhigh"), findsOneWidget);

    // Open variant picker.
    await tester.tap(find.widgetWithText(GlassButton, "xhigh"));
    await tester.pumpAndSettle();

    // Select a different variant.
    await tester.tap(find.widgetWithText(InkWell, "low"));
    await tester.pumpAndSettle();

    // The UI should now reflect the newly selected variant.
    expect(find.widgetWithText(GlassButton, "low"), findsOneWidget);
    expect(find.widgetWithText(GlassButton, "xhigh"), findsNothing);
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
    expect(find.widgetWithText(GlassButton, "xhigh"), findsOneWidget);

    // Open variant picker.
    await tester.tap(find.widgetWithText(GlassButton, "xhigh"));
    await tester.pumpAndSettle();

    // Select Default (null variant).
    await tester.tap(find.widgetWithText(InkWell, "Default"));
    await tester.pumpAndSettle();

    // The UI should now show "Default".
    expect(find.widgetWithText(GlassButton, "Default"), findsOneWidget);
    expect(find.widgetWithText(GlassButton, "xhigh"), findsNothing);
  });

  testWidgets("preserves selectedAgentModel variant when changing agent", (tester) async {
    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(GlassButton, "xhigh"));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InkWell, "xhigh"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(GlassButton, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(GlassButton, "coder"));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InkWell, "reviewer"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(GlassButton, "reviewer"), findsOneWidget);
    // Changing the agent seeds the variant from the agent's default.
    // Reviewer has variant: null, so the pill shows "Default".
    expect(find.widgetWithText(GlassButton, "Default"), findsOneWidget);
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

    await tester.enterText(find.byType(EditableText), "test message");
    await tester.tap(find.byIcon(Icons.send), warnIfMissed: false);
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

    await tester.enterText(find.byType(EditableText), "test message");
    await tester.tap(find.byIcon(Icons.send), warnIfMissed: false);
    await tester.pump();

    final absorbingFinder = find.byWidgetPredicate(
      (widget) => widget is AbsorbPointer && widget.absorbing,
    );
    expect(absorbingFinder, findsOneWidget);
    expect(find.byIcon(Icons.stop_circle), findsOneWidget);

    await tester.tap(find.byIcon(Icons.send), warnIfMissed: false);
    await tester.pump();

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

    await tester.enterText(find.byType(EditableText), "test message");
    await tester.tap(find.byIcon(Icons.send), warnIfMissed: false);
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

    await tester.enterText(find.byType(EditableText), "test message");
    await tester.tap(find.byIcon(Icons.send), warnIfMissed: false);
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

    await tester.enterText(find.byType(EditableText), "test message");
    await tester.tap(find.byIcon(Icons.send));
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

    await tester.enterText(find.byType(EditableText), "test message");
    await tester.tap(find.byIcon(Icons.send));
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

    await tester.enterText(find.byType(EditableText), "test message");
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.byKey(const Key("new_session_loading_overlay")), findsOneWidget);

    createCompleter.complete(ApiResponse.error(ApiError.generic()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("new_session_loading_overlay")), findsNothing);
    // Error text now comes from the shared, localized ApiError mapping.
    expect(find.text("An unknown error occurred"), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);

    await tester.enterText(find.byType(EditableText), "retry message");
    await tester.pump();

    expect(find.text("retry message"), findsOneWidget);
  });

  testWidgets("persists and restores the per-project new-session draft", (tester) async {
    final draftStore = DraftStore();
    GetIt.instance.registerSingleton<DraftStore>(draftStore);

    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), "half-written idea");
    await tester.pump();

    // Tear the screen down (e.g. the user navigates away) before creating a
    // session — PromptInput.dispose() should persist the unsent prompt.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(draftStore.read("new-session:project-1"), "half-written idea");

    // Re-open the new-session screen — the per-project draft is restored.
    await tester.pumpWidget(_buildApp(initialSupportsDedicatedWorktrees: true));
    await tester.pumpAndSettle();
    expect(find.text("half-written idea"), findsOneWidget);
  });
}
