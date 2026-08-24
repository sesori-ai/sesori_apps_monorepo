import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Console;
import "package:sesori_shared/sesori_shared.dart";

class CatalogImportConsoleListener({required final Stream<CatalogImportProgress> _progress}) {
  StreamSubscription<CatalogImportProgress>? _subscription;
  Type? _lastPhase;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _progress.listen(_onProgress);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
  }

  void _onProgress(CatalogImportProgress progress) {
    switch (progress) {
      case CatalogImportEnumerating(:final pluginId):
        if (_lastPhase != CatalogImportEnumerating) {
          Console.message("Importing $pluginId catalog...");
        }
      case CatalogImportCommitting(:final pluginId):
        if (_lastPhase != CatalogImportCommitting) {
          Console.message("Publishing $pluginId catalog...");
        }
      case CatalogImportCompleted(
        :final pluginId,
        :final projectsImported,
        :final sessionsImported,
        :final newItems,
      ):
        Console.message(
          [
            "Imported $pluginId catalog: $projectsImported project(s), $sessionsImported session(s).",
            ?_newItemsSentence(newItems),
          ].join(" "),
        );
        _lastPhase = null;
        return;
      case CatalogImportCancelled(:final pluginId):
        Console.warning("Cancelled $pluginId catalog import.");
        _lastPhase = null;
        return;
      case CatalogImportFailed(:final pluginId, :final message):
        Console.error("Failed to import $pluginId catalog: $message");
        _lastPhase = null;
        return;
    }
    _lastPhase = progress.runtimeType;
  }

  /// The delta sentence that follows a completion line, or null when the delta
  /// is absent.
  ///
  /// Null rather than an empty string so the caller's `join` owns the spacing:
  /// a sentence carrying its own leading space would silently drop or double it
  /// if either side changed. Absent means the counts came from a bridge that
  /// does not report them, so the totals stand alone rather than implying
  /// nothing changed.
  String? _newItemsSentence(CatalogImportNewItems? newItems) {
    if (newItems == null) return null;
    if (newItems.projects == 0 && newItems.sessions == 0) return "Nothing new.";
    return "${newItems.projects} new project(s), ${newItems.sessions} new session(s).";
  }
}
