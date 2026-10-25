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
import "package:sesori_dart_core/src/repositories/view_declaration_repository.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/widgets/desktop_cockpit_shell.dart";
import "package:sesori_desktop/core/widgets/desktop_connection_pill.dart";
import "package:sesori_desktop/core/widgets/desktop_page_toolbar.dart";
import "package:sesori_desktop/core/widgets/desktop_sidebar.dart";
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
  late Map<String, RecentSessionsEntry> recent;
  late _MockRecentSessionInventoryService recentInventory;
  late _MockProjectInventoryService projectInventory;
  late BehaviorSubject<String?> filter;
  late _MockFilterTracker filterTracker;
  late ProjectViewingService viewing;
  late _MockRepository repository;
  late DesktopSidebarCubit sidebar;
  late AllSessionsCubit sessions;
  late _MockRefreshService refreshService;
  late _MockWindowHost windowHost;
  late _MockAuthGateCubit authGate;
  late SessionLaunchRepository launches;

  setUpAll(() {
    registerFallbackValue(const DesktopSidebarLayout());
    registerFallbackValue(ProjectViewClaim());
    registerFallbackValue(ProjectViewPaneClaim());
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
    overlay = _MockConnectionOverlayCubit();
    contentTaps = 0;
    whenListen(
      overlay,
      const Stream<ConnectionOverlayState>.empty(),
      initialState: const ConnectionOverlayState.hidden(connected: true),
    );
    projects = _MockProjectListCubit();
    // Loaded and empty: a loading list shimmers for as long as it waits.
    recent = {"project-1": _loaded(sessions: const [])};
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(
        projects: [ProjectSummary(id: "project-1", name: "Sesori Desktop", path: "/work/sesori", time: null)],
      ),
    );
    // The inventories behind the mocked cubits, as the shared list reads them.
    recentInventory = _MockRecentSessionInventoryService();
    when(
      () => recentInventory.state,
    ).thenAnswer((_) => const Stream<Map<String, RecentSessionsEntry>>.empty().shareValueSeeded(recent));
    when(() => recentInventory.retry(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    projectInventory = _MockProjectInventoryService();
    when(() => projectInventory.state).thenAnswer((_) => projects.state);
    when(() => projectInventory.stateStream).thenAnswer((_) => projects.stream.shareValueSeeded(projects.state));
    filter = BehaviorSubject.seeded(null);
    filterTracker = _MockFilterTracker();
    when(() => filterTracker.projectId).thenAnswer((_) => filter.stream);
    when(() => filterTracker.select(projectId: any(named: "projectId"))).thenAnswer(
      (invocation) => filter.add(invocation.namedArguments[#projectId] as String?),
    );
    viewing = stubbedProjectViewingService();
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
            RepositoryProvider<RecentSessionInventoryService>.value(value: recentInventory),
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
                mode: AllSessionsMode.active,
                recentInventory: recentInventory,
                projectInventory: projectInventory,
                filterTracker: filterTracker,
                sessionListService: SessionListService(
                  repository: MockProjectRepository(),
                  activityCalculator: const SessionActivityCalculator(),
                ),
                projectViewingService: viewing,
              ),
            ),
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
                onOpenArchived: _noOp,
                onOpenSettings: _noOp,
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
        projects: [
          ProjectSummary(id: "project-1", name: "Sesori Desktop", path: "/work/sesori", time: null),
          ProjectSummary(id: "project-2", name: "Landing page", path: "/work/landing", time: null),
        ],
      ),
    );
    recent = {
      "project-1": _loaded(
        sessions: [testSession(id: "s1", title: "Fix the build", updatedAt: 2)],
      ),
      "project-2": _loaded(
        sessions: [testSession(id: "s2", title: "Write docs", updatedAt: 1)],
      ),
    };
  }

  final running = _state(processState: const BridgeProcessRunning(pid: 42));
  final panel = find.byKey(const Key("desktop-cockpit-sidebar"));
  final resize = find.byKey(const Key("desktop-sidebar-resize"));
  final toggle = find.byKey(const Key("desktop-sidebar-toggle"));
  final restore = find.byKey(const Key("desktop-sidebar-restore"));
  final page = find.byKey(const Key("cockpit-content"));
  final list = find.byKey(const Key("desktop-sidebar-session-list"));
  final filterTrigger = find.byKey(const Key("desktop-sidebar-filter"));
  const margin = DesktopSidebar.panelMargin;
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
          onNewSession: _openProject,
          sessionActions: _sessionActions,
          onOpenProject: _openProject,
          onOpenBridgeSettings: _noOp,
          onOpenArchived: _noOp,
          onOpenSettings: _noOp,
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
          onNewSession: _openProject,
          sessionActions: _sessionActions,
          onOpenProject: _openProject,
          onOpenBridgeSettings: _noOp,
          onOpenArchived: _noOp,
          onOpenSettings: _noOp,
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

  testWidgets("the shared list hears whether the sidebar shows it", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    void expectPane({required bool visible}) => verify(
      () => viewing.setWideListPaneVisible(
        claim: any(named: "claim"),
        isVisible: visible,
      ),
    ).called(1);
    await tester.pumpWidget(app(state: running));
    expectPane(visible: true);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expectPane(visible: false);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expectPane(visible: true);
    tester.view.physicalSize = const Size(700, 600);
    await tester.pumpAndSettle();
    expectPane(visible: false);
  });

  testWidgets("a filtered sidebar declares its project again once the project page closes", (tester) async {
    final declarations = _MockViewDeclarationRepository();
    when(() => declarations.sendProjectView(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    when(() => declarations.sendSessionView(sessionId: any(named: "sessionId"))).thenAnswer((_) async {});
    final connection = MockConnectionService();
    final status = ConnectionStatus.connected(
      config: const ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null),
      health: testHealthResponse(),
    );
    final statuses = BehaviorSubject<ConnectionStatus>.seeded(status);
    when(() => connection.status).thenAnswer((_) => statuses.stream);
    when(() => connection.currentStatus).thenReturn(status);
    final lifecycle = FakeLifecycleSource();
    final routes = MockRouteSource(initialRoute: AppRouteDef.home);
    final service = ProjectViewingService(
      viewRepository: declarations,
      lifecycleSource: lifecycle,
      connectionService: connection,
      routeSource: routes,
    );
    viewing = service;
    seedTwoProjects();
    filter.add("project-1");
    await tester.pumpWidget(app(state: running));
    await tester.pump();
    expect(service.declaredProjectId, "project-1");
    // Until step 11 the project page's own list replaces the sidebar's claim.
    final pageClaim = service.beginListClaim(projectId: "project-2");
    service.markClaimReady(claim: pageClaim, projectId: "project-2");
    routes.emitRoute(AppRouteDef.projectSessions);
    await tester.pump();
    expect(service.declaredProjectId, "project-2");
    service.releaseClaim(claim: pageClaim);
    routes.emitRoute(AppRouteDef.home);
    await tester.pump();
    expect(service.declaredProjectId, "project-1");
  });

  testWidgets("a hidden sidebar comes back from the page's corner, which the toolbar leaves free", (tester) async {
    await tester.pumpWidget(
      app(
        state: running,
        child: const DesktopCockpitShell(
          selectedProjectId: null,
          selectedSessionId: null,
          onOpenSession: _openSession,
          onNewSession: _openProject,
          sessionActions: _sessionActions,
          onOpenProject: _openProject,
          onOpenBridgeSettings: _noOp,
          onOpenArchived: _noOp,
          onOpenSettings: _noOp,
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

  testWidgets("the footer's Archived opens the archived page", (tester) async {
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
          onOpenBridgeSettings: _noOp,
          onOpenArchived: () => opens++,
          onOpenSettings: _noOp,
          onGoBack: _noOp,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final archived = find.byKey(const Key("desktop-sidebar-archived"));
    expect(find.descendant(of: find.byKey(const Key("desktop-sidebar-footer")), matching: archived), findsOneWidget);
    expect(find.byTooltip("Archived sessions"), findsOneWidget);
    await tester.tap(archived);
    expect(opens, 1);
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
          onNewSession: _openProject,
          sessionActions: _sessionActions,
          onOpenProject: _openProject,
          onOpenBridgeSettings: () => bridgeOpens++,
          onOpenArchived: _noOp,
          onOpenSettings: () => settingsOpens++,
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

  testWidgets("a project whose sessions fail to load says so in the list and retries it", (tester) async {
    recent = const {"project-1": RecentSessionsFailed(reason: RemoteFailureReason.networkDown)};
    await tester.pumpWidget(app(state: running));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: list, matching: find.text("Retry")));
    verify(() => recentInventory.retry(projectId: "project-1")).called(1);
  });

  for (final succeeded in [true, false]) {
    testWidgets("keyboard refresh stays busy until it ${succeeded ? "succeeds" : "fails"} and retains useful rows", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        recent = {
          "project-1": _loaded(
            sessions: [testSession(id: "s1", title: "Fix the build")],
          ),
        };
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
      const ProjectListState.loaded(projects: [], isRefreshing: true),
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
    // One 44-point row under a 1-point rule: This computer, then Archived, Settings and collapse.
    expect(tester.getSize(footer).height, 45);
    final bridgeRow = tester.getCenter(find.text("This computer")).dy;
    for (final key in ["desktop-sidebar-archived", "desktop-sidebar-settings", "desktop-sidebar-toggle"]) {
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
        initialState: ProjectListState.loaded(projects: available),
      );
      recent = {for (final project in available) project.id: _loaded(sessions: const [])};
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
          onOpenArchived: _noOp,
          onOpenSettings: _noOp,
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

    testWidgets("without any project it offers to add one", (tester) async {
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
      expect(find.byType(AddProjectDialog), findsOneWidget);
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
    recent = {
      "project-1": _loaded(sessions: [build, docs, untitled]),
    };
    final opened = <String>[];
    var backs = 0;
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
            onNewSession: _openProject,
            sessionActions: _sessionActions,
            onOpenProject: _openProject,
            onOpenBridgeSettings: _noOp,
            onOpenArchived: _noOp,
            onOpenSettings: _noOp,
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

    // A project filters the sidebar's list, and a hidden sidebar opens to show it.
    await press(LogicalKeyboardKey.keyK);
    await type("sesori");
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(sessions.state.projectId, "project-1");
    expect(filter.value, "project-1");
    expect(sidebar.state.collapsed, isFalse);
    expect(find.descendant(of: filterTrigger, matching: find.text("Sesori Desktop")), findsOneWidget);

    // An untitled session matches the title it shows.
    await press(LogicalKeyboardKey.keyK);
    await type("untitled");
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened.last, "s3");

    // Signing out takes the palette with the cockpit.
    await press(LogicalKeyboardKey.keyK);
    auth.add(const AuthGateState.signedOut());
    await tester.pumpAndSettle();
    expect(palette, findsNothing);
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
);

RecentSessionsLoaded _loaded({required List<Session> sessions}) => RecentSessionsLoaded(
  sourceSessions: sessions,
  visibleSessions: sessions,
  archivedSessions: const [],
  activityBySessionId: const {},
  listStateBySessionId: const {},
);

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
void _openProject({required BuildContext context, required ProjectSummary project, required String displayName}) {}

class _MockRefreshService() extends Mock implements SessionListRefreshService;

class _MockWindowHost() extends Mock implements WindowHost;

class _MockConnectionService() extends Mock implements ConnectionService;

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
class _MockConnectionOverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit;
class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;
class _MockRecentSessionInventoryService() extends Mock implements RecentSessionInventoryService;

class _MockProjectInventoryService() extends Mock implements ProjectInventoryService;

class _MockFilterTracker() extends Mock implements SessionListFilterTracker;

class _MockViewDeclarationRepository() extends Mock implements ViewDeclarationRepository;

class _MockRepository() extends Mock implements DesktopInstanceRepository;
