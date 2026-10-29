import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_desktop/core/widgets/desktop_connection_pill.dart";
import "package:sesori_desktop/core/widgets/desktop_page_toolbar.dart";
import "package:sesori_desktop/core/widgets/desktop_sidebar_expansion.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late _MockBridgeControlCubit bridgeControlCubit;
  late _MockConnectionOverlayCubit overlay;
  late int contentTaps;
  late _MockProjectListCubit projects;
  late _MockProjectInventoryService projectInventory;
  late _MockSessionWindowService window;

  /// The window's loaded rows, and every session its bridge searches.
  late List<Session> loadedSessions;
  late List<Session> bridgeSessions;

  /// Why the window failed to load, or null while it loads [loadedSessions].
  late RemoteFailureReason? windowFailure;
  late BehaviorSubject<String?> filter;
  late _MockFilterTracker filterTracker;
  late _MockRepository repository;
  late DesktopSidebarCubit sidebar;
  late AllSessionsCubit sessions;
  late _MockRefreshService refreshService;
  late _MockWindowHost windowHost;
  late _MockAuthGateCubit authGate;
  late _MockLocalBridgeStartupCubit startup;
  late SessionLaunchRepository launches;

  setUpAll(() {
    registerFallbackValue(const DesktopSidebarLayout());
    registerFallbackValue((projectId: null, query: null, filter: SessionListQuickFilter.all));
  });
  tearDown(GetIt.instance.reset);
  setUp(() {
    // The shell asks for the window host on macOS only, where it hides the title bar.
    windowHost = _MockWindowHost();
    when(windowHost.startDragging).thenAnswer((_) async {});
    when(windowHost.toggleZoom).thenAnswer((_) async {});
    GetIt.instance.registerSingleton<WindowHost>(windowHost);
    launches = inMemorySessionLaunchRepository();
    bridgeControlCubit = _MockBridgeControlCubit();
    authGate = _MockAuthGateCubit();
    whenListen(authGate, const Stream<AuthGateState>.empty(), initialState: const AuthGateState.signedIn(user: null));
    startup = _MockLocalBridgeStartupCubit();
    whenListen(startup, const Stream<LocalBridgeStartupState>.empty(), initialState: LocalBridgeStartupState.settled);
    overlay = _MockConnectionOverlayCubit();
    contentTaps = 0;
    whenListen(
      overlay,
      const Stream<ConnectionOverlayState>.empty(),
      initialState: const ConnectionOverlayState.hidden(connected: true),
    );
    projects = _MockProjectListCubit();
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(projects: [_sesori], folderProjects: [_sesori], scratchProject: null),
    );
    // The inventories behind the mocked cubits, as the shared list reads them.
    projectInventory = _MockProjectInventoryService();
    when(() => projectInventory.state).thenAnswer((_) => projects.state);
    when(() => projectInventory.stateStream).thenAnswer((_) => projects.stream.shareValueSeeded(projects.state));
    // Loaded and empty: a loading list shimmers for as long as it waits.
    loadedSessions = const [];
    bridgeSessions = const [];
    windowFailure = null;
    List<Session> newestMatches({required Iterable<Session> sessions, required String query, required int limit}) =>
        (matchTitles(
          items: sessions,
          titleOf: (session) => session.title,
          query: query,
        )..sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0))).take(limit).toList();
    window = _MockSessionWindowService();
    when(() => window.mode).thenReturn(AllSessionsMode.active);
    // The window narrows its rows to the project the list selects.
    String? windowProjectId;
    when(() => window.select(key: any(named: "key"))).thenAnswer(
      (invocation) => windowProjectId = (invocation.namedArguments[#key] as SessionWindowKey).projectId,
    );
    when(() => window.key).thenAnswer(
      (_) => (projectId: windowProjectId, query: null, filter: SessionListQuickFilter.all),
    );
    when(window.reload).thenAnswer((_) async => true);
    when(() => window.state).thenAnswer(
      (_) => const Stream<SessionWindowState>.empty().shareValueSeeded(switch (windowFailure) {
        final reason? => SessionWindowFailed(reason: reason),
        null => SessionWindowLoaded(
          sessions: [
            for (final session in loadedSessions)
              if (windowProjectId == null || session.projectID == windowProjectId) session,
          ],
          counts: SessionPageCounts(all: loadedSessions.length, running: 0, unread: 0),
          nextCursor: null,
          loadMore: SessionWindowLoadMore.idle,
          awaitingAnswer: false,
        ),
      }),
    );
    when(
      () => window.searchLoaded(
        query: any(named: "query"),
        earlier: any(named: "earlier"),
        limit: any(named: "limit"),
      ),
    ).thenAnswer((invocation) {
      final earlier = invocation.namedArguments[#earlier] as List<Session>;
      final loadedIds = {for (final session in loadedSessions) session.id};
      return newestMatches(
        sessions: [...loadedSessions, ...earlier.where((session) => !loadedIds.contains(session.id))],
        query: invocation.namedArguments[#query] as String,
        limit: invocation.namedArguments[#limit] as int,
      );
    });
    when(
      () => window.search(
        query: any(named: "query"),
        limit: any(named: "limit"),
      ),
    ).thenAnswer(
      (invocation) async => SessionWindowSearchMatches(
        sessions: newestMatches(
          sessions: bridgeSessions,
          query: invocation.namedArguments[#query] as String,
          limit: invocation.namedArguments[#limit] as int,
        ),
      ),
    );
    filter = BehaviorSubject.seeded(null);
    filterTracker = _MockFilterTracker();
    when(() => filterTracker.projectId).thenAnswer((_) => filter.stream);
    when(() => filterTracker.select(projectId: any(named: "projectId"))).thenAnswer(
      (invocation) => filter.add(invocation.namedArguments[#projectId] as String?),
    );
    refreshService = _MockRefreshService();
    when(() => refreshService.scan).thenAnswer((_) => BehaviorSubject.seeded(const CatalogRescanState.idle()));
    when(refreshService.refresh).thenAnswer((_) async => true);
    repository = _MockRepository();
    when(repository.readSidebarLayout).thenAnswer((_) async => const DesktopSidebarLayout());
    when(() => repository.writeSidebarLayout(layout: any(named: "layout"))).thenAnswer((_) async {});
  });

  Widget app({required BridgeControlState state, Widget? child}) {
    whenListen(bridgeControlCubit, const Stream<BridgeControlState>.empty(), initialState: state);
    final launchService = inMemorySessionLaunchService(launchRepository: launches);
    return MultiBlocProvider(
      providers: [
        BlocProvider<BridgeControlCubit>.value(value: bridgeControlCubit),
        BlocProvider<ConnectionOverlayCubit>.value(value: overlay),
        BlocProvider<AuthGateCubit>.value(value: authGate),
        BlocProvider<LocalBridgeStartupCubit>.value(value: startup),
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
            RepositoryProvider<ProjectInventoryService>.value(value: projectInventory),
            RepositoryProvider<SessionWindowService>.value(value: window),
            RepositoryProvider.value(value: launchService),
            BlocProvider(create: (_) => SessionLaunchCubit(launchService: launchService)),
            BlocProvider(create: (_) => SessionListRefreshCubit(service: refreshService)),
            BlocProvider<DesktopSidebarCubit>(create: (_) => sidebar = DesktopSidebarCubit(repository: repository)),
            BlocProvider(
              create: (_) => PendingSessionArchiveCubit(
                cleanupService: SessionCleanupService(repository: MockSessionRepository()),
              ),
            ),
            BlocProvider(
              create: (_) => sessions = AllSessionsCubit(
                window: window,
                projectInventory: projectInventory,
                filterTracker: filterTracker,
                sseEventTracker: MockSseEventTracker(),
                sessionUnseenTracker: FakeSessionUnseenTracker(),
              ),
            ),
          ],
          child:
              child ??
              DesktopCockpitShell(
                selectedProjectId: "project-1",
                selectedSessionId: null,
                onOpenSession: _openSession,
                onNewSession: _newSession,
                sessionActions: _sessionActions,
                onOpenBridgeSettings: _noOp,
                onOpenSettings: _noOp,
                onOpenArchived: _noOp,
                onGoBack: _noOp,
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

  /// Two projects with one recent session each.
  void seedTwoProjects() {
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(
        projects: [_sesori, _landing],
        folderProjects: [_sesori, _landing],
        scratchProject: null,
      ),
    );
    loadedSessions = [
      testSession(id: "s1", title: "Fix the build", updatedAt: 2),
      testSession(id: "s2", title: "Write docs", updatedAt: 1).copyWith(projectID: "project-2"),
    ];
  }

  final running = _state(processState: const BridgeProcessRunning(pid: 42));
  final panel = find.byKey(const Key("desktop-cockpit-sidebar"));
  final resize = find.byKey(const Key("desktop-sidebar-resize"));
  final toggle = find.byKey(const Key("desktop-sidebar-toggle"));
  final restore = find.byKey(const Key("desktop-sidebar-restore"));
  final page = find.byKey(const Key("cockpit-content"));
  final list = find.byKey(const Key("desktop-sidebar-session-list"));
  final filterTrigger = find.byKey(const Key("desktop-sidebar-filter"));
  const margin = FloatingSidebarPanel.margin;
  // The page starts past the open panel and the gaps on either side of it, or
  // at the window's edge while the sidebar is hidden.
  double pageStart(WidgetTester tester) => tester.getTopLeft(page).dx;
  double besideOpenPanel({required double width}) => width + 2 * margin;

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
          onNewSession: _newSession,
          sessionActions: _sessionActions,
          onOpenBridgeSettings: _noOp,
          onOpenSettings: _noOp,
          onOpenArchived: _noOp,
          onGoBack: _noOp,
          child: SizedBox.expand(
            key: const Key("cockpit-content"),
            child: TextField(focusNode: focus),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final macOS = defaultTargetPlatform == TargetPlatform.macOS;
    final modifier = macOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;
    final hint = macOS ? "⌘" : "Ctrl+";
    expect(find.byTooltip("Collapse sidebar (${hint}B)"), findsOneWidget);
    expect(find.byTooltip("Settings ($hint,)"), findsOneWidget);
    // The cockpit admits shortcuts before a child requests focus.
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    expect(sidebar.state.collapsed, isTrue);
    expect(pageStart(tester), 0);
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
    expect(pageStart(tester), besideOpenPanel(width: 260));
    expect(focus.hasFocus, isTrue);
    verify(() => repository.writeSidebarLayout(layout: any(named: "layout"))).called(2);
    // Too narrow a window hides the sidebar, and neither the button nor the
    // shortcut brings it back.
    tester.view.physicalSize = const Size(700, 600);
    await tester.pumpAndSettle();
    expect(pageStart(tester), 0);
    expect(find.byTooltip("Expand sidebar"), findsOneWidget);
    expect(tester.widget<IconButton>(restore).onPressed, isNull);
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
    expect(sidebar.state.collapsed, isFalse);
    expect(pageStart(tester), 0);
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    tester.view.physicalSize = const Size(900, 600);
    await tester.pumpAndSettle();
    expect(pageStart(tester), besideOpenPanel(width: 260));
    expect(focus.hasFocus, isTrue);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets("the sidebar lists sessions across projects and opens one in its own project", (tester) async {
    seedTwoProjects();
    final opened = <(String, String, String)>[];
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          selectedProjectId: null,
          selectedSessionId: null,
          onOpenSession: ({required context, required project, required displayName, required session}) =>
              opened.add((project.id, displayName, session.id)),
          onNewSession: _newSession,
          sessionActions: _sessionActions,
          onOpenBridgeSettings: _noOp,
          onOpenSettings: _noOp,
          onOpenArchived: _noOp,
          onGoBack: _noOp,
          child: const SizedBox.expand(key: Key("cockpit-content")),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.descendant(of: filterTrigger, matching: find.text("All projects")), findsOneWidget);
    expect(find.descendant(of: list, matching: find.text("Fix the build")), findsOneWidget);
    expect(find.descendant(of: list, matching: find.text("Write docs")), findsOneWidget);
    await tester.tap(find.descendant(of: list, matching: find.text("Write docs")));
    expect(opened, [("project-2", "Landing page", "s2")]);
  });

  testWidgets("the filter heads the list, narrows it to one project and returns to all", (tester) async {
    seedTwoProjects();
    await tester.pumpWidget(
      PregoInteractionScope(
        mode: PregoInteractionMode.pointer,
        child: app(state: running),
      ),
    );
    await tester.pumpAndSettle();
    final picker = find.byType(PregoPickerSearchList);
    expect(tester.getBottomLeft(filterTrigger).dy, lessThanOrEqualTo(tester.getTopLeft(list).dy));
    await tester.tap(filterTrigger);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: picker, matching: find.text("Landing page")));
    await tester.pumpAndSettle();
    expect(filter.value, "project-2");
    expect(find.descendant(of: filterTrigger, matching: find.text("Landing page")), findsOneWidget);
    expect(find.descendant(of: list, matching: find.text("Write docs")), findsOneWidget);
    expect(find.descendant(of: list, matching: find.text("Fix the build")), findsNothing);
    await tester.tap(filterTrigger);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: picker, matching: find.text("All projects")));
    await tester.pumpAndSettle();
    expect(filter.value, isNull);
    expect(find.descendant(of: filterTrigger, matching: find.text("All projects")), findsOneWidget);
    expect(find.descendant(of: list, matching: find.text("Fix the build")), findsOneWidget);
  });

  testWidgets("a hidden sidebar comes back from the page's corner, which the toolbar leaves free", (tester) async {
    await tester.pumpWidget(
      app(
        state: running,
        child: const DesktopCockpitShell(
          selectedProjectId: null,
          selectedSessionId: null,
          onOpenSession: _openSession,
          onNewSession: _newSession,
          sessionActions: _sessionActions,
          onOpenBridgeSettings: _noOp,
          onOpenSettings: _noOp,
          onOpenArchived: _noOp,
          onGoBack: _noOp,
          child: DesktopPageToolbar(
            breadcrumb: null,
            status: null,
            title: "Fixture page",
            subtitle: null,
            actions: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = find.text("Fixture page");
    final titleInset = tester.getTopLeft(title).dx - besideOpenPanel(width: 260);
    expect(restore, findsNothing);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    // Midway, the button rides just ahead of the sliding title, never over it.
    expect(tester.getRect(restore).right, moreOrLessEquals(tester.getTopLeft(title).dx - titleInset));
    await tester.pumpAndSettle();
    const size = DesktopSidebarRestoreInset.buttonSize;
    expect(
      tester.getRect(restore),
      Rect.fromLTWH(DesktopSidebarRestoreInset.buttonStart, (DesktopPageToolbar.height - size) / 2, size, size),
    );
    expect(tester.getTopLeft(title).dx, titleInset + DesktopSidebarRestoreInset.buttonStart + size);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(sidebar.state.collapsed, isFalse);
    expect(tester.getTopLeft(title).dx, titleInset + besideOpenPanel(width: 260));
    expect(restore, findsNothing);
  }, variant: const TargetPlatformVariant({TargetPlatform.linux, TargetPlatform.macOS}));

  testWidgets("Archived is the row under Search, not a footer button, and opens Archived", (tester) async {
    var archivedOpens = 0;
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          selectedProjectId: null,
          selectedSessionId: null,
          onOpenSession: _openSession,
          onNewSession: _newSession,
          sessionActions: _sessionActions,
          onOpenBridgeSettings: _noOp,
          onOpenSettings: _noOp,
          onOpenArchived: () => archivedOpens++,
          onGoBack: _noOp,
          child: const SizedBox.expand(key: Key("cockpit-content")),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final search = find.byKey(const Key("desktop-sidebar-search"));
    final archived = find.byKey(const Key("desktop-sidebar-archived"));
    expect(find.descendant(of: archived, matching: find.text("Archived sessions")), findsOneWidget);
    expect(find.descendant(of: archived, matching: find.byIcon(TablerRegular.archive)), findsOneWidget);
    expect(tester.getTopLeft(archived), tester.getBottomLeft(search));
    expect(tester.getSize(archived), tester.getSize(search));
    expect(tester.getBottomLeft(archived).dy, lessThanOrEqualTo(tester.getTopLeft(filterTrigger).dy));
    final footer = find.byKey(const Key("desktop-sidebar-footer"));
    expect(find.descendant(of: footer, matching: find.byIcon(TablerRegular.archive)), findsNothing);

    await tester.tap(archived);
    expect(archivedOpens, 1);
  });

  testWidgets("Bridge opens from the footer without replacing the main pane", (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1060, 480);
    await tester.pumpWidget(app(state: running));
    await tester.pumpAndSettle();
    final content = tester.element(page);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == "This computer, Bridge status",
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("desktop-bridge-popover")), findsOneWidget);
    expect(tester.element(page), same(content));
    await tester.tapAt(const Offset(1050, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("desktop-bridge-popover")), findsNothing);
    expect(contentTaps, 0);
  });

  testWidgets("renders shared routes and dispatches existing route actions", (tester) async {
    var bridgeOpens = 0;
    var settingsOpens = 0;
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          selectedProjectId: "project-1",
          selectedSessionId: null,
          onOpenSession: _openSession,
          onNewSession: _newSession,
          sessionActions: _sessionActions,
          onOpenBridgeSettings: () => bridgeOpens++,
          onOpenSettings: () => settingsOpens++,
          onOpenArchived: _noOp,
          onGoBack: _noOp,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getSize(panel).width, 260);
    await tester.tap(find.text("This computer"));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("desktop-bridge-popover")), findsOneWidget);
    expect(bridgeOpens, 0);
    await tester.tap(find.text("Bridge settings…"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("desktop-sidebar-settings")));
    expect((bridgeOpens, settingsOpens), (1, 1));
  });

  testWidgets("the sidebar is the only navigation pane at every desktop width", (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [560.0, 900.0, 1400.0]) {
      tester.view.physicalSize = Size(width, 700);
      await tester.pumpWidget(app(state: running));
      await tester.pumpAndSettle();
      // Too narrow a window hides the sidebar; otherwise the panel keeps a
      // margin at its start and the resize gap at its end.
      expect(
        tester.getSize(page).width,
        width < DesktopCockpitShell.autoCollapseBreakpoint ? width : width - besideOpenPanel(width: 260),
      );
      expect(find.byType(SessionSidebarShell), findsNothing);
    }
  });

  testWidgets("the sidebar floats as an inset panel whose gap is the resize handle", (tester) async {
    await tester.pumpWidget(app(state: running));
    final rect = tester.getRect(panel);
    expect(rect, const Rect.fromLTRB(margin, margin, margin + 260, 600 - margin));
    expect(tester.getRect(resize), Rect.fromLTRB(rect.right, 0, rect.right + margin, 600));
    expect(pageStart(tester), rect.right + margin);
    expect(find.byType(VerticalDivider), findsNothing);
    // A row's ink highlight is clipped with the list, not painted over the section above it.
    final listMaterial = find.ancestor(of: list, matching: find.byType(Material));
    expect(tester.widget<Material>(listMaterial.first).clipBehavior, Clip.hardEdge);

    // Hidden, the panel and its gap give the page the whole window.
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    expect(resize, findsNothing);
    expect(pageStart(tester), 0);
  });

  testWidgets(
    "on macOS the panel carries the traffic lights, its top drags and zooms, and the restore button clears them",
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      await tester.pumpWidget(app(state: running));
      expect(tester.getRect(panel), const Rect.fromLTRB(margin, margin, margin + 260, 600 - margin));
      // The first control starts below the lights, which end 33 pt from the window's top.
      expect(tester.getTopLeft(find.byKey(const Key("desktop-sidebar-new-session"))).dy, 42);

      Future<void> drag({required Offset from}) async {
        final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
        await gesture.moveBy(const Offset(40, 0));
        await gesture.up();
        await tester.pump();
      }

      Future<void> doubleClick({required Offset at}) async {
        await tester.tapAt(at, kind: PointerDeviceKind.mouse);
        await tester.pump(kDoubleTapMinTime);
        await tester.tapAt(at, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
      }

      // The room the panel leaves for the lights stands in for the title bar.
      await drag(from: const Offset(140, 26));
      verify(windowHost.startDragging).called(1);
      await doubleClick(at: const Offset(140, 26));
      verify(windowHost.toggleZoom).called(1);

      // Hidden, the sidebar leaves the lights over the page; the restore
      // button starts past them.
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(restore).dx, 80);

      // The window's top band belongs to the app root, not to the shell.
      await drag(from: const Offset(500, 20));
      verifyNever(windowHost.startDragging);
    },
  );

  testWidgets("retry uses the failure-aware reconnect path", (tester) async {
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.failed(reason: RemoteFailureReason.networkDown),
    );
    when(projects.retryLoadProjects).thenAnswer((_) async {});
    await tester.pumpWidget(app(state: running));
    // Refresh stays beside the filter, idle until projects load.
    expect(tester.widget<IconButton>(find.byKey(const Key("desktop-sidebar-refresh"))).onPressed, isNull);
    await tester.tap(find.text("Retry"));
    verify(projects.retryLoadProjects).called(1);
  });

  testWidgets("sessions that fail to load say so in the list and retry", (tester) async {
    windowFailure = RemoteFailureReason.networkDown;
    await tester.pumpWidget(app(state: running));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: list, matching: find.text("Retry")));
    verify(window.reload).called(1);
  });

  for (final succeeded in [true, false]) {
    testWidgets("keyboard refresh stays busy until it ${succeeded ? "succeeds" : "fails"} and retains useful rows", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        loadedSessions = [testSession(id: "s1", title: "Fix the build")];
        final reply = Completer<bool>();
        when(refreshService.refresh).thenAnswer((_) => reply.future);
        await tester.pumpWidget(app(state: running));
        await tester.pumpAndSettle();
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
        expect(find.descendant(of: list, matching: find.text("Fix the build")), findsOneWidget);
        expect(tester.widget<IconButton>(find.byKey(const Key("desktop-sidebar-settings"))).onPressed, isNotNull);
        verify(refreshService.refresh).called(1);
        reply.complete(succeeded);
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(refresh).onPressed, isNotNull);
        expect(find.descendant(of: list, matching: find.text("Fix the build")), findsOneWidget);
        expect(
          find.text(
            succeeded ? "Projects and sessions updated" : "Could not refresh projects and sessions",
          ),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets("refresh is unavailable during initial load, disconnection and existing project refresh", (tester) async {
    final semantics = tester.ensureSemantics();
    for (final state in <ProjectListState>[
      const ProjectListState.loading(),
      const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true),
      const ProjectListState.loaded(projects: [], folderProjects: [], scratchProject: null, isRefreshing: true),
    ]) {
      whenListen(projects, const Stream<ProjectListState>.empty(), initialState: state);
      await tester.pumpWidget(app(state: running));
      await tester.pump();
      expect(tester.widget<IconButton>(find.byKey(const Key("desktop-sidebar-refresh"))).onPressed, isNull);
      // New session cannot start before projects load, and says so.
      if (state is! ProjectListLoaded) {
        expect(
          tester.getSemantics(
            find.descendant(of: find.byKey(const Key("desktop-sidebar-new-session")), matching: find.byType(InkWell)),
          ),
          isSemantics(isButton: true, isEnabled: false),
        );
      }
    }
    semantics.dispose();
    verifyNever(refreshService.refresh);
  });

  testWidgets("drag resizes immediately, persists on end, and double-click resets", (tester) async {
    await tester.pumpWidget(app(state: running));
    final gesture = await tester.startGesture(tester.getCenter(resize));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(tester.getSize(panel).width, 350);
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    await gesture.up();
    await tester.pump();
    verify(() => repository.writeSidebarLayout(layout: any(named: "layout"))).called(1);
    await tester.tap(resize);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(resize);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(panel).width, 260);
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
        expect(tester.getSize(panel).width, widths[index]);
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

  testWidgets("collapse slides the sidebar out as the page widens, and restore brings back its saved width", (
    tester,
  ) async {
    await tester.pumpWidget(app(state: running));
    sidebar.resize(width: 310);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(pageStart(tester), inExclusiveRange(0, besideOpenPanel(width: 310)));
    // The panel slides whole; its rows never squeeze.
    expect(tester.getSize(panel).width, 310);
    await tester.pump(const Duration(milliseconds: 220));
    expect(pageStart(tester), 0);
    expect(panel, findsNothing);
    expect(resize, findsNothing);
    await tester.tap(restore);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(pageStart(tester), inExclusiveRange(0, besideOpenPanel(width: 310)));
    await tester.pump(const Duration(milliseconds: 220));
    expect(pageStart(tester), besideOpenPanel(width: 310));
    expect(tester.getSize(panel).width, 310);
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
      await tester.tap(toggle);
      await tester.pump();
      expect(pageStart(tester), 0);
      await tester.tap(restore);
      await tester.pump();
      expect(pageStart(tester), besideOpenPanel(width: 260));
    });
  }

  testWidgets("narrow-window collapse is temporary and never persisted", (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(759, 600);
    await tester.pumpWidget(app(state: running));
    expect(pageStart(tester), 0);
    expect(sidebar.state.collapsed, isFalse);
    tester.view.physicalSize = const Size(760, 600);
    await tester.pumpAndSettle();
    expect(pageStart(tester), besideOpenPanel(width: 260));
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    unawaited(sidebar.toggleCollapsed());
    tester.view.physicalSize = const Size(1200, 700);
    await tester.pumpAndSettle();
    expect(pageStart(tester), 0);
  });

  testWidgets("new session is a quiet row, the filter heads the list beside Refresh, the footer is one row", (
    tester,
  ) async {
    await tester.pumpWidget(app(state: running));
    expect(find.text("Sesori"), findsNothing);
    final newSession = find.byKey(const Key("desktop-sidebar-new-session"));
    expect(find.descendant(of: newSession, matching: find.text("New session")), findsOneWidget);
    expect(find.text("New project"), findsNothing);
    expect(
      find.descendant(
        of: newSession,
        matching: find.text(defaultTargetPlatform == TargetPlatform.macOS ? "⌘N" : "Ctrl+N"),
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: panel, matching: find.byType(FilledButton)), findsNothing);
    expect(
      tester.getTopLeft(filterTrigger).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byKey(const Key("desktop-sidebar-search"))).dy),
    );
    expect(
      tester.getCenter(find.byKey(const Key("desktop-sidebar-refresh"))).dy,
      tester.getCenter(filterTrigger).dy,
    );
    final footer = find.byKey(const Key("desktop-sidebar-footer"));
    expect(
      tester.widget<Container>(footer).decoration,
      isA<BoxDecoration>().having((decoration) => decoration.border, "border", isNotNull),
    );
    // One 44-point row under a 1-point rule: This computer, then Settings and collapse.
    expect(tester.getSize(footer).height, 45);
    final bridgeRow = tester.getCenter(find.text("This computer")).dy;
    for (final key in ["desktop-sidebar-settings", "desktop-sidebar-toggle"]) {
      expect(tester.getCenter(find.byKey(Key(key))).dy, bridgeRow);
    }
  });

  group("new session", () {
    const recentProject = ProjectSummary(id: "project-recent", name: "Most recent", path: "/work/recent", time: null);
    const openProject = ProjectSummary(id: "project-open", name: null, path: "/work/open-one", time: null);
    late List<(String, String)> started;

    Widget shell({required String? selectedProjectId, required List<ProjectSummary> available}) {
      whenListen(
        projects,
        const Stream<ProjectListState>.empty(),
        initialState: ProjectListState.loaded(projects: available, folderProjects: available, scratchProject: null),
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
          onOpenBridgeSettings: _noOp,
          onOpenSettings: _noOp,
          onOpenArchived: _noOp,
          onGoBack: _noOp,
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

    testWidgets("without an open project the sidebar's filter picks it", (tester) async {
      filter.add("project-open");
      await tester.pumpWidget(shell(selectedProjectId: null, available: const [recentProject, openProject]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("desktop-sidebar-new-session")));
      expect(started, [("project-open", "open-one")]);
    });

    testWidgets("without an open project or a filter the most recently active one is used", (tester) async {
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

    testWidgets("without any project it offers to add one, then starts a session there", (tester) async {
      final connection = _MockConnectionService();
      const status = ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
        health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
      );
      when(() => connection.status).thenAnswer((_) => BehaviorSubject<ConnectionStatus>.seeded(status));
      when(() => connection.currentStatus).thenReturn(status);
      when(() => projects.fetchFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer(
        (_) async => const FilesystemSuggestionsSuccess(
          suggestions: FilesystemSuggestions(data: [], path: "/home"),
        ),
      );
      // The session scope provides it above the shell.
      await tester.pumpWidget(
        RepositoryProvider<ConnectionService>.value(
          value: connection,
          child: shell(selectedProjectId: null, available: const []),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Add project"), findsOneWidget);
      await tester.tap(find.byKey(const Key("desktop-sidebar-new-session")));
      await tester.pumpAndSettle();
      expect(started, isEmpty);
      final dialog = find.byType(AddProjectDialog);
      expect(dialog, findsOneWidget);
      tester
          .widget<AddProjectDialog>(dialog)
          .onProjectAdded(context: tester.element(dialog), project: openProject, displayName: "open-one");
      expect(started, [("project-open", "open-one")]);
    });
  });

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

  testWidgets("this computer's starting bridge is no disconnection, until the start fails", (tester) async {
    final root = app(state: _state(processState: const BridgeProcessStarting()));
    final updates = StreamController<ConnectionOverlayState>();
    addTearDown(updates.close);
    whenListen(overlay, updates.stream, initialState: const ConnectionOverlayState.bridgeOffline());
    final starts = BehaviorSubject<LocalBridgeStartupState>.seeded(LocalBridgeStartupState.starting);
    addTearDown(starts.close);
    whenListen(startup, starts, initialState: starts.value);
    await tester.pumpWidget(root);
    expect(find.byKey(const Key("desktop-connection-pill")), findsNothing);

    updates.add(const ConnectionOverlayState.connectionLost());
    await tester.pumpAndSettle();
    expect(find.text("Reconnect"), findsOneWidget);

    updates.add(const ConnectionOverlayState.bridgeOffline());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("desktop-connection-pill")), findsNothing);
    starts.add(LocalBridgeStartupState.settled);
    await tester.pumpAndSettle();
    expect(find.text("Bridge disconnected"), findsOneWidget);
  });

  testWidgets("the sidebar list loads while this computer's bridge starts, and empties once it fails", (tester) async {
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true),
    );
    final starts = BehaviorSubject<LocalBridgeStartupState>.seeded(LocalBridgeStartupState.starting);
    addTearDown(starts.close);
    whenListen(startup, starts, initialState: starts.value);
    await tester.pumpWidget(app(state: _state(processState: const BridgeProcessStarting())));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SessionListSkeleton), findsOneWidget);
    expect(find.byType(SessionEmptyState), findsNothing);

    // A failed or stopped start leaves the footer's recovery card to say so.
    starts.add(LocalBridgeStartupState.settled);
    await tester.pump();
    await tester.pump();
    expect(find.byType(SessionListSkeleton), findsNothing);
    expect(find.byType(SessionEmptyState), findsNothing);
  });

  for (final throughProjectLoad in [true, false]) {
    testWidgets(
      "from launch to its rows the sidebar list shows one skeleton, which hands off to them"
      "${throughProjectLoad ? ", through the project load" : ""}",
      (tester) async {
        loadedSessions = [testSession(id: "s1", title: "Fix the build")];
        final projectUpdates = StreamController<ProjectListState>();
        addTearDown(projectUpdates.close);
        whenListen(projects, projectUpdates.stream, initialState: const ProjectListState.loading());
        final starts = BehaviorSubject<LocalBridgeStartupState>.seeded(LocalBridgeStartupState.starting);
        addTearDown(starts.close);
        whenListen(startup, starts, initialState: starts.value);
        await tester.pumpWidget(app(state: _state(processState: const BridgeProcessStarting())));
        final skeleton = find.descendant(of: list, matching: find.byType(SessionListSkeleton));
        final first = tester.element(skeleton);

        // A cold start finds this computer's bridge offline while it starts.
        projectUpdates.add(const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true));
        await tester.pump();
        expect(tester.element(skeleton), same(first));
        // Its 300 ms appearance delay, then its 200 ms fade in, timed from the
        // frame after the delay.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.element(skeleton), same(first));

        // Reaching it ends the start.
        starts.add(LocalBridgeStartupState.settled);
        if (throughProjectLoad) {
          projectUpdates.add(const ProjectListState.loading());
          await tester.pump(Duration.zero);
          expect(tester.element(skeleton), same(first));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.element(skeleton), same(first));
        }
        projectUpdates.add(
          const ProjectListState.loaded(projects: [_sesori], folderProjects: [_sesori], scratchProject: null),
        );
        // The list resolves on a zero timer after the projects arrive.
        await tester.pump(Duration.zero);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final row = find.descendant(of: list, matching: find.text("Fix the build"));
        expect(tester.element(skeleton), same(first));
        // Fading itself out.
        expect(
          tester
              .widget<FadeTransition>(find.descendant(of: skeleton, matching: find.byType(FadeTransition)))
              .opacity
              .value,
          inExclusiveRange(0, 1),
        );
        expect(
          tester
              .widget<SliverFadeTransition>(find.ancestor(of: row, matching: find.byType(SliverFadeTransition)))
              .opacity
              .value,
          inExclusiveRange(0, 1),
        );

        await tester.pump(const Duration(milliseconds: 150));
        expect(skeleton, findsNothing);
        expect(row, findsOneWidget);
      },
    );
  }

  // A scan already running when the sidebar opens is no news: the row stands
  // with the loading skeleton, so the projects arriving move nothing.
  testWidgets("a load that starts mid-scan shows the scan row from its first frame and keeps the list still", (
    tester,
  ) async {
    loadedSessions = [testSession(id: "s1", title: "Fix the build")];
    when(() => refreshService.scan).thenAnswer(
      (_) => BehaviorSubject.seeded(
        const CatalogRescanState.reading(
          activePluginName: "Codex",
          sessionsSeen: 12,
          finishedHarnessCount: 0,
          pluginIds: {"codex"},
        ),
      ),
    );
    final projectUpdates = StreamController<ProjectListState>();
    addTearDown(projectUpdates.close);
    whenListen(projects, projectUpdates.stream, initialState: const ProjectListState.loading());

    await tester.pumpWidget(app(state: running));
    expect(find.descendant(of: list, matching: find.byKey(const ValueKey("prego-deep-scan-card"))), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    final search = find.descendant(of: list, matching: find.byType(EditableText));
    final searchTop = tester.getTopLeft(search).dy;

    projectUpdates.add(
      const ProjectListState.loaded(projects: [_sesori], folderProjects: [_sesori], scratchProject: null),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.descendant(of: list, matching: find.text("Fix the build")), findsOneWidget);
    expect(tester.getTopLeft(search).dy, searchTop);
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

  testWidgets("recovery stays in the sidebar and respects command locks", (tester) async {
    when(bridgeControlCubit.takeOver).thenAnswer((_) async {});
    final base = _state(processState: const BridgeProcessContention());
    final widget = app(state: base);
    final updates = StreamController<BridgeControlState>();
    addTearDown(updates.close);
    whenListen(bridgeControlCubit, updates.stream, initialState: base);
    await tester.pumpWidget(widget);
    final card = find.byKey(const Key("desktop-bridge-recovery"));
    expect(tester.getRect(card).right, lessThanOrEqualTo(tester.getRect(panel).right));
    expect(tester.getRect(page).top, 0);
    final takeOver = find.widgetWithText(PregoButtonsSolid, "Take over");
    await tester.tap(takeOver);
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
      updateState: base.updateState,
    );
    updates.add(locked);
    await tester.pump();
    expect(tester.widget<PregoButtonsSolid>(takeOver).onPressed, isNull);
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
    expect(find.text("Open logs"), findsNothing);
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
    await tester.tap(find.text("Open logs"));
    verify(bridgeControlCubit.recoverConnection).called(1);
    verify(bridgeControlCubit.openLogs).called(1);
  });

  testWidgets("offers takeover from the integrated supervision surface", (tester) async {
    when(bridgeControlCubit.takeOver).thenAnswer((_) async {});
    await tester.pumpWidget(app(state: _state(processState: const BridgeProcessContention())));
    await tester.tap(find.text("Take over"));
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
    expect(find.text("Take over"), findsOneWidget);
    expect(find.text("Start bridge"), findsNothing);
    await tester.tap(find.text("Take over"));
    verify(bridgeControlCubit.takeOver).called(1);
  });

  testWidgets("offers authenticated bridge retry without CLI-install copy", (tester) async {
    when(bridgeControlCubit.recoverConnection).thenAnswer((_) async {});
    await tester.pumpWidget(app(state: _state(processState: const BridgeProcessLoginRequired())));
    expect(find.textContaining("account is required"), findsOneWidget);
    expect(find.textContaining("install"), findsNothing);
    await tester.tap(find.text("Start bridge"));
    verify(bridgeControlCubit.recoverConnection).called(1);
  });

  testWidgets("the command palette filters, picks by keyboard, closes on Esc and runs commands", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final build = testSession(id: "s1", title: "Fix the build", updatedAt: 2);
    final docs = testSession(id: "s2", title: "Write docs", updatedAt: 1);
    final untitled = testSession(id: "s3", title: null, updatedAt: 0);
    final auth = StreamController<AuthGateState>();
    addTearDown(auth.close);
    whenListen(authGate, auth.stream, initialState: const AuthGateState.signedIn(user: null));
    loadedSessions = [build, docs, untitled];
    bridgeSessions = loadedSessions;
    final opened = <String>[];
    var backs = 0;
    var archivedOpens = 0;
    await tester.pumpWidget(
      PregoInteractionScope(
        mode: PregoInteractionMode.pointer,
        child: app(
          state: running,
          child: DesktopCockpitShell(
            selectedProjectId: null,
            selectedSessionId: null,
            onOpenSession: ({required context, required project, required displayName, required session}) =>
                opened.add(session.id),
            onNewSession: _newSession,
            sessionActions: _sessionActions,
            onOpenBridgeSettings: _noOp,
            onOpenSettings: _noOp,
            onOpenArchived: () => archivedOpens++,
            onGoBack: () => backs++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final macOS = defaultTargetPlatform == TargetPlatform.macOS;
    final modifier = macOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;
    final palette = find.byKey(const Key("desktop-command-palette"));
    Finder inPalette(String text) => find.descendant(of: palette, matching: find.textContaining(text));
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
    }

    Future<void> type(String query) async {
      await tester.enterText(find.descendant(of: palette, matching: find.byType(TextField)), query);
      await tester.pumpAndSettle();
    }

    await press(LogicalKeyboardKey.keyK);
    expect(palette, findsOneWidget);
    expect(inPalette("New session"), findsOneWidget);
    expect(find.descendant(of: palette, matching: find.text(macOS ? "⌘N" : "Ctrl+N")), findsOneWidget);
    // Sessions follow recency and name their project.
    expect(
      tester.getTopLeft(inPalette("Fix the build")).dy,
      lessThan(tester.getTopLeft(inPalette("Write docs")).dy),
    );
    expect(find.descendant(of: palette, matching: find.text("Fix the build   Sesori Desktop")), findsOneWidget);

    await type("BUILD");
    expect(inPalette("Fix the build"), findsOneWidget);
    expect(inPalette("Write docs"), findsNothing);
    expect(inPalette("New session"), findsNothing);
    await type("nothing like it");
    // Not before the bridge has answered too.
    expect(find.descendant(of: palette, matching: find.text("No matches")), findsNothing);
    await tester.pump(SessionSearchCubit.searchDelay);
    await tester.pumpAndSettle();
    expect(find.descendant(of: palette, matching: find.text("No matches")), findsOneWidget);

    // Enter picks the first match: the session opens and the palette closes.
    await type("docs");
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened, ["s2"]);
    expect(palette, findsNothing);

    // The sidebar row opens it too; Down moves from New session to Toggle sidebar.
    await tester.tap(find.byKey(const Key("desktop-sidebar-search")));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(sidebar.state.collapsed, isTrue);
    expect(palette, findsNothing);

    await press(LogicalKeyboardKey.keyK);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(palette, findsNothing);

    // A command runs from the palette, and its shortcut still works.
    await press(LogicalKeyboardKey.keyK);
    await type("go back");
    expect(inPalette("Go back"), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(backs, 1);
    await press(LogicalKeyboardKey.bracketLeft);
    expect(backs, 2);

    // Archived, which has no shortcut, runs from the palette too.
    await press(LogicalKeyboardKey.keyK);
    await type("archived");
    expect(inPalette("Archived sessions"), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(archivedOpens, 1);

    // A project filters the sidebar's list, and a hidden sidebar opens to show it.
    await press(LogicalKeyboardKey.keyK);
    await type("sesori");
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(sessions.state.projectId, "project-1");
    expect(filter.value, "project-1");
    expect(sidebar.state.collapsed, isFalse);
    expect(find.descendant(of: filterTrigger, matching: find.text("Sesori Desktop")), findsOneWidget);

    // Signing out takes the palette with the cockpit.
    await press(LogicalKeyboardKey.keyK);
    auth.add(const AuthGateState.signedOut());
    await tester.pumpAndSettle();
    expect(palette, findsNothing);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets("the command palette shows loaded matches at once and adds the bridge's below them", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    seedTwoProjects();
    final build = testSession(id: "s1", title: "Fix the build", updatedAt: 2);
    final docs = testSession(id: "s2", title: "Write docs", updatedAt: 1).copyWith(projectID: "project-2");
    loadedSessions = [build];
    bridgeSessions = [build, docs];
    await tester.pumpWidget(
      PregoInteractionScope(
        mode: PregoInteractionMode.pointer,
        child: app(state: running),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("desktop-sidebar-search")));
    await tester.pumpAndSettle();
    final palette = find.byKey(const Key("desktop-command-palette"));
    Finder inPalette(String text) => find.descendant(of: palette, matching: find.textContaining(text));
    await tester.enterText(find.descendant(of: palette, matching: find.byType(TextField)), "i");
    await tester.pump();
    expect(inPalette("Fix the build"), findsOneWidget);
    expect(inPalette("Write docs"), findsNothing);
    final buildTop = tester.getTopLeft(inPalette("Fix the build")).dy;

    await tester.pump(SessionSearchCubit.searchDelay);
    await tester.pumpAndSettle();
    expect(find.descendant(of: palette, matching: find.text("Write docs   Landing page")), findsOneWidget);
    expect(tester.getTopLeft(inPalette("Fix the build")).dy, buildTop);
    expect(tester.getTopLeft(inPalette("Write docs")).dy, greaterThan(buildTop));
  }, variant: TargetPlatformVariant.desktop());
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
  updateState: const DesktopUpdateManagedBySystem(),
);

const _sesori = ProjectSummary(id: "project-1", name: "Sesori Desktop", path: "/work/sesori", time: null);
const _landing = ProjectSummary(id: "project-2", name: "Landing page", path: "/work/landing", time: null);

const _sessionActions = SessionListActionDispatcher(
  deleteConfirmation: SessionDeleteConfirmation.sheet,
  onSessionArchived: null,
  onSessionDeleted: _deleted,
  onSessionMarkedUnread: null,
);
void _deleted({required BuildContext context, required String sessionId}) {}
void _openSession({
  required BuildContext context,
  required ProjectSummary project,
  required String displayName,
  required Session session,
}) {}
class _MockAuthGateCubit() extends MockCubit<AuthGateState> implements AuthGateCubit;

void _noOp() {}
void _newSession({required BuildContext context, required ProjectSummary project, required String displayName}) {}

class _MockRefreshService() extends Mock implements SessionListRefreshService;

class _MockWindowHost() extends Mock implements WindowHost;

class _MockConnectionService() extends Mock implements ConnectionService;

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
class _MockConnectionOverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit;
class _MockLocalBridgeStartupCubit() extends MockCubit<LocalBridgeStartupState> implements LocalBridgeStartupCubit;
class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

class _MockProjectInventoryService() extends Mock implements ProjectInventoryService;

class _MockSessionWindowService() extends Mock implements SessionWindowService;

class _MockFilterTracker() extends Mock implements SessionListFilterTracker;

class _MockRepository() extends Mock implements DesktopInstanceRepository;
