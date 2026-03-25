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

/// Wraps [child] with `MaterialApp` + localization + `BlocProvider`.
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

/// A minimal Scaffold that mirrors the real screen's FAB + body switch.
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
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        return Dismissible(
                          key: ValueKey(project.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            context.read<ProjectListCubit>().closeProject(project.id);
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: Colors.red,
                            child: const Icon(Icons.visibility_off, color: Colors.white),
                          ),
                          child: ListTile(
                            key: Key("project-tile-${project.id}"),
                            title: Text(project.name ?? project.id),
                          ),
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

/// Stubs the project service to return [entries] for any prefix.
void _stubSuggestionsWithEntries(
  MockProjectService service, {
  required List<FilesystemSuggestion> entries,
}) {
  when(
    () => service.getFilesystemSuggestions(prefix: any(named: "prefix")),
  ).thenAnswer((_) async => ApiResponse.success(entries));
}

/// Stubs the project service to return different entries per prefix.
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

    // Register ProjectService in GetIt so the dialog can resolve it.
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
  // Test 1: FAB exists and opens dialog when tapped
  // -------------------------------------------------------------------------

  group("FAB", () {
    testWidgets("FAB is visible and opens add project dialog when tapped", (tester) async {
      when(() => mockCubit.state).thenReturn(
        const ProjectListState.loaded(projects: [], activityById: {}),
      );
      _stubSuggestionsWithEntries(mockProjectService, entries: _homeDirEntries);

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      // FAB exists
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets); // FAB icon + possible empty-state button

      // Tap FAB to open dialog
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Dialog should be visible with two tabs
      expect(find.text("Create New"), findsOneWidget);
      expect(find.text("Discover Existing"), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Test 2: Swipe-to-dismiss on a project tile calls closeProject
  // -------------------------------------------------------------------------

  group("Swipe to close", () {
    testWidgets("swiping a project tile left calls closeProject", (tester) async {
      final project = testProject();
      when(() => mockCubit.state).thenReturn(
        ProjectListState.loaded(projects: [project], activityById: const {}),
      );
      when(() => mockCubit.closeProject(any())).thenAnswer((_) async {});

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      // Find the ListTile by key
      final tileFinder = find.byKey(Key("project-tile-${project.id}"));
      expect(tileFinder, findsOneWidget);

      // Swipe left (endToStart)
      await tester.drag(tileFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      verify(() => mockCubit.closeProject(project.id)).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // Test 3: Empty state shows "Add Project" prompt
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

      expect(find.text("Create New"), findsOneWidget);
      expect(find.text("Discover Existing"), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Test 4: Dialog renders directory browser with entries
  // -------------------------------------------------------------------------

  group("AddProjectDialog", () {
    testWidgets("renders with two tabs and shows directory entries on open", (tester) async {
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

      // Two tabs
      expect(find.text("Create New"), findsOneWidget);
      expect(find.text("Discover Existing"), findsOneWidget);

      // Directory entries visible (Create tab shows its browser)
      expect(find.text("projects"), findsOneWidget);
      expect(find.text("work"), findsOneWidget);
      expect(find.text("my-repo"), findsOneWidget);

      // Git badge visible for my-repo
      expect(find.text("git"), findsOneWidget);

      // No path text field — only a project name field in Create tab
      expect(find.text("Project name"), findsOneWidget);

      // Create Project button visible
      expect(find.text("Create Project"), findsOneWidget);
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

      // Tap "projects" directory
      await tester.tap(find.text("projects"));
      await tester.pumpAndSettle();

      // Now we should see the children of /home/user/projects
      expect(find.text("app-one"), findsOneWidget);
      expect(find.text("lib-two"), findsOneWidget);

      // Previous entries should be gone
      expect(find.text("work"), findsNothing);

      // Breadcrumb path should show current path
      expect(find.text("/home/user/projects"), findsOneWidget);

      // Back button should be visible
      expect(find.byIcon(Icons.arrow_back), findsWidgets);
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

      // Navigate into "projects"
      await tester.tap(find.text("projects"));
      await tester.pumpAndSettle();

      expect(find.text("app-one"), findsOneWidget);

      // Tap back button (find the first one — Create tab's browser)
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      // Should show parent directory entries again
      expect(find.text("projects"), findsOneWidget);
      expect(find.text("work"), findsOneWidget);
    });

    testWidgets("switching to Discover tab shows Discover This Directory button", (tester) async {
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

      // Switch to Discover tab
      await tester.tap(find.text("Discover Existing"));
      await tester.pumpAndSettle();

      expect(find.text("Discover This Directory"), findsOneWidget);
    });

    testWidgets("Discover tab calls discoverProject with current path", (tester) async {
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

      // Switch to Discover tab
      await tester.tap(find.text("Discover Existing"));
      await tester.pumpAndSettle();

      // Navigate into my-repo
      await tester.tap(find.text("my-repo"));
      await tester.pumpAndSettle();

      // Tap "Discover This Directory"
      await tester.tap(find.text("Discover This Directory"));
      await tester.pumpAndSettle();

      verify(() => mockCubit.discoverProject(path: "/home/user/my-repo")).called(1);
    });

    testWidgets("Create tab calls createProject with browsing path + name", (tester) async {
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

      // Type a project name
      await tester.enterText(find.byType(TextField), "new-app");
      await tester.pumpAndSettle();

      // Tap "Create Project"
      await tester.tap(find.text("Create Project"));
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
      // Use a Completer that never completes — keeps loading state active
      // without creating a pending Timer.
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
      await tester.pump(); // Just one frame — don't settle, to keep loading

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });
}
