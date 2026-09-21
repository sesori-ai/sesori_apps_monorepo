import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionListCubit() extends MockCubit<SessionListState> implements SessionListCubit;

void main() {
  late _MockSessionListCubit cubit;
  late PendingSessionArchiveCubit archives;
  late List<String> archived;
  final session = testSession(id: "s1", title: "Fix the build");

  setUp(() {
    cubit = _MockSessionListCubit();
    archived = [];
    archives = PendingSessionArchiveCubit(repository: MockSessionRepository());
    when(() => cubit.retainActionScope()).thenReturn(() {});
  });

  Future<void> pumpArchiveButton({
    required WidgetTester tester,
    required bool running,
  }) async {
    when(() => cubit.state).thenReturn(
      SessionListState.loaded(
        sessions: [session],
        filter: SessionListFilter.active,
        activeSessionIds: {
          if (running)
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
        },
        baseBranch: null,
        repoSlug: null,
      ),
    );
    final dispatcher = SessionListActionDispatcher(
      deleteConfirmation: SessionDeleteConfirmation.sheet,
      onSessionArchived: ({required context, required sessionId}) => archived.add(sessionId),
      onSessionDeleted: null,
      onSessionMarkedUnread: null,
    );
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
              builder: (_, _) => MultiBlocProvider(
                providers: [
                  BlocProvider<SessionListCubit>.value(value: cubit),
                  BlocProvider.value(value: archives),
                ],
                child: Material(
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => dispatcher.handleSessionArchive(context: context, session: session),
                      child: const Text("go"),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text("go"));
    await tester.pumpAndSettle();
  }

  testWidgets("an idle session enters the Undo window without being asked about", (tester) async {
    await pumpArchiveButton(tester: tester, running: false);
    expect(archived, ["s1"]);
    expect(archives.state.hiddenIds, {"s1"});
    // Closing inside the window cancels its timer and sends nothing.
    await archives.close();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets("a running session is asked about first, and Cancel archives nothing", (tester) async {
    await pumpArchiveButton(tester: tester, running: true);
    expect(find.text("Archive a running session?"), findsOneWidget);
    expect(archives.state.hiddenIds, isEmpty);

    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();
    expect(archives.state.hiddenIds, isEmpty);

    await tester.tap(find.text("go"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, "Archive"));
    await tester.pumpAndSettle();
    expect(archived, ["s1"]);
    expect(archives.state.hiddenIds, {"s1"});
    // Closing inside the window cancels its timer and sends nothing.
    await archives.close();
  });
}
