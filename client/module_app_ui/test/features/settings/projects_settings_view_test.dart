import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
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

class _MockConnectionOverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit;

const _demoApp = ProjectSummary(id: "app", name: "demo-app", path: "/work/demo-app", time: null);
const _demoApi = ProjectSummary(id: "api", name: "demo-api", path: "/work/demo-api", time: null);
const _gone = ProjectSummary(id: "gone", name: "old-tool", path: "/work/old-tool", time: null, directoryMissing: true);

Finder _actions(String projectId) => find.byKey(ValueKey("projects-settings-actions-$projectId"));

final Finder _openFolder = find.byKey(const Key("projects-settings-open-folder"));

void main() {
  late _MockProjectListCubit cubit;
  late _MockConnectionOverlayCubit overlay;
  late BehaviorSubject<ConnectionOverlayState> overlayStates;

  setUp(() {
    cubit = _MockProjectListCubit();
    whenListen(
      cubit,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(projects: [_demoApp, _demoApi, _gone]),
    );
    when(() => cubit.hideProject(projectId: any(named: "projectId"))).thenAnswer((_) async => true);
    when(
      () => cubit.renameProject(
        projectId: any(named: "projectId"),
        name: any(named: "name"),
      ),
    ).thenAnswer((_) async => true);
    when(() => cubit.fetchFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer(
      (_) async => const FilesystemSuggestionsSuccess(
        suggestions: FilesystemSuggestions(data: [], path: "/work"),
      ),
    );
    when(() => cubit.parentHostPath(path: any(named: "path"))).thenReturn(null);
    overlay = _MockConnectionOverlayCubit();
    overlayStates = BehaviorSubject();
    addTearDown(overlayStates.close);
  });

  Future<void> pumpView({required WidgetTester tester, required bool connected}) async {
    final initial = ConnectionOverlayState.hidden(connected: connected);
    whenListen(overlay, overlayStates.stream, initialState: initial);
    final connectionService = MockConnectionService();
    when(() => connectionService.status)
        .thenAnswer((_) => BehaviorSubject.seeded(const ConnectionStatus.disconnected()));
    when(() => connectionService.currentStatus).thenReturn(const ConnectionStatus.disconnected());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: "/",
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<ProjectListCubit>.value(value: cubit),
              BlocProvider<ConnectionOverlayCubit>.value(value: overlay),
              RepositoryProvider<ConnectionService>.value(value: connectionService),
            ],
            child: ProjectsSettingsView(chrome: SettingsPageOwnBar(title: "Projects", connectionBanner: null)),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickAction({required WidgetTester tester, required String projectId, required String action}) async {
    await tester.tap(_actions(projectId));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets("lists every project under Open another folder, each over its path or its missing folder", (
    tester,
  ) async {
    await pumpView(tester: tester, connected: true);

    expect(find.text("Open another folder…"), findsOneWidget);
    expect(find.text("demo-app"), findsOneWidget);
    expect(find.text("demo-api"), findsOneWidget);
    expect(find.text("old-tool"), findsOneWidget);
    expect(find.text("Folder not found"), findsOneWidget);
    expect(find.text("Connect to a bridge to manage projects."), findsNothing);
    expect(tester.getTopLeft(_openFolder).dy, lessThan(tester.getTopLeft(find.text("demo-app")).dy));
  });

  testWidgets("Rename from a row's menu renames that project", (tester) async {
    await pumpView(tester: tester, connected: true);

    await pickAction(tester: tester, projectId: "api", action: "Rename");
    await tester.enterText(find.byType(TextField), "renamed-api");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    verify(() => cubit.renameProject(projectId: "api", name: "renamed-api")).called(1);
  });

  testWidgets("Hide from a row's menu hides that project and says so", (tester) async {
    await pumpView(tester: tester, connected: true);

    await pickAction(tester: tester, projectId: "app", action: "Hide project");

    verify(() => cubit.hideProject(projectId: "app")).called(1);
    expect(find.text("Project hidden"), findsOneWidget);
  });

  testWidgets("a project whose folder is gone offers Remove, which drops it", (tester) async {
    await pumpView(tester: tester, connected: true);

    await tester.tap(_actions("gone"));
    await tester.pumpAndSettle();
    expect(find.text("Hide project"), findsNothing);
    await tester.tap(find.text("Remove"));
    await tester.pumpAndSettle();

    verify(() => cubit.hideProject(projectId: "gone")).called(1);
  });

  testWidgets("Open another folder opens the folder browser", (tester) async {
    await pumpView(tester: tester, connected: true);

    await tester.tap(_openFolder);
    await tester.pumpAndSettle();

    expect(find.byType(AddProjectDialog), findsOneWidget);
  });

  testWidgets("offline, the rows dim and stop acting under a line that says why, until the bridge returns", (
    tester,
  ) async {
    await pumpView(tester: tester, connected: false);

    expect(find.text("Connect to a bridge to manage projects."), findsOneWidget);
    expect(find.text("demo-app"), findsOneWidget);
    final dimmed = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.text("demo-app"), matching: find.byType(AnimatedOpacity)),
    );
    expect(dimmed.opacity, 0.4);
    expect(tester.widget<PregoButtonsSolid>(_actions("app")).onPressed, isNull);
    await tester.tap(_openFolder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AddProjectDialog), findsNothing);

    overlayStates.add(const ConnectionOverlayState.hidden(connected: true));
    await tester.pumpAndSettle();
    expect(find.text("Connect to a bridge to manage projects."), findsNothing);
    expect(tester.widget<PregoButtonsSolid>(_actions("app")).onPressed, isNotNull);
  });
}
