import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late SessionLaunchRepository launches;

  Future<void> pumpAlerts(WidgetTester tester) async {
    launches = inMemorySessionLaunchRepository();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: "/",
              builder: (_, _) => BlocProvider(
                create: (_) =>
                    SessionLaunchCubit(launchService: inMemorySessionLaunchService(launchRepository: launches)),
                child: const SessionLaunchFailureAlerts(navigatorKey: null, child: Scaffold()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void startAndFail({required bool leftComposer}) {
    launches.start(
      launchId: "launch-1",
      projectId: "/work/sesori",
      pluginId: "claude",
      startedAt: DateTime.now(),
      projectName: "Sesori",
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Fix the bug"),
        attachments: const [],
      ),
    );
    if (leftComposer) launches.releaseHandoff(launchId: "launch-1");
    launches.fail(launchId: "launch-1", reason: RemoteFailureReason.serverRejected);
  }

  testWidgets("a creation that fails after the composer left names its project once", (tester) async {
    await pumpAlerts(tester);

    startAndFail(leftComposer: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Couldn't create your new session in Sesori"), findsOneWidget);
  });

  testWidgets("a creation that fails while its composer is open shows no alert", (tester) async {
    await pumpAlerts(tester);

    startAndFail(leftComposer: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining("Couldn't create your new session"), findsNothing);
  });
}
