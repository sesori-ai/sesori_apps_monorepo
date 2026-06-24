import "dart:io";

import "package:crypto/crypto.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  group("ChecksumValidator", () {
    late ChecksumValidator validator;

    setUp(() {
      validator = ChecksumValidator();
    });

    test("verify returns true for matching checksum", () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File("${tempDir.path}/test-binary.tar.gz");
      await testFile.writeAsString("test content");

      try {
        final actualHash = await validator.computeSha256(filePath: testFile.path);

        final result = await validator.verify(
          filePath: testFile.path,
          expectedHash: actualHash,
        );

        expect(result, isTrue);
      } finally {
        testFile.deleteSync();
        tempDir.deleteSync();
      }
    });

    test("verify returns false for tampered file", () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File("${tempDir.path}/test-binary.tar.gz");
      await testFile.writeAsString("test content");

      try {
        const wrongHash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

        final result = await validator.verify(
          filePath: testFile.path,
          expectedHash: wrongHash,
        );

        expect(result, isFalse);
      } finally {
        testFile.deleteSync();
        tempDir.deleteSync();
      }
    });

    test("verify returns false when file does not exist", () async {
      final result = await validator.verify(
        filePath: "/nonexistent/path/nonexistent.tar.gz",
        expectedHash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      );

      expect(result, isFalse);
    });

    test("verify handles case-insensitive hex comparison", () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File("${tempDir.path}/test-binary.tar.gz");
      await testFile.writeAsString("test content");

      try {
        final actualHash = await validator.computeSha256(filePath: testFile.path);
        final uppercaseHash = actualHash.toUpperCase();

        final result = await validator.verify(
          filePath: testFile.path,
          expectedHash: uppercaseHash,
        );

        expect(result, isTrue);
      } finally {
        testFile.deleteSync();
        tempDir.deleteSync();
      }
    });

    test("computeSha256 returns lowercase hex string", () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final testFile = File("${tempDir.path}/test-binary.tar.gz");
      await testFile.writeAsString("test content");

      try {
        final hash = await validator.computeSha256(filePath: testFile.path);

        expect(hash, matches(RegExp(r"^[a-f0-9]{64}$")));

        final expectedHash = sha256.convert("test content".codeUnits).toString();
        expect(hash, equals(expectedHash));
      } finally {
        testFile.deleteSync();
        tempDir.deleteSync();
      }
    });
  });
}
