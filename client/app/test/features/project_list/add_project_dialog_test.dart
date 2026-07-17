import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/project_list/add_project_dialog.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

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
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => BlocProvider<ProjectListCubit>.value(
          value: cubit,
          child: child,
        ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(
      colorScheme: PregoColors.light.toFlutterColorScheme(),
      textTheme: PregoTextTheme.light.asFlutterTextTheme(),
      fontFamily: PregoTextTheme.fontFamily,
      fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
      extensions: [PregoDesignSystem.light],
    ),
    darkTheme: ThemeData(
      colorScheme: PregoColors.dark.toFlutterColorScheme(),
      textTheme: PregoTextTheme.dark.asFlutterTextTheme(),
      fontFamily: PregoTextTheme.fontFamily,
      fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
      extensions: [PregoDesignSystem.dark],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

/// A minimal host for the add-project entry points — the FAB and the
/// empty-state call to action. It deliberately does not stand in for
/// [ProjectListScreen]: tests that exercise the real list (tiles, their
/// long-press menu) pump the screen itself.
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
            ProjectListLoaded() => Center(
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
            ),
            ProjectListFailed() => const Text("Error"),
            ProjectListBridgeDisconnected() => const Text("Bridge disconnected"),
          },
        );
      },
    ),
  );
}

void _stubSuggestionsWithEntries(
  MockProjectListCubit cubit, {
  required List<FilesystemSuggestion> entries,
}) {
  when(
    () => cubit.fetchFilesystemSuggestions(prefix: any(named: "prefix")),
  ).thenAnswer(
    (_) async => FilesystemSuggestionsSuccess(suggestions: FilesystemSuggestions(data: entries)),
  );
}

