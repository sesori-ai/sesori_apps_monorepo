import "package:args/args.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart";
import "package:test/test.dart";

void main() {
  test("omitted port stays unset", () {
    final options = _parseOptions(args: ["--relay", "wss://relay.sesori.test"]);

    expect(options.port, isNull);
  });

  test("explicit 4096 is preserved", () {
    final options = _parseOptions(args: ["--port", "4096"]);

    expect(options.port, 4096);
  });

  test("auth backend falls back to the default URL", () {
    final options = _parseOptions(args: const []);

    expect(options.authBackendUrl, "https://api.sesori.com");
  });

  test("debug port is parsed when present", () {
    final options = _parseOptions(args: ["--debug-port", "8080"]);

    expect(options.debugPort, 8080);
  });

  test("a plugin without a password option (e.g. codex) parses without crashing", () {
    // Codex registers `port` but not `password`. Only the selected plugin's
    // options are on the parser, so reading `password` unconditionally would
    // throw — BridgeCliOptions must tolerate its absence.
    final parser = ArgParser()
      ..addOption("relay", defaultsTo: "wss://relay.sesori.com")
      ..addOption("port")
      ..addOption("codex-bin", defaultsTo: "codex")
      ..addOption("auth-backend", defaultsTo: "")
      ..addOption("debug-port", defaultsTo: "")
      ..addOption(
        "log-level",
        defaultsTo: "info",
        allowed: ["verbose", "debug", "info", "warning", "error"],
      );
    final results = parser.parse(["--debug-port", "8080"]);

    final options = BridgeCliOptions.fromArgResults(
      cliArgs: const ["--debug-port", "8080"],
      results: results,
      environment: const {},
      defaultAuthUrl: "https://api.sesori.com",
    );

    expect(options.password, "");
    expect(options.port, isNull);
    expect(options.debugPort, 8080);
  });
}

BridgeCliOptions _parseOptions({required List<String> args}) {
  final parser = ArgParser()
    ..addOption("relay", defaultsTo: "wss://relay.sesori.com")
    ..addOption("port")
    ..addOption("password", defaultsTo: "")
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
