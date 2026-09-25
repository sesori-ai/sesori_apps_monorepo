import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:path/path.dart" as p;
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

class MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

late ConnectionService _testConnectionService;

/// The projects the dialog opened after adding them, by display name.
final _openedProjects = <String>[];

Future<void> _showAddProjectDialog(BuildContext context, ProjectListCubit cubit) => showAddProjectDialog(
  context: context,
  cubit: cubit,
  connectionService: _testConnectionService,
  onProjectAdded: ({required context, required project, required displayName}) => _openedProjects.add(displayName),
);

const _addedProject = ProjectSummary(id: "my-repo", name: null, path: "/home/user/my-repo", time: null);

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
            onPressed: () => _showAddProjectDialog(context, context.read<ProjectListCubit>()),
            child: const Icon(TablerRegular.plus),
          ),
          body: switch (state) {
            ProjectListLoading() => Center(
              child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
            ),
            ProjectListLoaded() => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.noProjects),
                  const SizedBox(height: 8),
                  Text(loc.addProjectPrompt),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showAddProjectDialog(context, context.read<ProjectListCubit>()),
                    icon: const Icon(TablerRegular.plus),
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

/// The action menu's labelled action. Its label names the folder, so it is
/// found by its glyph.
final Finder _addButton = find.widgetWithIcon(PregoButtonsSolid, TablerRegular.plus);

/// The action menu's other action, which is icon-only — so it is found by the
/// glyph that carries it.
final Finder _createFolderButton = find.widgetWithIcon(PregoButtonsSolid, TablerRegular.folder_plus);

/// The action-menu button [finder] resolves to, for asserting on its enabled
/// state.
PregoButtonsSolid _button(WidgetTester tester, Finder finder) => tester.widget<PregoButtonsSolid>(finder);

/// The quick-navigation button labelled [label] in the row above the breadcrumb.
Finder _placeButton(String label) => find.widgetWithText(PregoButtonsSolid, label);

/// The icon-only up button at the start of the breadcrumb.
final Finder _upButton = find.widgetWithIcon(PregoButtonsSolid, TablerRegular.arrow_up);

/// A screen whose one button opens the add-project dialog.
Widget _buildOpenerApp({required ProjectListCubit cubit}) => _buildApp(
  cubit: cubit,
  child: Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => _showAddProjectDialog(context, cubit),
        child: const Text("Open"),
      ),
    ),
  ),
);

/// The breadcrumb's Home segment. The Home place button comes first in the
/// tree, so the breadcrumb's is the last "Home".
final Finder _breadcrumbHome = find.text("Home").last;

