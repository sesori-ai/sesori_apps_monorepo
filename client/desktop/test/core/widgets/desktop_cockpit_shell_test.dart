import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/semantics.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
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
    when(() => recent.ensureLoaded(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(
        projects: [ProjectSummary(id: "project-1", name: "Sesori Desktop", path: "/work/sesori", time: null)],
        activityById: {},
      ),
    );
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
        BlocProvider<ProjectListCubit>.value(value: projects),
        BlocProvider<RecentSessionsCubit>.value(value: recent),
        BlocProvider<DesktopSidebarCubit>(create: (_) => sidebar = DesktopSidebarCubit(repository: repository)),
      ],
      child: MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home:
            child ??
            DesktopCockpitShell(
              destination: DesktopCockpitDestination.projects,
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
    );
  }

  final running = _state(processState: const BridgeProcessRunning(pid: 42));
  final rail = find.byKey(const Key("desktop-cockpit-sidebar"));
  final resize = find.byKey(const Key("desktop-sidebar-resize"));
  final toggle = find.byKey(const Key("desktop-sidebar-toggle"));

  testWidgets("section selection and screen-reader activation match the destination", (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var opens = 0;
      for (final destination in DesktopCockpitDestination.values) {
        await tester.pumpWidget(
          app(
            state: running,
            child: DesktopCockpitShell(
              destination: destination,
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
        for (final entry in {
          DesktopCockpitDestination.projects: "Projects",
          DesktopCockpitDestination.settings: "Settings",
        }.entries) {
          final finder = find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == entry.value,
          );
          expect(tester.widget<Semantics>(finder).properties.selected, entry.key == destination);
          if (entry.key == destination) {
            final node = tester.getSemantics(finder);
            tester.platformDispatcher.onSemanticsActionEvent!(
              SemanticsActionEvent(type: SemanticsAction.tap, nodeId: node.id, viewId: tester.view.viewId),
            );
          }
        }
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
          (widget) => widget is Semantics && widget.properties.label == "Bridge, Bridge status",
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
    await tester.tap(find.byTooltip("Retry"));
    verify(projects.retryLoadProjects).called(1);
    verifyNever(projects.refreshProjects);
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

  testWidgets("renders shared projects and dispatches existing route actions", (tester) async {
    var bridgeOpens = 0;
    var projectOpens = 0;
    var settingsOpens = 0;
    String? openedProject;
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          destination: DesktopCockpitDestination.projects,
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
    await tester.tap(find.text("Bridge"));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("desktop-bridge-popover")), findsOneWidget);
    expect(bridgeOpens, 0);
    await tester.tap(find.text("Bridge settings…"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Projects"));
    await tester.tap(find.text("Settings"));
    await tester.tap(find.text("Sesori Desktop"));
    expect((bridgeOpens, projectOpens, settingsOpens, openedProject), (1, 1, 1, "project-1"));
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
    var allSessions = 0;
    var newSessions = 0;
    await tester.pumpWidget(
      app(
        state: running,
        child: DesktopCockpitShell(
          destination: DesktopCockpitDestination.projects,
          selectedProjectId: "project-1",
          selectedSessionId: "session-4",
          sessionActions: _sessionActions,
          onOpenSession: ({required context, required project, required displayName, required session}) =>
              openedSession = session.id,
          onNewSession: ({required context, required project, required displayName}) => newSessions++,
          onOpenProject: ({required context, required project, required displayName}) => allSessions++,
          onOpenBridgeSettings: _noOp,
          onOpenProjects: _noOp,
          onOpenSettings: _noOp,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    for (final session in sessions) {
      expect(find.text(session.title!), findsOneWidget);
    }
    final selected = find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == "session-4");
    expect(tester.widget<Semantics>(selected).properties.selected, isTrue);
    await tester.tap(find.text("session-4"));
    expect(openedSession, "session-4");
    final allSessionsLabel = tester.widget<Text>(find.text("All sessions · 4"));
    expect(allSessionsLabel.maxLines, 1);
    expect(allSessionsLabel.style!.fontFamily, startsWith("packages/theme_prego/"));
    await tester.tap(find.text("All sessions · 4"));
    expect(allSessions, 1);
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

  testWidgets("drag resizes immediately, persists on end, and double-click resets", (tester) async {
    await tester.pumpWidget(app(state: running));
    final gesture = await tester.startGesture(tester.getCenter(resize));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(tester.getSize(rail).width, greaterThan(260));
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    await gesture.up();
    await tester.pump();
    verify(() => repository.writeSidebarLayout(layout: any(named: "layout"))).called(1);
    await tester.tap(resize);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(resize);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(rail).width, 260);
  });

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
              destination: DesktopCockpitDestination.settings,
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

  testWidgets("new project is labeled and the pinned footer has its own surface", (tester) async {
    await tester.pumpWidget(app(state: running));
    expect(find.text("Sesori"), findsNothing);
    expect(find.text("Projects"), findsOneWidget);
    expect(find.text("New project"), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key("desktop-sidebar-new-project"))).onPressed, isNotNull);
    final footer = tester.widget<Container>(find.byKey(const Key("desktop-sidebar-footer")));
    expect((footer.decoration! as BoxDecoration).border, isNotNull);
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

const _sessionActions = SessionListActionDispatcher(onSessionDeleted: _deleted);
void _deleted({required BuildContext context, required String sessionId}) {}
void _openSession({
  required BuildContext context,
  required ProjectSummary project,
  required String displayName,
  required Session session,
}) {}
void _noOp() {}
void _openProject({required BuildContext context, required ProjectSummary project, required String displayName}) {}

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;
class _MockConnectionOverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit;
class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;
class _MockRecentSessionsCubit() extends MockCubit<Map<String, RecentSessionsEntry>> implements RecentSessionsCubit;
class _MockRepository() extends Mock implements DesktopInstanceRepository;
