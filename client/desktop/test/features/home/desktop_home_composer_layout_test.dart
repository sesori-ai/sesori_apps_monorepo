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
import "package:theme_prego/module_prego.dart";

class _MockPluginService() extends Mock implements NewSessionPluginService;

class _MockOptionsService() extends Mock implements NewSessionOptionsService;

class _MockFileAccessCubit() extends MockCubit<FileAccessState> implements FileAccessCubit;

class _MockAllSessionsCubit() extends MockCubit<AllSessionsState> implements AllSessionsCubit;

class _MockChatInputModeCubit() extends MockCubit<ChatInputMode> implements ChatInputModeCubit;

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

const _openCode = PluginMetadata(
  id: "opencode",
  displayName: "OpenCode",
  isDefault: true,
  state: PluginLifecycleState.ready,
  actionHint: null,
  supportsPromptAttachments: true,
);

const _claudeCode = PluginMetadata(
  id: "claude",
  displayName: "Claude Code",
  isDefault: true,
  state: PluginLifecycleState.ready,
  actionHint: null,
  supportsPromptAttachments: true,
);

const _folder = ProjectSummary(id: "one", name: "demo-app", path: "/one", time: null);
const _scratch = ProjectSummary(id: "scratch", name: null, path: "/scratch", time: null, kind: ProjectKind.scratch);

