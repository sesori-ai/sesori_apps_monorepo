import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:cursor_plugin/src/api/cursor_catalog_api.dart";
import "package:test/test.dart";

void main() {
  group("CursorCatalogApi", () {
    late FakeAcpProcess process;
    late AcpStdioClient client;
    late CursorCatalogApi api;
    final handledFrameIds = <Object?>{};

    setUp(() {
      process = FakeAcpProcess();
      client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(
          command: "cursor-agent",
          args: ["acp"],
        ),
        processFactory: (_) async => process,
      );
      api = CursorCatalogApi(
        client: client,
        api: AcpApi(client: client),
      );
      handledFrameIds.clear();
    });

    tearDown(() async {
      await api.dispose();
      await process.close();
    });

    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 50; i++) {
        final matches = process.written.where(
          (frame) => frame["method"] == method && !handledFrameIds.contains(frame["id"]),
        );
        if (matches.isNotEmpty) {
          final frame = matches.first;
          handledFrameIds.add(frame["id"]);
          return frame;
        }
        await Future<void>.delayed(Duration.zero);
      }
      throw StateError("agent never received a '$method' frame");
    }

    void respond(Map<String, dynamic> frame, Object? result) {
      process.emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
    }

    Future<void> open({required bool requiresAuth}) async {
      final opening = api.open(timeout: const Duration(seconds: 1));
      final initialize = await waitForFrame(AcpMethods.initialize);
      expect(initialize["params"], {
        "protocolVersion": acpProtocolVersion,
        "clientCapabilities": {
          "fs": {"readTextFile": false, "writeTextFile": false},
          "terminal": false,
          "_meta": {"parameterizedModelPicker": true},
        },
        "clientInfo": {"name": "sesori-bridge", "version": "0.0.0"},
      });
      respond(initialize, {
        "protocolVersion": acpProtocolVersion,
        "agentCapabilities": {
          "loadSession": true,
          "sessionCapabilities": {"list": <String, dynamic>{}},
        },
        "authMethods": [
          if (requiresAuth) {"id": "cursor_login", "name": "Cursor Login"},
        ],
      });
      if (requiresAuth) {
        final authenticate = await waitForFrame(AcpMethods.authenticate);
        expect(authenticate["params"], {"methodId": "cursor_login"});
        respond(authenticate, null);
      }
      await opening;
    }

    test("owns connect, initialize, authentication, and reset lifecycle", () async {
      await open(requiresAuth: true);

      expect(client.isConnected, isTrue);

      await api.reset();

      expect(client.isConnected, isFalse);
      expect(
        () => api.listSessions(
          directory: null,
          cursor: null,
          timeout: const Duration(seconds: 1),
        ),
        throwsStateError,
      );
    });

    test("delegates typed session list and load operations", () async {
      await open(requiresAuth: false);

      final listing = api.listSessions(
        directory: "/project",
        cursor: "next-page",
        timeout: const Duration(seconds: 1),
      );
      final listFrame = await waitForFrame(AcpMethods.sessionList);
      expect(listFrame["params"], {"cwd": "/project", "cursor": "next-page"});
      respond(listFrame, {
        "sessions": [
          {"sessionId": "session-1", "cwd": "/project"},
        ],
        "nextCursor": null,
      });
      expect((await listing).sessions.single.sessionId, "session-1");

      final loading = api.loadSession(
        sessionId: "session-1",
        directory: "/project",
        timeout: const Duration(seconds: 1),
      );
      final loadFrame = await waitForFrame(AcpMethods.sessionLoad);
      expect(loadFrame["params"], {
        "sessionId": "session-1",
        "cwd": "/project",
        "mcpServers": <Object?>[],
      });
      respond(loadFrame, {"sessionId": "session-1", "configOptions": <Object?>[]});
      expect((await loading).sessionId, "session-1");
    });
  });
}
