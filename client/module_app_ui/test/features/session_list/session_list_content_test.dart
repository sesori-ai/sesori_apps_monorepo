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
    SessionListQuickFilter quickFilter = SessionListQuickFilter.all,
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
          child: Material(
            child: SizedBox(
              height: 1000,
              child: CustomScrollView(
                slivers: [
                  SessionListContent(
                    projectName: null,
                    onSessionTap: null,
                    actionDispatcher: const SessionListActionDispatcher(
                      deleteConfirmation: SessionDeleteConfirmation.sheet,
                      onSessionArchived: null,
                      onSessionDeleted: null,
                      onSessionMarkedUnread: null,
                    ),
                    archivedEmptyState: const SessionArchivedEmptyState(artwork: null),
                    quickFilter: quickFilter,
                    query: "",
                    hiddenSessionIds: const {},
                    launchRows: LaunchRows.none,
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

    expect(find.text("Running"), findsNothing);
    expect(find.text("Today"), findsOneWidget);
    expect(find.text("Yesterday"), findsOneWidget);
    expect(topOf(tester: tester, text: "Today"), lessThan(topOf(tester: tester, text: "Running task")));
    expect(topOf(tester: tester, text: "Running task"), lessThan(topOf(tester: tester, text: "Today task")));
    expect(topOf(tester: tester, text: "Today task"), lessThan(topOf(tester: tester, text: "Today task again")));
    expect(topOf(tester: tester, text: "Today task again"), lessThan(topOf(tester: tester, text: "Yesterday")));
    expect(topOf(tester: tester, text: "Yesterday"), lessThan(topOf(tester: tester, text: "Awaiting task")));
    expect(find.text("Waiting"), findsOneWidget);
  });

  testWidgets("a session running since yesterday still leads Today", (tester) async {
    final now = DateTime.now();
    final yesterday = atStartOfDay(date: now).subtract(const Duration(days: 1)).add(const Duration(hours: 12));
    final today = atStartOfDay(date: now).add(const Duration(hours: 12));
    // Running since yesterday: it still leads Today rather than opening a Yesterday bucket.
    final running = testSession(id: "running", title: "Running task", updatedAt: yesterday.millisecondsSinceEpoch);
    final idleToday = testSession(id: "idle-today", title: "Today task", updatedAt: today.millisecondsSinceEpoch);

    await pumpList(
      tester: tester,
      sessions: [running, idleToday],
      filter: SessionListFilter.active,
      activityBySessionId: {
        "running": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
      },
    );

    expect(find.text("Running"), findsNothing);
    expect(find.text("Today"), findsOneWidget);
    expect(find.text("Yesterday"), findsNothing);
    expect(topOf(tester: tester, text: "Today"), lessThan(topOf(tester: tester, text: "Running task")));
    expect(topOf(tester: tester, text: "Running task"), lessThan(topOf(tester: tester, text: "Today task")));
  });

  testWidgets("shown archived rows sit under their update date, as the list sorts", (tester) async {
    final now = DateTime.now();
    final today = atStartOfDay(date: now).add(const Duration(hours: 12));
    final yesterday = atStartOfDay(date: now).subtract(const Duration(days: 1)).add(const Duration(hours: 12));
    final activeToday = testSession(id: "active-today", title: "Active today", updatedAt: today.millisecondsSinceEpoch);
    final activeYesterday = testSession(
      id: "active-yesterday",
      title: "Active yesterday",
      updatedAt: yesterday.millisecondsSinceEpoch,
    );
    // Archived today, but last updated before the active row above it.
    final archived = testSession(
      id: "archived",
      title: "Archived",
      updatedAt: yesterday.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      archivedAt: today,
    );

    await pumpList(
      tester: tester,
      sessions: [activeToday, activeYesterday, archived],
      filter: SessionListFilter.all,
    );

    expect(find.text("Today"), findsOneWidget);
    expect(find.text("Yesterday"), findsOneWidget);
    expect(topOf(tester: tester, text: "Today"), lessThan(topOf(tester: tester, text: "Active today")));
    expect(topOf(tester: tester, text: "Active today"), lessThan(topOf(tester: tester, text: "Yesterday")));
    expect(topOf(tester: tester, text: "Yesterday"), lessThan(topOf(tester: tester, text: "Active yesterday")));
    expect(topOf(tester: tester, text: "Active yesterday"), lessThan(topOf(tester: tester, text: "Archived")));
  });

  testWidgets("archiving the first session of a group keeps its heading in place", (tester) async {
    final today = atStartOfDay(date: DateTime.now()).add(const Duration(hours: 12));
    final first = testSession(id: "first", title: "First task", updatedAt: today.millisecondsSinceEpoch);
    final second = testSession(id: "second", title: "Second task", updatedAt: today.millisecondsSinceEpoch);

    await pumpList(tester: tester, sessions: [first, second], filter: SessionListFilter.active);
    final heading = tester.element(find.text("Today"));
    final headingTop = topOf(tester: tester, text: "Today");

    // Mid-transition, only the archived row is closing: the heading is the
    // same element, alone and unmoved.
    await pumpList(tester: tester, sessions: [second], filter: SessionListFilter.active);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Today"), findsOneWidget);
    expect(tester.element(find.text("Today")), same(heading));
    expect(topOf(tester: tester, text: "Today"), headingTop);
    await tester.pumpAndSettle();

    // Undo re-inserts the row under the same heading.
    await pumpList(tester: tester, sessions: [first, second], filter: SessionListFilter.active);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text("Today"), findsOneWidget);
    expect(tester.element(find.text("Today")), same(heading));
    await tester.pumpAndSettle();
    expect(topOf(tester: tester, text: "First task"), lessThan(topOf(tester: tester, text: "Second task")));
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
