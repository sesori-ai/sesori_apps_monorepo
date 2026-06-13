import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../../helpers/test_helpers.dart";
import "../../routing/adaptive_session_router_test_harness.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("SessionSplitShell wide app bars", () {
    testWidgets("shows exactly one app bar in right panel for detail", (tester) async {
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
      );

      await tester.pumpWidget(harness.buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final rightPane = find.byKey(const Key("session-split-right-pane"));
      expect(find.descendant(of: rightPane, matching: find.byType(AppBar)), findsOneWidget);
      expect(find.descendant(of: rightPane, matching: find.byType(BackButton)), findsNothing);
    });

    testWidgets("shows exactly one app bar in right panel for diffs", (tester) async {
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      await harness.setUp(
        initialLocation: "/projects/p1/sessions/session-1/diffs",
        currentRouteDef: AppRouteDef.sessionDiffs,
        sessionsByProject: {
          "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
        },
        diffsBySession: {
          "session-1": [adaptiveTestDiff()],
        },
      );

      await tester.pumpWidget(harness.buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final rightPane = find.byKey(const Key("session-split-right-pane"));
      expect(find.descendant(of: rightPane, matching: find.byType(AppBar)), findsOneWidget);
      expect(find.descendant(of: rightPane, matching: find.byType(BackButton)), findsOneWidget);
      expect(find.descendant(of: rightPane, matching: find.text("File Changes")), findsOneWidget);
    });
  });
}
