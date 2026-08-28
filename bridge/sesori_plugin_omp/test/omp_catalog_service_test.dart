import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:omp_plugin/src/api/omp_acp_api.dart";
import "package:omp_plugin/src/models/omp_catalog_models.dart";
import "package:omp_plugin/src/repositories/omp_catalog_repository.dart";
import "package:omp_plugin/src/services/omp_catalog_service.dart";
import "package:omp_plugin/src/trackers/omp_catalog_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("captures initial default, exact model IDs, thinking, and commands", () async {
    final repository = _FakeCatalogRepository(
      created: _result(
        sessionId: "probe",
        model: "custom/team/model-v2",
        thinking: const ["off", "high"],
      ),
      selections: {
        "custom/team/model-v2": _result(
          sessionId: "probe",
          model: "custom/team/model-v2",
          thinking: const ["off", "high"],
        ),
        "other/model": _result(
          sessionId: "probe",
          model: "other/model",
          thinking: const ["auto", "max"],
        ),
      },
    );
    final tracker = OmpCatalogTracker();
    final service = OmpCatalogService(
      repository: repository,
      tracker: tracker,
      totalTimeout: const Duration(seconds: 2),
    );

    final outcome = await service.ensureCatalog(projectId: "/project");
    final catalog = (outcome as OmpCatalogObserved).catalog;

    expect(catalog.defaultModelValue, "custom/team/model-v2");
    expect(catalog.models.first.providerId, "custom");
    expect(catalog.models.first.modelId, "team/model-v2");
    expect(catalog.thinkingByModel["custom/team/model-v2"]!.variants, ["off", "high"]);
    expect(catalog.thinkingByModel["other/model"]!.variants, ["auto", "max"]);
    expect(catalog.commands.single.name, "review");
    expect(repository.selectedModels, [
      "custom/team/model-v2",
      "other/model",
      "one/model",
    ]);
    expect(repository.closedSessionIds, ["probe"]);
    expect(repository.settleCount, 1);
  });

  test("keeps project command snapshots distinct and reuses each one", () async {
    final repository = _FakeCatalogRepository(
      created: _result(sessionId: "probe", model: "one/model", thinking: const ["off"]),
      selections: {
        "one/model": _result(sessionId: "probe", model: "one/model", thinking: const ["off"]),
        "other/model": _result(sessionId: "probe", model: "other/model", thinking: const ["off"]),
      },
    );
    final tracker = OmpCatalogTracker();
    final service = OmpCatalogService(
      repository: repository,
      tracker: tracker,
      totalTimeout: const Duration(seconds: 2),
    );

    repository.commandName = "alpha";
    final alpha = (await service.ensureCatalog(projectId: "/alpha") as OmpCatalogObserved).catalog;
    repository.commandName = "beta";
    final beta = (await service.ensureCatalog(projectId: "/beta") as OmpCatalogObserved).catalog;
    repository.commandName = "changed";
    final reused = (await service.ensureCatalog(projectId: "/alpha") as OmpCatalogObserved).catalog;

    expect(alpha.commands.single.name, "alpha");
    expect(beta.commands.single.name, "beta");
    expect(reused.commands.single.name, "alpha");
    expect(repository.openedCwds, ["/alpha", "/beta"]);
  });

  test("waits for delayed command bootstrap before committing the catalog", () async {
    final repository = _FakeCatalogRepository(
      created: _result(sessionId: "probe", model: "one/model", thinking: const ["off"]),
      selections: {
        "one/model": _result(sessionId: "probe", model: "one/model", thinking: const ["off"]),
        "other/model": _result(sessionId: "probe", model: "other/model", thinking: const ["off"]),
      },
    )..commandSnapshotDelay = const Duration(milliseconds: 75);
    final service = OmpCatalogService(
      repository: repository,
      tracker: OmpCatalogTracker(),
      totalTimeout: const Duration(seconds: 2),
    );

    final catalog = (await service.ensureCatalog(projectId: "/project") as OmpCatalogObserved).catalog;

    expect(repository.commandWaited, isTrue);
    expect(catalog.commands.single.name, "review");
  });

  test("no-model discovery fails without replacing the last good snapshot", () async {
    final repository = _FakeCatalogRepository(
      created: _result(sessionId: "probe", model: "one/model", thinking: const ["off"]),
      selections: {
        "one/model": _result(sessionId: "probe", model: "one/model", thinking: const ["off"]),
        "other/model": _result(sessionId: "probe", model: "other/model", thinking: const ["off"]),
      },
    );
    final tracker = OmpCatalogTracker();
    final service = OmpCatalogService(
      repository: repository,
      tracker: tracker,
      totalTimeout: const Duration(seconds: 2),
    );
    final good = (await service.ensureCatalog(projectId: "/project") as OmpCatalogObserved).catalog;
    repository.created = const AcpNewSessionResult(
      sessionId: "empty",
      modes: [],
      configOptions: [],
      raw: {},
    );

    expect(await service.refreshCatalog(projectId: "/project"), isA<OmpCatalogNoModels>());
    expect(tracker.snapshotFor(projectId: "/project"), same(good));
    expect(repository.settleCount, 2);
  });

  test("one model hydration failure preserves a partial catalog", () async {
    final repository = _FakeCatalogRepository(
      created: _result(sessionId: "probe", model: "one/model", thinking: const ["off"]),
      selections: {
        "one/model": _result(sessionId: "probe", model: "one/model", thinking: const ["off"]),
        "other/model": _result(sessionId: "probe", model: "other/model", thinking: const ["high"]),
      },
    )..failedModels.add("custom/team/model-v2");
    final service = OmpCatalogService(
      repository: repository,
      tracker: OmpCatalogTracker(),
      totalTimeout: const Duration(seconds: 2),
    );

    final outcome = await service.ensureCatalog(projectId: "/project");
    final catalog = (outcome as OmpCatalogObserved).catalog;

    expect(catalog.completeness, PluginSessionOptionsCompleteness.partial);
    expect(catalog.models, hasLength(3));
    expect(catalog.thinkingByModel, isNot(contains("custom/team/model-v2")));
    expect(catalog.thinkingByModel["other/model"]!.variants, ["high"]);
  });

  test("hydrates every model in large catalogs", () async {
    final models = [for (var index = 0; index < 30; index++) "provider/model-$index"];
    final created = _result(sessionId: "probe", model: models.first, thinking: const ["off"]);
    created.configOptions.first["options"] = [
      for (final model in models) {"value": model, "name": model},
    ];
    final repository = _FakeCatalogRepository(
      created: created,
      selections: const {},
    );
    final service = OmpCatalogService(
      repository: repository,
      tracker: OmpCatalogTracker(),
      totalTimeout: const Duration(seconds: 2),
    );

    final outcome = await service.ensureCatalog(projectId: "/project");
    final catalog = (outcome as OmpCatalogObserved).catalog;

    expect(catalog.models, hasLength(models.length));
    expect(catalog.thinkingByModel.keys, unorderedEquals(models));
    expect(catalog.completeness, PluginSessionOptionsCompleteness.complete);
    expect(repository.selectedModels, models);
  });
}

