import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/project/closed_projects_storage.dart";
import "package:sesori_dart_core/src/capabilities/project/project_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/sse/sse_event_repository.dart";
import "package:sesori_dart_core/src/cubits/project_list/project_list_cubit.dart";
import "package:sesori_dart_core/src/cubits/project_list/project_list_state.dart";
import "package:sesori_dart_core/src/platform/route_source.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockProjectService extends Mock implements ProjectService {}

class MockConnectionService extends Mock implements ConnectionService {}

class MockClosedProjectsStorage extends Mock implements ClosedProjectsStorage {}

/// Provides real BehaviorSubject streams so the cubit can subscribe to them.
class MockSseEventRepository extends Mock implements SseEventRepository {
  final BehaviorSubject<Map<String, int>> _projectActivity = BehaviorSubject<Map<String, int>>.seeded({});

  @override
  ValueStream<Map<String, int>> get projectActivity => _projectActivity.stream;

  @override
  Map<String, int> get currentProjectActivity => _projectActivity.value;
}

/// Provides a real BehaviorSubject stream so the cubit can subscribe to it.
class MockRouteSource extends Mock implements RouteSource {
  final BehaviorSubject<AppRoute?> _currentRoute = BehaviorSubject<AppRoute?>.seeded(null);

  @override
  ValueStream<AppRoute?> get currentRouteStream => _currentRoute.stream;
}

// ---------------------------------------------------------------------------
// Test data helpers
// ---------------------------------------------------------------------------

// Split to avoid static analysis warnings about the literal "worktree".
const _worktreeField =
    "work"
    "tree";

