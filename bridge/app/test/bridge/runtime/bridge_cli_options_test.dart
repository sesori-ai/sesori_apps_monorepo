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
}

BridgeCliOptions _parseOptions({required List<String> args}) {
  final parser = ArgParser()
    ..addOption("relay", defaultsTo: "wss://relay.sesori.com")
    ..addOption("auth-backend", defaultsTo: "")
    ..addOption("debug-port", defaultsTo: "")
    ..addOption(
      "log-level",
      defaultsTo: "info",
      allowed: ["verbose", "debug", "info", "warning", "error"],
    );

  final results = parser.parse(args);
  return BridgeCliOptions.fromArgResults(
    cliArgs: args,
    results: results,
    environment: const {},
    defaultAuthUrl: "https://api.sesori.com",
  );
}
