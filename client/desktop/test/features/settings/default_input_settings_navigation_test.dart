import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:theme_prego/module_prego.dart";

class _MockChatInputModeStore() extends Mock implements ChatInputModeStore;

void main() {
  for (final opener in ["/projects", "/projects/p1/sessions/s1"]) {
    testWidgets("Default input Back returns Settings and X returns $opener", (tester) async {
      final cubit = ChatInputModeCubit(store: _MockChatInputModeStore(), initialMode: ChatInputMode.textFirst);
      addTearDown(cubit.close);
      final navigatorKey = GlobalKey<NavigatorState>();
      final product = buildDesktopRoutes().single as ShellRoute;
      final detailRoute = product.routes.whereType<GoRoute>().singleWhere(
        (route) => route.path == AppRouteDef.settingsDefaultInput.path,
      );
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: opener,
        routes: [
          GoRoute(
            path: opener,
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push<void>(const AppRoute.settings().buildPath()),
                child: const Text("Open settings"),
              ),
            ),
          ),
          GoRoute(
            path: AppRouteDef.settings.path,
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push<void>(const AppRoute.settingsDefaultInput().buildPath()),
                child: const Text("Open default input"),
              ),
            ),
          ),
          detailRoute,
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildPregoThemeData(brightness: Brightness.dark),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("Open settings"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Open default input"));
      await tester.pumpAndSettle();
      expect(find.byType(DefaultInputSettingsView), findsOneWidget);
      await tester.tap(find.byIcon(TablerRegular.chevron_left));
      await tester.pumpAndSettle();
      expect(GoRouterState.of(tester.element(find.text("Open default input"))).uri.path, AppRouteDef.settings.path);
      expect(find.text("Open default input"), findsOneWidget);
      await tester.tap(find.text("Open default input"));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(TablerRegular.x));
      await tester.pumpAndSettle();
      expect(GoRouterState.of(tester.element(find.text("Open settings"))).uri.path, opener);
      expect(find.text("Open settings"), findsOneWidget);
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
