import "package:bloc_test/bloc_test.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_list/session_list_panel.dart";
import "package:sesori_mobile/features/session_list/session_list_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// Long-pressing a session row opens its actions in an anchored popover
/// ([PregoAnchorMenu]) rather than a bottom sheet, so the row stays visible
/// beside the menu — the same treatment the project list gets. The entries come
/// from the real [SessionListActionDispatcher], so this covers the wiring from
/// the row all the way to the actions it dispatches.
class _MockSessionListCubit extends MockCubit<SessionListState> implements SessionListCubit {}

void main() {
  late _MockSessionListCubit cubit;

  setUp(() {
    cubit = _MockSessionListCubit();
  });

  /// Renders the real panel with the real action dispatcher behind the rows.
  Future<void> pumpPanel(WidgetTester tester, {required Session session}) async {
    when(() => cubit.state).thenReturn(
      SessionListState.loaded(sessions: [session], baseBranch: null),
    );

    const dispatcher = SessionListActionDispatcher();

    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>(
        create: (_) => StubConnectionOverlayCubit(),
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: BlocProvider<SessionListCubit>.value(
              value: cubit,
              child: SessionListPanel(
                projectName: "Project One",
                onNewSession: () {},
                onSessionTap: (_) {},
                sessionMenuEntries: (BuildContext context, Session session) =>
                    dispatcher.sessionMenuEntries(context: context, session: session),
                onSessionSwipe: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> longPressTile(WidgetTester tester, {required String title}) async {
    await tester.longPress(find.widgetWithText(ListTile, title));
    await tester.pumpAndSettle();
  }

  testWidgets("long-pressing a session opens its actions in an anchored menu, not a bottom sheet", (tester) async {
    final session = testSession(title: "My Session");

    await pumpPanel(tester, session: session);

    expect(find.text("Rename"), findsNothing);

    await longPressTile(tester, title: "My Session");

    // Every action lands in the flat anchored panel's InkWell rows…
    expect(find.widgetWithText(InkWell, "Rename"), findsOneWidget);
    expect(find.widgetWithText(InkWell, "Mark as unread"), findsOneWidget);
    expect(find.widgetWithText(InkWell, "Archive"), findsOneWidget);
    expect(find.widgetWithText(InkWell, "Delete"), findsOneWidget);
    expect(find.byType(PregoBottomSheet), findsNothing);

    // …and the row it is anchored to stays on screen behind the menu.
    expect(find.widgetWithText(ListTile, "My Session"), findsOneWidget);
  });

  testWidgets("right-clicking a session opens the same anchored menu", (tester) async {
    final session = testSession(title: "My Session");

    await pumpPanel(tester, session: session);

    // The mouse counterpart of the long-press, for the desktop app.
    await tester.tap(find.widgetWithText(ListTile, "My Session"), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InkWell, "Rename"), findsOneWidget);
    expect(find.widgetWithText(InkWell, "Delete"), findsOneWidget);
  });

  testWidgets("Delete is the only entry tinted as destructive", (tester) async {
    final session = testSession(title: "My Session");

    await pumpPanel(tester, session: session);
    await longPressTile(tester, title: "My Session");

    // Archiving is reversible and Delete is not, so only Delete shouts. If every
    // row were tinted, none of them would carry a warning.
    final error = PregoDesignSystem.light.colors.fgErrorPrimary;
    expect(tester.widget<Text>(find.text("Delete")).style?.color, equals(error));
    expect(tester.widget<Text>(find.text("Archive")).style?.color, isNot(equals(error)));
  });

  testWidgets("Mark as unread dismisses the menu and marks the session", (tester) async {
    final session = testSession(title: "My Session");
    when(() => cubit.markSessionSeen(sessionId: any(named: "sessionId"), read: any(named: "read"))).thenAnswer(
      (_) async {},
    );

    await pumpPanel(tester, session: session);
    await longPressTile(tester, title: "My Session");

    await tester.tap(find.widgetWithText(InkWell, "Mark as unread"));
    await tester.pumpAndSettle();

    verify(() => cubit.markSessionSeen(sessionId: session.id, read: false)).called(1);
    expect(find.text("Mark as unread"), findsNothing);
  });

  testWidgets("an archived session offers Unarchive instead of Archive", (tester) async {
    final session = testSession(title: "Old Session").copyWith(
      time: const SessionTime(created: 1700000000000, updated: 1700000000000, archived: 1700000001000),
    );

    await pumpPanel(tester, session: session);
    await longPressTile(tester, title: "Old Session");

    expect(find.widgetWithText(InkWell, "Unarchive"), findsOneWidget);
    expect(find.widgetWithText(InkWell, "Archive"), findsNothing);
  });

  testWidgets("tapping outside dismisses the menu without acting on the session", (tester) async {
    final session = testSession(title: "My Session");

    await pumpPanel(tester, session: session);
    await longPressTile(tester, title: "My Session");

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text("Delete"), findsNothing);
    verifyNever(
      () => cubit.markSessionSeen(sessionId: any(named: "sessionId"), read: any(named: "read")),
    );
  });
}
