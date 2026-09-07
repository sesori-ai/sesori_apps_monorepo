import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:test/test.dart";

void main() {
  const commits = {
    1: "9731711f079dc0d7acf7e5eff29c81a3622bc4a0",
    2: "d7a48471bf5339793beb0c9e1c1889e63f76ec92",
  };
  for (final entry in commits.entries) {
    test("vendored protocol v${entry.key} files match the source manifest", () async {
      final directory = Directory("test/fixtures/protocol/v${entry.key}");
      final manifest = jsonDecode(
        await File("${directory.path}/source_manifest.json").readAsString(),
      ) as Map<String, dynamic>;

      expect(manifest["repository"], "sesori-ai/sesori-deepseek-acp");
      expect(manifest["commit"], entry.value);
      final expected = (manifest["files"] as Map).cast<String, String>();
      expect(expected.keys.toSet(), {
        "deepseek-acp.schema.json",
        "valid.json",
        "invalid.json",
      });
      for (final file in expected.entries) {
        final bytes = await File("${directory.path}/${file.key}").readAsBytes();
        expect(sha256.convert(bytes).toString(), file.value, reason: file.key);
      }
    });
  }
}
