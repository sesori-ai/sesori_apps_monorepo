import "package:sesori_bridge/src/bridge/runtime/legacy_opencode_descriptor.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_registry.dart";
import "package:sesori_bridge/src/server/host/plugin_state_directory.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginConfig;
import "package:test/test.dart";

void main() {
  group("knownPlugins", () {
    test("registers the OpenCode surface off the legacy descriptor statics", () {
      expect(knownPlugins, hasLength(1));
      expect(knownPlugins.single.id, openCodePluginId);
      expect(identical(knownPlugins.single.options, LegacyOpenCodeDescriptor.cliOptions), isTrue);
      expect(knownPlugins.single.validateConfig, LegacyOpenCodeDescriptor.validateConfigValues);
      expect(defaultPluginId, openCodePluginId);
    });
  });

  group("PluginSelector", () {
    test("defaults to the fallback when nothing selects a plugin", () async {
      final selector = _selector(enabledPlugins: null);

      final surface = await selector.resolve(args: ["run", "--port", "4096"]);

      expect(surface.id, "opencode");
    });

    test("a --plugin value on the command line wins over settings", () async {
      var loads = 0;
      final selector = PluginSelector(
        knownPlugins: _surfaces,
        defaultPluginId: "opencode",
        loadEnabledPlugins: () async {
          loads++;
          return ["cursor"];
        },
      );

      final surface = await selector.resolve(args: ["--plugin", "opencode"]);

      expect(surface.id, "opencode");
      expect(loads, 0, reason: "settings are only read when the command line selects nothing");
    });

    test("the --plugin=id form is recognized", () async {
      final selector = _selector(enabledPlugins: null);

      final surface = await selector.resolve(args: ["--plugin=cursor"]);

      expect(surface.id, "cursor");
    });

    test("the last --plugin occurrence wins, like the parser's last-wins rule", () async {
      final selector = _selector(enabledPlugins: null);

      final surface = await selector.resolve(args: ["--plugin", "cursor", "--plugin=opencode"]);

      expect(surface.id, "opencode");
    });

    test("the scan stops at a standalone -- terminator", () async {
      final selector = _selector(enabledPlugins: ["cursor"]);

      final surface = await selector.resolve(args: ["run", "--", "--plugin", "opencode"]);

      expect(surface.id, "cursor", reason: "tokens after -- are rest arguments, not options");
    });

    test("the space form consumes the next token unconditionally, like the parser", () async {
      final selector = _selector(enabledPlugins: null);

      final surface = await selector.resolve(args: ["--plugin", "cursor", "--", "--plugin=opencode"]);

      expect(surface.id, "cursor");
    });

    test("the space form swallows even a -- token as the value, exactly like the parser", () async {
      final selector = _selector(enabledPlugins: ["cursor"]);

      final surface = await selector.resolve(args: ["--plugin", "--", "x"]);

      expect(
        surface.id,
        "opencode",
        reason: 'the parser reads "--" as the value (unknown id -> fallback); settings must not win',
      );
    });

    test("the space form swallows a following option token as the value, exactly like the parser", () async {
      final selector = _selector(enabledPlugins: ["cursor"]);

      final surface = await selector.resolve(args: ["--plugin", "--port", "4096"]);

      expect(
        surface.id,
        "opencode",
        reason: 'the parser reads "--port" as the value (unknown id -> fallback); the full parse reports it',
      );
    });

    test("an empty --plugin= value resolves to the fallback, not settings", () async {
      final selector = _selector(enabledPlugins: ["cursor"]);

      final surface = await selector.resolve(args: ["--plugin="]);

      expect(surface.id, "opencode");
    });

    test("an unknown --plugin value resolves to the fallback surface", () async {
      final selector = _selector(enabledPlugins: ["cursor"]);

      final surface = await selector.resolve(args: ["--plugin", "bogus"]);

      expect(
        surface.id,
        "opencode",
        reason: "the parser still gets built; its allowed: list reports the unknown id on the full parse",
      );
    });

    test("a trailing --plugin with no value falls through to settings", () async {
      final selector = _selector(enabledPlugins: ["cursor"]);

      final surface = await selector.resolve(args: ["--port", "4096", "--plugin"]);

      expect(surface.id, "cursor", reason: "the full parse reports the missing argument");
    });

    test("settings select the plugin when the command line does not", () async {
      final selector = _selector(enabledPlugins: ["cursor"]);

      final surface = await selector.resolve(args: ["run"]);

      expect(surface.id, "cursor");
    });

    test("an empty enabledPlugins list falls back to the default", () async {
      final selector = _selector(enabledPlugins: []);

      final surface = await selector.resolve(args: []);

      expect(surface.id, "opencode");
    });

    test("multiple enabledPlugins entries throw a selection error", () async {
      final selector = _selector(enabledPlugins: ["opencode", "cursor"]);

      await expectLater(
        selector.resolve(args: []),
        throwsA(
          isA<PluginSelectionException>().having(
            (e) => e.message,
            "message",
            allOf(contains("opencode, cursor"), contains("exactly one")),
          ),
        ),
      );
    });

    test("an unknown enabledPlugins id throws a selection error naming the known plugins", () async {
      final selector = _selector(enabledPlugins: ["bogus"]);

      await expectLater(
        selector.resolve(args: []),
        throwsA(
          isA<PluginSelectionException>().having(
            (e) => e.message,
            "message",
            allOf(contains('"bogus"'), contains("opencode, cursor")),
          ),
        ),
      );
    });
  });
}

void _noValidation(PluginConfig config) {}

const _surfaces = [
  PluginCliSurface(id: "opencode", options: [], validateConfig: _noValidation),
  PluginCliSurface(id: "cursor", options: [], validateConfig: _noValidation),
];

PluginSelector _selector({required List<String>? enabledPlugins}) {
  return PluginSelector(
    knownPlugins: _surfaces,
    defaultPluginId: "opencode",
    loadEnabledPlugins: () async => enabledPlugins,
  );
}
