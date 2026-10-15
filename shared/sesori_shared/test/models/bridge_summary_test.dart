import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

Map<String, Object?> _summaryJson({required String platform, required String status}) => {
  "id": "br_abc12345",
  "name": "Studio",
  "hostname": "alex-macbook",
  "platform": platform,
  "status": status,
  "addedAt": "2026-06-01T12:00:00.000Z",
  "lastSeenAt": null,
};

void main() {
  group("BridgeSummary", () {
    test("round-trips through JSON", () {
      final original = BridgeSummary(
        id: "br_abc12345",
        name: "Studio",
        hostname: "alex-macbook",
        platform: BridgePlatform.macos,
        status: BridgeRegistrationStatus.active,
        addedAt: DateTime.utc(2026, 6, 1, 12),
        lastSeenAt: DateTime.utc(2026, 6, 10, 9, 30),
      );

      final json = original.toJson();
      final restored = BridgeSummary.fromJson(json);

      expect(json["name"], equals("Studio"));
      expect(json["hostname"], equals("alex-macbook"));
      expect(json["platform"], equals("macos"));
      expect(json["status"], equals("active"));
      expect(restored, equals(original));
    });

    test("parses the display name and the hostname", () {
      final restored = BridgeSummary.fromJson(_summaryJson(platform: "macos", status: "active"));

      expect(restored.name, equals("Studio"));
      expect(restored.hostname, equals("alex-macbook"));
    });

    test("throws when the hostname is absent", () {
      final json = _summaryJson(platform: "macos", status: "active")..remove("hostname");

      expect(() => BridgeSummary.fromJson(json), throwsA(isA<TypeError>()));
    });

    test("parses null lastSeenAt", () {
      final restored = BridgeSummary.fromJson(_summaryJson(platform: "linux", status: "inactive"));

      expect(restored.id, equals("br_abc12345"));
      expect(restored.lastSeenAt, isNull);
    });

    test("parses both registration statuses", () {
      expect(
        BridgeSummary.fromJson(_summaryJson(platform: "macos", status: "active")).status,
        BridgeRegistrationStatus.active,
      );
      expect(
        BridgeSummary.fromJson(_summaryJson(platform: "macos", status: "inactive")).status,
        BridgeRegistrationStatus.inactive,
      );
    });

    test("throws when the status is absent", () {
      final json = _summaryJson(platform: "macos", status: "active")..remove("status");

      expect(() => BridgeSummary.fromJson(json), throwsA(isA<ArgumentError>()));
    });

    test("parses every known platform", () {
      expect(BridgeSummary.fromJson(_summaryJson(platform: "macos", status: "active")).platform, BridgePlatform.macos);
      expect(
        BridgeSummary.fromJson(_summaryJson(platform: "windows", status: "active")).platform,
        BridgePlatform.windows,
      );
      expect(BridgeSummary.fromJson(_summaryJson(platform: "linux", status: "active")).platform, BridgePlatform.linux);
    });

    test("parses an unrecognised platform as unknown", () {
      final restored = BridgeSummary.fromJson(_summaryJson(platform: "freebsd", status: "active"));

      expect(restored.platform, BridgePlatform.unknown);
    });
  });

  group("BridgesListResponse", () {
    test("parses the bridges list", () {
      final response = BridgesListResponse.fromJson({
        "bridges": [
          {
            "id": "br_abc12345",
            "name": "alex-macbook",
            "hostname": "alex-macbook",
            "platform": "macos",
            "status": "active",
            "addedAt": "2026-06-01T12:00:00.000Z",
            "lastSeenAt": null,
          },
        ],
      });

      expect(response.bridges, hasLength(1));
      expect(response.bridges.single.id, equals("br_abc12345"));
    });

    test("parses an empty bridges list", () {
      final response = BridgesListResponse.fromJson({"bridges": <Object>[]});

      expect(response.bridges, isEmpty);
    });

    test("throws when the key is absent", () {
      // The endpoint always returns a bridges array, so a missing key means a
      // broken or incompatible server — fail fast instead of silently
      // treating it as "no bridges".
      expect(
        () => BridgesListResponse.fromJson(const {}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group("AuthMeResponse", () {
    test("parses without a bridges key", () {
      // Registered bridges moved to the dedicated `GET /auth/bridges`
      // endpoint, so `/auth/me` no longer carries them.
      final response = AuthMeResponse.fromJson({
        "user": {
          "id": "user-1",
          "provider": "github",
          "providerUserId": "12345",
          "providerUsername": "octocat",
        },
      });

      expect(response.user.id, equals("user-1"));
    });

    test("ignores a legacy bridges key", () {
      // Servers mid-rollout may still include the removed field; unknown
      // keys are ignored.
      final response = AuthMeResponse.fromJson({
        "user": {
          "id": "user-1",
          "provider": "github",
          "providerUserId": "12345",
          "providerUsername": "octocat",
        },
        "bridges": [
          {
            "id": "br_abc12345",
            "name": "alex-macbook",
            "hostname": "alex-macbook",
            "platform": "macos",
            "status": "active",
            "addedAt": "2026-06-01T12:00:00.000Z",
            "lastSeenAt": null,
          },
        ],
      });

      expect(response.user.providerUsername, equals("octocat"));
    });
  });
}
