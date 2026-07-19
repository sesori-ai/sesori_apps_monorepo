import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/widgets/session_split/empty_session_detail_panel.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/features/session_list/session_tile.dart";

import "../../helpers/test_helpers.dart";
import "adaptive_session_router_test_harness.dart";

Future<void> _pumpDiffFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(registerAllFallbackValues);

  group("adaptive session route matrix", () {
    testWidgets("/projects/:projectId/sessions renders correctly at 390px and 1024px", (tester) async {
      const location = "/projects/p1/sessions";
      final sessions = {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
      };

      for (final width in [390.0, 1024.0]) {
        final harness = AdaptiveSessionRouterTestHarness();
        await tester.binding.setSurfaceSize(Size(width, 800));
        try {
          await harness.setUp(
            initialLocation: location,
            currentRouteDef: AppRouteDef.sessions,
            sessionsByProject: sessions,
          );

          await tester.pumpWidget(harness.buildApp());
          await _pumpDiffFrames(tester);

          expect(find.text("Session One"), findsOneWidget);

          if (width == 390) {
            expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
            expect(find.byKey(const Key("session-split-right-pane")), findsNothing);
            expect(find.byType(EmptySessionDetailPanel), findsNothing);
          } else {
            expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
            expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
            expect(find.byType(EmptySessionDetailPanel), findsOneWidget);
          }
        } finally {
          await harness.tearDown();
        }
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets("/projects/:projectId/sessions/:sessionId renders correctly at 390px and 1024px", (tester) async {
      const location = "/projects/p1/sessions/session-1?title=Session+One&readOnly=false";
      final sessions = {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
      };

      for (final width in [390.0, 1024.0]) {
        final harness = AdaptiveSessionRouterTestHarness();
        await tester.binding.setSurfaceSize(Size(width, 800));
        try {
          await harness.setUp(
            initialLocation: location,
            currentRouteDef: AppRouteDef.sessionDetail,
            sessionsByProject: sessions,
          );

          await tester.pumpWidget(harness.buildApp());
          await _pumpDiffFrames(tester);

          expect(find.byKey(const ValueKey("session-detail-session-1")), findsOneWidget);

          if (width == 390) {
            expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
            expect(find.byKey(const Key("session-split-right-pane")), findsNothing);
          } else {
            expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
            expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
          }
        } finally {
          await harness.tearDown();
        }
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets("/projects/:projectId/sessions/:sessionId/diffs renders correctly at 390px and 1024px", (tester) async {
      const location = "/projects/p1/sessions/session-1/diffs";
      final sessions = {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
      };

      for (final width in [390.0, 1024.0]) {
        final harness = AdaptiveSessionRouterTestHarness();
        await tester.binding.setSurfaceSize(Size(width, 800));
        try {
          await harness.setUp(
            initialLocation: location,
            currentRouteDef: AppRouteDef.sessionDiffs,
            sessionsByProject: sessions,
            diffsBySession: {
              "session-1": [adaptiveTestDiff()],
            },
          );

          await tester.pumpWidget(harness.buildApp());
          await _pumpDiffFrames(tester);

          expect(find.byKey(const ValueKey("session-diffs-session-1")), findsOneWidget);
          expect(find.text("File Changes"), findsOneWidget);

          if (width == 390) {
            expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
            expect(find.byKey(const Key("session-split-right-pane")), findsNothing);
          } else {
            expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
            expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
            expect(find.text("Session One"), findsOneWidget);
          }
        } finally {
          await harness.tearDown();
        }
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets("/projects/:projectId/sessions/new renders in the session pane and wins over dynamic matching", (
      tester,
    ) async {
      const location = "/projects/p1/sessions/new";
      final sessions = {
        "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
      };

      for (final width in [390.0, 1024.0]) {
        final harness = AdaptiveSessionRouterTestHarness();
        await tester.binding.setSurfaceSize(Size(width, 800));
        try {
          await harness.setUp(
            initialLocation: location,
            currentRouteDef: AppRouteDef.newSession,
            sessionsByProject: sessions,
          );

          await tester.pumpWidget(harness.buildApp());
          await tester.pumpAndSettle();

          expect(find.byType(NewSessionScreen), findsOneWidget);
          expect(find.byKey(const ValueKey("session-detail-new")), findsNothing);
          expect(find.byType(EmptySessionDetailPanel), findsNothing);
          if (width == 390) {
            expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
            expect(find.byKey(const Key("session-split-right-pane")), findsNothing);
          } else {
            expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
            expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
            final tile = tester.widget<SessionTile>(find.widgetWithText(SessionTile, "Session One"));
            expect(tile.selected, isFalse);
          }
        } finally {
          await harness.tearDown();
        }
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets("shrinking from wide detail to 390 keeps the same full-screen detail route", (tester) async {
      const location = "/projects/p1/sessions/session-1?title=Session+One&readOnly=false";
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      await harness.setUp(
        initialLocation: location,
        currentRouteDef: AppRouteDef.sessionDetail,
        sessionsByProject: {
          "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
        },
      );

      await tester.pumpWidget(harness.buildApp());
      await _pumpDiffFrames(tester);

      expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
      expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(390, 800));
      await tester.pumpAndSettle();

      expect(harness.currentLocation, location);
      expect(find.byKey(const ValueKey("session-detail-session-1")), findsOneWidget);
      expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
      expect(find.byKey(const Key("session-split-right-pane")), findsNothing);
    });

    testWidgets("expanding from narrow diffs to 1024 keeps the same route and shows split list plus diffs", (
      tester,
    ) async {
      const location = "/projects/p1/sessions/session-1/diffs";
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      await harness.setUp(
        initialLocation: location,
        currentRouteDef: AppRouteDef.sessionDiffs,
        sessionsByProject: {
          "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
        },
        diffsBySession: {
          "session-1": [adaptiveTestDiff()],
        },
      );

      await tester.pumpWidget(harness.buildApp());
      await _pumpDiffFrames(tester);

      expect(find.byKey(const ValueKey("session-diffs-session-1")), findsOneWidget);
      expect(find.byKey(const Key("session-split-left-pane")), findsNothing);

      await tester.binding.setSurfaceSize(const Size(1024, 800));
      await _pumpDiffFrames(tester);

      expect(harness.currentLocation, location);
      expect(find.byKey(const ValueKey("session-diffs-session-1")), findsOneWidget);
      expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
      expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
      expect(find.text("Session One"), findsOneWidget);
    });
  });
}
