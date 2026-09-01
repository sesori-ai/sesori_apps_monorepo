import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockConnectionService() extends Mock implements ConnectionService;

class _RecordingAttributionRepository() extends Mock implements AttributionRepository {
  final events = <AttributionEvent>[];
  AnalyticsDeliveryResult result = AnalyticsDeliveryResult.acceptedBySdk;

  @override
  Future<AnalyticsDeliveryResult> logEvent({required AttributionEvent event}) async {
    events.add(event);
    return result;
  }
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
const _health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

void main() {
  late _RecordingAttributionRepository repository;
  late _MockConnectionService connectionService;
  late BehaviorSubject<ConnectionStatus> statuses;
  late AttributionService service;

  setUp(() {
    repository = _RecordingAttributionRepository();
    connectionService = _MockConnectionService();
    statuses = BehaviorSubject.seeded(const ConnectionStatus.disconnected());
    when(() => connectionService.status).thenAnswer((_) => statuses.stream);
    service = AttributionService(repository: repository, connectionService: connectionService);
  });

  tearDown(() async {
    await service.dispose();
    await statuses.close();
  });

  test("routes authentication attribution through one coordinator", () async {
    expect(
      await service.reportAuthenticationCompleted(accountStatus: AccountStatus.created),
      AnalyticsDeliveryResult.acceptedBySdk,
    );
    expect(repository.events, [
      AttributionEvent.accountCreated,
      AttributionEvent.accountLogin,
    ]);

    repository.events.clear();
    await service.reportAuthenticationCompleted(accountStatus: AccountStatus.unknown);

    expect(repository.events, [AttributionEvent.accountLogin]);
  });

  test("buffers only canonical full activation until the crawl-gated listener starts", () async {
    await service.reportProductOutcome(
      event: const ProductAnalyticsEvent.sessionCreationFailed(
        failureReason: AnalyticsSessionCreationFailureReason.serverRejected,
        workspaceKind: AnalyticsWorkspaceKind.project,
      ),
    );
    await service.reportProductOutcome(
      event: const ProductAnalyticsEvent.sessionMessageSent(
        submission: AnalyticsSubmission.command(),
      ),
    );
    await service.reportProductOutcome(
      event: const ProductAnalyticsEvent.sessionCreatedWithMessage(
        submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
        workspaceKind: AnalyticsWorkspaceKind.dedicatedWorktree,
      ),
    );

    expect(repository.events, isEmpty);

    await service.start();
    await Future<void>.delayed(Duration.zero);
    expect(repository.events, [AttributionEvent.firstSessionRun]);

    await service.reportProductOutcome(
      event: const ProductAnalyticsEvent.sessionMessageSent(
        submission: AnalyticsSubmission.command(),
      ),
    );
    expect(repository.events, [
      AttributionEvent.firstSessionRun,
      AttributionEvent.firstSessionRun,
    ]);
  });

  test("the started listener reports connected status and owns repeat transitions", () async {
    await statuses.close();
    statuses = BehaviorSubject.seeded(_connected);
    when(() => connectionService.status).thenAnswer((_) => statuses.stream);

    await service.start();
    await Future<void>.delayed(Duration.zero);
    await service.start();
    statuses
      ..add(const ConnectionStatus.connectionLost(config: _config))
      ..add(_connected);
    await Future<void>.delayed(Duration.zero);

    expect(repository.events, [
      AttributionEvent.bridgePaired,
      AttributionEvent.bridgePaired,
    ]);
  });
}
