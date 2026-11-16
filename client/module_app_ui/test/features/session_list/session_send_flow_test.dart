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
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionActionsCubit() extends MockCubit<void> implements SessionActionsCubit;

class _MockSearchCubit() extends MockCubit<SessionSearchState> implements SessionSearchCubit;

class _MockWindow() extends Mock implements SessionWindowService;

class _MockInventory() extends Mock implements ProjectInventoryService;

void main() {
  final project = testProjectSummary(id: "p1", name: "demo-app", path: "/work/demo-app");
  final target = testSession(id: "target", title: "Idle chat");
  final source = testSession(id: "source", title: "Source chat");

  late _MockSessionActionsCubit actions;
  late PendingSessionArchiveCubit archives;
  late List<String> archived;

  /// Whether the page that opened the send is still showing.
  late ValueNotifier<bool> onPage;

  setUp(() {
    actions = _MockSessionActionsCubit();
    archives = PendingSessionArchiveCubit(cleanupService: SessionCleanupService(repository: MockSessionRepository()));
    archived = [];
    onPage = ValueNotifier(true);
    when(() => actions.setArchiveAfterSend(value: any(named: "value"))).thenAnswer((_) async {});
  });

  tearDown(() => onPage.dispose());

  /// Opens the send sheet for [sending] from its menu entry, with the switch
  /// remembered as [remembered].
  Future<void> openSheet({required WidgetTester tester, required Session sending, required bool remembered}) async {
    when(() => actions.archiveAfterSend()).thenAnswer((_) async => remembered);
    final search = _MockSearchCubit();
    whenListen(
      search,
      const Stream<SessionSearchState>.empty(),
      initialState: SessionSearchState(
        matches: [(session: target, project: project, running: null)],
        isSearching: false,
      ),
    );
    when(() => search.setQuery(query: any(named: "query"))).thenReturn(null);
    final dispatcher = SessionListActionDispatcher(
      deleteConfirmation: SessionDeleteConfirmation.sheet,
      onSessionArchived: ({required context, required sessionId}) => archived.add(sessionId),
      onSessionDeleted: null,
      onSessionMarkedUnread: null,
      openSession: ({required projectId, required projectName, required session}) {},
      createSessionSearch: ({required window, required projectInventory, required excludedSessionId}) => search,
    );
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<SessionWindowService>.value(value: _MockWindow()),
          RepositoryProvider<ProjectInventoryService>.value(value: _MockInventory()),
        ],
        child: BlocProvider.value(
          value: archives,
          child: PregoInteractionScope(
            mode: PregoInteractionMode.touch,
            child: MaterialApp.router(
              theme: buildPregoThemeData(brightness: Brightness.light),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: "/",
                    builder: (_, _) => PendingArchiveAlerts(
                      navigatorKey: null,
                      child: Scaffold(
                        body: ValueListenableBuilder(
                          valueListenable: onPage,
                          builder: (_, showing, _) => showing
                              ? Builder(
                                  builder: (context) => TextButton(
                                    onPressed: () => dispatcher
                                        .sessionMenuEntries(
                                          context: context,
                                          actions: actions,
                                          session: sending,
                                          isRunning: false,
                                          readEntry: const SessionReadMenuNone(),
                                          surfaceEntries: const [],
                                        )
                                        .whereType<PregoMenuItem>()
                                        .firstWhere((entry) => entry.title == "Send to another session…")
                                        .onTap(),
                                    child: const Text("menu"),
                                  ),
                                )
                              : const SizedBox(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("menu"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("send_session_target")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Idle chat"));
    await tester.pumpAndSettle();
  }

  void answerSend(Future<SendToSessionResult> Function() answer) => when(
    () => actions.sendToSession(sourceSessionId: "source", sourcePluginId: source.pluginId, targetSessionId: "target"),
  ).thenAnswer((_) => answer());

  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key("send_session_send")));
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester) => tester.widget<PregoSwitch>(find.byType(PregoSwitch)).value;

  testWidgets("with the switch on, a sent source is archived behind one alert with Open and Undo", (tester) async {
    answerSend(() async => const SendToSessionSent());
    await openSheet(tester: tester, sending: source, remembered: true);
    expect(switchValue(tester), isTrue);

    await tapSend(tester);

    expect(archives.state.hiddenIds, {"source"});
    expect(archived, ["source"]);
    expect(find.text("Sent to “Idle chat”. Archived “Source chat”."), findsOneWidget);
    expect(find.text("Open"), findsOneWidget);
    // The send's alert carries the archive's Undo, so the shared one stays away.
    expect(find.text("Session archived"), findsNothing);

    await tester.tap(find.text("Undo"));
    await tester.pumpAndSettle();
    expect(archives.state.window, isA<PendingArchiveIdle>());
    expect(archives.state.hiddenIds, isEmpty);
    await archives.close();
  });

  testWidgets("with the switch off, a sent source is kept", (tester) async {
    answerSend(() async => const SendToSessionSent());
    await openSheet(tester: tester, sending: source, remembered: false);
    expect(switchValue(tester), isFalse);

    await tapSend(tester);

    expect(archives.state.hiddenIds, isEmpty);
    expect(archived, isEmpty);
    expect(find.text("Sent to “Idle chat”"), findsOneWidget);
    await archives.close();
  });

  testWidgets("turning the switch off is remembered for the next send", (tester) async {
    await openSheet(tester: tester, sending: source, remembered: true);

    await tester.tap(find.byType(PregoSwitch));
    await tester.pumpAndSettle();

    expect(switchValue(tester), isFalse);
    verify(() => actions.setArchiveAfterSend(value: false)).called(1);
    await archives.close();
  });

  final notSent = <SendToSessionResult>[
    const SendToSessionRefused(code: SendToSessionErrorCode.summaryStopped, message: null),
    SendToSessionFailed(error: ApiError.generic()),
    const SendToSessionUnsupported(),
    SendToSessionUnconfirmed(error: ApiError.generic()),
    const SendToSessionComputerSwitched(),
  ];
  for (final result in notSent) {
    testWidgets("${result.runtimeType} keeps the source", (tester) async {
      answerSend(() async => result);
      await openSheet(tester: tester, sending: source, remembered: true);

      await tapSend(tester);

      expect(archives.state.hiddenIds, isEmpty);
      expect(archived, isEmpty);
      await archives.close();
    });
  }

  testWidgets("a pinned source is asked about before the send, and Cancel keeps the sheet", (tester) async {
    answerSend(() async => const SendToSessionSent());
    await openSheet(tester: tester, sending: source.copyWith(pinned: true), remembered: true);

    await tapSend(tester);
    expect(find.text("Archive a pinned session?"), findsOneWidget);
    verifyNever(
      () =>
          actions.sendToSession(sourceSessionId: "source", sourcePluginId: source.pluginId, targetSessionId: "target"),
    );

    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Cancel"));
    await tester.pumpAndSettle();
    expect(find.text("Archive a pinned session?"), findsNothing);
    expect(find.byKey(const Key("send_session_send")), findsOneWidget);
    verifyNever(
      () =>
          actions.sendToSession(sourceSessionId: "source", sourcePluginId: source.pluginId, targetSessionId: "target"),
    );

    await tapSend(tester);
    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Archive"));
    await tester.pumpAndSettle();

    verify(
      () =>
          actions.sendToSession(sourceSessionId: "source", sourcePluginId: source.pluginId, targetSessionId: "target"),
    ).called(1);
    // Asked once, before the send; the archive after it doesn't ask again.
    expect(find.text("Archive a pinned session?"), findsNothing);
    expect(archives.state.hiddenIds, {"source"});
    await archives.close();
  });

  testWidgets("a pinned source with the switch off is sent without a question", (tester) async {
    answerSend(() async => const SendToSessionSent());
    await openSheet(tester: tester, sending: source.copyWith(pinned: true), remembered: false);

    await tapSend(tester);

    expect(find.text("Archive a pinned session?"), findsNothing);
    verify(
      () =>
          actions.sendToSession(sourceSessionId: "source", sourcePluginId: source.pluginId, targetSessionId: "target"),
    ).called(1);
    expect(archives.state.hiddenIds, isEmpty);
    await archives.close();
  });

  testWidgets("leaving the page during the send still archives the source", (tester) async {
    final answer = Completer<SendToSessionResult>();
    answerSend(() => answer.future);
    await openSheet(tester: tester, sending: source, remembered: true);
    await tester.tap(find.byKey(const Key("send_session_send")));
    // The sending alert's spinner never settles.
    await tester.pump(const Duration(seconds: 1));

    onPage.value = false;
    await tester.pump();
    answer.complete(const SendToSessionSent());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(archives.state.hiddenIds, {"source"});
    // The page that would close is already gone.
    expect(archived, isEmpty);
    expect(find.text("Sent to “Idle chat”. Archived “Source chat”."), findsOneWidget);
    await archives.close();
  });
}