/// The home composer as the bridge answers it part by part: harness discovery,
/// the project's worktree check and the agents and models each answer when
/// their completer does.
class const _Answers({
  required final Completer<ApiResponse<NewSessionPluginDiscovery>> discovery,
  required final Completer<ApiResponse<Project>> project,
  required final Completer<NewSessionOptionsLoadResult> options,
}) {
  void discover({required List<PluginMetadata> plugins}) => discovery.complete(
    ApiResponse.success(
      NewSessionPluginDiscovery(
        bridgeId: "bridge",
        optionsSource: NewSessionOptionsSource.aggregate,
        plugins: plugins,
        selected: plugins.firstOrNull,
      ),
    ),
  );

  void checkProject({required ProjectSummary summary, required bool supportsDedicatedWorktrees}) => project.complete(
    ApiResponse.success(
      Project(
        id: summary.id,
        name: summary.name,
        path: summary.path,
        time: null,
        supportsDedicatedWorktrees: supportsDedicatedWorktrees,
        voiceGlossaryKey: null,
      ),
    ),
  );

  void loadOptions() => options.complete(
    NewSessionOptionsLoaded(
      options: NewSessionOptionsData(
        agents: const [
          AgentInfo(
            name: "build",
            description: "Build",
            model: AgentModel(providerID: "anthropic", modelID: "claude-3-5-sonnet", variant: null),
            mode: AgentMode.primary,
          ),
        ],
        providers: testProviderListResponse().items,
        commands: const [],
        selectedAgent: "build",
        selectedAgentModel: const AgentModel(providerID: "anthropic", modelID: "claude-3-5-sonnet", variant: null),
        fastMode: false,
        stagedCommand: null,
        availableVariants: const [],
      ),
      source: NewSessionOptionsSource.aggregate,
      isStale: false,
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(NewSessionOptionsSource.aggregate);
    registerFallbackValue(NewSessionOptionsLoadMode.dynamicLoad);
  });
  tearDown(getIt.reset);

  /// Pumps the home connected to a bridge that has not answered anything yet.
  Future<_Answers> pumpHome({required WidgetTester tester, required ProjectSummary project}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final voice = MockVoiceTranscriptionService();
    stubVoiceTranscriptionService(service: voice);
    getIt.registerSingleton<VoiceTranscriptionService>(voice);

    final answers = _Answers(discovery: Completer(), project: Completer(), options: Completer());
    final pluginService = _MockPluginService();
    when(
      () => pluginService.discover(
        currentSelectedPluginId: any(named: "currentSelectedPluginId"),
        currentSelectionBridgeId: any(named: "currentSelectionBridgeId"),
      ),
    ).thenAnswer((_) => answers.discovery.future);
    final optionsService = _MockOptionsService();
    when(
      () => optionsService.load(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
        source: any(named: "source"),
        mode: any(named: "mode"),
        restoredSelection: any(named: "restoredSelection"),
        previousOptions: any(named: "previousOptions"),
      ),
    ).thenAnswer((_) => answers.options.future);
    final projects = MockProjectRepository();
    when(() => projects.getProject(projectId: any(named: "projectId"))).thenAnswer((_) => answers.project.future);
    final connection = MockConnectionService();
    final statuses = BehaviorSubject<ConnectionStatus>.seeded(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
        health: HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false),
      ),
    );
    addTearDown(statuses.close);
    when(() => connection.status).thenAnswer((_) => statuses.stream);
    when(() => connection.currentStatus).thenAnswer((_) => statuses.value);
    final analytics = MockProductAnalyticsService();
    final tracker = NewSessionSelectionTracker();

    final fileAccess = _MockFileAccessCubit();
    whenListen(
      fileAccess,
      const Stream<FileAccessState>.empty(),
      initialState: const FileAccessState(status: FileAccessStatus.unsupported, dismissed: false),
    );
    final sessions = _MockAllSessionsCubit();
    whenListen(
      sessions,
      const Stream<AllSessionsState>.empty(),
      initialState: AllSessionsState(
        projectId: null,
        query: "",
        quickFilter: SessionListQuickFilter.all,
        everyProjectRows: const [],
        rows: const [],
        counts: const SessionListChipCounts(all: 0, running: 0, unread: 0),
        failures: const [],
        isLoading: false,
        scratchProjectId: null,
        defaultProjectId: project.id,
      ),
    );
    final inputMode = _MockChatInputModeCubit();
    whenListen(inputMode, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.textFirst);
    final projectList = _MockProjectListCubit();
    whenListen(
      projectList,
      const Stream<ProjectListState>.empty(),
      initialState: ProjectListState.loaded(
        projects: [project],
        folderProjects: [if (project.kind == ProjectKind.folder) project],
        scratchProject: project.kind == ProjectKind.scratch ? project : null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.dark),
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
            projects: [project],
            createNewSessionCubit: ({required projectId, required projectName, required projectKind}) =>
                NewSessionCubit(
                  connectionService: connection,
                  newSessionPluginService: pluginService,
                  newSessionOptionsService: optionsService,
                  projectRepository: projects,
                  selectionTracker: tracker,
                  composerDraftRepository: inMemoryComposerDraftRepository(),
                  productAnalyticsService: analytics,
                  sessionLaunchService: SessionLaunchService(
                    sessionRepository: MockSessionRepository(),
                    launchRepository: inMemorySessionLaunchRepository(),
                    feedbackPromptService: FakeFeedbackPromptService(),
                    productAnalyticsService: analytics,
                    selectionTracker: tracker,
                    authSession: FakeAuthSession(initialState: const AuthState.initial()),
                  ),
                  dedicatedWorktreePreferenceStore: FakeDedicatedWorktreePreferenceStore(),
                  projectId: projectId,
                  projectName: projectName,
                  projectKind: projectKind,
                ),
            onOpenSession: ({required context, required project, required displayName, required session}) {},
            onOpenHarnessSettings: () {},
          ),
        ),
      ),
    );
    return answers;
  }

  final title = find.text("What should we work on?");
  final composer = find.byType(PromptInput);
  final options = find.byKey(const Key("new_session_options"));
  final harness = find.byKey(const Key("new_session_plugin_trigger"));
  final worktreeSwitch = find.byKey(const Key("new_session_dedicated_workspace"));
  final attach = find.byIcon(TablerRegular.plus);
  Finder shimmerIn(Finder parent) => find.descendant(of: parent, matching: find.byType(PregoShimmer));
  final harnessShimmer = shimmerIn(find.byType(NewSessionHeader));
  final pillsShimmer = shimmerIn(composer);
  final worktreeShimmer = shimmerIn(options);

  /// Whether [shimmer] is on screen, not held invisible for a delay.
  bool shows(WidgetTester tester, Finder shimmer) => !tester
      .widget<FadeTransition>(find.descendant(of: shimmer, matching: find.byType(FadeTransition)))
      .opacity
      .isDismissed;

  /// Lets an answer land and the transitions it starts run out; the shimmers'
  /// sweep never ends, so pumpAndSettle cannot.
  Future<void> landAnswer(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  /// Pumps every frame of [duration], expecting the title and the composer
  /// to stay exactly at [titleRect] and [composerRect] throughout.
  Future<void> expectStillThrough({
    required WidgetTester tester,
    required Rect titleRect,
    required Rect composerRect,
    Duration duration = const Duration(milliseconds: 400),
  }) async {
    for (var elapsed = Duration.zero; elapsed <= duration; elapsed += const Duration(milliseconds: 16)) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getRect(title), titleRect);
      expect(tester.getRect(composer), composerRect);
    }
  }

  testWidgets("the composer appears at its final layout at once, each loading part shimmering in its place", (
    tester,
  ) async {
    final answers = await pumpHome(tester: tester, project: _folder);
    final titleRect = tester.getRect(title);
    final composerRect = tester.getRect(composer);
    final optionsRect = tester.getRect(options);

    // Every part still loading shows a placeholder from the first frame.
    expect(shows(tester, harnessShimmer), isTrue);
    expect(tester.getSize(harnessShimmer), const Size(140, 36));
    expect(shows(tester, pillsShimmer), isTrue);
    final pillsRect = tester.getRect(pillsShimmer);
    expect(shows(tester, worktreeShimmer), isTrue);
    expect(attach, findsOneWidget);

    answers.discover(plugins: const [_openCode]);
    await expectStillThrough(tester: tester, titleRect: titleRect, composerRect: composerRect);
    expect(harnessShimmer, findsNothing);
    expect(tester.getSize(harness).height, 36);

    answers.checkProject(summary: _folder, supportsDedicatedWorktrees: true);
    await expectStillThrough(tester: tester, titleRect: titleRect, composerRect: composerRect);
    expect(worktreeShimmer, findsNothing);
    expect(worktreeSwitch, findsOneWidget);
    expect(tester.getRect(options), optionsRect);

    answers.loadOptions();
    await expectStillThrough(tester: tester, titleRect: titleRect, composerRect: composerRect);
    expect(pillsShimmer, findsNothing);
    expect(tester.getRect(find.byType(AgentModelButtons)), pillsRect);
    expect(attach, findsOneWidget);
  });

  testWidgets("the harness pill eases to its chooser's width, so the project pill glides to its new centre", (
    tester,
  ) async {
    final answers = await pumpHome(tester: tester, project: _folder);
    final project = find.byKey(const Key("new_session_project"));
    final start = tester.getCenter(project).dx;

    answers.discover(plugins: const [_claudeCode]);
    await tester.pump();
    await tester.pump();
    expect(tester.getCenter(project).dx, start);

    await tester.pump(const Duration(milliseconds: 100));
    final midway = tester.getCenter(project).dx;
    await tester.pump(const Duration(milliseconds: 300));
    final end = tester.getCenter(project).dx;
    expect(tester.getSize(harness).width, isNot(closeTo(140, 20)));
    expect((end - start).abs(), greaterThan(10));
    expect(midway, isNot(anyOf(start, end)));
    expect((midway - start).sign, (end - start).sign);
    expect((end - midway).sign, (end - start).sign);
  });

  testWidgets("No project holds no worktree room, so its answer moves nothing", (tester) async {
    final answers = await pumpHome(tester: tester, project: _scratch);
    final titleRect = tester.getRect(title);
    final composerRect = tester.getRect(composer);
    expect(worktreeShimmer, findsNothing);

    answers.discover(plugins: const [_openCode]);
    answers.checkProject(summary: _scratch, supportsDedicatedWorktrees: false);
    await expectStillThrough(tester: tester, titleRect: titleRect, composerRect: composerRect);
    answers.loadOptions();
    await expectStillThrough(tester: tester, titleRect: titleRect, composerRect: composerRect);
    expect(worktreeSwitch, findsNothing);
    expect(find.byType(AgentModelButtons), findsOneWidget);
  });

  testWidgets("a failed discovery still swaps the placeholders for the retry", (tester) async {
    final answers = await pumpHome(tester: tester, project: _folder);

    answers.discovery.complete(ApiResponse.error(ApiError.generic()));
    await landAnswer(tester);

    expect(find.byKey(const Key("new_session_options_retry")), findsOneWidget);
    expect(harnessShimmer, findsNothing);
    expect(pillsShimmer, findsNothing);
    expect(worktreeShimmer, findsNothing);
  });

  testWidgets("a bridge with no harness still says so in the options' place", (tester) async {
    final answers = await pumpHome(tester: tester, project: _folder);

    answers.discover(plugins: const []);
    await landAnswer(tester);

    expect(find.byKey(const Key("new_session_no_harness_notice")), findsOneWidget);
    expect(find.byType(PregoShimmer), findsNothing);
    expect(harness, findsNothing);
  });
}
