import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_list/session_list_panel.dart";
import "package:sesori_mobile/features/session_list/session_list_screen.dart";
import "package:sesori_mobile/features/session_list/session_tile.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// Swiping a session row toward its start edge reveals the delete and archive
/// pills ([PregoSwipeActions]); a full swipe commits the archive. The opposite
/// swipe reveals the mail-style read toggle, committed by a full swipe
/// likewise. The callbacks run through the real [SessionListActionDispatcher],
/// so this covers the wiring from the row to the actions it dispatches; the
/// long-press menu stays the assistive path to the same actions.
///
/// Drag distances assume the 800px default test surface: the trailing strip
/// settles open comfortably past ~200px of drag, the leading one past ~150px,
/// and the full-swipe commit threshold is 480px. ~20px of every drag is spent
/// on touch slop.
class _MockSessionListCubit extends MockCubit<SessionListState> implements SessionListCubit {}

void main() {
  late _MockSessionListCubit cubit;

  setUp(() {
    cubit = _MockSessionListCubit();
  });

  /// Renders the real panel with the real action dispatcher behind the rows.
  /// The swipe callbacks close over a context above the rows, as the screen's
  /// do, so they keep working after an action unmounts its row.
  Future<void> pumpPanel(WidgetTester tester, {required Session session}) async {
    when(() => cubit.state).thenReturn(
      SessionListState.loaded(sessions: [session], baseBranch: null, repoSlug: null),
    );

    const dispatcher = SessionListActionDispatcher();

    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>(
        create: (_) => StubConnectionOverlayCubit(),
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<SessionListCubit>.value(
              value: cubit,
              child: Builder(
                builder: (context) => SessionListPanel(
                  projectName: "Project One",
                  onNewSession: () {},
                  onSessionTap: (_) {},
                  sessionMenuEntries: (BuildContext context, Session session) =>
                      dispatcher.sessionMenuEntries(context: context, session: session),
                  onSessionArchive: (session) => dispatcher.handleSessionArchive(context: context, session: session),
                  onSessionDelete: (session) => dispatcher.handleSessionDelete(context: context, session: session),
                  onSessionToggleUnread: (session) =>
                      dispatcher.handleSessionToggleUnread(context: context, session: session),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(String title) => find.widgetWithText(SessionTile, title);

  /// Swipes the row far enough to settle open; negative [dx] reveals the
  /// trailing pills, positive the read toggle.
  Future<void> swipeOpen(WidgetTester tester, {required String title, required double dx}) async {
    await tester.drag(tile(title), Offset(dx, 0));
    await tester.pumpAndSettle();
  }

  testWidgets("swiping toward the start edge reveals Delete and Archive without acting", (tester) async {
    final session = testSession(title: "My Session");

    await pumpPanel(tester, session: session);

    // Both pills start past the row's end edge, clipped out of view.
    expect(tester.getRect(find.text("Archive")).left, greaterThanOrEqualTo(800));
    expect(tester.getRect(find.text("Delete")).left, greaterThanOrEqualTo(800));

    await swipeOpen(tester, title: "My Session", dx: -220);

    // Delete sits between the content and the archive pill at the row's end.
    final deleteRect = tester.getRect(find.text("Delete"));
    final archiveRect = tester.getRect(find.text("Archive"));
    expect(archiveRect.left, lessThan(800));
    expect(deleteRect.right, lessThan(archiveRect.left));

    // Still the list — the swipe is not a tap — and nothing was acted on.
    expect(tile("My Session"), findsOneWidget);
    verifyNever(
      () => cubit.archiveSession(
        sessionId: any(named: "sessionId"),
        deleteWorktree: any(named: "deleteWorktree"),
        deleteBranch: any(named: "deleteBranch"),
        force: any(named: "force"),
      ),
    );
    verifyNever(
      () => cubit.deleteSession(
        sessionId: any(named: "sessionId"),
        deleteWorktree: any(named: "deleteWorktree"),
        deleteBranch: any(named: "deleteBranch"),
        force: any(named: "force"),
      ),
    );
  });

  testWidgets("the revealed Archive pill archives directly and confirms with the undo snackbar", (tester) async {
    // testSession has no worktree, so Archive skips the confirm sheet and
    // runs directly.
    final session = testSession(title: "My Session");
    when(
      () => cubit.archiveSession(
        sessionId: any(named: "sessionId"),
        deleteWorktree: any(named: "deleteWorktree"),
        deleteBranch: any(named: "deleteBranch"),
        force: any(named: "force"),
      ),
    ).thenAnswer((_) async => true);

    await pumpPanel(tester, session: session);
    await swipeOpen(tester, title: "My Session", dx: -220);

    await tester.tap(find.text("Archive"));
    await tester.pumpAndSettle();

    verify(
      () => cubit.archiveSession(
        sessionId: session.id,
        deleteWorktree: false,
        deleteBranch: false,
        force: false,
      ),
    ).called(1);
    expect(find.text("Session archived"), findsOneWidget);
    expect(find.text("Undo"), findsOneWidget);
  });

  testWidgets("a full swipe archives without touching the pills", (tester) async {
    final session = testSession(title: "My Session");
    when(
      () => cubit.archiveSession(
        sessionId: any(named: "sessionId"),
        deleteWorktree: any(named: "deleteWorktree"),
        deleteBranch: any(named: "deleteBranch"),
        force: any(named: "force"),
      ),
    ).thenAnswer((_) async => true);

    await pumpPanel(tester, session: session);

    await tester.drag(tile("My Session"), const Offset(-520, 0));
    await tester.pumpAndSettle();

    verify(
      () => cubit.archiveSession(
        sessionId: session.id,
        deleteWorktree: false,
        deleteBranch: false,
        force: false,
      ),
    ).called(1);
    expect(find.text("Session archived"), findsOneWidget);
  });

  testWidgets("an archived row's pill reads Unarchive and unarchives on tap", (tester) async {
    final session = testSession(title: "Old Session").copyWith(
      time: const SessionTime(created: 1700000000000, updated: 1700000000000, archived: 1700000001000),
    );
    when(() => cubit.unarchiveSession(any())).thenAnswer((_) async => true);

    await pumpPanel(tester, session: session);
    await swipeOpen(tester, title: "Old Session", dx: -220);

    expect(find.text("Archive"), findsNothing);
    await tester.tap(find.text("Unarchive"));
    await tester.pumpAndSettle();

    verify(() => cubit.unarchiveSession(session.id)).called(1);
    expect(find.text("Session unarchived"), findsOneWidget);
  });

  testWidgets("the Delete pill opens the confirmation sheet for a worktree session without acting", (tester) async {
    final session = testSession(title: "My Session").copyWith(hasWorktree: true);

    await pumpPanel(tester, session: session);
    await swipeOpen(tester, title: "My Session", dx: -220);

    await tester.tap(find.text("Delete"));
    await tester.pumpAndSettle();

    // The same deliberate flow as the menu entry: confirm first, and nothing
    // is deleted until the sheet says so.
    expect(find.text("Delete session?"), findsOneWidget);
    verifyNever(
      () => cubit.deleteSession(
        sessionId: any(named: "sessionId"),
        deleteWorktree: any(named: "deleteWorktree"),
        deleteBranch: any(named: "deleteBranch"),
        force: any(named: "force"),
      ),
    );
  });

  testWidgets("the leading swipe reveals the read toggle, which marks a read row unread", (tester) async {
    final session = testSession(title: "My Session");
    when(
      () => cubit.markSessionSeen(
        sessionId: any(named: "sessionId"),
        read: any(named: "read"),
      ),
    ).thenAnswer((_) async {});

    await pumpPanel(tester, session: session);

    // The toggle starts past the row's start edge, clipped out of view.
    expect(tester.getRect(find.text("Mark as unread")).right, lessThanOrEqualTo(0));

    await swipeOpen(tester, title: "My Session", dx: 200);

    expect(tester.getRect(find.text("Mark as unread")).left, greaterThanOrEqualTo(0));
    await tester.tap(find.text("Mark as unread"));
    await tester.pumpAndSettle();

    verify(() => cubit.markSessionSeen(sessionId: session.id, read: false)).called(1);
  });

  testWidgets("a full leading swipe marks an unseen row read", (tester) async {
    final session = testSession(title: "My Session").copyWith(unseen: true);
    when(
      () => cubit.markSessionSeen(
        sessionId: any(named: "sessionId"),
        read: any(named: "read"),
      ),
    ).thenAnswer((_) async {});

    await pumpPanel(tester, session: session);

    // The unseen row offers the other direction of the toggle.
    expect(find.text("Mark as read"), findsOneWidget);

    await tester.drag(tile("My Session"), const Offset(520, 0));
    await tester.pumpAndSettle();

    verify(() => cubit.markSessionSeen(sessionId: session.id, read: true)).called(1);
  });

  testWidgets("the long-press menu still works after a swipe-open-close cycle", (tester) async {
    final session = testSession(title: "My Session");

    await pumpPanel(tester, session: session);
    await swipeOpen(tester, title: "My Session", dx: -220);

    // The tap lands on the row's close-catcher, not the content underneath.
    await tester.tap(tile("My Session"), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.longPress(tile("My Session"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InkWell, "Rename"), findsOneWidget);
    expect(find.widgetWithText(InkWell, "Delete"), findsOneWidget);
  });
}
