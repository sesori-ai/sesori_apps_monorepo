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
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/project_list_service.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
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
    late MockProjectRepository mockProjectRepository;
    late ProjectListService projectListService;
    late MockConnectionService mockConnectionService;
    late MockSseEventTracker mockSseEventTracker;
    late MockRouteSource mockRouteSource;
    late MockRegisteredBridgesService mockRegisteredBridgesService;
    late FakeSessionUnseenTracker fakeSessionUnseenTracker;
    late MockFailureReporter mockFailureReporter;
    late BehaviorSubject<ConnectionStatus> statusController;
    late Completer<ApiResponse<Projects>> projectFetchCompleter;

    setUp(() {
      mockProjectRepository = MockProjectRepository();
      projectListService = ProjectListService(
        repository: mockProjectRepository,
        activityCalculator: const SessionActivityCalculator(),
      );
      mockConnectionService = MockConnectionService();
      mockSseEventTracker = MockSseEventTracker();
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
      when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
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
      mockProjectRepository,
      mockConnectionService,
      mockSseEventTracker,
      mockRouteSource,
      projectListService: projectListService,
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
          () => mockProjectRepository.listProjects(),
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
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
        addTearDown(() {
          if (!initialConnectCompleter.isCompleted) initialConnectCompleter.complete(false);
        });
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        verifyNever(() => mockProjectRepository.listProjects());

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
        verify(() => mockProjectRepository.listProjects()).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // Test 2: load success with empty list
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "load success with empty list: emits ProjectListLoaded with empty projects",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
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
        when(() => mockProjectRepository.listProjects()).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
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
          verifyNever(() => mockProjectRepository.listProjects());
        },
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "bridge going offline keeps a non-empty loaded list (top-nav banner owns the messaging)",
        build: () {
          when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          when(() => mockProjectRepository.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [projectA])),
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          statusController.add(_bridgeOfflineStatus);
          await Future<void>.delayed(Duration.zero);
          when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          when(() => mockProjectRepository.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [testProject()])),
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          // Bridge becomes unavailable; drive loadProjects() directly (no status
          // event) so the fetch-error branch is exercised, not the listener.
          when(() => mockConnectionService.currentStatus).thenReturn(_bridgeOfflineStatus);
          when(() => mockProjectRepository.listProjects()).thenAnswer(
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
            () => mockProjectRepository.listProjects(),
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
            () => mockProjectRepository.listProjects(),
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
            () => mockProjectRepository.listProjects(),
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
          verify(() => mockProjectRepository.listProjects()).called(1);
        },
      );

      // Regression: the bridge-offline view's Reconnect button and the page's
      // pull-to-refresh both drive reconnectBridge, and neither blocks the
      // other. Overlapping triggers must share one attempt: a second pass would
      // fetch again behind the first and clear _reconnectBridgeInFlight while
      // the first is still connecting, re-opening the duplicate-reload window
      // that flag exists to close.
      blocTest<ProjectListCubit, ProjectListState>(
        "reconnectBridge: overlapping triggers coalesce into a single attempt",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero); // initial -> bridgeDisconnected
          when(
            () => mockProjectRepository.listProjects(),
          ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
          // Hold the connect open so the second trigger lands mid-attempt.
          final connect = Completer<bool>();
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) {
            when(() => mockConnectionService.currentStatus).thenReturn(_connectedStatus);
            return connect.future;
          });

          final fromButton = cubit.reconnectBridge();
          final fromPullToRefresh = cubit.reconnectBridge();
          connect.complete(true);
          await Future.wait([fromButton, fromPullToRefresh]);
        },
        skip: 1, // initial ProjectListBridgeDisconnected
        expect: () => [
          // One terminal Loaded: the second trigger awaited the first's future
          // rather than running a fetch of its own.
          isA<ProjectListLoaded>().having((s) => s.projects.length, "projects after reconnect", 1),
        ],
        verify: (_) {
          // The constructor's attempt plus one coalesced reconnect — not two.
          verify(() => mockConnectionService.connectWithFreshAuthToken()).called(2);
          verify(() => mockProjectRepository.listProjects()).called(1);
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
          verifyNever(() => mockProjectRepository.listProjects());
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
        // The setup onboarding has no machine row, so the bridge list is never
        // fetched for a bridge-less account.
        verify: (_) => verifyNever(() => mockRegisteredBridgesService.getRegisteredBridges()),
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "registered bridge exists: bridgeDisconnected carries hasRegisteredBridges=true (turn-on view)",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
          return buildCubit();
        },
        // The bridge fetch failed (empty list) while the boolean latch still
        // answers positively — the turn-on view must be picked regardless, just
        // without a machine name (no enrichment emit for an empty list).
        expect: () => [
          isA<ProjectListBridgeDisconnected>()
              .having((s) => s.hasRegisteredBridges, "hasRegisteredBridges", isTrue)
              .having((s) => s.bridges, "bridges", isEmpty),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "the fetched machine identity enriches the disconnected state in a follow-up emit",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
          when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
            (_) async => [testBridgeSummary(name: "Macbook-Pro.local")],
          );
          return buildCubit();
        },
        // The recovery view shows immediately off the latch; the machine names
        // land as a second emit once the fetch resolves.
        expect: () => [
          isA<ProjectListBridgeDisconnected>()
              .having((s) => s.hasRegisteredBridges, "hasRegisteredBridges", isTrue)
              .having((s) => s.bridges, "bridges", isEmpty),
          isA<ProjectListBridgeDisconnected>()
              .having((s) => s.hasRegisteredBridges, "hasRegisteredBridges", isTrue)
              .having((s) => s.bridges.map((b) => b.name), "bridge names", ["Macbook-Pro.local"]),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "connection recovery during the bridge fetch suppresses the stale enrichment emit",
        build: () {
          statusController.add(const ConnectionStatus.disconnected());
          when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => false);
          when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
          pendingLookupGate = Completer<bool>();
          when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
            (_) => pendingLookupGate.future.then((_) => [testBridgeSummary(name: "Macbook-Pro.local")]),
          );
          addTearDown(() {
            if (!pendingLookupGate.isCompleted) pendingLookupGate.complete(true);
          });
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero); // bridge fetch now in flight
          // The bridge connects while the fetch is pending. Mutate currentStatus
          // directly (no stream event) so only the post-fetch guard is exercised.
          when(() => mockConnectionService.currentStatus).thenReturn(_connectedStatus);
          pendingLookupGate.complete(true);
          await Future<void>.delayed(Duration.zero);
        },
        // Only the immediate name-less state; no enrichment over the recovered
        // connection — the connected transition owns the next state.
        expect: () => [
          isA<ProjectListBridgeDisconnected>().having((s) => s.bridges, "bridges", isEmpty),
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
    // Connected-but-empty machine identity enrichment
    // -------------------------------------------------------------------------

    group("connected-empty machine identity", () {
      late Completer<bool> pendingFetchGate;

      blocTest<ProjectListCubit, ProjectListState>(
        "an empty loaded list is enriched with the machine identity in a follow-up emit",
        build: () {
          when(() => mockProjectRepository.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(const Projects(data: [])),
          );
          when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
            (_) async => [testBridgeSummary(name: "Macbook-Pro.local")],
          );
          return buildCubit();
        },
        // The empty body shows immediately; the machine name lands as a second
        // emit once the fetch resolves.
        expect: () => [
          isA<ProjectListLoaded>()
              .having((s) => s.projects, "projects", isEmpty)
              .having((s) => s.bridges, "bridges", isEmpty),
          isA<ProjectListLoaded>().having((s) => s.projects, "projects", isEmpty).having(
            (s) => s.bridges.map((b) => b.name),
            "bridge names",
            ["Macbook-Pro.local"],
          ),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "a failed bridge fetch leaves the empty loaded state without a follow-up emit",
        build: () {
          when(() => mockProjectRepository.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(const Projects(data: [])),
          );
          // The setUp default getRegisteredBridges stub resolves empty — the
          // service's fail-soft error shape.
          return buildCubit();
        },
        expect: () => [
          isA<ProjectListLoaded>().having((s) => s.bridges, "bridges", isEmpty),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "a non-empty loaded list never fetches the machine identity",
        build: () {
          when(() => mockProjectRepository.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [testProject()])),
          );
          return buildCubit();
        },
        expect: () => [
          isA<ProjectListLoaded>()
              .having((s) => s.projects, "projects", isNotEmpty)
              .having((s) => s.bridges, "bridges", isEmpty),
        ],
        verify: (_) => verifyNever(() => mockRegisteredBridgesService.getRegisteredBridges()),
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "projects arriving during the bridge fetch suppress the stale enrichment emit",
        build: () {
          when(() => mockProjectRepository.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(const Projects(data: [])),
          );
          pendingFetchGate = Completer<bool>();
          when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
            (_) => pendingFetchGate.future.then((_) => [testBridgeSummary(name: "Macbook-Pro.local")]),
          );
          addTearDown(() {
            if (!pendingFetchGate.isCompleted) pendingFetchGate.complete(true);
          });
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero); // bridge fetch now in flight
          // Projects arrive while the fetch is pending; that state owns the
          // screen and has no machine row to enrich.
          when(() => mockProjectRepository.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [testProject()])),
          );
          await cubit.refreshProjects();
          pendingFetchGate.complete(true);
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [
          isA<ProjectListLoaded>().having((s) => s.projects, "projects", isEmpty),
          isA<ProjectListLoaded>()
              .having((s) => s.projects, "projects", isNotEmpty)
              .having((s) => s.bridges, "bridges", isEmpty),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "a refresh of a still-empty list carries the machine identity over without a flicker",
        build: () {
          when(() => mockProjectRepository.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(const Projects(data: [])),
          );
          when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
            (_) async => [testBridgeSummary(name: "Macbook-Pro.local")],
          );
          return buildCubit();
        },
        act: (cubit) async {
          // Let the initial empty load and its enrichment land first.
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await cubit.refreshProjects();
          await Future<void>.delayed(Duration.zero);
        },
        // Exactly the two initial emits: the refresh re-emits an identical
        // enriched state (bridges carried over), which bloc dedupes — the row
        // never blinks out.
        expect: () => [
          isA<ProjectListLoaded>().having((s) => s.bridges, "bridges", isEmpty),
          isA<ProjectListLoaded>().having((s) => s.bridges.map((b) => b.name), "bridge names", ["Macbook-Pro.local"]),
        ],
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "hiding the last project enriches the now-empty list with the machine identity",
        build: () {
          when(() => mockProjectRepository.listProjects()).thenAnswer(
            (_) async => ApiResponse.success(Projects(data: [testProject(id: "only")])),
          );
          when(
            () => mockProjectRepository.hideProject(projectId: any(named: "projectId")),
          ).thenAnswer((_) async => ApiResponse.success(null));
          when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer(
            (_) async => [testBridgeSummary(name: "Macbook-Pro.local")],
          );
          return buildCubit();
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero); // non-empty initial load
          await cubit.hideProject("only");
          await Future<void>.delayed(Duration.zero); // enrichment lands
        },
        skip: 1, // the non-empty initial load
        // The local hide reaches the connected-empty body just like an empty
        // fetch does, so it gets the same follow-up machine-identity emit.
        expect: () => [
          isA<ProjectListLoaded>()
              .having((s) => s.projects, "projects", isEmpty)
              .having((s) => s.bridges, "bridges", isEmpty),
          isA<ProjectListLoaded>().having((s) => s.projects, "projects", isEmpty).having(
            (s) => s.bridges.map((b) => b.name),
            "bridge names",
            ["Macbook-Pro.local"],
          ),
        ],
      );
    });

    // -------------------------------------------------------------------------
    // Test 4a: hideProject
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "hideProject: removes project from state and calls repository.hideProject",
      build: () {
        when(() => mockProjectRepository.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [projectA, projectB, projectC])),
        );
        when(
          () => mockProjectRepository.hideProject(projectId: any(named: "projectId")),
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
        verify(() => mockProjectRepository.hideProject(projectId: "B")).called(1);
      },
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "hideProject: reports failure and keeps the project when the bridge rejects the hide",
      build: () {
        when(() => mockProjectRepository.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [projectA, projectB, projectC])),
        );
        when(
          () => mockProjectRepository.hideProject(projectId: any(named: "projectId")),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final hidden = await cubit.hideProject("B");
        expect(hidden, isFalse);
      },
      skip: 1,
      // Nothing was hidden, so no state follows the initial load.
      expect: () => <ProjectListState>[],
    );

    // -------------------------------------------------------------------------
    // Test 4b: createProject success
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "createProject: calls repository, refreshes project list, and returns true on success",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectRepository.createProject(
            parentPath: any(named: "parentPath"),
            name: any(named: "name"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(projectB));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectRepository.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [projectA, projectB])),
        );
        final result = await cubit.createProject(parentPath: "/dev", name: "new");
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
          () => mockProjectRepository.createProject(parentPath: "/dev", name: "new"),
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
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectRepository.createProject(
            parentPath: any(named: "parentPath"),
            name: any(named: "name"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.createProject(parentPath: "/dev", name: "new");
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
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectRepository.createProject(
            parentPath: any(named: "parentPath"),
            name: any(named: "name"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.error(
            ApiError.nonSuccessCode(errorCode: 403, rawErrorString: "permission denied: /dev/new"),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.createProject(parentPath: "/dev", name: "new");
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
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectRepository.discoverProject(
            path: any(named: "path"),
            gitAction: OpenProjectGitAction.promptIfNeeded,
          ),
        ).thenAnswer((_) async => ApiResponse.success(projectB));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectRepository.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [projectA, projectB])),
        );
        final result = await cubit.discoverProject(
          path: "/dev/B",
          gitAction: OpenProjectGitAction.promptIfNeeded,
        );
        expect(result, OpenProjectOutcome.success);
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
        verify(
          () => mockProjectRepository.discoverProject(
            path: "/dev/B",
            gitAction: OpenProjectGitAction.promptIfNeeded,
          ),
        ).called(1);
      },
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "discoverProject: requests a Git choice when the bridge returns 428",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectRepository.discoverProject(
            path: "/dev/plain",
            gitAction: OpenProjectGitAction.promptIfNeeded,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.error(
            ApiError.nonSuccessCode(errorCode: 428, rawErrorString: "Git setup choice required"),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.discoverProject(
          path: "/dev/plain",
          gitAction: OpenProjectGitAction.promptIfNeeded,
        );
        expect(result, OpenProjectOutcome.gitChoiceRequired);
      },
      skip: 1,
      expect: () => <ProjectListState>[],
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "discoverProject: reports incomplete Git setup after opening the folder",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectRepository.discoverProject(
            path: "/dev/plain",
            gitAction: OpenProjectGitAction.initializeGit,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            projectB.copyWith(supportsDedicatedWorktrees: false),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.discoverProject(
          path: "/dev/plain",
          gitAction: OpenProjectGitAction.initializeGit,
        );
        expect(result, OpenProjectOutcome.gitSetupIncomplete);
      },
      skip: 1,
      expect: () => <ProjectListState>[],
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "discoverProject: keeps permission denial distinct",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectRepository.discoverProject(
            path: "/dev/protected",
            gitAction: OpenProjectGitAction.openWithoutGit,
          ),
        ).thenAnswer(
          (_) async => ApiResponse.error(
            ApiError.nonSuccessCode(errorCode: 403, rawErrorString: "permission denied"),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        final result = await cubit.discoverProject(
          path: "/dev/protected",
          gitAction: OpenProjectGitAction.openWithoutGit,
        );
        expect(result, OpenProjectOutcome.permissionDenied);
      },
      skip: 1,
      expect: () => <ProjectListState>[],
    );

    // -------------------------------------------------------------------------
    // Test 4d2: fetchFilesystemSuggestions outcomes
    // -------------------------------------------------------------------------

    test("fetchFilesystemSuggestions returns success with data", () async {
      when(
        () => mockProjectRepository.listProjects(),
      ).thenAnswer((_) async => ApiResponse.success(const Projects(data: [])));
      const suggestions = FilesystemSuggestions(
        data: [FilesystemSuggestion(path: "/dev/a", name: "a", isGitRepo: false)],
        path: "/dev",
      );
      when(
        () => mockProjectRepository.getFilesystemSuggestions(prefix: any(named: "prefix")),
      ).thenAnswer((_) async => ApiResponse.success(suggestions));

      final cubit = buildCubit();
      final result = await cubit.fetchFilesystemSuggestions(prefix: "/dev");

      expect(result, isA<FilesystemSuggestionsSuccess>());
      expect((result as FilesystemSuggestionsSuccess).suggestions.data, hasLength(1));
      await cubit.close();
    });

    test("fetchFilesystemSuggestions returns permissionDenied on a 403", () async {
      when(
        () => mockProjectRepository.listProjects(),
      ).thenAnswer((_) async => ApiResponse.success(const Projects(data: [])));
      when(() => mockProjectRepository.getFilesystemSuggestions(prefix: any(named: "prefix"))).thenAnswer(
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
        () => mockProjectRepository.listProjects(),
      ).thenAnswer((_) async => ApiResponse.success(const Projects(data: [])));
      when(
        () => mockProjectRepository.getFilesystemSuggestions(prefix: any(named: "prefix")),
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
      "renameProject: calls repository, refreshes project list, and returns true on success",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectRepository.renameProject(
            projectId: any(named: "projectId"),
            name: any(named: "name"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(projectA));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          () => mockProjectRepository.renameProject(projectId: "A", name: "New Name"),
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
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [projectA])));
        when(
          () => mockProjectRepository.renameProject(
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
          () => mockProjectRepository.listProjects(),
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
          () => mockProjectRepository.listProjects(),
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
        when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockProjectRepository.listProjects()).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
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
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventTracker.emitProjectActivity({_projectId: 3});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having((s) => s.activityById, "activityById", {_projectId: 3}),
      ],
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "running activity received after REST creates an alphabetical prefix",
      build: () {
        when(() => mockProjectRepository.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [projectA, projectB, projectC])),
        );
        return buildCubit();
      },
      act: (_) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventTracker.emitSessionActivity({
          "A": {"a": const SessionActivityInfo(mainAgentRunning: true)},
          "C": {"c": const SessionActivityInfo(backgroundTaskCount: 1)},
        });
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having(
          (state) => state.projects.map((project) => project.id).toList(),
          "project order",
          ["A", "C", "B"],
        ),
      ],
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "running activity received before REST is applied when projects arrive",
      build: () {
        mockSseEventTracker.emitSessionActivity({
          "A": {"a": const SessionActivityInfo(mainAgentRunning: true)},
          "C": {"c": const SessionActivityInfo(backgroundTaskCount: 1)},
        });
        when(() => mockProjectRepository.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [projectA, projectB, projectC])),
        );
        return buildCubit();
      },
      expect: () => [
        isA<ProjectListLoaded>().having(
          (state) => state.projects.map((project) => project.id).toList(),
          "project order",
          ["A", "C", "B"],
        ),
      ],
    );

    // -------------------------------------------------------------------------
    // Test 11: activity update ignored when not loaded
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "projectActivity update: ignored when state is not ProjectListLoaded",
      build: () {
        final completer = Completer<ApiResponse<Projects>>();
        when(() => mockProjectRepository.listProjects()).thenAnswer((_) => completer.future);
        return buildCubit();
      },
      act: (cubit) async {
        mockSseEventTracker.emitProjectActivity({_projectId: 2});
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
        mockSseEventTracker.emitProjectActivity({_projectId: 2});
        when(
          () => mockProjectRepository.listProjects(),
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
        mockSseEventTracker.emitProjectActivity({_projectId: 1});
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer((_) async => ApiResponse.success(Projects(data: [testProject()])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventTracker.emitProjectActivity(const {});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having((s) => s.activityById, "activityById", isEmpty),
      ],
    );

    // =========================================================================
    // Project timestamp updates (no fetch)
    // =========================================================================

    blocTest<ProjectListCubit, ProjectListState>(
      "projectTimestampUpdates: updates matching project timestamp and re-sorts",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            Projects(
              data: [
                testProject(id: "A", name: "Alpha"),
                testProject(id: "B", name: "Bravo"),
                testProject(id: "C", name: "Charlie"),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventTracker.emitProjectTimestampUpdate({"B": 9999999999999});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having(
          (s) => s.projects.map((p) => p.id).toList(),
          "projects order",
          ["B", "A", "C"],
        ),
      ],
      verify: (_) {
        verify(() => mockProjectRepository.listProjects()).called(1);
      },
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "projectTimestampUpdates: stale update cannot regress or reorder projects",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Projects(
              data: [
                Project(
                  id: "A",
                  name: "Alpha",
                  path: "/A",
                  time: ProjectTime(created: 1000, updated: 3000),
                ),
                Project(
                  id: "B",
                  name: "Bravo",
                  path: "/B",
                  time: ProjectTime(created: 1000, updated: 2000),
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventTracker.emitProjectTimestampUpdate({"A": 1000});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => <ProjectListState>[],
      verify: (cubit) {
        final loaded = cubit.state as ProjectListLoaded;
        expect(loaded.projects.map((project) => project.id), ["A", "B"]);
        expect(loaded.projects.first.time?.updated, 3000);
        verify(() => mockProjectRepository.listProjects()).called(1);
      },
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "projectTimestampUpdates: event during initial fetch is merged before first loaded emit",
      build: () {
        projectFetchCompleter = Completer<ApiResponse<Projects>>();
        when(() => mockProjectRepository.listProjects()).thenAnswer((_) => projectFetchCompleter.future);
        addTearDown(() {
          if (!projectFetchCompleter.isCompleted) {
            projectFetchCompleter.complete(ApiResponse.success(const Projects(data: [])));
          }
        });
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        verify(() => mockProjectRepository.listProjects()).called(1);
        mockSseEventTracker.emitProjectTimestampUpdate({"B": 4000});
        projectFetchCompleter.complete(
          ApiResponse.success(
            const Projects(
              data: [
                Project(
                  id: "A",
                  name: "Alpha",
                  path: "/A",
                  time: ProjectTime(created: 1000, updated: 3000),
                ),
                Project(
                  id: "B",
                  name: "Bravo",
                  path: "/B",
                  time: ProjectTime(created: 1000, updated: 2000),
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<ProjectListLoaded>()
            .having(
              (state) => state.projects.map((project) => project.id).toList(),
              "project order",
              ["B", "A"],
            )
            .having(
              (state) => state.projects.first.time?.updated,
              "live timestamp",
              4000,
            ),
      ],
      verify: (_) {
        verifyNoMoreInteractions(mockProjectRepository);
      },
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "projectTimestampUpdates: ignores unknown project IDs",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            Projects(
              data: [testProject(id: "A", name: "Alpha")],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventTracker.emitProjectTimestampUpdate({"unknown": 9999999999999});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => <ProjectListState>[],
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "projectTimestampUpdates: ignores projects with null time",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Projects(
              data: [
                Project(id: "A", name: "Alpha", path: "/A", time: null),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventTracker.emitProjectTimestampUpdate({"A": 9999999999999});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => <ProjectListState>[],
      verify: (_) {
        verify(() => mockProjectRepository.listProjects()).called(1);
      },
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "projectTimestampUpdates: ignored when state is not ProjectListLoaded",
      build: () {
        final completer = Completer<ApiResponse<Projects>>();
        when(() => mockProjectRepository.listProjects()).thenAnswer((_) => completer.future);
        return buildCubit();
      },
      act: (cubit) async {
        mockSseEventTracker.emitProjectTimestampUpdate({"A": 9999999999999});
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => <ProjectListState>[],
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "projectTimestampUpdates: sorts by updated desc then effective name then id",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Projects(
              data: [
                Project(
                  id: "B",
                  name: "Bravo",
                  time: ProjectTime(created: 1000, updated: 2000),
                  path: "/B",
                ),
                Project(
                  id: "a",
                  name: "alpha",
                  time: ProjectTime(created: 1000, updated: 3000),
                  path: "/a",
                ),
                Project(
                  id: "A",
                  name: "Alpha",
                  time: ProjectTime(created: 1000, updated: 3000),
                  path: "/A",
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        mockSseEventTracker.emitProjectTimestampUpdate({"B": 3000});
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<ProjectListLoaded>().having(
          (s) => s.projects.map((p) => p.id).toList(),
          "projects order",
          ["A", "a", "B"],
        ),
      ],
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "REST project list is sorted by updated desc then effective name then id",
      build: () {
        when(
          () => mockProjectRepository.listProjects(),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            const Projects(
              data: [
                Project(id: "null", name: "First", path: "/null", time: null),
                Project(
                  id: "B",
                  name: "bravo",
                  path: "/B",
                  time: ProjectTime(created: 1000, updated: 2000),
                ),
                Project(
                  id: "a",
                  name: "alpha",
                  path: "/a",
                  time: ProjectTime(created: 1000, updated: 3000),
                ),
                Project(
                  id: "A",
                  name: "Alpha",
                  path: "/A",
                  time: ProjectTime(created: 1000, updated: 3000),
                ),
              ],
            ),
          ),
        );
        return buildCubit();
      },
      expect: () => [
        isA<ProjectListLoaded>().having(
          (s) => s.projects.map((p) => p.id).toList(),
          "projects order",
          ["A", "a", "B", "null"],
        ),
      ],
    );

    // =========================================================================
    // Throttled project data refresh
    // =========================================================================

    group("throttled project data refresh", () {
      test("activity event triggers refresh after throttle duration", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectRepository.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success(Projects(data: [testProject()]));
          });
          mockRouteSource.emitRoute(AppRouteDef.projects);
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          final baseline = fetchCount;

          mockSseEventTracker.emitProjectActivity({_projectId: 1});
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
          when(() => mockProjectRepository.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success(Projects(data: [testProject()]));
          });
          mockRouteSource.emitRoute(AppRouteDef.projects);
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          final baseline = fetchCount;

          for (var i = 0; i < 5; i++) {
            mockSseEventTracker.emitProjectActivity({_projectId: i});
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
          when(() => mockProjectRepository.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success(Projects(data: [testProject()]));
          });
          final cubit = buildCubit(); // route = null
          async.elapse(Duration.zero);
          expect(fetchCount, 1, reason: "only manual load");

          mockSseEventTracker.emitProjectActivity({_projectId: 1});
          async.elapse(const Duration(seconds: 60));

          expect(fetchCount, 1, reason: "no auto-refresh when page not visible");
          cubit.close();
        });
      });

      test("immediate refresh when navigating back to projects page", () {
        fakeAsync((FakeAsync async) {
          var fetchCount = 0;
          when(() => mockProjectRepository.listProjects()).thenAnswer((_) async {
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
          when(() => mockProjectRepository.listProjects()).thenAnswer((_) async {
            fetchCount++;
            return ApiResponse.success(Projects(data: [testProject()]));
          });
          mockRouteSource.emitRoute(AppRouteDef.projects);
          final cubit = buildCubit();
          async.elapse(Duration.zero);
          final baseline = fetchCount;

          mockSseEventTracker.emitProjectActivity({_projectId: 1});
          async.elapse(refreshThrottleDuration);
          expect(fetchCount, baseline + 1, reason: "first window");

          mockSseEventTracker.emitProjectActivity({_projectId: 2});
          async.elapse(refreshThrottleDuration);
          expect(fetchCount, baseline + 2, reason: "second window");
          cubit.close();
        });
      });
    });

    blocTest<ProjectListCubit, ProjectListState>(
      "connection reconnect triggers silent refresh",
      build: () {
        when(() => mockProjectRepository.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [testProject()])),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Change mock to return updated data
        when(() => mockProjectRepository.listProjects()).thenAnswer(
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
        when(() => mockProjectRepository.listProjects()).thenAnswer(
          (_) async => ApiResponse.error(ApiError.generic()),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        // Switch mock to succeed so the reconnect-triggered load works.
        when(() => mockProjectRepository.listProjects()).thenAnswer(
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
        when(() => mockProjectRepository.listProjects()).thenAnswer(
          (_) async => ApiResponse.success(Projects(data: [testProject()])),
        );
        return buildCubit();
      },
      act: (cubit) async {
        // Wait for initial load to complete.
        await Future<void>.delayed(Duration.zero);
        // Reset interaction count after initial load.
        reset(mockProjectRepository);

        // Use a Completer so the first refresh stays in-flight while the
        // second ConnectionConnected arrives — this is what exercises the guard.
        final completer = Completer<ApiResponse<Projects>>();
        when(() => mockProjectRepository.listProjects()).thenAnswer((_) => completer.future);

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
        verify(() => mockProjectRepository.listProjects()).called(1);
      },
    );

    blocTest<ProjectListCubit, ProjectListState>(
      "ConnectionConnected while state is loading does not trigger refresh",
      build: () {
        when(() => mockProjectRepository.listProjects()).thenAnswer(
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
        verify(() => mockProjectRepository.listProjects()).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // retryLoadProjects
    // -------------------------------------------------------------------------

    blocTest<ProjectListCubit, ProjectListState>(
      "retryLoadProjects: reconnects and loads projects when connection is lost",
      build: () {
        when(() => mockProjectRepository.listProjects()).thenAnswer(
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
        when(() => mockProjectRepository.listProjects()).thenAnswer(
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
        when(() => mockProjectRepository.listProjects()).thenAnswer(
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
        when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          verify(() => mockProjectRepository.listProjects()).called(2);
        },
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "stale signal is ignored when state is not ProjectListLoaded",
        build: () {
          when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          verify(() => mockProjectRepository.listProjects()).called(1);
        },
      );

      blocTest<ProjectListCubit, ProjectListState>(
        "stale + ConnectionConnected refresh coalesced into single API call",
        build: () {
          when(() => mockProjectRepository.listProjects()).thenAnswer(
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
          verify(() => mockProjectRepository.listProjects()).called(2);
        },
      );
    });
  });
}
