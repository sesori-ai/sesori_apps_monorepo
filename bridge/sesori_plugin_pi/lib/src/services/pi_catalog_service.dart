import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/pi_backend_catalog_repository.dart";
import "../trackers/pi_catalog_tracker.dart";

class PiCatalogService({
  required final PiBackendCatalogRepository _repository,
  required final PiCatalogTracker _tracker,
  required final Duration _totalTimeout,
}) {
  this {
    if (_totalTimeout <= Duration.zero) throw ArgumentError.value(_totalTimeout, "totalTimeout", "must be positive");
  }

  static const String compactionCommandName = "compact";

  static final PluginCommand _compactionCommand = PluginCommand.compaction(name: compactionCommandName);

  final Map<String, Future<_PiCatalogProbeOutcome>> _inFlight = {};

  Future<bool> healthCheck() => _repository.healthCheck();

  Future<List<PluginCommand>> getCommands({required String projectId}) async =>
      (await requireOptions(projectId: projectId)).commands;

  bool isNativeCompactionCommand({required PluginCommand command}) => identical(command, _compactionCommand);

  Future<PluginSessionOptions> requireOptions({required String projectId}) async {
    final normalized = normalizeProjectDirectory(directory: projectId);
    final tracked = _tracker.snapshotFor(projectId: normalized);
    if (tracked != null) return tracked;
    final outcome = await _coalescedProbe(projectId: normalized);
    return switch (outcome.result) {
      PluginSessionOptionsDiscoveryObserved(:final options) => options,
      PluginSessionOptionsDiscoveryFailed() => _throwDiscoveryFailure(outcome: outcome),
    };
  }

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
    return _coalescedProbe(projectId: normalized).then((outcome) => outcome.result);
  }

  Future<_PiCatalogProbeOutcome> _coalescedProbe({required String projectId}) {
    final pending = _inFlight[projectId];
    if (pending != null) return pending;
    late final Future<_PiCatalogProbeOutcome> operation;
    operation = _probe(projectId: projectId).whenComplete(() {
      if (identical(_inFlight[projectId], operation)) _inFlight.remove(projectId);
    });
    _inFlight[projectId] = operation;
    return operation;
  }

  Future<_PiCatalogProbeOutcome> _probe({required String projectId}) async {
    try {
      final probe = await _repository.probe(
        projectId: projectId,
        totalTimeout: _totalTimeout,
      );
      final snapshot = PluginSessionOptions(
        agents: probe.agents,
        providers: probe.providers,
        commands: _withCompaction(probe.commands),
        completeness: probe.complete
            ? PluginSessionOptionsCompleteness.complete
            : PluginSessionOptionsCompleteness.partial,
      );
      _tracker.replace(projectId: projectId, snapshot: snapshot);
      return (
        result: PluginSessionOptionsDiscoveryResult.observed(options: snapshot),
        error: null,
        stackTrace: null,
      );
    } on Object catch (error, stack) {
      Log.w("[pi] project catalog probe failed", error, stack);
      return (
        result: const PluginSessionOptionsDiscoveryResult.failed(),
        error: error,
        stackTrace: stack,
      );
    }
  }

  List<PluginCommand> _withCompaction(List<PluginCommand> commands) {
    if (commands.any((command) => command.name == compactionCommandName)) return commands;
    return [...commands, _compactionCommand];
  }

  Never _throwDiscoveryFailure({required _PiCatalogProbeOutcome outcome}) {
    final error = PluginOperationException(
      "discover Pi options",
      message: "Pi session options are unavailable.",
      cause: outcome.error,
    );
    final stackTrace = outcome.stackTrace;
    if (stackTrace == null) throw error;
    Error.throwWithStackTrace(error, stackTrace);
  }
}

typedef _PiCatalogProbeOutcome = ({
  PluginSessionOptionsDiscoveryResult result,
  Object? error,
  StackTrace? stackTrace,
});
