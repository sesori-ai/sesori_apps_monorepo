import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/src/api/cursor_catalog_probe_api.dart";
import "package:cursor_plugin/src/api/models/cursor_available_models_dto.dart";
import "package:cursor_plugin/src/repositories/cursor_catalog_repository.dart";
import "package:test/test.dart";

void main() {
  group("CursorCatalogRepository", () {
    late _FakeCursorCatalogProbeApi api;
    late CursorCatalogRepository repository;

    setUp(() {
      api = _FakeCursorCatalogProbeApi();
      repository = CursorCatalogRepository(
        api: api,
        launchScope: "/launch",
      );
    });

    test("aggregates scopes, deduplicates candidates, and maps their cwd", () async {
      api.sessionsByScope[null] = [
        _session("shared", cwd: null, updatedAtMs: 100),
        _session("global", cwd: "/global", updatedAtMs: 300),
      ];
      api.sessionsByScope["/launch"] = [
        _session("launch", cwd: null, updatedAtMs: 200),
      ];
      api.sessionsByScope["/project"] = [
        _session("shared", cwd: "/project", updatedAtMs: 400),
      ];

      final result = await repository.listCandidates(
        scope: "/project",
        timeout: const Duration(seconds: 1),
      );

      expect(api.listedScopes, [null, "/launch", "/project"]);
      expect(result.exhaustive, isTrue);
      expect(result.candidates.map((candidate) => candidate.sessionId), {
        "shared",
        "global",
        "launch",
      });
      expect(
        result.candidates.singleWhere((candidate) => candidate.sessionId == "shared").cwd,
        "/project",
      );
      expect(
        result.candidates.singleWhere((candidate) => candidate.sessionId == "launch").cwd,
        "/launch",
      );
    });

    test("preserves authoritative cwd and the newest duplicate timestamp", () async {
      api.sessionsByScope[null] = [
        _session("authoritative", cwd: "/actual", updatedAtMs: 300),
        _session("newer", cwd: "/newer-actual", updatedAtMs: 100),
      ];
      api.sessionsByScope["/launch"] = [
        _session("authoritative", cwd: null, updatedAtMs: 200),
        _session("newer", cwd: null, updatedAtMs: 400),
      ];
      api.sessionsByScope["/project"] = [
        _session("authoritative", cwd: null, updatedAtMs: null),
      ];

      final result = await repository.listCandidates(
        scope: "/project",
        timeout: const Duration(seconds: 1),
      );

      final authoritative = result.candidates.singleWhere(
        (candidate) => candidate.sessionId == "authoritative",
      );
      expect(authoritative.cwd, "/actual");
      expect(authoritative.updatedAtMs, 300);
      final newer = result.candidates.singleWhere(
        (candidate) => candidate.sessionId == "newer",
      );
      expect(newer.cwd, "/newer-actual");
      expect(newer.updatedAtMs, 400);
    });

    test("drops unscoped candidates whose cwd is never established", () async {
      api.sessionsByScope[null] = [
        _session("unknown", cwd: null, updatedAtMs: 300),
        _session("promoted", cwd: null, updatedAtMs: 200),
      ];
      api.sessionsByScope["/launch"] = [
        _session("promoted", cwd: null, updatedAtMs: 200),
      ];
      api.sessionsByScope["/project"] = const [];

      final result = await repository.listCandidates(
        scope: "/project",
        timeout: const Duration(seconds: 1),
      );

      expect(result.candidates.map((candidate) => candidate.sessionId), ["promoted"]);
      expect(result.candidates.single.cwd, "/launch");
    });

    test("known unsupported unfiltered listing remains exhaustive", () async {
      api.errorsByScope[null] = AcpRpcException(
        method: AcpMethods.sessionList,
        code: -32602,
        message: "cwd is required",
      );
      api.sessionsByScope["/launch"] = const [];
      api.sessionsByScope["/project"] = [
        _session("project", cwd: null, updatedAtMs: null),
      ];

      final result = await repository.listCandidates(
        scope: "/project",
        timeout: const Duration(seconds: 1),
      );

      expect(result.exhaustive, isTrue);
      expect(result.candidates.single.cwd, "/project");
    });

    test("unexpected enumeration failure marks partial results non-exhaustive", () async {
      api.errorsByScope[null] = StateError("agent unavailable");
      api.sessionsByScope["/launch"] = [
        _session("launch", cwd: "/launch", updatedAtMs: 10),
      ];
      api.sessionsByScope["/project"] = const [];

      final result = await repository.listCandidates(
        scope: "/project",
        timeout: const Duration(seconds: 1),
      );

      expect(result.exhaustive, isFalse);
      expect(result.candidates.single.sessionId, "launch");
    });

    test("maps grouped options and thought levels from typed ACP results", () {
      final snapshot = repository.mapSessionResult(
        result: _catalogResult(
          modelId: "sonnet-4.6",
          includeThoughtLevel: true,
        ),
      );

      expect(snapshot.modelConfigId, "model-picker");
      expect(snapshot.models.map((option) => option.value), ["gpt-5.4", "sonnet-4.6"]);
      expect(snapshot.loadedModelId, "sonnet-4.6");
      expect(snapshot.modeConfigId, "mode-picker");
      expect(snapshot.modes.map((option) => option.name), ["Agent", "Plan"]);
      expect(snapshot.thoughtLevel?.configId, "effort");
      expect(snapshot.thoughtLevel?.variants, ["medium", "low", "high"]);
    });

    test("maps account models, stable modes, and per-model thought levels", () async {
      api.availableModels = CursorAvailableModelsDto.fromJson({
        "models": [
          {"value": "default", "name": "Auto"},
          {
            "value": "gpt-5.6-sol",
            "name": "GPT-5.6 Sol",
            "configOptions": [
              {
                "id": "reasoning",
                "name": "Reasoning",
                "category": "thought_level",
                "currentValue": "medium",
                "options": [
                  {"value": "none", "name": "None"},
                  {"value": "low", "name": "Low"},
                  {"value": "medium", "name": "Medium"},
                  {"value": "high", "name": "High"},
                ],
              },
            ],
          },
        ],
      });

      final snapshot = await repository.loadAvailableCatalog(
        timeout: const Duration(seconds: 1),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.models.map((model) => model.value), ["default", "gpt-5.6-sol"]);
      expect(snapshot.modes.map((mode) => mode.value), ["agent", "plan", "ask"]);
      expect(snapshot.defaultModeId, "agent");
      expect(snapshot.thoughtLevelsByModel["gpt-5.6-sol"]?.configId, "reasoning");
      expect(
        snapshot.thoughtLevelsByModel["gpt-5.6-sol"]?.variants,
        ["medium", "none", "low", "high"],
      );
    });

    test("maps an unsupported account catalog extension to absence", () async {
      api.availableModelsError = AcpRpcException(
        method: "cursor/list_available_models",
        code: -32601,
        message: "method not found",
      );

      expect(
        await repository.loadAvailableCatalog(timeout: const Duration(seconds: 1)),
        isNull,
      );
    });
  });
}

