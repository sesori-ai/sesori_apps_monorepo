import "dart:convert";

import "package:sesori_bridge/src/services/device_canvas_turn_credential_builder.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("DeviceCanvasTurnCredentialBuilder", () {
    test("builds the coturn REST username and independently calculated HMAC-SHA1 credential", () {
      final urls = <String>["TURN:TURN.EXAMPLE.TEST.:03478?TRANSPORT=UDP"];
      final sharedSecret = utf8.encode("0123456789abcdef0123456789abcdef");
      final builder = DeviceCanvasTurnCredentialBuilder(urls: urls, sharedSecret: sharedSecret);

      urls[0] = "turn:changed.example.test";
      sharedSecret.fillRange(0, sharedSecret.length, 0);
      final configuration = builder.build(
        operationId: "operation_1",
        leaseExpiresAt: 1700000600000,
        now: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );

      expect(configuration.urls, const ["turn:turn.example.test:3478?transport=udp"]);
      expect(configuration.username, "1700000300:operation_1");
      // Calculated independently with Python's stdlib hmac/hashlib implementation.
      expect(configuration.credential, "1n9URpCBuTaRLLwSyPk0sriLGJ8=");
      expect(configuration.expiresAt, 1700000300000);
      expect(configuration.isValid, isTrue);
    });

    test("uses the earlier of credential lifetime and lease expiry at whole-second precision", () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000123, isUtc: true);
      final builder = DeviceCanvasTurnCredentialBuilder(
        urls: const ["turn:relay.example.test"],
        sharedSecret: _validSecret(),
      );

      final lifetimeLimited = builder.build(
        operationId: "lifetime",
        leaseExpiresAt: 1700000600999,
        now: now,
      );
      final leaseLimited = builder.build(
        operationId: "lease",
        leaseExpiresAt: 1700000123456,
        now: now,
      );

      expect(lifetimeLimited.username, "1700000300:lifetime");
      expect(lifetimeLimited.expiresAt, 1700000300000);
      expect(leaseLimited.username, "1700000123:lease");
      expect(leaseLimited.expiresAt, 1700000123000);
    });

    test("rejects empty, invalid, excessive, and canonically duplicate URL lists", () {
      final invalidLists = <List<String>>[
        <String>[],
        <String>["https:relay.example.test"],
        <String>["turn:relay.example.test", "TURN:RELAY.EXAMPLE.TEST.:03478?TRANSPORT=UDP"],
        List<String>.generate(maxDeviceCanvasTurnUrls + 1, (index) => "turn:relay-$index.example.test"),
      ];

      for (final urls in invalidLists) {
        expect(
          () => DeviceCanvasTurnCredentialBuilder(urls: urls, sharedSecret: _validSecret()),
          throwsArgumentError,
          reason: urls.length.toString(),
        );
      }
    });

    test("rejects a short or non-byte secret and a nonpositive lifetime", () {
      expect(
        () => DeviceCanvasTurnCredentialBuilder(urls: const ["turn:relay.example.test"], sharedSecret: const []),
        throwsArgumentError,
      );
      expect(
        () => DeviceCanvasTurnCredentialBuilder(
          urls: const ["turn:relay.example.test"],
          sharedSecret: List<int>.filled(DeviceCanvasTurnCredentialBuilder.minimumSharedSecretBytes - 1, 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => DeviceCanvasTurnCredentialBuilder(
          urls: const ["turn:relay.example.test"],
          sharedSecret: <int>[..._validSecret().take(31), 256],
        ),
        throwsArgumentError,
      );
      expect(
        () => DeviceCanvasTurnCredentialBuilder(
          urls: const ["turn:relay.example.test"],
          sharedSecret: _validSecret(),
          credentialLifetime: Duration.zero,
        ),
        throwsArgumentError,
      );
    });

    test("rejects leases that are not future at whole-second precision", () {
      final builder = DeviceCanvasTurnCredentialBuilder(
        urls: const ["turn:relay.example.test"],
        sharedSecret: _validSecret(),
      );
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000900, isUtc: true);

      expect(
        () => builder.build(operationId: "operation", leaseExpiresAt: 1700000000999, now: now),
        throwsStateError,
      );
      expect(
        () => builder.build(operationId: "operation", leaseExpiresAt: 1699999999999, now: now),
        throwsStateError,
      );
    });

    test("rejects empty, unbounded, and non-opaque operation IDs", () {
      final builder = DeviceCanvasTurnCredentialBuilder(
        urls: const ["turn:relay.example.test"],
        sharedSecret: _validSecret(),
      );
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);

      for (final operationId in <String>[
        "",
        "not opaque",
        "non-ascii-é",
        "x" * (maxDeviceCanvasStreamOperationIdLength + 1),
      ]) {
        expect(
          () => builder.build(operationId: operationId, leaseExpiresAt: 1700000600000, now: now),
          throwsArgumentError,
        );
      }
    });

    test("diagnostics do not reveal the shared secret, credential, or rejected operation", () {
      const secretText = "diagnostic-secret-value-1234567890";
      const rejectedOperation = "private operation value";
      final builder = DeviceCanvasTurnCredentialBuilder(
        urls: const ["turn:relay.example.test"],
        sharedSecret: utf8.encode(secretText),
      );
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final configuration = builder.build(
        operationId: "operation",
        leaseExpiresAt: 1700000600000,
        now: now,
      );

      Object? error;
      try {
        builder.build(operationId: rejectedOperation, leaseExpiresAt: 1700000600000, now: now);
      } on Object catch (caught) {
        error = caught;
      }
      expect(error, isNotNull);

      for (final diagnostic in <String>[builder.toString(), error.toString()]) {
        expect(diagnostic, isNot(contains(secretText)));
        expect(diagnostic, isNot(contains(configuration.credential)));
        expect(diagnostic, isNot(contains(rejectedOperation)));
      }
    });
  });
}

List<int> _validSecret() => List<int>.filled(DeviceCanvasTurnCredentialBuilder.minimumSharedSecretBytes, 1);
