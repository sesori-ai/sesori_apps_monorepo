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
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
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

/// The folder the stubbed bridge starts the browser in, mirroring the real
/// bridge's prefix-less first answer.
const _homePath = "/home/user";

void _stubSuggestionsWithEntries(
  MockProjectListCubit cubit, {
  required List<FilesystemSuggestion> entries,
  String? path,
}) {
  when(
    () => cubit.fetchFilesystemSuggestions(prefix: any(named: "prefix")),
  ).thenAnswer(
    (_) async => FilesystemSuggestionsSuccess(
      suggestions: FilesystemSuggestions(data: entries, path: path),
    ),
  );
}

void _stubSuggestionsPerPrefix(
  MockProjectListCubit cubit, {
  required Map<String, List<FilesystemSuggestion>> byPrefix,
  String rootPath = _homePath,
}) {
  when(() => cubit.fetchFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer((invocation) async {
    final prefix = invocation.namedArguments[const Symbol("prefix")] as String?;
    return FilesystemSuggestionsSuccess(
      // The bridge always names the folder it listed; the prefix-less first
      // call is how the browser learns where it starts.
      suggestions: FilesystemSuggestions(data: byPrefix[prefix ?? ""] ?? [], path: prefix ?? rootPath),
    );
  });
}

/// The action menu's labelled action.
final Finder _addButton = find.widgetWithText(PregoButtonsSolid, "Add as new project");

/// The action menu's other action, which is icon-only — so it is found by the
/// glyph that carries it.
final Finder _createFolderButton = find.widgetWithIcon(PregoButtonsSolid, TablerRegular.folder_plus);

/// The action-menu button [finder] resolves to, for asserting on its enabled
/// state.
PregoButtonsSolid _button(WidgetTester tester, Finder finder) => tester.widget<PregoButtonsSolid>(finder);

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
    // The browser heads its listing with the machine the bridge runs on.
    when(() => mockCubit.hostMachineName()).thenAnswer((_) async => "MacBook-Pro.local");
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

      // Single view — the machine heads the listing, with both actions below.
      expect(find.text("MacBook-Pro.local"), findsOneWidget);
      expect(find.text("projects"), findsOneWidget);
      expect(find.text("Add as new project"), findsOneWidget);
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

      expect(_addButton, findsOneWidget);
      expect(_createFolderButton, findsOneWidget);
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

      // Git tag — the bridge only reports that a repository is there, so the
      // label stays "Git" even though the glyph is GitHub's.
      expect(find.text("Git"), findsOneWidget);

      // Both action buttons
      expect(_addButton, findsOneWidget);
      expect(_createFolderButton, findsOneWidget);
    });

    testWidgets("starting folder is addable but cannot be written into", (tester) async {
      _stubSuggestionsWithEntries(
        mockCubit,
        entries: const [],
        path: _homePath,
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

      // The machine names the starting folder, and there is nowhere to go back
      // to from it.
      expect(find.text("MacBook-Pro.local"), findsOneWidget);
      expect(find.byIcon(TablerRegular.arrow_left), findsNothing);

      expect(_button(tester, _addButton).onPressed, isNotNull);
      expect(_button(tester, _createFolderButton).onPressed, isNull);
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
      // The bar follows the browser: the folder heads it, and the path below
      // reads from the machine down rather than from the filesystem root.
      expect(find.text("projects"), findsOneWidget);
      expect(find.text("MacBook-Pro.local/projects"), findsOneWidget);
      expect(find.byIcon(TablerRegular.arrow_left), findsOneWidget);
    });

    testWidgets("back button navigates up one directory level", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/projects": _projectsDirEntries,
          _homePath: _homeDirEntries,
        },
      );
      when(
        () => mockCubit.parentHostPath(path: "/home/user/projects"),
      ).thenReturn(_homePath);

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

      await tester.tap(find.byIcon(TablerRegular.arrow_left));
      await tester.pumpAndSettle();

      expect(find.text("projects"), findsOneWidget);
      expect(find.text("work"), findsOneWidget);
      // Back at the starting folder, so the way further up is gone again.
      expect(find.byIcon(TablerRegular.arrow_left), findsNothing);
    });

    testWidgets("Add as new project calls discoverProject with browsed path", (tester) async {
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
      await tester.tap(_addButton);
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
      await tester.tap(_addButton);
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
      await tester.tap(_addButton);
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
      await tester.tap(_addButton);
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
      expect(_addButton, findsNothing);
    });

    testWidgets("Create new folder makes it in the browsed dir and steps into it", (tester) async {
      const newFolderPath = "/home/user/projects/new-app";
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/projects": _projectsDirEntries,
          newFolderPath: const [],
        },
      );
      when(
        () => mockCubit.createDirectory(
          parentPath: any(named: "parentPath"),
          name: any(named: "name"),
        ),
      ).thenAnswer(
        (_) async => const CreateDirectorySuccess(
          directory: FilesystemSuggestion(path: newFolderPath, name: "new-app", isGitRepo: false),
        ),
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

      await tester.tap(_createFolderButton);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "new-app");
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PregoButtonsSolid, "Create"));
      await tester.pumpAndSettle();

      verify(
        () => mockCubit.createDirectory(
          parentPath: "/home/user/projects",
          name: "new-app",
        ),
      ).called(1);

      // Only the folder was made: the browser moves into it and leaves adding
      // it as a project to the user's next tap.
      verifyNever(
        () => mockCubit.discoverProject(path: any(named: "path"), gitAction: any(named: "gitAction")),
      );
      expect(find.text("new-app"), findsOneWidget);
      expect(find.text("MacBook-Pro.local/projects/new-app"), findsOneWidget);
      expect(find.text("This directory is empty"), findsOneWidget);
    });

    testWidgets("a bridge without the create-folder endpoint says so", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/projects": _projectsDirEntries,
        },
      );
      when(
        () => mockCubit.createDirectory(
          parentPath: any(named: "parentPath"),
          name: any(named: "name"),
        ),
      ).thenAnswer((_) async => const CreateDirectoryUnsupported());

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
      await tester.tap(_createFolderButton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), "new-app");
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PregoButtonsSolid, "Create"));
      await tester.pumpAndSettle();

      // Retrying will not help, so the message points at the fix.
      expect(find.textContaining("Update Sesori Bridge"), findsOneWidget);
      // The browser stays where it was.
      expect(find.text("app-one"), findsOneWidget);
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

    testWidgets("loading state holds the row shape with skeleton bars", (tester) async {
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

      expect(find.byType(PregoSkeletonBar), findsWidgets);
    });
  });
}
