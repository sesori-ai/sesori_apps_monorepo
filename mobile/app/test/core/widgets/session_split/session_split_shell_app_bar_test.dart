import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

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

      // The detail screen is now a PregoGlassScaffold: its bar is a GlassAppBar
      // (not a Material AppBar). In the wide split the initial detail pane has
      // no back affordance (showLeading is false), so there is neither a stock
      // BackButton nor a glass chevron.
      final rightPane = find.byKey(const Key("session-split-right-pane"));
      expect(find.descendant(of: rightPane, matching: find.byType(GlassAppBar)), findsOneWidget);
      expect(find.descendant(of: rightPane, matching: find.byType(BackButton)), findsNothing);
      expect(find.descendant(of: rightPane, matching: find.byIcon(TablerRegular.chevron_left)), findsNothing);
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

      // The diffs screen is now a PregoGlassScaffold: its bar is a GlassAppBar
      // (not a Material AppBar) and its back affordance is the glass bar button
      // (chevron_left), not a stock BackButton. The collapsing large title is
      // the single "File Changes" at rest.
      final rightPane = find.byKey(const Key("session-split-right-pane"));
      expect(find.descendant(of: rightPane, matching: find.byType(GlassAppBar)), findsOneWidget);
      expect(find.descendant(of: rightPane, matching: find.byIcon(TablerRegular.chevron_left)), findsOneWidget);
      expect(find.descendant(of: rightPane, matching: find.text("File Changes")), findsOneWidget);
    });
  });
}
