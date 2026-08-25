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
    expect(manifest["commit"], "e23a5c7e435c61af9ee7b8c5cdd61ee39fd60c6d");
    final expected = (manifest["files"] as Map).cast<String, String>();
    expect(expected.keys.toSet(), {
      "deepseek-acp.schema.json",
      "valid.json",
      "invalid.json",
    });
    for (final entry in expected.entries) {
      final bytes = await File("${directory.path}/${entry.key}").readAsBytes();
      expect(sha256.convert(bytes).toString(), entry.value, reason: entry.key);
    }
  });
}
