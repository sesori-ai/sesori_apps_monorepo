import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/routing/adaptive_session_router_test_harness.dart";
import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  testWidgets("diff button pushes diffs on narrow layouts", (tester) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: "/projects/p1/sessions/session-1?title=Session+One&readOnly=false",
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
      },
      diffsBySession: {
        "session-1": [adaptiveTestDiff()],
      },
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.difference_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.router.canPop(), isTrue);
    expect(find.byKey(const ValueKey("session-diffs-session-1")), findsOneWidget);
    expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
  });

  testWidgets("diff button replaces the right pane on wide layouts", (tester) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: "/projects/p1/sessions/session-1?title=Session+One&readOnly=false",
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
      },
      diffsBySession: {
        "session-1": [adaptiveTestDiff()],
      },
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.difference_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.currentLocation, "/projects/p1/sessions/session-1/diffs");
    expect(harness.router.canPop(), isFalse);
    expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
    expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
    expect(find.byKey(const ValueKey("session-diffs-session-1")), findsOneWidget);
    expect(find.text("Session One"), findsOneWidget);
  });
}
