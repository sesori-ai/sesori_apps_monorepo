import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:hermes_plugin/src/api/hermes_acp_api.dart";
import "package:hermes_plugin/src/models/hermes_model_state_dto.dart";
import "package:hermes_plugin/src/repositories/hermes_catalog_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("maps exact model IDs and deletes only after the scratch process exits", () async {
    final api = _FakeHermesAcpApi(result: _modelResult());
    final repository = HermesCatalogRepository(api: api);

    final catalog = await repository.discoverCatalog(
      cwd: "/repo",
      timeout: const Duration(seconds: 2),
    );

    expect(api.operations, ["open", "new", "settle", "delete:catalog-session"]);
    expect(catalog.currentModel?.value, "custom:team:org/model:v2");
    expect(catalog.currentModel?.providerId, "custom:team");
    expect(catalog.currentModel?.modelId, "org/model:v2");
    expect(catalog.currentModel?.providerName, "Team Gateway");
    expect(catalog.currentModel?.name, "Model V2");
    expect(catalog.models.last.providerId, "openrouter");
    expect(catalog.models.last.modelId, "anthropic/claude:beta");
  });

  test("a failed persisted-session delete fails discovery", () async {
    final api = _FakeHermesAcpApi(
      result: _modelResult(),
      deleteError: StateError("database busy"),
    );
    final repository = HermesCatalogRepository(api: api);

    await expectLater(
      repository.discoverCatalog(
        cwd: "/repo",
        timeout: const Duration(seconds: 2),
      ),
      throwsA(
        isA<PluginOperationException>().having(
          (error) => error.operation,
          "operation",
          "hermes catalog cleanup",
        ),
      ),
    );
    expect(api.operations, ["open", "new", "settle", "delete:catalog-session"]);
  });

  test("a scratch process that does not settle is never deleted", () async {
    final api = _FakeHermesAcpApi(
      result: _modelResult(),
      settleError: TimeoutException("process still running"),
    );
    final repository = HermesCatalogRepository(api: api);

    await expectLater(
      repository.discoverCatalog(
        cwd: "/repo",
        timeout: const Duration(seconds: 2),
      ),
      throwsA(isA<PluginOperationException>()),
    );
    expect(api.operations, ["open", "new", "settle"]);
  });

  test("omitted Hermes model fields remain absent at the transport boundary", () {
    final state = HermesSessionModelStateDto.fromJson({
      "availableModels": [
        {"description": null},
      ],
    });

    expect(state.availableModels.single.modelId, isNull);
    expect(state.availableModels.single.name, isNull);
    expect(state.currentModelId, isNull);
  });

  test("an omitted scratch session ID is not sent to the delete command", () async {
    final api = _FakeHermesAcpApi(
      result: const AcpNewSessionResult(
        sessionId: "",
        modes: [],
        configOptions: [],
        raw: {},
      ),
    );
    final repository = HermesCatalogRepository(api: api);

    await expectLater(
      repository.discoverCatalog(
        cwd: "/repo",
        timeout: const Duration(seconds: 2),
      ),
      throwsA(isA<StateError>()),
    );
    expect(api.operations, ["open", "new", "settle"]);
  });
}

AcpNewSessionResult _modelResult() => const AcpNewSessionResult(
  sessionId: "catalog-session",
  modes: [],
  configOptions: [],
  raw: {
    "sessionId": "catalog-session",
    "models": {
      "currentModelId": "custom:team:org/model:v2",
      "availableModels": [
        {
          "modelId": "custom:team:org/model:v2",
          "name": "Team Gateway · Model V2",
          "description": "Provider: Team Gateway • current",
        },
        {
          "modelId": "openrouter:anthropic/claude:beta",
          "name": "OpenRouter · Claude Beta",
          "description": "Provider: OpenRouter",
        },
      ],
    },
  },
);

class _FakeHermesAcpApi({
  required final AcpNewSessionResult result,
  final Object? deleteError,
  final Object? settleError,
}) implements HermesAcpApi {
  final List<String> operations = [];
  bool _processExited = false;

  @override
  Future<void> openScratch({required String cwd, required Duration timeout}) async {
    operations.add("open");
  }

  @override
  Future<AcpNewSessionResult> newScratchSession({
    required String cwd,
    required Duration timeout,
  }) async {
    operations.add("new");
    return result;
  }

  @override
  Future<void> settleScratch({required Duration timeout}) async {
    operations.add("settle");
    final error = settleError;
    if (error != null) throw error;
    _processExited = true;
  }

  @override
  Future<void> deletePersistedSession({
    required String sessionId,
    required Duration timeout,
  }) async {
    if (!_processExited) throw StateError("delete ran before process exit");
    operations.add("delete:$sessionId");
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
