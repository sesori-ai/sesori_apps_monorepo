import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/semantics.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_desktop/core/widgets/desktop_connection_pill.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late _MockBridgeControlCubit bridgeControlCubit;
  late _MockConnectionOverlayCubit overlay;
  late int contentTaps;
  late _MockProjectListCubit projects;
  late _MockRecentSessionsCubit recent;
  late _MockRepository repository;
  late DesktopSidebarCubit sidebar;
  late _MockRefreshService refreshService;

  setUpAll(() => registerFallbackValue(const DesktopSidebarLayout()));
  setUp(() {
    bridgeControlCubit = _MockBridgeControlCubit();
    overlay = _MockConnectionOverlayCubit();
    contentTaps = 0;
    whenListen(
      overlay,
      const Stream<ConnectionOverlayState>.empty(),
      initialState: const ConnectionOverlayState.hidden(connected: true),
    );
    projects = _MockProjectListCubit();
    recent = _MockRecentSessionsCubit();
    whenListen(
      recent,
      const Stream<Map<String, RecentSessionsEntry>>.empty(),
      initialState: const <String, RecentSessionsEntry>{},
    );
    when(() => recent.retry(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(
        projects: [ProjectSummary(id: "project-1", name: "Sesori Desktop", path: "/work/sesori", time: null)],
        activityById: {},
      ),
    );
    refreshService = _MockRefreshService();
    when(refreshService.refresh).thenAnswer((_) async => DesktopSidebarRefreshOutcome.succeeded);
    repository = _MockRepository();
    when(repository.readSidebarLayout).thenAnswer((_) async => const DesktopSidebarLayout());
    when(() => repository.writeSidebarLayout(layout: any(named: "layout"))).thenAnswer((_) async {});
  });

  Widget app({required BridgeControlState state, Widget? child}) {
    whenListen(bridgeControlCubit, const Stream<BridgeControlState>.empty(), initialState: state);
    return MultiBlocProvider(
      providers: [
        BlocProvider<BridgeControlCubit>.value(value: bridgeControlCubit),
        BlocProvider<ConnectionOverlayCubit>.value(value: overlay),
      ],
      child: MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // As in the router, the cockpit's cubits sit below the root navigator,
        // out of reach of the popups it hosts.
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ProjectListCubit>.value(value: projects),
            BlocProvider<RecentSessionsCubit>.value(value: recent),
            BlocProvider(create: (_) => DesktopSidebarRefreshCubit(service: refreshService)),
            BlocProvider<DesktopSidebarCubit>(create: (_) => sidebar = DesktopSidebarCubit(repository: repository)),
          ],
          child:
              child ??
              DesktopCockpitShell(
                selectedProjectId: "project-1",
                selectedSessionId: null,
                onOpenSession: _openSession,
                onNewSession: _openProject,
                sessionActions: _sessionActions,
                onOpenProject: _openProject,
                onOpenBridgeSettings: _noOp,
                onOpenProjects: _noOp,
                onOpenSettings: _noOp,
                child: GestureDetector(
                  key: const Key("cockpit-content"),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => contentTaps++,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
        ),
      ),
    );
  }

  final running = _state(processState: const BridgeProcessRunning(pid: 42));
  final rail = find.byKey(const Key("desktop-cockpit-sidebar"));
  final resize = find.byKey(const Key("desktop-sidebar-resize"));
  final toggle = find.byKey(const Key("desktop-sidebar-toggle"));

  testWidgets("sidebar shortcut preserves focus, ignores repeats and respects automatic collapse", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          selectedProjectId: "project-1",
          selectedSessionId: null,
          onOpenSession: _openSession,
          onNewSession: _openProject,
          sessionActions: _sessionActions,
          onOpenProject: _openProject,
          onOpenBridgeSettings: _noOp,
          onOpenProjects: _noOp,
          onOpenSettings: _noOp,
          child: TextField(focusNode: focus),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final macOS = defaultTargetPlatform == TargetPlatform.macOS;
    final modifier = macOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;
    final hint = macOS ? "⌘" : "Ctrl+";
    expect(find.byTooltip("Collapse sidebar (${hint}B)"), findsOneWidget);
    expect(find.byTooltip("Settings ($hint,)"), findsOneWidget);
    expect(find.byTooltip("New session in Sesori Desktop (${hint}N)"), findsOneWidget);
    // The cockpit admits shortcuts before a child requests focus.
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    expect(sidebar.state.collapsed, isTrue);
    expect(tester.getSize(rail).width, 56);
    expect(find.byTooltip("Expand sidebar (${hint}B)"), findsOneWidget);
    focus.requestFocus();
    await tester.pump();
    final wrongModifier = macOS ? LogicalKeyboardKey.controlLeft : LogicalKeyboardKey.metaLeft;
    await tester.sendKeyDownEvent(wrongModifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(wrongModifier);
    expect(sidebar.state.collapsed, isTrue);
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    expect(sidebar.state.collapsed, isFalse);
    expect(tester.getSize(rail).width, 260);
    expect(focus.hasFocus, isTrue);
    verify(() => repository.writeSidebarLayout(layout: any(named: "layout"))).called(2);
    tester.view.physicalSize = const Size(700, 600);
    await tester.pump();
    expect(find.byTooltip("Collapse sidebar"), findsOneWidget);
    expect(find.byIcon(TablerRegular.layout_sidebar_left_collapse), findsOneWidget);
    expect(tester.widget<IconButton>(toggle).onPressed, isNull);
    await tester.pumpAndSettle();
    expect(find.byTooltip("Expand sidebar"), findsOneWidget);
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    expect(sidebar.state.collapsed, isFalse);
    expect(tester.getSize(rail).width, 56);
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    tester.view.physicalSize = const Size(900, 600);
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 260);
    expect(focus.hasFocus, isTrue);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets("only the selected project's New session control advertises the shortcut", (tester) async {
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(
        projects: [
          ProjectSummary(id: "project-1", name: "Selected", path: "/work/selected", time: null),
          ProjectSummary(id: "project-2", name: "Another", path: "/work/another", time: null),
        ],
        activityById: {},
      ),
    );
    await tester.pumpWidget(app(state: running));
    await tester.pumpAndSettle();
    final hint = defaultTargetPlatform == TargetPlatform.macOS ? "⌘N" : "Ctrl+N";
    expect(find.byTooltip("New session in Selected ($hint)"), findsOneWidget);
    expect(find.byTooltip("New session in Another"), findsOneWidget);
  });

  testWidgets("compact home and Settings remain screen-reader actions", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      var opens = 0;
      await tester.pumpWidget(
        app(
          state: running,
          child: DesktopCockpitShell(
            selectedProjectId: null,
            selectedSessionId: null,
            onOpenSession: _openSession,
            onNewSession: _openProject,
            sessionActions: _sessionActions,
            onOpenProject: _openProject,
            onOpenBridgeSettings: () => opens++,
            onOpenProjects: () => opens++,
            onOpenSettings: () => opens++,
            child: const SizedBox.shrink(),
          ),
        ),
      );
      final projectsAction = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == "Projects",
      );
      expect(tester.widget<Semantics>(projectsAction).properties.selected, isTrue);
      for (final finder in [projectsAction, find.byKey(const Key("desktop-sidebar-settings"))]) {
        final node = tester.getSemantics(finder);
        expect(node.label, finder == projectsAction ? "Projects" : "Settings");
        tester.platformDispatcher.onSemanticsActionEvent!(
          SemanticsActionEvent(type: SemanticsAction.tap, nodeId: node.id, viewId: tester.view.viewId),
        );
      }
      expect(opens, 2);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets("Bridge opens in expanded and compact mode without replacing the main pane", (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [560.0, 1060.0]) {
      tester.view.physicalSize = Size(width, 480);
      await tester.pumpWidget(app(state: running));
      await tester.pumpAndSettle();
      final page = tester.element(find.byKey(const Key("cockpit-content")));
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == "This computer, Bridge status",
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("desktop-bridge-popover")), findsOneWidget);
      expect(tester.element(find.byKey(const Key("cockpit-content"))), same(page));
      await tester.tapAt(Offset(width - 10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key("desktop-bridge-popover")), findsNothing);
      expect(contentTaps, 0);
    }
  });

  testWidgets("the sidebar is the only navigation pane at every desktop width", (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [560.0, 900.0, 1400.0]) {
      tester.view.physicalSize = Size(width, 700);
      await tester.pumpWidget(app(state: running));
      await tester.pumpAndSettle();
      final mainPane = find.byKey(const Key("cockpit-content"));
      final dividerWidth = width < DesktopCockpitShell.autoCollapseBreakpoint ? 1 : 6;
      expect(tester.getSize(mainPane).width, width - tester.getSize(rail).width - dividerWidth);
      expect(find.byType(SessionSplitShell), findsNothing);
      expect(find.byType(SessionListPanel), findsNothing);
    }
  });

  testWidgets("retry uses the failure-aware reconnect path", (tester) async {
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.failed(reason: RemoteFailureReason.networkDown),
    );
    when(projects.retryLoadProjects).thenAnswer((_) async {});
    await tester.pumpWidget(app(state: running));
    expect(tester.widget<IconButton>(find.byKey(const Key("desktop-sidebar-refresh"))).onPressed, isNull);
    await tester.tap(find.text("Retry"));
    verify(projects.retryLoadProjects).called(1);
    verifyNever(projects.refreshProjects);
  });

  for (final outcome in DesktopSidebarRefreshOutcome.values) {
    testWidgets("keyboard refresh stays busy until ${outcome.name} and retains useful rows", (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final reply = Completer<DesktopSidebarRefreshOutcome>();
        when(refreshService.refresh).thenAnswer((_) => reply.future);
        await tester.pumpWidget(app(state: running));
        await tester.pumpAndSettle();
        expect(find.byTooltip(RegExp(r"^New session \(")), findsNothing);
        expect(find.byTooltip("This computer, Bridge status"), findsOneWidget);
        final refresh = find.byKey(const Key("desktop-sidebar-refresh"));
        final icon = find.descendant(of: refresh, matching: find.byType(Icon));
        Focus.of(tester.element(icon)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(tester.widget<IconButton>(refresh).onPressed, isNull);
        expect(find.bySemanticsLabel("Refreshing projects and sessions"), findsOneWidget);
        expect(find.descendant(of: refresh, matching: find.byType(PregoActivityIndicator)), findsOneWidget);
        expect(find.text("Sesori Desktop"), findsOneWidget);
        expect(tester.widget<IconButton>(find.byKey(const Key("desktop-sidebar-settings"))).onPressed, isNotNull);
        verify(refreshService.refresh).called(1);
        verifyNever(projects.refreshProjects);
        reply.complete(outcome);
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(refresh).onPressed, isNotNull);
        expect(find.text("Sesori Desktop"), findsOneWidget);
        expect(
          find.text(
            outcome == DesktopSidebarRefreshOutcome.succeeded
                ? "Projects and sessions updated"
                : "Could not refresh projects and sessions",
          ),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets("refresh is disabled during initial load, disconnection and existing project refresh", (tester) async {
    for (final state in <ProjectListState>[
      const ProjectListState.loading(),
      const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true),
      const ProjectListState.loaded(projects: [], activityById: {}, isRefreshing: true),
    ]) {
      whenListen(projects, const Stream<ProjectListState>.empty(), initialState: state);
      await tester.pumpWidget(app(state: running));
      await tester.pump();
      expect(tester.widget<IconButton>(find.byKey(const Key("desktop-sidebar-refresh"))).onPressed, isNull);
    }
    verifyNever(refreshService.refresh);
  });

  testWidgets("project row identity follows live reordering and removal", (tester) async {
    const first = ProjectSummary(id: "one", name: "First project", path: "/work/first", time: null);
    const second = ProjectSummary(id: "two", name: "Second project", path: "/work/second", time: null);
    final updates = StreamController<ProjectListState>();
    whenListen(
      projects,
      updates.stream,
      initialState: const ProjectListState.loaded(projects: [first, second], activityById: {}),
    );
    await tester.pumpWidget(app(state: running));
    final original = tester.element(find.byKey(const ValueKey("one")));
    updates.add(const ProjectListState.loaded(projects: [second, first], activityById: {}));
    await tester.pumpAndSettle();
    expect(tester.element(find.byKey(const ValueKey("one"))), same(original));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("two"))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey("one"))).dy),
    );
    updates.add(const ProjectListState.loaded(projects: [second], activityById: {}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("one")), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await updates.close();
  });

  testWidgets("project rendering never dispatches recent-session loads", (tester) async {
    final updates = StreamController<ProjectListState>();
    const added = ProjectSummary(id: "project-2", name: "Two", path: "/two", time: null);
    whenListen(
      projects,
      updates.stream,
      initialState: projects.state,
    );

    await tester.pumpWidget(app(state: running));
    updates.add(const ProjectListState.loaded(projects: [added], activityById: {}));
    await tester.pumpAndSettle();

    verifyNever(() => recent.retry(projectId: any(named: "projectId")));
    await tester.pumpWidget(const SizedBox.shrink());
    await updates.close();
  });

  testWidgets("priority activity stays global, counted, selected and actionable", (tester) async {
    const projectOne = ProjectSummary(id: "project-1", name: "Project One", path: "/one", time: null);
    const projectTwo = ProjectSummary(id: "project-2", name: "Project Two", path: "/two", time: null);
    final priority = _session(id: "priority").copyWith(unseen: true);
    final ordinary = _session(id: "ordinary");
    final runningSession = _session(id: "running").copyWith(projectID: "project-2", directory: "/two");
    when(repository.readSidebarLayout).thenAnswer(
      (_) async => const DesktopSidebarLayout(collapsedProjectIds: {"project-1", "project-2"}),
    );
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(projects: [projectOne, projectTwo], activityById: {}),
    );
    whenListen(
      recent,
      const Stream<Map<String, RecentSessionsEntry>>.empty(),
      initialState: {
        "project-1": RecentSessionsLoaded(
          sourceSessions: [priority, ordinary],
          visibleSessions: [priority, ordinary],
          activityBySessionId: const {},
          listStateBySessionId: const {},
        ),
        "project-2": RecentSessionsLoaded(
          sourceSessions: [runningSession],
          visibleSessions: [runningSession],
          activityBySessionId: const {
            "running": SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
          },
          listStateBySessionId: const {},
        ),
      },
    );
    String? openedSession;
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          selectedProjectId: "project-1",
          selectedSessionId: "priority",
          onOpenSession: ({required context, required project, required displayName, required session}) =>
              openedSession = session.id,
          onNewSession: _openProject,
          sessionActions: _sessionActions,
          onOpenProject: _openProject,
          onOpenBridgeSettings: _noOp,
          onOpenProjects: _noOp,
          onOpenSettings: _noOp,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Activity · 2"), findsOneWidget);
    final priorityRow = find.byKey(const ValueKey("sidebar-activity-session-project-1-priority"));
    final runningRow = find.byKey(const ValueKey("sidebar-activity-session-project-2-running"));
    expect(priorityRow, findsOneWidget);
    expect(runningRow, findsOneWidget);
    expect(find.byKey(const ValueKey("sidebar-session-project-1-priority")), findsNothing);
    expect(find.text("priority"), findsOneWidget);
    expect(find.text("Project One"), findsNWidgets(2));
    expect(
      tester
          .widget<Semantics>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && (widget.properties.label?.startsWith("priority in Project One") ?? false),
            ),
          )
          .properties
          .selected,
      isTrue,
    );
    await tester.tap(priorityRow);
    expect(openedSession, "priority");
    final activityMenu = find.descendant(of: priorityRow, matching: find.byType(PregoAnchorMenu));
    expect(activityMenu, findsOneWidget);
    expect(tester.widget<PregoAnchorMenu>(activityMenu).acquireOpenLease, isNotNull);
  });

  testWidgets("Activity lists what is in motion above project rows that never move", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final session = _session(
      id: "moving",
    ).copyWith(unseen: true, time: const SessionTime(created: 1, updated: 5, archived: null));
    final updates = StreamController<Map<String, RecentSessionsEntry>>();
    Map<String, RecentSessionsEntry> entries({required Session session, required bool unseen}) => {
      "project-1": RecentSessionsLoaded(
        sourceSessions: [session],
        visibleSessions: [session],
        activityBySessionId: const {},
        listStateBySessionId: {"moving": (unseen: unseen, lastUserActivityAt: null)},
      ),
    };
    whenListen(recent, updates.stream, initialState: entries(session: session, unseen: false));
    Widget shell({required String? selectedSessionId}) => app(
      state: running,
      child: DesktopCockpitShell(
        selectedProjectId: "project-1",
        selectedSessionId: selectedSessionId,
        onOpenSession: _openSession,
        onNewSession: _openProject,
        sessionActions: _sessionActions,
        onOpenProject: _openProject,
        onOpenBridgeSettings: _noOp,
        onOpenProjects: _noOp,
        onOpenSettings: _noOp,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pumpWidget(shell(selectedSessionId: null));
    final projectElement = tester.element(find.byKey(const ValueKey("project-1")));
    final ordinaryRow = find.byKey(const ValueKey("sidebar-session-project-1-moving"));
    final activityRow = find.byKey(const ValueKey("sidebar-activity-session-project-1-moving"));
    expect(find.byKey(const Key("desktop-sidebar-activity-header"), skipOffstage: false), findsOneWidget);
    expect(ordinaryRow, findsOneWidget);
    expect(activityRow, findsNothing);
    expect(
      tester
          .widget<PregoAnchorMenu>(find.descendant(of: ordinaryRow, matching: find.byType(PregoAnchorMenu)))
          .acquireOpenLease,
      isNotNull,
    );

    updates.add(entries(session: session, unseen: true));
    await tester.pump();
    expect(ordinaryRow, findsOneWidget);
    expect(activityRow, findsOneWidget);
    expect(tester.element(find.byKey(const ValueKey("project-1"))), same(projectElement));

    // Opening it from Activity marks it seen; it stays listed while selected.
    await tester.pumpWidget(shell(selectedSessionId: "moving"));
    updates.add(entries(session: session, unseen: false));
    await tester.pump();
    expect(activityRow, findsOneWidget);
    await tester.pumpWidget(shell(selectedSessionId: null));
    expect(activityRow, findsNothing);
    expect(ordinaryRow, findsOneWidget);

    // Marked unread on purpose: out of Activity until the agent moves the stamp.
    deferMarkedUnreadSession(context: tester.element(find.byType(DesktopCockpitShell)), session: session);
    updates.add(entries(session: session, unseen: true));
    await tester.pump();
    expect(activityRow, findsNothing);
    expect(ordinaryRow, findsOneWidget);
    updates.add(
      entries(
        session: session.copyWith(time: const SessionTime(created: 1, updated: 6, archived: null)),
        unseen: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(activityRow, findsOneWidget);
    await updates.close();
  });

  testWidgets("recent inventory failure stays project-local and retries explicitly", (tester) async {
    whenListen(
      recent,
      const Stream<Map<String, RecentSessionsEntry>>.empty(),
      initialState: const {
        "project-1": RecentSessionsFailed(reason: RemoteFailureReason.networkDown),
      },
    );
    when(() => recent.retry(projectId: "project-1")).thenAnswer((_) async {});

    await tester.pumpWidget(app(state: running));
    final activityHeader = find.byKey(const Key("desktop-sidebar-activity-header"), skipOffstage: false);
    expect(activityHeader, findsOneWidget);
    await tester.tap(find.text("Retry"));
    verify(() => recent.retry(projectId: "project-1")).called(1);
  });

  testWidgets("renders shared projects and dispatches existing route actions", (tester) async {
    var bridgeOpens = 0;
    var projectOpens = 0;
    var settingsOpens = 0;
    String? openedProject;
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          selectedProjectId: "project-1",
          selectedSessionId: null,
          onOpenSession: _openSession,
          onNewSession: _openProject,
          sessionActions: _sessionActions,
          onOpenProject: ({required context, required project, required displayName}) => openedProject = project.id,
          onOpenBridgeSettings: () => bridgeOpens++,
          onOpenProjects: () => projectOpens++,
          onOpenSettings: () => settingsOpens++,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getSize(rail).width, 260);
    await tester.tap(find.text("This computer"));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("desktop-bridge-popover")), findsOneWidget);
    expect(bridgeOpens, 0);
    await tester.tap(find.text("Bridge settings…"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("desktop-sidebar-settings")));
    await tester.tap(find.text("Sesori Desktop"));
    expect((bridgeOpens, projectOpens, settingsOpens, openedProject), (1, 0, 1, "project-1"));
  });

  testWidgets("recent tree pins selection, keeps route actions, and persists project collapse", (tester) async {
    final sessions = [for (var index = 1; index <= 4; index++) _session(id: "session-$index")];
    whenListen(
      recent,
      const Stream<Map<String, RecentSessionsEntry>>.empty(),
      initialState: {
        "project-1": RecentSessionsLoaded(
          sourceSessions: sessions,
          visibleSessions: sessions,
          activityBySessionId: const {},
          listStateBySessionId: const {},
        ),
      },
    );
    String? openedSession;
    var newSessions = 0;
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          selectedProjectId: "project-1",
          selectedSessionId: "session-4",
          sessionActions: _sessionActions,
          onOpenSession: ({required context, required project, required displayName, required session}) =>
              openedSession = session.id,
          onNewSession: ({required context, required project, required displayName}) => newSessions++,
          onOpenProject: _openProject,
          onOpenBridgeSettings: _noOp,
          onOpenProjects: _noOp,
          onOpenSettings: _noOp,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    // The selected session is pinned under the three newest, so nothing is left to show.
    expect(find.byKey(const ValueKey("sidebar-show-more-project-1")), findsNothing);
    for (final session in sessions) {
      expect(find.text(session.title!), findsOneWidget);
    }
    final selected = find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == "session-4");
    expect(tester.widget<Semantics>(selected).properties.selected, isTrue);
    await tester.tap(find.text("session-4"));
    expect(openedSession, "session-4");
    final projectToggle = find.byKey(const ValueKey("sidebar-project-toggle-project-1"));
    await tester.tap(projectToggle);
    await tester.pump();
    expect(find.text("session-4"), findsNothing);
    expect(sidebar.state.collapsedProjectIds, {"project-1"});
    verify(() => repository.writeSidebarLayout(layout: const DesktopSidebarLayout(collapsedProjectIds: {"project-1"})))
        .called(1);
    await tester.tap(projectToggle);
    await tester.pump();
    expect(find.text("session-4"), findsOneWidget);
    final add = find.byKey(const ValueKey("sidebar-new-session-project-1"));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(add));
    await tester.pump();
    await mouse.down(tester.getCenter(add));
    await mouse.up();
    expect(newSessions, 1);
    await mouse.removePointer();
    await tester.tap(find.text("Sesori Desktop"), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text("Rename"), findsOneWidget);
    expect(find.text("Hide Project"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("show more grows a project's rows in place and folding the project starts over", (tester) async {
    final sessions = [for (var index = 1; index <= 15; index++) _session(id: "session-$index")];
    whenListen(
      recent,
      const Stream<Map<String, RecentSessionsEntry>>.empty(),
      initialState: {
        "project-1": RecentSessionsLoaded(
          sourceSessions: sessions,
          visibleSessions: sessions,
          activityBySessionId: const {},
          listStateBySessionId: const {},
        ),
      },
    );
    await tester.pumpWidget(app(state: running));
    final rows = find.textContaining("session-");
    final showMore = find.byKey(const ValueKey("sidebar-show-more-project-1"));
    expect(rows, findsNWidgets(3));
    final showMoreLabel = tester.widget<Text>(find.text("Show more"));
    expect(showMoreLabel.maxLines, 1);
    expect(showMoreLabel.style?.fontFamily, startsWith("packages/theme_prego/"));
    await tester.tap(showMore);
    await tester.pumpAndSettle();
    expect(rows, findsNWidgets(13));
    await tester.ensureVisible(showMore);
    await tester.pump();
    await tester.tap(showMore);
    await tester.pumpAndSettle();
    expect(rows, findsNWidgets(15));
    expect(showMore, findsNothing);

    // The list is scrolled by now, so fold through the cubit the chevron calls.
    await sidebar.toggleProject(projectId: "project-1");
    await tester.pump();
    expect(rows, findsNothing);
    await sidebar.toggleProject(projectId: "project-1");
    await tester.pumpAndSettle();
    expect(rows, findsNWidgets(3));
  });

  testWidgets("section headers fold their rows and persist, and the rail has no folded sections", (tester) async {
    final session = _session(id: "moving").copyWith(unseen: true);
    whenListen(
      recent,
      const Stream<Map<String, RecentSessionsEntry>>.empty(),
      initialState: {
        "project-1": RecentSessionsLoaded(
          sourceSessions: [session],
          visibleSessions: [session],
          activityBySessionId: const {},
          listStateBySessionId: const {},
        ),
      },
    );
    await tester.pumpWidget(app(state: running));
    final activityRow = find.byKey(const ValueKey("sidebar-activity-session-project-1-moving"));
    final project = find.byKey(const ValueKey("project-1"));
    expect(activityRow, findsOneWidget);

    await tester.tap(find.text("Activity · 1"));
    await tester.pumpAndSettle();
    expect(activityRow, findsNothing);
    expect(project, findsOneWidget);
    await tester.tap(find.text("Projects"));
    await tester.pumpAndSettle();
    expect(project, findsNothing);
    verify(
      () => repository.writeSidebarLayout(
        layout: const DesktopSidebarLayout(activitySectionCollapsed: true, projectsSectionCollapsed: true),
      ),
    ).called(1);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 56);
    expect(find.byKey(const Key("desktop-sidebar-rail-activity")), findsOneWidget);
    expect(project, findsOneWidget);
  });

  testWidgets("the rail's one Activity button counts and pops out live rows beside it", (tester) async {
    const projectOne = ProjectSummary(id: "project-1", name: "Project One", path: "/one", time: null);
    const projectTwo = ProjectSummary(id: "project-2", name: "Project Two", path: "/two", time: null);
    final priority = _session(id: "priority").copyWith(unseen: true);
    final runningSession = _session(id: "running").copyWith(projectID: "project-2", directory: "/two");
    Map<String, RecentSessionsEntry> entries({required bool stillRunning}) => {
      "project-1": RecentSessionsLoaded(
        sourceSessions: [priority],
        visibleSessions: [priority],
        activityBySessionId: const {},
        listStateBySessionId: const {},
      ),
      "project-2": RecentSessionsLoaded(
        sourceSessions: [runningSession],
        visibleSessions: [runningSession],
        activityBySessionId: {
          if (stillRunning)
            "running": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
        },
        listStateBySessionId: const {},
      ),
    };
    final updates = StreamController<Map<String, RecentSessionsEntry>>();
    when(repository.readSidebarLayout).thenAnswer((_) async => const DesktopSidebarLayout(collapsed: true));
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(projects: [projectOne, projectTwo], activityById: {}),
    );
    whenListen(recent, updates.stream, initialState: entries(stillRunning: true));
    String? openedSession;
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          selectedProjectId: null,
          selectedSessionId: null,
          onOpenSession: ({required context, required project, required displayName, required session}) =>
              openedSession = session.id,
          onNewSession: _openProject,
          sessionActions: _sessionActions,
          onOpenProject: _openProject,
          onOpenBridgeSettings: _noOp,
          onOpenProjects: _noOp,
          onOpenSettings: _noOp,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 56);

    // One Activity button, then one chip per project: no session stands in as its project.
    final button = find.byKey(const Key("desktop-sidebar-rail-activity"));
    expect(find.descendant(of: button, matching: find.text("2")), findsOneWidget);
    expect(find.byTooltip("Activity · 2, Running"), findsOneWidget);
    expect(find.byType(PregoAvatarInitials), findsNWidgets(2));
    expect(find.text("priority"), findsNothing);

    await tester.tap(button);
    await tester.pumpAndSettle();
    final popout = find.byKey(const Key("desktop-sidebar-activity-popout"));
    expect(tester.getTopLeft(popout).dx, greaterThan(56));
    expect(find.descendant(of: popout, matching: find.text("priority")), findsOneWidget);
    expect(find.descendant(of: popout, matching: find.text("running")), findsOneWidget);

    // The open popout follows the cubits: a finished, seen session leaves it.
    updates.add(entries(stillRunning: false));
    await tester.pumpAndSettle();
    expect(find.descendant(of: popout, matching: find.text("running")), findsNothing);

    await tester.tap(find.descendant(of: popout, matching: find.text("priority")));
    await tester.pumpAndSettle();
    expect(openedSession, "priority");
    expect(popout, findsNothing);
    await updates.close();
  });

  testWidgets("session status signals stay inside the row while the rail collapses", (tester) async {
    final sessions = [_session(id: "session-1")];
    whenListen(
      recent,
      const Stream<Map<String, RecentSessionsEntry>>.empty(),
      initialState: {
        "project-1": RecentSessionsLoaded(
          sourceSessions: sessions,
          visibleSessions: sessions,
          activityBySessionId: const {
            "session-1": SessionActivityInfo(awaitingInput: true, lastUserActivityAt: null, updatedAt: null),
          },
          listStateBySessionId: const {},
        ),
      },
    );
    await tester.pumpWidget(app(state: running));
    expect(find.descendant(of: rail, matching: find.byIcon(TablerRegular.message_circle)), findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 56);
    expect(tester.takeException(), isNull);
  });

  testWidgets("collapsing the narrow rail keeps every session row frame inside its width", (tester) async {
    final sessions = [_session(id: "session-1")];
    whenListen(
      recent,
      const Stream<Map<String, RecentSessionsEntry>>.empty(),
      initialState: {
        "project-1": RecentSessionsLoaded(
          sourceSessions: sessions,
          visibleSessions: sessions,
          activityBySessionId: const {
            "session-1": SessionActivityInfo(awaitingInput: true, lastUserActivityAt: null, updatedAt: null),
          },
          listStateBySessionId: const {},
        ),
      },
    );
    await tester.pumpWidget(app(state: running));
    sidebar.resize(width: DesktopSidebarCubit.minWidth);
    await tester.pump();
    expect(tester.getSize(rail).width, DesktopSidebarCubit.minWidth);
    await tester.tap(toggle);
    await tester.pump();
    // Sample the whole collapse: the tail is where the row is narrower than its
    // own signals, which a coarse frame cadence can step over.
    for (var frame = 0; frame < 240; frame++) {
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets("a row shows its last activity, says it in full, and larger text drops it first", (tester) async {
    final updated = DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch;
    final sessions = [
      _session(id: "session-1").copyWith(time: SessionTime(created: 1, updated: updated, archived: null)),
    ];
    whenListen(
      recent,
      const Stream<Map<String, RecentSessionsEntry>>.empty(),
      initialState: {
        "project-1": RecentSessionsLoaded(
          sourceSessions: sessions,
          visibleSessions: sessions,
          activityBySessionId: const {},
          listStateBySessionId: const {},
        ),
      },
    );
    await tester.pumpWidget(app(state: running));
    expect(find.text("3h"), findsOneWidget);
    expect(find.byTooltip("session-1, 3h ago"), findsOneWidget);
    expect(find.bySemanticsLabel("session-1, 3h ago"), findsOneWidget);

    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();
    expect(find.text("3h"), findsNothing);
    expect(find.text("session-1"), findsOneWidget);
    expect(find.bySemanticsLabel("session-1, 3h ago"), findsOneWidget);
  });

  testWidgets("drag resizes immediately, persists on end, and double-click resets", (tester) async {
    await tester.pumpWidget(app(state: running));
    final gesture = await tester.startGesture(tester.getCenter(resize));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(tester.getSize(rail).width, 350);
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    await gesture.up();
    await tester.pump();
    verify(() => repository.writeSidebarLayout(layout: any(named: "layout"))).called(1);
    await tester.tap(resize);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(resize);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(rail).width, 260);
    verify(() => repository.writeSidebarLayout(layout: any(named: "layout"))).called(1);
  });

  for (final (bound, offsets, widths) in [
    ("maximum", [250.0, 230.0, 150.0], [420.0, 420.0, 410.0]),
    ("minimum", [-160.0, -140.0, -30.0], [200.0, 200.0, 230.0]),
  ]) {
    testWidgets("drag preserves $bound overshoot until the pointer returns inside the bound", (tester) async {
      await tester.pumpWidget(app(state: running));
      final origin = tester.getCenter(resize);
      final gesture = await tester.startGesture(origin, kind: PointerDeviceKind.mouse);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      for (var index = 0; index < offsets.length; index++) {
        await gesture.moveTo(origin + Offset(offsets[index], 0));
        await tester.pump();
        expect(tester.getSize(rail).width, widths[index]);
      }
      verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      verify(() => repository.writeSidebarLayout(layout: DesktopSidebarLayout(width: widths.last))).called(1);
    });
  }

  testWidgets("an admitted drag commits once on cancellation", (tester) async {
    await tester.pumpWidget(app(state: running));
    final gesture = await tester.startGesture(tester.getCenter(resize), kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    final layout = sidebar.state;
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 100));
    verify(() => repository.writeSidebarLayout(layout: layout)).called(1);
  });

  testWidgets("project toggle edge and scrollbar thumb remain usable", (tester) async {
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: ProjectListState.loaded(
        projects: [
          for (var index = 0; index < 20; index++)
            ProjectSummary(id: "project-$index", name: "Project $index", path: "/fixture/$index", time: null),
        ],
        activityById: const {},
      ),
    );
    await tester.pumpWidget(app(state: running));
    final list = find.byKey(const Key("desktop-sidebar-project-list"));
    final scrollable = tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    // Show the automatic desktop scrollbar at the first project's row.
    scrollable.position.jumpTo(24);
    await tester.pump(const Duration(milliseconds: 200));
    scrollable.position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 200));
    final projectToggle = find.byKey(const ValueKey("sidebar-project-toggle-project-0"));
    final button = tester.getRect(projectToggle);
    await tester.tapAt(button.centerRight - const Offset(6, 0), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(sidebar.state.collapsedProjectIds, {"project-0"});
    expect(tester.getRect(list).right - button.right, greaterThanOrEqualTo(16));
    final viewport = tester.getRect(list);
    final thumb = await tester.startGesture(
      Offset(viewport.right - 6, viewport.top + 20),
      kind: PointerDeviceKind.mouse,
    );
    await thumb.moveBy(const Offset(0, 20));
    await tester.pump();
    await thumb.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(0));
    await thumb.up();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.linux, TargetPlatform.macOS}));

  testWidgets("collapse animates into a compact rail and expands to the saved width", (tester) async {
    await tester.pumpWidget(app(state: running));
    sidebar.resize(width: 310);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(rail).width, inExclusiveRange(56, 310));
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.getSize(rail).width, 56);
    expect(find.text("Sesori Desktop"), findsNothing);
    expect(find.text("SD"), findsOneWidget);
    expect(find.byTooltip("Sesori Desktop"), findsOneWidget);
    expect(resize, findsNothing);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(rail).width, inExclusiveRange(56, 310));
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.getSize(rail).width, 310);
    expect(tester.takeException(), isNull);
  });

  for (final features in [
    const FakeAccessibilityFeatures(disableAnimations: true),
    const FakeAccessibilityFeatures(reduceMotion: true),
  ]) {
    testWidgets("collapse respects ${features.disableAnimations ? 'disabled animations' : 'platform reduced motion'}", (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(app(state: running));
      expect(tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration, Duration.zero);
      await tester.tap(toggle);
      await tester.pump();
      expect(tester.getSize(rail).width, 56);
      await tester.tap(toggle);
      await tester.pump();
      expect(tester.getSize(rail).width, 260);
    });
  }

  testWidgets("narrow-window collapse is temporary and never persisted", (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(759, 600);
    await tester.pumpWidget(app(state: running));
    expect(tester.getSize(rail).width, 56);
    expect(sidebar.state.collapsed, isFalse);
    tester.view.physicalSize = const Size(760, 600);
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 260);
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    unawaited(sidebar.toggleCollapsed());
    tester.view.physicalSize = const Size(1200, 700);
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 56);
  });

  testWidgets("compact Projects stays accessible without any project rows", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      var opens = 0;
      const states = [
        ProjectListState.loaded(projects: [], activityById: {}),
        ProjectListState.loading(),
        ProjectListState.failed(reason: RemoteFailureReason.networkDown),
        ProjectListState.bridgeDisconnected(hasRegisteredBridges: true),
        ProjectListState.bridgeDisconnected(hasRegisteredBridges: false),
      ];
      for (final state in states) {
        whenListen(projects, const Stream<ProjectListState>.empty(), initialState: state);
        await tester.pumpWidget(
          app(
            state: running,
            child: DesktopCockpitShell(
              selectedProjectId: null,
              selectedSessionId: null,
              onOpenSession: _openSession,
              onNewSession: _openProject,
              sessionActions: _sessionActions,
              onOpenProject: _openProject,
              onOpenBridgeSettings: _noOp,
              onOpenProjects: () => opens++,
              onOpenSettings: _noOp,
              child: const SizedBox.shrink(),
            ),
          ),
        );
        expect(tester.getSize(rail).width, 56);
        expect(tester.widget<IconButton>(toggle).onPressed, isNull);
        final overview = find.byKey(const Key("desktop-sidebar-projects"));
        await tester.tap(overview);
        final node = tester.getSemantics(
          find.descendant(
            of: overview,
            matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == "Projects"),
          ),
        );
        tester.platformDispatcher.onSemanticsActionEvent!(
          SemanticsActionEvent(type: SemanticsAction.tap, nodeId: node.id, viewId: tester.view.viewId),
        );
      }
      expect(opens, states.length * 2);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets("new session is the labeled primary action and new project sits on the Projects header", (tester) async {
    await tester.pumpWidget(app(state: running));
    expect(find.text("Sesori"), findsNothing);
    expect(find.text("New session"), findsOneWidget);
    expect(find.text("New project"), findsNothing);
    expect(find.text(defaultTargetPlatform == TargetPlatform.macOS ? "⌘N" : "Ctrl+N"), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key("desktop-sidebar-new-session"))).onPressed, isNotNull);
    final newProject = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key("desktop-sidebar-projects-header")),
        matching: find.byKey(const Key("desktop-sidebar-new-project")),
      ),
    );
    expect(newProject.tooltip, "New project");
    expect(newProject.onPressed, isNotNull);
    final footer = tester.widget<Container>(find.byKey(const Key("desktop-sidebar-footer")));
    expect((footer.decoration! as BoxDecoration).border, isNotNull);
  });

  group("new session", () {
    const recentProject = ProjectSummary(id: "project-recent", name: "Most recent", path: "/work/recent", time: null);
    const openProject = ProjectSummary(id: "project-open", name: null, path: "/work/open-one", time: null);
    late List<(String, String)> started;

    Widget shell({required String? selectedProjectId, required List<ProjectSummary> available}) {
      whenListen(
        projects,
        const Stream<ProjectListState>.empty(),
        initialState: ProjectListState.loaded(projects: available, activityById: const {}),
      );
      return app(
        state: running,
        child: DesktopCockpitShell(
          selectedProjectId: selectedProjectId,
          selectedSessionId: null,
          onOpenSession: _openSession,
          onNewSession: ({required context, required project, required displayName}) =>
              started.add((project.id, displayName)),
          sessionActions: _sessionActions,
          onOpenProject: _openProject,
          onOpenBridgeSettings: _noOp,
          onOpenProjects: _noOp,
          onOpenSettings: _noOp,
          child: const TextField(autofocus: true),
        ),
      );
    }

    Future<void> pressNew({required WidgetTester tester, required LogicalKeyboardKey modifier}) async {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
    }

    setUp(() => started = []);

    testWidgets("shortcut and button start in the open project and ignore repeats", (tester) async {
      await tester.pumpWidget(shell(selectedProjectId: "project-open", available: const [recentProject, openProject]));
      await tester.pumpAndSettle();
      final macOS = defaultTargetPlatform == TargetPlatform.macOS;
      await pressNew(tester: tester, modifier: macOS ? LogicalKeyboardKey.controlLeft : LogicalKeyboardKey.metaLeft);
      expect(started, isEmpty);
      await pressNew(tester: tester, modifier: macOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft);
      expect(started, [("project-open", "open-one")]);
      await tester.tap(find.byKey(const Key("desktop-sidebar-new-session")));
      expect(started, [("project-open", "open-one"), ("project-open", "open-one")]);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets("without an open project the most recently active one is used", (tester) async {
      await tester.pumpWidget(shell(selectedProjectId: null, available: const [recentProject, openProject]));
      await tester.pumpAndSettle();
      await pressNew(
        tester: tester,
        modifier: defaultTargetPlatform == TargetPlatform.macOS
            ? LogicalKeyboardKey.metaLeft
            : LogicalKeyboardKey.controlLeft,
      );
      expect(started, [("project-recent", "Most recent")]);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets("an open project missing from the inventory is never swapped for another", (tester) async {
      await tester.pumpWidget(shell(selectedProjectId: "project-hidden", available: const [recentProject]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("desktop-sidebar-new-session")));
      await tester.pumpAndSettle();
      expect(started, isEmpty);
      expect(find.byType(AddProjectDialog), findsNothing);
    });

    testWidgets("without any project it offers to add one", (tester) async {
      final connection = _MockConnectionService();
      const status = ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
        health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
      );
      when(() => connection.status).thenAnswer((_) => BehaviorSubject<ConnectionStatus>.seeded(status));
      when(() => connection.currentStatus).thenReturn(status);
      when(() => projects.fetchFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer(
        (_) async => const FilesystemSuggestionsSuccess(
          suggestions: FilesystemSuggestions(data: [], path: "/home"),
        ),
      );
      GetIt.instance.registerSingleton<ConnectionService>(connection);
      addTearDown(GetIt.instance.reset);
      await tester.pumpWidget(shell(selectedProjectId: null, available: const []));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("desktop-sidebar-new-session")));
      await tester.pumpAndSettle();
      expect(started, isEmpty);
      expect(find.byType(AddProjectDialog), findsOneWidget);
    });
  });

  testWidgets("running and unread project signals update in expanded and compact modes", (tester) async {
    const project = ProjectSummary(
      id: "project-1",
      name: "Sesori Desktop",
      path: "/work/sesori",
      time: null,
      hasUnseenChanges: true,
    );
    final updates = StreamController<ProjectListState>();
    whenListen(
      projects,
      updates.stream,
      initialState: const ProjectListState.loaded(projects: [project], activityById: {"project-1": 2}),
    );
    await tester.pumpWidget(app(state: running));
    final loc = tester.element(rail).loc;
    final native = defaultTargetPlatform == TargetPlatform.macOS;
    final runningHint = "Sesori Desktop, ${loc.projectListRunning(2)}, ${loc.projectListNewActivity}";
    expect(find.byTooltip(runningHint), findsOneWidget);
    expect(tester.widget<PregoAiLoader>(find.byType(PregoAiLoader)).animate, isTrue);
    expect(find.byType(AppKitView), native ? findsOneWidget : findsNothing);
    expect(
      tester.getCenter(find.byType(PregoAiLoader)).dx,
      greaterThan(tester.getCenter(find.text("Sesori Desktop")).dx),
    );
    expect(
      tester.getCenter(find.byType(PregoAiLoader)).dx,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey("sidebar-new-session-project-1"))).dx),
    );
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(AppKitView), native ? findsNWidgets(2) : findsNothing);
    await tester.pump(const Duration(milliseconds: 170));
    expect(tester.getSize(rail).width, 56);
    expect(find.byTooltip(runningHint), findsOneWidget);
    expect(tester.getCenter(find.byType(PregoAiLoader)).dx, lessThan(56));
    updates.add(const ProjectListState.loaded(projects: [project], activityById: {}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.widget<PregoAiLoader>(find.byType(PregoAiLoader)).animate, isFalse);
    expect(find.byType(AppKitView), native ? findsOneWidget : findsNothing);
    expect(find.byTooltip("Sesori Desktop, ${loc.projectListNewActivity}"), findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    updates.add(
      const ProjectListState.loaded(projects: [project], activityById: {}, unseenByProjectId: {"project-1": false}),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PregoAiLoader), findsNothing);
    expect(find.byTooltip("Sesori Desktop"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await updates.close();
  }, variant: const TargetPlatformVariant({TargetPlatform.linux, TargetPlatform.macOS}));

  testWidgets("connection transitions overlay unchanged content bounds", (tester) async {
    final root = app(state: running);
    final updates = StreamController<ConnectionOverlayState>();
    addTearDown(updates.close);
    whenListen(overlay, updates.stream, initialState: const ConnectionOverlayState.hidden(connected: true));
    await tester.pumpWidget(root);
    final content = find.byKey(const Key("cockpit-content"));
    final bounds = tester.getRect(content);
    for (final state in [
      const ConnectionOverlayState.reconnecting(),
      const ConnectionOverlayState.bridgeOffline(),
      const ConnectionOverlayState.connectionLost(),
      const ConnectionOverlayState.hidden(connected: true),
    ]) {
      updates.add(state);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getRect(content), bounds);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const Key("desktop-connection-pill")),
        state is ConnectionOverlayHidden ? findsNothing : findsOneWidget,
      );
      expect(tester.getRect(content), bounds);
    }
  });

  testWidgets("intentional Off suppresses bridge-offline but retains relay recovery", (tester) async {
    final root = app(state: _state(processState: const BridgeProcessStopped()));
    final updates = StreamController<ConnectionOverlayState>();
    addTearDown(updates.close);
    whenListen(overlay, updates.stream, initialState: const ConnectionOverlayState.bridgeOffline());
    await tester.pumpWidget(root);
    expect(find.byKey(const Key("desktop-connection-pill")), findsNothing);
    updates.add(const ConnectionOverlayState.connectionLost());
    await tester.pumpAndSettle();
    expect(find.text("Reconnect"), findsOneWidget);
  });

  testWidgets("Retry works and a departing pill lets content receive the click", (tester) async {
    final root = app(state: running);
    final updates = StreamController<ConnectionOverlayState>();
    addTearDown(updates.close);
    whenListen(overlay, updates.stream, initialState: const ConnectionOverlayState.connectionLost());
    await tester.pumpWidget(root);
    final position = tester.getCenter(find.text("Reconnect"));
    await tester.tapAt(position);
    verify(overlay.reconnect).called(1);
    updates.add(const ConnectionOverlayState.hidden(connected: true));
    await tester.pump();
    expect(find.byKey(const Key("desktop-connection-pill")), findsOneWidget);
    final departing = find.ancestor(
      of: find.byKey(const Key("desktop-connection-pill")),
      matching: find.byType(ExcludeSemantics),
    );
    expect(tester.widget<ExcludeSemantics>(departing).excluding, isTrue);
    await tester.tapAt(position);
    verifyNever(overlay.reconnect);
    expect(contentTaps, 1);
    await tester.pumpAndSettle();
    expect(find.byType(DesktopConnectionPill), findsOneWidget);
    expect(find.byKey(const Key("desktop-connection-pill")), findsNothing);
  });

  testWidgets("compact recovery stays in the sidebar and respects command locks", (tester) async {
    when(bridgeControlCubit.takeOver).thenAnswer((_) async {});
    final base = _state(processState: const BridgeProcessContention());
    await tester.pumpWidget(app(state: base));
    final bounds = tester.getRect(find.byKey(const Key("cockpit-content")));
    final card = find.byKey(const Key("desktop-bridge-recovery"));
    expect(tester.getRect(card).right, lessThanOrEqualTo(tester.getRect(rail).right));
    expect(bounds.top, 0);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(card);
    verify(bridgeControlCubit.takeOver).called(1);
    final locked = BridgeControlState(
      trayAvailability: base.trayAvailability,
      activity: BridgeControlActivity.quitting,
      statusLabel: base.statusLabel,
      processState: base.processState,
      desiredState: base.desiredState,
      toggleTarget: base.toggleTarget,
      launchAtLoginEnabled: base.launchAtLoginEnabled,
      controlStatus: base.controlStatus,
    );
    await tester.pumpWidget(app(state: locked));
    expect(tester.widget<IconButton>(card).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets("keeps ordinary running supervision out of the content", (tester) async {
    await tester.pumpWidget(app(state: running));
    expect(find.byKey(const Key("desktop-bridge-recovery")), findsNothing);
  });

  testWidgets("renders retained bundle repair guidance with explicit retry but no child log action", (tester) async {
    when(bridgeControlCubit.startBridge).thenAnswer((_) async {});
    const message =
        "The bundled bridge is missing or does not match this app. Restart Sesori after an update. "
        "If this persists, reinstall the matching desktop download.";
    final failed = _state(processState: const BridgeProcessStartFailed(message: message));
    final widget = app(state: failed);
    final updates = StreamController<BridgeControlState>();
    addTearDown(updates.close);
    whenListen(bridgeControlCubit, updates.stream, initialState: failed);
    await tester.pumpWidget(widget);

    expect(find.byKey(const Key("desktop-bridge-recovery")), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    verifyNever(bridgeControlCubit.startBridge);
    expect(find.text("Open Logs"), findsNothing);
    await tester.ensureVisible(find.text("Retry"));
    await tester.tap(find.text("Retry"));
    verify(bridgeControlCubit.startBridge).called(1);

    updates.add(running);
    await tester.pump();
    expect(find.byKey(const Key("desktop-bridge-recovery")), findsNothing);
  });

  testWidgets("integrates crash recovery and logs in the sidebar", (tester) async {
    when(bridgeControlCubit.openLogs).thenAnswer((_) async {});
    when(bridgeControlCubit.recoverConnection).thenAnswer((_) async {});
    await tester.pumpWidget(
      app(
        state: _state(
          processState: const BridgeProcessCrashGiveUp(exitCode: 1, crashCount: 6),
        ),
      ),
    );
    expect(find.text("The local bridge stopped after repeated crashes."), findsOneWidget);
    await tester.tap(find.text("Retry"));
    await tester.tap(find.text("Open Logs"));
    verify(bridgeControlCubit.recoverConnection).called(1);
    verify(bridgeControlCubit.openLogs).called(1);
  });

  testWidgets("offers takeover from the integrated supervision surface", (tester) async {
    when(bridgeControlCubit.takeOver).thenAnswer((_) async {});
    await tester.pumpWidget(app(state: _state(processState: const BridgeProcessContention())));
    await tester.tap(find.text("Take Over"));
    verify(bridgeControlCubit.takeOver).called(1);
  });

  testWidgets("prioritizes takeover when a displaced relay meets a login-required process state", (tester) async {
    when(bridgeControlCubit.takeOver).thenAnswer((_) async {});
    await tester.pumpWidget(
      app(
        state: _state(
          processState: const BridgeProcessLoginRequired(),
          relay: ControlRelayConnectionState.takenOver,
        ),
      ),
    );
    expect(find.text("Take Over"), findsOneWidget);
    expect(find.text("Start Bridge"), findsNothing);
    await tester.tap(find.text("Take Over"));
    verify(bridgeControlCubit.takeOver).called(1);
  });

  testWidgets("offers authenticated bridge retry without CLI-install copy", (tester) async {
    when(bridgeControlCubit.recoverConnection).thenAnswer((_) async {});
    await tester.pumpWidget(app(state: _state(processState: const BridgeProcessLoginRequired())));
    expect(find.textContaining("account is required"), findsOneWidget);
    expect(find.textContaining("install"), findsNothing);
    await tester.tap(find.text("Start Bridge"));
    verify(bridgeControlCubit.recoverConnection).called(1);
  });
}

BridgeControlState _state({
  required BridgeProcessState processState,
  ControlRelayConnectionState relay = ControlRelayConnectionState.disconnected,
}) => BridgeControlState(
  trayAvailability: SystemTrayAvailability.available,
  activity: BridgeControlActivity.idle,
  statusLabel: "Bridge status",
  processState: processState,
  desiredState: processState is BridgeProcessStopped ? BridgeProcessDesiredState.off : BridgeProcessDesiredState.on,
  toggleTarget: BridgeProcessDesiredState.off,
  launchAtLoginEnabled: false,
  controlStatus: BridgeControlStatus(
    startup: ControlStartupState.ready,
    helperOnline: false,
    bridgeId: null,
    relay: relay,
    plugin: ControlPluginHealthState.unknown,
    activeSessionCount: 0,
  ),
);

Session _session({required String id}) => Session(
  id: id,
  title: id,
  projectID: "project-1",
  pluginId: "plugin-1",
  directory: "/work/sesori",
  parentID: null,
  branchName: null,
  pullRequest: null,
  time: null,
  promptDefaults: null,
  lastUserActivityAt: null,
);

const _sessionActions = SessionListActionDispatcher(onSessionDeleted: _deleted, onSessionMarkedUnread: null);
void _deleted({required BuildContext context, required String sessionId}) {}
void _openSession({
  required BuildContext context,
  required ProjectSummary project,
  required String displayName,
  required Session session,
}) {}
void _noOp() {}
void _openProject({required BuildContext context, required ProjectSummary project, required String displayName}) {}

class _MockRefreshService() extends Mock implements DesktopSidebarRefreshService;

class _MockConnectionService() extends Mock implements ConnectionService;

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
class _MockConnectionOverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit;
class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;
class _MockRecentSessionsCubit() extends MockCubit<Map<String, RecentSessionsEntry>> implements RecentSessionsCubit;
class _MockRepository() extends Mock implements DesktopInstanceRepository;
