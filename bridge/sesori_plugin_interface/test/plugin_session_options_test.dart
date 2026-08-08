import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const options = PluginSessionOptions(
    agents: [],
    providers: PluginProvidersResult(providers: []),
    commands: [],
    completeness: PluginSessionOptionsCompleteness.complete,
  );

  test("discovery result variants expose only their valid state", () {
    const observed = PluginSessionOptionsDiscoveryResult.observed(options: options);
    const failed = PluginSessionOptionsDiscoveryResult.failed();

    String describe({required PluginSessionOptionsDiscoveryResult result}) => switch (result) {
      PluginSessionOptionsDiscoveryObserved(:final options) => options.completeness.name,
      PluginSessionOptionsDiscoveryFailed() => "failed",
    };

    expect(describe(result: observed), "complete");
    expect(describe(result: failed), "failed");
  });

  test("discovery mode is independent from aggregate completeness", () {
    expect(PluginSessionOptionsDiscoveryMode.values, [
      PluginSessionOptionsDiscoveryMode.reuse,
      PluginSessionOptionsDiscoveryMode.refresh,
    ]);
    expect(PluginSessionOptionsCompleteness.values, [
      PluginSessionOptionsCompleteness.partial,
      PluginSessionOptionsCompleteness.complete,
    ]);
  });
}
