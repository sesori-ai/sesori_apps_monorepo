import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/project_list/add_project_dialog.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

class MockProjectListCubit extends MockCubit<ProjectListState> implements ProjectListCubit {}

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

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      await tester.tap(find.widgetWithText(FilledButton, "Add Project"));
      await tester.pumpAndSettle();

      expect(find.text("Create New"), findsOneWidget);
      expect(find.text("Discover Existing"), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Test 4: Add project dialog renders with two tabs
  // -------------------------------------------------------------------------

  group("AddProjectDialog", () {
    testWidgets("renders with Create New and Discover Existing tabs", (tester) async {
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

      // Path input visible in the first tab
      expect(find.text("Enter directory path"), findsOneWidget);

      // Create Project button visible in the first tab
      expect(find.text("Create Project"), findsOneWidget);
    });

    testWidgets("switching to Discover tab shows Discover Project button", (tester) async {
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

      expect(find.text("Discover Project"), findsOneWidget);
    });
  });
}
