import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
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
  late List<BuildContext> openedFrom;
  late ProjectOpenedCallback? addedCallback;

  setUp(() {
    selected = [];
    openedFrom = [];
    addedCallback = null;
  });

  ProjectPickerMode newSessionMode() => ProjectPickerNewSessionMode(
    selectedProjectId: "app",
    onSelected: ({required projectId, required projectName}) => selected.add("$projectId $projectName"),
    openFolder: ({required context, required onProjectAdded}) {
      openedFrom.add(context);
      addedCallback = onProjectAdded;
    },
  );

  Future<void> pumpPicker({
    required WidgetTester tester,
    required List<ProjectSummary> projects,
    required ProjectPickerMode mode,
    Size size = const Size(1200, 800),
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
    await tester.pumpWidget(
      BlocProvider<ProjectListCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ProjectPicker(
                mode: mode,
                triggerBuilder: (_, open) => TextButton(onPressed: open, child: const Text("Choose project")),
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
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi, _clientWeb], mode: newSessionMode());
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
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], mode: newSessionMode());

    await search(tester: tester, query: "zzz");
    expect(find.text("Open another folder…"), findsOneWidget);
    expect(find.text("No projects match"), findsOneWidget);
    expect(find.text("demo-app"), findsNothing);
  });

  testWidgets("only projects sharing a name show their paths", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _clientWeb, _serverWeb], mode: newSessionMode());

    expect(find.text("web"), findsNWidgets(2));
    expect(find.text("…/client/web"), findsOneWidget);
    expect(find.text("…/server/web"), findsOneWidget);
    expect(find.text("demo-app"), findsOneWidget);
    expect(find.textContaining("/demo-app"), findsNothing);
  });

  testWidgets("with no project the add entry is the whole list", (tester) async {
    await pumpPicker(tester: tester, projects: const [], mode: newSessionMode());

    expect(find.text("Open another folder…"), findsOneWidget);
    expect(find.text("No projects match"), findsNothing);
  });

  testWidgets("with one project, picking it again changes nothing and closes", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp], mode: newSessionMode());
    expect(find.text("Open another folder…"), findsOneWidget);

    await tester.tap(find.text("demo-app"));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.text("Search projects"), findsNothing);
  });

  testWidgets("picking another project closes the picker and selects it", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], mode: newSessionMode());

    await tester.tap(find.text("demo-api"));
    await tester.pumpAndSettle();
    expect(selected, ["api demo-api"]);
    expect(find.text("Search projects"), findsNothing);
  });

  testWidgets("Open another folder opens the browser and selects the project it adds", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp], mode: newSessionMode());

    await tester.tap(find.text("Open another folder…"));
    await tester.pumpAndSettle();
    expect(find.text("Search projects"), findsNothing);
    expect(openedFrom.single.mounted, isTrue);

    addedCallback?.call(context: openedFrom.single, project: _demoApi, displayName: "demo-api");
    expect(selected, ["api demo-api"]);
  });

  testWidgets("a phone opens a sheet whose search takes the keyboard", (tester) async {
    await pumpPicker(
      tester: tester,
      projects: [_demoApp, _demoApi],
      mode: newSessionMode(),
      size: const Size(390, 844),
    );

    expect(find.text("Projects"), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);

    await search(tester: tester, query: "app");
    expect(find.text("demo-app"), findsOneWidget);
    expect(find.text("demo-api"), findsNothing);

    await tester.tap(find.text("demo-app"));
    await tester.pumpAndSettle();
    expect(find.text("Projects"), findsNothing);
  });

  testWidgets("the filter is led by All projects, which clears it", (tester) async {
    final filtered = <String?>[];
    await pumpPicker(
      tester: tester,
      projects: [_demoApp, _demoApi],
      mode: ProjectPickerFilterMode(
        selectedProjectId: "app",
        onSelected: ({required projectId}) => filtered.add(projectId),
      ),
    );
    expect(find.text("Open another folder…"), findsNothing);

    await tester.tap(find.text("All projects"));
    await tester.pumpAndSettle();
    expect(filtered, [null]);

    await tester.tap(find.text("Choose project"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("demo-api"));
    await tester.pumpAndSettle();
    expect(filtered, [null, "api"]);
  });
}
