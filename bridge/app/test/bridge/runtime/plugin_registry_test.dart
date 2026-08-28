import "package:sesori_bridge/src/runtime/plugin_registry.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;
import "package:test/test.dart";

void main() {
  test("registry contains every bundled plugin exactly once", () {
    final ids = knownPlugins.map((plugin) => plugin.id).toList();

    expect(
      ids,
      unorderedEquals(["opencode", "codex", "copilot", "cursor", "claude", "hermes", "pi", "omp", "deepseek"]),
    );
  });

  test("every registered plugin id is a built-in Harness identity", () {
    final harnessNames = Harness.values.map((harness) => harness.name).toSet();
    for (final plugin in knownPlugins) {
      expect(harnessNames, contains(plugin.id));
    }
  });

  test("registered descriptors remain inert declarations", () {
    for (final plugin in knownPlugins) {
      expect(plugin.id, isNotEmpty);
      expect(plugin.displayName, isNotEmpty);
      expect(plugin.options.map((option) => option.name).toSet(), hasLength(plugin.options.length));
    }
  });
}
