import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart" show Session;
import "package:theme_prego/module_prego.dart";

class _MockSessionListCubit() extends MockCubit<SessionListState> implements SessionListCubit;

void main() {
  late StreamController<SessionListState> sessionStates;
  late SessionLaunchRepository launches;
  late int opened;
  final now = DateTime.now().millisecondsSinceEpoch;
  final earlier = testSession(id: "earlier", title: "Earlier work", updatedAt: now - 60000);
  final created = testSession(id: "created", title: "Fix the bug", updatedAt: now);

  SessionListState loaded({required List<Session> sessions}) =>
      SessionListState.loaded(sessions: sessions, baseBranch: null, repoSlug: null);

  Future<void> pumpList(
    WidgetTester tester, {
    required List<Session> sessions,
    PregoInteractionMode mode = PregoInteractionMode.touch,
    double textScale = 1,
    bool reduceMotion = false,
  }) async {
    sessionStates = StreamController<SessionListState>();
    addTearDown(sessionStates.close);
    final cubit = _MockSessionListCubit();
    whenListen(cubit, sessionStates.stream, initialState: loaded(sessions: sessions));
    when(() => cubit.projectId).thenReturn("project-1");
    launches = inMemorySessionLaunchRepository();
    opened = 0;
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: "/",
              builder: (context, _) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
                child: PregoInteractionScope(
                  mode: mode,
                  child: MultiBlocProvider(
                    providers: [
                      BlocProvider<SessionListCubit>.value(value: cubit),
                      BlocProvider(
                        create: (_) => PendingSessionArchiveCubit(
                          cleanupService: SessionCleanupService(repository: MockSessionRepository()),
                        ),
                      ),
                      BlocProvider(
                        create: (_) => SessionLaunchCubit(
                          launchService: inMemorySessionLaunchService(launchRepository: launches),
                        ),
                      ),
                    ],
                    child: Scaffold(
                      body: CustomScrollView(
                        slivers: [
                          SessionListFilteredContent(
                            projectName: "Sesori",
                            selectedSessionId: null,
                            onSessionTap: ({required session}) => opened++,
                            actionDispatcher: const SessionListActionDispatcher(
                              deleteConfirmation: SessionDeleteConfirmation.sheet,
                              onSessionArchived: null,
                              onSessionDeleted: null,
                              onSessionMarkedUnread: null,
                            ),
                            archivedEmptyState: const SizedBox.shrink(),
                            searchable: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  // The launching row's sparkle never settles, so this pumps fixed frames: one
  // for the updates in flight to build, one for the transitions they start to
  // take their first tick, then past those transitions.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> startLaunch(WidgetTester tester) async {
    launches.start(
      launchId: "launch-1",
      projectId: "project-1",
      pluginId: "claude",
      startedAt: DateTime.now(),
      projectName: "Sesori",
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Fix the bug\nin the parser"),
        attachments: const [],
      ),
    );
    await settle(tester);
  }

  final launchRow = find.byType(PendingSessionLaunchTile);
  double rowBelowTop(WidgetTester tester) => tester.getTopLeft(find.text("Earlier work")).dy;

  testWidgets("a launch leads the list as one row outside the counts, then settles in place into its session", (
    tester,
  ) async {
    await pumpList(tester, sessions: [earlier]);
    final belowBefore = rowBelowTop(tester);

    await startLaunch(tester);
    expect(launchRow, findsOneWidget);
    expect(find.text("Fix the bug"), findsOneWidget);
    expect(find.textContaining("Creating…"), findsOneWidget);
    expect(find.text("All · 1"), findsOneWidget, reason: "a launch is not a session yet");
    final below = rowBelowTop(tester);
    expect(below, greaterThan(tester.getBottomLeft(launchRow).dy - 1), reason: "the launch row leads");
    expect(below, greaterThan(belowBefore));

    // The reply names the session before the list has it: still one row.
    launches.promote(launchId: "launch-1", session: created);
    await tester.pump();
    expect(launchRow, findsOneWidget);

    sessionStates.add(loaded(sessions: [created, earlier]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(rowBelowTop(tester), below, reason: "the row below never moves while the row swaps");

    await settle(tester);
    expect(launchRow, findsNothing);
    expect(find.text("Fix the bug"), findsOneWidget);
    expect(find.text("All · 2"), findsOneWidget);
    expect(rowBelowTop(tester), below);
  });

  testWidgets("a session out of the row's slot waits for the next sessions update, not a status one", (tester) async {
    await pumpList(tester, sessions: [earlier]);
    await startLaunch(tester);
    launches.promote(launchId: "launch-1", session: created);
    final outOfSlot = [earlier, created];
    sessionStates.add(loaded(sessions: outOfSlot));
    await settle(tester);
    expect(launchRow, findsOneWidget, reason: "the session is not at the head of Today yet");

    sessionStates.add(
      SessionListState.loaded(sessions: outOfSlot, baseBranch: null, repoSlug: null, isRefreshing: true),
    );
    await settle(tester);
    expect(launchRow, findsOneWidget, reason: "a status update keeps the same sessions");

    sessionStates.add(loaded(sessions: [created, earlier]));
    await settle(tester);
    expect(launchRow, findsNothing);
    expect(find.text("Fix the bug"), findsOneWidget);
  });

  testWidgets("with reduced motion the launching row becomes its session at once", (tester) async {
    await pumpList(tester, sessions: [earlier], reduceMotion: true);
    await startLaunch(tester);
    launches.promote(launchId: "launch-1", session: created);
    sessionStates.add(loaded(sessions: [created, earlier]));
    await tester.pump();
    await tester.pump();

    expect(launchRow, findsNothing);
    expect(find.text("Fix the bug"), findsOneWidget);
  });

  testWidgets("a project's first launch shows its row instead of the empty state; search and chips hide it", (
    tester,
  ) async {
    await pumpList(tester, sessions: const []);
    expect(find.byType(SessionEmptyState), findsOneWidget);

    await startLaunch(tester);
    expect(launchRow, findsOneWidget);
    expect(find.byType(SessionEmptyState), findsNothing);
    expect(find.text("All · 0"), findsOneWidget, reason: "the chips are in place for the session it becomes");

    await tester.tap(find.byKey(const Key("session-list-filter-running")));
    await settle(tester);
    expect(launchRow, findsNothing);

    await tester.tap(find.byKey(const Key("session-list-filter-all")));
    await settle(tester);
    await tester.enterText(find.byType(TextField), "parser");
    await settle(tester);
    expect(launchRow, findsNothing);
    expect(find.byType(SessionEmptyState), findsOneWidget);
  });

  testWidgets("tapping a launching row explains it is not ready and opens nothing", (tester) async {
    await pumpList(tester, sessions: [earlier]);
    await startLaunch(tester);

    await tester.tap(launchRow);
    await settle(tester);

    expect(find.text("This session is still being created. You can open it once it's ready."), findsOneWidget);
    expect(opened, 0);
  });

  for (final mode in PregoInteractionMode.values) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets("a launching row is as tall as a session row (${mode.name}, text x$textScale)", (tester) async {
        await pumpList(tester, sessions: [earlier], mode: mode, textScale: textScale);
        await startLaunch(tester);

        expect(tester.getSize(launchRow).height, tester.getSize(find.byType(SessionTile)).height);
      });
    }
  }
}
