import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/auth/auth_api.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/services/device_canvas_remote_turn_credential_issuer.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  final now = DateTime.utc(2026, 8, 27, 12);
  final expiresAt = now.add(const Duration(minutes: 5)).millisecondsSinceEpoch;
  final leaseExpiresAt = now.add(const Duration(minutes: 10)).millisecondsSinceEpoch;

  DeviceCanvasTurnConfiguration validConfiguration() => DeviceCanvasTurnConfiguration(
    urls: const [
      "turn:turn.example.test:3478?transport=udp",
      "turns:turn.example.test:5349?transport=tcp",
    ],
    username: "${expiresAt ~/ Duration.millisecondsPerSecond}:operation_1",
    credential: base64Encode(List<int>.filled(20, 7)),
    expiresAt: expiresAt,
  );

  test("uses the registered bridge and current access token", () async {
    final requests = <_CredentialRequest>[];
    final tokens = _TokenRefresher("access-1");
    final issuer = DeviceCanvasRemoteTurnCredentialIssuer(
      requestCredentials:
          ({required bridgeId, required operationId, required leaseExpiresAt, required accessToken}) async {
            requests.add(
              _CredentialRequest(
                bridgeId: bridgeId,
                operationId: operationId,
                leaseExpiresAt: leaseExpiresAt,
                accessToken: accessToken,
              ),
            );
            return validConfiguration();
          },
      tokenRefresher: tokens,
      bridgeIdProvider: _BridgeIdProvider("br_server001"),
    );

    expect(
      await issuer.issue(operationId: "operation_1", leaseExpiresAt: leaseExpiresAt, now: now),
      validConfiguration(),
    );
    expect(requests, hasLength(1));
    expect(requests.single.bridgeId, "br_server001");
    expect(requests.single.operationId, "operation_1");
    expect(requests.single.leaseExpiresAt, leaseExpiresAt);
    expect(requests.single.accessToken, "access-1");
    expect(tokens.forceRefreshValues, [false]);
  });

  test("force-refreshes exactly once after a 401", () async {
    final requests = <String>[];
    final tokens = _TokenRefresher("access-1", refreshedToken: "access-2");
    var attempts = 0;
    final issuer = DeviceCanvasRemoteTurnCredentialIssuer(
      requestCredentials:
          ({required bridgeId, required operationId, required leaseExpiresAt, required accessToken}) async {
            requests.add(accessToken);
            attempts += 1;
            if (attempts == 1) {
              throw const DeviceCanvasTurnApiException(statusCode: 401, reason: "request rejected");
            }
            return validConfiguration();
          },
      tokenRefresher: tokens,
      bridgeIdProvider: _BridgeIdProvider("br_server001"),
    );

    await issuer.issue(operationId: "operation_1", leaseExpiresAt: leaseExpiresAt, now: now);

    expect(requests, ["access-1", "access-2"]);
    expect(tokens.forceRefreshValues, [false, true]);
  });

  test("does not retry a second 401 or a non-auth rejection", () async {
    for (final statusCode in [401, 503]) {
      final tokens = _TokenRefresher("access-1", refreshedToken: "access-2");
      var attempts = 0;
      final issuer = DeviceCanvasRemoteTurnCredentialIssuer(
        requestCredentials:
            ({required bridgeId, required operationId, required leaseExpiresAt, required accessToken}) async {
              attempts += 1;
              throw DeviceCanvasTurnApiException(statusCode: statusCode, reason: "request rejected");
            },
        tokenRefresher: tokens,
        bridgeIdProvider: _BridgeIdProvider("br_server001"),
      );

      await expectLater(
        issuer.issue(operationId: "operation_1", leaseExpiresAt: leaseExpiresAt, now: now),
        throwsA(isA<DeviceCanvasTurnApiException>()),
      );
      expect(attempts, statusCode == 401 ? 2 : 1);
      expect(tokens.forceRefreshValues, statusCode == 401 ? [false, true] : [false]);
    }
  });

  test("fails before token or transport access when the bridge is unregistered", () async {
    final tokens = _TokenRefresher("access-1");
    var requested = false;
    final issuer = DeviceCanvasRemoteTurnCredentialIssuer(
      requestCredentials:
          ({required bridgeId, required operationId, required leaseExpiresAt, required accessToken}) async {
            requested = true;
            return validConfiguration();
          },
      tokenRefresher: tokens,
      bridgeIdProvider: _BridgeIdProvider(null),
    );

    await expectLater(
      issuer.issue(operationId: "operation_1", leaseExpiresAt: leaseExpiresAt, now: now),
      throwsA(isA<DeviceCanvasTurnCredentialIssuanceException>()),
    );
    expect(tokens.forceRefreshValues, isEmpty);
    expect(requested, isFalse);
  });

  test("rejects malformed, unscoped, non-production, and lease-escaping responses", () async {
    final invalidConfigurations = [
      validConfiguration().copyWith(username: "wrong-operation"),
      validConfiguration().copyWith(credential: "not-base64"),
      validConfiguration().copyWith(urls: const ["turn:192.0.2.1:3478?transport=udp"]),
      validConfiguration().copyWith(urls: const ["turn:0x7f.0.0.1:3478?transport=udp"]),
      validConfiguration().copyWith(urls: const ["turn:127.0.0.0x1:3478?transport=udp"]),
      validConfiguration().copyWith(urls: const ["turn:0x.0.0.1:3478?transport=udp"]),
      validConfiguration().copyWith(urls: const ["turn:0x.0x.0x.0x1:3478?transport=udp"]),
      validConfiguration().copyWith(urls: const ["turns:turn.example.test:5349?transport=udp"]),
      validConfiguration().copyWith(expiresAt: leaseExpiresAt + 1000),
      validConfiguration().copyWith(expiresAt: now.millisecondsSinceEpoch),
    ];

    for (final configuration in invalidConfigurations) {
      final issuer = DeviceCanvasRemoteTurnCredentialIssuer(
        requestCredentials: ({
          required bridgeId,
          required operationId,
          required leaseExpiresAt,
          required accessToken,
        }) async => configuration,
        tokenRefresher: _TokenRefresher("access-1"),
        bridgeIdProvider: _BridgeIdProvider("br_server001"),
      );

      await expectLater(
        issuer.issue(operationId: "operation_1", leaseExpiresAt: leaseExpiresAt, now: now),
        throwsA(isA<DeviceCanvasTurnCredentialIssuanceException>()),
      );
    }
  });

  test("discards a late response when bridge registration changes", () async {
    final bridgeIdProvider = _BridgeIdProvider("br_server001");
    final response = Completer<DeviceCanvasTurnConfiguration>();
    final issuer = DeviceCanvasRemoteTurnCredentialIssuer(
      requestCredentials: ({required bridgeId, required operationId, required leaseExpiresAt, required accessToken}) =>
          response.future,
      tokenRefresher: _TokenRefresher("access-1"),
      bridgeIdProvider: bridgeIdProvider,
    );

    final pending = issuer.issue(operationId: "operation_1", leaseExpiresAt: leaseExpiresAt, now: now);
    await Future<void>.delayed(Duration.zero);
    bridgeIdProvider.bridgeId = null;
    response.complete(validConfiguration());

    await expectLater(pending, throwsA(isA<DeviceCanvasTurnCredentialIssuanceException>()));
  });
}

class _TokenRefresher(final String token, {final String? refreshedToken}) implements TokenRefresher {
  final List<bool> forceRefreshValues = [];

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    forceRefreshValues.add(forceRefresh);
    return forceRefresh ? refreshedToken ?? token : token;
  }
}

class _BridgeIdProvider(@override var String? bridgeId) implements BridgeIdProvider;

class const _CredentialRequest({
  required final String bridgeId,
  required final String operationId,
  required final int leaseExpiresAt,
  required final String accessToken,
});
