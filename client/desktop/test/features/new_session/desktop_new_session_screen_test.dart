import "dart:async";
import "dart:math" as math;

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop/core/widgets/desktop_page_toolbar.dart";
import "package:sesori_desktop/features/new_session/desktop_new_session_screen.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockNewSessionCubit() extends MockCubit<NewSessionState> implements NewSessionCubit;
class _MockAuthGateCubit() extends MockCubit<AuthGateState> implements AuthGateCubit;
class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

/// The live project list the page names its project from.
BlocProvider<ProjectListCubit> _projectList({required List<ProjectSummary> projects}) {
  final cubit = _MockProjectListCubit();
  final state = ProjectListState.loaded(projects: projects, folderProjects: projects, scratchProject: null);
  whenListen(cubit, const Stream<ProjectListState>.empty(), initialState: state);
  return BlocProvider<ProjectListCubit>.value(value: cubit);
}

class _MockChatInputModeCubit() extends MockCubit<ChatInputMode> implements ChatInputModeCubit;

class _MockPluginManagementService() extends Mock implements PluginManagementService;
class _MockCatalogRescanService() extends Mock implements CatalogRescanService;
class _MockUrlLauncher() extends Mock implements UrlLauncher;

const _config = NewSessionComposeConfig(
  availablePlugins: [],
  selectedPlugin: null,
  options: NewSessionOptionsLoadState.unsupported(),
  backendScope: NewSessionBackendScope.verified(bridgeId: null),
  isPluginDiscoveryInFlight: false,
  projectWorktreeCapability: NewSessionProjectWorktreeCapability.supported,
);

const _state = NewSessionState.composing(config: _config, phase: NewSessionPhase.idle());

