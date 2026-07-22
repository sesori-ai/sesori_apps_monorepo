import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/catalog_import_repository.dart";
import "../repositories/models/catalog_import_control.dart";

enum CatalogImportTrigger { automatic, explicit, headless }

enum CatalogEmptyHydrationPolicy { complete, retry }

class CatalogImportPluginUnknownException implements Exception {
  CatalogImportPluginUnknownException({required this.pluginId});

  final String pluginId;
}

class CatalogImportPluginNotEnabledException implements Exception {
  CatalogImportPluginNotEnabledException({required this.pluginId});

  final String pluginId;
}

class CatalogImportPluginUnavailableException implements Exception {
  CatalogImportPluginUnavailableException({required this.pluginId});

  final String pluginId;
}

class CatalogImportService {
  CatalogImportService({
    required CatalogImportRepository repository,
    required Set<String> knownPluginIds,
    required List<String> Function() readEligiblePluginIds,
    required CatalogEmptyHydrationPolicy Function(String pluginId) readEmptyHydrationPolicy,
  }) : _repository = repository,
       _knownPluginIds = knownPluginIds,
       _readEligiblePluginIds = readEligiblePluginIds,
       _readEmptyHydrationPolicy = readEmptyHydrationPolicy;

  final CatalogImportRepository _repository;
  final Set<String> _knownPluginIds;
  final List<String> Function() _readEligiblePluginIds;
  final CatalogEmptyHydrationPolicy Function(String pluginId) _readEmptyHydrationPolicy;
  final StreamController<CatalogImportProgress> _progressController = StreamController<CatalogImportProgress>.broadcast(
    sync: true,
  );
  final Map<String, CatalogImportControl> _controls = <String, CatalogImportControl>{};
  final Map<String, Future<void>> _operations = <String, Future<void>>{};
  final Map<String, CatalogImportProgress> _latestStatuses = <String, CatalogImportProgress>{};
  bool _disposing = false;
  Future<void>? _drainFuture;

  Stream<CatalogImportProgress> get progress => _progressController.stream;

  List<CatalogImportProgress> get latestStatuses => List<CatalogImportProgress>.unmodifiable([
    for (final pluginId in _readEligiblePluginIds()) ?_latestStatuses[pluginId],
  ]);

  void start({required String pluginId, required CatalogImportTrigger trigger}) {
    _validatePlugin(pluginId);
    if (_disposing) throw StateError("catalog import service is disposed");

    final activeControl = _controls[pluginId];
    if (activeControl != null) {
      _applyTrigger(control: activeControl, trigger: trigger);
      return;
    }

    final control = CatalogImportControl(
      explicitImportRequested: trigger != CatalogImportTrigger.automatic,
      hydrationMarkerRequested: trigger == CatalogImportTrigger.automatic,
    );
    _controls[pluginId] = control;
    final operation = _run(pluginId: pluginId, control: control);
    _operations[pluginId] = operation;
    unawaited(operation);
  }

  void cancel({required String pluginId}) {
    _validateKnownPlugin(pluginId);
    final control = _controls[pluginId];
    if (control != null) {
      control.cancellationRequested = true;
      return;
    }
    _validateEligiblePlugin(pluginId);
    if (!_repository.importEligiblePluginIds.contains(pluginId)) {
      throw CatalogImportPluginUnavailableException(pluginId: pluginId);
    }
  }

  void beginShutdown() {
    if (_disposing) return;
    _disposing = true;
    for (final control in _controls.values) {
      control.cancellationRequested = true;
    }
  }

  Future<void> drain() => _drainFuture ??= _drain();

  Future<void> dispose() {
    beginShutdown();
    return drain();
  }

  Future<void> _drain() async {
    await Future.wait(_operations.values.toList(growable: false));
    await _progressController.close();
  }

  Future<void> _run({required String pluginId, required CatalogImportControl control}) async {
    try {
      if (!control.explicitImportRequested) {
        final completion = await _repository.getHydrationCompletion(pluginId: pluginId);
        if (control.cancellationRequested) {
          _publish(CatalogImportProgress.cancelled(pluginId: pluginId));
          return;
        }
        if (!control.explicitImportRequested && completion != null) {
          _publish(
            CatalogImportProgress.completed(
              pluginId: pluginId,
              projectsImported: 0,
              sessionsImported: 0,
              completedAt: completion.completedAt,
            ),
          );
          return;
        }
      }

      await for (final progress in _repository.importCatalog(pluginId: pluginId, control: control)) {
        if (progress case CatalogImportCommitting(
          sessionsSeen: 0,
        ) when _readEmptyHydrationPolicy(pluginId) == CatalogEmptyHydrationPolicy.retry) {
          control.hydrationMarkerRequested = false;
        }
        _publish(progress);
      }
    } on Object catch (error) {
      _publish(CatalogImportProgress.failed(pluginId: pluginId, message: error.toString()));
    } finally {
      if (identical(_controls[pluginId], control)) {
        _controls.remove(pluginId);
        unawaited(_operations.remove(pluginId));
      }
    }
  }

  void _applyTrigger({required CatalogImportControl control, required CatalogImportTrigger trigger}) {
    switch (trigger) {
      case CatalogImportTrigger.automatic:
        control.hydrationMarkerRequested = true;
      case CatalogImportTrigger.explicit:
      case CatalogImportTrigger.headless:
        control.explicitImportRequested = true;
    }
  }

  void _publish(CatalogImportProgress status) {
    _latestStatuses[status.pluginId] = status;
    if (!_progressController.isClosed) _progressController.add(status);
  }

  void _validatePlugin(String pluginId) {
    _validateEligiblePlugin(pluginId);
    if (!_repository.importEligiblePluginIds.contains(pluginId)) {
      throw CatalogImportPluginUnavailableException(pluginId: pluginId);
    }
  }

  void _validateEligiblePlugin(String pluginId) {
    _validateKnownPlugin(pluginId);
    if (!_readEligiblePluginIds().contains(pluginId)) {
      throw CatalogImportPluginNotEnabledException(pluginId: pluginId);
    }
  }

  void _validateKnownPlugin(String pluginId) {
    if (!_knownPluginIds.contains(pluginId)) {
      throw CatalogImportPluginUnknownException(pluginId: pluginId);
    }
  }
}
