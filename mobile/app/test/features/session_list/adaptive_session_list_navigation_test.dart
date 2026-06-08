import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/features/session_list/session_list_panel.dart";

import "../../core/routing/adaptive_session_router_test_harness.dart";
import "../../helpers/test_helpers.dart";

Future<void> _pumpRouteFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(registerAllFallbackValues);

  testWidgets("list tile tap pushes detail on narrow layouts", (tester) async {
    const location = "/projects/p1/sessions";
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: location,
      currentRouteDef: AppRouteDef.sessions,
      sessionsByProject: {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
      },
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Session One"));
    await _pumpRouteFrames(tester);

    expect(harness.router.canPop(), isTrue);
    expect(find.byKey(const ValueKey("session-detail-session-1")), findsOneWidget);
    expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
  });

  testWidgets("list tile tap replaces detail in the wide split shell", (tester) async {
    const location = "/projects/p1/sessions";
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: location,
      currentRouteDef: AppRouteDef.sessions,
      sessionsByProject: {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
      },
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Session One"));
    await tester.pumpAndSettle();

    final uri = Uri.parse(harness.currentLocation);
    expect(uri.path, "/projects/p1/sessions/session-1");
    expect(uri.queryParameters["title"], "Session One");
    expect(uri.queryParameters["readOnly"], "false");
    expect(harness.router.canPop(), isFalse);
    expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
    expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
    expect(find.byKey(const ValueKey("session-detail-session-1")), findsOneWidget);

    final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, "Session One"));
    expect(tile.selected, isTrue);
  });

  testWidgets("replaceRoute preserves the parent stack below the current route", (tester) async {
    final harness = AdaptiveSessionRouterTestHarness();
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: "/projects/p1/sessions",
      currentRouteDef: AppRouteDef.sessions,
      sessionsByProject: {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
      },
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    // Push session detail on top of sessions.
    // The future only completes when the route is popped, which never
    // happens in this test — fire-and-forget so the await doesn't hang.
    unawaited(harness.router.push("/projects/p1/sessions/session-1"));
    await tester.pumpAndSettle();

    expect(harness.router.canPop(), isTrue);

    // Replace the current route with the diffs route.  We verify the
    // replacement happened by checking canPop() stays true (the parent
    // /projects/p1/sessions route is preserved).  We avoid asserting on the
    // exact path because GoRouter’s routeInformationProvider does not reflect
    // push/replace state in widget tests when called directly on the router.
    harness.router.replaceRoute(
      const AppRoute.sessionDiffs(projectId: "p1", sessionId: "session-1"),
    );
    await tester.pumpAndSettle();

    // replaceRoute should keep the /projects/p1/sessions route below the current one.
    expect(harness.router.canPop(), isTrue);
  });

  testWidgets("wide shell preserves the left-list cubit for same-project routes and resets it for a new project", (
    tester,
  ) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: "/projects/p1/sessions/session-1?title=Session+One&readOnly=false",
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
        "p2": [adaptiveTestSession(projectId: "p2", id: "session-2", title: "Session Two")],
      },
      diffsBySession: {
        "session-1": [adaptiveTestDiff()],
        "session-2": [adaptiveTestDiff(file: "lib/src/other.dart")],
      },
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    final firstListElement = tester.element(
      find.descendant(
        of: find.byKey(const ValueKey("session-list-p1")).first,
        matching: find.byType(SessionListPanel),
      ),
    );
    final firstCubit = BlocProvider.of<SessionListCubit>(firstListElement);

    verify(() => harness.projectService.listSessions(projectId: "p1", waitForPrData: false)).called(1);
    verify(() => harness.projectService.getBaseBranch(projectId: "p1")).called(1);

    harness.router.go("/projects/p1/sessions/session-1/diffs");
    await _pumpRouteFrames(tester);

    final sameProjectCubit = BlocProvider.of<SessionListCubit>(
      tester.element(
        find.descendant(
          of: find.byKey(const ValueKey("session-list-p1")).first,
          matching: find.byType(SessionListPanel),
        ),
      ),
    );
    expect(identical(sameProjectCubit, firstCubit), isTrue);
    verifyNever(() => harness.projectService.listSessions(projectId: "p1", waitForPrData: true));

    harness.router.go("/projects/p2/sessions/session-2?title=Session+Two&readOnly=false");
    await _pumpRouteFrames(tester);

    final secondProjectCubit = BlocProvider.of<SessionListCubit>(
      tester.element(
        find.descendant(
          of: find.byKey(const ValueKey("session-list-p2")).first,
          matching: find.byType(SessionListPanel),
        ),
      ),
    );
    expect(identical(secondProjectCubit, firstCubit), isFalse);
    verify(() => harness.projectService.listSessions(projectId: "p2", waitForPrData: false)).called(1);
    verify(() => harness.projectService.getBaseBranch(projectId: "p2")).called(1);
  });
}
