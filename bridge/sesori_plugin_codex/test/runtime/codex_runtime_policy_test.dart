import "dart:io";
import "dart:math";

import "package:codex_plugin/src/runtime/codex_ownership_record.dart";
import "package:codex_plugin/src/runtime/codex_runtime_policy.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

ProcessIdentity _identity({required int pid, required String? executablePath, required String? startMarker}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: startMarker,
    executablePath: executablePath,
    commandLine: executablePath == null ? "codex" : "$executablePath app-server",
    ownerUser: null,
    platform: "macos",
    capturedAt: DateTime.utc(2026, 6, 1),
  );
}

void main() {
  group("codexAppServerArgs / codexServerUrl", () {
    test("spawn args pin the loopback WebSocket on the chosen port", () {
      expect(
        codexAppServerArgs(port: 51000, modelCatalogPath: null),
        equals(<String>["app-server", "--listen", "ws://127.0.0.1:51000"]),
      );
    });

    test("spawn args encode the isolated model catalog as TOML", () {
      expect(
        codexAppServerArgs(
          port: 51000,
          modelCatalogPath: r"C:\Sesori State\codex-model-catalog.json",
        ),
        equals(<String>[
          "app-server",
          "-c",
          r'model_catalog_json="C:\\Sesori State\\codex-model-catalog.json"',
          "--listen",
          "ws://127.0.0.1:51000",
        ]),
      );
    });

    test("the server url matches the spawn listen address", () {
      expect(codexServerUrl(port: 51000), equals("ws://127.0.0.1:51000"));
    });
  });

  group("codexDynamicCandidates", () {
    test("draws maxAttempts distinct in-range ephemeral ports", () {
      final ports = codexDynamicCandidates(random: Random(7)).toList();
      expect(ports, hasLength(dynamicCodexMaxAttempts));
      expect(ports.toSet(), hasLength(dynamicCodexMaxAttempts));
      for (final port in ports) {
        expect(port, inInclusiveRange(dynamicCodexPortMin, dynamicCodexPortMax));
      }
    });

    test("filters supplied candidates to the in-range rule, preserving order", () {
      final ports = codexDynamicCandidates(
        candidates: <int>[80, 49152, 70000, 49153],
      ).toList();
      expect(ports, equals(<int>[49152, 49153]));
    });

    test("bounds a lazy all-invalid supplied source instead of spinning forever", () {
      Iterable<int> infiniteInvalid() sync* {
        while (true) {
          yield 80; // out of range → always filtered out
        }
      }

      expect(codexDynamicCandidates(candidates: infiniteInvalid()).toList(), isEmpty);
    });

    test("caps the supplied candidates examined at dynamicCodexMaxAttempts", () {
      final ports = codexDynamicCandidates(
        candidates: <int>[49152, 49153, 49154, 49155, 49156, 49157, 49158],
      ).toList();
      expect(ports, equals(<int>[49152, 49153, 49154, 49155, 49156]));
    });
  });

  group("buildCodexOwnershipRecord", () {
    test("maps the draft into a starting record with the spawn args", () {
      final record = buildCodexOwnershipRecord(
        RuntimeRecordDraft(
          ownerSessionId: "owner-1",
          runtimeIdentity: _identity(pid: 4242, executablePath: "/bin/codex", startMarker: "marker"),
          port: 51000,
          bridgeIdentity: _identity(pid: 900, executablePath: "/bin/bridge", startMarker: "bridge-marker"),
          startedAt: DateTime.utc(2026, 6, 1, 9, 30),
        ),
        modelCatalogPath: "/state/codex-model-catalog.json",
      );

      expect(record.ownerSessionId, equals("owner-1"));
      expect(record.codexPid, equals(4242));
      expect(record.codexStartMarker, equals("marker"));
      expect(record.codexExecutablePath, equals("/bin/codex"));
      expect(record.codexCommand, equals("/bin/codex"));
      expect(
        record.codexArgs,
        equals(<String>[
          "app-server",
          "-c",
          'model_catalog_json="/state/codex-model-catalog.json"',
          "--listen",
          "ws://127.0.0.1:51000",
        ]),
      );
      expect(record.port, equals(51000));
      expect(record.bridgePid, equals(900));
      expect(record.bridgeStartMarker, equals("bridge-marker"));
      expect(record.startedAt, equals(DateTime.utc(2026, 6, 1, 9, 30)));
      expect(record.status, equals(CodexOwnershipStatus.starting));
    });

    test("falls back to codex when the runtime executable path is unknown", () {
      final record = buildCodexOwnershipRecord(
        RuntimeRecordDraft(
          ownerSessionId: "owner-2",
          runtimeIdentity: _identity(pid: 7, executablePath: null, startMarker: null),
          port: 49152,
          bridgeIdentity: _identity(pid: 900, executablePath: "/bin/bridge", startMarker: null),
          startedAt: DateTime.utc(2026, 6, 1),
        ),
        modelCatalogPath: null,
      );
      expect(record.codexExecutablePath, equals(""));
      expect(record.codexCommand, equals("codex"));
    });
  });

  group("probeCodexHealth", () {
    test("reports healthy when the loopback port is accepting connections", () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((socket) => socket.destroy());
      addTearDown(server.close);

      final probe = await probeCodexHealth(port: server.port);
      expect(probe.healthy, isTrue);
      expect(probe.error, isNull);
    });

    test("reports unhealthy (with an error) when nothing is listening", () async {
      // Bind then immediately release the port so it is almost certainly free.
      final scratch = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = scratch.port;
      await scratch.close();

      final probe = await probeCodexHealth(port: port, timeout: const Duration(milliseconds: 500));
      expect(probe.healthy, isFalse);
      expect(probe.error, isNotNull);
    });
  });

  group("policy knobs", () {
    test("crash restart is disabled (an unexpected exit is terminal)", () {
      expect(buildCodexRestartPolicy(), isA<DisabledRestartPolicy>());
    });
  });
}