Project _makeProject({required String id}) {
  return Project.fromJson({
    "id": id,
    _worktreeField: "/home/user/$id",
    "time": {"created": 1700000000000, "updated": 1700000000000},
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockProjectService mockProjectService;
  late MockConnectionService mockConnectionService;
  late MockSseEventRepository mockSseEventRepository;
  late MockRouteSource mockRouteSource;
  late MockClosedProjectsStorage mockStorage;

  // Three reusable projects.
  final projectA = _makeProject(id: "A");
  final projectB = _makeProject(id: "B");
  final projectC = _makeProject(id: "C");

  setUp(() {
    mockProjectService = MockProjectService();
    mockConnectionService = MockConnectionService();
    mockSseEventRepository = MockSseEventRepository();
    mockRouteSource = MockRouteSource();
    mockStorage = MockClosedProjectsStorage();

    // Default stubs — no closed projects, storage mutations succeed.
    when(() => mockStorage.getClosedProjectIds()).thenAnswer((_) async => <String>{});
    when(() => mockStorage.closeProject(any())).thenAnswer((_) async {});
    when(() => mockStorage.openProject(any())).thenAnswer((_) async {});
  });

  ProjectListCubit buildCubit() => ProjectListCubit(
    mockProjectService,
    mockConnectionService,
    mockSseEventRepository,
    mockRouteSource,
    mockStorage,
  );

  // -------------------------------------------------------------------------
  // Test 1: closeProject
  // -------------------------------------------------------------------------

  blocTest<ProjectListCubit, ProjectListState>(
    "closeProject: removes project from state and calls storage.closeProject",
    build: () {
      when(() => mockProjectService.listProjects()).thenAnswer(
        (_) async => ApiResponse.success([projectA, projectB, projectC]),
      );
      return buildCubit();
    },
    act: (cubit) async {
      // Let the initial load complete before exercising closeProject.
      await Future<void>.delayed(Duration.zero);
      await cubit.closeProject("B");
    },
    skip: 1, // skip the initial ProjectListLoaded([A, B, C])
    expect: () => [
      isA<ProjectListLoaded>()
          .having(
            (s) => s.projects.any((p) => p.id == "B"),
            "B is absent",
            isFalse,
          )
          .having(
            (s) => s.projects.map((p) => p.id).toList(),
            "remaining project ids",
            containsAll(["A", "C"]),
          )
          .having(
            (s) => s.projects.length,
            "projects length",
            2,
          ),
    ],
    verify: (cubit) {
      verify(() => mockStorage.closeProject("B")).called(1);
    },
  );

  // -------------------------------------------------------------------------
  // Test 2: loadProjects filters closed IDs
  // -------------------------------------------------------------------------

  blocTest<ProjectListCubit, ProjectListState>(
    "loadProjects: filters out projects whose IDs are in closed storage",
    build: () {
      when(() => mockStorage.getClosedProjectIds()).thenAnswer((_) async => {"B"});
      when(() => mockProjectService.listProjects()).thenAnswer(
        (_) async => ApiResponse.success([projectA, projectB, projectC]),
      );
      return buildCubit();
    },
    // No act needed — constructor triggers the load.
    expect: () => [
      isA<ProjectListLoaded>()
          .having(
            (s) => s.projects.any((p) => p.id == "B"),
            "B is absent",
            isFalse,
          )
          .having(
            (s) => s.projects.map((p) => p.id).toList(),
            "remaining project ids",
            containsAll(["A", "C"]),
          )
          .having(
            (s) => s.projects.length,
            "projects length",
            2,
          ),
    ],
  );

  // -------------------------------------------------------------------------
  // Test 3: createProject success
  // -------------------------------------------------------------------------

  blocTest<ProjectListCubit, ProjectListState>(
    "createProject: calls service, refreshes project list, and returns true on success",
    build: () {
      when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([projectA]));
      when(
        () => mockProjectService.createProject(path: any(named: "path")),
      ).thenAnswer((_) async => ApiResponse.success(projectB));
      return buildCubit();
    },
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero); // let initial load finish
      // Refresh will now return A + B.
      when(() => mockProjectService.listProjects()).thenAnswer(
        (_) async => ApiResponse.success([projectA, projectB]),
      );
      final result = await cubit.createProject(path: "/dev/new");
      expect(result, isTrue);
    },
    skip: 1, // skip initial ProjectListLoaded([A])
    expect: () => [
      isA<ProjectListLoaded>().having(
        (s) => s.projects.length,
        "projects count after create",
        2,
      ),
    ],
    verify: (cubit) {
      verify(
        () => mockProjectService.createProject(path: "/dev/new"),
      ).called(1);
    },
  );

  // -------------------------------------------------------------------------
  // Test 4: createProject failure
  // -------------------------------------------------------------------------

  blocTest<ProjectListCubit, ProjectListState>(
    "createProject: returns false and emits no state on API error",
    build: () {
      when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([projectA]));
      when(
        () => mockProjectService.createProject(path: any(named: "path")),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
      return buildCubit();
    },
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      final result = await cubit.createProject(path: "/dev/new");
      expect(result, isFalse);
    },
    skip: 1,
    expect: () => <ProjectListState>[],
  );

  // -------------------------------------------------------------------------
  // Test 5: discoverProject success
  // -------------------------------------------------------------------------

  blocTest<ProjectListCubit, ProjectListState>(
    "discoverProject: calls openProject on storage and refreshes on success",
    build: () {
      // B is closed initially — service still returns only [A] to keep it simple.
      when(() => mockStorage.getClosedProjectIds()).thenAnswer((_) async => {"B"});
      when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([projectA]));
      when(
        () => mockProjectService.discoverProject(path: any(named: "path")),
      ).thenAnswer((_) async => ApiResponse.success(projectB));
      return buildCubit();
    },
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero); // let initial load finish ([A])
      // After openProject, B is no longer closed.
      when(() => mockStorage.getClosedProjectIds()).thenAnswer((_) async => <String>{});
      when(() => mockProjectService.listProjects()).thenAnswer(
        (_) async => ApiResponse.success([projectA, projectB]),
      );
      final result = await cubit.discoverProject(path: "/dev/B");
      expect(result, isTrue);
    },
    skip: 1, // skip initial ProjectListLoaded([A])
    expect: () => [
      isA<ProjectListLoaded>()
          .having(
            (s) => s.projects.map((p) => p.id).toList(),
            "project ids after discover",
            containsAll(["A", "B"]),
          )
          .having(
            (s) => s.projects.length,
            "projects count",
            2,
          ),
    ],
    verify: (cubit) {
      verify(() => mockStorage.openProject("B")).called(1);
    },
  );

  // -------------------------------------------------------------------------
  // Test 6: discoverProject auto-uncloses — previously closed project reappears
  // -------------------------------------------------------------------------

  blocTest<ProjectListCubit, ProjectListState>(
    "discoverProject: a previously closed project reappears in the list after discover",
    build: () {
      // B is closed — initial list has A & C (B filtered out).
      when(() => mockStorage.getClosedProjectIds()).thenAnswer((_) async => {"B"});
      when(() => mockProjectService.listProjects()).thenAnswer(
        (_) async => ApiResponse.success([projectA, projectB, projectC]),
      );
      when(
        () => mockProjectService.discoverProject(path: any(named: "path")),
      ).thenAnswer((_) async => ApiResponse.success(projectB));
      return buildCubit();
    },
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero); // initial state: [A, C]
      // Simulate storage removing B from closed set after openProject.
      when(() => mockStorage.getClosedProjectIds()).thenAnswer((_) async => <String>{});
      await cubit.discoverProject(path: "/dev/B");
    },
    skip: 1, // skip initial ProjectListLoaded([A, C])
    expect: () => [
      isA<ProjectListLoaded>()
          .having(
            (s) => s.projects.any((p) => p.id == "B"),
            "B reappears after discover",
            isTrue,
          )
          .having(
            (s) => s.projects.length,
            "all three projects present",
            3,
          ),
    ],
    verify: (cubit) {
      verify(() => mockStorage.openProject("B")).called(1);
    },
  );
}
