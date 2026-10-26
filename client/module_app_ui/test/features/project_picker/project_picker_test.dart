import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

final _demoApp = testProjectSummary(id: "app", name: "demo-app", path: "/work/demo-app");
final _demoApi = testProjectSummary(id: "api", name: "demo-api", path: "/work/demo-api");
final _clientWeb = testProjectSummary(id: "client-web", name: "web", path: "/work/client/web");
final _serverWeb = testProjectSummary(id: "server-web", name: "web", path: "/work/server/web");
const _scratch = ProjectSummary(
  id: "scratch",
  name: null,
  path: "/work/scratch",
  time: null,
  kind: ProjectKind.scratch,
);

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
    ProjectSummary? scratchProject,
    PregoInteractionMode mode = PregoInteractionMode.touch,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = _MockProjectListCubit();
    whenListen(
      cubit,
      const Stream<ProjectListState>.empty(),
      initialState: ProjectListState.loaded(
        projects: [...projects, ?scratchProject],
        folderProjects: projects,
        scratchProject: scratchProject,
      ),
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

  double topOf({required WidgetTester tester, required Finder finder}) => tester.getTopLeft(finder).dy;

  testWidgets("search narrows the projects by name and path", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi, _clientWeb]);
    expect(find.text("Search projects"), findsOneWidget);
    expect(find.text("demo-app"), findsOneWidget);
    expect(find.text("demo-api"), findsOneWidget);
    expect(find.text("web"), findsOneWidget);

    await search(tester: tester, query: "API");
    expect(find.text("demo-api"), findsOneWidget);
    expect(find.text("demo-app"), findsNothing);
    expect(find.text("web"), findsNothing);

    // A path matches too.
    await search(tester: tester, query: "client");
    expect(find.text("web"), findsOneWidget);
    expect(find.text("demo-api"), findsNothing);
  });

  final openFolder = find.text("Open folder…");

  testWidgets("the search is the first control under the title, and Open folder is pinned below the list", (
    tester,
  ) async {
    // The phone sheet, whose fixed height keeps the search and the footer
    // still while the matches narrow.
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], size: const Size(390, 844));
    final searchTop = topOf(tester: tester, finder: find.byType(TextField));
    expect(topOf(tester: tester, finder: find.text("Projects")), lessThan(searchTop));
    final controls = find.descendant(
      of: find.byType(PregoPickerSearchList),
      matching: find.byWidgetPredicate((widget) => widget is InkWell || widget is PregoButtonsSolid),
    );
    // The two projects and the footer, whose pill holds an ink well too.
    final count = controls.evaluate().length;
    expect(count, greaterThanOrEqualTo(3));
    for (var index = 0; index < count; index++) {
      expect(topOf(tester: tester, finder: controls.at(index)), greaterThan(searchTop));
    }
    // Below every project and outside their scroll, not one of them.
    final actionTop = topOf(tester: tester, finder: openFolder);
    expect(actionTop, greaterThan(tester.getBottomLeft(find.text("demo-api")).dy));
    expect(find.descendant(of: find.byType(ListView), matching: openFolder), findsNothing);

    // No query filters it, and nothing moves.
    await search(tester: tester, query: "API");
    expect(openFolder, findsOneWidget);
    expect(topOf(tester: tester, finder: openFolder), actionTop);
    expect(topOf(tester: tester, finder: find.byType(TextField)), searchTop);
    await search(tester: tester, query: "folder");
    expect(openFolder, findsOneWidget);
    expect(find.text("No projects match"), findsOneWidget);
  });

  testWidgets("a search with no match keeps the action and says nothing matches", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi]);

    await search(tester: tester, query: "zzz");
    expect(openFolder, findsOneWidget);
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

  testWidgets("with no project the action is all the picker offers", (tester) async {
    await pumpPicker(tester: tester, projects: const []);

    expect(openFolder, findsOneWidget);
    expect(find.text("No projects match"), findsNothing);
  });

  testWidgets("with one project, picking it again changes nothing and closes", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp]);
    expect(openFolder, findsOneWidget);

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

  testWidgets("the footer's Open folder opens the browser and selects the project it adds", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp]);

    await tester.tap(openFolder);
    await tester.pumpAndSettle();
    expect(find.text("Search projects"), findsNothing);
    final browser = find.byType(AddProjectDialog);
    expect(browser, findsOneWidget);

    tester
        .widget<AddProjectDialog>(browser)
        .onProjectAdded(context: tester.element(browser), project: _demoApi, displayName: "demo-api");
    expect(selected, ["api demo-api"]);
  });

  final showAll = find.text("All projects");
  final footer = find.ancestor(of: showAll, matching: find.byType(PregoButtonsSolid));
  Finder checkIn(Finder scope) => find.descendant(of: scope, matching: find.byIcon(TablerRegular.check));
  Finder row(String name) => find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

  testWidgets("filtering, All projects is pinned below the list in place of the action and clears the filter", (
    tester,
  ) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], filters: true);
    expect(footer, findsOneWidget);
    expect(openFolder, findsNothing);
    // Below every project and outside their scroll, not one of them.
    expect(topOf(tester: tester, finder: footer), greaterThan(tester.getBottomLeft(find.text("demo-api")).dy));
    expect(find.descendant(of: find.byType(ListView), matching: showAll), findsNothing);
    // Another project is the choice, so only that project is checked.
    expect(checkIn(footer), findsNothing);
    expect(checkIn(row("demo-app")), findsOneWidget);

    await tester.tap(showAll);
    await tester.pumpAndSettle();
    expect(allProjectsPicks, 1);
    expect(find.text("Search projects"), findsNothing);
  });

  testWidgets("showing every project, the footer is there checked, no project is, and it only closes", (
    tester,
  ) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], selectedProjectId: null, filters: true);
    expect(checkIn(footer), findsOneWidget);
    expect(checkIn(find.byType(ListView)), findsNothing);

    await tester.tap(showAll);
    await tester.pumpAndSettle();
    expect(allProjectsPicks, 0);
    expect(find.text("Search projects"), findsNothing);
  });

  testWidgets("filtering, the search narrows only the projects and never hides the footer", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], filters: true);

    await search(tester: tester, query: "api");
    expect(footer, findsOneWidget);
    expect(find.text("demo-app"), findsNothing);
    await search(tester: tester, query: "all projects");
    expect(footer, findsOneWidget);
    expect(find.text("No projects match"), findsOneWidget);
  });

  final noProject = find.text("No project");

  testWidgets("with No project the footer pairs it with Open folder, and picking it closes and selects it", (
    tester,
  ) async {
    await pumpPicker(tester: tester, projects: [_demoApp], scratchProject: _scratch);
    expect(noProject, findsOneWidget);
    expect(openFolder, findsOneWidget);
    // In the footer, not a row of the list.
    expect(find.descendant(of: find.byType(ListView), matching: noProject), findsNothing);

    await tester.tap(noProject);
    await tester.pumpAndSettle();
    expect(selected, ["scratch No project"]);
    expect(find.text("Search projects"), findsNothing);
  });

  testWidgets("filtering with No project the footer pairs it with All projects, checked while it is the filter", (
    tester,
  ) async {
    await pumpPicker(
      tester: tester,
      projects: [_demoApp],
      scratchProject: _scratch,
      selectedProjectId: "scratch",
      filters: true,
    );
    expect(showAll, findsOneWidget);
    expect(openFolder, findsNothing);
    expect(checkIn(find.ancestor(of: noProject, matching: find.byType(PregoButtonsSolid))), findsOneWidget);
    expect(checkIn(footer), findsNothing);
    expect(checkIn(find.byType(ListView)), findsNothing);
  });

  testWidgets("a phone sheet keeps the footer at its bottom, riding the keyboard up without moving the search", (
    tester,
  ) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], size: const Size(390, 844), filters: true);
    // Low in the sheet, in thumb reach, well clear of the two rows.
    final restingBottom = tester.getBottomLeft(footer).dy;
    expect(restingBottom, greaterThan(700));
    final searchTop = topOf(tester: tester, finder: find.byType(TextField));

    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(footer).dy, lessThanOrEqualTo(844 - 300));
    expect(topOf(tester: tester, finder: find.byType(TextField)), searchTop);
    expect(find.text("demo-app"), findsOneWidget);
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

  Future<void> press({required WidgetTester tester, required LogicalKeyboardKey key}) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets("under a pointer Enter after typing picks the first match, not the action", (tester) async {
    await pumpPicker(
      tester: tester,
      projects: [_demoApp, _demoApi],
      selectedProjectId: null,
      mode: PregoInteractionMode.pointer,
    );

    await search(tester: tester, query: "api");
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(selected, ["api demo-api"]);
    expect(find.byType(AddProjectDialog), findsNothing);
  });

  testWidgets("under a pointer Down past the last project reaches the action, which Enter opens", (tester) async {
    await pumpPicker(
      tester: tester,
      projects: [_demoApp, _demoApi],
      selectedProjectId: null,
      mode: PregoInteractionMode.pointer,
    );

    // From the first project, past the second, onto the action.
    await press(tester: tester, key: LogicalKeyboardKey.arrowDown);
    await press(tester: tester, key: LogicalKeyboardKey.arrowDown);
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(selected, isEmpty);
    expect(find.text("Search projects"), findsNothing);
    expect(find.byType(AddProjectDialog), findsOneWidget);
  });

  testWidgets("under a pointer with nothing matching, Enter waits and Down reaches the action", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp], mode: PregoInteractionMode.pointer);

    await search(tester: tester, query: "zzz");
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(find.text("Search projects"), findsOneWidget);
    expect(find.byType(AddProjectDialog), findsNothing);
    await press(tester: tester, key: LogicalKeyboardKey.arrowDown);
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(find.byType(AddProjectDialog), findsOneWidget);
  });

  bool footerHighlighted(WidgetTester tester) {
    final ring = find.ancestor(of: footer, matching: find.byType(DecoratedBox)).first;
    return (tester.widget<DecoratedBox>(ring).decoration as BoxDecoration).boxShadow != null;
  }

  testWidgets("under a pointer Down past the last project highlights the footer, which Enter picks", (tester) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], filters: true, mode: PregoInteractionMode.pointer);
    expect(footerHighlighted(tester), isFalse);

    // From the first project, past the second, onto the footer, where it holds.
    for (var i = 0; i < 3; i++) {
      await press(tester: tester, key: LogicalKeyboardKey.arrowDown);
    }
    expect(footerHighlighted(tester), isTrue);
    await press(tester: tester, key: LogicalKeyboardKey.arrowUp);
    expect(footerHighlighted(tester), isFalse);
    await press(tester: tester, key: LogicalKeyboardKey.arrowDown);

    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(allProjectsPicks, 1);
    expect(selected, isEmpty);
    expect(find.text("Search projects"), findsNothing);
  });

  testWidgets("under a pointer Enter after typing picks the first matching project, never the footer", (
    tester,
  ) async {
    await pumpPicker(tester: tester, projects: [_demoApp, _demoApi], filters: true, mode: PregoInteractionMode.pointer);

    // Nothing matching leaves nothing for Enter, though Down still reaches the footer.
    await search(tester: tester, query: "zzz");
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(selected, isEmpty);
    expect(allProjectsPicks, 0);
    expect(find.text("Search projects"), findsOneWidget);
    await press(tester: tester, key: LogicalKeyboardKey.arrowDown);
    expect(footerHighlighted(tester), isTrue);

    await search(tester: tester, query: "api");
    expect(footerHighlighted(tester), isFalse);
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(selected, ["api demo-api"]);
    expect(allProjectsPicks, 0);
  });

  testWidgets("under a pointer Enter on the footer Tab focused presses it, not the highlighted project", (
    tester,
  ) async {
    await pumpPicker(
      tester: tester,
      projects: [_demoApp, _demoApi],
      selectedProjectId: "api",
      filters: true,
      mode: PregoInteractionMode.pointer,
    );

    bool footerFocused() =>
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<PregoButtonsSolid>() != null;
    for (var i = 0; i < 5 && !footerFocused(); i++) {
      await press(tester: tester, key: LogicalKeyboardKey.tab);
    }
    expect(footerFocused(), isTrue);

    // demo-app still holds the highlight.
    await press(tester: tester, key: LogicalKeyboardKey.enter);
    expect(allProjectsPicks, 1);
    expect(selected, isEmpty);
  });
}
