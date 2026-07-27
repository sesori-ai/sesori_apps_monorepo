import "package:sesori_bridge/src/bridge/runtime/plugin_registry.dart";
import "package:test/test.dart";

void main() {
  test("registry contains every bundled plugin exactly once", () {
    final ids = knownPlugins.map((plugin) => plugin.id).toList();

    expect(ids, containsAll(["opencode", "codex", "cursor"]));
    expect(ids.toSet(), hasLength(ids.length));
  });

  test("registered descriptors remain inert declarations", () {
    for (final plugin in knownPlugins) {
      expect(plugin.id, isNotEmpty);
      expect(plugin.displayName, isNotEmpty);
      expect(plugin.options.map((option) => option.name).toSet(), hasLength(plugin.options.length));
    }
  });
}
