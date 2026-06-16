import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_scope.dart";
import "package:sesori_mobile/features/session_detail/widgets/background_tasks_bar.dart";
import "package:sesori_mobile/features/session_detail/widgets/subtask_part_widget.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

Widget _buildApp({
  required Widget child,
  String initialLocation = "/",
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => child,
      ),
      GoRoute(
        path: "/projects/:projectId/sessions/:sessionId",
        builder: (context, state) {
          if (state.pathParameters["sessionId"] == "session-parent") {
            return child;
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
    theme: ThemeData(extensions: [ZyraDesignSystem.light]),
    darkTheme: ThemeData(extensions: [ZyraDesignSystem.dark]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

Session _childSession({required String id, String? title}) {
  return Session(
    id: id,
    projectID: "project-1",
    directory: "/home/user/my-project",
    parentID: "session-parent",
    title: title ?? "Child Session",
    summary: null,
    pullRequest: null,
    time: const SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
    promptDefaults: null,
  );
}

MessagePart _subtaskPart({String? description}) {
  return MessagePart(
    id: "part-1",
    sessionID: "session-parent",
    messageID: "msg-1",
    type: MessagePartType.subtask,
    text: null,
    tool: null,
    state: null,
    prompt: description,
    description: description,
    agent: null,
    agentName: null,
    attempt: null,
    retryError: null, mime: null, url: null, filename: null,
  );
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

  group("BackgroundTasksBar", () {
    testWidgets("tapping task row pushes route with readOnly=true outside split scope", (tester) async {
      final child = _childSession(id: "task-1", title: "Task One");
      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: BackgroundTasksBar(
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
