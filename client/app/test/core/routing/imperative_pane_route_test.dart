import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_mobile/core/routing/imperative_pane_route.dart";

void main() {
  testWidgets("isImperativePaneRoute is false for declarative route matches", (tester) async {
    final router = _router(initialLocation: "/projects/p1/sessions/s1");

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text("imperative=false"), findsOneWidget);
  });

  testWidgets("isImperativePaneRoute is true for imperatively pushed matches", (tester) async {
    final router = _router(initialLocation: "/");

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    unawaited(router.push("/projects/p1/sessions/s1"));
    await tester.pumpAndSettle();

    expect(find.text("imperative=true"), findsOneWidget);
  });
}

class _ImperativeProbe extends StatelessWidget {
  const _ImperativeProbe();

  @override
  Widget build(BuildContext context) {
    return Text("imperative=${isImperativePaneRoute(context)}");
  }
}

GoRouter _router({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push("/projects/p1/sessions/s1"),
            child: const Text("Push detail"),
          ),
        ),
      ),
      GoRoute(
        path: "/projects/:projectId/sessions/:sessionId",
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
          child: const Scaffold(body: _ImperativeProbe()),
        ),
      ),
    ],
  );
}
