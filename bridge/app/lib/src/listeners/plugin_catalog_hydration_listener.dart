import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../services/catalog_import_service.dart";

class PluginCatalogHydrationListener {
  PluginCatalogHydrationListener({
    required Stream<List<String>> readyPluginIds,
    required CatalogImportService catalogImportService,
  }) : _readyPluginIds = readyPluginIds,
       _catalogImportService = catalogImportService;

  final Stream<List<String>> _readyPluginIds;
  final CatalogImportService _catalogImportService;
  StreamSubscription<List<String>>? _subscription;
  Set<String> _previousReadyIds = const {};
  bool _disposed = false;

  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = _readyPluginIds.listen(
      _handleReadyPluginIds,
      onError: (Object error, StackTrace stackTrace) {
        Log.w("Plugin catalog hydration readiness stream failed", error, stackTrace);
      },
    );
  }

  void _handleReadyPluginIds(List<String> pluginIds) {
    final nextReadyIds = pluginIds.toSet();
    final additions = [
      for (final pluginId in pluginIds)
        if (!_previousReadyIds.contains(pluginId)) pluginId,
    ];
    _previousReadyIds = nextReadyIds;
    for (final pluginId in additions) {
      try {
        _catalogImportService.start(pluginId: pluginId, trigger: CatalogImportTrigger.automatic);
      } on Object catch (error, stackTrace) {
        Log.w('Automatic catalog hydration could not start for plugin "$pluginId"', error, stackTrace);
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }
}
