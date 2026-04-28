import "package:sesori_bridge/src/auth/token.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("TokenData JSON", () {
    test("round-trip preserves all token fields", () {
      final original = TokenData(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        bridgeToken: "bridge-token",
        lastProvider: AuthProvider.github,
      );

      final restored = TokenData.fromJson(original.toJson());

      expect(restored.accessToken, equals(original.accessToken));
      expect(restored.refreshToken, equals(original.refreshToken));
      expect(restored.bridgeToken, equals(original.bridgeToken));
      expect(restored.lastProvider, equals(original.lastProvider));
    });

    test("toJson omits bridgeToken when it is null", () {
      final data = TokenData(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        lastProvider: AuthProvider.github,
      );

      final json = data.toJson();

      expect(json.containsKey("bridgeToken"), isFalse);
      expect(json["lastProvider"], equals("github"));
    });

    test("fromJson sets bridgeToken to null when missing", () {
      final restored = TokenData.fromJson(<String, dynamic>{
        "accessToken": "access-token",
        "refreshToken": "refresh-token",
        "lastProvider": "google",
      });

      expect(restored.accessToken, equals("access-token"));
      expect(restored.refreshToken, equals("refresh-token"));
      expect(restored.bridgeToken, isNull);
      expect(restored.lastProvider, equals(AuthProvider.google));
    });

    test("fromJson defaults lastProvider to github when missing", () {
      final restored = TokenData.fromJson(<String, dynamic>{
        "accessToken": "access-token",
        "refreshToken": "refresh-token",
      });

      expect(restored.lastProvider, equals(AuthProvider.github));
    });
  });
}
