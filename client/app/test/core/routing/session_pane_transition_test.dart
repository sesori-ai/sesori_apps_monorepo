import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_mobile/core/routing/app_router.dart";

void main() {
  testWidgets("a translucent route over a session page leaves it still", (tester) async {
    final session = await _pumpSessionPage(tester: tester);
    final restingLeft = tester.getTopLeft(find.text("Session")).dx;

    _push(session: session, opaque: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.getTopLeft(find.text("Session")).dx, restingLeft);
  });

  testWidgets("a page over a session page still moves it aside", (tester) async {
    final session = await _pumpSessionPage(tester: tester);
    final restingLeft = tester.getTopLeft(find.text("Session")).dx;

    _push(session: session, opaque: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.getTopLeft(find.text("Session")).dx, lessThan(restingLeft));
  });
}

Future<BuildContext> _pumpSessionPage({required WidgetTester tester}) async {
  late BuildContext sessionContext;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        pageBuilder: (context, state) => buildSessionPaneTransitionPage(
          context: context,
          state: state,
          pageKey: state.pageKey,
          skipsEntryTransition: false,
          child: Scaffold(
            body: Builder(
              builder: (context) {
                sessionContext = context;
                return const Text("Session");
              },
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: ThemeData(platform: TargetPlatform.iOS),
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
  return sessionContext;
}

void _push({required BuildContext session, required bool opaque}) {
  // ignore: no_slop_linter/avoid_navigator_of, mirrors the transient routes pushed over the session page
  Navigator.of(session).push(
    PageRouteBuilder<void>(
      opaque: opaque,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => const SizedBox.expand(),
    ),
  );
}