AcpSessionInfo _session(
  String sessionId, {
  required String? cwd,
  required int? updatedAtMs,
}) {
  return AcpSessionInfo(
    sessionId: sessionId,
    cwd: cwd,
    title: sessionId,
    updatedAtMs: updatedAtMs,
  );
}

AcpNewSessionResult _catalogResult({
  required String modelId,
  required bool includeThoughtLevel,
}) {
  return AcpNewSessionResult.fromJson({
    "sessionId": "session",
    "configOptions": [
      {
        "id": "mode-picker",
        "category": "mode",
        "currentValue": "agent",
        "options": [
          {"value": "agent", "name": "Agent"},
          {"value": "plan", "name": "Plan"},
        ],
      },
      {
        "id": "model-picker",
        "category": "model",
        "currentValue": modelId,
        "options": [
          {
            "group": "models",
            "name": "Models",
            "options": [
              {"value": "gpt-5.4", "name": "GPT-5.4"},
              {"value": "sonnet-4.6", "name": "Sonnet 4.6"},
            ],
          },
        ],
      },
      if (includeThoughtLevel)
        {
          "id": "effort",
          "category": "thought_level",
          "currentValue": "medium",
          "options": [
            {"value": "low", "name": "Low"},
            {"value": "medium", "name": "Medium"},
            {"value": "high", "name": "High"},
          ],
        },
    ],
  });
}

class _FakeCursorCatalogProbeApi implements CursorCatalogProbeApi {
  final Map<String?, List<AcpSessionInfo>> sessionsByScope = {};
  final Map<String?, Object> errorsByScope = {};
  final List<String?> listedScopes = [];
  CursorAvailableModelsDto availableModels = const CursorAvailableModelsDto();
  Object? availableModelsError;

  @override
  Stream<AcpNotification> get notifications => const Stream.empty();

  @override
  Future<AcpInitializeResult> open({required Duration timeout}) async {
    return AcpInitializeResult.fromJson({
      "protocolVersion": 1,
      "agentCapabilities": {
        "loadSession": true,
        "sessionCapabilities": {"list": <String, dynamic>{}},
      },
      "authMethods": <Object?>[],
    });
  }

  @override
  Future<List<AcpSessionInfo>> listSessions({
    required String? cwd,
    required Duration timeout,
  }) async {
    listedScopes.add(cwd);
    final error = errorsByScope[cwd];
    if (error != null) throw error;
    return sessionsByScope[cwd] ?? const [];
  }

  @override
  Future<CursorAvailableModelsDto> listAvailableModels({required Duration timeout}) async {
    final error = availableModelsError;
    if (error != null) throw error;
    return availableModels;
  }

  @override
  Future<AcpNewSessionResult> loadSession({
    required String sessionId,
    required String cwd,
    required Duration timeout,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> reset() async {}

  @override
  Future<void> dispose() async {}
}
