import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:test/test.dart";

class _MockAttributionApi() extends Mock implements AttributionApi;

class _MemoryAttributionClaimStorage() implements AttributionClaimStorage {
  final claimedKeys = <String>{};
  final operations = <String>[];
  bool throwOnRead = false;
  bool throwOnWrite = false;
  int reads = 0;
  int writes = 0;

  @override
  Future<bool> isClaimed({required String claimKey}) async {
    reads += 1;
    operations.add("read");
    if (throwOnRead) throw StateError("claim read failed");
    return claimedKeys.contains(claimKey);
  }

  @override
  Future<void> markClaimed({required String claimKey}) async {
    writes += 1;
    operations.add("write");
    if (throwOnWrite) throw StateError("claim write failed");
    claimedKeys.add(claimKey);
  }
}

void main() {
  late _MockAttributionApi api;
  late _MemoryAttributionClaimStorage claimStorage;

  setUpAll(() {
    registerFallbackValue(AttributionEvent.accountLogin);
  });

  setUp(() {
    api = _MockAttributionApi();
    claimStorage = _MemoryAttributionClaimStorage();
    when(() => api.isReady).thenReturn(true);
    when(() => api.logEvent(event: any(named: "event"))).thenAnswer((_) async {});
  });

  AttributionRepository buildRepository() => AttributionRepository(api: api, claimStorage: claimStorage);

  test("repeatable events map SDK acceptance and failure without claim storage", () async {
    final repository = buildRepository();

    expect(
      await repository.logEvent(event: AttributionEvent.accountCreated),
      AnalyticsDeliveryResult.acceptedBySdk,
    );

    when(() => api.logEvent(event: any(named: "event"))).thenThrow(StateError("sdk unavailable"));
    expect(
      await repository.logEvent(event: AttributionEvent.accountLogin),
      AnalyticsDeliveryResult.failed,
    );
    expect(claimStorage.reads, 0);
    expect(claimStorage.writes, 0);
  });

  test("an unavailable sink does not claim a one-shot event", () async {
    when(() => api.isReady).thenReturn(false);
    final repository = buildRepository();

    expect(
      await repository.logEvent(event: AttributionEvent.bridgePaired),
      AnalyticsDeliveryResult.failed,
    );
    expect(claimStorage.reads, 0);
    expect(claimStorage.writes, 0);
    verifyNever(() => api.logEvent(event: any(named: "event")));
  });

  test("claims before SDK delivery and suppresses repeats even while the sink is unavailable", () async {
    final operations = claimStorage.operations;
    when(() => api.logEvent(event: AttributionEvent.bridgePaired)).thenAnswer((_) async {
      operations.add("api");
    });
    final repository = buildRepository();

    expect(
      await repository.logEvent(event: AttributionEvent.bridgePaired),
      AnalyticsDeliveryResult.acceptedBySdk,
    );
    when(() => api.isReady).thenReturn(false);
    expect(
      await repository.logEvent(event: AttributionEvent.bridgePaired),
      AnalyticsDeliveryResult.acceptedBySdk,
    );

    expect(operations, ["read", "write", "api"]);
    expect(claimStorage.reads, 1);
    expect(claimStorage.writes, 1);
    verify(() => api.logEvent(event: AttributionEvent.bridgePaired)).called(1);
  });

  test("a persisted claim suppresses delivery after repository restart", () async {
    claimStorage.claimedKeys.add("first_session_run_v1");
    final repository = buildRepository();

    expect(
      await repository.logEvent(event: AttributionEvent.firstSessionRun),
      AnalyticsDeliveryResult.acceptedBySdk,
    );

    expect(claimStorage.reads, 1);
    expect(claimStorage.writes, 0);
    verifyNever(() => api.logEvent(event: any(named: "event")));
  });

  test("a failed claim read fails this attempt but remains safely retryable", () async {
    claimStorage.throwOnRead = true;
    final repository = buildRepository();

    expect(
      await repository.logEvent(event: AttributionEvent.bridgePaired),
      AnalyticsDeliveryResult.failed,
    );
    expect(claimStorage.writes, 0);
    verifyNever(() => api.logEvent(event: any(named: "event")));

    claimStorage.throwOnRead = false;
    expect(
      await repository.logEvent(event: AttributionEvent.bridgePaired),
      AnalyticsDeliveryResult.acceptedBySdk,
    );
    expect(claimStorage.reads, 2);
    expect(claimStorage.writes, 1);
    verify(() => api.logEvent(event: AttributionEvent.bridgePaired)).called(1);
  });

  test("a failed claim write fails this attempt but remains safely retryable", () async {
    claimStorage.throwOnWrite = true;
    final repository = buildRepository();

    expect(
      await repository.logEvent(event: AttributionEvent.firstSessionRun),
      AnalyticsDeliveryResult.failed,
    );
    verifyNever(() => api.logEvent(event: any(named: "event")));

    claimStorage.throwOnWrite = false;
    expect(
      await repository.logEvent(event: AttributionEvent.firstSessionRun),
      AnalyticsDeliveryResult.acceptedBySdk,
    );
    expect(claimStorage.reads, 2);
    expect(claimStorage.writes, 2);
    verify(() => api.logEvent(event: AttributionEvent.firstSessionRun)).called(1);
  });

  test("a failed SDK call remains claimed instead of risking a duplicate", () async {
    when(() => api.logEvent(event: AttributionEvent.bridgePaired)).thenThrow(StateError("sdk unavailable"));
    final repository = buildRepository();

    expect(
      await repository.logEvent(event: AttributionEvent.bridgePaired),
      AnalyticsDeliveryResult.failed,
    );
    when(() => api.logEvent(event: AttributionEvent.bridgePaired)).thenAnswer((_) async {});
    expect(
      await repository.logEvent(event: AttributionEvent.bridgePaired),
      AnalyticsDeliveryResult.acceptedBySdk,
    );

    verify(() => api.logEvent(event: AttributionEvent.bridgePaired)).called(1);
  });

  test("a stalled SDK operation fails after the bounded delivery deadline", () async {
    final repository = AttributionRepository.withDeliveryDeadline(
      api: api,
      claimStorage: claimStorage,
      deliveryDeadline: Duration.zero,
    );
    when(() => api.logEvent(event: any(named: "event"))).thenAnswer((_) => Completer<void>().future);

    expect(
      await repository.logEvent(event: AttributionEvent.accountLogin),
      AnalyticsDeliveryResult.failed,
    );
  });
}
