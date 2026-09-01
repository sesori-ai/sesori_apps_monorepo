import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockConnectionService() extends Mock implements ConnectionService;

class _RecordingAttributionRepository() extends Mock implements AttributionRepository {
  final readiness = StreamController<void>.broadcast(sync: true);
  final events = <AttributionEvent>[];

  @override
  Stream<void> get readinessStream => readiness.stream;

  @override
  Future<AnalyticsDeliveryResult> logEvent({required AttributionEvent event}) async {
    events.add(event);
    return AnalyticsDeliveryResult.acceptedBySdk;
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
    statuses = BehaviorSubject.seeded(_connected);
    when(() => connectionService.status).thenAnswer((_) => statuses.stream);
    when(() => connectionService.currentStatus).thenAnswer((_) => statuses.value);
    service = AttributionService(repository: repository, connectionService: connectionService);
  });

  tearDown(() async {
    await service.dispose();
    await repository.readiness.close();
    await statuses.close();
  });

  test("reports the replayed and each subsequent connected status", () async {
    service.start();
    await Future<void>.delayed(Duration.zero);
    statuses
      ..add(const ConnectionStatus.connectionLost(config: _config))
      ..add(_connected);
    await Future<void>.delayed(Duration.zero);

    expect(repository.events, [
      AttributionEvent.bridgePaired,
      AttributionEvent.bridgePaired,
    ]);
  });

  test("re-reports an established connection when the sink becomes ready", () async {
    service.start();
    await Future<void>.delayed(Duration.zero);
    repository.readiness.add(null);

    expect(repository.events, [
      AttributionEvent.bridgePaired,
      AttributionEvent.bridgePaired,
    ]);

    statuses.add(const ConnectionStatus.connectionLost(config: _config));
    repository.readiness.add(null);
    expect(repository.events, hasLength(2));
  });
}