AcpNewSessionResult _result({
  required String sessionId,
  required String model,
  required List<String> thinking,
}) => AcpNewSessionResult(
  sessionId: sessionId,
  modes: const [],
  configOptions: [
    {
      "id": "model",
      "category": "model",
      "currentValue": model,
      "options": const [
        {"value": "custom/team/model-v2", "name": "Team Model"},
        {"value": "other/model", "name": "Other"},
        {"value": "one/model", "name": "One"},
      ],
    },
    {
      "id": "mode",
      "category": "mode",
      "currentValue": "default",
      "options": const [
        {"value": "default", "name": "Default"},
        {"value": "plan", "name": "Plan"},
      ],
    },
    {
      "id": "thinking",
      "category": "thought_level",
      "currentValue": thinking.first,
      "options": [
        for (final value in thinking) {"value": value, "name": value},
      ],
    },
  ],
  raw: const {},
);

class _FakeCatalogRepository({
  required var AcpNewSessionResult created,
  required final Map<String, AcpNewSessionResult> selections,
}) implements OmpCatalogRepository {
  final StreamController<AcpNotification> _notifications = StreamController.broadcast();
  final List<String> openedCwds = [];
  final List<String> selectedModels = [];
  final List<String> closedSessionIds = [];
  final Set<String> failedModels = {};
  String commandName = "review";
  Duration commandSnapshotDelay = Duration.zero;
  bool commandWaited = false;
  int settleCount = 0;

  @override
  List<PluginCommand> get commands => [
    PluginCommand(
      name: commandName,
      description: "Project command",
      provider: null,
      source: PluginCommandSource.command,
    ),
  ];

  @override
  bool get hasCommandSnapshot => true;

  @override
  Future<void> waitForCommandSnapshot({required Duration timeout}) async {
    await Future<void>.delayed(commandSnapshotDelay).timeout(timeout);
    commandWaited = true;
  }

  @override
  Future<AcpInitializeResult> open({required String cwd, required Duration timeout}) async {
    openedCwds.add(cwd);
    return AcpInitializeResult.fromJson(const {
      "protocolVersion": 1,
      "agentCapabilities": {
        "sessionCapabilities": {"close": <String, dynamic>{}},
      },
    });
  }

  @override
  Future<OmpCatalogSession> createSession({required String cwd, required Duration timeout}) async {
    scheduleMicrotask(() {
      _notifications.add(
        AcpNotification(
          method: AcpMethods.sessionUpdate,
          params: {
            "sessionId": created.sessionId,
            "update": {
              "sessionUpdate": "available_commands_update",
              "availableCommands": [
                {"name": commandName, "description": "Project command"},
              ],
            },
          },
        ),
      );
    });
    return OmpCatalogSession(
      sessionId: created.sessionId,
      snapshot: mapSessionResult(result: created),
    );
  }

  @override
  Future<OmpSessionConfigSnapshot> selectModel({
    required String sessionId,
    required String configId,
    required String modelValue,
    required Duration timeout,
  }) async {
    selectedModels.add(modelValue);
    if (failedModels.contains(modelValue)) throw StateError("model unavailable");
    return mapSessionResult(
      result: selections[modelValue] ?? _result(sessionId: sessionId, model: modelValue, thinking: const ["off"]),
    );
  }

  @override
  OmpSessionConfigSnapshot mapSessionResult({required AcpNewSessionResult result}) =>
      OmpCatalogRepository(api: _UnusedAcpApi()).mapSessionResult(result: result);

  @override
  Future<void> closeSession({required String sessionId, required Duration timeout}) async {
    closedSessionIds.add(sessionId);
  }

  @override
  Future<void> settle() async => settleCount++;

  @override
  Future<void> dispose() async {
    await _notifications.close();
  }
}

class _UnusedAcpApi() implements OmpAcpApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
