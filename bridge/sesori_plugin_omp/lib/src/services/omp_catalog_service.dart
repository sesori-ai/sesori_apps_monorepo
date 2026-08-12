import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginSessionOptionsCompleteness;

import "../models/omp_catalog_models.dart";
import "../repositories/omp_catalog_repository.dart";
import "../trackers/omp_catalog_tracker.dart";

/// Coordinates bounded scratch-session discovery of OMP project options.
class OmpCatalogService {
  OmpCatalogService({
    required OmpCatalogRepository repository,
    required OmpCatalogTracker tracker,
    required Duration totalTimeout,
    required Duration commandBootstrapDelay,
    required int maxModels,
  }) : _repository = repository,
       _tracker = tracker,
       _totalTimeout = totalTimeout,
       _commandBootstrapDelay = commandBootstrapDelay,
       _maxModels = maxModels;

  final OmpCatalogRepository _repository;
  final OmpCatalogTracker _tracker;
  final Duration _totalTimeout;
  final Duration _commandBootstrapDelay;
  final int _maxModels;
  final Map<String, Future<OmpProjectCatalog?>> _inFlight = {};
  Future<void> _leaseTail = Future.value();

  Future<OmpProjectCatalog?> ensureCatalog({required String projectId}) {
    final scope = normalizeProjectDirectory(directory: projectId);
    final existing = _tracker.snapshotFor(projectId: scope);
    if (existing != null) return Future.value(existing);
    return _coalescedProbe(projectId: scope);
  }

  Future<OmpProjectCatalog?> refreshCatalog({required String projectId}) =>
      _coalescedProbe(projectId: normalizeProjectDirectory(directory: projectId));

  Future<void> dispose() => _repository.dispose();

  Future<OmpProjectCatalog?> _coalescedProbe({required String projectId}) {
    final pending = _inFlight[projectId];
    if (pending != null) return pending;
    late final Future<OmpProjectCatalog?> operation;
    operation = _serializedProbe(projectId: projectId).whenComplete(() {
      if (identical(_inFlight[projectId], operation)) _inFlight.remove(projectId);
    });
    _inFlight[projectId] = operation;
    return operation;
  }

  Future<OmpProjectCatalog?> _serializedProbe({required String projectId}) async {
    final previous = _leaseTail;
    final released = Completer<void>();
    _leaseTail = released.future;
    await previous;
    try {
      return await _probe(projectId: projectId);
    } finally {
      released.complete();
    }
  }

  Future<OmpProjectCatalog?> _probe({required String projectId}) async {
    final stopwatch = Stopwatch()..start();
    String? sessionId;
    try {
      await _repository.open(
        cwd: projectId,
        timeout: _remaining(stopwatch),
      );
      final created = await _repository.createSession(
        cwd: projectId,
        timeout: _remaining(stopwatch),
      );
      sessionId = created.sessionId;
      if (sessionId.isEmpty) throw StateError("OMP catalog session/new omitted sessionId");
      final initial = created.snapshot;
      if (initial.models.isEmpty || initial.modelConfigId == null) {
        return null;
      }

      final thinkingByModel = <String, OmpThinkingOptions>{};
      for (final model in initial.models.take(_maxModels)) {
        final snapshot = await _repository.selectModel(
          sessionId: sessionId,
          configId: initial.modelConfigId!,
          modelValue: model.value,
          timeout: _remaining(stopwatch),
        );
        if (snapshot.currentModelValue != model.value) {
          throw StateError("OMP catalog model selection was only partially applied");
        }
        final thinking = snapshot.thinking;
        if (thinking != null) thinkingByModel[model.value] = thinking;
      }
      await Future<void>.delayed(_commandBootstrapDelay).timeout(_remaining(stopwatch));
      final complete = thinkingByModel.length == initial.models.length && _repository.hasCommandSnapshot;
      final catalog = OmpProjectCatalog(
        modelConfigId: initial.modelConfigId,
        models: initial.models,
        defaultModelValue: initial.currentModelValue,
        modeConfigId: initial.modeConfigId,
        modes: initial.modes,
        defaultModeValue: initial.currentModeValue,
        thinkingByModel: thinkingByModel,
        commands: _repository.commands,
        completeness: complete ? PluginSessionOptionsCompleteness.complete : PluginSessionOptionsCompleteness.partial,
      );
      _tracker.replace(projectId: projectId, catalog: catalog);
      return catalog;
    } on TimeoutException catch (error, stack) {
      Log.w("[omp] catalog probe timed out", error, stack);
      return null;
    } on Object catch (error, stack) {
      Log.w("[omp] catalog probe failed", error, stack);
      return null;
    } finally {
      if (sessionId != null) {
        try {
          await _repository.closeSession(
            sessionId: sessionId,
            timeout: _remainingOrMinimum(stopwatch),
          );
        } on Object catch (error, stack) {
          Log.w("[omp] failed to close catalog session", error, stack);
        }
      }
      await _repository.settle();
    }
  }

  Duration _remaining(Stopwatch stopwatch) {
    final remaining = _totalTimeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("OMP catalog probe exceeded $_totalTimeout");
    }
    return remaining;
  }

  Duration _remainingOrMinimum(Stopwatch stopwatch) {
    final remaining = _totalTimeout - stopwatch.elapsed;
    return remaining > Duration.zero ? remaining : const Duration(seconds: 1);
  }
}
