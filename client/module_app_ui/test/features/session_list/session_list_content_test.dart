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

class _MockSessionListCubit() extends MockCubit<SessionListState> implements SessionListCubit;

void main() {
  late _MockSessionListCubit cubit;

  setUp(() {
    cubit = _MockSessionListCubit();
  });

  Future<void> pumpList({
    required WidgetTester tester,
    required List<Session> sessions,
    required SessionListFilter filter,
    Map<String, SessionActivityInfo> activityBySessionId = const {},
  }) async {
    when(() => cubit.state).thenReturn(
      SessionListState.loaded(
        sessions: sessions,
        filter: filter,
        activeSessionIds: activityBySessionId,
        baseBranch: null,
        repoSlug: null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SessionListCubit>.value(
          value: cubit,
          child: const Material(
            child: SizedBox(
              height: 1000,
              child: CustomScrollView(
                slivers: [
                  SessionListContent(
                    projectName: null,
                    onSessionTap: null,
                    actionDispatcher: SessionListActionDispatcher(onSessionDeleted: null),
                    archivedEmptyState: SessionArchivedEmptyState(artwork: null),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  DateTime atStartOfDay({required DateTime date}) => DateTime(date.year, date.month, date.day);

  double topOf({required WidgetTester tester, required String text}) => tester.getTopLeft(find.text(text)).dy;

  testWidgets("regular sessions show running first, then updated-time buckets", (tester) async {
    final now = DateTime.now();
    final today = atStartOfDay(date: now).add(const Duration(hours: 12));
    final yesterday = atStartOfDay(date: now).subtract(const Duration(days: 1)).add(const Duration(hours: 12));
    final running = testSession(id: "running", title: "Running task", updatedAt: today.millisecondsSinceEpoch);
    final idleToday = testSession(id: "idle-today", title: "Today task", updatedAt: today.millisecondsSinceEpoch);
    final idleTodayAgain = testSession(
      id: "idle-today-again",
      title: "Today task again",
      updatedAt: today.millisecondsSinceEpoch,
    );
    final awaiting = testSession(id: "awaiting", title: "Awaiting task", updatedAt: yesterday.millisecondsSinceEpoch);

    await pumpList(
      tester: tester,
      sessions: [running, idleToday, idleTodayAgain, awaiting],
      filter: SessionListFilter.active,
      activityBySessionId: {
        "running": const SessionActivityInfo(
          mainAgentRunning: true,
          lastUserActivityAt: null,
          updatedAt: null,
        ),
        "awaiting": const SessionActivityInfo(
          awaitingInput: true,
          lastUserActivityAt: null,
          updatedAt: null,
        ),
      },
    );

    expect(find.text("Running"), findsOneWidget);
    expect(find.text("Today"), findsOneWidget);
    expect(find.text("Yesterday"), findsOneWidget);
    expect(topOf(tester: tester, text: "Running"), lessThan(topOf(tester: tester, text: "Running task")));
    expect(topOf(tester: tester, text: "Running task"), lessThan(topOf(tester: tester, text: "Today")));
    expect(topOf(tester: tester, text: "Today"), lessThan(topOf(tester: tester, text: "Today task")));
    expect(topOf(tester: tester, text: "Today task"), lessThan(topOf(tester: tester, text: "Today task again")));
    expect(topOf(tester: tester, text: "Today task again"), lessThan(topOf(tester: tester, text: "Yesterday")));
    expect(topOf(tester: tester, text: "Yesterday"), lessThan(topOf(tester: tester, text: "Awaiting task")));
    expect(find.text("Awaiting input"), findsOneWidget);
  });

  testWidgets("archived sessions keep archive-time buckets", (tester) async {
    final now = DateTime.now();
    final today = atStartOfDay(date: now).add(const Duration(hours: 12));
    final yesterday = atStartOfDay(date: now).subtract(const Duration(days: 1)).add(const Duration(hours: 12));
    final archivedToday = testSession(
      id: "archived-today",
      title: "Archived today",
      updatedAt: yesterday.millisecondsSinceEpoch,
      archivedAt: today,
    );
    final archivedTodayAgain = testSession(
      id: "archived-today-again",
      title: "Archived today again",
      updatedAt: yesterday.millisecondsSinceEpoch,
      archivedAt: today,
    );
    final archivedYesterday = testSession(
      id: "archived-yesterday",
      title: "Archived yesterday",
      updatedAt: today.millisecondsSinceEpoch,
      archivedAt: yesterday,
    );

    await pumpList(
      tester: tester,
      sessions: [archivedToday, archivedTodayAgain, archivedYesterday],
      filter: SessionListFilter.archived,
      activityBySessionId: {
        "archived-today": const SessionActivityInfo(
          mainAgentRunning: true,
          lastUserActivityAt: null,
          updatedAt: null,
        ),
      },
    );

    expect(find.text("Running"), findsNothing);
    expect(find.text("Today"), findsOneWidget);
    expect(find.text("Yesterday"), findsOneWidget);
    expect(topOf(tester: tester, text: "Today"), lessThan(topOf(tester: tester, text: "Archived today")));
    expect(
      topOf(tester: tester, text: "Archived today"),
      lessThan(topOf(tester: tester, text: "Archived today again")),
    );
    expect(topOf(tester: tester, text: "Archived today again"), lessThan(topOf(tester: tester, text: "Yesterday")));
    expect(topOf(tester: tester, text: "Yesterday"), lessThan(topOf(tester: tester, text: "Archived yesterday")));
  });

  for (final filter in [SessionListFilter.active, SessionListFilter.archived]) {
    testWidgets("${filter.name} sessions label missing timestamps without inventing a date", (tester) async {
      final session = testSession(id: "missing-time", title: "Missing timestamp").copyWith(time: null);

      await pumpList(tester: tester, sessions: [session], filter: filter);

      expect(find.text("Unknown date"), findsOneWidget);
      expect(find.textContaining("1970"), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
