import "dart:async";

import "package:sesori_bridge/src/listeners/plugin_catalog_hydration_listener.dart";
import "package:sesori_bridge/src/services/catalog_import_service.dart";
import "package:test/test.dart";

void main() {
  test("first ready snapshot hydrates every id and later snapshots hydrate only additions", () async {
    final readyPluginIds = StreamController<List<String>>.broadcast(sync: true);
    final service = _RecordingCatalogImportService(operationalPluginIds: const {"one", "two", "three"});
    final listener = PluginCatalogHydrationListener(
      readyPluginIds: readyPluginIds.stream,
      catalogImportService: service,
    );
    addTearDown(() async {
      await listener.dispose();
      await readyPluginIds.close();
    });

    listener.start();
    readyPluginIds.add(const ["one", "two"]);
    readyPluginIds.add(const ["one", "two"]);
    readyPluginIds.add(const ["two"]);
    readyPluginIds.add(const ["two", "three"]);

    expect(service.starts, const [
      (pluginId: "one", trigger: CatalogImportTrigger.automatic),
      (pluginId: "two", trigger: CatalogImportTrigger.automatic),
      (pluginId: "three", trigger: CatalogImportTrigger.automatic),
    ]);
  });

  test("dispose is terminal", () async {
    final readyPluginIds = StreamController<List<String>>.broadcast(sync: true);
    final service = _RecordingCatalogImportService(operationalPluginIds: const {"one"});
    final listener = PluginCatalogHydrationListener(
      readyPluginIds: readyPluginIds.stream,
      catalogImportService: service,
    );
    addTearDown(readyPluginIds.close);

    listener.start();
    await listener.dispose();
    listener.start();
    readyPluginIds.add(const ["one"]);

    expect(service.starts, isEmpty);
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
