import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/widgets/desktop_page_toolbar.dart";
import "package:sesori_desktop/features/sessions/desktop_session_list_screen.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionListCubit() extends MockCubit<SessionListState> implements SessionListCubit;

class _MockConnectionOverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit;

void main() {
  late _MockSessionListCubit cubit;
  late _MockConnectionOverlayCubit overlay;
  late PendingSessionArchiveCubit archives;

  setUp(() {
    cubit = _MockSessionListCubit();
    when(() => cubit.toggleArchived()).thenReturn(null);
    when(() => cubit.projectId).thenReturn("project-1");
    when(() => cubit.refreshSessions()).thenAnswer((_) async => true);
    overlay = _MockConnectionOverlayCubit();
    when(() => overlay.state).thenReturn(const ConnectionOverlayState.hidden(connected: true));
  });

  Future<void> pumpPage({required WidgetTester tester, required SessionListFilter filter}) async {
    when(() => cubit.state).thenReturn(
      SessionListState.loaded(
        sessions: [
          testSession(id: "s1", title: "Fix the build", updatedAt: DateTime.now().millisecondsSinceEpoch),
          testSession(id: "s2", title: "Unread one", updatedAt: DateTime.now().millisecondsSinceEpoch, unseen: true),
        ],
        filter: filter,
        activeSessionIds: const {},
        baseBranch: null,
        repoSlug: null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PregoInteractionScope(
          mode: PregoInteractionMode.pointer,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<SessionListCubit>.value(value: cubit),
              BlocProvider<ConnectionOverlayCubit>.value(value: overlay),
              BlocProvider(create: (_) => archives = PendingSessionArchiveCubit(repository: MockSessionRepository())),
            ],
            child: DesktopSessionListScreen(
              projectName: "sesori",
              onSessionTap: ({required session}) {},
              actionDispatcher: const SessionListActionDispatcher(
                deleteConfirmation: SessionDeleteConfirmation.sheet,
                onSessionArchived: null,
                onSessionDeleted: null,
                onSessionMarkedUnread: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("the toolbar names the project and leaves New session to the sidebar", (tester) async {
    await pumpPage(tester: tester, filter: SessionListFilter.active);

    final toolbar = find.byType(DesktopPageToolbar);
    expect(find.descendant(of: toolbar, matching: find.text("sesori")), findsOneWidget);
    expect(find.descendant(of: toolbar, matching: find.text("New session")), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text("Fix the build"), findsOneWidget);
    expect(find.text("Today"), findsOneWidget);
  });

  testWidgets("Archived toggles the cubit and reads as on while archived sessions show", (tester) async {
    await pumpPage(tester: tester, filter: SessionListFilter.active);
    const archived = Key("desktop-project-page-archived");
    expect(tester.widget<PregoButtonsSolid>(find.byKey(archived)).hierarchy, PregoButtonsSolidHierarchy.secondary);

    await tester.tap(find.byKey(archived));
    verify(() => cubit.toggleArchived()).called(1);

    await pumpPage(tester: tester, filter: SessionListFilter.archived);
    expect(tester.widget<PregoButtonsSolid>(find.byKey(archived)).hierarchy, PregoButtonsSolidHierarchy.primary);
  });

  testWidgets("the toolbar's Refresh shows progress until the silent refresh returns", (tester) async {
    final refresh = Completer<bool>();
    when(() => cubit.refreshSessions(waitForPrData: true)).thenAnswer((_) => refresh.future);
    await pumpPage(tester: tester, filter: SessionListFilter.active);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key("desktop-project-page-more")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Refresh sessions"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    refresh.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets("the chips count the loaded list and narrow it locally; Archived hides them", (tester) async {
    await pumpPage(tester: tester, filter: SessionListFilter.active);
    expect(find.text("All · 2"), findsOneWidget);
    expect(find.text("Running · 0"), findsOneWidget);

    await tester.tap(find.text("Unread · 1"));
    await tester.pumpAndSettle();
    expect(find.text("Unread one"), findsOneWidget);
    expect(find.text("Fix the build"), findsNothing);

    await tester.tap(find.text("Running · 0"));
    await tester.pumpAndSettle();
    expect(find.text("No sessions match this filter"), findsOneWidget);

    await pumpPage(tester: tester, filter: SessionListFilter.archived);
    expect(find.byKey(const Key("session-list-filter-all")), findsNothing);
    expect(find.text("Fix the build"), findsOneWidget);
  });

  testWidgets("a session being archived leaves the list and the counts at once, and Undo brings it back", (
    tester,
  ) async {
    await pumpPage(tester: tester, filter: SessionListFilter.active);

    archives.archive(
      session: testSession(id: "s1", title: "Fix the build"),
      deleteWorktree: false,
    );
    await tester.pumpAndSettle();
    expect(find.text("Fix the build"), findsNothing);
    expect(find.text("All · 1"), findsOneWidget);

    archives.undo();
    await tester.pumpAndSettle();
    expect(find.text("Fix the build"), findsOneWidget);
    expect(find.text("All · 2"), findsOneWidget);
  });
}
