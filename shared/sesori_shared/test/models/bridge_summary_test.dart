import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BridgeSummary", () {
    test("round-trips through JSON", () {
      final original = BridgeSummary(
        id: "br_abc12345",
        name: "alex-macbook",
        platform: "macos",
        addedAt: DateTime.utc(2026, 6, 1, 12),
        lastSeenAt: DateTime.utc(2026, 6, 10, 9, 30),
      );

      final json = original.toJson();
      final restored = BridgeSummary.fromJson(json);

      expect(restored, equals(original));
    });

    test("parses null lastSeenAt", () {
      final restored = BridgeSummary.fromJson({
        "id": "br_abc12345",
        "name": "alex-macbook",
        "platform": "linux",
        "addedAt": "2026-06-01T12:00:00.000Z",
        "lastSeenAt": null,
      });

      expect(restored.id, equals("br_abc12345"));
      expect(restored.platform, equals("linux"));
      expect(restored.lastSeenAt, isNull);
    });
  });

  group("AuthMeResponse bridges", () {
    test("defaults to an empty list when the key is absent", () {
      final response = AuthMeResponse.fromJson({
        "user": {
          "id": "user-1",
          "provider": "github",
          "providerUserId": "12345",
          "providerUsername": "octocat",
        },
      });

      expect(response.bridges, isEmpty);
    });

    test("parses the bridges list when present", () {
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
            "platform": "macos",
            "addedAt": "2026-06-01T12:00:00.000Z",
            "lastSeenAt": null,
          },
        ],
      });

      expect(response.bridges, hasLength(1));
      expect(response.bridges.single.id, equals("br_abc12345"));
    });
  });
}
