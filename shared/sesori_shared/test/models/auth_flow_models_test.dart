import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("AuthInitRequest", () {
    test("round-trips through JSON", () {
      const original = AuthInitRequest(clientType: "mobile");

      final json = original.toJson();
      final restored = AuthInitRequest.fromJson(json);

      expect(restored, equals(original));
      expect(json, equals({"clientType": "mobile"}));
    });
  });

  group("AuthInitResponse", () {
    test("round-trips through JSON", () {
      const original = AuthInitResponse(
        authUrl: "https://example.com/auth",
        state: "state-123",
        userCode: "ABCD-EFGH",
        expiresIn: 600,
      );

      final json = original.toJson();
      final restored = AuthInitResponse.fromJson(json);

      expect(restored, equals(original));
      expect(
        json,
        equals({
          "authUrl": "https://example.com/auth",
          "state": "state-123",
          "userCode": "ABCD-EFGH",
          "expiresIn": 600,
        }),
      );
    });
  });

  group("AuthSessionStatusResponse", () {
    test("round-trips pending status", () {
      const original = AuthSessionStatusResponse.pending();

      final json = original.toJson();
      final restored = AuthSessionStatusResponse.fromJson(json);

      expect(restored, equals(original));
      expect(json, equals({"status": "pending"}));
    });

    test("round-trips denied status", () {
      const original = AuthSessionStatusResponse.denied();

      final json = original.toJson();
      final restored = AuthSessionStatusResponse.fromJson(json);

      expect(restored, equals(original));
      expect(json, equals({"status": "denied"}));
    });

    test("round-trips expired status", () {
      const original = AuthSessionStatusResponse.expired();

      final json = original.toJson();
      final restored = AuthSessionStatusResponse.fromJson(json);

      expect(restored, equals(original));
      expect(json, equals({"status": "expired"}));
    });

    test("round-trips error status", () {
      const original = AuthSessionStatusResponse.error(message: "timeout");

      final json = original.toJson();
      final restored = AuthSessionStatusResponse.fromJson(json);

      expect(restored, equals(original));
      expect(json, equals({"status": "error", "message": "timeout"}));
    });

    test("round-trips complete status with tokens and user", () {
      const original = AuthSessionStatusResponse.complete(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        user: AuthUser(
          id: "user-1",
          provider: "github",
          providerUserId: "12345",
          providerUsername: "octocat",
        ),
      );

      final json = original.toJson();
      final restored = AuthSessionStatusResponse.fromJson(json);

      expect(restored, equals(original));
      expect(
        json,
        equals({
          "status": "complete",
          "accessToken": "access-token",
          "refreshToken": "refresh-token",
          "user": {
            "id": "user-1",
            "provider": "github",
            "providerUserId": "12345",
            "providerUsername": "octocat",
          },
        }),
      );
    });
  });
}
