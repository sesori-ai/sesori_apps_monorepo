import "package:grok_plugin/grok_plugin.dart";
import "package:test/test.dart";

void main() {
  test("declares stable Grok identity", () {
    expect(GrokPluginIdentity.id, "grok");
    expect(GrokPluginIdentity.displayName, "Grok Build");
    expect(GrokBinary.defaultBinary, "grok");
  });

  test("launches a dedicated non-updating ACP process in ask mode", () {
    const environment = {"GROK_HOME": "/isolated/grok"};
    final spec = GrokBinary.launchSpec(
      binary: "/custom/grok",
      cwd: "/workspace/project",
      environment: environment,
    );

    expect(spec.command, "/custom/grok");
    expect(spec.args, ["--no-auto-update", "agent", "--no-leader", "stdio"]);
    expect(spec.args, isNot(contains("--always-approve")));
    expect(spec.args, isNot(contains("--yolo")));
    expect(spec.cwd, "/workspace/project");
    expect(spec.environment, environment);
  });
}
