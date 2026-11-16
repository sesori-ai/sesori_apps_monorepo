import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/routing/app_router.dart";

import "../../helpers/test_helpers.dart";
import "adaptive_session_router_test_harness.dart";

const _originKey = ValueKey("session-detail-origin");
const _forkKey = ValueKey("session-detail-fork");

Future<void> _settle(WidgetTester tester) async {
  // The session screen animates indefinitely, so pumpAndSettle never returns.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(registerAllFallbackValues);

  Future<AdaptiveSessionRouterTestHarness> pumpHome(WidgetTester tester) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await harness.setUp(
      initialLocation: "/sessions",
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: {
        "p1": [
          adaptiveTestSession(projectId: "p1", id: "origin", title: "Origin"),
          adaptiveTestSession(projectId: "p1", id: "fork", title: "Origin (fork)"),
        ],
      },
    );
    await tester.pumpWidget(harness.buildApp());
    await _settle(tester);
    return harness;
  }

  void returnToOrigin(WidgetTester tester) => returnToSessionRoute(
    context: tester.element(find.byKey(_forkKey)),
    projectId: "p1",
    projectName: null,
    sessionId: "origin",
    sessionTitle: "Origin",
  );

  testWidgets("a fork opened over its origin goes back to it, so the pages never pile up", (tester) async {
    final harness = await pumpHome(tester);
    try {
      unawaited(harness.router.push<void>("/sessions/p1/origin?readOnly=false"));
      await _settle(tester);
      unawaited(harness.router.push<void>("/sessions/p1/fork?readOnly=false"));
      await _settle(tester);

      returnToOrigin(tester);
      await _settle(tester);
      expect(find.byKey(_forkKey), findsNothing);
      expect(find.byKey(_originKey), findsOneWidget);

      // The origin is the page it was before the fork opened: back leaves it for the home.
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byKey(_originKey), findsNothing);
      expect(find.byKey(const Key("home-new-session")), findsOneWidget);
    } finally {
      await harness.tearDown();
    }
  });

  testWidgets("a fork reached another way opens its origin over it", (tester) async {
    final harness = await pumpHome(tester);
    try {
      harness.router.go("/sessions/p1/fork?readOnly=false");
      await _settle(tester);

      returnToOrigin(tester);
      await _settle(tester);
      expect(find.byKey(_originKey), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byKey(_forkKey), findsOneWidget);
    } finally {
      await harness.tearDown();
    }
  });
}
