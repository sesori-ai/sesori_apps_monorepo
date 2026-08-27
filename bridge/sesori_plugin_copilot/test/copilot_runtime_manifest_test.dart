import "package:copilot_plugin/copilot_plugin.dart";
import "package:test/test.dart";

void main() {
  test("pins the validated ACP floor", () {
    expect(const CopilotRuntimeManifest().minPathVersion.raw, "1.0.78");
  });
}
