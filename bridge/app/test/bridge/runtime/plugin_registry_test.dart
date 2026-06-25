import "package:codex_plugin/codex_plugin.dart" show CodexPluginDescriptor;
import "package:opencode_plugin/opencode_plugin.dart" show OpenCodePluginDescriptor;
import "package:sesori_bridge/src/bridge/runtime/plugin_registry.dart";
import "package:sesori_bridge/src/server/host/plugin_state_directory.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgePlugin, BridgePluginDescriptor, PluginConfig, PluginHost, PluginOption;
import "package:test/test.dart";

void main() {
  group("knownPlugins", () {
    test("registers the real OpenCode and Codex descriptors", () {
      expect(knownPlugins, hasLength(2));

      final openCode = knownPlugins.firstWhere((plugin) => plugin.id == openCodePluginId);
      expect(openCode, isA<OpenCodePluginDescriptor>());
      expect(identical(openCode.options, OpenCodePluginDescriptor.cliOptions), isTrue);

      final codex = knownPlugins.firstWhere((plugin) => plugin.id == "codex");
      expect(codex, isA<CodexPluginDescriptor>());
      expect(identical(codex.options, CodexPluginDescriptor.cliOptions), isTrue);

      // OpenCode stays the default so existing installs see zero change.
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
        knownPlugins: _descriptors,
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

    test("a default id missing from the known plugins is a descriptive wiring error", () async {
      final selector = PluginSelector(
        knownPlugins: _descriptors,
        defaultPluginId: "miswired",
        loadEnabledPlugins: () async => null,
      );

      await expectLater(
        selector.resolve(args: []),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            "message",
            allOf(contains('"miswired"'), contains("opencode, cursor")),
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

class _FakeDescriptor extends BridgePluginDescriptor {
  const _FakeDescriptor({required this.id});

  @override
  final String id;

  @override
  String get displayName => id;

  @override
  List<PluginOption> get options => const [];

  @override
  void validateConfig(PluginConfig config) {}

  @override
  Future<BridgePlugin> start(PluginHost host) =>
      throw UnsupportedError("selector tests never start a plugin");
}

const _descriptors = [
  _FakeDescriptor(id: "opencode"),
  _FakeDescriptor(id: "cursor"),
];

PluginSelector _selector({required List<String>? enabledPlugins}) {
  return PluginSelector(
    knownPlugins: _descriptors,
    defaultPluginId: "opencode",
    loadEnabledPlugins: () async => enabledPlugins,
  );
}
