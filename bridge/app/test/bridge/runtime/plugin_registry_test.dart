import "package:antigravity_plugin/antigravity_plugin.dart" show AntigravityIdentity, AntigravityRelease;
import "package:sesori_bridge/src/runtime/plugin_registry.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformTarget;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginConfig, PluginControlCapability;
import "package:sesori_shared/sesori_shared.dart" show Harness;
import "package:test/test.dart";

void main() {
  test("registry contains every bundled plugin exactly once", () {
    final ids = knownPlugins.map((plugin) => plugin.id).toList();

    expect(
      ids,
      unorderedEquals([
        "opencode",
        AntigravityIdentity.pluginId,
        "codex",
        "copilot",
        "cursor",
        "claude",
        "hermes",
        "pi",
        "omp",
        "deepseek",
        "grok",
      ]),
    );
  });

  test("OpenCode remains the preferred default", () {
    expect(preferredDefaultPluginId, Harness.opencode.name);
  });

  test("Antigravity remains a plugin-owned opaque identity", () {
    final descriptor = knownPlugins.singleWhere((plugin) => plugin.id == AntigravityIdentity.pluginId);

    expect(Harness.values.map((harness) => harness.name), isNot(contains(descriptor.id)));
    expect(descriptor.displayName, AntigravityIdentity.displayName);
    expect(descriptor.options.map((option) => option.name), contains("bin"));
    expect(descriptor.managementCapabilities(config: const PluginConfig(values: {"bin": null})), {
      PluginControlCapability.lifecycle,
      PluginControlCapability.setupRefresh,
      PluginControlCapability.idleTimeout,
      PluginControlCapability.authentication,
      if (AntigravityRelease.supportsTarget(target: PlatformTarget.current())) PluginControlCapability.install,
    });
  });

  test("registered descriptors remain inert declarations", () {
    for (final plugin in knownPlugins) {
      expect(plugin.id, isNotEmpty);
      expect(plugin.displayName, isNotEmpty);
      expect(plugin.options.map((option) => option.name).toSet(), hasLength(plugin.options.length));
    }
  });
}
