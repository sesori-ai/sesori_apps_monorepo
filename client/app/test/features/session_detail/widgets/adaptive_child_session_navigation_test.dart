import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/features/session_detail/widgets/background_tasks_bar.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockMessageImageRepository() extends Mock implements MessageImageRepository;

class _MockImageSaver() extends Mock implements ImageSaver;

class _MockImageClipboard() extends Mock implements ImageClipboard;

class _MockImageSharer() extends Mock implements ImageSharer;

Widget _presentationScope({required BuildContext context, required Widget child}) {
  return SessionDetailPresentationScope(
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

MessagePartSubtask _subtaskPart({String? description, String? childSessionID, ToolStatus? status}) {
  final part = MessagePart.subtask(
    id: "part-1",
    sessionID: "session-parent",
    messageID: "msg-1",
    prompt: description ?? "",
    description: description ?? "",
    agent: "",
    taskState: status == null ? null : ToolState(status: status, title: null, output: null, error: null),
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
              children: [child],
              childStatuses: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Child Session"));
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
                children: [child],
                childStatuses: const {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Child Session"));
      await tester.pumpAndSettle();

      expect(find.text("canPop=true"), findsOneWidget);
      expect(find.text("sessionId=child-1"), findsOneWidget);
      expect(find.text("readOnly=true"), findsOneWidget);
      expect(find.text("name=Project One"), findsOneWidget);
    });
  });

  group("SubtaskPartWidget child resolution", () {
    testWidgets("a named child session is opened by id, not by matching titles", (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: SubtaskPartWidget(
              projectId: "project-1",
              // The only known child has a matching title, so the heuristic
              // would open it; the named child must win.
              part: _subtaskPart(description: "Child Session", childSessionID: "agent-42"),
              children: [_childSession(id: "child-1", title: "Child Session")],
              childStatuses: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Child Session"));
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
              children: const [],
              childStatuses: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Explore the plugin"));
      await tester.pumpAndSettle();

      expect(find.text("sessionId=agent-42"), findsOneWidget);
    });

    testWidgets("an unnamed child with no title match stays closed", (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: SubtaskPartWidget(
              projectId: "project-1",
              part: _subtaskPart(description: "Explore the plugin"),
              children: [
                _childSession(id: "child-1", title: "Something else"),
                _childSession(id: "child-2", title: "Another thing"),
              ],
              childStatuses: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Explore the plugin"));
      await tester.pumpAndSettle();

      expect(find.textContaining("sessionId="), findsNothing);
    });
  });

  group("SubtaskPartWidget status", () {
    // A running tile animates forever, so these pump one frame instead of
    // settling.
    Future<void> pumpStatus(WidgetTester tester, {required ToolStatus? status}) async {
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: SubtaskPartWidget(
              projectId: "project-1",
              part: _subtaskPart(description: "Explore the plugin", childSessionID: "agent-42", status: status),
              children: const [],
              childStatuses: const {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets("a running subtask reports its own lifecycle", (tester) async {
      await pumpStatus(tester, status: ToolStatus.running);

      expect(find.text("Running"), findsOneWidget);
      expect(find.byType(PregoActivityIndicator), findsOneWidget);
    });

    testWidgets("a completed subtask reports its own lifecycle", (tester) async {
      await pumpStatus(tester, status: ToolStatus.completed);

      expect(find.text("Done"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets("a failed subtask reports its own lifecycle", (tester) async {
      await pumpStatus(tester, status: ToolStatus.error);

      expect(find.text("Failed"), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets("a cancelled subtask reports its own lifecycle", (tester) async {
      await pumpStatus(tester, status: ToolStatus.cancelled);

      expect(find.text("Cancelled"), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets("a subtask without its own lifecycle keeps following its child session", (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: SubtaskPartWidget(
              projectId: "project-1",
              part: _subtaskPart(description: "Child Session"),
              children: [_childSession(id: "child-1", title: "Child Session")],
              childStatuses: const {"child-1": SessionStatus.busy()},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PregoActivityIndicator), findsOneWidget);
      // No lifecycle of its own means no status label to report.
      expect(find.text("Running"), findsNothing);
    });
  });

  group("BackgroundTasksBar", () {
    testWidgets("tapping task row pushes route with readOnly=true outside split scope", (tester) async {
      final child = _childSession(id: "task-1", title: "Task One");
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: BackgroundTasksBar(
              surfaceStyle: PregoComposerSurfaceStyle.subtle,
              projectId: "project-1",
              children: [child],
              childStatuses: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("All tasks completed"));
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

      await tester.tap(find.text("All tasks completed"));
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
