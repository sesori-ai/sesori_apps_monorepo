import "package:sesori_bridge/src/bridge/runtime/bridge_runtime_runner.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_runtime_server.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_shutdown_coordinator.dart";
import "package:sesori_bridge/src/server/models/open_code_ownership_record.dart";
import "package:test/test.dart";

void main() {
  group("registerOwnedOpenCodeShutdown", () {
    test("registers one shutdown cleanup for an owned started OpenCode record", () async {
      final shutdownCoordinator = BridgeShutdownCoordinator();
      final stopCalls = <OpenCodeOwnershipRecord>[];
      final ownedRecord = _ownedRecord();

      registerOwnedOpenCodeShutdown(
        shutdownCoordinator: shutdownCoordinator,
        serverRuntime: BridgeServerRuntime(
          serverUrl: "http://127.0.0.1:50123",
          serverPassword: "secret",
          process: null,
          ownedOpenCodeRecord: ownedRecord,
          port: 50123,
        ),
        stopOwnedOpenCode: (record) async {
          stopCalls.add(record);
        },
      );

      await shutdownCoordinator.shutdown();

      expect(stopCalls, equals(<OpenCodeOwnershipRecord>[ownedRecord]));
    });

    test("does not register shutdown cleanup when no owned record exists", () async {
      final shutdownCoordinator = BridgeShutdownCoordinator();
      var stopCallCount = 0;

      registerOwnedOpenCodeShutdown(
        shutdownCoordinator: shutdownCoordinator,
        serverRuntime: const BridgeServerRuntime(
          serverUrl: "http://127.0.0.1:4096",
          serverPassword: null,
          process: null,
          ownedOpenCodeRecord: null,
          port: 4096,
        ),
        stopOwnedOpenCode: (_) async {
          stopCallCount += 1;
        },
      );

      await shutdownCoordinator.shutdown();

      expect(stopCallCount, equals(0));
    });
  });
}

OpenCodeOwnershipRecord _ownedRecord() {
  return OpenCodeOwnershipRecord(
    ownerSessionId: "owner-session",
    openCodePid: 300,
    openCodeStartMarker: "open-start",
    openCodeExecutablePath: "/usr/local/bin/opencode",
    openCodeCommand: "/usr/local/bin/opencode",
    openCodeArgs: const <String>["serve", "--port", "50123", "--hostname", "127.0.0.1"],
    port: 50123,
    bridgePid: 100,
    bridgeStartMarker: "bridge-start",
    startedAt: DateTime.utc(2026, 5, 15, 12),
    status: OpenCodeOwnershipStatus.ready,
  );
}
