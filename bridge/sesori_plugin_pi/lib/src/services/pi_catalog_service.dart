import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/pi_backend_catalog_repository.dart";
import "../trackers/pi_catalog_tracker.dart";

class PiCatalogService({
  required final PiBackendCatalogRepository _repository,
  required final PiCatalogTracker _tracker,
  required final Duration _totalTimeout,
  required final int _maxModels,
}) {
  this {
    if (_totalTimeout <= Duration.zero) throw ArgumentError.value(_totalTimeout, "totalTimeout", "must be positive");
    if (_maxModels <= 0) throw ArgumentError.value(_maxModels, "maxModels", "must be positive");
  }

  final Map<String, Future<PluginSessionOptionsDiscoveryResult>> _inFlight = {};

  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) {
    final normalized = normalizeProjectDirectory(directory: projectId);
    if (discoveryMode == PluginSessionOptionsDiscoveryMode.reuse) {
      final tracked = _tracker.snapshotFor(projectId: normalized);
      if (tracked != null) {
        return Future.value(PluginSessionOptionsDiscoveryResult.observed(options: tracked));
      }
    }
    return _coalescedProbe(projectId: normalized);
  }

  Future<PluginSessionOptionsDiscoveryResult> _coalescedProbe({required String projectId}) {
    final pending = _inFlight[projectId];
    if (pending != null) return pending;
    late final Future<PluginSessionOptionsDiscoveryResult> operation;
    operation = _probe(projectId: projectId).whenComplete(() {
      if (identical(_inFlight[projectId], operation)) _inFlight.remove(projectId);
    });
    _inFlight[projectId] = operation;
    return operation;
  }

  Future<PluginSessionOptionsDiscoveryResult> _probe({required String projectId}) async {
    try {
      final probe = await _repository.probe(
        projectId: projectId,
        totalTimeout: _totalTimeout,
        maxModels: _maxModels,
      );
      final snapshot = PluginSessionOptions(
        agents: probe.agents,
        providers: probe.providers,
        commands: probe.commands,
        completeness: probe.complete
            ? PluginSessionOptionsCompleteness.complete
            : PluginSessionOptionsCompleteness.partial,
      );
      _tracker.replace(projectId: projectId, snapshot: snapshot);
      return PluginSessionOptionsDiscoveryResult.observed(options: snapshot);
    } on Object catch (error, stack) {
      Log.w("[pi] project catalog probe failed", error, stack);
      return const PluginSessionOptionsDiscoveryResult.failed();
    }
  }
}
