import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:test/test.dart";

void main() {
  test("vendored protocol files match the source manifest", () async {
    final directory = Directory("test/fixtures/protocol/v1");
    final manifest = jsonDecode(
      await File("${directory.path}/source_manifest.json").readAsString(),
    ) as Map<String, dynamic>;

    expect(manifest["repository"], "sesori-ai/sesori-deepseek-acp");
    expect(manifest["commit"], "3d4c5d0e016390f0077fc01fcfa0aba0025ca2b6");
    final expected = (manifest["files"] as Map).cast<String, String>();
    for (final entry in expected.entries) {
      final bytes = await File("${directory.path}/${entry.key}").readAsBytes();
      expect(sha256.convert(bytes).toString(), entry.value, reason: entry.key);
    }
  });
}
