import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_list/send_session_sheet.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/module_prego.dart";

class _MockSearchCubit() extends MockCubit<SessionSearchState> implements SessionSearchCubit;

class _MockWindow() extends Mock implements SessionWindowService;

class _MockInventory() extends Mock implements ProjectInventoryService;

void main() {
  final project = testProjectSummary(id: "p1", name: "demo-app", path: "/work/demo-app");
  final source = testSession(id: "source", title: "Source chat");
  final matches = <SessionSearchMatch>[
    (session: testSession(id: "acp", title: "ACP chat"), project: project, running: RunningTarget.stopsTurn),
    (session: testSession(id: "steer", title: "Steering chat"), project: project, running: RunningTarget.keepsTurn),
    (session: testSession(id: "idle", title: "Idle chat"), project: project, running: null),
  ];

  late List<String?> excludedIds;
  late List<SendSessionChoice?> choices;

  setUp(() {
    excludedIds = [];
    choices = [];
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    final search = _MockSearchCubit();
    whenListen(
      search,
      const Stream<SessionSearchState>.empty(),
      initialState: SessionSearchState(matches: matches, isSearching: false),
    );
    when(() => search.setQuery(query: any(named: "query"))).thenReturn(null);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<SessionWindowService>.value(value: _MockWindow()),
          RepositoryProvider<ProjectInventoryService>.value(value: _MockInventory()),
        ],
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
                  builder: (context, _) => Scaffold(
                    body: TextButton(
                      onPressed: () async => choices.add(
                        await showSendSessionSheet(
                          context: context,
                          source: source,
                          createSearch: ({required window, required projectInventory, required excludedSessionId}) {
                            excludedIds.add(excludedSessionId);
                            return search;
                          },
                        ),
                      ),
                      child: const Text("Send"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Send"));
    await tester.pumpAndSettle();
  }

  testWidgets("searches every session but the one being sent", (tester) async {
    await pumpSheet(tester);

    expect(excludedIds, ["source"]);
  });

  testWidgets("the picker says what sending does to each running session", (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.byKey(const Key("send_session_target")));
    await tester.pumpAndSettle();

    expect(find.text("demo-app · Running: sending stops its current turn"), findsOneWidget);
    expect(find.text("demo-app · Running"), findsOneWidget);
    expect(find.text("demo-app"), findsOneWidget);
  });

  testWidgets("Send waits for a target, then returns it with the archive choice", (tester) async {
    await pumpSheet(tester);
    final send = find.byKey(const Key("send_session_send"));
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(choices, isEmpty);
    expect(find.text("Choose a session"), findsOneWidget);

    await tester.tap(find.byKey(const Key("send_session_target")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Idle chat"));
    await tester.pumpAndSettle();
    expect(find.text("Idle chat"), findsOneWidget);

    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(choices.single?.target.session.id, "idle");
    expect(choices.single?.archiveAfterSending, isTrue);
  });
}
