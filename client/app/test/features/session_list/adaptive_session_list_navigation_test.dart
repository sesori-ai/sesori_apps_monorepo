import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/home/home_sidebar_footer.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/routing/adaptive_session_router_test_harness.dart";
import "../../helpers/test_helpers.dart";

/// The reveal origin the + puts in the URL: its centre as fractions of the
/// 390 x 800 phone.
String _revealFrom({required WidgetTester tester}) {
  final centre = tester.getCenter(find.byKey(const Key("home-new-session")));
  return "${(centre.dx / 390).toStringAsFixed(4)},${(centre.dy / 800).toStringAsFixed(4)}";
}

Future<void> _pumpRouteFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(registerAllFallbackValues);

  final leftPane = find.byKey(const Key("session-sidebar"));

  Future<AdaptiveSessionRouterTestHarness> setUpHome({
    required WidgetTester tester,
    required Size size,
    required String initialLocation,
    required AppRouteDef currentRouteDef,
    required Map<String, List<Session>> sessionsByProject,
  }) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: initialLocation,
      currentRouteDef: currentRouteDef,
      sessionsByProject: sessionsByProject,
    );
    return harness;
  }

  final oneSession = {
    "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
  };

  testWidgets("the narrow home is the root, and a row opens its detail", (tester) async {
    final harness = await setUpHome(
      tester: tester,
      size: const Size(390, 800),
      initialLocation: "/sessions",
      currentRouteDef: AppRouteDef.home,
      sessionsByProject: oneSession,
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerRegular.chevron_left), findsNothing);
    expect(harness.router.canPop(), isFalse);

    await tester.tap(find.text("Session One"));
    await _pumpRouteFrames(tester);

    expect(Uri.parse(harness.currentLocation).path, "/sessions/p1/session-1");
    expect(find.byKey(const ValueKey("session-detail-session-1")), findsOneWidget);
    expect(leftPane, findsNothing);
  });

  testWidgets("the narrow home's floating + stays put while the list scrolls, and the last row clears it", (
    tester,
  ) async {
    // A phone's home indicator.
    final homeIndicator = FakeViewPadding(bottom: 34 * tester.view.devicePixelRatio);
    tester.view
      ..padding = homeIndicator
      ..viewPadding = homeIndicator;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final harness = await setUpHome(
      tester: tester,
      size: const Size(390, 800),
      initialLocation: "/sessions",
      currentRouteDef: AppRouteDef.home,
      sessionsByProject: {
        "p1": [
          for (var index = 0; index < 20; index++)
            adaptiveTestSession(projectId: "p1", id: "session-$index", title: "Session $index"),
        ],
      },
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    final plus = find.byKey(const Key("home-new-session"));
    final resting = tester.getRect(plus);
    // At the bottom right, above the home indicator.
    expect(resting.right, lessThan(390));
    expect(resting.bottom, lessThan(800 - 34));
    expect(resting.center.dx, greaterThan(390 / 2));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    expect(tester.getRect(plus), resting);

    // At the end of the list the last row rests above the +.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(tester.getRect(plus), resting);
    final lastRowBottom = [
      for (final row in find.byType(SessionTile).evaluate()) tester.getRect(find.byWidget(row.widget)).bottom,
    ].reduce(math.max);
    expect(lastRowBottom, lessThanOrEqualTo(resting.top));

    // It opens the new-session page, as the bar's button did.
    await tester.tap(plus);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, "/sessions/new");
  });

  testWidgets("a row opens its detail beside the wide home, selected", (tester) async {
    final harness = await setUpHome(
      tester: tester,
      size: const Size(1024, 800),
      initialLocation: "/sessions",
      currentRouteDef: AppRouteDef.home,
      sessionsByProject: oneSession,
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    expect(find.byType(NewSessionView), findsOneWidget);

    await tester.tap(find.text("Session One"));
    await tester.pumpAndSettle();

    final uri = Uri.parse(harness.currentLocation);
    expect(uri.path, "/sessions/p1/session-1");
    expect(uri.queryParameters["name"], "Project One");
    expect(uri.queryParameters["title"], "Session One");
    expect(uri.queryParameters["readOnly"], "false");
    expect(leftPane, findsOneWidget);
    expect(find.byKey(const Key("session-sidebar-content")), findsOneWidget);
    expect(find.byKey(const ValueKey("session-detail-session-1")), findsOneWidget);
    final tile = tester.widget<SessionTile>(find.widgetWithText(SessionTile, "Session One"));
    expect(tile.selected, isTrue);

    harness.router.pop();
    await tester.pumpAndSettle();

    expect(Uri.parse(harness.currentLocation).path, "/sessions");
    expect(find.byType(NewSessionView), findsOneWidget);
    expect(find.byKey(const ValueKey("session-detail-session-1")), findsNothing);
  });

  testWidgets("wide detail navigation crossfades inside the right pane", (tester) async {
    final harness = await setUpHome(
      tester: tester,
      size: const Size(1024, 800),
      initialLocation: "/sessions",
      currentRouteDef: AppRouteDef.home,
      sessionsByProject: oneSession,
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Session One"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    final detail = find.byKey(const ValueKey("session-detail-session-1"));
    expect(detail, findsOneWidget);
    expect(find.ancestor(of: detail, matching: find.byType(FadeTransition)), findsWidgets);

    await tester.pumpAndSettle();
    expect(Uri.parse(harness.currentLocation).path, "/sessions/p1/session-1");
  });

  testWidgets("a cold-start wide detail has the home underneath, with no Back of its own", (tester) async {
    final harness = await setUpHome(
      tester: tester,
      size: const Size(1024, 800),
      initialLocation: "/sessions/p1/session-1?title=Session+One&readOnly=false",
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: oneSession,
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("session-detail-session-1")), findsOneWidget);
    // The footer holds Settings and collapse; Archived opens from Settings.
    expect(
      find.descendant(of: find.byType(HomeSidebarFooter), matching: find.byType(PregoButtonsIconGlass)),
      findsNWidgets(2),
    );
    expect(find.descendant(of: leftPane, matching: find.byKey(const Key("home-settings"))), findsOneWidget);
    expect(harness.router.canPop(), isTrue);
    expect(find.descendant(of: leftPane, matching: find.byType(BackButton)), findsNothing);
  });

  void stubDelete(AdaptiveSessionRouterTestHarness harness) => when(
    () => harness.sessionRepository.deleteSession(
      sessionId: any(named: "sessionId"),
      deleteWorktree: any(named: "deleteWorktree"),
      deleteSessionFolder: any(named: "deleteSessionFolder"),
      force: any(named: "force"),
    ),
  ).thenAnswer((_) async => ApiResponse<void>.success(null));

  Future<void> deleteFromList({required WidgetTester tester, required String title}) async {
    await tester.longPress(find.descendant(of: leftPane, matching: find.text(title)));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Delete").hitTestable());
    await tester.pumpAndSettle();
    // Deleting always confirms, so the menu entry only raises the sheet.
    await tester.tap(find.widgetWithText(FilledButton, "Delete"));
    await tester.pumpAndSettle();
  }

  testWidgets("deleting the selected session returns the wide detail pane to the empty state", (tester) async {
    final harness = await setUpHome(
      tester: tester,
      size: const Size(1024, 800),
      initialLocation: "/sessions",
      currentRouteDef: AppRouteDef.home,
      sessionsByProject: oneSession,
    );
    stubDelete(harness);

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text("Session One"));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("session-detail-session-1")), findsOneWidget);

    await deleteFromList(tester: tester, title: "Session One");

    expect(Uri.parse(harness.currentLocation).path, "/sessions");
    expect(find.byType(NewSessionView), findsOneWidget);
    expect(find.byKey(const ValueKey("session-detail-session-1")), findsNothing);

    // Let the deletion alert expire so no timers outlive the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets("deleting an unselected session keeps the open wide detail pane", (tester) async {
    final harness = await setUpHome(
      tester: tester,
      size: const Size(1024, 800),
      initialLocation: "/sessions",
      currentRouteDef: AppRouteDef.home,
      sessionsByProject: {
        "p1": [
          adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One"),
          adaptiveTestSession(projectId: "p1", id: "session-2", title: "Session Two"),
        ],
      },
    );
    stubDelete(harness);

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text("Session One"));
    await tester.pumpAndSettle();

    await deleteFromList(tester: tester, title: "Session Two");

    expect(Uri.parse(harness.currentLocation).path, "/sessions/p1/session-1");
    expect(find.byKey(const ValueKey("session-detail-session-1")), findsOneWidget);
    expect(find.byType(NewSessionView), findsNothing);

    // Let the deletion alert expire so no timers outlive the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  Future<AdaptiveSessionRouterTestHarness> setUpTwoProjects({
    required WidgetTester tester,
    required Size size,
    required Map<String, List<Session>> sessionsByProject,
  }) async {
    final harness = await setUpHome(
      tester: tester,
      size: size,
      initialLocation: "/sessions",
      currentRouteDef: AppRouteDef.home,
      sessionsByProject: sessionsByProject,
    );
    when(() => harness.projectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(
        const Projects(
          data: [
            ProjectSummary(id: "p1", name: "Project One", path: "/p1", time: null),
            ProjectSummary(id: "p2", name: "Project Two", path: "/p2", time: null),
          ],
        ),
      ),
    );
    return harness;
  }

  testWidgets("the title filters the home to one project, and New session starts there", (tester) async {
    final harness = await setUpTwoProjects(
      tester: tester,
      size: const Size(390, 800),
      sessionsByProject: {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
        "p2": [adaptiveTestSession(projectId: "p2", id: "session-2", title: "Session Two")],
      },
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    expect(find.text("Session One"), findsOneWidget);
    expect(find.text("Session Two"), findsOneWidget);

    await tester.tap(find.text("All projects"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Project Two").last);
    await tester.pumpAndSettle();
    expect(find.text("Session One"), findsNothing);
    expect(find.text("Session Two"), findsOneWidget);

    final reveal = _revealFrom(tester: tester);
    await tester.tap(find.byKey(const Key("home-new-session")));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.queryParameters, {"project": "p2", "name": "Project Two", "reveal": reveal});
    harness.router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text("Project Two"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("All projects"));
    await tester.pumpAndSettle();
    expect(find.text("Session One"), findsOneWidget);
    expect(find.text("Session Two"), findsOneWidget);
  });

  testWidgets("with no session yet, New session asks for a project and lists the known ones", (tester) async {
    final harness = await setUpTwoProjects(
      tester: tester,
      size: const Size(390, 800),
      sessionsByProject: const {"p1": [], "p2": []},
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    final reveal = _revealFrom(tester: tester);
    await tester.tap(find.byKey(const Key("home-new-session")));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, "/sessions/new");
    expect(harness.router.state.uri.queryParameters, {"reveal": reveal});
    // The picker opens by itself, with nothing chosen.
    expect(find.text("Project One"), findsOneWidget);
    expect(find.text("Project Two"), findsOneWidget);
    expect(find.text("Open folder…"), findsOneWidget);

    // The chosen project replaces the page in place, still leaving by the +.
    await tester.tap(find.text("Project Two"));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.queryParameters, {"project": "p2", "name": "Project Two", "reveal": reveal});
  });

  testWidgets("the wide pane's draft follows the filter and the header", (tester) async {
    final harness = await setUpTwoProjects(
      tester: tester,
      size: const Size(1024, 800),
      sessionsByProject: {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
        "p2": [],
      },
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    final switcher = find.byKey(const Key("home-sidebar-switcher"));
    String draftProject() => tester.widget<NewSessionView>(find.byType(NewSessionView)).projectId;
    Future<void> pick({required Finder trigger, required String option}) async {
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    // The newest session's project.
    expect(draftProject(), "p1");

    await pick(trigger: switcher, option: "Project Two");
    expect(draftProject(), "p2");

    await pick(trigger: switcher, option: "All projects");
    expect(draftProject(), "p1");

    // The header moves the draft and leaves the filter.
    await pick(trigger: find.byKey(const Key("new_session_project")), option: "Project Two");
    expect(draftProject(), "p2");
    expect(find.descendant(of: switcher, matching: find.text("All projects")), findsOneWidget);
  });

  testWidgets("the wide home keeps one list across every project's routes", (tester) async {
    final harness = await setUpHome(
      tester: tester,
      size: const Size(1024, 800),
      initialLocation: "/sessions/p1/session-1?title=Session+One&readOnly=false",
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
        "p2": [adaptiveTestSession(projectId: "p2", id: "session-2", title: "Session Two")],
      },
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    AllSessionsCubit listCubit() => BlocProvider.of<AllSessionsCubit>(
      tester.element(find.descendant(of: leftPane, matching: find.byType(AllSessionsList))),
    );
    final first = listCubit();
    expect(find.descendant(of: leftPane, matching: find.text("Session Two")), findsOneWidget);

    harness.router.go("/sessions/p1/session-1/diffs");
    await _pumpRouteFrames(tester);
    expect(identical(listCubit(), first), isTrue);

    harness.router.go("/sessions/p2/session-2?title=Session+Two&readOnly=false");
    await _pumpRouteFrames(tester);
    expect(identical(listCubit(), first), isTrue);
    expect(find.byKey(const ValueKey("session-detail-session-2")), findsOneWidget);
    // Each project's sessions are read once, by the window, not again per
    // route.
    verify(() => harness.projectRepository.listSessions(projectId: "p2")).called(1);
  });
}
