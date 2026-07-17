import "package:sesori_bridge/src/bridge/runtime/bridge_runtime_runner.dart";
import "package:sesori_bridge/src/services/catalog_import_service.dart";
import "package:test/test.dart";

void main() {
  test("runner starts automatic import before ordered headless triggers", () {
    final service = _RecordingCatalogImportService();

    BridgeRuntimeRunner.startCatalogImports(
      service: service,
      pluginIds: const ["selected"],
      headlessPluginIds: const ["selected", "selected"],
    );

    expect(service.starts, const [
      (pluginId: "selected", trigger: CatalogImportTrigger.automatic),
      (pluginId: "selected", trigger: CatalogImportTrigger.headless),
      (pluginId: "selected", trigger: CatalogImportTrigger.headless),
    ]);
  });
}

class _RecordingCatalogImportService implements CatalogImportService {
  final List<({String pluginId, CatalogImportTrigger trigger})> starts = [];

  @override
  void start({required String pluginId, required CatalogImportTrigger trigger}) {
    starts.add((pluginId: pluginId, trigger: trigger));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
