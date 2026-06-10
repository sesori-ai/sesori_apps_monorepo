import "package:sesori_bridge/src/auth/token.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("TokenData JSON", () {
    test("round-trip preserves all token fields", () {
      final original = TokenData(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        bridgeId: "br_abc12345",
        lastProvider: AuthProvider.github,
      );

      final restored = TokenData.fromJson(original.toJson());

      expect(restored.accessToken, equals(original.accessToken));
      expect(restored.refreshToken, equals(original.refreshToken));
      expect(restored.bridgeId, equals(original.bridgeId));
      expect(restored.lastProvider, equals(original.lastProvider));
    });

    test("toJson omits bridgeId when it is null", () {
      final data = TokenData(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        lastProvider: AuthProvider.github,
      );

      final json = data.toJson();

      expect(json.containsKey("bridgeId"), isFalse);
      expect(json["lastProvider"], equals("github"));
    });

    test("fromJson sets bridgeId to null when missing", () {
      final restored = TokenData.fromJson(<String, dynamic>{
        "accessToken": "access-token",
        "refreshToken": "refresh-token",
        "lastProvider": "google",
      });

      expect(restored.accessToken, equals("access-token"));
      expect(restored.refreshToken, equals("refresh-token"));
      expect(restored.bridgeId, isNull);
      expect(restored.lastProvider, equals(AuthProvider.google));
    });

    test("fromJson ignores the legacy bridgeToken key from old token files", () {
      final restored = TokenData.fromJson(<String, dynamic>{
        "accessToken": "access-token",
        "refreshToken": "refresh-token",
        "bridgeToken": "legacy-bridge-token",
        "lastProvider": "github",
      });

      expect(restored.accessToken, equals("access-token"));
      expect(restored.refreshToken, equals("refresh-token"));
      expect(restored.bridgeId, isNull);
      expect(restored.lastProvider, equals(AuthProvider.github));
      expect(restored.toJson().containsKey("bridgeToken"), isFalse);
    });

    test("fromJson throws when lastProvider is missing", () {
      expect(
        () => TokenData.fromJson(<String, dynamic>{
          "accessToken": "access-token",
          "refreshToken": "refresh-token",
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test("fromJson throws when lastProvider is invalid", () {
      expect(
        () => TokenData.fromJson(<String, dynamic>{
          "accessToken": "access-token",
          "refreshToken": "refresh-token",
          "lastProvider": "invalid_provider",
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
