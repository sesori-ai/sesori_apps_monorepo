import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:fake_async/fake_async.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show AppRoute;
import "package:sesori_dart_core/src/cubits/project_list/project_list_cubit.dart";
import "package:sesori_dart_core/src/cubits/project_list/project_list_state.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Project ID used in [testProject].
const _projectId = "project-1";

void main() {
  setUpAll(registerAllFallbackValues);

  group("ProjectListCubit", () {
    late MockProjectService mockProjectService;
    late MockConnectionService mockConnectionService;
    late MockSseEventRepository mockSseEventRepository;
    late MockRouteSource mockRouteSource;
    late MockClosedProjectsStorage mockClosedStorage;

    setUp(() {
      mockProjectService = MockProjectService();
      mockConnectionService = MockConnectionService();
      mockSseEventRepository = MockSseEventRepository();
      mockRouteSource = MockRouteSource();
      mockClosedStorage = MockClosedProjectsStorage();

      // Default stubs for ClosedProjectsStorage — no closed projects.
      when(() => mockClosedStorage.getClosedProjectIds()).thenAnswer((_) async => <String>{});
      when(() => mockClosedStorage.closeProject(any())).thenAnswer((_) async {});
      when(() => mockClosedStorage.openProject(any())).thenAnswer((_) async {});
    });

    /// Creates a fresh [ProjectListCubit] with the route source seeded to
    /// null (auto-refresh inactive). All mock stubs MUST be configured before
    /// calling this because the constructor immediately calls loadProjects.
    ProjectListCubit buildCubit() => ProjectListCubit(
      mockProjectService,
      mockConnectionService,
      mockSseEventRepository,
      mockRouteSource,
      mockClosedStorage,
    );

    // -------------------------------------------------------------------------
    // Test 1: constructor triggers load — success with projects
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "constructor triggers loadProjects: emits ProjectListLoaded with fetched projects",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([testProject()]));
        return buildCubit();
      },
      expect: () => [
        isA<ProjectListLoaded>().having(
          (s) => s.projects,
          "projects",
          [testProject()],
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // Test 2: load success with empty list
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "load success with empty list: emits ProjectListLoaded with empty projects",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success(<Project>[]));
        return buildCubit();
      },
      expect: () => [
        isA<ProjectListLoaded>().having(
          (s) => s.projects,
          "projects",
          isEmpty,
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // Test 3: load failure — listProjects returns an error
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "load failure: listProjects error emits ProjectListFailed",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      expect: () => [
        isA<ProjectListFailed>(),
      ],
    );

    // -------------------------------------------------------------------------
    // Test 5: setActiveProject — calls connectionService.setActiveDirectory
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "setActiveProject: calls connectionService.setActiveDirectory with project id",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success(<Project>[]));
        return buildCubit();
      },
      act: (cubit) => cubit.setActiveProject(testProject()),
      expect: () => [
        isA<ProjectListLoaded>(),
      ],
      verify: (cubit) {
        verify(
          () => mockConnectionService.setActiveDirectory(testProject().id),
        ).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // Test 6: explicit loadProjects call — re-fetches and re-emits
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "explicit loadProjects call: re-fetches and emits loading then loaded",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([testProject()]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        await cubit.loadProjects();
      },
      expect: () => [
        isA<ProjectListLoaded>(), // constructor's async load
        isA<ProjectListLoading>(), // explicit loadProjects begins
        isA<ProjectListLoaded>(), // explicit loadProjects completes
      ],
    );

    // -------------------------------------------------------------------------
    // Test 7: projects are returned as-is, including virtual global entries
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "project with id 'global' is preserved in the loaded project list",
      build: () {
        const projectPathField =
            "work"
            "tree";
        final globalProject = Project.fromJson({
          "id": "global",
          projectPathField: "/",
          "time": {
            "created": 1700000000000,
            "updated": 1700000000000,
          },
        });
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success([globalProject, testProject()]),
        );
        return buildCubit();
      },
      expect: () => [
        isA<ProjectListLoaded>()
            .having(
              (s) => s.projects.any((p) => p.id == "global"),
              "contains global project",
              isTrue,
            )
            .having(
              (s) => s.projects.length,
              "projects length",
              2,
            ),
      ],
    );

    // -------------------------------------------------------------------------
    // Test 8: refreshProjects success — no loading state, emits loaded, returns true
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "refreshProjects: emits loaded without loading state and returns true",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([testProject()]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success([testProject(name: "Refreshed")]),
        );
        final result = await cubit.refreshProjects();
        expect(result, isTrue);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having(
          (s) => s.projects.first.name,
          "refreshed project name",
          "Refreshed",
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // Test 9: refreshProjects failure — keeps current state, returns false
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "refreshProjects: keeps current state and returns false on API failure",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([testProject()]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        final result = await cubit.refreshProjects();
        expect(result, isFalse);
      },
      skip: 1,
      expect: () => <ProjectListState>[],
    );

    // -------------------------------------------------------------------------
    // Test 10: activity stream update propagates to state
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "projectActivity update: emits loaded state with updated activityById",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([testProject()]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventRepository.emitProjectActivity({_projectId: 3});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having((s) => s.activityById, "activityById", {_projectId: 3}),
      ],
    );

    // -------------------------------------------------------------------------
    // Test 11: activity update ignored when not loaded
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "projectActivity update: ignored when state is not ProjectListLoaded",
      build: () {
        final completer = Completer<ApiResponse<List<Project>>>();
        when(() => mockProjectService.listProjects()).thenAnswer((_) => completer.future);
        return buildCubit();
      },
      act: (cubit) async {
        mockSseEventRepository.emitProjectActivity({_projectId: 2});
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => <ProjectListState>[],
    );

    // -------------------------------------------------------------------------
    // Test 12: load preserves existing activity from repository
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "_fetchProjects: seeds activityById from repository at load time",
      build: () {
        mockSseEventRepository.emitProjectActivity({_projectId: 2});
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([testProject()]));
        return buildCubit();
      },
      expect: () => [
        isA<ProjectListLoaded>().having((s) => s.activityById, "activityById", {_projectId: 2}),
      ],
    );

    // -------------------------------------------------------------------------
    // Test 13: activity clears when no projects are active
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "projectActivity update: activity clears when repository emits empty map",
      build: () {
        mockSseEventRepository.emitProjectActivity({_projectId: 1});
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([testProject()]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventRepository.emitProjectActivity(const {});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having((s) => s.activityById, "activityById", isEmpty),
      ],
    );

    // =========================================================================
    // Throttled project data refresh
    // =========================================================================

    group("throttled project data refresh", () {
      test("activity event triggers refresh after throttle duration", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectService.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success([testProject()]);
          });
          mockRouteSource.emitRoute(AppRoute.projects);
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          final baseline = fetchCount;

          mockSseEventRepository.emitProjectActivity({_projectId: 1});
          async.elapse(Duration.zero);
          expect(fetchCount, baseline, reason: "throttle hasn't fired yet");

          async.elapse(refreshThrottleDuration);
          expect(fetchCount, baseline + 1, reason: "throttle fired");
          cubit.close();
        });
      });

      test("multiple rapid events result in single refresh", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectService.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success([testProject()]);
          });
          mockRouteSource.emitRoute(AppRoute.projects);
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          final baseline = fetchCount;

          for (var i = 0; i < 5; i++) {
            mockSseEventRepository.emitProjectActivity({_projectId: i});
            async.elapse(const Duration(seconds: 1));
          }
          expect(fetchCount, baseline, reason: "still within window");

          async.elapse(const Duration(seconds: 25));
          expect(fetchCount, baseline + 1, reason: "one refresh despite 5 events");
          cubit.close();
        });
      });

      test("no auto-refresh when page is not visible", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectService.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success([testProject()]);
          });
          final cubit = buildCubit(); // route = null
          async.elapse(Duration.zero);
          expect(fetchCount, 1, reason: "only manual load");

          mockSseEventRepository.emitProjectActivity({_projectId: 1});
          async.elapse(const Duration(seconds: 60));

          expect(fetchCount, 1, reason: "no auto-refresh when page not visible");
          cubit.close();
        });
      });

      test("immediate refresh when navigating back to projects page", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectService.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success([testProject()]);
          });
          // Start on projects, navigate away, navigate back.
          mockRouteSource.emitRoute(AppRoute.projects);
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          final baseline = fetchCount;

          mockRouteSource.emitRoute(AppRoute.sessions);
          async.elapse(Duration.zero);
          expect(fetchCount, baseline, reason: "no fetch on navigate away");

          mockRouteSource.emitRoute(AppRoute.projects);
          async.elapse(Duration.zero);
          expect(fetchCount, baseline + 1, reason: "immediate refresh on navigate back");
          cubit.close();
        });
      });

      test("new throttle window starts after previous completes", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectService.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success([testProject()]);
          });
          mockRouteSource.emitRoute(AppRoute.projects);
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          final baseline = fetchCount;

          mockSseEventRepository.emitProjectActivity({_projectId: 1});
          async.elapse(refreshThrottleDuration);
          expect(fetchCount, baseline + 1, reason: "first window");

          mockSseEventRepository.emitProjectActivity({_projectId: 2});
          async.elapse(refreshThrottleDuration);
          expect(fetchCount, baseline + 2, reason: "second window");
          cubit.close();
        });
      });
    });
  });
}