void _stubSuggestionsPerPrefix(
  MockProjectListCubit cubit, {
  required Map<String, List<FilesystemSuggestion>> byPrefix,
}) {
  when(() => cubit.fetchFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer((invocation) async {
    final prefix = invocation.namedArguments[const Symbol("prefix")] as String?;
    return FilesystemSuggestionsSuccess(suggestions: FilesystemSuggestions(data: byPrefix[prefix ?? ""] ?? []));
  });
}

void main() {
  setUpAll(() {
    registerFallbackValue(OpenProjectGitAction.promptIfNeeded);
  });

  late MockProjectListCubit mockCubit;
  late MockProjectRepository mockProjectRepository;
  late MockConnectionService mockConnectionService;
  late BehaviorSubject<ConnectionStatus> connectionStatusController;

  void stubConnectionStatus(ConnectionStatus status) {
    connectionStatusController.add(status);
    when(() => mockConnectionService.status).thenAnswer((_) => connectionStatusController);
    when(() => mockConnectionService.currentStatus).thenReturn(status);
  }

  setUp(() {
    mockCubit = MockProjectListCubit();
    mockProjectRepository = MockProjectRepository();
    mockConnectionService = MockConnectionService();
    connectionStatusController = BehaviorSubject<ConnectionStatus>.seeded(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com"),
        health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null),
      ),
    );
    // Default: connected with no degraded filesystem access.
    stubConnectionStatus(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com"),
        health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null),
      ),
    );

    final getIt = GetIt.instance;
    if (getIt.isRegistered<ProjectRepository>()) {
      getIt.unregister<ProjectRepository>();
    }
    getIt.registerSingleton<ProjectRepository>(mockProjectRepository);
    registerListServices(
      projectRepository: mockProjectRepository,
    );
    if (getIt.isRegistered<ConnectionService>()) {
      getIt.unregister<ConnectionService>();
    }
    getIt.registerSingleton<ConnectionService>(mockConnectionService);
  });

  tearDown(() async {
    await connectionStatusController.close();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ProjectRepository>()) {
      getIt.unregister<ProjectRepository>();
    }
    if (getIt.isRegistered<ConnectionService>()) {
      getIt.unregister<ConnectionService>();
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
      _stubSuggestionsWithEntries(mockCubit, entries: _homeDirEntries);

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
  // Filesystem-access warning banner (scoped to this sheet)
  // -------------------------------------------------------------------------

  group("Filesystem-access banner", () {
    testWidgets("shows the limited-folder-access warning when the bridge reports degraded access", (tester) async {
      stubConnectionStatus(
        const ConnectionStatus.connected(
          config: ServerConnectionConfig(relayHost: "relay.example.com"),
          health: HealthResponse(healthy: true, version: "1.0.0", filesystemAccessDegraded: true),
        ),
      );
      _stubSuggestionsWithEntries(mockCubit, entries: _homeDirEntries);

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

      expect(find.text("Limited folder access"), findsOneWidget);
    });

    testWidgets("hides the warning when filesystem access is not degraded", (tester) async {
      // Default stubbed status has filesystemAccessDegraded: null.
      _stubSuggestionsWithEntries(mockCubit, entries: _homeDirEntries);

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

      expect(find.text("Limited folder access"), findsNothing);
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
      _stubSuggestionsWithEntries(mockCubit, entries: _homeDirEntries);

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
      _stubSuggestionsWithEntries(mockCubit, entries: _homeDirEntries);

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
        mockCubit,
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
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/projects": _projectsDirEntries,
          "/home/user": _homeDirEntries,
        },
      );
      when(
        () => mockCubit.parentHostPath(path: "/home/user/projects"),
      ).thenReturn("/home/user");

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
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/my-repo": const [],
        },
      );
      when(
        () => mockCubit.discoverProject(
          path: any(named: "path"),
          gitAction: OpenProjectGitAction.promptIfNeeded,
        ),
      ).thenAnswer((_) async => OpenProjectOutcome.success);

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

      verify(
        () => mockCubit.discoverProject(
          path: "/home/user/my-repo",
          gitAction: OpenProjectGitAction.promptIfNeeded,
        ),
      ).called(1);
    });

    testWidgets("non-Git folder prompt can enable Git before opening", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/work": const [],
        },
      );
      when(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.promptIfNeeded,
        ),
      ).thenAnswer((_) async => OpenProjectOutcome.gitChoiceRequired);
      when(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.initializeGit,
        ),
      ).thenAnswer((_) async => OpenProjectOutcome.success);

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
      await tester.tap(find.text("work"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Open as Project"));
      await tester.pumpAndSettle();

      expect(find.text("Enable Git tracking?"), findsOneWidget);
      expect(find.text("Continue Without Git"), findsOneWidget);
      expect(find.text("Enable Git"), findsOneWidget);

      await tester.tap(find.text("Enable Git"));
      await tester.pumpAndSettle();

      verify(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.initializeGit,
        ),
      ).called(1);
    });

    testWidgets("non-Git folder prompt can continue without Git", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/work": const [],
        },
      );
      when(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.promptIfNeeded,
        ),
      ).thenAnswer((_) async => OpenProjectOutcome.gitChoiceRequired);
      when(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.openWithoutGit,
        ),
      ).thenAnswer((_) async => OpenProjectOutcome.success);

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
      await tester.tap(find.text("work"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Open as Project"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Continue Without Git"));
      await tester.pumpAndSettle();

      verify(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.openWithoutGit,
        ),
      ).called(1);
    });

    testWidgets("incomplete Git setup requires acknowledgment after opening", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/work": const [],
        },
      );
      when(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.promptIfNeeded,
        ),
      ).thenAnswer((_) async => OpenProjectOutcome.gitChoiceRequired);
      when(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.initializeGit,
        ),
      ).thenAnswer((_) async => OpenProjectOutcome.gitSetupIncomplete);

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
      await tester.tap(find.text("work"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Open as Project"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Enable Git"));
      await tester.pumpAndSettle();

      expect(find.text("Project opened, Git setup incomplete"), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text("Project opened, Git setup incomplete"), findsOneWidget);

      await tester.tap(find.text("I understand"));
      await tester.pumpAndSettle();
      expect(find.text("Project opened, Git setup incomplete"), findsNothing);
      expect(find.text("Open as Project"), findsNothing);
    });

    testWidgets("Create constructs path from browsed dir + typed name", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/projects": _projectsDirEntries,
        },
      );
      when(
        () => mockCubit.createProject(
          parentPath: any(named: "parentPath"),
          name: any(named: "name"),
        ),
      ).thenAnswer((_) async => AddProjectOutcome.success);

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

      verify(
        () => mockCubit.createProject(
          parentPath: "/home/user/projects",
          name: "new-app",
        ),
      ).called(1);
    });

    testWidgets("Create passes the Windows host parent and project name as intent", (tester) async {
      const projectsPath = r"C:\Users\dev\projects";
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": const [
            FilesystemSuggestion(path: projectsPath, name: "projects", isGitRepo: false),
          ],
          projectsPath: const [],
        },
      );
      when(
        () => mockCubit.createProject(
          parentPath: any(named: "parentPath"),
          name: any(named: "name"),
        ),
      ).thenAnswer((_) async => AddProjectOutcome.success);

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
      await tester.enterText(find.byType(TextField), "new-app");
      await tester.pumpAndSettle();
      await tester.tap(find.text("Create"));
      await tester.pumpAndSettle();

      verify(
        () => mockCubit.createProject(
          parentPath: projectsPath,
          name: "new-app",
        ),
      ).called(1);
    });

    testWidgets("empty directory shows empty state message", (tester) async {
      _stubSuggestionsWithEntries(mockCubit, entries: const []);

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
        () => mockCubit.fetchFilesystemSuggestions(prefix: any(named: "prefix")),
      ).thenAnswer((_) => Completer<FilesystemSuggestionsOutcome>().future);

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
