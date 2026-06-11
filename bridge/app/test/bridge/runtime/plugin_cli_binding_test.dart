import "package:args/args.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_cli_binding.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show PluginConfigException, PluginFlagOption, PluginOption, PluginValueOption;
import "package:test/test.dart";

void main() {
  group("registerPluginOptions", () {
    test("registers flags and value options with declared defaults", () {
      final parser = ArgParser();
      registerPluginOptions(parser: parser, options: _options);

      final results = parser.parse(const []);
      expect(results["no-auto-start"], isFalse);
      expect(results["port"], isNull);
      expect(results["password"], "");
      expect(results["opencode-bin"], "opencode");
    });

    test("keeps flags negatable when declared negatable", () {
      final parser = ArgParser();
      registerPluginOptions(parser: parser, options: _options);

      final results = parser.parse(const ["--no-no-auto-start"]);
      expect(results["no-auto-start"], isFalse);
    });

    test("rejects values outside allowedValues at parse time", () {
      final parser = ArgParser();
      registerPluginOptions(
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

      expect(() => parser.parse(const ["--mode", "slow"]), throwsA(isA<ArgParserException>()));
    });
  });

  group("parsePluginConfig", () {
    test("captures parsed values for every declared option", () {
      final parser = ArgParser();
      registerPluginOptions(parser: parser, options: _options);
      final results = parser.parse(const ["--port", "4096", "--no-auto-start"]);

      final config = parsePluginConfig(options: _options, results: results);
      expect(config.intValue("port"), 4096);
      expect(config.flag("no-auto-start"), isTrue);
      expect(config.value("password"), "");
      expect(config.value("opencode-bin"), "opencode");
    });

    test("runs validate hooks on present, non-empty values", () {
      final parser = ArgParser();
      registerPluginOptions(parser: parser, options: _options);
      final results = parser.parse(const ["--port", "not-a-number"]);

      expect(
        () => parsePluginConfig(options: _options, results: results),
        throwsA(
          isA<PluginConfigException>().having((e) => e.message, "message", contains("--port")),
        ),
      );
    });

    test("skips validate hooks for absent and empty values", () {
      final parser = ArgParser();
      registerPluginOptions(parser: parser, options: _options);

      final absent = parsePluginConfig(options: _options, results: parser.parse(const []));
      expect(absent.intValue("port"), isNull);

      final empty = parsePluginConfig(options: _options, results: parser.parse(const ["--port", ""]));
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
    help: "Skip auto-starting opencode server (use existing localhost server)",
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
    name: "opencode-bin",
    help: "Path to opencode binary",
    defaultsTo: "opencode",
    allowedValues: null,
    valueHelp: null,
    validate: null,
  ),
];
