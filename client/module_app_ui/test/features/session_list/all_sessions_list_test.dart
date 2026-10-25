import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockAllSessionsCubit() extends MockCubit<AllSessionsState> implements AllSessionsCubit;

void main() {
  const project = ProjectSummary(id: "p1", name: "Project One", path: "/p1", time: null);

  AllSessionsState state({
    required String query,
    required List<AllSessionsFailure> failures,
    required List<AllSessionsRow> rows,
  }) => AllSessionsState(
    projectId: null,
    query: query,
    quickFilter: SessionListQuickFilter.all,
    rows: rows,
    counts: const SessionListChipCounts(all: 0, running: 0, unread: 0),
    failures: failures,
    isLoading: false,
    defaultProjectId: null,
  );

  Future<_MockAllSessionsCubit> pumpList(WidgetTester tester, {required AllSessionsState initial}) async {
    final cubit = _MockAllSessionsCubit();
    whenListen(cubit, const Stream<AllSessionsState>.empty(), initialState: initial);
    when(() => cubit.retry(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<AllSessionsCubit>.value(
          value: cubit,
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                AllSessionsList(
                  onSessionTap: ({required row}) {},
                  actionDispatcher: const SessionListActionDispatcher(
                    deleteConfirmation: SessionDeleteConfirmation.sheet,
                    onSessionArchived: null,
                    onSessionDeleted: null,
                    onSessionMarkedUnread: null,
                  ),
                  createActionCubit: ({required projectId, required session}) => throw StateError("no row to act on"),
                  emptyState: const Text("Nothing here"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // A running row's loader never settles.
    await tester.pump();
    return cubit;
  }

  testWidgets("a project that failed to load gets a retry row instead of the empty state", (tester) async {
    final cubit = await pumpList(
      tester,
      initial: state(
        query: "",
        failures: const [AllSessionsFailure(project: project, reason: RemoteFailureReason.networkDown)],
        rows: const [],
      ),
    );
    expect(find.text("Couldn’t load Project One"), findsOneWidget);
    expect(find.text("Nothing here"), findsNothing);
    await tester.tap(find.text("Retry"));
    verify(() => cubit.retry(projectId: "p1")).called(1);
  });

  testWidgets("a query that matches nothing says so instead of the empty state", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "zzz", failures: const [], rows: const []),
    );
    expect(find.text("Nothing here"), findsNothing);
    expect(find.text("No matches"), findsOneWidget);
  });

  testWidgets("archived rows sit under their archive date, as the archived mode sorts", (tester) async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    AllSessionsRow row({
      required String title,
      required DateTime archivedAt,
      required DateTime updatedAt,
      required bool isRunning,
    }) => AllSessionsRow(
      session: testSession(
        id: title,
        title: title,
        updatedAt: updatedAt.millisecondsSinceEpoch,
        archivedAt: archivedAt,
      ),
      project: project,
      isRunning: isRunning,
      isUnseen: false,
      isAwaitingInput: false,
      isRetrying: false,
      backgroundTaskCount: 0,
    );

    await pumpList(
      tester,
      initial: state(
        query: "",
        failures: const [],
        rows: [
          row(title: "Archived today", archivedAt: today, updatedAt: yesterday, isRunning: false),
          // Still running, but an archive lists it by its archive date.
          row(title: "Archived yesterday", archivedAt: yesterday, updatedAt: today, isRunning: true),
        ],
      ),
    );

    double topOf(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text("Today"), findsOneWidget);
    expect(find.text("Yesterday"), findsOneWidget);
    expect(topOf("Today"), lessThan(topOf("Archived today")));
    expect(topOf("Archived today"), lessThan(topOf("Yesterday")));
    expect(topOf("Yesterday"), lessThan(topOf("Archived yesterday")));
  });

  testWidgets("with nothing to show the empty state fills the list", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "", failures: const [], rows: const []),
    );
    expect(find.text("Nothing here"), findsOneWidget);
  });
}
