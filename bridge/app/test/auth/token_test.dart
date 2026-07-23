import "dart:io";

import "package:path/path.dart" as path;
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

  group("token persistence", () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp("sesori-token-test-");
    });

    tearDown(() {
      if (temporaryDirectory.existsSync()) {
        temporaryDirectory.deleteSync(recursive: true);
      }
    });

    test("keeps credentials and bridge identity paths inside the supplied root", () {
      expect(
        tokenPath(dataDirectory: temporaryDirectory.path),
        path.join(temporaryDirectory.path, "token.json"),
      );
      expect(
        bridgeIdPath(dataDirectory: temporaryDirectory.path),
        path.join(temporaryDirectory.path, "bridge_id"),
      );
    });

    test("reads, writes, and clears only the supplied root", () async {
      final firstRoot = path.join(temporaryDirectory.path, "first");
      final secondRoot = path.join(temporaryDirectory.path, "second");
      final data = TokenData(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        lastProvider: AuthProvider.github,
      );

      await saveTokens(data: data, dataDirectory: firstRoot);

      expect(File(tokenPath(dataDirectory: firstRoot)).existsSync(), isTrue);
      expect(File(tokenPath(dataDirectory: secondRoot)).existsSync(), isFalse);
      final restored = await loadTokens(dataDirectory: firstRoot);
      expect(restored.accessToken, data.accessToken);
      expect(restored.refreshToken, data.refreshToken);
      expect(restored.lastProvider, data.lastProvider);

      await clearTokens(dataDirectory: firstRoot);

      expect(File(tokenPath(dataDirectory: firstRoot)).existsSync(), isFalse);
    });
  });
}
