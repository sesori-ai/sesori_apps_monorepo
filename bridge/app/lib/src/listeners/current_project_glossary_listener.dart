import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PendingOperations;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/project_glossary_publication_repository.dart";
import "../services/project_glossary_population_service.dart";

/// Populates glossaries after successful current-project route loads.
class CurrentProjectGlossaryListener({
  required final Stream<String> _source,
  required final ProjectGlossaryPopulationService _service,
}) {
  final PendingOperations _pending = PendingOperations();
  StreamSubscription<String>? _subscription;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (projectId) {
        if (_disposed) return;
        unawaited(_pending.track(operation: _populate(projectId: projectId)));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_disposed) return;
        Log.w("Current-project glossary trigger stream failed", error, stackTrace);
      },
    );
  }

  Future<void> _populate({required String projectId}) async {
    try {
      await _service.populate(projectId: projectId);
    } on ProjectGlossaryPublicationAbortedException {
      // Expected when bridge shutdown aborts publication transport.
    } on Object catch (error, stackTrace) {
      if (_disposed) return;
      Log.w("Current-project glossary population failed; continuing without an updated glossary", error, stackTrace);
    }
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await _pending.drain();
  }
}
