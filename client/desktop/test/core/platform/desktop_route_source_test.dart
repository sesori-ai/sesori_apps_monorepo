import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_route_source.dart";

void main() {
  testWidgets("reports the desktop router's initial module-core route", (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRouteDef.splash.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRouteDef.splash.path,
          builder: (BuildContext context, GoRouterState state) => const SizedBox.shrink(),
        ),
      ],
    );
    final DesktopRouteSource source = DesktopRouteSource.test(router: router);
    addTearDown(source.onDispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(source.currentRouteStream.value, AppRouteDef.splash);
    expect(source.currentLocation, AppRouteDef.splash.path);
  });
}
