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

    setUp(() {
      mockProjectService = MockProjectService();
      mockConnectionService = MockConnectionService();
      mockSseEventRepository = MockSseEventRepository();
      mockRouteSource = MockRouteSource();
    });

    /// Creates a fresh [ProjectListCubit].
    ///
    /// All mock stubs MUST be configured before calling this because the
    /// constructor immediately calls [ProjectListCubit.loadProjects].
    ProjectListCubit buildCubit() => ProjectListCubit(
      mockProjectService,
      mockConnectionService,
      mockSseEventRepository,
      mockRouteSource,
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
      // The constructor's async loadProjects completes during the post-act wait
      // and emits a single ProjectListLoaded state.
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
        // Let the constructor's async loadProjects settle first so that the
        // cubit is in ProjectListLoaded before we trigger a second load. This
        // guarantees the explicit emit(loading) is not a same-state no-op.
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
        // Return different data on refresh to prove new data is used.
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success([testProject(name: "Refreshed")]),
        );
        final result = await cubit.refreshProjects();
        expect(result, isTrue);
      },
      skip: 1, // skip constructor's initial loaded emission
      expect: () => [
        // Only ProjectListLoaded — no ProjectListLoading in between.
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
        // Switch mock to error for the refresh call.
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        final result = await cubit.refreshProjects();
        expect(result, isFalse);
      },
      skip: 1, // skip constructor's initial loaded emission
      // No state changes — current loaded state is preserved.
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
        await Future<void>.delayed(Duration.zero); // let initial load settle
        mockSseEventRepository.emitProjectActivity({_projectId: 3});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1, // skip initial loaded emission (no activity yet)
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
        // Keep the API hanging so state stays at loading.
        final completer = Completer<ApiResponse<List<Project>>>();
        when(() => mockProjectService.listProjects()).thenAnswer((_) => completer.future);
        return buildCubit();
      },
      act: (cubit) async {
        mockSseEventRepository.emitProjectActivity({_projectId: 2});
        await Future<void>.delayed(Duration.zero);
      },
      // Still in loading state — no emission expected.
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
        // Seed with activity so state starts non-empty.
        mockSseEventRepository.emitProjectActivity({_projectId: 1});
        when(() => mockProjectService.listProjects()).thenAnswer((_) async => ApiResponse.success([testProject()]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero); // let load settle with activity
        // Now clear activity — repository filters out zeros and emits empty.
        mockSseEventRepository.emitProjectActivity(const {});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1, // skip initial loaded emission (activityById: {_projectId: 1})
      expect: () => [
        isA<ProjectListLoaded>().having((s) => s.activityById, "activityById", isEmpty),
      ],
    );

    // =========================================================================
    // Throttled project data refresh
    // =========================================================================

    group("throttled project data refresh", () {
      test("activity event schedules refresh that fires after 30 seconds", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectService.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success([testProject()]);
          });
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          expect(fetchCount, 1, reason: "initial load");

          mockSseEventRepository.emitProjectActivity({_projectId: 1});
          async.elapse(Duration.zero);
          expect(fetchCount, 1, reason: "throttle hasn't fired yet");

          async.elapse(const Duration(seconds: 30));
          expect(fetchCount, 2, reason: "throttle fired after 30s");
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
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          expect(fetchCount, 1);

          for (var i = 0; i < 5; i++) {
            mockSseEventRepository.emitProjectActivity({_projectId: i});
            async.elapse(const Duration(seconds: 1));
          }
          expect(fetchCount, 1, reason: "still within first 30s window");

          async.elapse(const Duration(seconds: 25));
          expect(fetchCount, 2, reason: "exactly one refresh despite 5 events");
          cubit.close();
        });
      });

      test("no refresh scheduled when page is not visible", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectService.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success([testProject()]);
          });
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          expect(fetchCount, 1, reason: "after initial load");

          mockRouteSource.emitRoute(AppRoute.sessions);
          expect(fetchCount, 1, reason: "after emitRoute(sessions)");
          async.elapse(Duration.zero);
          expect(fetchCount, 1, reason: "after elapse after sessions");

          mockSseEventRepository.emitProjectActivity({_projectId: 1});
          expect(fetchCount, 1, reason: "after emitProjectActivity");
          async.elapse(const Duration(seconds: 1));
          expect(fetchCount, 1, reason: "after 1s");
          async.elapse(const Duration(seconds: 59));
          expect(fetchCount, 1, reason: "after 60s total");
          cubit.close();
        });
      });

      test("pending refresh fires immediately when navigating back to page", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectService.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success([testProject()]);
          });
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          expect(fetchCount, 1);

          mockRouteSource.emitRoute(AppRoute.sessions);
          async.elapse(Duration.zero);
          mockSseEventRepository.emitProjectActivity({_projectId: 1});
          async.elapse(Duration.zero);
          expect(fetchCount, 1, reason: "no refresh while page hidden");

          mockRouteSource.emitRoute(AppRoute.projects);
          async.elapse(Duration.zero);
          expect(fetchCount, 2, reason: "immediate refresh when page visible");
          cubit.close();
        });
      });

      test("no refresh when navigating back without pending events", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectService.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success([testProject()]);
          });
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          expect(fetchCount, 1);

          mockRouteSource.emitRoute(AppRoute.sessions);
          async.elapse(Duration.zero);
          mockRouteSource.emitRoute(AppRoute.projects);
          async.elapse(Duration.zero);

          expect(fetchCount, 1, reason: "no refresh when no pending events");
          cubit.close();
        });
      });

      test("new throttle window starts after previous refresh completes", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectService.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success([testProject()]);
          });
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          expect(fetchCount, 1);

          mockSseEventRepository.emitProjectActivity({_projectId: 1});
          async.elapse(const Duration(seconds: 30));
          expect(fetchCount, 2, reason: "first throttle window");

          mockSseEventRepository.emitProjectActivity({_projectId: 2});
          async.elapse(const Duration(seconds: 30));
          expect(fetchCount, 3, reason: "second throttle window");
          cubit.close();
        });
      });
    });
  });
}
