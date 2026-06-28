import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("AuthInitRequest", () {
    test("round-trips through JSON with a full device", () {
      const original = AuthInitRequest(
        clientType: "app_ios",
        device: DeviceInfo(name: "Alex's iPhone", osVersion: "iOS 17.5", appVersion: "1.2.0"),
      );

      final json = original.toJson();
      final restored = AuthInitRequest.fromJson(json);

      expect(restored, equals(original));
      expect(
        json,
        equals({
          "clientType": "app_ios",
          "device": {"name": "Alex's iPhone", "osVersion": "iOS 17.5", "appVersion": "1.2.0"},
        }),
      );
    });

    test("omits null device version fields from the wire payload", () {
      const original = AuthInitRequest(
        clientType: "bridge_macos",
        device: DeviceInfo(name: "Alex's MacBook Pro", osVersion: null, appVersion: null),
      );

      final json = original.toJson();

      expect(
        json,
        equals({
          "clientType": "bridge_macos",
          "device": {"name": "Alex's MacBook Pro"},
        }),
      );
      expect(AuthInitRequest.fromJson(json), equals(original));
    });
  });

  group("AuthInitResponse", () {
    test("round-trips through JSON", () {
      const original = AuthInitResponse(
        authUrl: "https://example.com/auth",
        state: "state-123",
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
          provider: AuthProvider.github,
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
