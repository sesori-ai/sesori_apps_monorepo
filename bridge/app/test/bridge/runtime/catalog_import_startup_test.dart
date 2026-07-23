import "package:sesori_bridge/src/bridge/runtime/bridge_runtime_runner.dart";
import "package:sesori_bridge/src/services/catalog_import_service.dart";
import "package:test/test.dart";

void main() {
  test("runner starts automatic import before ordered headless triggers", () {
    final service = _RecordingCatalogImportService(operationalPluginIds: const {"selected"});

    BridgeRuntimeRunner.startCatalogImports(
      service: service,
      pluginIds: const ["selected"],
      headlessPluginIds: const ["selected", "selected"],
      operationalPluginIds: const {"selected"},
    );

    expect(service.starts, const [
      (pluginId: "selected", trigger: CatalogImportTrigger.automatic),
      (pluginId: "selected", trigger: CatalogImportTrigger.headless),
      (pluginId: "selected", trigger: CatalogImportTrigger.headless),
    ]);
  });

  test("runner rejects an unavailable explicit headless import", () {
    final service = _RecordingCatalogImportService(operationalPluginIds: const {"healthy"});

    expect(
      () => BridgeRuntimeRunner.startCatalogImports(
        service: service,
        pluginIds: const ["unavailable", "healthy"],
        headlessPluginIds: const ["unavailable", "healthy"],
        operationalPluginIds: const {"healthy"},
      ),
      throwsA(isA<CatalogImportPluginUnavailableException>()),
    );

    expect(service.starts, const [
      (pluginId: "healthy", trigger: CatalogImportTrigger.automatic),
    ]);
  });
}

class _RecordingCatalogImportService implements CatalogImportService {
  _RecordingCatalogImportService({required this.operationalPluginIds});

  final Set<String> operationalPluginIds;
  final List<({String pluginId, CatalogImportTrigger trigger})> starts = [];

  @override
  void start({required String pluginId, required CatalogImportTrigger trigger}) {
    if (!operationalPluginIds.contains(pluginId)) {
      throw CatalogImportPluginUnavailableException(pluginId: pluginId);
    }
    starts.add((pluginId: pluginId, trigger: trigger));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
