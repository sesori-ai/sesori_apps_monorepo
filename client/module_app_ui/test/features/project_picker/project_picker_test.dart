import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

final _demoApp = testProjectSummary(id: "app", name: "demo-app", path: "/work/demo-app");
final _demoApi = testProjectSummary(id: "api", name: "demo-api", path: "/work/demo-api");
final _clientWeb = testProjectSummary(id: "client-web", name: "web", path: "/work/client/web");
final _serverWeb = testProjectSummary(id: "server-web", name: "web", path: "/work/server/web");

void main() {
  late List<String> selected;
  late int allProjectsPicks;

  setUp(() {
    selected = [];
    allProjectsPicks = 0;
  });

  Future<void> pumpPicker({
    required WidgetTester tester,
    required List<ProjectSummary> projects,
    Size size = const Size(1200, 800),
    String? selectedProjectId = "app",
    bool filters = false,
    PregoInteractionMode mode = PregoInteractionMode.touch,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = _MockProjectListCubit();
    whenListen(
      cubit,
      const Stream<ProjectListState>.empty(),
      initialState: ProjectListState.loaded(projects: projects),
    );
    // What the folder browser reads once it opens.
    when(() => cubit.fetchFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer(
      (_) async => const FilesystemSuggestionsSuccess(
        suggestions: FilesystemSuggestions(data: [], path: "/work"),
      ),
    );
    when(() => cubit.parentHostPath(path: any(named: "path"))).thenReturn(null);
    final connectionService = MockConnectionService();
    when(() => connectionService.status)
        .thenAnswer((_) => BehaviorSubject.seeded(const ConnectionStatus.disconnected()));
    when(() => connectionService.currentStatus).thenReturn(const ConnectionStatus.disconnected());
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ProjectListCubit>.value(value: cubit),
          RepositoryProvider<ConnectionService>.value(value: connectionService),
        ],
        // Above the app, so the popover's route sees the mode too.
        child: PregoInteractionScope(
          mode: mode,
          child: MaterialApp(
            theme: buildPregoThemeData(brightness: Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: ProjectPicker(
                  selectedProjectId: selectedProjectId,
                  onSelected: ({required projectId, required projectName}) => selected.add("$projectId $projectName"),
                  onAllProjects: filters ? () => allProjectsPicks++ : null,
                  triggerBuilder: (_, open) => TextButton(onPressed: open, child: const Text("Choose project")),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Choose project"));
    await tester.pumpAndSettle();
  }

  Future<void> search({required WidgetTester tester, required String query}) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  testWidgets("search narrows the projects by name and path, under the add entry", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi, _clientWeb]);
    expect(find.text("Search projects"), findsOneWidget);
    expect(find.text("demo-app"), findsOneWidget);
    expect(find.text("demo-api"), findsOneWidget);
    expect(find.text("web"), findsOneWidget);

    await search(tester: tester, query: "API");
    expect(find.text("Open another folder…"), findsOneWidget);
    expect(find.text("demo-api"), findsOneWidget);
    expect(find.text("demo-app"), findsNothing);
    expect(find.text("web"), findsNothing);

    // A path matches too.
    await search(tester: tester, query: "client");
    expect(find.text("web"), findsOneWidget);
    expect(find.text("demo-api"), findsNothing);
  });

  testWidgets("a search with no match keeps the add entry and says nothing matches", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi]);

    await search(tester: tester, query: "zzz");
    expect(find.text("Open another folder…"), findsOneWidget);
    expect(find.text("No projects match"), findsOneWidget);
    expect(find.text("demo-app"), findsNothing);
  });

  testWidgets("only projects sharing a name show their paths", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _clientWeb, _serverWeb]);

    expect(find.text("web"), findsNWidgets(2));
    expect(find.text("…/client/web"), findsOneWidget);
    expect(find.text("…/server/web"), findsOneWidget);
    expect(find.text("demo-app"), findsOneWidget);
    expect(find.textContaining("/demo-app"), findsNothing);
  });

  testWidgets("with no project the add entry is the whole list", (tester) async {
    await pumpPicker(tester: tester, projects: const []);

    expect(find.text("Open another folder…"), findsOneWidget);
    expect(find.text("No projects match"), findsNothing);
  });

  testWidgets("with one project, picking it again changes nothing and closes", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp]);
    expect(find.text("Open another folder…"), findsOneWidget);

    await tester.tap(find.text("demo-app"));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.text("Search projects"), findsNothing);
  });

  testWidgets("picking another project closes the picker and selects it", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi]);

    await tester.tap(find.text("demo-api"));
    await tester.pumpAndSettle();
    expect(selected, ["api demo-api"]);
    expect(find.text("Search projects"), findsNothing);
  });

  testWidgets("Open another folder opens the browser and selects the project it adds", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp]);

    await tester.tap(find.text("Open another folder…"));
    await tester.pumpAndSettle();
    expect(find.text("Search projects"), findsNothing);
    final browser = find.byType(AddProjectDialog);
    expect(browser, findsOneWidget);

    tester
        .widget<AddProjectDialog>(browser)
        .onProjectAdded(context: tester.element(browser), project: _demoApi, displayName: "demo-api");
    expect(selected, ["api demo-api"]);
  });

  testWidgets("filtering, All projects leads in place of the add entry and clears the filter", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], filters: true);
    expect(find.text("All projects"), findsOneWidget);
    expect(find.text("Open another folder…"), findsNothing);

    await tester.tap(find.text("All projects"));
    await tester.pumpAndSettle();
    expect(allProjectsPicks, 1);
    expect(find.text("Search projects"), findsNothing);
  });

  testWidgets("filtering nothing yet, All projects is selected and picking it changes nothing", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp], selectedProjectId: null, filters: true);

    await tester.tap(find.text("All projects"));
    await tester.pumpAndSettle();
    expect(allProjectsPicks, 0);
    expect(find.text("Search projects"), findsNothing);
  });

  bool searchHasFocus(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

  testWidgets("a phone opens a sheet with the keyboard down until its search is tapped", (tester) async {
    await pumpPicker(
      tester: tester,
      projects: [_demoApp, _demoApi],
      size: const Size(390, 844),
    );

    expect(find.text("Projects"), findsOneWidget);
    expect(searchHasFocus(tester), isFalse);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(searchHasFocus(tester), isTrue);

    await search(tester: tester, query: "app");
    expect(find.text("demo-app"), findsOneWidget);
    expect(find.text("demo-api"), findsNothing);

    await tester.tap(find.text("demo-app"));
    await tester.pumpAndSettle();
    expect(find.text("Projects"), findsNothing);
  });

  testWidgets("a wide touch popover leaves the keyboard down too", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi]);

    expect(find.text("Search projects"), findsOneWidget);
    expect(searchHasFocus(tester), isFalse);
  });

  testWidgets("under a pointer the search takes focus, so typing filters at once", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], mode: PregoInteractionMode.pointer);

    expect(searchHasFocus(tester), isTrue);
  });
}
