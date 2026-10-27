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

const _frame = Duration(milliseconds: 16);

const _folder = ProjectSummary(id: "one", name: "demo-app", path: "/one", time: null);
const _scratch = ProjectSummary(id: "scratch", name: null, path: "/scratch", time: null, kind: ProjectKind.scratch);

final _options = NewSessionOptionsData(
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
);

/// The home composer as the bridge answers it part by part: harness discovery,
/// the project's worktree check and the agents and models each answer when
/// their completer does. Option loads after the first answer from [reloads]
/// in turn while any are queued.
class const _Answers({
  required final Completer<ApiResponse<NewSessionPluginDiscovery>> discovery,
  required final Completer<ApiResponse<Project>> project,
  required final Completer<NewSessionOptionsLoadResult> options,
  required final List<Completer<NewSessionOptionsLoadResult>> reloads,
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
    NewSessionOptionsLoaded(options: _options, source: NewSessionOptionsSource.aggregate, isStale: false),
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

    final answers = _Answers(discovery: Completer(), project: Completer(), options: Completer(), reloads: []);
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
    ).thenAnswer((_) => answers.reloads.isEmpty ? answers.options.future : answers.reloads.removeAt(0).future);
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

  testWidgets("a bridge with no harness folds the composer away as its notice opens, so the heading never jumps", (
    tester,
  ) async {
    final answers = await pumpHome(tester: tester, project: _folder);
    final notice = find.byKey(const Key("new_session_no_harness_notice"));
    var titleTop = tester.getRect(title).top;
    var largestStep = 0.0;
    var foldedWhileNoticeOpened = false;

    answers.discover(plugins: const []);
    for (var elapsed = Duration.zero; elapsed <= const Duration(milliseconds: 400); elapsed += _frame) {
      await tester.pump(_frame);
      final top = tester.getRect(title).top;
      largestStep = math.max(largestStep, (top - titleTop).abs());
      titleTop = top;
      foldedWhileNoticeOpened |= composer.evaluate().isNotEmpty && notice.evaluate().isNotEmpty;
    }

    // The column stays centred, so the heading follows half of what the
    // composer and its gap give up and the notice takes: frame by frame,
    // never in one step.
    expect(largestStep, lessThan(4));
    expect(foldedWhileNoticeOpened, isTrue);
    expect(composer, findsNothing);
    expect(notice, findsOneWidget);
    expect(find.byType(PregoShimmer), findsNothing);
    expect(harness, findsNothing);
  });

  group("the composer and the login card trade places", () {
    const loginHint = "Run the harness locally and use /login.";
    final card = find.byKey(const Key("new_session_login_required"));

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

    /// Brings the home to rest on [first] for its options, with [reload]
    /// queued to answer the next load.
    Future<void> pumpAnswered({
      required WidgetTester tester,
      required NewSessionOptionsLoadResult first,
      required Completer<NewSessionOptionsLoadResult> reload,
    }) async {
      final answers = await pumpHome(tester: tester, project: _folder);
      answers.discover(plugins: const [_claudeCode]);
      answers.checkProject(summary: _folder, supportsDedicatedWorktrees: true);
      await landAnswer(tester);
      answers.reloads.add(reload);
      answers.options.complete(first);
      await landAnswer(tester);
    }

    /// Steps 16 ms frames from the one that applies an answer until long
    /// after, expecting the card and the composer each to hold still while on
    /// screen, the pills and the worktree row to keep to the heading, and
    /// returns each frame's opacities and heading top, and the swap's travel:
    /// half the height the room gives up.
    Future<({List<({double? card, double? composer, double titleTop})> frames, double travel})> stepThroughSwap({
      required WidgetTester tester,
      required bool toComposer,
    }) async {
      // Zero time, but timed, so a timer due now runs as well as microtasks:
      // a logout found by a background refresh lands through one.
      await tester.pump(Duration.zero);
      final cardRect = tester.getRect(card);
      final composerRect = tester.getRect(composer);
      // Both centre on the room's middle, which the centred column holds.
      expect(cardRect.center.dy, moreOrLessEquals(composerRect.center.dy, epsilon: 0.5));
      final harnessGap = tester.getRect(harness).top - tester.getRect(title).top;
      final worktreeGap = tester.getRect(worktreeSwitch).top - tester.getRect(title).top;
      final frames = <({double? card, double? composer, double titleTop})>[];
      for (var elapsed = Duration.zero; elapsed <= const Duration(milliseconds: 400); elapsed += _frame) {
        final titleTop = tester.getRect(title).top;
        expect(tester.getRect(harness).top - titleTop, moreOrLessEquals(harnessGap, epsilon: 0.01));
        expect(tester.getRect(worktreeSwitch).top - titleTop, moreOrLessEquals(worktreeGap, epsilon: 0.01));
        if (card.evaluate().isNotEmpty) expect(tester.getRect(card), cardRect);
        if (composer.evaluate().isNotEmpty) expect(tester.getRect(composer), composerRect);
        frames.add((card: opacityOf(tester, card), composer: opacityOf(tester, composer), titleTop: titleTop));
        await tester.pump(_frame);
      }
      final shrink = toComposer ? cardRect.height - composerRect.height : composerRect.height - cardRect.height;
      return (frames: frames, travel: shrink / 2);
    }

    /// Expects [frames] to show [leaving] fading out as [arriving] fades in
    /// over it, both on screen together, and the heading gliding by [travel]
    /// over many frames rather than jumping.
    void expectCrossFade({
      required List<({double? card, double? composer, double titleTop})> frames,
      required double? Function(({double? card, double? composer, double titleTop})) leaving,
      required double? Function(({double? card, double? composer, double titleTop})) arriving,
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

      final tops = [for (final frame in frames) frame.titleTop];
      expect(travel.abs(), greaterThan(10));
      expect(tops.last - tops.first, moreOrLessEquals(travel, epsilon: 0.5));
      for (var index = 1; index < tops.length; index++) {
        final step = tops[index] - tops[index - 1];
        expect(step.sign, anyOf(0, travel.sign));
        // The steepest 16 ms of the 200 ms ease covers about an eighth.
        expect(step.abs(), lessThan(travel.abs() / 6));
      }
    }

    testWidgets("Recheck's answer fades the card out as the composer fades in, the heading gliding down", (
      tester,
    ) async {
      final recheck = Completer<NewSessionOptionsLoadResult>();
      await pumpAnswered(
        tester: tester,
        first: const NewSessionOptionsAuthenticationRequiredUnavailable(actionHint: loginHint),
        reload: recheck,
      );
      expect(card, findsOneWidget);
      expect(composer, findsNothing);
      await tester.tap(find.byKey(const Key("session_harness_recheck")));
      await landAnswer(tester);

      recheck.complete(
        NewSessionOptionsLoaded(options: _options, source: NewSessionOptionsSource.aggregate, isStale: false),
      );
      final swap = await stepThroughSwap(tester: tester, toComposer: true);

      expectCrossFade(
        frames: swap.frames,
        leaving: (frame) => frame.card,
        arriving: (frame) => frame.composer,
        travel: swap.travel,
      );
      expect(find.byType(AgentModelButtons), findsOneWidget);
    });

    testWidgets("a harness found logged out fades the composer out under the card, the heading gliding up", (
      tester,
    ) async {
      final refresh = Completer<NewSessionOptionsLoadResult>();
      await pumpAnswered(
        tester: tester,
        first: NewSessionOptionsLoaded(options: _options, source: NewSessionOptionsSource.aggregate, isStale: true),
        reload: refresh,
      );
      expect(card, findsNothing);

      refresh.complete(
        NewSessionOptionsAuthenticationRequiredRetained(
          actionHint: loginHint,
          options: _options,
          source: NewSessionOptionsSource.aggregate,
        ),
      );
      final swap = await stepThroughSwap(tester: tester, toComposer: false);

      expectCrossFade(
        frames: swap.frames,
        leaving: (frame) => frame.composer,
        arriving: (frame) => frame.card,
        travel: swap.travel,
      );
    });

    testWidgets("reduced motion swaps the card for the composer in one frame", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final recheck = Completer<NewSessionOptionsLoadResult>();
      await pumpAnswered(
        tester: tester,
        first: const NewSessionOptionsAuthenticationRequiredUnavailable(actionHint: loginHint),
        reload: recheck,
      );
      final titleTop = tester.getRect(title).top;
      await tester.tap(find.byKey(const Key("session_harness_recheck")));
      await landAnswer(tester);

      recheck.complete(
        NewSessionOptionsLoaded(options: _options, source: NewSessionOptionsSource.aggregate, isStale: false),
      );
      await tester.pump();
      expect(card, findsNothing);
      expect(opacityOf(tester, composer), 1);
      final settledTop = tester.getRect(title).top;
      expect(settledTop, greaterThan(titleTop + 10));
      for (var index = 0; index < 15; index++) {
        await tester.pump(_frame);
        expect(tester.getRect(title).top, settledTop);
      }
    });
  });
}