void main() {
  setUp(() {
    final voice = MockVoiceTranscriptionService();
    stubVoiceTranscriptionService(service: voice);
    getIt.registerSingleton<VoiceTranscriptionService>(voice);
  });

  tearDown(getIt.reset);

  testWidgets("desktop new session stays text-first with a persisted voice-first preference", (tester) async {
    final newSessionCubit = _MockNewSessionCubit();
    final inputModeCubit = _MockChatInputModeCubit();
    when(() => newSessionCubit.state).thenReturn(_state);
    whenListen(newSessionCubit, const Stream<NewSessionState>.empty(), initialState: _state);
    when(() => newSessionCubit.needsHarnessDiscovery).thenReturn(false);
    when(() => newSessionCubit.hasNoHarnesses).thenReturn(false);
    when(newSessionCubit.readDedicatedWorktreePreference).thenAnswer((_) async => true);
    when(() => newSessionCubit.canSubmit).thenReturn(true);
    when(() => newSessionCubit.composerPresentation).thenReturn(const NewSessionComposerReady());
    when(() => newSessionCubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
    when(() => newSessionCubit.projectKind).thenReturn(ProjectKind.folder);
    when(() => inputModeCubit.state).thenReturn(ChatInputMode.voiceFirst);
    whenListen(inputModeCubit, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.voiceFirst);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<NewSessionCubit>.value(value: newSessionCubit),
          BlocProvider<ChatInputModeCubit>.value(value: inputModeCubit),
          _projectList(projects: const []),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DesktopNewSessionView(
            projectId: "project-1",
            projectName: "Sesori",
            onBack: () {},
            onOpenHarnessSettings: () {},
            onSessionCreated: ({required session}) {},
            onProjectSelected: ({required projectId, required projectName}) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text("New session"), findsOneWidget);
    expect(find.text("New worktree"), findsOneWidget);
    expect(find.text("Ask anything..."), findsOneWidget);
    expect(find.bySemanticsLabel("Start recording"), findsNothing);
    expect(
      tester.widget<PromptInput>(find.byType(PromptInput)).surfaceStyleController.value,
      PregoComposerSurfaceStyle.emphasized,
    );

    await tester.tap(find.text("Ask anything..."));
    await tester.pump();
    expect(find.byType(EditableText), findsOneWidget);
  });
  testWidgets("the page is one centred column under the toolbar, and choosing another project reports it", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final newSessionCubit = _MockNewSessionCubit();
    final inputModeCubit = _MockChatInputModeCubit();
    when(() => newSessionCubit.state).thenReturn(_state);
    whenListen(newSessionCubit, const Stream<NewSessionState>.empty(), initialState: _state);
    when(() => newSessionCubit.needsHarnessDiscovery).thenReturn(false);
    when(() => newSessionCubit.hasNoHarnesses).thenReturn(false);
    when(newSessionCubit.readDedicatedWorktreePreference).thenAnswer((_) async => true);
    when(() => newSessionCubit.canSubmit).thenReturn(true);
    when(() => newSessionCubit.canRefreshOptions).thenReturn(true);
    when(() => newSessionCubit.composerPresentation).thenReturn(const NewSessionComposerReady());
    when(() => newSessionCubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
    when(() => newSessionCubit.projectKind).thenReturn(ProjectKind.folder);
    when(() => inputModeCubit.state).thenReturn(ChatInputMode.textFirst);
    whenListen(inputModeCubit, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.textFirst);
    final selected = <String>[];

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<NewSessionCubit>.value(value: newSessionCubit),
          BlocProvider<ChatInputModeCubit>.value(value: inputModeCubit),
          _projectList(
            projects: [
              testProjectSummary(id: "project-1", name: "Sesori"),
              testProjectSummary(id: "project-2", name: "Landing"),
            ],
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DesktopNewSessionView(
            projectId: "project-1",
            // The route can lack the name; the loaded list supplies it.
            projectName: null,
            onBack: () {},
            onOpenHarnessSettings: () {},
            onSessionCreated: ({required session}) {},
            onProjectSelected: ({required projectId, required projectName}) => selected.add("$projectId $projectName"),
          ),
        ),
      ),
    );
    await tester.pump();

    final toolbar = tester.getRect(find.byType(DesktopPageToolbar));
    final heading = tester.getRect(find.text("What should we work on?"));
    final input = tester.getRect(find.byType(PromptInput));
    final workspace = tester.getRect(find.text("New worktree"));
    expect(toolbar.top, 0);
    expect(heading.top, greaterThan(toolbar.bottom));
    expect(input.width, DesktopNewSessionView.maxContentWidth);
    expect(input.center.dx, 700);
    expect(workspace.top, greaterThan(heading.bottom));
    expect(input.top, greaterThan(workspace.bottom));
    // Centred, not anchored: the pane keeps room below the column.
    expect(input.bottom, lessThan(800));

    expect(
      find.descendant(of: find.byKey(const Key("new_session_project")), matching: find.text("Sesori")),
      findsOneWidget,
    );
    // The picker names the project; the toolbar carries no crumb.
    expect(find.byKey(const Key("desktop-page-breadcrumb")), findsNothing);

    await tester.tap(find.byKey(const Key("new_session_project")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Landing"));
    await tester.pumpAndSettle();
    expect(selected, ["project-2 Landing"]);
  });

  testWidgets("at Send the page becomes the session, moving the same composer to the bottom edge", (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sending = NewSessionState.composing(
      config: _config,
      phase: NewSessionPhase.sending(
        submission: NewSessionSubmissionSnapshot.text(
          draft: ComposerDraft.typed(text: "Go"),
          attachments: const [],
        ),
        launchId: "launch-1",
        startedAt: DateTime.utc(2026, 9, 27),
        followUps: const [],
      ),
    );
    final newSessionCubit = _MockNewSessionCubit();
    final inputModeCubit = _MockChatInputModeCubit();
    final states = StreamController<NewSessionState>();
    addTearDown(states.close);
    whenListen(newSessionCubit, states.stream, initialState: _state);
    when(() => newSessionCubit.needsHarnessDiscovery).thenReturn(false);
    when(() => newSessionCubit.hasNoHarnesses).thenReturn(false);
    when(newSessionCubit.readDedicatedWorktreePreference).thenAnswer((_) async => true);
    when(() => newSessionCubit.canSubmit).thenReturn(true);
    when(() => newSessionCubit.composerPresentation).thenReturn(const NewSessionComposerReady());
    when(() => newSessionCubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
    when(() => newSessionCubit.projectKind).thenReturn(ProjectKind.folder);
    when(() => inputModeCubit.state).thenReturn(ChatInputMode.textFirst);
    whenListen(inputModeCubit, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.textFirst);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<NewSessionCubit>.value(value: newSessionCubit),
          BlocProvider<ChatInputModeCubit>.value(value: inputModeCubit),
          _projectList(projects: const []),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DesktopNewSessionView(
            projectId: "project-1",
            projectName: "Sesori",
            onBack: () {},
            onOpenHarnessSettings: () {},
            onSessionCreated: ({required session}) {},
            onProjectSelected: ({required projectId, required projectName}) {},
          ),
        ),
      ),
    );
    await tester.pump();
    final prompt = find.byType(PromptInput);
    final promptState = tester.state(prompt);
    final centredRect = tester.getRect(prompt);

    states.add(sending);
    await tester.pump();
    // The move is animated: the toolbar is still fading out, and the composer
    // (where it paints, and so where it takes taps) is on its way down.
    expect(find.byType(DesktopPageToolbar), findsOneWidget);
    await tester.pump();
    expect(tester.getRect(prompt).top, closeTo(centredRect.top, 0.01));
    await tester.pump(const Duration(milliseconds: 120));
    final midwayRect = tester.getRect(prompt);
    await tester.pumpAndSettle();

    // The same composer, not a new one, now spans the session page's 760 px
    // composer column at the bottom edge; the toolbar is gone.
    expect(tester.state(prompt), same(promptState));
    expect(find.byType(DesktopPageToolbar), findsNothing);
    final bottomRect = tester.getRect(prompt);
    expect(bottomRect.bottom, greaterThan(centredRect.bottom));
    expect(midwayRect.top, inExclusiveRange(centredRect.top, bottomRect.top));
    expect(bottomRect.left, (1400 - 760) / 2 + 16);
    expect(bottomRect.right, 1400 - (1400 - 760) / 2 - 16);
    final bubble = find.byType(QueuedMessageBubble);
    expect(find.descendant(of: bubble, matching: find.text("Go")), findsOneWidget);
    // The session page's 960 px transcript column, centred in the 1400 px pane,
    // with its newest row 8 px above the composer.
    final rect = tester.getRect(bubble);
    expect(rect.left, 220);
    expect(rect.right, 1180);
    expect(rect.bottom, closeTo(bottomRect.top - 8, 0.01));
  });

  group("the error banner opens and folds while the centred page glides", () {
    const plugin = PluginMetadata(
      id: "plugin-1",
      displayName: "Plugin One",
      isDefault: true,
      state: PluginLifecycleState.ready,
      actionHint: null,
    );
    const discovering = NewSessionState.composing(
      config: NewSessionComposeConfig(
        availablePlugins: [],
        selectedPlugin: null,
        options: NewSessionOptionsLoadState.loading(source: null),
        backendScope: NewSessionBackendScope.unverified(lastIdentifiedBridgeId: null),
        isPluginDiscoveryInFlight: true,
        projectWorktreeCapability: NewSessionProjectWorktreeCapability.loading,
      ),
      phase: NewSessionPhase.idle(),
    );
    NewSessionState failed({required RemoteFailureReason reason}) => NewSessionState.composing(
      config: const NewSessionComposeConfig(
        availablePlugins: [],
        selectedPlugin: null,
        options: NewSessionOptionsLoadState.loading(source: null),
        backendScope: NewSessionBackendScope.unverified(lastIdentifiedBridgeId: null),
        isPluginDiscoveryInFlight: false,
        projectWorktreeCapability: NewSessionProjectWorktreeCapability.loading,
      ),
      phase: NewSessionPhase.discoveryError(reason: reason),
    );
    const found = NewSessionState.composing(
      config: NewSessionComposeConfig(
        availablePlugins: [plugin],
        selectedPlugin: plugin,
        options: NewSessionOptionsLoadState.unsupported(),
        backendScope: NewSessionBackendScope.verified(bridgeId: null),
        isPluginDiscoveryInFlight: false,
        projectWorktreeCapability: NewSessionProjectWorktreeCapability.supported,
      ),
      phase: NewSessionPhase.idle(),
    );
    const networkDown = "Connection failed — check your network and try again.";
    const serverRejected = "The server returned an error. Please try again.";
    final heading = find.text("What should we work on?");
    final project = find.byKey(const Key("new_session_project"));

    /// The desktop page over a cubit that emits what the test adds.
    Future<StreamController<NewSessionState>> pumpPage(WidgetTester tester, {required NewSessionState initial}) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = _MockNewSessionCubit();
      final inputModeCubit = _MockChatInputModeCubit();
      final states = StreamController<NewSessionState>();
      addTearDown(states.close);
      whenListen(cubit, states.stream, initialState: initial);
      bool failedDiscovery() => cubit.state.phase is NewSessionPhaseDiscoveryError;
      when(() => cubit.needsHarnessDiscovery).thenAnswer((_) => failedDiscovery());
      when(() => cubit.hasNoHarnesses).thenReturn(false);
      when(() => cubit.composerPresentation).thenAnswer(
        (_) => failedDiscovery()
            ? const NewSessionComposerRetry()
            : identical(cubit.state, discovering)
            ? const NewSessionComposerPending()
            : const NewSessionComposerReady(),
      );
      when(cubit.readDedicatedWorktreePreference).thenAnswer((_) async => true);
      when(() => cubit.canSubmit).thenReturn(false);
      when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
      when(() => cubit.projectKind).thenReturn(ProjectKind.folder);
      whenListen(inputModeCubit, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.textFirst);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<NewSessionCubit>.value(value: cubit),
            BlocProvider<ChatInputModeCubit>.value(value: inputModeCubit),
            _projectList(projects: const []),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [PregoDesignSystem.light]),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DesktopNewSessionView(
              projectId: "project-1",
              projectName: "Sesori",
              onBack: () {},
              onOpenHarnessSettings: () {},
              onSessionCreated: ({required session}) {},
              onProjectSelected: ({required projectId, required projectName}) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      return states;
    }

    /// The heading's and the project pill's rects at each 16 ms frame after
    /// [next] lands, from the frame before it until the page has settled.
    /// [checkFirstFrame] runs on the frame that applies [next].
    Future<List<(Rect, Rect)>> framesAfter(
      WidgetTester tester, {
      required StreamController<NewSessionState> states,
      required NewSessionState next,
      required VoidCallback? checkFirstFrame,
    }) async {
      (Rect, Rect) frame() => (tester.getRect(heading), tester.getRect(project));
      final frames = [frame()];
      states.add(next);
      // Zero time still delivers the state before the frame, even when no
      // other motion has one scheduled.
      await tester.pump(Duration.zero);
      checkFirstFrame?.call();
      frames.add(frame());
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        frames.add(frame());
      }
      await tester.pump(const Duration(milliseconds: 400));
      frames.add(frame());
      return frames;
    }

    /// How far the heading moves up or down in the frame that moves it most.
    double largestStep(List<(Rect, Rect)> frames) => [
      for (var i = 1; i < frames.length; i++) (frames[i].$1.top - frames[i - 1].$1.top).abs(),
    ].reduce(math.max);

    /// Fails when the project pill parts from the heading vertically: it must
    /// ride along with it every frame, however the page re-centres.
    void expectPillUnderHeading(List<(Rect, Rect)> frames) {
      final gap = frames.first.$2.top - frames.first.$1.bottom;
      for (final (heading, project) in frames) {
        expect(project.top - heading.bottom, moreOrLessEquals(gap, epsilon: 0.01));
      }
    }

    /// The opacity [finder] paints with, through every fade above it.
    double opacityOf(WidgetTester tester, Finder finder) => tester
        .widgetList<FadeTransition>(find.ancestor(of: finder, matching: find.byType(FadeTransition)))
        .fold(1, (opacity, fade) => opacity * fade.opacity.value);

    testWidgets("when discovery fails, and back when Retry finds a harness", (tester) async {
      final states = await pumpPage(tester, initial: discovering);

      final opening = await framesAfter(
        tester,
        states: states,
        next: failed(reason: RemoteFailureReason.networkDown),
        checkFirstFrame: null,
      );
      // The banner's room makes the column taller, so the centred heading
      // moves, but over the motion rather than in one frame.
      expect(opening.last.$1.top, isNot(moreOrLessEquals(opening.first.$1.top, epsilon: 1)));
      expect(largestStep(opening), lessThan(1.5));
      expectPillUnderHeading(opening);
      expect(find.text(networkDown), findsOneWidget);
      expect(opacityOf(tester, find.text(networkDown)), 1);

      // Another error while one shows takes its place at once, without
      // fading, and its room eases to the new text's height.
      final swapping = await framesAfter(
        tester,
        states: states,
        next: failed(reason: RemoteFailureReason.serverRejected),
        checkFirstFrame: () {
          expect(find.text(networkDown), findsNothing);
          expect(opacityOf(tester, find.text(serverRejected)), 1);
        },
      );
      expect(largestStep(swapping), lessThan(1.5));
      expectPillUnderHeading(swapping);

      final folding = await framesAfter(tester, states: states, next: found, checkFirstFrame: null);
      expect(largestStep(folding), lessThan(1.5));
      expectPillUnderHeading(folding);
      expect(find.text(serverRejected), findsNothing);
    });

    testWidgets("at once under reduced motion", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final states = await pumpPage(tester, initial: discovering);

      for (final next in [failed(reason: RemoteFailureReason.networkDown), found]) {
        final frames = await framesAfter(tester, states: states, next: next, checkFirstFrame: null);
        // The frame that applies the change already shows the page at rest.
        expect(frames[1].$1, frames.last.$1);
        expect(frames[1].$1, isNot(frames.first.$1));
        expect(find.text(networkDown), next == found ? findsNothing : findsOneWidget);
      }
    });
  });

  for (final closeFromDetail in [false, true]) {
    testWidgets("desktop harness modal X preserves the live composer draft (detail: $closeFromDetail)", (tester) async {
      registerFallbackValue(ComposerDraft.typed(text: ""));
      final newSessionCubit = _MockNewSessionCubit();
      final inputModeCubit = _MockChatInputModeCubit();
      final authGateCubit = _MockAuthGateCubit();
      whenListen(
        authGateCubit,
        const Stream<AuthGateState>.empty(),
        initialState: const AuthGateState.signedIn(
          user: AuthUser(
            id: "user",
            provider: AuthProvider.github,
            providerUserId: "user",
            providerUsername: "developer",
          ),
        ),
      );
      whenListen(newSessionCubit, const Stream<NewSessionState>.empty(), initialState: _state);
      when(() => newSessionCubit.needsHarnessDiscovery).thenReturn(false);
      when(() => newSessionCubit.hasNoHarnesses).thenReturn(false);
      when(newSessionCubit.readDedicatedWorktreePreference).thenAnswer((_) async => true);
      when(() => newSessionCubit.canSubmit).thenReturn(true);
      when(() => newSessionCubit.composerPresentation).thenReturn(const NewSessionComposerReady());
      var draft = ComposerDraft.typed(text: "");
      when(() => newSessionCubit.composerDraft).thenAnswer((_) => draft);
      when(() => newSessionCubit.projectKind).thenReturn(ProjectKind.folder);
      when(() => newSessionCubit.saveComposerDraft(draft: any(named: "draft"))).thenAnswer((invocation) {
        draft = invocation.namedArguments[#draft]! as ComposerDraft;
      });
      whenListen(inputModeCubit, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.voiceFirst);
      final service = _MockPluginManagementService();
      final scans = _MockCatalogRescanService();
      final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
        const PluginManagementLoadResult.supported(
          response: PluginManagementResponse(
            snapshotToken: "navigation-test",
            bridgeId: "bridge",
            defaultPluginId: "test",
            defaultIdleTimeoutMins: 10,
            plugins: [],
          ),
          refreshError: null,
        ),
      );
      final installs = BehaviorSubject<Map<String, PluginInstallState>>.seeded(const {});
      addTearDown(snapshots.close);
      addTearDown(installs.close);
      when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
      when(() => service.installStates).thenAnswer((_) => installs.stream);
      final challenges = BehaviorSubject<Map<String, PluginAuthenticationChallenge>>.seeded(const {});
      final browserStates = BehaviorSubject<Map<String, PluginAuthenticationBrowserState>>.seeded(const {});
      addTearDown(challenges.close);
      addTearDown(browserStates.close);
      when(() => service.authenticationChallenges).thenAnswer((_) => challenges.stream);
      when(() => service.authenticationBrowserStates).thenAnswer((_) => browserStates.stream);
      when(() => service.authenticationTerminal)
          .thenAnswer((_) => const Stream<PluginAuthenticationTerminalUpdate>.empty());
      when(service.onDispose).thenAnswer((_) async {});
      final scanStates = BehaviorSubject<CatalogRescanState>.seeded(const CatalogRescanState.idle());
      addTearDown(scanStates.close);
      when(() => scans.state).thenAnswer((_) => scanStates.stream);
      when(scans.onDispose).thenAnswer((_) async {});
      getIt.registerSingleton<PluginManagementService>(service);
      getIt.registerSingleton<CatalogRescanService>(scans);
      getIt.registerSingleton<UrlLauncher>(_MockUrlLauncher());
      final router = GoRouter(
        initialLocation: "/sessions/new?project=p",
        routes: [
          GoRoute(
            path: AppRouteDef.newSession.path,
            builder: (context, state) {
              final shell = buildDesktopRoutes().single as ShellRoute;
              final route = shell.routes.whereType<GoRoute>().singleWhere(
                (route) => route.path == AppRouteDef.newSession.path,
              );
              final screen = route.builder!(context, state) as DesktopNewSessionScreen;
              // Replacing the route reuses the page, so only this key gives
              // another project its own cubit.
              expect(screen.key, const ValueKey("desktop-new-session-p"));
              return DesktopNewSessionView(
                projectId: "p",
                projectName: "Project",
                onBack: () {},
                onOpenHarnessSettings: screen.onOpenHarnessSettings,
                onSessionCreated: ({required session}) {},
                onProjectSelected: ({required projectId, required projectName}) {},
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<NewSessionCubit>.value(value: newSessionCubit),
            BlocProvider<ChatInputModeCubit>.value(value: inputModeCubit),
            BlocProvider<AuthGateCubit>.value(value: authGateCubit),
            _projectList(projects: const []),
            RepositoryProvider<ConnectionService>.value(value: MockConnectionService()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildPregoThemeData(brightness: Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("Ask anything..."));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), "unfinished desktop idea");
      await tester.pump();
      final opener = tester.element(find.byType(DesktopNewSessionView));
      final composer = tester.element(find.byType(PromptInput));
      tester.widget<DesktopNewSessionView>(find.byType(DesktopNewSessionView)).onOpenHarnessSettings();
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), "/sessions/new?project=p");
      final overview = tester.element(find.byType(HarnessesSettingsView));
      final harnessCubit = overview.read<PluginManagementCubit>();
      if (closeFromDetail) {
        tester.widget<HarnessesSettingsView>(find.byType(HarnessesSettingsView)).onOpenHarness(pluginId: "removed");
        await tester.pumpAndSettle();
      }
      await tester.tap(find.bySemanticsLabel("Close settings"));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(DesktopNewSessionView)), same(opener));
      expect(tester.element(find.byType(PromptInput)), same(composer));
      expect(composer.read<NewSessionCubit>(), same(newSessionCubit));
      expect(draft, ComposerDraft.typed(text: "unfinished desktop idea"));
      expect(find.text("unfinished desktop idea"), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(harnessCubit.isClosed, isTrue);
      expect(snapshots.hasListener, isFalse);
    });
  }
}
