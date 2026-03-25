import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/project_list/add_project_dialog.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

class MockProjectListCubit extends MockCubit<ProjectListState> implements ProjectListCubit {}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _homeDirEntries = [
  FilesystemSuggestion(path: "/home/user/projects", name: "projects", isGitRepo: false),
  FilesystemSuggestion(path: "/home/user/work", name: "work", isGitRepo: false),
  FilesystemSuggestion(path: "/home/user/my-repo", name: "my-repo", isGitRepo: true),
];

const _projectsDirEntries = [
  FilesystemSuggestion(path: "/home/user/projects/app-one", name: "app-one", isGitRepo: true),
  FilesystemSuggestion(path: "/home/user/projects/lib-two", name: "lib-two", isGitRepo: false),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({required ProjectListCubit cubit, required Widget child}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<ProjectListCubit>.value(
      value: cubit,
      child: child,
    ),
  );
}

Widget _buildProjectListShell({required ProjectListCubit cubit}) {
  return _buildApp(
    cubit: cubit,
    child: Builder(
      builder: (context) {
        final loc = AppLocalizations.of(context)!;
        final state = context.watch<ProjectListCubit>().state;

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            tooltip: loc.addProject,
            onPressed: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
            child: const Icon(Icons.add),
          ),
          body: switch (state) {
            ProjectListLoading() => const Center(child: CircularProgressIndicator()),
            ProjectListLoaded(:final projects) =>
              projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(loc.noProjects),
                          const SizedBox(height: 8),
                          Text(loc.addProjectPrompt),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
                            icon: const Icon(Icons.add),
                            label: Text(loc.addProject),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: projects.length,
                      itemBuilder: (ctx, index) {
                        final project = projects[index];
                        final listCubit = context.read<ProjectListCubit>();
                        return ListTile(
                          key: Key("project-tile-${project.id}"),
                          title: Text(project.name ?? project.id),
                          onLongPress: () {
                            showModalBottomSheet<void>(
                              context: ctx,
                              builder: (sheetContext) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.visibility_off_outlined),
                                      title: Text(loc.hideProject),
                                      onTap: () {
                                        Navigator.of(sheetContext).pop();
                                        listCubit.hideProject(project.id);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ProjectListFailed() => const Text("Error"),
          },
        );
      },
    ),
  );
}

void _stubSuggestionsWithEntries(
  MockProjectService service, {
  required List<FilesystemSuggestion> entries,
}) {
  when(
    () => service.getFilesystemSuggestions(prefix: any(named: "prefix")),
  ).thenAnswer((_) async => ApiResponse.success(entries));
}

void _stubSuggestionsPerPrefix(
  MockProjectService service, {
  required Map<String, List<FilesystemSuggestion>> byPrefix,
}) {
  when(() => service.getFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer((invocation) async {
    final prefix = invocation.namedArguments[const Symbol("prefix")] as String;
    return ApiResponse.success(byPrefix[prefix] ?? []);
  });
}

void main() {
  late MockProjectListCubit mockCubit;
  late MockProjectService mockProjectService;

  setUp(() {
    mockCubit = MockProjectListCubit();
    mockProjectService = MockProjectService();

    final getIt = GetIt.instance;
    if (getIt.isRegistered<ProjectService>()) {
      getIt.unregister<ProjectService>();
    }
    getIt.registerSingleton<ProjectService>(mockProjectService);
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ProjectService>()) {
      getIt.unregister<ProjectService>();
    }
  });

  // -------------------------------------------------------------------------
  // FAB
  // -------------------------------------------------------------------------

  group("FAB", () {
    testWidgets("opens add project dialog when tapped", (tester) async {
      when(() => mockCubit.state).thenReturn(
        const ProjectListState.loaded(projects: [], activityById: {}),
      );
      _stubSuggestionsWithEntries(mockProjectService, entries: _homeDirEntries);

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Single view — title + directory entries + both action buttons
      expect(find.text("Add Project"), findsWidgets);
      expect(find.text("projects"), findsOneWidget);
      expect(find.text("Open as Project"), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Long-press to hide
  // -------------------------------------------------------------------------

  group("Long-press to hide", () {
    testWidgets("long-pressing a project tile shows bottom sheet with Hide Project", (tester) async {
      final project = testProject();
      when(() => mockCubit.state).thenReturn(
        ProjectListState.loaded(projects: [project], activityById: const {}),
      );

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      final tileFinder = find.byKey(Key("project-tile-${project.id}"));
      expect(tileFinder, findsOneWidget);

      await tester.longPress(tileFinder);
      await tester.pumpAndSettle();

      expect(find.text("Hide Project"), findsOneWidget);
    });

    testWidgets("tapping Hide Project calls hideProject", (tester) async {
      final project = testProject();
      when(() => mockCubit.state).thenReturn(
        ProjectListState.loaded(projects: [project], activityById: const {}),
      );
      when(() => mockCubit.hideProject(any())).thenAnswer((_) async {});

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      final tileFinder = find.byKey(Key("project-tile-${project.id}"));
      await tester.longPress(tileFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Hide Project"));
      await tester.pumpAndSettle();

      verify(() => mockCubit.hideProject(project.id)).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // Empty state
  // -------------------------------------------------------------------------

  group("Empty state", () {
    testWidgets("shows no-projects text and add project button when list is empty", (tester) async {
      when(() => mockCubit.state).thenReturn(
        const ProjectListState.loaded(projects: [], activityById: {}),
      );

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      expect(find.text("No projects"), findsOneWidget);
      expect(find.text("Add a project to get started"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "Add Project"), findsOneWidget);
    });

    testWidgets("empty state add button opens dialog", (tester) async {
      when(() => mockCubit.state).thenReturn(
        const ProjectListState.loaded(projects: [], activityById: {}),
      );
      _stubSuggestionsWithEntries(mockProjectService, entries: _homeDirEntries);

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      await tester.tap(find.widgetWithText(FilledButton, "Add Project"));
      await tester.pumpAndSettle();

      expect(find.text("Open as Project"), findsOneWidget);
      expect(find.text("Project name"), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // AddProjectDialog — single view
  // -------------------------------------------------------------------------

  group("AddProjectDialog", () {
    testWidgets("shows directory browser with entries and both action buttons", (tester) async {
      _stubSuggestionsWithEntries(mockProjectService, entries: _homeDirEntries);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Directory entries visible
      expect(find.text("projects"), findsOneWidget);
      expect(find.text("work"), findsOneWidget);
      expect(find.text("my-repo"), findsOneWidget);

      // Git badge
      expect(find.text("git"), findsOneWidget);

      // Both action buttons
      expect(find.text("Open as Project"), findsOneWidget);
      expect(find.text("Create"), findsOneWidget);

      // Project name field
      expect(find.text("Project name"), findsOneWidget);

      // No tab bar
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets("tapping a directory entry navigates into it", (tester) async {
      _stubSuggestionsPerPrefix(
        mockProjectService,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/projects": _projectsDirEntries,
        },
      );

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("projects"));
      await tester.pumpAndSettle();

      expect(find.text("app-one"), findsOneWidget);
      expect(find.text("lib-two"), findsOneWidget);
      expect(find.text("work"), findsNothing);
      expect(find.text("/home/user/projects"), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets("back button navigates up one directory level", (tester) async {
      _stubSuggestionsPerPrefix(
        mockProjectService,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/projects": _projectsDirEntries,
          "/home/user": _homeDirEntries,
        },
      );

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("projects"));
      await tester.pumpAndSettle();
      expect(find.text("app-one"), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text("projects"), findsOneWidget);
      expect(find.text("work"), findsOneWidget);
    });

    testWidgets("Open as Project calls discoverProject with browsed path", (tester) async {
      _stubSuggestionsPerPrefix(
        mockProjectService,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/my-repo": const [],
        },
      );
      when(() => mockCubit.discoverProject(path: any(named: "path"))).thenAnswer((_) async => true);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Navigate into my-repo
      await tester.tap(find.text("my-repo"));
      await tester.pumpAndSettle();

      // Tap "Open as Project"
      await tester.tap(find.text("Open as Project"));
      await tester.pumpAndSettle();

      verify(() => mockCubit.discoverProject(path: "/home/user/my-repo")).called(1);
    });

    testWidgets("Create constructs path from browsed dir + typed name", (tester) async {
      _stubSuggestionsPerPrefix(
        mockProjectService,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/projects": _projectsDirEntries,
        },
      );
      when(() => mockCubit.createProject(path: any(named: "path"))).thenAnswer((_) async => true);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Navigate into "projects"
      await tester.tap(find.text("projects"));
      await tester.pumpAndSettle();

      // Type project name
      await tester.enterText(find.byType(TextField), "new-app");
      await tester.pumpAndSettle();

      // Tap "Create"
      await tester.tap(find.text("Create"));
      await tester.pumpAndSettle();

      verify(() => mockCubit.createProject(path: "/home/user/projects/new-app")).called(1);
    });

    testWidgets("empty directory shows empty state message", (tester) async {
      _stubSuggestionsWithEntries(mockProjectService, entries: const []);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(find.text("This directory is empty"), findsOneWidget);
    });

    testWidgets("loading state shows progress indicator", (tester) async {
      when(
        () => mockProjectService.getFilesystemSuggestions(prefix: any(named: "prefix")),
      ).thenAnswer((_) => Completer<ApiResponse<List<FilesystemSuggestion>>>().future);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
