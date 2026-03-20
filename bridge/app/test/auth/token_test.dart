import "package:sesori_bridge/src/auth/token.dart";
import "package:test/test.dart";

void main() {
  group("TokenData JSON", () {
    test("round-trip preserves all token fields", () {
      final original = TokenData(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        bridgeToken: "bridge-token",
      );

      final restored = TokenData.fromJson(original.toJson());

      expect(restored.accessToken, equals(original.accessToken));
      expect(restored.refreshToken, equals(original.refreshToken));
      expect(restored.bridgeToken, equals(original.bridgeToken));
    });

    test("toJson omits bridgeToken when it is null", () {
      final data = TokenData(
        accessToken: "access-token",
        refreshToken: "refresh-token",
      );

      final json = data.toJson();

      expect(json.containsKey("bridgeToken"), isFalse);
    });

    test("fromJson sets bridgeToken to null when missing", () {
      final restored = TokenData.fromJson(<String, dynamic>{
        "accessToken": "access-token",
        "refreshToken": "refresh-token",
      });

      expect(restored.accessToken, equals("access-token"));
      expect(restored.refreshToken, equals("refresh-token"));
      expect(restored.bridgeToken, isNull);
    });
  });
}
