import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/widgets/desktop_pending_archive_alerts.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:theme_prego/module_prego.dart";

void main() {
  late MockSessionRepository repository;
  late PendingSessionArchiveCubit cubit;
  final session = testSession(id: "s1", title: "Fix the build");

  Future<void> pumpAlerts(WidgetTester tester) async {
    repository = MockSessionRepository();
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The alerts close themselves through the router, as in the app.
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: "/",
              builder: (_, _) => BlocProvider(
                create: (_) => cubit = PendingSessionArchiveCubit(repository: repository),
                child: const DesktopPendingArchiveAlerts(child: Scaffold()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets("offers Undo for as long as the window is open, and Undo sends nothing", (tester) async {
    await pumpAlerts(tester);

    cubit.archive(session: session, deleteWorktree: true);
    await tester.pump();
    await tester.pump(PendingSessionArchiveCubit.undoWindow - const Duration(milliseconds: 500));
    expect(find.text("Session archived"), findsOneWidget);

    await tester.tap(find.text("Undo"));
    await tester.pumpAndSettle();

    expect(cubit.state.window, isA<PendingArchiveIdle>());
    expect(find.text("Session archived"), findsNothing);
    await tester.pump(PendingSessionArchiveCubit.undoWindow);
    verifyNever(
      () => repository.archiveSession(
        sessionId: any(named: "sessionId"),
        deleteWorktree: any(named: "deleteWorktree"),
        force: any(named: "force"),
      ),
    );
  });

  testWidgets("a refused cleanup defaults to keeping the worktree and commits without a second Undo", (tester) async {
    await pumpAlerts(tester);
    const rejection = shared.SessionCleanupRejection(issues: [shared.CleanupIssue.unstagedChanges()]);
    when(() => repository.archiveSession(sessionId: "s1", deleteWorktree: true, force: false)).thenThrow(
      SessionCleanupRejectedException(
        rejection: SessionCleanupRejection(issues: rejection.issues),
        innerError: const SessionCleanupApiRejectedException(rejection: rejection),
      ),
    );
    when(
      () => repository.archiveSession(sessionId: "s1", deleteWorktree: false, force: false),
    ).thenAnswer((_) async => ApiResponse.success(session));

    cubit.archive(session: session, deleteWorktree: true);
    await tester.pump();
    await tester.pump(PendingSessionArchiveCubit.undoWindow);
    await tester.pumpAndSettle();

    final keep = find.widgetWithText(FilledButton, "Archive, keep worktree");
    expect(tester.widget<FilledButton>(keep).autofocus, isTrue);
    expect(find.text("Delete it anyway"), findsOneWidget);
    await tester.tap(keep);
    await tester.pumpAndSettle();

    verify(() => repository.archiveSession(sessionId: "s1", deleteWorktree: false, force: false)).called(1);
    expect(cubit.state.window, isA<PendingArchiveIdle>());
    expect(cubit.state.hiddenIds, {"s1"});
  });

  testWidgets("any other failure says so", (tester) async {
    await pumpAlerts(tester);
    when(
      () => repository.archiveSession(sessionId: "s1", deleteWorktree: true, force: false),
    ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

    cubit.archive(session: session, deleteWorktree: true);
    await tester.pump();
    await tester.pump(PendingSessionArchiveCubit.undoWindow);
    await tester.pump();

    expect(find.text("Failed to archive session"), findsOneWidget);
    expect(cubit.state.hiddenIds, isEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });
}
