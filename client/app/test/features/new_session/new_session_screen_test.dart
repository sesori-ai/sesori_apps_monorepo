import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class MockVoiceTranscriptionService extends Mock implements VoiceTranscriptionService {}

AgentInfo _testAgent({required String name, required String description, required String? variant}) {
  return AgentInfo(
    name: name,
    description: description,
    model: AgentModel(providerID: "anthropic", modelID: "claude-3-5-sonnet", variant: variant),
    mode: AgentMode.primary,
  );
}

Widget _buildApp() {
  final router = GoRouter(
    initialLocation: "/new",
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: "new",
            builder: (context, state) => const NewSessionScreen(projectId: "project-1", projectName: "Project One"),
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  late MockSessionService sessionService;
  late MockVoiceTranscriptionService voiceTranscriptionService;

  // flutter_test defaults `defaultTargetPlatform` to android, so PregoAnchorMenu
  // renders its flat (cue) menu here — the menu rows are Material InkWells, not
  // GlassMenuItems. Finders below target those InkWells.
  setUp(() async {
    await GetIt.instance.reset();
    sessionService = MockSessionService();
    voiceTranscriptionService = MockVoiceTranscriptionService();

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

    final maxDurationReached = StreamController<void>.broadcast();
    addTearDown(maxDurationReached.close);
    when(() => voiceTranscriptionService.onMaxDurationReached).thenAnswer((_) => maxDurationReached.stream);

    GetIt.instance.registerSingleton<SessionService>(sessionService);
    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
    GetIt.instance.registerSingleton<NewSessionSelectionTracker>(NewSessionSelectionTracker());
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets("shows variant picker when selected agent has a variant", (tester) async {
    await tester.pumpWidget(_buildApp());
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

    await tester.pumpWidget(_buildApp());
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
    await tester.pumpWidget(_buildApp());
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

    await tester.pumpWidget(_buildApp());
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

    await tester.pumpWidget(_buildApp());
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

    await tester.pumpWidget(_buildApp());
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
    // The snackbar is scheduled via a post-frame callback (so it stays safe
    // when the pop is invoked during build), so pump once more to render it.
    await tester.pump();

    // Snackbar should appear before the screen pops.
    expect(find.text(loc.newSessionLaunchingInBackground), findsOneWidget);

    // The screen should have popped (no longer showing NewSessionScreen).
    await tester.pumpAndSettle();
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

    await tester.pumpWidget(_buildApp());
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
    // The launching-in-background snackbar is deferred to a post-frame
    // callback; pump once more to render it.
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

    await tester.pumpWidget(_buildApp());
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

    await tester.pumpWidget(_buildApp());
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

    await tester.pumpWidget(_buildApp());
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

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), "half-written idea");
    await tester.pump();

    // Tear the screen down (e.g. the user navigates away) before creating a
    // session — PromptInput.dispose() should persist the unsent prompt.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(draftStore.read("new-session:project-1"), "half-written idea");

    // Re-open the new-session screen — the per-project draft is restored.
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.text("half-written idea"), findsOneWidget);
  });
}
