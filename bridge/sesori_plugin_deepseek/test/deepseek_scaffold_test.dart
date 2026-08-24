import "package:acp_plugin/acp_plugin.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("identity and launch contract are exact", () {
    final spec = DeepSeekBinary.launchSpec(
      binary: "/runtime/deepseek",
      cwd: "/project",
      stateDirectory: "/state",
      environment: const {"TOKEN": "secret", "DSH_TELEMETRY_MODE": "enabled"},
    );
    expect([DeepSeekIdentity.id, DeepSeekIdentity.displayName], ["deepseek", "DeepSeek"]);
    expect(
      [spec.command, spec.args, spec.cwd, spec.environment],
      [
        "/runtime/deepseek",
        ["serve", "--state-dir", "/state"],
        "/project",
        {"TOKEN": "secret", "DSH_TELEMETRY_MODE": "off"},
      ],
    );
  });
  test("event mapper handles only Step 8 completed compaction status", () {
    final mapper = DeepSeekEventMapper(
      launchDirectory: "/project",
      pluginId: DeepSeekIdentity.id,
      configurationTracker: AcpSessionConfigurationTracker(),
      api: const DeepSeekAcpApi(),
    );
    List<BridgeSseEvent> map(String kind) => mapper.map(
      AcpNotification(
        method: DeepSeekAcpApi.sessionStatusMethod,
        params: {"sessionId": "session-1", "kind": kind},
      ),
    );
    expect(map("compaction_completed"), [isA<BridgeSseSessionCompacted>()]);
    for (final kind in ["retry", "future_status"]) {
      expect(map(kind), isEmpty);
    }
  });
}
