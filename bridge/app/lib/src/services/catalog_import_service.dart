import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/catalog_import_repository.dart";
import "../repositories/models/catalog_import_control.dart";

enum CatalogImportTrigger { automatic, explicit, headless }

class CatalogImportPluginNotSelectedException implements Exception {
  CatalogImportPluginNotSelectedException({required this.pluginId});

  final String pluginId;

  @override
  String toString() => "plugin $pluginId is not selected";
}

class CatalogImportService {
  CatalogImportService({required CatalogImportRepository repository}) : _repository = repository;

  final CatalogImportRepository _repository;
  final StreamController<CatalogImportProgress> _progressController = StreamController<CatalogImportProgress>.broadcast(
    sync: true,
  );

  CatalogImportControl? _control;
  Future<void>? _operation;
  CatalogImportProgress? _latestStatus;
  bool _disposed = false;

  Stream<CatalogImportProgress> get progress => _progressController.stream;

  List<CatalogImportProgress> get latestStatuses {
    final latestStatus = _latestStatus;
    return latestStatus == null ? const [] : List.unmodifiable([latestStatus]);
  }

  void start({required String pluginId, required CatalogImportTrigger trigger}) {
    _validateSelectedPlugin(pluginId);
    if (_disposed) throw StateError("catalog import service is disposed");

    final activeControl = _control;
    if (activeControl != null) {
      _applyTrigger(control: activeControl, trigger: trigger);
      return;
    }

    final control = CatalogImportControl(
      explicitImportRequested: trigger != CatalogImportTrigger.automatic,
      hydrationMarkerRequested: trigger == CatalogImportTrigger.automatic,
    );
    _control = control;
    final operation = _run(control: control);
    _operation = operation;
    unawaited(operation);
  }

  void cancel({required String pluginId}) {
    _validateSelectedPlugin(pluginId);
    _control?.cancellationRequested = true;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _control?.cancellationRequested = true;
    await _operation;
    await _progressController.close();
  }

  Future<void> _run({required CatalogImportControl control}) async {
    try {
      if (!control.explicitImportRequested) {
        final completion = await _repository.getHydrationCompletion();
        if (control.cancellationRequested) {
          _publish(CatalogImportProgress.cancelled(pluginId: _repository.pluginId));
          return;
        }
        if (!control.explicitImportRequested && completion != null) {
          _publish(
            CatalogImportProgress.completed(
              pluginId: _repository.pluginId,
              projectsImported: 0,
              sessionsImported: 0,
              completedAt: completion.completedAt,
            ),
          );
          return;
        }
      }

      await _repository.importCatalog(control: control).forEach(_publish);
    } on Object catch (error) {
      _publish(
        CatalogImportProgress.failed(
          pluginId: _repository.pluginId,
          message: error.toString(),
        ),
      );
    } finally {
      if (identical(_control, control)) {
        _control = null;
        _operation = null;
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
    _latestStatus = status;
    if (!_progressController.isClosed) _progressController.add(status);
  }

  void _validateSelectedPlugin(String pluginId) {
    if (pluginId != _repository.pluginId) {
      throw CatalogImportPluginNotSelectedException(pluginId: pluginId);
    }
  }
}
