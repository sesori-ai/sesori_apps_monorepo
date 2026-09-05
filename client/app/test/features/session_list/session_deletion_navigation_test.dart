import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_mobile/features/session_list/session_list_screen.dart";

void main() {
  for (final suffix in ["", "/diffs"]) {
    testWidgets("deletion closes the current session$suffix from a context outside its route", (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: "/projects/p1/sessions/deleted$suffix?name=Project+One",
        routes: [
          GoRoute(
            path: "/projects/:projectId/sessions",
            builder: (_, _) => const SizedBox(),
            routes: [
              GoRoute(
                path: ":sessionId",
                builder: (_, _) => const SizedBox(),
                routes: [GoRoute(path: "diffs", builder: (_, _) => const SizedBox())],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final context = navigatorKey.currentContext!;
      expect(ModalRoute.of(context), isNull);

      closeDeletedSessionRoute(context: context, sessionId: "another-session");
      expect(router.state.pathParameters["sessionId"], "deleted");

      closeDeletedSessionRoute(context: context, sessionId: "deleted");
      await tester.pumpAndSettle();
      expect(router.state.uri.path, "/projects/p1/sessions");
      expect(router.state.uri.queryParameters["name"], "Project One");

      closeDeletedSessionRoute(context: context, sessionId: "deleted");
      await tester.pumpAndSettle();
      expect(router.state.uri.path, "/projects/p1/sessions");
      expect(tester.takeException(), isNull);
    });
  }
}
