import "dart:async";

import "package:claude_plugin/claude_plugin.dart";
import "package:claude_plugin/claude_testing.dart";
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";

void main() {
  group("ClaudeCatalogService", () {
    late List<FakeClaudeProcess> spawned;
    late List<ClaudeLaunchSpec> specs;
    late ClaudeSessionProcessRepository processes;
    late ClaudeCatalogService service;

    setUp(() {
      spawned = [];
      specs = [];
      processes = ClaudeSessionProcessRepository(
        processFactory: (spec) async {
          final process = FakeClaudeProcess();
          specs.add(spec);
          spawned.add(process);
          unawaited(_answerCatalogControls(process, commandName: "review"));
          return process;
        },
        binaryPath: "claude",
        environment: const {},
      );
      service = ClaudeCatalogService(
        catalog: const ClaudeBackendCatalogRepository(),
        processes: processes,
        probeSessionId: otherTestSessionId,
        discoveryDirectory: "/tmp/claude-state",
      );
    });

    tearDown(() async {
      await processes.dispose();
      for (final process in spawned) {
        await process.close();
      }
    });

    test("discovers globally from the configured directory and reaps the probe", () async {
      final catalog = await service.getCatalog(refresh: false);

      expect(catalog.providers.providers.single.models, hasLength(2));
      expect(specs.single.workingDirectory, "/tmp/claude-state");
      expect(_controlSubtypes(spawned.single), ["initialize"]);
      expect(spawned.single.killed, isTrue);
    });

    test("serves the cached global catalog without another probe", () async {
      await service.getCatalog(refresh: false);
      await service.getCatalog(refresh: false);

      expect(spawned, hasLength(1));
    });

    test("refreshes models through a new global probe while retaining commands", () async {
      await service.getCatalog(refresh: false);
      final refreshed = await service.getCatalog(refresh: true);

      expect(spawned, hasLength(2));
      expect(specs.map((spec) => spec.workingDirectory), everyElement("/tmp/claude-state"));
      expect(_controlSubtypes(spawned.last), contains("list_models"));
      expect(refreshed.providers.providers.single.models.single.id, "new");
      expect(refreshed.commands.single.name, "review");
      expect(spawned.last.killed, isTrue);
    });

    test("coalesces concurrent global reads", () async {
      final first = service.getCatalog(refresh: false);
      final second = service.getCatalog(refresh: false);

      expect(await first, same(await second));
      expect(spawned, hasLength(1));
    });

    test("queues an explicit refresh behind an in-flight reuse discovery", () async {
      final reuse = service.getCatalog(refresh: false);
      final refresh = service.getCatalog(refresh: true);

      await reuse;
      final refreshed = await refresh;
      expect(spawned, hasLength(2));
      expect(_controlSubtypes(spawned.last), contains("list_models"));
      expect(refreshed.providers.providers.single.models.single.id, "new");
    });
  });

  group("ClaudeCatalogService live selections", () {
    late FakeClaudeProcess process;
    late ClaudeSessionProcessRepository processes;
    late ClaudeCatalogService service;

    setUp(() async {
      process = FakeClaudeProcess();
      processes = ClaudeSessionProcessRepository(
        processFactory: (_) async {
          unawaited(_answerCatalogControls(process, commandName: "review"));
          return process;
        },
        binaryPath: "claude",
        environment: const {},
      );
      service = ClaudeCatalogService(
        catalog: const ClaudeBackendCatalogRepository(),
        processes: processes,
        probeSessionId: otherTestSessionId,
        discoveryDirectory: "/tmp/claude-state",
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

    test("switches model without changing the process launch effort", () async {
      final selected = service.selectModel(sessionId: testSessionId, modelId: "large");
      final request = await _waitForControl(process, "set_model");
      expect(_request(request)["model"], "large");
      process.emitControlResponse(requestId: request["request_id"]! as String, payload: const {});
      await selected;

      final applied = processes.appliedSelection(sessionId: testSessionId)!;
      expect(applied.model, "large");
      expect(applied.effort, ClaudeEffortLevel.low);
      expect(applied.permissionMode, ClaudePermissionMode.standard);
    });

    test("resets the default model without discarding launch selections", () async {
      final selected = service.selectModel(sessionId: testSessionId, modelId: "default");
      final request = await _waitForControl(process, "set_model");
      expect(_request(request), containsPair("model", null));
      process.emitControlResponse(requestId: request["request_id"]! as String, payload: const {});
      await selected;

      final applied = processes.appliedSelection(sessionId: testSessionId)!;
      expect(applied.model, isNull);
      expect(applied.effort, ClaudeEffortLevel.low);
      expect(applied.permissionMode, ClaudePermissionMode.standard);
    });

    test("maps Plan to the control protocol and preserves model selection", () async {
      final selected = service.selectAgent(sessionId: testSessionId, agent: "Plan");
      final request = await _waitForControl(process, "set_permission_mode");
      expect(_request(request)["mode"], "plan");
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
      expect(_controlSubtypes(process), ["initialize"]);
    });
  });
}

Future<void> _answerCatalogControls(FakeClaudeProcess process, {required String commandName}) async {
  final answered = <String>{};
  while (!process.killed) {
    for (final frame in process.written) {
      if (frame["type"] != "control_request") continue;
      final requestId = frame["request_id"]! as String;
      if (!answered.add(requestId)) continue;
      final subtype = _request(frame)["subtype"];
      process.emitControlResponse(
        requestId: requestId,
        payload: switch (subtype) {
          "initialize" => {
            ...sampleHandshake,
            "commands": [
              {"name": commandName, "description": "Review changes", "argumentHint": "[path]"},
            ],
          },
          "list_models" => {
            "models": [
              {"value": "new", "displayName": "New model"},
            ],
          },
          _ => const {},
        },
      );
    }
    await pump();
  }
}

Map<String, Object?> _request(Map<String, Object?> frame) => (frame["request"]! as Map).cast<String, Object?>();

Iterable<String?> _controlSubtypes(FakeClaudeProcess process) => process.written
    .where((frame) => frame["type"] == "control_request")
    .map((frame) => _request(frame)["subtype"] as String?);

Future<Map<String, Object?>> _waitForControl(FakeClaudeProcess process, String subtype) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    for (final frame in process.written) {
      if (frame["type"] == "control_request" && _request(frame)["subtype"] == subtype) return frame;
    }
    await pump();
  }
  throw StateError("no '$subtype' control request written");
}
