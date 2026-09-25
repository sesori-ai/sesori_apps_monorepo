import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockMessageImageRepository() extends Mock implements MessageImageRepository;

class _MockImageSaver() extends Mock implements ImageSaver;

class _MockImageClipboard() extends Mock implements ImageClipboard;

class _MockImageSharer() extends Mock implements ImageSharer;

Widget _presentationScope({required BuildContext context, required Widget child}) {
  return SessionDetailPresentationScope(
    openHarnessSettings: () {},
    openBridgeSettings: () {},
    messageImageRepository: _MockMessageImageRepository.new,
    imageSaver: _MockImageSaver.new,
    imageClipboard: _MockImageClipboard.new,
    imageSharer: _MockImageSharer.new,
    canShareImages: true,
    openExternalLink: ({required url, required mode}) async => false,
    openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) =>
        context.pushRoute(
          AppRoute.sessionDetail(
            projectId: projectId,
            projectName: "Project One",
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            readOnly: readOnly,
          ),
        ),
    child: child,
  );
}

Widget _buildApp({
  required Widget child,
  String initialLocation = "/",
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => _presentationScope(context: context, child: child),
      ),
      GoRoute(
        path: "/projects/:projectId/sessions/:sessionId",
        builder: (context, state) {
          if (state.pathParameters["sessionId"] == "session-parent") {
            return _presentationScope(context: context, child: child);
          }
          final readOnly = state.uri.queryParameters["readOnly"];
          final projectName = state.uri.queryParameters["name"];
          return Scaffold(
            body: Column(
              children: [
                Text('sessionId=${state.pathParameters["sessionId"]}'),
                Text('readOnly=$readOnly'),
                Text('name=$projectName'),
                if (GoRouter.of(context).canPop()) const Text('canPop=true'),
              ],
            ),
          );
        },
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

Session _childSession({required String id, String? title}) {
  return Session(
    approvalOverride: null,
    autoContinuation: null,
    branchName: null,
    id: id,
    pluginId: "plugin-1",
    projectID: "project-1",
    directory: "/home/user/my-project",
    parentID: "session-parent",
    title: title ?? "Child Session",
    pullRequest: null,
    time: const SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
    promptDefaults: null,
    lastUserActivityAt: null,
  );
}

MessagePartSubtask _subtaskPart({String? description, String? childSessionID}) {
  final part = MessagePart.subtask(
    id: "part-1",
    sessionID: "session-parent",
    messageID: "msg-1",
    prompt: description ?? "",
    description: description ?? "",
    agent: "",
    taskState: null,
    childSessionID: childSessionID,
  );
  if (part case final MessagePartSubtask subtask) return subtask;
  throw StateError("MessagePart.subtask returned a non-subtask variant");
}

void main() {
  group("SubtaskPartWidget", () {
    testWidgets("tapping child session pushes route with readOnly=true outside split scope", (tester) async {
      final child = _childSession(id: "child-1", title: "Child Session");
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: SubtaskPartWidget(
              projectId: "project-1",
              part: _subtaskPart(description: "Child Session"),
              childSession: child,
              status: TranscriptStepStatus.finished,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Agent Child Session"));
      await tester.pumpAndSettle();

      // Push adds to stack, so canPop should be true.
      expect(find.text("canPop=true"), findsOneWidget);
      expect(find.text("sessionId=child-1"), findsOneWidget);
      expect(find.text("readOnly=true"), findsOneWidget);
    });

    testWidgets("tapping child session pushes route with readOnly=true from split context", (tester) async {
      final child = _childSession(id: "child-1", title: "Child Session");
      await tester.pumpWidget(
        _buildApp(
          initialLocation: "/projects/project-1/sessions/session-parent?name=Project+One&readOnly=false",
          child: Scaffold(
            body: SessionSplitScope(
              isSplit: true,
              child: SubtaskPartWidget(
                projectId: "project-1",
                part: _subtaskPart(description: "Child Session"),
                childSession: child,
                status: TranscriptStepStatus.finished,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Agent Child Session"));
      await tester.pumpAndSettle();

      expect(find.text("canPop=true"), findsOneWidget);
      expect(find.text("sessionId=child-1"), findsOneWidget);
      expect(find.text("readOnly=true"), findsOneWidget);
      expect(find.text("name=Project One"), findsOneWidget);
    });
  });

  group("SubtaskPartWidget target", () {
    testWidgets("a named child session is opened by id, not by the resolved child", (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: SubtaskPartWidget(
              projectId: "project-1",
              part: _subtaskPart(description: "Child Session", childSessionID: "agent-42"),
              childSession: _childSession(id: "child-1", title: "Child Session"),
              status: TranscriptStepStatus.finished,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Agent Child Session"));
      await tester.pumpAndSettle();

      expect(find.text("sessionId=agent-42"), findsOneWidget);
      expect(find.text("readOnly=true"), findsOneWidget);
    });

    testWidgets("a named child session is opened before the bridge publishes it", (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: SubtaskPartWidget(
              projectId: "project-1",
              part: _subtaskPart(description: "Explore the plugin", childSessionID: "agent-42"),
              childSession: null,
              status: TranscriptStepStatus.finished,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Agent Explore the plugin"));
      await tester.pumpAndSettle();

      expect(find.text("sessionId=agent-42"), findsOneWidget);
    });

    testWidgets("an unnamed, unresolved child stays closed", (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: SubtaskPartWidget(
              projectId: "project-1",
              part: _subtaskPart(description: "Explore the plugin"),
              childSession: null,
              status: TranscriptStepStatus.finished,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Agent Explore the plugin"));
      await tester.pumpAndSettle();

      expect(find.textContaining("sessionId="), findsNothing);
    });
  });

  group("SubtaskPartWidget status", () {
    // A running tile animates forever, so these pump one frame instead of
    // settling.
    Future<void> pumpStatus(WidgetTester tester, {required TranscriptStepStatus status}) async {
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: SubtaskPartWidget(
              projectId: "project-1",
              part: _subtaskPart(description: "Explore the plugin", childSessionID: "agent-42"),
              childSession: null,
              status: status,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets("a running sub-agent's label shimmers", (tester) async {
      await pumpStatus(tester, status: TranscriptStepStatus.running);

      expect(find.byType(PregoShimmer), findsOneWidget);
      expect(find.byType(PregoActivityIndicator), findsNothing);
    });

    testWidgets("a finished sub-agent says nothing", (tester) async {
      await pumpStatus(tester, status: TranscriptStepStatus.finished);

      expect(find.text("Done"), findsNothing);
      expect(find.byType(PregoShimmer), findsNothing);
      expect(find.byIcon(TablerSolid.alert_circle), findsNothing);
    });

    testWidgets("a failed sub-agent keeps one signal", (tester) async {
      await pumpStatus(tester, status: TranscriptStepStatus.failed);

      expect(find.text("Failed"), findsNothing);
      expect(find.byIcon(TablerSolid.alert_circle), findsOneWidget);
    });
  });

  group("BackgroundTasksBar", () {
    testWidgets("counts sub-agents, signals work, and never calls an idle one completed", (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: BackgroundTasksBar(
                surfaceStyle: PregoComposerSurfaceStyle.subtle,
                projectId: "project-1",
                children: [
                  _childSession(id: "task-1", title: "Idle one"),
                  _childSession(id: "task-2", title: "Working one"),
                ],
                childStatuses: const {"task-2": SessionStatus.busy()},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("2"), findsOneWidget);
      expect(find.byType(PregoActivityIndicator), findsOneWidget);
      expect(find.byTooltip("2 sub-agents, 1 working"), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey("sub_agents_pill")));
      await tester.pump();

      // Working first; the idle one stays listed because it can be resumed.
      expect(
        tester.getTopLeft(find.text("Working one")).dy,
        lessThan(tester.getTopLeft(find.text("Idle one")).dy),
      );
      expect(find.textContaining("Idle"), findsWidgets);
      expect(find.textContaining("ompleted"), findsNothing);
    });

    testWidgets("tapping task row pushes route with readOnly=true outside split scope", (tester) async {
      final child = _childSession(id: "task-1", title: "Task One");
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            // The pill lives at the composer's trailing edge; its list grows up.
            body: Align(
              alignment: Alignment.bottomRight,
              child: BackgroundTasksBar(
                surfaceStyle: PregoComposerSurfaceStyle.subtle,
                projectId: "project-1",
                children: [child],
                childStatuses: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey("sub_agents_pill")));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Task One"));
      await tester.pumpAndSettle();

      expect(find.text("canPop=true"), findsOneWidget);
      expect(find.text("sessionId=task-1"), findsOneWidget);
      expect(find.text("readOnly=true"), findsOneWidget);
    });

    testWidgets("tapping task row pushes route with readOnly=true from split context", (tester) async {
      final child = _childSession(id: "task-1", title: "Task One");
      await tester.pumpWidget(
        _buildApp(
          initialLocation: "/projects/project-1/sessions/session-parent?name=Project+One&readOnly=false",
          child: Scaffold(
            body: SessionSplitScope(
              isSplit: true,
              child: Align(
                alignment: Alignment.bottomRight,
                child: BackgroundTasksBar(
                  surfaceStyle: PregoComposerSurfaceStyle.subtle,
                  projectId: "project-1",
                  children: [child],
                  childStatuses: const {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey("sub_agents_pill")));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Task One"));
      await tester.pumpAndSettle();

      expect(find.text("canPop=true"), findsOneWidget);
      expect(find.text("sessionId=task-1"), findsOneWidget);
      expect(find.text("readOnly=true"), findsOneWidget);
      expect(find.text("name=Project One"), findsOneWidget);
    });
  });
}
