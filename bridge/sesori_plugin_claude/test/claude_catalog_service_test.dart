import "dart:async";

import "package:claude_plugin/claude_plugin.dart";
import "package:claude_plugin/claude_testing.dart";
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";

void main() {
  group("ClaudeCatalogService", () {
    late FakeClaudeProcess process;
    late ClaudeSessionProcessRepository processes;
    late ClaudeCatalogService service;

    setUp(() async {
      process = FakeClaudeProcess();
      processes = ClaudeSessionProcessRepository(
        processFactory: (_) async {
          unawaited(() async {
            final request = await _waitForControl(process, "initialize");
            process.emitControlResponse(requestId: request["request_id"]! as String, payload: sampleHandshake);
          }());
          return process;
        },
        binaryPath: "claude",
        environment: const {},
      );
      service = ClaudeCatalogService(
        catalog: const ClaudeBackendCatalogRepository(),
        processes: processes,
      );
      await processes.ensureResident(
        sessionId: testSessionId,
        directory: "/tmp/project",
        createNew: true,
        model: "small",
        effort: ClaudeEffortLevel.low,
        permissionMode: ClaudePermissionMode.standard,
        allowedTools: const [],
      );
    });

    tearDown(() async {
      await processes.dispose();
      await process.close();
    });

    test("maps the retained initialize response without another probe", () async {
      final catalog = await service.getCatalog(sessionId: testSessionId, refresh: false);

      expect(catalog.providers.providers.single.models, hasLength(2));
      expect(process.written.where(_isControlRequest), hasLength(1));
    });

    test("refreshes models through list_models while retaining commands", () async {
      final refreshed = service.getCatalog(sessionId: testSessionId, refresh: true);
      final request = await _waitForControl(process, "list_models");
      process.emitControlResponse(
        requestId: request["request_id"]! as String,
        payload: {
          "models": [
            {"value": "new", "displayName": "New model"},
          ],
        },
      );

      final catalog = await refreshed;
      expect(catalog.providers.providers.single.models.single.id, "new");
      expect(catalog.commands.single.name, "review");
    });

    test("switches model and records the selected effort", () async {
      final selected = service.selectModel(
        sessionId: testSessionId,
        modelId: "large",
        variant: "high",
      );
      final request = await _waitForControl(process, "set_model");
      expect(_requestPayload(request)["model"], "large");
      process.emitControlResponse(requestId: request["request_id"]! as String, payload: const {});
      await selected;

      final applied = processes.appliedSelection(sessionId: testSessionId)!;
      expect(applied.model, "large");
      expect(applied.effort, ClaudeEffortLevel.high);
      expect(applied.permissionMode, ClaudePermissionMode.standard);
    });

    test("resets the default model without discarding the selected mode", () async {
      final selected = service.selectModel(
        sessionId: testSessionId,
        modelId: "default",
        variant: null,
      );
      final request = await _waitForControl(process, "set_model");
      expect(_requestPayload(request), containsPair("model", null));
      process.emitControlResponse(requestId: request["request_id"]! as String, payload: const {});
      await selected;

      final applied = processes.appliedSelection(sessionId: testSessionId)!;
      expect(applied.model, isNull);
      expect(applied.effort, isNull);
      expect(applied.permissionMode, ClaudePermissionMode.standard);
    });

    test("maps Plan to the control protocol and preserves model selection", () async {
      final selected = service.selectAgent(sessionId: testSessionId, agent: "Plan");
      final request = await _waitForControl(process, "set_permission_mode");
      expect(_requestPayload(request)["mode"], "plan");
      process.emitControlResponse(requestId: request["request_id"]! as String, payload: const {});
      await selected;

      final applied = processes.appliedSelection(sessionId: testSessionId)!;
      expect(applied.model, "small");
      expect(applied.effort, ClaudeEffortLevel.low);
      expect(applied.permissionMode, ClaudePermissionMode.plan);
    });

    test("rejects an unknown agent without sending a control request", () async {
      await expectLater(
        service.selectAgent(sessionId: testSessionId, agent: "Research"),
        throwsArgumentError,
      );
      expect(process.written.where(_isControlRequest), hasLength(1));
    });
  });
}

bool _isControlRequest(Map<String, Object?> frame) => frame["type"] == "control_request";

Map<String, Object?> _requestPayload(Map<String, Object?> frame) => (frame["request"]! as Map).cast<String, Object?>();

Future<Map<String, Object?>> _waitForControl(FakeClaudeProcess process, String subtype) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    for (final frame in process.written) {
      if (frame["type"] == "control_request" && _requestPayload(frame)["subtype"] == subtype) return frame;
    }
    await pump();
  }
  throw StateError("no '$subtype' control request written");
}
