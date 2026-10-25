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
  late FakeAuthSession auth;

  Future<void> pumpAlerts(WidgetTester tester) async {
    launches = inMemorySessionLaunchRepository();
    auth = FakeAuthSession(initialState: const AuthState.initial());
    addTearDown(auth.dispose);
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
                create: (_) => SessionLaunchCubit(
                  launchService: SessionLaunchService(
                    sessionRepository: MockSessionRepository(),
                    launchRepository: launches,
                    feedbackPromptService: FakeFeedbackPromptService(),
                    productAnalyticsService: MockProductAnalyticsService(),
                    selectionTracker: NewSessionSelectionTracker(),
                    authSession: auth,
                  ),
                ),
                child: const SessionLaunchFailureAlerts(navigatorKey: null, child: Scaffold()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void startAndFail({
    required bool leftComposer,
    required String launchId,
    required String? projectName,
  }) {
    launches.start(
      launchId: launchId,
      projectId: "/work/$launchId",
      pluginId: "claude",
      startedAt: DateTime.now(),
      projectName: projectName,
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Fix the bug"),
        attachments: const [],
      ),
    );
    if (leftComposer) launches.releaseHandoff(launchId: launchId);
    launches.fail(launchId: launchId, reason: RemoteFailureReason.serverRejected);
  }

  Future<void> showAlerts(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets("a creation that fails after the composer left names its project once", (tester) async {
    await pumpAlerts(tester);

    startAndFail(leftComposer: true, launchId: "launch-1", projectName: "Sesori");
    await showAlerts(tester);

    expect(find.text("Couldn't create your new session in Sesori"), findsOneWidget);
  });

  testWidgets("creations that fail together share one alert instead of replacing each other", (tester) async {
    await pumpAlerts(tester);

    startAndFail(leftComposer: true, launchId: "launch-1", projectName: "Sesori");
    startAndFail(leftComposer: true, launchId: "launch-2", projectName: "Relay");
    await showAlerts(tester);

    expect(find.text("Couldn't create 2 new sessions in Sesori, Relay"), findsOneWidget);
  });

  testWidgets("a failure in a project without a loaded name names no folder", (tester) async {
    await pumpAlerts(tester);

    startAndFail(leftComposer: true, launchId: "launch-1", projectName: null);
    await showAlerts(tester);

    expect(find.text("Couldn't create your new session"), findsOneWidget);
  });

  testWidgets("signing out takes a shown alert and one still being batched with it", (tester) async {
    await pumpAlerts(tester);
    startAndFail(leftComposer: true, launchId: "launch-1", projectName: "Sesori");
    await showAlerts(tester);
    expect(find.text("Couldn't create your new session in Sesori"), findsOneWidget);

    startAndFail(leftComposer: true, launchId: "launch-2", projectName: "Relay");
    auth.emit(const AuthState.unauthenticated());
    await showAlerts(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining("Couldn't create"), findsNothing);
  });

  testWidgets("a creation that fails while its composer is open shows no alert", (tester) async {
    await pumpAlerts(tester);

    startAndFail(leftComposer: false, launchId: "launch-1", projectName: "Sesori");
    await showAlerts(tester);

    expect(find.textContaining("Couldn't create"), findsNothing);
  });
}
