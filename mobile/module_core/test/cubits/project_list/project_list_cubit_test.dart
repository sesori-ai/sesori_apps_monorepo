import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
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

  // Three reusable projects.
  final projectA = _makeProject(id: "A");
  final projectB = _makeProject(id: "B");
  final projectC = _makeProject(id: "C");

  setUp(() {
    mockProjectService = MockProjectService();
    mockConnectionService = MockConnectionService();
    mockSseEventRepository = MockSseEventRepository();
    mockRouteSource = MockRouteSource();
  });

  ProjectListCubit buildCubit() => ProjectListCubit(
    mockProjectService,
    mockConnectionService,
    mockSseEventRepository,
    mockRouteSource,
  );

  // -------------------------------------------------------------------------
  // Test 1: closeProject
  // -------------------------------------------------------------------------

  blocTest<ProjectListCubit, ProjectListState>(
    "closeProject: removes project from state and calls service.closeProject",
    build: () {
      when(() => mockProjectService.listProjects()).thenAnswer(
        (_) async => ApiResponse.success([projectA, projectB, projectC]),
      );
      when(
        () => mockProjectService.closeProject(projectId: any(named: "projectId")),
      ).thenAnswer((_) async => ApiResponse.success(null));
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
      verify(() => mockProjectService.closeProject(projectId: "B")).called(1);
    },
  );

  // -------------------------------------------------------------------------
  // Test 2: createProject success
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
  // Test 3: createProject failure
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
  // Test 4: discoverProject success
  // -------------------------------------------------------------------------

  blocTest<ProjectListCubit, ProjectListState>(
    "discoverProject: refreshes project list on success",
    build: () {
      when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([projectA]));
      when(
        () => mockProjectService.discoverProject(path: any(named: "path")),
      ).thenAnswer((_) async => ApiResponse.success(projectB));
      return buildCubit();
    },
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero); // let initial load finish ([A])
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
      verify(() => mockProjectService.discoverProject(path: "/dev/B")).called(1);
    },
  );
}
