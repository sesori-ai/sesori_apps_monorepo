import "dart:io";

import "package:args/args.dart";
import "package:path/path.dart" as path;
import "package:sesori_bridge/src/runtime/bridge_cli_options.dart";
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

  test("auth backend removes every trailing slash at composition", () {
    final options = _parseOptions(args: ["--auth-backend", "https://auth.example.test///"]);

    expect(options.authBackendUrl, "https://auth.example.test");
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

    test("expands a leading tilde to the user's home directory", () {
      final options = _parseOptions(args: const ["--data-dir", "~/sesori-dev"]);

      expect(options.dataDirectory, "/test/home/sesori-dev");
    });

    test("expands a bare tilde to the user's home directory", () {
      final options = _parseOptions(args: const ["--data-dir", "~"]);

      expect(options.dataDirectory, "/test/home");
    });

    test("rejects an empty explicit path", () {
      expect(
        () => _parseOptions(args: const ["--data-dir", "   "]),
        throwsA(isA<ArgParserException>()),
      );
    });

    test("can be resolved independently for another command", () {
      expect(
        BridgeCliOptions.resolveDataDirectory(
          dataDirectoryFlag: "relative-logout-data",
          defaultDataDirectory: "/default/sesori-data",
          environment: const {},
        ),
        path.normalize(path.absolute("relative-logout-data")),
      );
    });

    test("uses the injected environment when expanding a tilde", () {
      expect(
        BridgeCliOptions.resolveDataDirectory(
          dataDirectoryFlag: "~/logout-data",
          defaultDataDirectory: "/default/sesori-data",
          environment: const {"HOME": "/injected/home"},
        ),
        "/injected/home/logout-data",
      );
    });

    test("rejects a tilde when the home directory is unavailable", () {
      expect(
        () => BridgeCliOptions.resolveDataDirectory(
          dataDirectoryFlag: "~/missing-home",
          defaultDataDirectory: "/default/sesori-data",
          environment: const {},
        ),
        throwsA(isA<ArgParserException>()),
      );
    });

    test("recognizes a symlink to the canonical directory as the default", () async {
      if (Platform.isWindows) return;
      final temporaryDirectory = await Directory.systemTemp.createTemp("sesori-data-alias-test-");
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final defaultDirectory = Directory(path.join(temporaryDirectory.path, "default"))..createSync();
      final alias = Link(path.join(temporaryDirectory.path, "alias"))..createSync(defaultDirectory.path);

      expect(
        BridgeCliOptions.isDefaultDataDirectory(
          dataDirectory: alias.path,
          defaultDataDirectory: defaultDirectory.path,
        ),
        isTrue,
      );
    });
  });

  test("import plugin values retain order and duplicates", () {
    final options = _parseOptions(
      args: const ["--import-plugin", "opencode", "--import-plugin", "opencode"],
    );

    expect(options.importPluginIds, const ["opencode", "opencode"]);
  });

  group("Device Canvas local TURN", () {
    test("is disabled by default", () {
      final options = _parseOptions(args: const []);

      expect(options.deviceCanvasLocalTurnUrls, isEmpty);
      expect(options.deviceCanvasLocalTurnSecretFile, isNull);
    });

    test("canonicalizes URLs and resolves the paired secret path", () {
      final options = _parseOptions(
        args: const [
          "--device-canvas-local-turn-url",
          "TURN:192.168.1.10:03478?TRANSPORT=UDP",
          "--device-canvas-local-turn-url",
          "turn:192.168.1.10?transport=tcp",
          "--device-canvas-local-turn-secret-file",
          "~/turn/secret",
        ],
      );

      expect(options.deviceCanvasLocalTurnUrls, const [
        "turn:192.168.1.10:3478?transport=udp",
        "turn:192.168.1.10:3478?transport=tcp",
      ]);
      expect(options.deviceCanvasLocalTurnSecretFile, "/test/home/turn/secret");
    });

    test("requires URL and secret options together", () {
      expect(
        () => _parseOptions(args: const ["--device-canvas-local-turn-url", "turn:192.168.1.10"]),
        throwsA(isA<ArgParserException>()),
      );
      expect(
        () => _parseOptions(args: const ["--device-canvas-local-turn-secret-file", "/tmp/secret"]),
        throwsA(isA<ArgParserException>()),
      );
    });

    test("rejects malformed and semantically duplicate URLs", () {
      for (final urls in const <List<String>>[
        ["https:relay.example.test"],
        ["turn:192.168.1.10", "TURN:192.168.1.10:03478?TRANSPORT=UDP"],
      ]) {
        expect(
          () => _parseOptions(
            args: [
              for (final url in urls) ...["--device-canvas-local-turn-url", url],
              "--device-canvas-local-turn-secret-file",
              "/tmp/secret",
            ],
          ),
          throwsA(isA<ArgParserException>()),
        );
      }
    });

    test("rejects nonlocal and mixed TURN endpoints", () {
      for (final urls in const <List<String>>[
        ["turn:relay.example.test"],
        ["turn:8.8.8.8"],
        ["turn:127.0.0.1"],
        ["turns:192.168.1.10"],
        ["turn:192.168.1.10?transport=udp", "turn:192.168.1.11?transport=tcp"],
        ["turn:192.168.1.10:3478?transport=udp", "turn:192.168.1.10:3479?transport=tcp"],
      ]) {
        expect(
          () => _parseOptions(
            args: [
              for (final url in urls) ...["--device-canvas-local-turn-url", url],
              "--device-canvas-local-turn-secret-file",
              "/tmp/secret",
            ],
          ),
          throwsA(isA<ArgParserException>()),
          reason: urls.toString(),
        );
      }
    });

    test("rejects more than the protocol URL limit", () {
      expect(
        () => _parseOptions(
          args: [
            for (var index = 0; index < 9; index++) ...[
              "--device-canvas-local-turn-url",
              "turn:192.168.1.10:3478?transport=udp",
            ],
            "--device-canvas-local-turn-secret-file",
            "/tmp/secret",
          ],
        ),
        throwsA(isA<ArgParserException>()),
      );
    });
  });

  group("Device Canvas production TURN", () {
    test("is disabled by default and accepts only explicit boolean values", () {
      expect(_parseOptions(args: const []).deviceCanvasProductionTurnEnabled, isFalse);
      expect(
        _parseOptions(
          args: const [],
          environment: const {"DEVICE_CANVAS_PRODUCTION_TURN": "true"},
        ).deviceCanvasProductionTurnEnabled,
        isTrue,
      );
      expect(
        _parseOptions(
          args: const [],
          environment: const {"DEVICE_CANVAS_PRODUCTION_TURN": "1"},
        ).deviceCanvasProductionTurnEnabled,
        isTrue,
      );
      for (final value in const ["", "TRUE", "yes"]) {
        expect(
          () => _parseOptions(
            args: const [],
            environment: {"DEVICE_CANVAS_PRODUCTION_TURN": value},
          ),
          throwsA(isA<ArgParserException>()),
        );
      }
    });

    test("cannot be combined with the local issuer", () {
      expect(
        () => _parseOptions(
          args: const [
            "--device-canvas-local-turn-url",
            "turn:192.168.1.10",
            "--device-canvas-local-turn-secret-file",
            "/tmp/secret",
          ],
          environment: const {"DEVICE_CANVAS_PRODUCTION_TURN": "true"},
        ),
        throwsA(isA<ArgParserException>()),
      );
    });
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

BridgeCliOptions _parseOptions({required List<String> args, Map<String, String> environment = const {}}) {
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
    ..addMultiOption("device-canvas-local-turn-url", hide: true)
    ..addOption("device-canvas-local-turn-secret-file", hide: true)
    ..addOption("control-url", hide: true);

  final results = parser.parse(args);
  return BridgeCliOptions.fromArgResults(
    cliArgs: args,
    results: results,
    environment: {"HOME": "/test/home", ...environment},
    defaultAuthUrl: "https://api.sesori.com",
    defaultDataDirectory: "/default/sesori-data",
  );
}
