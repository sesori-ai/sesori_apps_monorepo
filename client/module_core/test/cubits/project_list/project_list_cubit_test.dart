import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show AppRouteDef;
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/project_list/add_project_outcome.dart";
import "package:sesori_dart_core/src/cubits/project_list/project_list_cubit.dart";
import "package:sesori_dart_core/src/cubits/project_list/project_list_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Project ID used in [testProject].
const _projectId = "project-1";

final projectA = testProject(id: "A", path: "/home/user/A");
final projectB = testProject(id: "B", path: "/home/user/B");
final projectC = testProject(id: "C", path: "/home/user/C");

const _connectionConfig = ServerConnectionConfig(
  relayHost: "relay.example.com",
  authToken: "test-token",
);
const _connectionHealth = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
const _connectedStatus = ConnectionStatus.connected(
  config: _connectionConfig,
  health: _connectionHealth,
);
const _bridgeOfflineStatus = ConnectionStatus.bridgeOffline(
  config: _connectionConfig,
  health: _connectionHealth,
);

void main() {
  setUpAll(registerAllFallbackValues);

  group("ProjectListCubit", () {
    late MockProjectService mockProjectService;
    late MockConnectionService mockConnectionService;
    late MockSseEventRepository mockSseEventRepository;
    late MockRouteSource mockRouteSource;
    late MockRegisteredBridgesService mockRegisteredBridgesService;
    late FakeSessionUnseenTracker fakeSessionUnseenTracker;
    late MockFailureReporter mockFailureReporter;
    late BehaviorSubject<ConnectionStatus> statusController;

    setUp(() {
      mockProjectService = MockProjectService();
      mockConnectionService = MockConnectionService();
      mockSseEventRepository = MockSseEventRepository();
      mockRouteSource = MockRouteSource();
      mockRegisteredBridgesService = MockRegisteredBridgesService();
      fakeSessionUnseenTracker = FakeSessionUnseenTracker();
      mockFailureReporter = MockFailureReporter();
      statusController = BehaviorSubject<ConnectionStatus>.seeded(
        _connectedStatus,
      );

      // Must be stubbed before any cubit is built — constructor subscribes immediately.
      when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
      when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
      when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
      // Default: a fresh account with no registered bridge (setup onboarding).
      when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => false);
      when(
        () => mockFailureReporter.recordFailure(
          error: any(named: "error"),
          stackTrace: any(named: "stackTrace"),
          uniqueIdentifier: any(named: "uniqueIdentifier"),
          fatal: any(named: "fatal"),
          reason: any(named: "reason"),
          information: any(named: "information"),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      await statusController.close();
    });

    /// Creates a fresh [ProjectListCubit] with the route source seeded to
    /// null (auto-refresh inactive). All mock stubs MUST be configured before
    /// calling this because the constructor immediately starts initial loading.
    ProjectListCubit buildCubit() => ProjectListCubit(
      mockProjectService,
      mockConnectionService,
      mockSseEventRepository,
      mockRouteSource,
      sessionUnseenTracker: fakeSessionUnseenTracker,
      registeredBridgesService: mockRegisteredBridgesService,
      failureReporter: mockFailureReporter,
    );

    // -------------------------------------------------------------------------
    // Test 1: constructor triggers load — success with projects
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "constructor triggers loadProjects: emits ProjectListLoaded with fetched projects",
      build: () {
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
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

    late Completer<bool> initialConnectCompleter;

    blocTest<ProjectListCubit, ProjectListState>(
      "constructor waits for relay connection attempt before initial project fetch",
      build: () {
        statusController.add(const ConnectionStatus.disconnected());
        initialConnectCompleter = Completer<bool>();
        when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) => initialConnectCompleter.future);
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
        addTearDown(() {
          if (!initialConnectCompleter.isCompleted) initialConnectCompleter.complete(false);
        });
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        verifyNever(() => mockProjectService.listProjects());

        final captured = verify(() => mockConnectionService.connectWithFreshAuthToken());
        captured.called(1);

        // A successful connect brings the bridge online, so the initial load
        // proceeds to fetch projects (rather than the onboarding state).
        statusController.add(_connectedStatus);
        initialConnectCompleter.complete(true);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<ProjectListLoaded>().having(
          (s) => s.projects,
          "projects",
          [testProject()],
        ),
      ],
      verify: (_) {
        verify(() => mockProjectService.listProjects()).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // Test 2: load success with empty list
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "load success with empty list: emits ProjectListLoaded with empty projects",
      build: () {
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(const Projects(data: <Project>[])));
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
    // Bridge-disconnected onboarding
    // -------------------------------------------------------------------------

    group("bridge disconnected onboarding", () {
      blocTest<ProjectListCubit, ProjectListState>(
        "initial load while disconnected emits bridgeDisconnected without fetching",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          // Connect attempt resolves but the bridge stays unreachable.
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          return buildCubit();
        },
        expect: () => [isA<ProjectListBridgeDisconnected>()],
        verify: (_) {
          verifyNever(() => mockProjectService.listProjects());
        },
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "bridge going offline keeps a non-empty loaded list (top-nav banner owns the messaging)",
        build: () {
          when(() => mockProjectService.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [testProject()])),
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          statusController.add(_bridgeOfflineStatus);
          await Future<void>.delayed(Duration.zero);
        },
        skip: 1, // constructor's ProjectListLoaded
        expect: () => <ProjectListState>[],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "bridge going offline with an empty loaded list surfaces the onboarding",
        build: () {
          when(() => mockProjectService.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(const Projects(data: <Project>[])),
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          statusController.add(_bridgeOfflineStatus);
          await Future<void>.delayed(Duration.zero);
        },
        skip: 1, // constructor's ProjectListLoaded
        expect: () => [isA<ProjectListBridgeDisconnected>()],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "bridge coming back after a kept loaded list refreshes silently (no loading flash)",
        build: () {
          when(() => mockProjectService.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [projectA])),
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          statusController.add(_bridgeOfflineStatus);
          await Future<void>.delayed(Duration.zero);
          when(() => mockProjectService.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [projectA, projectB])),
          );
          statusController.add(_connectedStatus);
          await Future<void>.delayed(Duration.zero);
        },
        skip: 1, // constructor's ProjectListLoaded
        expect: () => [
          isA<ProjectListLoaded>().having((s) => s.projects.length, "projects count after reconnect", 2),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "bridge coming online loads projects from the onboarding state",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          when(() => mockProjectService.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [testProject()])),
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          statusController.add(_connectedStatus);
          await Future<void>.delayed(Duration.zero);
        },
        skip: 1, // initial ProjectListBridgeDisconnected
        expect: () => [
          isA<ProjectListLoading>(),
          isA<ProjectListLoaded>().having((s) => s.projects.length, "projects count after connect", 1),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "fetch error while the bridge is unavailable emits bridgeDisconnected, not failed",
        build: () {
          when(() => mockProjectService.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [testProject()])),
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          // Bridge becomes unavailable; drive loadProjects() directly (no status
          // event) so the fetch-error branch is exercised, not the listener.
          when(() => mockConnectionService.currentStatus).thenReturn(_bridgeOfflineStatus);
          when(() => mockProjectService.listProjects()).thenAnswer(
            (_) async => ApiResponse.error(ApiError.generic()),
          );
          await cubit.loadProjects();
        },
        skip: 1, // constructor's ProjectListLoaded
        expect: () => [
          isA<ProjectListLoading>(),
          isA<ProjectListBridgeDisconnected>(),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "live ConnectionDisconnected while loaded surfaces the onboarding",
        build: () {
          when(
            () => mockProjectService.listProjects(),
          ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          statusController.add(const ConnectionStatus.disconnected());
          await Future<void>.delayed(Duration.zero);
        },
        skip: 1, // constructor's ProjectListLoaded
        expect: () => [isA<ProjectListBridgeDisconnected>()],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "transient connection states do not disturb the onboarding",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          // ConnectionReconnecting / ConnectionLost must NOT replace the
          // onboarding (the cubit's transient-state no-op) — keeps it stable.
          statusController.add(const ConnectionStatus.reconnecting(config: _connectionConfig));
          statusController.add(const ConnectionStatus.connectionLost(config: _connectionConfig));
          await Future<void>.delayed(Duration.zero);
        },
        skip: 1, // initial ProjectListBridgeDisconnected
        expect: () => <ProjectListState>[],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "reconnectBridge: establishes a fresh connection and loads projects",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero); // initial -> bridgeDisconnected
          when(
            () => mockProjectService.listProjects(),
          ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
          // A subsequent connect attempt succeeds. Mutate currentStatus directly
          // (no stream event) so we isolate reconnectBridge's own fetch path.
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async {
            when(() => mockConnectionService.currentStatus).thenReturn(_connectedStatus);
            return true;
          });
          await cubit.reconnectBridge();
        },
        skip: 1, // initial ProjectListBridgeDisconnected
        expect: () => [
          isA<ProjectListLoaded>().having((s) => s.projects.length, "projects after reconnect", 1),
        ],
      );

      // Regression: a real ConnectionConnected stream event fires *during*
      // reconnectBridge's connect (the BehaviorSubject delivers it as the
      // production ConnectionService does). Before the _reconnectBridgeInFlight
      // guard this drove _onConnectionStatusChanged into its own loadProjects()
      // — a second, non-coalesced fetch plus a full-screen loading() flash over
      // the onboarding. The guard makes reconnectBridge the sole, silent fetch.
      blocTest<ProjectListCubit, ProjectListState>(
        "reconnectBridge: a ConnectionConnected event during connect neither double-fetches nor flashes loading",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          // Initial connect fails -> bridgeDisconnected onboarding.
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero); // initial -> bridgeDisconnected
          when(
            () => mockProjectService.listProjects(),
          ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
          // The reconnect succeeds and, like the real service, publishes the
          // ConnectionConnected transition on the status stream — which the
          // cubit also listens to via _onConnectionStatusChanged.
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async {
            statusController.add(_connectedStatus);
            return true;
          });
          await cubit.reconnectBridge();
          await Future<void>.delayed(Duration.zero); // flush any deferred listener microtasks
        },
        skip: 1, // initial ProjectListBridgeDisconnected
        expect: () => [
          // A single terminal Loaded — no ProjectListLoading flash from a
          // duplicate loadProjects() driven by the status listener.
          isA<ProjectListLoaded>().having((s) => s.projects.length, "projects after reconnect", 1),
        ],
        verify: (_) {
          // Only reconnectBridge fetched; the listener's reload was suppressed.
          verify(() => mockProjectService.listProjects()).called(1);
        },
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "reconnectBridge: stays on onboarding (no fetch) when the bridge is still unreachable",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.reconnectBridge();
        },
        skip: 1, // initial ProjectListBridgeDisconnected
        expect: () => <ProjectListState>[],
        verify: (_) {
          // Constructor + reconnectBridge each attempt a fresh connection.
          verify(() => mockConnectionService.connectWithFreshAuthToken()).called(2);
          verifyNever(() => mockProjectService.listProjects());
        },
      );
    });

    // -------------------------------------------------------------------------
    // Registered-bridges decision: which bridge-disconnected flow to show.
    //
    // The cubit delegates the lookup to RegisteredBridgesService and only
    // reflects the answer; the resolution tiers, latching and reactive stream
    // are the service's own concern (see registered_bridges_service_test.dart).
    // -------------------------------------------------------------------------

    group("registered bridges decision", () {
      late Completer<bool> pendingLookupGate;

      blocTest<ProjectListCubit, ProjectListState>(
        "no registered bridge: bridgeDisconnected carries hasRegisteredBridges=false (setup onboarding)",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => false);
          return buildCubit();
        },
        expect: () => [
          isA<ProjectListBridgeDisconnected>().having(
            (s) => s.hasRegisteredBridges,
            "hasRegisteredBridges",
            isFalse,
          ),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "registered bridge exists: bridgeDisconnected carries hasRegisteredBridges=true (turn-on view)",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
          return buildCubit();
        },
        expect: () => [
          isA<ProjectListBridgeDisconnected>().having(
            (s) => s.hasRegisteredBridges,
            "hasRegisteredBridges",
            isTrue,
          ),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "connection recovery during the lookup suppresses the stale bridgeDisconnected emit",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          pendingLookupGate = Completer<bool>();
          when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) => pendingLookupGate.future);
          addTearDown(() {
            if (!pendingLookupGate.isCompleted) pendingLookupGate.complete(false);
          });
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero); // lookup now in flight
          // The bridge connects while the lookup is pending. Mutate currentStatus
          // directly (no stream event) so only the post-lookup guard is exercised.
          when(() => mockConnectionService.currentStatus).thenReturn(_connectedStatus);
          pendingLookupGate.complete(true);
          await Future<void>.delayed(Duration.zero);
        },
        // No bridgeDisconnected over the recovered connection — the loading
        // state stays until the connected transition drives the next fetch.
        expect: () => <ProjectListState>[],
      );
    });

    // -------------------------------------------------------------------------
    // Test 4a: hideProject
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "hideProject: removes project from state and calls service.hideProject",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [projectA, projectB, projectC])),
        );
        when(
          () => mockProjectService.hideProject(projectId: any(named: "projectId")),
        ).thenAnswer((_) async => ApiResponse.success(null));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        await cubit.hideProject("B");
      },
      skip: 1,
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
      verify: (_) {
        verify(() => mockProjectService.hideProject(projectId: "B")).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // Test 4b: createProject success
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "createProject: calls service, refreshes project list, and returns true on success",
      build: () {
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectService.createProject(path: any(named: "path")),
        ).thenAnswer((_) async => ApiResponse.success(projectB));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [projectA, projectB])),
        );
        final result = await cubit.createProject(path: "/dev/new");
        expect(result, AddProjectOutcome.success);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having(
          (s) => s.projects.length,
          "projects count after create",
          2,
        ),
      ],
      verify: (_) {
        verify(
          () => mockProjectService.createProject(path: "/dev/new"),
        ).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // Test 4c: createProject failure
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "createProject: returns otherError and emits no state on API error",
      build: () {
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectService.createProject(path: any(named: "path")),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.createProject(path: "/dev/new");
        expect(result, AddProjectOutcome.otherError);
      },
      skip: 1,
      expect: () => <ProjectListState>[],
    );

    // -------------------------------------------------------------------------
    // Test 4c2: createProject permission denial (HTTP 403)
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "createProject: returns permissionDenied on a 403 from the bridge",
      build: () {
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(() => mockProjectService.createProject(path: any(named: "path"))).thenAnswer(
          (_) async => ApiResponse.error(
            ApiError.nonSuccessCode(errorCode: 403, rawErrorString: "permission denied: /dev/new"),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.createProject(path: "/dev/new");
        expect(result, AddProjectOutcome.permissionDenied);
      },
      skip: 1,
      expect: () => <ProjectListState>[],
    );

    // -------------------------------------------------------------------------
    // Test 4d: discoverProject success
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "discoverProject: refreshes project list on success",
      build: () {
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectService.discoverProject(path: any(named: "path")),
        ).thenAnswer((_) async => ApiResponse.success(projectB));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [projectA, projectB])),
        );
        final result = await cubit.discoverProject(path: "/dev/B");
        expect(result, AddProjectOutcome.success);
      },
      skip: 1,
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
      verify: (_) {
        verify(() => mockProjectService.discoverProject(path: "/dev/B")).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // Test 4d2: fetchFilesystemSuggestions outcomes
    // -------------------------------------------------------------------------

    test("fetchFilesystemSuggestions returns success with data", () async {
      when(
        () => mockProjectService.listProjects(),
      ).thenAnswer((_) async => ApiResponse.success(const Projects(data: [])));
      const suggestions = FilesystemSuggestions(
        data: [FilesystemSuggestion(path: "/dev/a", name: "a", isGitRepo: false)],
      );
      when(
        () => mockProjectService.getFilesystemSuggestions(prefix: any(named: "prefix")),
      ).thenAnswer((_) async => ApiResponse.success(suggestions));

      final cubit = buildCubit();
      final result = await cubit.fetchFilesystemSuggestions(prefix: "/dev");

      expect(result, isA<FilesystemSuggestionsSuccess>());
      expect((result as FilesystemSuggestionsSuccess).suggestions.data, hasLength(1));
      await cubit.close();
    });

    test("fetchFilesystemSuggestions returns permissionDenied on a 403", () async {
      when(
        () => mockProjectService.listProjects(),
      ).thenAnswer((_) async => ApiResponse.success(const Projects(data: [])));
      when(() => mockProjectService.getFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.nonSuccessCode(errorCode: 403, rawErrorString: "permission denied: /dev"),
        ),
      );

      final cubit = buildCubit();
      final result = await cubit.fetchFilesystemSuggestions(prefix: "/dev");

      expect(result, isA<FilesystemSuggestionsPermissionDenied>());
      await cubit.close();
    });

    test("fetchFilesystemSuggestions returns error on a non-permission failure", () async {
      when(
        () => mockProjectService.listProjects(),
      ).thenAnswer((_) async => ApiResponse.success(const Projects(data: [])));
      when(
        () => mockProjectService.getFilesystemSuggestions(prefix: any(named: "prefix")),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      final cubit = buildCubit();
      final result = await cubit.fetchFilesystemSuggestions(prefix: "/dev");

      expect(result, isA<FilesystemSuggestionsError>());
      await cubit.close();
    });

    // -------------------------------------------------------------------------
    // Test 4e: renameProject success
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "renameProject: calls service, refreshes project list, and returns true on success",
      build: () {
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectService.renameProject(
            projectId: any(named: "projectId"),
            name: any(named: "name"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(projectA));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [projectA, projectB])),
        );
        final result = await cubit.renameProject(projectId: "A", name: "New Name");
        expect(result, isTrue);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having(
          (s) => s.projects.length,
          "projects count after rename",
          2,
        ),
      ],
      verify: (_) {
        verify(
          () => mockProjectService.renameProject(projectId: "A", name: "New Name"),
        ).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // Test 4f: renameProject failure
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "renameProject: returns false and emits no state on API error",
      build: () {
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectService.renameProject(
            projectId: any(named: "projectId"),
            name: any(named: "name"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.renameProject(projectId: "A", name: "New Name");
        expect(result, isFalse);
      },
      skip: 1,
      expect: () => <ProjectListState>[],
    );

    // -------------------------------------------------------------------------
    // Test 5: setActiveProject — calls connectionService.setActiveDirectory
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "setActiveProject: calls connectionService.setActiveDirectory with project id",
      build: () {
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(const Projects(data: <Project>[])));
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
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
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
          (_) async => ApiResponse.success(Projects(data: [globalProject, testProject()])),
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
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [testProject(name: "Refreshed")])),
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
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
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
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
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
        final completer = Completer<ApiResponse<Projects>>();
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
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
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
        when(
          () => mockProjectService.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
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
            return ApiResponse.success(Projects(data: [testProject()]));
          });
          mockRouteSource.emitRoute(AppRouteDef.projects);
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
            return ApiResponse.success(Projects(data: [testProject()]));
          });
          mockRouteSource.emitRoute(AppRouteDef.projects);
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
            return ApiResponse.success(Projects(data: [testProject()]));
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
            return ApiResponse.success(Projects(data: [testProject()]));
          });
          // Start on projects, navigate away, navigate back.
          mockRouteSource.emitRoute(AppRouteDef.projects);
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          final baseline = fetchCount;

          mockRouteSource.emitRoute(AppRouteDef.sessions);
          async.elapse(Duration.zero);
          expect(fetchCount, baseline, reason: "no fetch on navigate away");

          mockRouteSource.emitRoute(AppRouteDef.projects);
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
            return ApiResponse.success(Projects(data: [testProject()]));
          });
          mockRouteSource.emitRoute(AppRouteDef.projects);
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

    blocTest<ProjectListCubit, ProjectListState>(
      "connection reconnect triggers silent refresh",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [testProject()])),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Change mock to return updated data
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(
            Projects(
              data: [
                testProject(),
                testProject(path: "/home/user/another-project"),
              ],
            ),
          ),
        );
        // Emit connected status
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
        statusController.add(
          const ConnectionStatus.connected(config: config, health: health),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having((s) => s.projects.length, "projects count after reconnect", 2),
      ],
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "connection reconnect triggers loadProjects when state is ProjectListFailed",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.error(ApiError.generic()),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Switch mock to succeed so the reconnect-triggered load works.
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [testProject()])),
        );
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
        statusController.add(
          const ConnectionStatus.connected(config: config, health: health),
        );
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1, // Skip the initial ProjectListFailed from constructor.
      expect: () => [
        isA<ProjectListLoading>(),
        isA<ProjectListLoaded>().having(
          (s) => s.projects.length,
          "projects count after reconnect retry",
          1,
        ),
      ],
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "rapid ConnectionConnected events coalesce into single refresh",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [testProject()])),
        );
        return buildCubit();
      },
      act: (cubit) async {
        // Wait for initial load to complete.
        await Future<void>.delayed(Duration.zero);
        // Reset interaction count after initial load.
        reset(mockProjectService);

        // Use a Completer so the first refresh stays in-flight while the
        // second ConnectionConnected arrives — this is what exercises the guard.
        final completer = Completer<ApiResponse<Projects>>();
        when(() => mockProjectService.listProjects()).thenAnswer((_) => completer.future);

        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
        const connected = ConnectionStatus.connected(config: config, health: health);

        // Fire two rapid ConnectionConnected events.
        statusController.add(connected);
        statusController.add(connected);
        await Future<void>.delayed(Duration.zero);

        // Let the in-flight refresh complete.
        completer.complete(ApiResponse.success(Projects(data: [testProject()])));
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      // State is deduplicated (same data), so no new emissions — verify call count instead.
      expect: () => <ProjectListState>[],
      verify: (_) {
        // Should have been called only once despite two ConnectionConnected events.
        verify(() => mockProjectService.listProjects()).called(1);
      },
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "ConnectionConnected while state is loading does not trigger refresh",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [testProject()])),
        );

        // Seed the status controller as Connected BEFORE building the cubit,
        // so the cubit receives ConnectionConnected immediately on subscribe.
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
        statusController.add(
          const ConnectionStatus.connected(config: config, health: health),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      verify: (_) {
        // Only 1 call from the constructor's loadProjects().
        // The ConnectionConnected should NOT trigger a second fetch.
        verify(() => mockProjectService.listProjects()).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // retryLoadProjects
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "retryLoadProjects: reconnects and loads projects when connection is lost",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.error(ApiError.generic()),
        );
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connectionLost(config: config),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [testProject()])),
        );
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        when(() => mockConnectionService.reconnect()).thenAnswer((_) {
          when(() => mockConnectionService.currentStatus).thenReturn(
            const ConnectionStatus.reconnecting(config: config),
          );
          statusController.add(const ConnectionStatus.reconnecting(config: config));
        });
        final retryFuture = cubit.retryLoadProjects();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
        statusController.add(
          const ConnectionStatus.connected(config: config, health: health),
        );
        await retryFuture;
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoading>(),
        isA<ProjectListLoaded>().having(
          (s) => s.projects.length,
          "projects count after retry",
          1,
        ),
      ],
      verify: (_) {
        verify(() => mockConnectionService.reconnect()).called(1);
      },
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "retryLoadProjects: loads directly when already connected",
      build: () {
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.error(ApiError.generic()),
        );
        const config = ServerConnectionConfig(
          relayHost: "relay.example.com",
          authToken: "test-token",
        );
        const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
        when(() => mockConnectionService.currentStatus).thenReturn(
          const ConnectionStatus.connected(config: config, health: health),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectService.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [testProject()])),
        );
        await cubit.retryLoadProjects();
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoading>(),
        isA<ProjectListLoaded>().having(
          (s) => s.projects.length,
          "projects count after retry",
          1,
        ),
      ],
      verify: (_) {
        verifyNever(() => mockConnectionService.reconnect());
      },
    );

    // -------------------------------------------------------------------------
    // Stale reconnect
    // -------------------------------------------------------------------------

    group("stale reconnect", () {
      blocTest<ProjectListCubit, ProjectListState>(
        "stale signal triggers refresh with isRefreshing indicator",
        build: () {
          when(() => mockProjectService.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [testProject()])),
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          mockConnectionService.emitDataMayBeStale();
          await Future<void>.delayed(Duration.zero);
        },
        skip: 1,
        expect: () => [
          isA<ProjectListLoaded>()
              .having(
                (s) => s.isRefreshing,
                "isRefreshing when stale emitted",
                isTrue,
              )
              .having(
                (s) => s.projects,
                "projects preserved",
                [testProject()],
              ),
          isA<ProjectListLoaded>()
              .having(
                (s) => s.isRefreshing,
                "isRefreshing after refresh completes",
                isFalse,
              )
              .having(
                (s) => s.projects,
                "projects preserved",
                [testProject()],
              ),
        ],
        verify: (_) {
          // 1 call from constructor, 1 from stale reconnect
          verify(() => mockProjectService.listProjects()).called(2);
        },
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "stale signal is ignored when state is not ProjectListLoaded",
        build: () {
          when(() => mockProjectService.listProjects()).thenAnswer(
            (_) async => ApiResponse.error(ApiError.generic()),
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          mockConnectionService.emitDataMayBeStale();
          await Future<void>.delayed(Duration.zero);
        },
        skip: 1,
        expect: () => <ProjectListState>[],
        verify: (_) {
          // Only 1 call from constructor, stale should not trigger refresh
          verify(() => mockProjectService.listProjects()).called(1);
        },
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "stale + ConnectionConnected refresh coalesced into single API call",
        build: () {
          when(() => mockProjectService.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [testProject()])),
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          // Emit both stale and connection connected simultaneously
          mockConnectionService.emitDataMayBeStale();
          const config = ServerConnectionConfig(
            relayHost: "relay.example.com",
            authToken: "test-token",
          );
          const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
          statusController.add(
            const ConnectionStatus.connected(config: config, health: health),
          );
          await Future<void>.delayed(Duration.zero);
        },
        skip: 1,
        expect: () => [
          isA<ProjectListLoaded>().having(
            (s) => s.isRefreshing,
            "isRefreshing when stale emitted",
            isTrue,
          ),
          isA<ProjectListLoaded>().having(
            (s) => s.isRefreshing,
            "isRefreshing after refresh completes",
            isFalse,
          ),
        ],
        verify: (_) {
          // 1 call from constructor, 1 from stale (coalesced with ConnectionConnected)
          verify(() => mockProjectService.listProjects()).called(2);
        },
      );
    });
  });
}
