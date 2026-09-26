import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/routing/adaptive_session_router_test_harness.dart";
import "../../helpers/test_helpers.dart";

/// Opens the session page's menu and picks Changes, which is where the phone
/// bar keeps it so the centred title has room.
Future<void> _openChanges(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key("session-detail-more")));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key("session-detail-changes")));
}

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

    await _openChanges(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.router.canPop(), isTrue);
    expect(find.byKey(const ValueKey("session-diffs-session-1")), findsOneWidget);
    expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
  });

  testWidgets("diff button pushes diffs in the right pane on wide layouts", (tester) async {
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

    await _openChanges(tester);
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.toString(), "/projects/p1/sessions/session-1/diffs");
    expect(harness.router.canPop(), isTrue);
    final rightPane = find.byKey(const Key("session-split-right-pane"));
    expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
    expect(rightPane, findsOneWidget);
    expect(
      find.descendant(of: rightPane, matching: find.byKey(const ValueKey("session-diffs-session-1"))),
      findsOneWidget,
    );
    // The session route is retained under the pushed diffs route, so its title
    // is still in the tree — offstage, as any covered route's is.
    expect(find.text("Session One", skipOffstage: false), findsOneWidget);

    harness.router.pop();
    await tester.pumpAndSettle();

    expect(Uri.parse(harness.currentLocation).path, "/projects/p1/sessions/session-1");
    expect(
      find.descendant(of: rightPane, matching: find.byKey(const ValueKey("session-detail-session-1"))),
      findsOneWidget,
    );
    expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
  });

  testWidgets("child-session push from wide detail returns to parent detail on back", (tester) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    final parent = adaptiveTestSession(projectId: "p1", id: "parent-1", title: "Parent Session");
    final child = adaptiveTestSession(projectId: "p1", id: "child-1", title: "Child Session");
    await harness.setUp(
      initialLocation: "/projects/p1/sessions/parent-1?title=Parent+Session&readOnly=false",
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: {
        "p1": [parent, child],
      },
      childSessionsBySession: {
        "parent-1": [child],
      },
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("sub_agents_pill")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Child Session").last);
    await tester.pumpAndSettle();

    final rightPane = find.byKey(const Key("session-split-right-pane"));
    expect(
      find.descendant(of: rightPane, matching: find.byKey(const ValueKey("session-detail-child-1"))),
      findsOneWidget,
    );
    expect(find.descendant(of: rightPane, matching: find.byIcon(TablerRegular.chevron_left)), findsOneWidget);

    await _openChanges(tester);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: rightPane, matching: find.byKey(const ValueKey("session-diffs-child-1"))),
      findsOneWidget,
    );

    harness.router.pop();
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: rightPane, matching: find.byKey(const ValueKey("session-detail-child-1"))),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: rightPane, matching: find.byIcon(TablerRegular.chevron_left)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("session-detail-parent-1")), findsOneWidget);
    expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
  });

  testWidgets("covered session does not present an incoming question over new session", (tester) async {
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
    await tester.pumpAndSettle();

    unawaited(harness.router.push<void>("/projects/p1/sessions/new"));
    await tester.pumpAndSettle();
    harness.emitSessionEvent(
      event: const SesoriQuestionAsked(
        id: "question-1",
        sessionID: "session-1",
        displaySessionId: null,
        questions: [
          QuestionInfo(
            question: "Choose a release channel",
            header: "Release channel",
            options: [QuestionOption(label: "Stable", description: "Release to everyone")],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, "/projects/p1/sessions/new");
    expect(find.text("Choose a release channel"), findsNothing);
  });

  testWidgets("cross-session navigation dismisses the previous session permission sheet", (tester) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: "/projects/p1/sessions/session-1?title=Session+One&readOnly=false",
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: {
        "p1": [
          adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One"),
          adaptiveTestSession(projectId: "p1", id: "session-2", title: "Session Two"),
        ],
      },
    );

    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    harness.emitSessionEvent(
      event: const SesoriPermissionAsked(
        requestID: "permission-1",
        sessionID: "session-1",
        displaySessionId: null,
        tool: "write_file",
        description: "Allow writing the release notes",
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("write_file"), findsOneWidget);

    harness.router.go("/projects/p1/sessions/session-2?title=Session+Two&readOnly=false");
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("session-detail-session-2")), findsOneWidget);
    expect(find.text("write_file"), findsNothing);
  });
}
