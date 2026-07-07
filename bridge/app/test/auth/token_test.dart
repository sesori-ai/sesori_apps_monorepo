import "package:sesori_bridge/src/auth/token.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("TokenData JSON", () {
    test("round-trip preserves all token fields", () {
      final original = TokenData(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        lastProvider: AuthProvider.github,
      );

      final restored = TokenData.fromJson(original.toJson());

      expect(restored.accessToken, equals(original.accessToken));
      expect(restored.refreshToken, equals(original.refreshToken));
      expect(restored.lastProvider, equals(original.lastProvider));
    });

    test("toJson serializes the provider key", () {
      final data = TokenData(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        lastProvider: AuthProvider.github,
      );

      final json = data.toJson();

      expect(json["lastProvider"], equals("github"));
    });

    test("fromJson ignores a legacy bridgeId key from old token files", () {
      final restored = TokenData.fromJson(<String, dynamic>{
        "accessToken": "access-token",
        "refreshToken": "refresh-token",
        "bridgeId": "br_abc12345",
        "lastProvider": "github",
      });

      expect(restored.accessToken, equals("access-token"));
      expect(restored.refreshToken, equals("refresh-token"));
      expect(restored.lastProvider, equals(AuthProvider.github));
      expect(restored.toJson().containsKey("bridgeId"), isFalse);
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