void main() {
  setUpAll(() {
    registerCoreFallbackValues();
    registerFallbackValue(OpenProjectGitAction.promptIfNeeded);
  });

  late MockProjectListCubit mockCubit;
  late MockConnectionService mockConnectionService;
  late BehaviorSubject<ConnectionStatus> connectionStatusController;

  void stubConnectionStatus(ConnectionStatus status) {
    connectionStatusController.add(status);
    when(() => mockConnectionService.status).thenAnswer((_) => connectionStatusController);
    when(() => mockConnectionService.currentStatus).thenReturn(status);
  }

  setUp(() {
    _openedProjects.clear();
    mockCubit = MockProjectListCubit();
    mockConnectionService = MockConnectionService();
    // A POSIX host by default; tests that need another hierarchy stub over it.
    when(() => mockCubit.parentHostPath(path: any(named: "path"))).thenAnswer((invocation) {
      final path = invocation.namedArguments[const Symbol("path")] as String;
      final parent = p.posix.dirname(path);
      return parent == path ? null : parent;
    });
    _testConnectionService = mockConnectionService;
    connectionStatusController = BehaviorSubject<ConnectionStatus>.seeded(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
        health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
      ),
    );
    // Default: connected with no degraded filesystem access.
    stubConnectionStatus(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
        health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
      ),
    );
  });

  tearDown(() => connectionStatusController.close());

  // -------------------------------------------------------------------------
  // FAB
  // -------------------------------------------------------------------------

  group("FAB", () {
    testWidgets("opens add project dialog when tapped", (tester) async {
      when(() => mockCubit.state).thenReturn(
        const ProjectListState.loaded(projects: []),
      );
      _stubSuggestionsWithEntries(mockCubit, entries: _homeDirEntries, path: _homePath);

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Single view — titled, with the bridge-returned host path as a
      // breadcrumb over the listing, under the Home and Root buttons.
      expect(find.descendant(of: find.byType(AddProjectDialog), matching: find.text("Add project")), findsOneWidget);
      expect(find.text("Home"), findsNWidgets(2));
      expect(find.text("projects"), findsOneWidget);
      expect(find.widgetWithText(PregoButtonsSolid, "Add user"), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Filesystem-access warning banner (scoped to this sheet)
  // -------------------------------------------------------------------------

  group("Filesystem-access banner", () {
    testWidgets("shows the limited-folder-access warning when the bridge reports degraded access", (tester) async {
      stubConnectionStatus(
        const ConnectionStatus.connected(
          config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
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
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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
      // Default stubbed status has filesystemAccessDegraded: false.
      _stubSuggestionsWithEntries(mockCubit, entries: _homeDirEntries);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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
        const ProjectListState.loaded(projects: []),
      );

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      expect(find.text("No projects"), findsOneWidget);
      expect(find.text("Add a project to get started"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "Add project"), findsOneWidget);
    });

    testWidgets("empty state add button opens dialog", (tester) async {
      when(() => mockCubit.state).thenReturn(
        const ProjectListState.loaded(projects: []),
      );
      _stubSuggestionsWithEntries(mockCubit, entries: _homeDirEntries);

      await tester.pumpWidget(_buildProjectListShell(cubit: mockCubit));

      await tester.tap(find.widgetWithText(FilledButton, "Add project"));
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
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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

    testWidgets("starting folder reads Home in the breadcrumb and remains navigable and writable", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": const [],
          "/home": const [],
        },
      );
      when(() => mockCubit.parentHostPath(path: _homePath)).thenReturn("/home");

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // The path comes from the bridge response, so it is bound to the host
      // serving the filesystem request. The folders above Home collapse into
      // it, and the root stays reachable ahead of it.
      expect(find.text("/"), findsOneWidget);
      expect(find.text("Home"), findsNWidgets(2));
      expect(find.text("home"), findsNothing);
      expect(find.byIcon(TablerRegular.arrow_left), findsNothing);

      expect(_button(tester, _addButton).onPressed, isNotNull);
      expect(_button(tester, _createFolderButton).onPressed, isNotNull);

      await tester.tap(find.text("/"));
      await tester.pumpAndSettle();

      verify(() => mockCubit.fetchFilesystemSuggestions(prefix: "/")).called(1);
    });

    testWidgets("tapping a directory entry navigates into it", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/projects": _projectsDirEntries,
        },
      );
      when(() => mockCubit.parentHostPath(path: "/home/user/projects")).thenReturn(_homePath);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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
      // The breadcrumb follows, with the folder being browsed last.
      expect(find.text("Home"), findsNWidgets(2));
      expect(find.text("projects"), findsOneWidget);
      expect(find.widgetWithText(PregoButtonsSolid, "Add projects"), findsOneWidget);
      expect(find.byIcon(TablerRegular.arrow_left), findsNothing);
      expect(
        tester.getTopLeft(find.text("projects")).dy,
        lessThan(tester.getTopLeft(find.text("app-one")).dy),
      );
    });

    testWidgets("tapping a breadcrumb segment opens that folder", (tester) async {
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
      when(() => mockCubit.parentHostPath(path: _homePath)).thenReturn("/home");

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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

      await tester.tap(_breadcrumbHome);
      await tester.pumpAndSettle();

      expect(find.text("projects"), findsOneWidget);
      expect(find.text("work"), findsOneWidget);
      // The starting folder is only the initial location; its parent remains
      // reachable through the breadcrumb's root.
      expect(find.text("/"), findsOneWidget);
      expect(find.byIcon(TablerRegular.arrow_left), findsNothing);
    });

    testWidgets("the breadcrumb reaches the root and names folders outside Home", (tester) async {
      const rootEntries = [
        FilesystemSuggestion(path: "/home", name: "home", isGitRepo: false),
      ];
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home/user/projects": _projectsDirEntries,
          _homePath: _homeDirEntries,
          "/": rootEntries,
        },
      );
      when(() => mockCubit.parentHostPath(path: "/home/user/projects")).thenReturn(_homePath);
      when(() => mockCubit.parentHostPath(path: _homePath)).thenReturn("/home");
      when(() => mockCubit.parentHostPath(path: "/home")).thenReturn("/");
      when(() => mockCubit.parentHostPath(path: "/")).thenReturn(null);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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

      await tester.tap(find.text("/"));
      await tester.pumpAndSettle();
      // At the root the breadcrumb is the root alone, and the listing names
      // the folders under it. Only the Home button still reads Home.
      expect(find.text("Home"), findsOneWidget);
      expect(find.text("/"), findsOneWidget);
      expect(find.text("home"), findsOneWidget);

      // Outside Home, every folder reads by its own name.
      await tester.tap(find.text("home"));
      await tester.pumpAndSettle();
      expect(find.text("home"), findsOneWidget);
      expect(find.text("Home"), findsOneWidget);
      expect(find.widgetWithText(PregoButtonsSolid, "Add home"), findsOneWidget);
    });

    testWidgets("a Windows bridge's drives sit beside Home and open that drive", (tester) async {
      const windowsHome = r"C:\Users\dev";
      const driveEntries = [
        FilesystemSuggestion(path: r"D:\games", name: "games", isGitRepo: false),
      ];
      when(() => mockCubit.fetchFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer((invocation) async {
        final prefix = invocation.namedArguments[const Symbol("prefix")] as String?;
        return FilesystemSuggestionsSuccess(
          suggestions: prefix == null
              ? const FilesystemSuggestions(data: [], path: windowsHome, driveRoots: [r"C:\", r"D:\"])
              : FilesystemSuggestions(data: prefix == r"D:\" ? driveEntries : const [], path: prefix),
        );
      });
      when(() => mockCubit.parentHostPath(path: windowsHome)).thenReturn(r"C:\Users");
      when(() => mockCubit.parentHostPath(path: r"C:\Users")).thenReturn(r"C:\");
      when(() => mockCubit.parentHostPath(path: r"C:\")).thenReturn(null);
      when(() => mockCubit.parentHostPath(path: r"D:\")).thenReturn(null);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      // Home and each drive are buttons in place of Root; C:\ and Home also
      // lead the breadcrumb.
      expect(_placeButton("Home"), findsOneWidget);
      expect(_placeButton(r"C:\"), findsOneWidget);
      expect(_placeButton(r"D:\"), findsOneWidget);
      expect(find.text("Root"), findsNothing);
      expect(find.text("Home"), findsNWidgets(2));
      expect(find.text(r"C:\"), findsNWidgets(2));
      // Home is where the browser starts, so its button is disabled.
      expect(_button(tester, _placeButton("Home")).onPressed, isNull);
      expect(_button(tester, _placeButton(r"D:\")).onPressed, isNotNull);

      await tester.tap(_placeButton(r"D:\"));
      await tester.pumpAndSettle();

      verify(() => mockCubit.fetchFilesystemSuggestions(prefix: r"D:\")).called(1);
      expect(find.text("games"), findsOneWidget);
      expect(find.widgetWithText(PregoButtonsSolid, r"Add D:\"), findsOneWidget);
      expect(_button(tester, _placeButton(r"D:\")).onPressed, isNull);

      // The drives stay listed while browsing, so Home is one tap away.
      await tester.tap(_placeButton("Home"));
      await tester.pumpAndSettle();
      verify(() => mockCubit.fetchFilesystemSuggestions(prefix: windowsHome)).called(1);
    });

    testWidgets("a POSIX host lists Home and Root, disabling the one being browsed", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/": const [FilesystemSuggestion(path: "/home", name: "home", isGitRepo: false)],
          _homePath: _homeDirEntries,
        },
      );

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(_placeButton("Home"), findsOneWidget);
      expect(_placeButton("Root"), findsOneWidget);
      expect(_button(tester, _placeButton("Home")).onPressed, isNull);
      expect(_button(tester, _placeButton("Root")).onPressed, isNotNull);

      // Root is the host root the starting folder resolves to.
      await tester.tap(_placeButton("Root"));
      await tester.pumpAndSettle();
      verify(() => mockCubit.fetchFilesystemSuggestions(prefix: "/")).called(1);
      expect(find.text("home"), findsOneWidget);
      expect(_button(tester, _placeButton("Home")).onPressed, isNotNull);
      expect(_button(tester, _placeButton("Root")).onPressed, isNull);

      await tester.tap(_placeButton("Home"));
      await tester.pumpAndSettle();
      verify(() => mockCubit.fetchFilesystemSuggestions(prefix: _homePath)).called(1);
      expect(_button(tester, _placeButton("Home")).onPressed, isNull);
    });

    testWidgets("the up button opens the parent folder and is disabled at the root", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home": const [FilesystemSuggestion(path: _homePath, name: "user", isGitRepo: false)],
          "/": const [FilesystemSuggestion(path: "/home", name: "home", isGitRepo: false)],
        },
      );

      await tester.pumpWidget(_buildOpenerApp(cubit: mockCubit));
      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel("Parent folder"), findsOneWidget);
      expect(_button(tester, _upButton).onPressed, isNotNull);

      // From Home, up leaves the starting folder for its real parent.
      await tester.tap(_upButton);
      await tester.pumpAndSettle();
      verify(() => mockCubit.fetchFilesystemSuggestions(prefix: "/home")).called(1);
      expect(find.text("user"), findsOneWidget);

      await tester.tap(_upButton);
      await tester.pumpAndSettle();
      verify(() => mockCubit.fetchFilesystemSuggestions(prefix: "/")).called(1);

      // The root has no parent, so the button stays in place but disabled.
      expect(_upButton, findsOneWidget);
      expect(_button(tester, _upButton).onPressed, isNull);
      // Screen readers hear a disabled button, not static text.
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel("Parent folder")),
        isSemantics(label: "Parent folder", isButton: true, hasEnabledState: true, isEnabled: false),
      );
      semantics.dispose();
    });

    testWidgets("on touch the up button draws at 40 but keeps a 44 tap target", (tester) async {
      _stubSuggestionsPerPrefix(
        mockCubit,
        byPrefix: {
          "": _homeDirEntries,
          "/home": const [FilesystemSuggestion(path: _homePath, name: "user", isGitRepo: false)],
        },
      );

      await tester.pumpWidget(_buildOpenerApp(cubit: mockCubit));
      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(tester.getSize(_upButton), const Size(40, 40));

      // Screen readers get one button node covering the whole 44 target.
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel("Parent folder"), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel("Parent folder"));
      expect(node, isSemantics(label: "Parent folder", isButton: true, hasTapAction: true));
      expect(node.rect.size, const Size(44, 44));
      semantics.dispose();

      // A tap just above the drawn button, inside the 44 target, still goes up.
      await tester.tapAt(tester.getCenter(_upButton) - const Offset(0, 21));
      await tester.pumpAndSettle();
      verify(() => mockCubit.fetchFilesystemSuggestions(prefix: "/home")).called(1);
    });

    testWidgets("a short breadcrumb segment gets a touch-sized tap target", (tester) async {
      _stubSuggestionsPerPrefix(mockCubit, byPrefix: {"": _homeDirEntries});

      await tester.pumpWidget(_buildOpenerApp(cubit: mockCubit));
      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      final rootSegment = find.ancestor(of: find.text("/"), matching: find.byType(InkWell));
      final size = tester.getSize(rootSegment);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      // A tap below the glyph, outside its drawn padding, still opens the root.
      await tester.tapAt(tester.getCenter(find.text("/")) + const Offset(0, 18));
      await tester.pumpAndSettle();
      verify(() => mockCubit.fetchFilesystemSuggestions(prefix: "/")).called(1);
    });

    testWidgets("under a pointer a breadcrumb segment gets a pointer-sized tap target", (tester) async {
      _stubSuggestionsPerPrefix(mockCubit, byPrefix: {"": _homeDirEntries});

      await tester.pumpWidget(
        PregoInteractionScope(
          mode: PregoInteractionMode.pointer,
          child: _buildOpenerApp(cubit: mockCubit),
        ),
      );
      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.ancestor(of: find.text("/"), matching: find.byType(InkWell)));
      expect(size.width, greaterThanOrEqualTo(32));
      expect(size.height, greaterThanOrEqualTo(32));
    });

    testWidgets("a listing that lands after stepping back out is ignored", (tester) async {
      // Stepping into a folder and back out again leaves the deeper listing in
      // flight: it answers a folder that is no longer being browsed, so filling
      // the browser with it would put another folder's rows under this header.
      final projectsListing = Completer<FilesystemSuggestionsOutcome>();
      when(() => mockCubit.fetchFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer((invocation) {
        final prefix = invocation.namedArguments[const Symbol("prefix")] as String?;
        if (prefix == "/home/user/projects") return projectsListing.future;
        return Future.value(
          FilesystemSuggestionsSuccess(
            suggestions: FilesystemSuggestions(data: _homeDirEntries, path: prefix ?? _homePath),
          ),
        );
      });
      when(() => mockCubit.parentHostPath(path: "/home/user/projects")).thenReturn(_homePath);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("projects"));
      await tester.pump();
      await tester.tap(_breadcrumbHome);
      await tester.pumpAndSettle();

      projectsListing.complete(
        const FilesystemSuggestionsSuccess(
          suggestions: FilesystemSuggestions(data: _projectsDirEntries, path: "/home/user/projects"),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("app-one"), findsNothing);
      expect(find.text("work"), findsOneWidget);
      expect(find.widgetWithText(PregoButtonsSolid, "Add user"), findsOneWidget);
    });

    testWidgets("the add button names the browsed folder and adds it", (tester) async {
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
      ).thenAnswer((_) async => const OpenProjectAdded(project: _addedProject));

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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

      expect(find.widgetWithText(PregoButtonsSolid, "Add my-repo"), findsOneWidget);
      await tester.tap(_addButton);
      await tester.pumpAndSettle();

      verify(
        () => mockCubit.discoverProject(
          path: "/home/user/my-repo",
          gitAction: OpenProjectGitAction.promptIfNeeded,
        ),
      ).called(1);

      // The confirmation outlives the sheet, so it has to be raised on the
      // screen's messenger rather than the one the sheet hosts for itself.
      expect(_addButton, findsNothing);
      expect(find.text("Project discovered"), findsOneWidget);
      expect(_openedProjects, ["my-repo"]);
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
      ).thenAnswer((_) async => const OpenProjectGitChoiceRequired());
      when(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.initializeGit,
        ),
      ).thenAnswer((_) async => const OpenProjectAdded(project: _addedProject));

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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
      expect(find.text("Continue without Git"), findsOneWidget);
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
      ).thenAnswer((_) async => const OpenProjectGitChoiceRequired());
      when(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.openWithoutGit,
        ),
      ).thenAnswer((_) async => const OpenProjectAdded(project: _addedProject));

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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
      await tester.tap(find.text("Continue without Git"));
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
      ).thenAnswer((_) async => const OpenProjectGitChoiceRequired());
      when(
        () => mockCubit.discoverProject(
          path: "/home/user/work",
          gitAction: OpenProjectGitAction.initializeGit,
        ),
      ).thenAnswer((_) async => const OpenProjectGitSetupIncomplete(project: _addedProject));

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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
      expect(_openedProjects, ["my-repo"]);
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
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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
        () => mockCubit.discoverProject(
          path: any(named: "path"),
          gitAction: any(named: "gitAction"),
        ),
      );
      expect(find.text("new-app"), findsOneWidget);
      expect(find.widgetWithText(PregoButtonsSolid, "Add new-app"), findsOneWidget);
      expect(find.text("No folders here"), findsOneWidget);
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
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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

    testWidgets("a folder without subfolders says so, and that files are not listed", (tester) async {
      _stubSuggestionsWithEntries(mockCubit, entries: const []);

      await tester.pumpWidget(
        _buildApp(
          cubit: mockCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => _showAddProjectDialog(context, mockCubit),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();

      expect(find.text("No folders here"), findsOneWidget);
      expect(find.text("Only folders are listed, so any files in it stay hidden."), findsOneWidget);
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
                onPressed: () => _showAddProjectDialog(context, mockCubit),
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
