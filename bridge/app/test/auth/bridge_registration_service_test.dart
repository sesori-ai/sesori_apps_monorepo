import "dart:io";

import "package:sesori_bridge/src/auth/bridge_registration_api.dart";
import "package:sesori_bridge/src/auth/bridge_registration_repository.dart";
import "package:sesori_bridge/src/auth/bridge_registration_service.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  late FakeBridgeRegistrationRepository repository;
  late FakeBridgeIdStorage bridgeIdStorage;
  late _RecordingTokenRefresher tokenRefresher;
  late BridgeRegistrationService service;

  setUp(() {
    repository = FakeBridgeRegistrationRepository();
    bridgeIdStorage = FakeBridgeIdStorage();
    tokenRefresher = _RecordingTokenRefresher();
    service = BridgeRegistrationService(
      repository: repository,
      tokenRefresher: tokenRefresher,
      bridgeIdStorage: bridgeIdStorage,
      hostName: "dev-laptop",
      platform: "macos",
    );
  });

  group("BridgeRegistrationService.ensureRegistered", () {
    test("registers without a bridge id and persists the server-minted id", () async {
      await service.ensureRegistered();

      expect(repository.registeredBridgeIds, equals([null]));
      expect(service.bridgeId, equals("br_test1234"));
      expect(bridgeIdStorage.bridgeId, equals("br_test1234"));
    });

    test("posts the persisted bridge id when one exists", () async {
      bridgeIdStorage.bridgeId = "br_persisted1";
      repository.nextBridgeId = "br_persisted1";

      await service.ensureRegistered();

      expect(repository.registeredBridgeIds, equals(["br_persisted1"]));
      expect(service.bridgeId, equals("br_persisted1"));
      expect(bridgeIdStorage.bridgeId, equals("br_persisted1"));
    });

    test("is memoized per process — a second call does not re-register", () async {
      await service.ensureRegistered();
      await service.ensureRegistered();

      expect(repository.registeredBridgeIds, hasLength(1));
    });

    test("failure propagates and the next call retries the registration", () async {
      repository.registerError = BridgeRegistrationException(statusCode: 500, body: "boom");

      await expectLater(service.ensureRegistered(), throwsA(isA<BridgeRegistrationException>()));
      expect(service.bridgeId, isNull);

      repository.registerError = null;
      await service.ensureRegistered();

      expect(repository.registeredBridgeIds, hasLength(2));
      expect(service.bridgeId, equals("br_test1234"));
    });

    test("retries once with a force-refreshed token on 401", () async {
      repository.registerError = BridgeRegistrationException(statusCode: 401, body: "expired");
      tokenRefresher.onForceRefresh = () {
        repository.registerError = null;
      };

      await service.ensureRegistered();

      expect(repository.registeredBridgeIds, hasLength(2));
      expect(tokenRefresher.forceRefreshCalls, equals(1));
      expect(service.bridgeId, equals("br_test1234"));
    });
  });

  group("BridgeRegistrationService.sanitizeBridgeName", () {
    test("passes a normal hostname through unchanged", () {
      expect(BridgeRegistrationService.sanitizeBridgeName("Alexs-MacBook"), equals("Alexs-MacBook"));
    });

    test("truncates names longer than the server's 120-char limit", () {
      final long = "h" * 200;
      expect(BridgeRegistrationService.sanitizeBridgeName(long).length, equals(120));
    });

    test("falls back to a default for empty or whitespace-only names", () {
      expect(BridgeRegistrationService.sanitizeBridgeName("   "), equals("sesori-bridge"));
    });
  });

  group("BridgeRegistrationService.handleBridgeRevoked", () {
    test("clears the persisted bridge id and re-registers fresh on the next attempt", () async {
      await service.ensureRegistered();
      repository.nextBridgeId = "br_fresh5678";

      await service.handleBridgeRevoked();

      expect(service.bridgeId, isNull);
      expect(bridgeIdStorage.bridgeId, isNull);

      await service.ensureRegistered();

      expect(repository.registeredBridgeIds, equals([null, null]));
      expect(service.bridgeId, equals("br_fresh5678"));
      expect(bridgeIdStorage.bridgeId, equals("br_fresh5678"));
    });

    test("still resets the memoization when clearing storage fails", () async {
      await service.ensureRegistered();
      bridgeIdStorage.clearError = const FileSystemException("clear failed");

      await service.handleBridgeRevoked();

      expect(service.bridgeId, isNull);

      bridgeIdStorage.clearError = null;
      await service.ensureRegistered();

      expect(repository.registeredBridgeIds, hasLength(2));
    });
  });

  group("BridgeRegistrationService.unregister", () {
    test("does nothing when no bridge id is persisted", () async {
      await service.unregister();

      expect(repository.unregisteredBridgeIds, isEmpty);
    });

    test("deletes the persisted bridge id on the auth server and clears storage", () async {
      bridgeIdStorage.bridgeId = "br_persisted1";

      await service.unregister();

      expect(repository.unregisteredBridgeIds, equals(["br_persisted1"]));
      expect(bridgeIdStorage.bridgeId, isNull);
    });

    test("treats a 404 (already revoked) as success and clears storage", () async {
      bridgeIdStorage.bridgeId = "br_persisted1";
      final failingRepository = _UnregisterFailingRepository(statusCode: 404);
      final failingService = BridgeRegistrationService(
        repository: failingRepository,
        tokenRefresher: tokenRefresher,
        bridgeIdStorage: bridgeIdStorage,
        hostName: "dev-laptop",
        platform: "macos",
      );

      await failingService.unregister();

      expect(bridgeIdStorage.bridgeId, isNull);
    });

    test("rethrows non-404 failures and keeps the persisted id", () async {
      bridgeIdStorage.bridgeId = "br_persisted1";
      final failingRepository = _UnregisterFailingRepository(statusCode: 500);
      final failingService = BridgeRegistrationService(
        repository: failingRepository,
        tokenRefresher: tokenRefresher,
        bridgeIdStorage: bridgeIdStorage,
        hostName: "dev-laptop",
        platform: "macos",
      );

      await expectLater(
        failingService.unregister(),
        throwsA(isA<BridgeRegistrationException>().having((e) => e.statusCode, "statusCode", 500)),
      );
      expect(bridgeIdStorage.bridgeId, equals("br_persisted1"));
    });
  });
}

class _RecordingTokenRefresher implements TokenRefresher {
  int forceRefreshCalls = 0;
  void Function()? onForceRefresh;

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      forceRefreshCalls += 1;
      onForceRefresh?.call();
      return "refreshed-token";
    }
    return "access-token";
  }
}

class _UnregisterFailingRepository implements BridgeRegistrationRepository {
  final int statusCode;

  _UnregisterFailingRepository({required this.statusCode});

  @override
  Future<BridgeSummary> register({
    required String name,
    required String platform,
    required String? bridgeId,
    required String accessToken,
  }) {
    throw UnimplementedError("not used by unregister tests");
  }

  @override
  Future<void> unregister({required String bridgeId, required String accessToken}) async {
    throw BridgeRegistrationException(statusCode: statusCode, body: "unregister failed");
  }
}
