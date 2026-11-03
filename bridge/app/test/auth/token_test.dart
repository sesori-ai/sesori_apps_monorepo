import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_bridge/src/auth/token.dart";
import "package:sesori_bridge/src/foundation/data_directory_hardening.dart";
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

    test("toJson writes the persisted token file shape", () {
      final data = TokenData(
        accessToken: "access-token",
        refreshToken: "refresh-token",
        lastProvider: AuthProvider.github,
      );

      final json = data.toJson();

      expect(json, {
        "accessToken": "access-token",
        "refreshToken": "refresh-token",
        "lastProvider": "github",
      });
    });

    test("fromJson throws when lastProvider is missing", () {
      // Released bridges wrote token files without lastProvider.
      expect(
        () => TokenData.fromJson(<String, dynamic>{
          "accessToken": "access-token",
          "refreshToken": "refresh-token",
          "bridgeToken": "bridge-token",
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test("fromJson throws when a token is missing", () {
      expect(
        () => TokenData.fromJson(<String, dynamic>{
          "refreshToken": "refresh-token",
          "lastProvider": "github",
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test("fromJson ignores fields that released bridges no longer write", () {
      final restored = TokenData.fromJson(<String, dynamic>{
        "accessToken": "access-token",
        "refreshToken": "refresh-token",
        "lastProvider": "github",
        "bridgeId": "bridge-id",
      });

      expect(restored.accessToken, "access-token");
      expect(restored.lastProvider, AuthProvider.github);
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

      await saveTokens(
        data: data,
        dataDirectory: firstRoot,
        writeRestrictedFile: writeRestrictedFile,
      );

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
