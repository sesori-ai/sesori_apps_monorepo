import "package:args/args.dart";
import "package:sesori_bridge/src/runtime/plugin_cli_options_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show PluginConfigException, PluginFlagOption, PluginOption, PluginValueOption;
import "package:test/test.dart";

void main() {
  const mapper = PluginCliOptionsMapper(pluginId: "opencode");

  group("register", () {
    test("registers flags and value options under their canonical names with defaults", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);

      final results = parser.parse(const []);
      expect(results["opencode-no-auto-start"], isFalse);
      expect(results["opencode-port"], isNull);
      expect(results["opencode-password"], "");
      expect(results["opencode-bin"], "opencode");
    });

    test("keeps flags negatable when declared negatable", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);

      final results = parser.parse(const ["--no-opencode-no-auto-start"]);
      expect(results["opencode-no-auto-start"], isFalse);
    });

    test("rejects values outside allowedValues at parse time", () {
      final parser = ArgParser();
      mapper.register(
        parser: parser,
        options: const [
          PluginValueOption(
            name: "mode",
            help: "Mode",
            defaultsTo: null,
            allowedValues: ["fast", "safe"],
            valueHelp: null,
            validate: null,
          ),
        ],
      );

      expect(() => parser.parse(const ["--opencode-mode", "slow"]), throwsA(isA<ArgParserException>()));
    });
  });

  group("parse", () {
    test("captures parsed values for every declared option keyed by bare name", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);
      final results = parser.parse(const ["--opencode-port", "4096", "--opencode-no-auto-start"]);

      final config = mapper.parse(results: results, options: _options);
      expect(config.intValue("port"), 4096);
      expect(config.flag("no-auto-start"), isTrue);
      expect(config.value("password"), "");
      expect(config.value("bin"), "opencode");
    });

    test("runs validate hooks on present, non-empty values naming the canonical flag", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);
      final results = parser.parse(const ["--opencode-port", "not-a-number"]);

      expect(
        () => mapper.parse(results: results, options: _options),
        throwsA(
          isA<PluginConfigException>().having((e) => e.message, "message", contains("--opencode-port")),
        ),
      );
    });

    test("skips validate hooks for absent and empty values", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);

      final absent = mapper.parse(results: parser.parse(const []), options: _options);
      expect(absent.intValue("port"), isNull);

      final empty = mapper.parse(results: parser.parse(const ["--opencode-port", ""]), options: _options);
      expect(empty.intValue("port"), isNull);
    });
  });
}

const List<PluginOption> _options = [
  PluginValueOption.integer(
    name: "port",
    help: "Port for opencode server to listen on",
    defaultsTo: null,
    valueHelp: null,
  ),
  PluginFlagOption(
    name: "no-auto-start",
    help: "Skip auto-starting opencode server (use existing server)",
    defaultsTo: false,
    negatable: true,
  ),
  PluginValueOption(
    name: "password",
    help: "Override server password (auto-generated if not set)",
    defaultsTo: "",
    allowedValues: null,
    valueHelp: null,
    validate: null,
  ),
  PluginValueOption(
    name: "bin",
    help: "Path to opencode binary",
    defaultsTo: "opencode",
    allowedValues: null,
    valueHelp: null,
    validate: null,
  ),
];
