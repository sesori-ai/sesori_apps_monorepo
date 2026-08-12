import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/project_view_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockProjectViewRepository extends Mock implements ProjectViewRepository {}

class _MockConnectionService extends Mock implements ConnectionService {}

class _FakeLifecycleSource implements LifecycleSource {
  final BehaviorSubject<LifecycleState> states;

  _FakeLifecycleSource() : states = BehaviorSubject.seeded(LifecycleState.resumed);

  _FakeLifecycleSource.blocking({required FutureOr<void> Function() onCancel})
    : states = BehaviorSubject.seeded(LifecycleState.resumed, onCancel: onCancel);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => states.stream;
}

class _FakeRouteSource implements RouteSource {
  final BehaviorSubject<AppRouteDef?> routes;

  _FakeRouteSource({required AppRouteDef? initialRoute}) : routes = BehaviorSubject.seeded(initialRoute);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => routes.stream;

  @override
  String? currentLocation;
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token");
const _health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

void main() {
  group("ProjectViewingService", () {
    late _MockProjectViewRepository repository;
    late _MockConnectionService connectionService;
    late _FakeLifecycleSource lifecycleSource;
    late _FakeRouteSource routeSource;
    late BehaviorSubject<ConnectionStatus> statuses;
    late List<String?> sent;
    late ProjectViewingService service;

    setUp(() {
      repository = _MockProjectViewRepository();
      connectionService = _MockConnectionService();
      lifecycleSource = _FakeLifecycleSource();
      routeSource = _FakeRouteSource(initialRoute: AppRouteDef.sessions);
      statuses = BehaviorSubject.seeded(_connected);
      sent = <String?>[];
      when(() => connectionService.status).thenAnswer((_) => statuses.stream);
      when(() => connectionService.currentStatus).thenAnswer((_) => statuses.value);
      when(() => repository.sendProjectView(projectId: any(named: "projectId"))).thenAnswer((invocation) async {
        sent.add(invocation.namedArguments[#projectId] as String?);
      });
      service = ProjectViewingService(
        viewRepository: repository,
        lifecycleSource: lifecycleSource,
        connectionService: connectionService,
        routeSource: routeSource,
      );
    });

    tearDown(() async {
      await service.onDispose();
      await Future.wait([
        lifecycleSource.states.close(),
        routeSource.routes.close(),
        statuses.close(),
      ]);
    });

    Future<void> drain() async {
      await Future<void>.delayed(Duration.zero);
      await service.sendTail;
      await Future<void>.delayed(Duration.zero);
    }

    ProjectViewClaim readyList(String projectId) {
      final claim = service.beginListClaim(projectId: projectId);
      service.markClaimReady(claim: claim, projectId: projectId);
      return claim;
    }

    ProjectViewPaneClaim showWideListPane() {
      final claim = service.beginWideListPaneClaim();
      service.setWideListPaneVisible(claim: claim, isVisible: true);
      return claim;
    }

    test("a list claim declares only after its first successful snapshot", () async {
      final claim = service.beginListClaim(projectId: "project-1");
      await drain();
      expect(sent, isEmpty);

      service.markClaimReady(claim: claim, projectId: "project-1");
      await drain();
      expect(sent, ["project-1"]);

      service.markClaimReady(claim: claim, projectId: "project-1");
      await drain();
      expect(sent, ["project-1"], reason: "unchanged ready snapshots must not resend");
    });

    test("same-project list to detail handoff never declares a false clear", () async {
      readyList("project-1");
      await drain();

      routeSource.routes.add(AppRouteDef.sessionDetail);
      final detail = service.beginDetailClaim(projectId: "project-1");
      await drain();
      expect(sent, ["project-1"]);

      service.markClaimReady(claim: detail, projectId: "project-1");
      await drain();
      expect(sent, ["project-1"]);
    });

    test("narrow covered routes clear and returning to the list reasserts", () async {
      readyList("project-1");
      await drain();

      routeSource.routes.add(AppRouteDef.newSession);
      await drain();
      routeSource.routes.add(AppRouteDef.sessions);
      await drain();

      expect(sent, ["project-1", null, "project-1"]);
    });

    test("an actually mounted wide list pane stays effective on covered routes", () async {
      readyList("project-1");
      await drain();
      showWideListPane();

      routeSource.routes.add(AppRouteDef.newSession);
      await drain();
      routeSource.routes.add(AppRouteDef.sessionDiffs);
      await drain();

      expect(sent, ["project-1"]);
    });

    test("detail child routes hide detail and fall back only to a visible wide list", () async {
      readyList("project-list");
      await drain();
      routeSource.routes.add(AppRouteDef.sessionDetail);
      final detail = service.beginDetailClaim(projectId: "project-detail");
      service.markClaimReady(claim: detail, projectId: "project-detail");
      await drain();
      expect(sent, ["project-list", "project-detail"]);

      final paneClaim = showWideListPane();
      routeSource.routes.add(AppRouteDef.sessionDiffs);
      await drain();
      expect(sent.last, "project-list");

      service.setWideListPaneVisible(claim: paneClaim, isVisible: false);
      await drain();
      expect(sent.last, isNull);
    });

    test("an obsolete wide shell cannot clear its replacement's list pane", () async {
      routeSource.routes.add(AppRouteDef.sessionDetail);
      await drain();
      readyList("project-1");
      final oldPane = showWideListPane();
      await drain();

      readyList("project-2");
      showWideListPane();
      service.releaseWideListPaneClaim(claim: oldPane);
      await drain();

      expect(sent, ["project-1", "project-2"]);
      expect(service.declaredProjectId, "project-2");
    });

    test("an obsolete wide shell cannot reclaim pane ownership with a late positive report", () async {
      routeSource.routes.add(AppRouteDef.sessionDetail);
      await drain();
      readyList("project-1");
      final obsoletePane = showWideListPane();
      await drain();

      showWideListPane();
      service.setWideListPaneVisible(claim: obsoletePane, isVisible: true);
      service.releaseWideListPaneClaim(claim: obsoletePane);
      await drain();

      expect(sent, ["project-1"]);
      expect(service.declaredProjectId, "project-1");
    });

    test("a ready visible wide list remains declared while a direct detail load is pending", () async {
      routeSource.routes.add(AppRouteDef.sessionDetail);
      await drain();
      service.beginDetailClaim(projectId: "project-1");
      readyList("project-1");
      showWideListPane();
      await drain();

      expect(sent, ["project-1"]);
      expect(service.declaredProjectId, "project-1");
    });

    test("failed detail loading releases a narrow transition handoff", () async {
      readyList("project-1");
      await drain();
      routeSource.routes.add(AppRouteDef.sessionDetail);
      final detail = service.beginDetailClaim(projectId: "project-1");
      await drain();

      service.markClaimFailed(claim: detail);
      await drain();

      expect(sent, ["project-1", null]);
    });

    test("cross-project replacement and late clears cannot erase the new claim", () async {
      final oldList = readyList("project-1");
      await drain();
      routeSource.routes.add(AppRouteDef.sessionDetail);
      final oldDetail = service.beginDetailClaim(projectId: "project-2");
      service.markClaimReady(claim: oldDetail, projectId: "project-2");
      await drain();

      final currentDetail = service.beginDetailClaim(projectId: "project-3");
      service.markClaimReady(claim: currentDetail, projectId: "project-3");
      service.releaseClaim(claim: oldList);
      service.releaseClaim(claim: oldDetail);
      await drain();

      expect(sent.last, "project-3");
      expect(sent.where((projectId) => projectId == "project-3"), hasLength(1));
    });

    test("background clears once and resume reasserts the visible project", () async {
      readyList("project-1");
      await drain();

      lifecycleSource.states.add(LifecycleState.hidden);
      lifecycleSource.states.add(LifecycleState.paused);
      await drain();
      lifecycleSource.states.add(LifecycleState.resumed);
      await drain();

      expect(sent, ["project-1", null, "project-1"]);
    });

    test("reconnect reasserts only a project still visible under the current route", () async {
      readyList("project-1");
      await drain();
      statuses.add(const ConnectionStatus.connectionLost(config: _config));
      statuses.add(_connected);
      await drain();
      expect(sent, ["project-1", "project-1"]);

      routeSource.routes.add(AppRouteDef.newSession);
      await drain();
      statuses.add(const ConnectionStatus.connectionLost(config: _config));
      statuses.add(_connected);
      await drain();
      expect(sent.last, isNull);
      expect(sent.where((projectId) => projectId == "project-1"), hasLength(2));
    });

    test("a newly created session detail declares its project immediately after loading", () async {
      routeSource.routes.add(AppRouteDef.newSession);
      final list = service.beginListClaim(projectId: "project-1");
      service.markClaimReady(claim: list, projectId: "project-1");
      await drain();
      expect(sent, isEmpty, reason: "the narrow new-session route covers the list");

      routeSource.routes.add(AppRouteDef.sessionDetail);
      final detail = service.beginDetailClaim(projectId: "project-1");
      await drain();
      expect(sent, isEmpty, reason: "detail loading alone is not visible readiness");

      service.markClaimReady(claim: detail, projectId: "project-1");
      await drain();
      expect(sent, ["project-1"]);
    });

    test("serialized sends observe replacement order without a late-clear regression", () async {
      final firstSend = Completer<void>();
      var first = true;
      when(() => repository.sendProjectView(projectId: any(named: "projectId"))).thenAnswer((invocation) async {
        sent.add(invocation.namedArguments[#projectId] as String?);
        if (first) {
          first = false;
          await firstSend.future;
        }
      });

      final oldClaim = readyList("project-1");
      await Future<void>.delayed(Duration.zero);
      final currentClaim = service.beginListClaim(projectId: "project-2");
      service.markClaimReady(claim: currentClaim, projectId: "project-2");
      service.releaseClaim(claim: oldClaim);
      firstSend.complete();
      await drain();

      expect(sent, ["project-1", "project-2"]);
    });

    test("disposal rejects new claims while subscription cancellation is pending", () async {
      await service.onDispose();
      await lifecycleSource.states.close();
      final cancellationStarted = Completer<void>();
      final allowCancellation = Completer<void>();
      lifecycleSource = _FakeLifecycleSource.blocking(
        onCancel: () {
          cancellationStarted.complete();
          return allowCancellation.future;
        },
      );
      service = ProjectViewingService(
        viewRepository: repository,
        lifecycleSource: lifecycleSource,
        connectionService: connectionService,
        routeSource: routeSource,
      );

      final disposal = service.onDispose();
      await cancellationStarted.future;

      expect(
        () => service.beginListClaim(projectId: "project-during-disposal"),
        throwsStateError,
      );

      allowCancellation.complete();
      await disposal;
    });
  });
}
