import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class CatalogImportControl({
  required var bool rescanRequested,
  required var bool hydrationMarkerRequested,
}) implements PluginCatalogCancellationSignal {
  bool _cancelled = false;

  @override
  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}
