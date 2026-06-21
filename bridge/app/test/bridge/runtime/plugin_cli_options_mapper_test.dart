import "package:args/args.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_cli_options_mapper.dart";
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

    test("also registers the deprecated aliases under their legacy names", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);

      // The legacy spellings still parse (hidden), defaulting to absent/false.
      final results = parser.parse(const ["--port", "4096", "--no-auto-start"]);
      expect(results["port"], "4096");
      expect(results["no-auto-start"], isTrue);
    });

    test("keeps flags negatable when declared negatable", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);

      final results = parser.parse(const ["--no-opencode-no-auto-start"]);
      expect(results["opencode-no-auto-start"], isFalse);
    });

    test("rejects values outside allowedValues at parse time, including via the alias", () {
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
            deprecatedAliases: ["mode"],
          ),
        ],
      );

      expect(() => parser.parse(const ["--opencode-mode", "slow"]), throwsA(isA<ArgParserException>()));
      // The legacy alias enforces the same allowed-value set.
      expect(() => parser.parse(const ["--mode", "slow"]), throwsA(isA<ArgParserException>()));
    });
  });

  group("parse", () {
    test("captures parsed values for every declared option keyed by bare name", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);
      final results = parser.parse(const ["--opencode-port", "4096", "--opencode-no-auto-start"]);

      final parsed = mapper.parse(results: results, options: _options);
      expect(parsed.config.intValue("port"), 4096);
      expect(parsed.config.flag("no-auto-start"), isTrue);
      expect(parsed.config.value("password"), "");
      expect(parsed.config.value("bin"), "opencode");
      expect(parsed.deprecations, isEmpty);
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
      expect(absent.config.intValue("port"), isNull);

      final empty = mapper.parse(results: parser.parse(const ["--opencode-port", ""]), options: _options);
      expect(empty.config.intValue("port"), isNull);
    });

    test("resolves a legacy alias and reports it as deprecated", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);
      final results = parser.parse(const ["--port", "4096"]);

      final parsed = mapper.parse(results: results, options: _options);
      expect(parsed.config.intValue("port"), 4096);
      expect(parsed.deprecations, equals(["--port is deprecated; use --opencode-port instead."]));
    });

    test("prefers the canonical value when both canonical and alias are passed, still warning", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);
      final results = parser.parse(const ["--opencode-port", "5000", "--port", "4096"]);

      final parsed = mapper.parse(results: results, options: _options);
      expect(parsed.config.intValue("port"), 5000);
      expect(parsed.deprecations, equals(["--port is deprecated; use --opencode-port instead."]));
    });

    test("validates a value supplied through the legacy alias, naming the legacy flag", () {
      final parser = ArgParser();
      mapper.register(parser: parser, options: _options);
      final results = parser.parse(const ["--port", "nope"]);

      expect(
        () => mapper.parse(results: results, options: _options),
        throwsA(
          isA<PluginConfigException>().having((e) => e.message, "message", contains("--port ")),
        ),
      );
    });
  });
}

const List<PluginOption> _options = [
  PluginValueOption.integer(
    name: "port",
    help: "Port for opencode server to listen on",
    defaultsTo: null,
    valueHelp: null,
    deprecatedAliases: ["port"],
  ),
  PluginFlagOption(
    name: "no-auto-start",
    help: "Skip auto-starting opencode server (use existing server)",
    defaultsTo: false,
    negatable: true,
    deprecatedAliases: ["no-auto-start"],
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
