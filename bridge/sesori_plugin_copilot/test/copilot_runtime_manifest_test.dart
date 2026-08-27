import "package:copilot_plugin/copilot_plugin.dart";
import "package:test/test.dart";

void main() {
  group("CopilotRuntimeManifest", () {
    const manifest = CopilotRuntimeManifest();

    test("pins the validated ACP floor and target", () {
      expect(manifest.runtimeId, "copilot");
      expect(manifest.minPathVersion.raw, "1.0.78");
    });

    test("parses bare and sentence-final Copilot version tokens", () {
      expect(manifest.parseVersion(value: "1.0.80")?.raw, "1.0.80");
      expect(manifest.parseVersion(value: "1.0.80.")?.raw, "1.0.80");
      expect(manifest.parseVersion(value: "GitHub"), isNull);
    });
  });
}
