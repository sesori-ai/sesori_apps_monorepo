import "package:args/args.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart";
import "package:test/test.dart";

void main() {
  test("relay URL is read from the flag", () {
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
  // Mirrors the bridge-core options that [BridgeCliOptions.fromArgResults]
  // reads. Notably there is NO `--control-secret` option — the per-spawn secret
  // is delivered off-argv (ADR A8), never on the command line.
  final parser = ArgParser()
    ..addOption("relay", defaultsTo: "wss://relay.sesori.com")
    ..addOption("auth-backend", defaultsTo: "")
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
  );
}
