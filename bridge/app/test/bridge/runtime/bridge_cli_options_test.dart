import "package:args/args.dart";
import "package:path/path.dart" as path;
import "package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart";
import "package:test/test.dart";

void main() {
  test("relay falls back to the parser default", () {
    final options = _parseOptions(args: const []);

    expect(options.relayUrl, "wss://relay.sesori.com");
  });

  test("explicit relay is preserved", () {
    final options = _parseOptions(args: ["--relay", "wss://relay.sesori.test"]);

    expect(options.relayUrl, "wss://relay.sesori.test");
  });

  test("auth backend falls back to the default URL", () {
    final options = _parseOptions(args: const []);

    expect(options.authBackendUrl, "https://api.sesori.com");
  });

  test("debug port is parsed when present", () {
    final options = _parseOptions(args: ["--debug-port", "8080"]);

    expect(options.debugPort, 8080);
  });

  group("data directory", () {
    test("uses the canonical default when the flag is absent", () {
      final options = _parseOptions(args: const []);

      expect(options.dataDirectory, "/default/sesori-data");
    });

    test("normalizes an explicit path to an absolute path", () {
      final options = _parseOptions(args: const ["--data-dir", "relative-data"]);

      expect(
        options.dataDirectory,
        path.normalize(path.absolute("relative-data")),
      );
    });

    test("rejects an empty explicit path", () {
      expect(
        () => _parseOptions(args: const ["--data-dir", "   "]),
        throwsA(isA<ArgParserException>()),
      );
    });
  });

  test("import plugin values retain order and duplicates", () {
    final options = _parseOptions(
      args: const ["--import-plugin", "opencode", "--import-plugin", "opencode"],
    );

    expect(options.importPluginIds, const ["opencode", "opencode"]);
  });

  group("supervised mode (--control-url)", () {
    test("is standalone when --control-url is absent", () {
      final options = _parseOptions(args: const []);

      expect(options.controlUrl, isNull);
      expect(options.isSupervised, isFalse);
    });

    test("is supervised when --control-url is provided", () {
      final options = _parseOptions(args: const ["--control-url", "ws://127.0.0.1:54321/control"]);

      expect(options.controlUrl, equals("ws://127.0.0.1:54321/control"));
      expect(options.isSupervised, isTrue);
    });

    test("treats a blank --control-url as standalone", () {
      final options = _parseOptions(args: const ["--control-url", "   "]);

      expect(options.controlUrl, isNull);
      expect(options.isSupervised, isFalse);
    });

    test("trims the control URL", () {
      final options = _parseOptions(args: const ["--control-url", "  ws://127.0.0.1:9/ctrl  "]);

      expect(options.controlUrl, equals("ws://127.0.0.1:9/ctrl"));
    });

    test("leaves the standalone options unchanged", () {
      final options = _parseOptions(args: const ["--relay", "wss://example.test/relay", "--log-level", "debug"]);

      expect(options.relayUrl, equals("wss://example.test/relay"));
      expect(options.logLevelName, equals("debug"));
      expect(options.isSupervised, isFalse);
    });
  });
}

BridgeCliOptions _parseOptions({required List<String> args}) {
  // Only the core options the RunCommand parser registers. Plugin-owned
  // options (e.g. opencode's --port/--password) are intentionally absent:
  // BridgeCliOptions must not read them, or selecting a plugin that doesn't
  // declare them (e.g. cursor) would crash at parse time. There is also NO
  // `--control-secret` option — the per-spawn secret is delivered off-argv
  // (ADR A8), never on the command line.
  final parser = ArgParser()
    ..addOption("relay", defaultsTo: "wss://relay.sesori.com")
    ..addOption("auth-backend", defaultsTo: "")
    ..addOption("data-dir")
    ..addMultiOption("import-plugin")
    ..addOption("debug-port", defaultsTo: "")
    ..addOption(
      "log-level",
      defaultsTo: "info",
      allowed: ["verbose", "debug", "info", "warning", "error"],
    )
    ..addOption("control-url", hide: true);

  final results = parser.parse(args);
  return BridgeCliOptions.fromArgResults(
    cliArgs: args,
    results: results,
    environment: const {},
    defaultAuthUrl: "https://api.sesori.com",
    defaultDataDirectory: "/default/sesori-data",
  );
}
