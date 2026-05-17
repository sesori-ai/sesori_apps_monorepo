import "package:args/args.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart";
import "package:test/test.dart";

void main() {
  test("omitted port stays unset for auto-start", () {
    final options = _parseOptions(args: ["--relay", "wss://relay.sesori.test"]);

    expect(options.port, isNull);
    expect(options.noAutoStart, isFalse);
  });

  test("explicit 4096 is preserved", () {
    final options = _parseOptions(args: ["--port", "4096"]);

    expect(options.port, 4096);
  });

  test("no-auto-start without port fails clearly", () {
    expect(
      () => _parseOptions(args: ["--no-auto-start"]),
      throwsA(
        isA<ArgParserException>().having(
          (error) => error.message,
          "message",
          allOf(contains("--no-auto-start"), contains("--port")),
        ),
      ),
    );
  });
}

BridgeCliOptions _parseOptions({required List<String> args}) {
  final parser = ArgParser()
    ..addOption("relay", defaultsTo: "wss://relay.sesori.com")
    ..addOption("port")
    ..addFlag("no-auto-start", defaultsTo: false)
    ..addOption("password", defaultsTo: "")
    ..addOption("opencode-bin", defaultsTo: "opencode")
    ..addOption("auth-backend", defaultsTo: "")
    ..addFlag("login", defaultsTo: false)
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
