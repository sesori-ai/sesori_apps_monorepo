import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/pi_backend_catalog_repository.dart";
import "../trackers/pi_catalog_tracker.dart";

sealed class const PiOptionsDiscoveryResult();

final class const PiOptionsObserved({required final PluginSessionOptions options}) extends PiOptionsDiscoveryResult;

final class const PiOptionsNoModels() extends PiOptionsDiscoveryResult;

final class const PiOptionsDiscoveryFailed({
  required final Object cause,
  required final StackTrace causeStackTrace,
}) extends PiOptionsDiscoveryResult;

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

  final Map<String, Future<PiOptionsDiscoveryResult>> _inFlight = {};

  Future<bool> healthCheck() => _repository.healthCheck();

  Future<List<PluginCommand>> getCommands({required String projectId}) async =>
      (await requireOptions(projectId: projectId)).commands;

  bool isNativeCompactionCommand({required PluginCommand command}) => identical(command, _compactionCommand);

  Future<PluginSessionOptions> requireOptions({required String projectId}) async {
    final normalized = normalizeProjectDirectory(directory: projectId);
    final tracked = _tracker.snapshotFor(projectId: normalized);
    if (tracked != null) return tracked;
    final result = await _coalescedProbe(projectId: normalized);
    return switch (result) {
      PiOptionsObserved(:final options) => options,
      PiOptionsNoModels() => _throwNoModels(),
      PiOptionsDiscoveryFailed() => _throwDiscoveryFailure(result: result),
    };
  }

  Future<PiOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) {
    final normalized = normalizeProjectDirectory(directory: projectId);
    if (discoveryMode == PluginSessionOptionsDiscoveryMode.reuse) {
      final tracked = _tracker.snapshotFor(projectId: normalized);
      if (tracked != null) return Future.value(PiOptionsObserved(options: tracked));
    }
    return _coalescedProbe(projectId: normalized);
  }

  Future<PiOptionsDiscoveryResult> _coalescedProbe({required String projectId}) {
    final pending = _inFlight[projectId];
    if (pending != null) return pending;
    late final Future<PiOptionsDiscoveryResult> operation;
    operation = _probe(projectId: projectId).whenComplete(() {
      if (identical(_inFlight[projectId], operation)) _inFlight.remove(projectId);
    });
    _inFlight[projectId] = operation;
    return operation;
  }

  Future<PiOptionsDiscoveryResult> _probe({required String projectId}) async {
    try {
      final result = await _repository.probe(
        projectId: projectId,
        totalTimeout: _totalTimeout,
      );
      final PiCatalogProbeSnapshot probe;
      switch (result) {
        case PiCatalogProbeNoModels():
          return const PiOptionsNoModels();
        case PiCatalogProbeObserved(:final snapshot):
          probe = snapshot;
      }
      final snapshot = PluginSessionOptions(
        agents: probe.agents,
        providers: probe.providers,
        commands: _withCompaction(probe.commands),
        completeness: probe.complete
            ? PluginSessionOptionsCompleteness.complete
            : PluginSessionOptionsCompleteness.partial,
      );
      _tracker.replace(projectId: projectId, snapshot: snapshot);
      return PiOptionsObserved(options: snapshot);
    } on Object catch (error, stack) {
      Log.w("[pi] project catalog probe failed", error, stack);
      return PiOptionsDiscoveryFailed(cause: error, causeStackTrace: stack);
    }
  }

  List<PluginCommand> _withCompaction(List<PluginCommand> commands) {
    if (commands.any((command) => command.name == compactionCommandName)) return commands;
    return [...commands, _compactionCommand];
  }

  Never _throwNoModels() => throw const PluginOperationException(
    "discover Pi options",
    message: "Pi session options are unavailable.",
    cause: PiCatalogNoModelsException(),
  );

  Never _throwDiscoveryFailure({required PiOptionsDiscoveryFailed result}) {
    final error = PluginOperationException(
      "discover Pi options",
      message: "Pi session options are unavailable.",
      cause: result.cause,
    );
    Error.throwWithStackTrace(error, result.causeStackTrace);
  }
}
