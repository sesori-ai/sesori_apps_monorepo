import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:test/test.dart";

class _MockAttributionApi() extends Mock implements AttributionApi;

class _MemoryAttributionClaimStorage() implements AttributionClaimStorage {
  final claimedEvents = <AttributionEvent>{};
  final operations = <String>[];
  Completer<bool>? readGate;
  bool throwOnRead = false;
  bool throwOnWrite = false;
  int reads = 0;
  int writes = 0;

  @override
  Future<bool> isClaimed({required AttributionEvent event}) async {
    reads += 1;
    operations.add("read");
    if (throwOnRead) throw StateError("claim read failed");
    final gate = readGate;
    return gate == null ? claimedEvents.contains(event) : await gate.future;
  }

  @override
  Future<void> markClaimed({required AttributionEvent event}) async {
    writes += 1;
    operations.add("write");
    if (throwOnWrite) throw StateError("claim write failed");
    claimedEvents.add(event);
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

  test("maps authentication outcomes in registration-before-login order", () async {
    final repository = buildRepository();

    expect(
      await repository.reportAuthenticationCompleted(accountStatus: AccountStatus.created),
      AnalyticsDeliveryResult.acceptedBySdk,
    );
    verifyInOrder([
      () => api.logEvent(event: AttributionEvent.accountCreated),
      () => api.logEvent(event: AttributionEvent.accountLogin),
    ]);

    clearInteractions(api);
    await repository.reportAuthenticationCompleted(accountStatus: AccountStatus.unknown);
    verify(() => api.logEvent(event: AttributionEvent.accountLogin)).called(1);
    verifyNever(() => api.logEvent(event: AttributionEvent.accountCreated));
  });

  test("retains one canonical product outcome until crawl-gated start", () async {
    final repository = buildRepository();

    await repository.reportProductOutcome(
      event: const ProductAnalyticsEvent.sessionCreationFailed(
        failureReason: AnalyticsSessionCreationFailureReason.serverRejected,
        workspaceKind: AnalyticsWorkspaceKind.project,
      ),
    );
    await repository.reportProductOutcome(
      event: const ProductAnalyticsEvent.sessionMessageSent(
        submission: AnalyticsSubmission.command(),
      ),
    );
    await repository.reportProductOutcome(
      event: const ProductAnalyticsEvent.sessionCreatedWithMessage(
        submission: AnalyticsSubmission.text(inputMode: AnalyticsInputMode.typed),
        workspaceKind: AnalyticsWorkspaceKind.dedicatedWorktree,
      ),
    );
    verifyNever(() => api.logEvent(event: any(named: "event")));

    await repository.start();
    await repository.start();
    await repository.reportProductOutcome(
      event: const ProductAnalyticsEvent.sessionMessageSent(
        submission: AnalyticsSubmission.command(),
      ),
    );

    verify(() => api.logEvent(event: AttributionEvent.firstSessionRun)).called(1);
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

  test("claims before SDK delivery and suppresses repeats for this process", () async {
    final operations = claimStorage.operations;
    when(() => api.logEvent(event: AttributionEvent.bridgePaired)).thenAnswer((_) async {
      operations.add("api");
    });
    final repository = buildRepository();

    expect(
      await repository.logEvent(event: AttributionEvent.bridgePaired),
      AnalyticsDeliveryResult.acceptedBySdk,
    );
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
    claimStorage.claimedEvents.add(AttributionEvent.firstSessionRun);
    final repository = buildRepository();

    expect(
      await repository.logEvent(event: AttributionEvent.firstSessionRun),
      AnalyticsDeliveryResult.acceptedBySdk,
    );

    expect(claimStorage.reads, 1);
    expect(claimStorage.writes, 0);
    verifyNever(() => api.logEvent(event: any(named: "event")));
  });

  test("concurrent first claims coalesce to one marker and SDK call", () async {
    final readGate = claimStorage.readGate = Completer<bool>();
    final repository = buildRepository();

    final first = repository.logEvent(event: AttributionEvent.firstSessionRun);
    final second = repository.logEvent(event: AttributionEvent.firstSessionRun);
    await Future<void>.delayed(Duration.zero);
    readGate.complete(false);

    expect(await Future.wait([first, second]), [
      AnalyticsDeliveryResult.acceptedBySdk,
      AnalyticsDeliveryResult.acceptedBySdk,
    ]);
    expect(claimStorage.reads, 1);
    expect(claimStorage.writes, 1);
    verify(() => api.logEvent(event: AttributionEvent.firstSessionRun)).called(1);
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
