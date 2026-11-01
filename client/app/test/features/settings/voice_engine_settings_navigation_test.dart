import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:theme_prego/module_prego.dart";

class _MockVoiceModeRepository() extends Mock implements VoiceModeRepository;

void main() {
  testWidgets("the voice engine route opens the picker and Back returns to Settings", (tester) async {
    final repository = _MockVoiceModeRepository();
    when(repository.loadEngine).thenAnswer((_) async {});
    when(() => repository.engine).thenReturn(VoiceEngine.device);
    getIt.registerSingleton<VoiceModeRepository>(repository);
    addTearDown(() => getIt.unregister<VoiceModeRepository>());
    final settingsRoute = buildAppRoutesForTesting()
        .whereType<ShellRoute>()
        .single
        .routes
        .whereType<GoRoute>()
        .singleWhere((route) => route.path == AppRouteDef.settings.path);
    final router = GoRouter(
      initialLocation: AppRouteDef.settings.path,
      routes: [
        GoRoute(
          path: AppRouteDef.settings.path,
          routes: settingsRoute.routes,
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push<void>(const AppRoute.settingsVoiceEngine().buildPath()),
              child: const Text("Open voice engine"),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: buildPregoThemeData(brightness: Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Open voice engine"));
    await tester.pumpAndSettle();

    expect(find.byType(VoiceEngineSettingsView), findsOneWidget);

    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text("Open voice engine"), findsOneWidget);
  });
}
